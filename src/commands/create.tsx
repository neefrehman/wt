import { Suspense, useEffect } from "react";

import { Spinner, StatusMessage } from "@inkjs/ui";
import { Box, Text } from "ink";

import { useMutation, useSuspenseQuery } from "@tanstack/react-query";
import { z } from "zod";

import { type InferProps, registerCommand } from "#/cli-setup.js";
import type { ConfigValues } from "#/clients/config.js";
import { type EditorKey, editorDisplayName } from "#/clients/editor.js";
import { useWizardForm } from "#/components/Wizard.js";
import { useCli } from "#/hooks/useCli.js";
import { detectInstallCommandsAsync } from "#/utils/lockfiles.js";
import { nextWorktreeName, sanitizeBranchName, validateWorktreeName } from "#/utils/name.js";
import { syncGitignored } from "#/utils/sync-patterns.js";

export const command = registerCommand({
  name: "create",
  alias: "c",
  description: "create a worktree and optionally open it",
  args: z.tuple([z.string().optional().describe("name")]),
  options: z.object({
    from: z.string().optional().describe("Start branch from a specific ref"),
    pr: z.number().optional().describe("Create worktree from a GitHub PR"),
    checkout: z.string().optional().describe("Check out an existing branch"),
    editor: z.string().optional().describe("Override editor"),
    cd: z.boolean().default(false).describe("cd into the new worktree"),
    open: z.boolean().default(false).describe("Open in editor"),
    configure: z.boolean().default(false).describe("Run setup wizard for this worktree only"),
    stash: z.boolean().default(false).describe("Stash current changes and pop into new worktree"),
    execute: z.string().optional().describe("Run a command in the worktree after opening"),
    noPrompt: z.boolean().default(false).describe("Skip the post-create prompt entirely"),
    noInit: z.boolean().default(false).describe("Skip dependency install & theme setup"),
  }),
  shortFlags: {
    from: "f",
    pr: "p",
    checkout: "c",
    editor: "e",
    cd: "d",
    open: "o",
    configure: "C",
    stash: "s",
    execute: "x",
    noPrompt: "n",
    noInit: "N",
  },
});

type CreateOptions = InferProps<typeof command>["options"];

export default function Create(props: InferProps<typeof command>) {
  return (
    <Box flexDirection="column" gap={1} paddingY={1}>
      <Text bold>Creating worktree…</Text>
      <Suspense fallback={<Spinner label="Resolving…" />}>
        <CreateInner inputName={props.args?.[0]} opts={props.options ?? ({} as CreateOptions)} />
      </Suspense>
    </Box>
  );
}

interface BaseData {
  config: ConfigValues;
  hasChanges: boolean;
  mainWorktree: string;
  name: string;
  parentDir: string;
}

interface CreateResult {
  branchFrom: string;
  displayBranch: string;
  mode: "pr" | "checkout" | "new";
  shouldStash: boolean;
  wtPath: string;
}

