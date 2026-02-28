import { Suspense } from "react";

import { Spinner, StatusMessage } from "@inkjs/ui";
import { Box, Text } from "ink";

import { useSuspenseQuery } from "@tanstack/react-query";
import { z } from "zod";

import { type InferProps, registerCommand } from "#/cli-setup.js";
import { Banner } from "#/components/Banner.js";
import { useCli } from "#/hooks/useCli.js";
import { syncGitignored } from "#/utils/sync-patterns.js";

export const command = registerCommand({
  name: "sync",
  alias: "s",
  description: "re-sync gitignored files from main to a worktree",
  args: z.tuple([z.string().optional().describe("name").meta({ worktreeComplete: true })]),
});

export default function Sync(props: InferProps<typeof command>) {
  return (
    <Box flexDirection="column" gap={1} paddingY={1}>
      <Banner />
      <Text bold>Syncing gitignored files</Text>
      <Suspense fallback={<Spinner label="Syncing…" />}>
        <SyncInner name={props.args?.[0]} />
      </Suspense>
    </Box>
  );
}

function SyncInner({ name }: { name?: string }) {
  const { exit, clients } = useCli();

  const { data } = useSuspenseQuery({
    queryKey: ["sync", name],
    queryFn: async () => {
      const [config, mainWt] = await Promise.all([
        clients.config.read(),
        clients.git.mainWorktree(),
      ]);

      // Resolve target worktree
      let wtPath: string;
      if (name) {
        const parent = config.worktreeDir ?? mainWt.split("/").slice(0, -1).join("/");
        wtPath = `${parent}/${name}`;
      } else {
        const rootResult = await clients.git.repoRoot();
        wtPath = rootResult;
        if (wtPath === mainWt) {
          throw new Error("Cannot sync main worktree to itself");
        }
      }

      const wtName = wtPath.split("/").pop() ?? "";
      const syncResult = await syncGitignored(wtPath, mainWt, config, clients.git);

      if (syncResult) {
        const categories = config.ignoredFileCategories?.join(", ") ?? "";
        return categories
          ? `Synced ${categories} files to ${wtName}`
          : `Gitignored files synced to ${wtName}`;
      }
      return "No sync categories configured — run wt init to configure";
    },
  });

  setTimeout(exit, 100);

  return (
    <StatusMessage variant="success">
      <Text>{data}</Text>
    </StatusMessage>
  );
}

command.registerComponent(Sync);
