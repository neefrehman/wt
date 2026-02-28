import { Suspense, useState } from "react";

import { Spinner, StatusMessage } from "@inkjs/ui";
import { Box, Text } from "ink";

import { useMutation, useSuspenseQuery } from "@tanstack/react-query";
import * as R from "remeda";
import { match } from "ts-pattern";
import { z } from "zod";

import { type InferProps, registerCommand } from "#/cli-setup.js";
import { Select } from "#/components/Select.js";
import { useCli } from "#/hooks/useCli.js";

export const command = registerCommand({
  name: "rename",
  alias: "rn",
  description: "rename a worktree directory and optionally its branch",
  args: z.tuple([
    z.string().optional().describe("old-or-new").meta({ worktreeComplete: true }),
    z.string().optional().describe("new-name"),
  ]),
});

export default function Rename(props: InferProps<typeof command>) {
  return (
    <Box flexDirection="column" gap={1} paddingY={1}>
      <Text bold>Rename worktree</Text>
      <Suspense fallback={<Spinner label="Loading worktrees…" />}>
        <RenameInner oldOrNew={props.args?.[0]} newNameArg={props.args?.[1]} />
      </Suspense>
    </Box>
  );
}

function RenameInner({ oldOrNew, newNameArg }: { oldOrNew?: string; newNameArg?: string }) {
  const { exit, clients } = useCli();
  const [messages, setMessages] = useState<Array<{ variant: "success" | "error"; text: string }>>(
    [],
  );
  const { data } = useSuspenseQuery({
    queryKey: ["rename", oldOrNew, newNameArg],
    queryFn: async () => {
      const [conf, main] = await Promise.all([clients.config.read(), clients.git.mainWorktree()]);
      const parentDir = conf.worktreeDir ?? main.split("/").slice(0, -1).join("/");

      if (oldOrNew && newNameArg) {
        // Both args given — rename directly
        return {
          parentDir,
          main,
          oldName: oldOrNew,
          newName: newNameArg,
          secondaries: [] as string[],
          needsPicker: false,
        };
      }

      if (oldOrNew && !newNameArg) {
        // Single arg — it's the new name, determine old from context
        const currentRoot = await clients.git.repoRoot();
        if (currentRoot && currentRoot !== main) {
          const old = currentRoot.split("/").pop() ?? "";
          return {
            parentDir,
            main,
            oldName: old,
            newName: oldOrNew,
            secondaries: [] as string[],
            needsPicker: false,
          };
        }

        // Need picker for old name
        const worktrees = await clients.git.worktreeList();
        const secs = R.pipe(
          worktrees,
          R.filter((wt) => wt.path !== main),
          R.map((wt) => wt.path.split("/").pop() ?? ""),
        );
        return {
          parentDir,
          main,
          oldName: "",
          newName: oldOrNew,
          secondaries: secs,
          needsPicker: true,
        };
      }

      // No args
      throw new Error("Usage: wt rename [<old>] <new>");
    },
  });

  const renameMutation = useMutation({
    mutationFn: async ({ old, newN }: { old: string; newN: string }) => {
      const oldPath = `${data.parentDir}/${old}`;
      const newPath = `${data.parentDir}/${newN}`;

      await clients.git.worktreeMove(oldPath, newPath, { cwd: data.main });

      setMessages((prev) => [...prev, { variant: "success" as const, text: "Directory moved" }]);

      const currentBranch = await clients.git.currentBranch(newPath);
      if (currentBranch && currentBranch !== newN) {
        await clients.git.branchRename(currentBranch, newN, { cwd: newPath });
        setMessages((prev) => [
          ...prev,
          { variant: "success" as const, text: `Branch renamed to ${newN}` },
        ]);
      }

      return { old, newN };
    },
    onSuccess: () => {
      setTimeout(exit, 100);
    },
  });

  if (!data.needsPicker && renameMutation.isIdle) {
    // Direct rename (no picker needed)
    renameMutation.mutate({ old: data.oldName, newN: data.newName });
  }

  const view = (() => {
    if (renameMutation.isPending) {
      return "renaming" as const;
    }
    if (renameMutation.isSuccess) {
      return "done" as const;
    }
    return "picking" as const;
  })();

  return match(view)
    .with("picking", () => (
      <Select
        onSubmit={(value) => {
          renameMutation.mutate({
            old: value as string,
            newN: data.newName,
          });
        }}
      >
        {data.secondaries.map((s) => (
          <Select.Option key={s} value={s}>
            {s}
          </Select.Option>
        ))}
      </Select>
    ))
    .with("renaming", () => {
      const old = (renameMutation.variables?.old ?? data.oldName) || "worktree";
      const newN = renameMutation.variables?.newN ?? data.newName;
      return <Spinner label={`Renaming ${old} → ${newN}…`} />;
    })
    .with("done", () => {
      const { old, newN } = renameMutation.data!;
      return (
        <>
          <Text bold>
            Renamed <Text color="cyan">{old}</Text> → <Text color="cyan">{newN}</Text>
          </Text>
          {messages.map((msg) => (
            <StatusMessage key={msg.text} variant={msg.variant}>
              <Text>{msg.text}</Text>
            </StatusMessage>
          ))}
        </>
      );
    })
    .exhaustive();
}

command.registerComponent(Rename);
