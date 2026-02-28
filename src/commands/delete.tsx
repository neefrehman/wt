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
import type { WorktreeInfo } from "#/types/worktree.js";

export const command = registerCommand({
  name: "delete",
  alias: "d",
  description: "delete worktree + branch",
  args: z.tuple([z.string().optional().describe("name").meta({ worktreeComplete: true })]),
  options: z.object({
    force: z.boolean().default(false).describe("Force delete even with uncommitted changes"),
    all: z.boolean().default(false).describe("Delete all secondary worktrees"),
  }),
});

interface SecondaryWorktree {
  branch: string | null;
  name: string;
  path: string;
}

export default function Delete(props: InferProps<typeof command>) {
  return (
    <Box flexDirection="column" gap={1} paddingY={1}>
      <Text bold>Delete worktrees</Text>
      <Suspense fallback={<Spinner label="Loading worktrees…" />}>
        <DeleteInner
          inputName={props.args?.[0]}
          flagForce={props.options?.force ?? false}
          flagAll={props.options?.all ?? false}
        />
      </Suspense>
    </Box>
  );
}

function DeleteInner({
  inputName,
  flagForce,
  flagAll,
}: {
  inputName?: string;
  flagForce: boolean;
  flagAll: boolean;
}) {
  const { exit, clients } = useCli();
  const [phase, setPhase] = useState<"selecting" | "confirming">("selecting");
  const [selected, setSelected] = useState<SecondaryWorktree[]>([]);
  const [results, setResults] = useState<Array<{ name: string; ok: boolean; message: string }>>([]);
  const [current, setCurrent] = useState(0);

  const { data } = useSuspenseQuery({
    queryKey: ["delete", inputName, flagAll],
    queryFn: async () => {
      const mainWt = await clients.git.mainWorktree();
      const conf = await clients.config.read();
      const parentDir = conf.worktreeDir ?? mainWt.split("/").slice(0, -1).join("/");

      const worktrees = await clients.git.worktreeList();

      const secondaries: SecondaryWorktree[] = R.pipe(
        worktrees,
        R.filter((wt: WorktreeInfo) => wt.path !== mainWt),
        R.map((wt: WorktreeInfo) => ({
          name: wt.path.split("/").pop() ?? "",
          path: wt.path,
          branch: wt.branch,
        })),
      );

      if (secondaries.length === 0) {
        throw new Error("No secondary worktrees to delete");
      }

      // Pre-select based on input
      let preSelected: SecondaryWorktree[] = [];
      if (inputName) {
        const matched = secondaries.filter((s) => [inputName].includes(s.name));
        if (matched.length === 0) {
          throw new Error(`Worktree '${inputName}' not found`);
        }
        preSelected = matched;
      } else if (flagAll) {
        preSelected = secondaries;
      } else if (secondaries.length === 1) {
        preSelected = secondaries;
      }

      return { mainWorktree: mainWt, parentDir, secondaries, preSelected };
    },
  });

  const deleteMutation = useMutation({
    mutationFn: async (items: SecondaryWorktree[]) => {
      const newResults: Array<{ name: string; ok: boolean; message: string }> = [];

      for (const [i, item] of items.entries()) {
        setCurrent(i);

        try {
          await clients.git.worktreeRemove(item.path, {
            force: flagForce,
            cwd: data.mainWorktree,
          });
          newResults.push({ name: item.name, ok: true, message: "Removed" });
        } catch (err) {
          if (flagForce) {
            newResults.push({
              name: item.name,
              ok: false,
              message: String(err instanceof Error ? err.message : err),
            });
          } else {
            try {
              await clients.git.worktreeRemove(item.path, {
                force: true,
                cwd: data.mainWorktree,
              });
              newResults.push({
                name: item.name,
                ok: true,
                message: "Removed (forced)",
              });
            } catch (forceErr) {
              newResults.push({
                name: item.name,
                ok: false,
                message: String(forceErr instanceof Error ? forceErr.message : forceErr),
              });
            }
          }
        }

        // Delete branch too
        if (item.branch) {
          try {
            await clients.git.branchDelete(item.branch, {
              force: flagForce,
              cwd: data.mainWorktree,
            });
          } catch {
            // best effort
          }
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

  // Pre-selected → go straight to confirming
  if (data.preSelected.length > 0 && phase === "selecting") {
    setSelected(data.preSelected);
    setPhase("confirming");
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
      <Select
        selectionMode="multiple"
        onSubmit={(values) => {
          const vals = values as string[];
          const items = data.secondaries.filter((s) => vals.includes(s.name));
          if (items.length === 0) {
            setTimeout(exit, 100);
            return;
          }
          setSelected(items);
          setPhase("confirming");
        }}
      >
        {data.secondaries.map((s) => (
          <Select.Option key={s.name} value={s.name}>
            {s.name}
          </Select.Option>
        ))}
      </Select>
    ))
    .with("confirming", () => (
      <>
        <Text bold>
          Delete {selected.length} worktree{selected.length > 1 ? "s" : ""}?
        </Text>
        {selected.map((s) => (
          <Text color="yellow" key={s.name}>
            {s.name}
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
              <Text color={r.ok ? "green" : "red"}>{r.name}</Text> — {r.message}
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
              <Text color={r.ok ? "green" : "red"}>{r.name}</Text> — {r.message}
            </Text>
          </StatusMessage>
        ))}
      </>
    ))
    .exhaustive();
}

command.registerComponent(Delete);
