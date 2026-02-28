import { Suspense } from "react";

import { Spinner } from "@inkjs/ui";
import { Box, Text } from "ink";

import { useQuery, useSuspenseQuery } from "@tanstack/react-query";
import { Typewriter } from "ink-motion";
import * as R from "remeda";

import { registerCommand } from "#/cli-setup.js";
import { configSchema } from "#/clients/config.js";
import { Banner } from "#/components/Banner.js";
import { useWizardForm } from "#/components/Wizard";
import { SYNC_CATEGORIES, SYNC_CATEGORY_KEYS } from "#/constants.js";
import { useCli } from "#/hooks/useCli.js";
import { findDepDirs } from "#/utils/lockfiles.js";
import { findWorkspaceFiles } from "#/utils/workspace";

export const command = registerCommand({
  name: "init",
  alias: "i",
  description: "configure worktree creation for current repo",
});

export default function Init() {
  const { clients } = useCli();
  const { data: repoName } = useQuery({
    queryKey: ["init", "repoName"],
    queryFn: async () => {
      const mainWt = await clients.git.mainWorktree();
      return mainWt.split("/").pop() ?? "";
    },
  });

  return (
    <Box flexDirection="column" gap={1} paddingY={1}>
      <Banner />
      <Box flexDirection="column" gap={1}>
        <Text bold>
          Setting up <Text color="yellow">wt</Text> for{" "}
          <Typewriter color="cyan">{repoName ?? ""}</Typewriter>
        </Text>
        <Suspense fallback={<Spinner label="Detecting project setup…" />}>
          <InitWizard />
        </Suspense>
      </Box>
    </Box>
  );
}

