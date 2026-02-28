import { Suspense } from "react";

import { Spinner } from "@inkjs/ui";
import { Box, Text } from "ink";

import { useSuspenseQuery } from "@tanstack/react-query";
import * as R from "remeda";

import { registerCommand } from "#/cli-setup.js";
import type { GitClient } from "#/clients/git.js";
import { useCli } from "#/hooks/useCli.js";

export const command = registerCommand({
  name: "list",
  alias: "ls",
  description: "list worktrees with status",
});

const THEME_RE = /"workbench\.colorTheme"\s*:\s*"([^"]*)"/;

const getWorktreeStatus = async (git: GitClient, path: string): Promise<string> => {
  const parts: string[] = [];

  const count = await git.statusCount({ cwd: path });
  if (count > 0) {
    parts.push(`${count} dirty`);
  }

  const { ahead, behind } = await git.aheadBehind({ cwd: path });
  if (ahead > 0) {
    parts.push(`↑${ahead}`);
  }
  if (behind > 0) {
    parts.push(`↓${behind}`);
  }

  return parts.length > 0 ? parts.join(" ") : "clean";
};

const readWorktreeTheme = async (wtPath: string): Promise<string> => {
  const settingsDirs = [".vscode", ".cursor", ".windsurf"];
  for (const dir of settingsDirs) {
    try {
      const file = Bun.file(`${wtPath}/${dir}/settings.json`);
      const text = await file.text();
      const match = text.match(THEME_RE);
      if (match) {
        return match[1] ?? "(none)";
      }
    } catch {
      // file doesn't exist, continue
    }
  }
  return "(none)";
};

export default function List() {
  return (
    <Box flexDirection="column" gap={1} paddingY={1}>
      <Suspense fallback={<Spinner label="Loading worktrees…" />}>
        <ListInner />
      </Suspense>
    </Box>
  );
}

function ListInner() {
  const { clients } = useCli();

  const { data } = useSuspenseQuery({
    queryKey: ["list"],
    queryFn: async () => {
      const mainWt = await clients.git.mainWorktree();
      const repoName = mainWt.split("/").pop() ?? "";
      const currentWt = await clients.git.repoRoot();
      const allWorktrees = await clients.git.worktreeList();
      const secondary = R.filter(allWorktrees, (wt) => wt.path !== mainWt);

      const worktrees = await Promise.all(
        secondary.map(async (wt) => ({
          name: wt.path.split("/").pop() ?? "",
          branch: wt.branch ?? "(detached)",
          theme: await readWorktreeTheme(wt.path),
          status: await getWorktreeStatus(clients.git, wt.path),
          isCurrent: wt.path === currentWt,
        })),
      );

      return { repoName, worktrees };
    },
  });

  if (data.worktrees.length === 0) {
    return (
      <>
        <Text bold>
          Worktrees for <Text color="cyan">{data.repoName}</Text>
        </Text>
        <Text dimColor>(no secondary worktrees)</Text>
      </>
    );
  }

  // Calculate column widths
  const maxName = Math.max(...data.worktrees.map((w) => w.name.length));
  const maxBranch = Math.max(...data.worktrees.map((w) => w.branch.length));
  const maxTheme = Math.max(...data.worktrees.map((w) => w.theme.length));

  return (
    <>
      <Text bold>
        Worktrees for <Text color="cyan">{data.repoName}</Text>
      </Text>
      <Box flexDirection="column">
        {data.worktrees.map((wt) => (
          <Text key={wt.name}>
            <Text color="cyan">{wt.name.padEnd(maxName)}</Text>
            {"  "}
            <Text dimColor>branch:</Text> {wt.branch.padEnd(maxBranch)}
            {"  "}
            <Text dimColor>theme:</Text> <Text color="yellow">{wt.theme.padEnd(maxTheme)}</Text>
            {"  "}
            <Text dimColor>status:</Text>{" "}
            <Text
              color={wt.status === "clean" ? "green" : undefined}
              dimColor={wt.status !== "clean"}
            >
              {wt.status}
            </Text>
            {wt.isCurrent && <Text dimColor> (current)</Text>}
          </Text>
        ))}
      </Box>
    </>
  );
}

command.registerComponent(List);
