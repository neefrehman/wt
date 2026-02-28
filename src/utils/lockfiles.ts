import { LOCKFILE_COMMANDS, LOCKFILE_NAMES } from "#/constants.js";

export const detectInstallCommands = (dir: string): string[] => {
  const commands: string[] = [];
  for (const lockfile of LOCKFILE_NAMES) {
    const _file = Bun.file(`${dir}/${lockfile}`);
    // Bun.file().size is 0 for nonexistent files, but we need to check existence
    try {
      // Use sync stat check
      const stat = Bun.file(`${dir}/${lockfile}`);
      if (stat.size > 0 || Bun.file(`${dir}/${lockfile}`).name) {
        const cmd = LOCKFILE_COMMANDS[lockfile];
        if (cmd) {
          commands.push(cmd);
        }
      }
    } catch {
      // file doesn't exist
    }
  }
  return commands;
};

export const detectInstallCommandsAsync = async (dir: string): Promise<string[]> => {
  const commands: string[] = [];
  for (const lockfile of LOCKFILE_NAMES) {
    try {
      const file = Bun.file(`${dir}/${lockfile}`);
      if (await file.exists()) {
        const cmd = LOCKFILE_COMMANDS[lockfile];
        if (cmd) {
          commands.push(cmd);
        }
      }
    } catch {
      // file doesn't exist
    }
  }
  return commands;
};

export const findDepDirs = async (
  root: string,
): Promise<Array<{ dir: string; commands: string[] }>> => {
  const proc = Bun.spawn(
    [
      "find",
      root,
      "-maxdepth",
      "4",
      ...LOCKFILE_NAMES.flatMap((name, i) =>
        i === 0 ? ["(", "-name", name] : ["-o", "-name", name],
      ),
      ")",
      "-not",
      "-path",
      "*/node_modules/*",
      "-not",
      "-path",
      "*/.git/*",
    ],
    { stdout: "pipe", stderr: "pipe" },
  );
  const output = await new Response(proc.stdout).text();
  await proc.exited;

  const dirsSet = new Set<string>();
  for (const line of output.split("\n")) {
    if (!line.trim()) {
      continue;
    }
    const relative = line.replace(`${root}/`, "");
    const dir = relative.split("/").slice(0, -1).join("/") || ".";
    dirsSet.add(dir);
  }

  const results: Array<{ dir: string; commands: string[] }> = [];
  for (const dir of [...dirsSet].sort()) {
    const fullDir = dir === "." ? root : `${root}/${dir}`;
    const commands = await detectInstallCommandsAsync(fullDir);
    if (commands.length > 0) {
      results.push({ dir, commands });
    }
  }

  return results;
};

export const findWorkspaceFiles = async (root: string): Promise<string[]> => {
  const proc = Bun.spawn(
    [
      "find",
      root,
      "-maxdepth",
      "3",
      "-name",
      "*.code-workspace",
      "-not",
      "-path",
      "*/node_modules/*",
      "-not",
      "-path",
      "*/.git/*",
      "-not",
      "-path",
      "*/dist/*",
      "-not",
      "-path",
      "*/.next/*",
    ],
    { stdout: "pipe", stderr: "pipe" },
  );
  const output = await new Response(proc.stdout).text();
  await proc.exited;

  return output
    .split("\n")
    .filter(Boolean)
    .map((f) => f.replace(`${root}/`, ""));
};
