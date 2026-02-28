import { Suspense, useState } from "react";

import { Spinner, StatusMessage } from "@inkjs/ui";
import { Box, Text } from "ink";

import { useMutation, useSuspenseQuery } from "@tanstack/react-query";
import { match } from "ts-pattern";
import { z } from "zod";

import { type InferProps, registerCommand } from "#/cli-setup.js";
import { Select } from "#/components/Select.js";
import { useCli } from "#/hooks/useCli.js";

export const command = registerCommand({
  name: "clean",
  alias: "cl",
  description: "detect and delete stale worktrees",
  options: z.object({
    yes: z.boolean().default(false).describe("Skip confirmation prompt"),
  }),
});

interface StaleBranch {
  name: string;
  reason: "merged" | "gone";
  upstream: string | null;
}

export default function Clean(props: InferProps<typeof command>) {
  return (
    <Box flexDirection="column" gap={1} paddingY={1}>
      <Text bold>Clean stale branches</Text>
      <Suspense fallback={<Spinner label="Scanning for stale branches…" />}>
        <CleanInner {...props} />
      </Suspense>
    </Box>
  );
}

function CleanInner({ options }: InferProps<typeof command>) {
  const { exit, clients } = useCli();
  const [phase, setPhase] = useState<"selecting" | "confirming">("selecting");
  const [selected, setSelected] = useState<StaleBranch[]>([]);
  const [results, setResults] = useState<Array<{ name: string; ok: boolean; message: string }>>([]);
  const [current, setCurrent] = useState(0);

  const { data } = useSuspenseQuery({
    queryKey: ["clean"],
    queryFn: async () => {
      const mainWt = await clients.git.mainWorktree();
      const defaultBranch = await clients.git.defaultBranch();

      await clients.git.fetch({ prune: true, cwd: mainWt });

      const branches = await clients.git.branchList({
        cwd: mainWt,
        verbose: true,
      });
      const worktrees = await clients.git.worktreeList(mainWt);
      const wtBranches = new Set<string>();
      for (const wt of worktrees) {
        if (wt.branch) {
          wtBranches.add(wt.branch);
        }
      }

      const staleBranches: StaleBranch[] = [];

      for (const branch of branches) {
        if (branch.name === defaultBranch) {
          continue;
        }
        if (wtBranches.has(branch.name)) {
          continue;
        }
        if (branch.isHead) {
          continue;
        }

        if (branch.gone) {
          staleBranches.push({
            name: branch.name,
            reason: "gone",
            upstream: branch.upstream,
          });
        } else {
          const mergedBranches = await clients.git.branchListMerged(defaultBranch, {
            cwd: mainWt,
          });
          if (mergedBranches.includes(branch.name)) {
            staleBranches.push({
              name: branch.name,
              reason: "merged",
              upstream: branch.upstream,
            });
          }
        }
      }

      return { mainWorktree: mainWt, defaultBranch, staleBranches };
    },
  });

  const deleteMutation = useMutation({
    mutationFn: async (items: StaleBranch[]) => {
      const newResults: Array<{ name: string; ok: boolean; message: string }> = [];

      for (const [i, branch] of items.entries()) {
        setCurrent(i);
        try {
          await clients.git.branchDelete(branch.name, {
            force: true,
            cwd: data.mainWorktree,
          });
          newResults.push({
            name: branch.name,
            ok: true,
            message: `Deleted (${branch.reason})`,
          });
        } catch (err) {
          newResults.push({
            name: branch.name,
            ok: false,
            message: String(err instanceof Error ? err.message : err),
          });
        }
        setResults([...newResults]);
      }

      setCurrent(items.length);
      return newResults;
    },
    onSuccess: () => {
      setTimeout(exit, 100);
    },
  });

  if (data.staleBranches.length === 0) {
    setTimeout(exit, 100);
    return (
      <StatusMessage variant="success">
        <Text>No stale branches found</Text>
      </StatusMessage>
    );
  }

  const view = (() => {
    if (deleteMutation.isPending) {
      return "deleting" as const;
    }
    if (deleteMutation.isSuccess) {
      return "done" as const;
    }
    return phase;
  })();

  return match(view)
    .with("selecting", () => (
      <>
        <Text bold>
          Found {data.staleBranches.length} stale branch
          {data.staleBranches.length > 1 ? "es" : ""}:
        </Text>
        <Select
          selectionMode="multiple"
          onSubmit={(values) => {
            const vals = values as string[];
            const items = data.staleBranches.filter((b) => vals.includes(b.name));
            if (items.length === 0) {
              setTimeout(exit, 100);
              return;
            }
            setSelected(items);
            if (options.yes) {
              deleteMutation.mutate(items);
            } else {
              setPhase("confirming");
            }
          }}
        >
          {data.staleBranches.map((b) => (
            <Select.Option key={b.name} value={b.name}>
              {b.name}
            </Select.Option>
          ))}
        </Select>
      </>
    ))
    .with("confirming", () => (
      <>
        <Text bold>
          Delete {selected.length} branch
          {selected.length > 1 ? "es" : ""}?
        </Text>
        {selected.map((b) => (
          <Text color="yellow" key={b.name}>
            {b.name} <Text dimColor>({b.reason})</Text>
          </Text>
        ))}
        <Select
          onSubmit={(value) => {
            if (value === "yes") {
              deleteMutation.mutate(selected);
            } else {
              setTimeout(exit, 100);
            }
          }}
        >
          <Select.Option value="yes">Yes, delete</Select.Option>
          <Select.Option value="no">Cancel</Select.Option>
        </Select>
      </>
    ))
    .with("deleting", () => (
      <>
        {results.map((r) => (
          <StatusMessage key={r.name} variant={r.ok ? "success" : "error"}>
            <Text>
              {r.name} — {r.message}
            </Text>
          </StatusMessage>
        ))}
        {current < selected.length && <Spinner label={`Deleting ${selected[current]?.name}…`} />}
      </>
    ))
    .with("done", () => (
      <>
        {results.map((r) => (
          <StatusMessage key={r.name} variant={r.ok ? "success" : "error"}>
            <Text>
              {r.name} — {r.message}
            </Text>
          </StatusMessage>
        ))}
      </>
    ))
    .exhaustive();
}

command.registerComponent(Clean);
