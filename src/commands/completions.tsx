import React from "react";

import { Text, useApp } from "ink";

import { z } from "zod";

import type { CommandConfig, CommandDef, InferProps } from "#/cli-setup.js";
import {
  commandRegistry,
  formatArgs,
  formatOptions,
  registerCommand,
  worktreeCompleteIndices,
} from "#/cli-setup.js";

export const command = registerCommand({
  name: "completions",
  description: "generate shell completions",
  args: z.tuple([z.string().optional().describe("shell")]),
});

/** Escape single quotes for zsh completion strings. */
const zq = (s: string): string => s.replaceAll(/'/g, "'\\''");

/**
 * Build an `_arguments` spec entry for a single option.
 * e.g. `'(-e --editor)'{-e,--editor}'[Override editor]:editor:'`
 */
const formatZshOption = (opt: {
  short?: string;
  long: string;
  arg: string;
  description: string;
}): string => {
  const desc = zq(opt.description);

  if (opt.short) {
    const excl = `(${opt.short} ${opt.long})`;
    const flags = `${opt.short},${opt.long}`;
    const valuePart = opt.arg ? `:${zq(opt.arg)}:` : "";
    return `'${excl}'{${flags}}'[${desc}]${valuePart}'`;
  }

  const valuePart = opt.arg ? `:${zq(opt.arg)}:` : "";
  return `'${opt.long}[${desc}]${valuePart}'`;
};

const generateZshCompletion = (cmds: Map<string, CommandDef>): string => {
  // --- Subcommand list ---
  const subcmdLines: string[] = [];
  for (const [name, def] of cmds) {
    subcmdLines.push(`                '${zq(name)}:${zq(def.description ?? "")}'`);
    if (def.alias) {
      subcmdLines.push(`                '${zq(def.alias)}:Shorthand for ${zq(name)}'`);
    }
  }

  // --- Per-command case arms ---
  const caseArms: string[] = [];
  for (const [name, def] of cmds) {
    const config = def as CommandConfig;
    if (!(config.options || config.args)) {
      continue;
    }

    const pattern = config.alias ? `${name}|${config.alias}` : name;
    const argSpecs: string[] = [];

    // Options
    if (config.options) {
      const opts = formatOptions(config.options, config.shortFlags);
      for (const opt of opts) {
        argSpecs.push(`                        ${formatZshOption(opt)}`);
      }
    }

    // Positional args
    if (config.args) {
      const argNames = formatArgs(config.args);
      const worktreeIndices = worktreeCompleteIndices(config.args);
      for (let i = 0; i < argNames.length; i++) {
        const argName = argNames[i] ?? "arg";
        const pos = i + 1;
        const action = worktreeIndices.has(i) ? ":_wt_complete_worktrees" : ":";
        argSpecs.push(`                        '${pos}::${zq(argName)}${action}'`);
      }
    }

    caseArms.push(
      `                ${pattern})\n                    _arguments \\\n${argSpecs.join(" \\\n")}\n                    ;;`,
    );
  }

  const argsCase =
    caseArms.length > 0
      ? `        args)\n            case "\${line[1]}" in\n${caseArms.join("\n")}\n            esac\n            ;;`
      : "";

  return `#compdef wt

_wt_completion() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \\
        '1: :->subcmd' \\
        '*:: :->args' \\
        && return 0

    case $state in
        subcmd)
            local -a subcmds=(
${subcmdLines.join("\n")}
            )
            _describe -t commands 'subcommand' subcmds
            ;;
${argsCase}
    esac
}

_wt_complete_worktrees() {
    local main_wt
    main_wt=$(git worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')
    if [[ -n "$main_wt" ]]; then
        local -a wts
        local wp pline
        while IFS= read -r pline; do
            case "$pline" in
                worktree\\ *)
                    wp="\${pline#worktree }"
                    [[ "$wp" != "$main_wt" ]] && wts+=("$(basename "$wp")")
                    ;;
            esac
        done < <(git worktree list --porcelain 2>/dev/null)
        _describe -t worktrees 'worktree' wts
    fi
}

compdef _wt_completion wt`;
};

export default function Completions(props: InferProps<typeof command>) {
  const shell = props.args?.[0] ?? "zsh";
  const { exit } = useApp();

  React.useEffect(() => {
    exit();
  }, [exit]);

  if (shell !== "zsh") {
    return <Text color="red">{"  "}Only zsh completions are supported.</Text>;
  }

  return <Text>{generateZshCompletion(commandRegistry)}</Text>;
}

command.registerComponent(Completions);
