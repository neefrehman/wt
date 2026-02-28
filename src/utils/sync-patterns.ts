import type { ConfigValues } from "#/clients/config.js";
import type { GitClient } from "#/clients/git.js";
import {
  BUILD_DIRS,
  CACHE_DIRS,
  CONFIG_DIRS,
  CONFIG_FILES,
  DEP_DIRS,
  NOISE_FILES,
  SYNC_CATEGORY_KEYS,
  type SyncCategoryKey,
} from "#/constants.js";

const DOTENV_RE = /(^|\/)\.env($|[./])/;
export const SYNC_NOISE_RE =
  /(\.DS_Store|\.tsbuildinfo|next-env\.d\.ts|CACHEDIR\.TAG|\.gitignore|chromium-pack\.tar)$/;

// Build regex patterns for each sync category
const escapeRegex = (s: string): string => {
  return s.replaceAll(/[.*+?^${}()|[\]\\]/g, "\\$&");
};

const buildPatterns = (): Record<SyncCategoryKey, RegExp> => {
  const depPattern = DEP_DIRS.map(escapeRegex).join("|");
  const configDirPattern = CONFIG_DIRS.map(escapeRegex).join("|");
  const configFilePattern = CONFIG_FILES.map(escapeRegex).join("|");
  const buildPattern = BUILD_DIRS.map(escapeRegex).join("|");
  const cachePattern = CACHE_DIRS.map(escapeRegex).join("|");

  return {
    deps: new RegExp(`(^|/)(${depPattern})(/|$)`),
    dotenv: DOTENV_RE,
    config: new RegExp(`(^|/)(${configDirPattern})(/|$)|(^|/)(${configFilePattern})$`),
    build: new RegExp(`(^|/)(${buildPattern})(/|$)`),
    cache: new RegExp(`(^|/)(${cachePattern})(/|$)`),
  };
};

const PATTERNS = buildPatterns();

export const classifyCategory = (entry: string): SyncCategoryKey | null => {
  for (const key of SYNC_CATEGORY_KEYS) {
    if (PATTERNS[key].test(entry)) {
      return key;
    }
  }
  return null;
};

export const syncGitignored = async (
  targetDir: string,
  mainWt: string,
  config: ConfigValues,
  git?: GitClient,
): Promise<boolean> => {
  const ignoredFileCategories = config.ignoredFileCategories ?? [];
  if (ignoredFileCategories.length === 0) {
    return false;
  }

  const enabledCategories = ignoredFileCategories;

  // Build combined pattern from enabled categories
  const combinedPatterns = enabledCategories.map((key) => PATTERNS[key]).filter(Boolean);

  if (combinedPatterns.length === 0) {
    return false;
  }

  // Bail out if the target directory doesn't exist (e.g. fake/dev clients)
  // TODO: move logic into clients to make managing fake client expectation clearer
  const targetExists = await Bun.file(`${targetDir}/.git`).exists();
  if (!targetExists) {
    return false;
  }

  // Get gitignored files from main worktree
  let allEntries: string[];
  if (git) {
    allEntries = await git.listIgnoredFiles({ cwd: mainWt });
  } else {
    const proc = Bun.spawn(
      ["git", "ls-files", "--others", "--ignored", "--directory", "--exclude-standard"],
      { cwd: mainWt, stdout: "pipe", stderr: "pipe" },
    );
    const output = await new Response(proc.stdout).text();
    await proc.exited;
    allEntries = output.split("\n").filter(Boolean);
  }

  const entries = allEntries
    .filter((e) => e && !SYNC_NOISE_RE.test(e))
    .filter((entry) => combinedPatterns.some((p) => p.test(entry)));

  if (entries.length === 0) {
    return true;
  }

  // Build rsync excludes for noise files
  const rsyncExcludes = NOISE_FILES.flatMap((f) => ["--exclude", f]);

  // Separate directories from files
  const dirs: string[] = [];
  const files: string[] = [];
  for (const entry of entries) {
    if (entry.endsWith("/")) {
      dirs.push(entry);
    } else {
      files.push(entry);
    }
  }

  // Sync directories individually
  for (const dir of dirs) {
    const src = `${mainWt}/${dir}`;
    const dest = `${targetDir}/${dir}`;
    try {
      await Bun.spawn(["mkdir", "-p", dest]).exited;
      await Bun.spawn(["rsync", "-a", ...rsyncExcludes, src, dest]).exited;
    } catch {
      // best effort
    }
  }

  if (files.length > 0) {
    // Batch-copy files
    const tmpFile = `${targetDir}/.wt-sync-list`;
    await Bun.write(tmpFile, files.join("\n"));
    try {
      await Bun.spawn(["rsync", "-a", `--files-from=${tmpFile}`, `${mainWt}/`, `${targetDir}/`])
        .exited;
    } catch {
      // best effort
    }
    try {
      await Bun.spawn(["rm", "-f", tmpFile]).exited;
    } catch {
      // ignore
    }
  }

  return true;
};
