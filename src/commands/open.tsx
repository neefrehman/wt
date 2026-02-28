import { Suspense, useState } from "react";

import { Spinner, StatusMessage } from "@inkjs/ui";
import { Box, Text } from "ink";

import { useSuspenseQuery } from "@tanstack/react-query";
import * as R from "remeda";
import { z } from "zod";

import { type InferProps, registerCommand } from "#/cli-setup.js";
import type { ConfigValues } from "#/clients/config.js";
import { type EditorKey, editorDisplayName } from "#/clients/editor.js";
import { Select } from "#/components/Select.js";
import { useCli } from "#/hooks/useCli.js";

export const command = registerCommand({
  name: "open",
  alias: "o",
  description: "open or cd into a worktree",
  args: z.tuple([z.string().optional().describe("name").meta({ worktreeComplete: true })]),
  options: z.object({
    open: z.boolean().default(false).describe("Open in editor"),
    cd: z.boolean().default(false).describe("cd into worktree"),
    editor: z.string().optional().describe("Override editor"),
  }),
  shortFlags: {
    open: "o",
    cd: "d",
    editor: "e",
  },
});

export default function Open(props: InferProps<typeof command>) {
  return (
    <Box flexDirection="column" gap={1} paddingY={1}>
      <Text bold>Open worktree</Text>
      <Suspense fallback={<Spinner label="Loading worktrees…" />}>
        <OpenInner
          name={props.args?.[0]}
          flagCd={props.options?.cd}
          editorOverride={props.options?.editor}
        />
      </Suspense>
    </Box>
  );
}

type Phase = "picking" | "opening" | "done";

function OpenInner({
  name,
  flagCd,
  editorOverride,
}: {
  name?: string;
  flagCd?: boolean;
  editorOverride?: string;
}) {
  const { exit, clients } = useCli();
  const [phase, setPhase] = useState<Phase>("picking");
  const [message, setMessage] = useState("");

  const { data } = useSuspenseQuery({
    queryKey: ["open", name],
    queryFn: async () => {
      const [conf, main] = await Promise.all([clients.config.read(), clients.git.mainWorktree()]);
      const parentDir = conf.worktreeDir ?? main.split("/").slice(0, -1).join("/");

      // If name given, open directly
      if (name) {
        return { parentDir, conf, target: name, secondaries: [] as string[] };
      }

      // Check if in secondary worktree
      const currentRoot = await clients.git.repoRoot();
      if (currentRoot && currentRoot !== main) {
        const currentName = currentRoot.split("/").pop() ?? "";
        return {
          parentDir,
          conf,
          target: currentName,
          secondaries: [] as string[],
        };
      }

      // List secondary worktrees for picker
      const worktrees = await clients.git.worktreeList();
      const secs = R.pipe(
        worktrees,
        R.filter((wt) => wt.path !== main),
        R.map((wt) => wt.path.split("/").pop() ?? ""),
      );

      if (secs.length === 0) {
        return { parentDir, conf, target: null, secondaries: [] as string[] };
      }

      return { parentDir, conf, target: null, secondaries: secs };
    },
  });

  const doOpen = async (wtName: string, parentDir: string, conf: ConfigValues) => {
    setPhase("opening");
    const wtPath = `${parentDir}/${wtName}`;
    const ed = editorOverride ?? conf.editor ?? "code";

    if (flagCd) {
      setMessage(`cd ${wtPath}`);
      setPhase("done");
      setTimeout(exit, 100);
      return;
    }

    await clients.editor.open(wtPath, ed as EditorKey);
    const edName = editorDisplayName(ed as EditorKey);
    setMessage(`Opened ${wtName} in ${edName}`);
    setPhase("done");
    setTimeout(exit, 100);
  };

  // No secondary worktrees
  if (data.target === null && data.secondaries.length === 0) {
    setTimeout(exit, 100);
    return (
      <StatusMessage variant="success">
        <Text>No secondary worktrees found. Create one with: wt create</Text>
      </StatusMessage>
    );
  }

  // Direct open (name given or in secondary worktree)
  if (data.target && phase === "picking") {
    void doOpen(data.target, data.parentDir, data.conf);
    return <Spinner label={`Opening ${data.target}…`} />;
  }

  if (phase === "opening") {
    return <Spinner label="Opening…" />;
  }

  if (phase === "done") {
    return (
      <StatusMessage variant="success">
        <Text>{message}</Text>
      </StatusMessage>
    );
  }

  // Picker
  return (
    <Select
      onSubmit={(value) => {
        void doOpen(value as string, data.parentDir, data.conf);
      }}
    >
      {data.secondaries.map((s) => (
        <Select.Option key={s} value={s}>
          {s}
        </Select.Option>
      ))}
    </Select>
  );
}

command.registerComponent(Open);