function InitWizard() {
  const { exit, clients } = useCli();

  const { data: baseData } = useSuspenseQuery({
    queryKey: ["init", "base"],
    queryFn: async () => {
      const [mainWt, config, configPath] = await Promise.all([
        clients.git.mainWorktree(),
        clients.config.read(),
        clients.config.path(),
      ]);
      return {
        mainWt,
        configPath,
        config,
        worktreeDir: mainWt.split("/").slice(0, -1).join("/"),
      };
    },
  });

  const { mainWt, configPath, worktreeDir, config } = baseData;

  const form = useWizardForm({
    defaultValues: config,
    validators: { onChange: configSchema },
    onSubmit: async ({ value }) => {
      await clients.config.write(value);
      exit();
    },
  });

  // TODO: consider something like Suspensive or a custom QueryLoader component for these secondary queries
  const { data: defaultBranch = "main" } = useQuery({
    queryKey: ["init", "defaultBranch", mainWt],
    queryFn: () => clients.git.defaultBranch(),
  });

  const { data: installedEditors = [] } = useQuery({
    queryKey: ["init", "installedEditors"],
    queryFn: () => clients.editor.getInstalledEditors(),
  });

  const { data: gtInstalled = false } = useQuery({
    queryKey: ["init", "gtInstalled"],
    queryFn: () => clients.gt.isInstalled(),
  });

  const { data: workspaceFiles = [] } = useQuery({
    queryKey: ["init", "workspaceFiles", mainWt],
    queryFn: () => findWorkspaceFiles(mainWt),
  });

  const { data: depDirs = [] } = useQuery({
    queryKey: ["init", "depDirs", mainWt],
    queryFn: () => findDepDirs(mainWt),
  });

  const { data: detectedIgnoredFileCategories = [] } = useQuery({
    queryKey: ["init", "ignoredFileCategories", mainWt],
    queryFn: () => clients.git.detectIgnoredFileCategories({ cwd: mainWt }),
  });

  return (
    <form.AppForm>
      <form.Wizard onCancel={() => setTimeout(exit, 100)}>
        <form.AppField
          name="worktreeDir"
          children={(field) => (
            <field.WizardStep title="Where should worktrees be created">
              <field.Select>
                <field.Select.Option value={worktreeDir}>
                  Sibling of repository <Text dimColor>({worktreeDir})</Text>
                </field.Select.Option>
                <field.Select.TextInput placeholder="Enter custom path…" />
              </field.Select>
            </field.WizardStep>
          )}
        />

        <form.AppField
          name="branchStart"
          children={(field) => (
            <field.WizardStep title="Default starting point for worktrees">
              <field.Select>
                <field.Select.Option value={defaultBranch}>
                  {defaultBranch} <Text dimColor>(default branch)</Text>
                </field.Select.Option>
                <field.Select.TextInput placeholder="Enter branch name…" />
              </field.Select>
            </field.WizardStep>
          )}
        />

        {gtInstalled && (
          <form.AppField
            name="useGraphite"
            children={(field) => (
              <field.WizardStep title="Use Graphite for branch creation">
                <field.Select>
                  <field.Select.Option value="no">No</field.Select.Option>
                  <field.Select.Option value="yes">Yes</field.Select.Option>
                </field.Select>
              </field.WizardStep>
            )}
          />
        )}

        {installedEditors.length > 0 && (
          <form.AppField
            name="editor"
            children={(field) => (
              <field.WizardStep title="Select editor to open worktrees in">
                <field.Select>
                  {installedEditors.map(({ command, name }) => (
                    <field.Select.Option key={command} value={command}>
                      {name}
                    </field.Select.Option>
                  ))}
                </field.Select>
              </field.WizardStep>
            )}
          />
        )}

        {workspaceFiles.length > 1 && (
          <form.AppField
            name="workspaces"
            children={(field) => (
              <field.WizardStep title="Select workspace files">
                <field.Select selectionMode="multiple">
                  {workspaceFiles.map((file) => (
                    <field.Select.Option key={file} value={file}>
                      {file}
                    </field.Select.Option>
                  ))}
                </field.Select>
              </field.WizardStep>
            )}
          />
        )}

        {depDirs.length > 1 && (
          <form.AppField
            name="depDirsSelected"
            children={(field) => (
              <field.WizardStep title="Directories to install dependencies for">
                <field.Select selectionMode="multiple">
                  {depDirs.map(({ dir, commands }) => (
                    <field.Select.Option key={dir} value={dir}>
                      {dir} <Text dimColor>{commands.join(", ")}</Text>
                    </field.Select.Option>
                  ))}
                </field.Select>
              </field.WizardStep>
            )}
          />
        )}

        {detectedIgnoredFileCategories.length > 0 && (
          <form.AppField
            name="ignoredFileCategories"
            children={(field) => (
              <field.WizardStep title="gitignored files to sync">
                <field.Select selectionMode="multiple">
                  {R.pipe(
                    detectedIgnoredFileCategories,
                    R.sortBy((key) => SYNC_CATEGORY_KEYS.indexOf(key)),
                    R.map((key) => [key, SYNC_CATEGORIES[key]] as const),
                    R.map(([key, category]) => (
                      <field.Select.Option
                        key={key}
                        value={key}
                        disabled={category.default === "fixed"}
                      >
                        {category.label}{" "}
                        {!!category.description && <Text dimColor>({category.description})</Text>}
                      </field.Select.Option>
                    )),
                  )}
                </field.Select>
              </field.WizardStep>
            )}
          />
        )}

        <form.AppField
          name="theming"
          children={(field) => (
            <field.WizardStep title="Enable editor theming">
              <field.Select>
                <field.Select.Option value="on">
                  Yes — assign a unique color theme to each worktree
                </field.Select.Option>
                <field.Select.Option value="off">No — skip theming</field.Select.Option>
              </field.Select>
            </field.WizardStep>
          )}
        />

        <form.AppField
          name="onCreateAction"
          children={(field) => (
            <field.WizardStep title="After creating a worktree">
              <form.Subscribe
                selector={(s) => s.values.editor}
                children={(editor) => (
                  <field.Select>
                    <field.Select.Option value="ask">Ask every time</field.Select.Option>
                    {editor && (
                      <field.Select.Option value="editor">
                        Open in {clients.editor.getDisplayName(editor)}
                      </field.Select.Option>
                    )}
                    <field.Select.Option value="cd">cd into worktree</field.Select.Option>
                    <field.Select.Option value="nothing">Do nothing</field.Select.Option>
                  </field.Select>
                )}
              />
            </field.WizardStep>
          )}
        />

        {workspaceFiles.length > 1 && (
          <form.AppField
            name="defaultWorkspace"
            children={(field) => (
              <field.WizardStep title="Default workspace to open">
                <form.Subscribe
                  selector={(s) => s.values.workspaces}
                  children={(workspaces) => (
                    <field.Select>
                      <field.Select.Option value="ask">Ask every time</field.Select.Option>
                      {workspaces.map((ws: string) => (
                        <field.Select.Option key={ws} value={ws}>
                          {ws.replace(".code-workspace", "")}
                        </field.Select.Option>
                      ))}
                    </field.Select>
                  )}
                />
              </field.WizardStep>
            )}
          />
        )}

        <form.PostCompletionStep>
          <Text color="green">Done! Config saved to {configPath}</Text>
        </form.PostCompletionStep>
      </form.Wizard>
    </form.AppForm>
  );
}

command.registerComponent(Init);
