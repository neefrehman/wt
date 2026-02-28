const SLASH_RE = /\//g;
const INVALID_BRANCH_CHARS_RE = /[^a-zA-Z0-9._-]/g;
const MULTI_DASH_RE = /-+/g;
const LEADING_TRAILING_DASH_RE = /^-|-$/g;
const INVALID_NAME_CHARS_RE = /[^a-zA-Z0-9._/-]/;

export const sanitizeBranchName = (name: string): string => {
  return name
    .replace(SLASH_RE, "-")
    .replace(INVALID_BRANCH_CHARS_RE, "-")
    .replace(MULTI_DASH_RE, "-")
    .replace(LEADING_TRAILING_DASH_RE, "");
};

export const validateWorktreeName = (name: string): string | null => {
  if (name.startsWith("-")) {
    return "Name cannot start with '-'";
  }
  if (name.includes("..")) {
    return "Name cannot contain '..'";
  }
  if (INVALID_NAME_CHARS_RE.test(name)) {
    return "Only alphanumeric characters, dots, slashes, hyphens, and underscores are allowed";
  }
  return null;
};

export const nextWorktreeName = (mainWorktreePath: string, parentDir: string): string => {
  const repoName = mainWorktreePath.split("/").pop() ?? mainWorktreePath;
  let max = 0;

  try {
    const entries = Array.from(
      new Bun.Glob(`${repoName}-wt-*`).scanSync({
        cwd: parentDir,
        onlyFiles: false,
      }),
    );
    for (const entry of entries) {
      const suffix = entry.replace(`${repoName}-wt-`, "");
      const n = Number.parseInt(suffix, 10);
      if (!Number.isNaN(n) && n > max) {
        max = n;
      }
    }
  } catch {
    // directory doesn't exist or can't be read
  }

  return `${repoName}-wt-${max + 1}`;
};