function CreateInner({ inputName, opts }: { inputName?: string; opts: CreateOptions }) {
  const { exit, clients } = useCli();

  const { data } = useSuspenseQuery({
    queryKey: ["create", "base"],
    queryFn: async (): Promise<BaseData> => {
      const [config, mainWt, hasChanges] = await Promise.all([
        clients.config.read(),
        clients.git.mainWorktree(),
        clients.git.hasChanges(),
      ]);
      const parentDir = config.worktreeDir ?? mainWt.split("/").slice(0, -1).join("/");
      const name = inputName ?? nextWorktreeName(mainWt, parentDir);

      return {
        config,
        mainWorktree: mainWt,
        hasChanges,
        parentDir,
        name,
      };
    },
  });

  const editor = opts.editor ?? data.config.editor ?? "code";

  const syncFiles = useMutation({
    mutationFn: async () => {
      const { wtPath } = created;
      if (data.config.ignoredFileCategories?.length) {
        await syncGitignored(wtPath, data.mainWorktree, data.config, clients.git);
        return "Synced";
      }
      return "Skipped";
    },
  });

  const setTheme = useMutation({
    mutationFn: async () => {
      const { wtPath } = created;
      if (data.config.theming === "on") {
        const theme = await clients.editor.nextTheme(data.mainWorktree, data.parentDir);
        await clients.editor.setTheme(wtPath, theme, editor);
        return theme;
      }
      return "Skipped";
    },
  });

  const installDeps = useMutation({
    mutationFn: async () => {
      const { wtPath } = created;
      const depDirs = data.config.depDirsSelected;
      if (depDirs) {
        const dirs = depDirs.filter(Boolean);
        for (const dir of dirs) {
          const fullDir = dir === "." ? wtPath : `${wtPath}/${dir}`;
          const commands = await detectInstallCommandsAsync(fullDir);
          for (const cmd of commands) {
            const [bin = "", ...args] = cmd.split(" ");
            await Bun.spawn([bin, ...args], {
              cwd: fullDir,
              stdout: "pipe",
              stderr: "pipe",
            }).exited;
          }
        }
        return `Installed (${dirs.join(", ")})`;
      }
      return "Skipped";
    },
  });

  const finish = useMutation({
    mutationFn: async (shouldStash: boolean) => {
      const { wtPath } = created;
      if (shouldStash) {
        await clients.git.stashPop({ cwd: wtPath });
      }

      const onCreate = data.config.onCreateAction;
      if (opts.noPrompt || opts.cd || opts.open || (onCreate && onCreate !== "ask")) {
        if (opts.open || onCreate === "editor") {
          await clients.editor.open(wtPath, editor as EditorKey);
        }
        return "done" as const;
      }
      return "postCreate" as const;
    },
    onSuccess: (result) => {
      if (result === "done") {
        exit();
      }
    },
  });

  const createWorktree = useMutation({
    mutationFn: async (shouldStash: boolean): Promise<CreateResult> => {
      let exclusiveCount = 0;
      if (opts.pr) {
        exclusiveCount++;
      }
      if (opts.checkout) {
        exclusiveCount++;
      }
      if (opts.from) {
        exclusiveCount++;
      }
      if (exclusiveCount > 1) {
        throw new Error("--pr, --checkout, and --from are mutually exclusive");
      }

      const nameError = validateWorktreeName(data.name);
      if (nameError) {
        throw new Error(`Invalid name: ${nameError}`);
      }

      let name = data.name;
      let displayBranch = name;
      let branchFrom = "";
      let mode: CreateResult["mode"] = "new";

      const defaultBranch = await clients.git.defaultBranch();

      if (opts.pr) {
        mode = "pr";
        const prResult = await clients.gh.fetchPRBranch(opts.pr, data.mainWorktree);
        displayBranch = prResult.branch;
        branchFrom = `PR #${opts.pr}`;
        if (!inputName) {
          name = sanitizeBranchName(prResult.branch);
        }
      } else if (opts.checkout) {
        mode = "checkout";
        try {
          await clients.git.revParse(["--verify", `refs/heads/${opts.checkout}`], {
            cwd: data.mainWorktree,
          });
        } catch {
          await clients.git.fetchRef(opts.checkout, { cwd: data.mainWorktree });
          await clients.git.branchCreate(opts.checkout, `origin/${opts.checkout}`, {
            cwd: data.mainWorktree,
          });
        }
        displayBranch = opts.checkout;
        branchFrom = `origin/${opts.checkout}`;
        if (!inputName) {
          name = sanitizeBranchName(opts.checkout);
        }
      } else {
        const branchStart = data.config.branchStart ?? "main";
        branchFrom = opts.from ?? (branchStart === "main" ? defaultBranch : branchStart);
      }

      const wtPath = `${data.parentDir}/${name}`;

      if (shouldStash) {
        await clients.git.stashPush(`wt: stash for ${name}`);
      }

      if (opts.pr && displayBranch) {
        await clients.git.worktreeAdd(wtPath, displayBranch, {
          cwd: data.mainWorktree,
        });
      } else if (opts.checkout) {
        await clients.git.worktreeAdd(wtPath, opts.checkout, {
          cwd: data.mainWorktree,
        });
      } else {
        await clients.git.worktreeAdd(wtPath, name, {
          cwd: data.mainWorktree,
          newBranch: true,
          base: branchFrom,
        });
      }

      await clients.gt.trackBranch(branchFrom || defaultBranch, {
        cwd: wtPath,
      });

      return { wtPath, displayBranch, branchFrom, mode, shouldStash };
    },
    onSuccess: (result) => {
      if (opts.noInit) {
        finish.mutate(result.shouldStash);
        return;
      }
      syncFiles.mutate();
      setTheme.mutate();
      installDeps.mutate();
    },
  });

  // Shorthand for downstream mutations — only accessed after createWorktree succeeds
  const created = createWorktree.data as CreateResult;

  const needsStashPrompt = data.hasChanges && !opts.stash;

  const preCreateForm = useWizardForm({
    defaultValues: { stashAction: "yes" as "yes" | "no" },
    validators: { onChange: z.object({ stashAction: z.enum(["yes", "no"]) }) },
    onSubmit: ({ value }) => {
      createWorktree.mutate(value.stashAction === "yes");
    },
  });

  const postCreateForm = useWizardForm({
    defaultValues: { action: "open" as "open" | "cd" | "nothing" },
    validators: {
      onChange: z.object({ action: z.enum(["open", "cd", "nothing"]) }),
    },
    onSubmit: ({ value }) => {
      if (value.action === "open") {
        void clients.editor.open(created.wtPath, editor as EditorKey);
      }
      exit();
    },
  });

  // biome-ignore lint/correctness/useExhaustiveDependencies: auto-start on mount only
  useEffect(() => {
    if (!needsStashPrompt) {
      createWorktree.mutate(opts.stash && data.hasChanges);
    }
  }, []);

  const allInitDone = syncFiles.isSuccess && setTheme.isSuccess && installDeps.isSuccess;

  // biome-ignore lint/correctness/useExhaustiveDependencies: trigger finish once all init done
  useEffect(() => {
    if (allInitDone && finish.isIdle) {
      finish.mutate(created.shouldStash);
    }
  }, [allInitDone]);

  if (needsStashPrompt && createWorktree.isIdle) {
    return (
      <preCreateForm.AppForm>
        <preCreateForm.Wizard onCancel={exit}>
          <preCreateForm.AppField
            name="stashAction"
            children={(field) => (
              <field.WizardStep title="Stash uncommitted changes?">
                <field.Select>
                  <field.Select.Option value="yes">
                    Yes — stash and apply to new worktree
                  </field.Select.Option>
                  <field.Select.Option value="no">No — leave changes here</field.Select.Option>
                </field.Select>
              </field.WizardStep>
            )}
          />
        </preCreateForm.Wizard>
      </preCreateForm.AppForm>
    );
  }

  if (createWorktree.isPending || createWorktree.isIdle) {
    return <Spinner label={`Creating ${data.name}…`} />;
  }

  if (createWorktree.isError) {
    return <StatusMessage variant="error">{createWorktree.error.message}</StatusMessage>;
  }

  if (!finish.isSuccess) {
    return (
      <>
        {created.branchFrom ? (
          <StatusMessage variant="success">
            <Text>
              {created.mode === "new" ? "Created" : "Checked out"} branch{" "}
              <Text color="yellow">{created.displayBranch}</Text> from{" "}
              <Text color="cyan">{created.branchFrom}</Text>
            </Text>
          </StatusMessage>
        ) : (
          <StatusMessage variant="success">
            <Text>
              Created branch <Text color="yellow">{created.displayBranch}</Text>
            </Text>
          </StatusMessage>
        )}
        <Box flexDirection="column" gap={0}>
          {[
            { mutation: syncFiles, label: "Syncing gitignored files" },
            { mutation: setTheme, label: "Setting editor theme" },
            { mutation: installDeps, label: "Installing dependencies" },
          ].map(({ mutation: { isSuccess, data }, label }) => (
            <Box key={label}>
              {isSuccess ? <Text color="green">✓</Text> : <Spinner label="" />}
              <Text dimColor={isSuccess}> {label}</Text>
              {isSuccess && data && <Text dimColor> — {data}</Text>}
            </Box>
          ))}
        </Box>
      </>
    );
  }

  if (finish.data === "postCreate") {
    const edName = editorDisplayName(editor as EditorKey);
    return (
      <>
        <StatusMessage variant="success">
          <Text>
            Branch <Text color="yellow">{created.displayBranch}</Text> ready
          </Text>
        </StatusMessage>
        {syncFiles.data !== "Skipped" && (
          <StatusMessage variant="success">
            <Text>Synced</Text>
          </StatusMessage>
        )}
        {setTheme.data !== "Skipped" && (
          <StatusMessage variant="success">
            <Text>
              Theme: <Text color="yellow">{setTheme.data}</Text>
            </Text>
          </StatusMessage>
        )}
        {installDeps.data !== "Skipped" && (
          <StatusMessage variant="success">
            <Text>Dependencies installed</Text>
          </StatusMessage>
        )}
        <postCreateForm.AppForm>
          <postCreateForm.Wizard onCancel={exit}>
            <postCreateForm.AppField
              name="action"
              children={(field) => (
                <field.WizardStep title="What next?">
                  <field.Select>
                    <field.Select.Option value="open">Open in {edName}</field.Select.Option>
                    <field.Select.Option value="cd">cd into worktree</field.Select.Option>
                    <field.Select.Option value="nothing">Do nothing</field.Select.Option>
                  </field.Select>
                </field.WizardStep>
              )}
            />
          </postCreateForm.Wizard>
        </postCreateForm.AppForm>
      </>
    );
  }

  return (
    <StatusMessage variant="success">
      Worktree <Text color="yellow">{data.name}</Text> created
    </StatusMessage>
  );
}

command.registerComponent(Create);
