#!/usr/bin/env bun

import type React from "react";

import { Command } from "commander";

import RealApp from "#/App.js";
import { commandRegistry, PROGRAM_DESCRIPTION, setupCommand, setupCommands } from "#/cli-setup.js";
import { FakeConfigClient, RealConfigClient } from "#/clients/config.js";
import { FakeEditorClient, RealEditorClient } from "#/clients/editor.js";
import { FakeGhClient, RealGhClient } from "#/clients/gh.js";
import { FakeGitClient, RealGitClient } from "#/clients/git.js";
import { FakeGtClient, RealGtClient } from "#/clients/gt.js";
import { command as indexCmd } from "#/commands/index.js";
import "#/commands/_all.js";

const isDev = Bun.env.NODE_ENV === "development";

const gitClient = isDev ? new FakeGitClient() : new RealGitClient();
const configClient = isDev ? new FakeConfigClient() : new RealConfigClient({ git: gitClient });
const ghClient = isDev ? new FakeGhClient() : new RealGhClient(gitClient);
const gtClient = isDev ? new FakeGtClient() : new RealGtClient();
const editorClient = isDev ? new FakeEditorClient() : new RealEditorClient();

const AppWrapper = (props: Record<string, unknown>) => {
  const Component = props.Component as React.ComponentType<Record<string, unknown>>;
  const commandProps = props.commandProps as Record<string, unknown>;
  return (
    <RealApp
      Component={Component}
      commandProps={commandProps}
      config={configClient}
      editor={editorClient}
      gh={ghClient}
      git={gitClient}
      gt={gtClient}
    />
  );
};

const program = new Command();
const BareWrapper = (props: Record<string, unknown>) => {
  const Component = props.Component as React.ComponentType<Record<string, unknown>>;
  const commandProps = props.commandProps as Record<string, unknown>;
  return <Component {...commandProps} />;
};

setupCommand(program, indexCmd, BareWrapper);
setupCommands(program, commandRegistry, AppWrapper);

program.name("wt");
program.version("0.1.0", "-v, --version", "Show version number");
program.description(PROGRAM_DESCRIPTION);

program.helpOption("-h, --help", "Show help");

// When no subcommand is present, strip --help/-h so our custom Index component
// renders instead of Commander's default help text.
const subcommandNames = new Set([...commandRegistry.keys(), "help"]);
const hasSubcommand = Bun.argv.slice(2).some((a) => subcommandNames.has(a));
program.parse(hasSubcommand ? Bun.argv : Bun.argv.filter((a) => a !== "--help" && a !== "-h"));
