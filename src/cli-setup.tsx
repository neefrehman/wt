import React from "react";

import { render, Text } from "ink";

import { Argument, Command, Option } from "commander";
import z, {
  ZodArray,
  ZodBoolean,
  ZodDefault,
  ZodEnum,
  ZodNumber,
  type ZodObject,
  ZodOptional,
  type ZodRawShape,
  ZodTuple,
} from "zod";

declare module "zod" {
  interface GlobalMeta {
    /** This argument support tab autocomplete for worktree names */
    worktreeComplete?: boolean;
  }
}

export interface CommandConfig<
  TOptions extends ZodRawShape = ZodRawShape,
  TArgs extends z.ZodType = z.ZodType,
> {
  alias?: string;
  args?: TArgs;
  component?: React.ComponentType<InferProps<CommandConfig<TOptions, TArgs>>>;
  description: string;
  name: string;
  options?: ZodObject<TOptions>;
  /** Set to `false` to skip auto-registration in the command registry. */
  register?: boolean;
  shortFlags?: Partial<Record<Extract<keyof TOptions, string>, string>>;
}

/** Derive component props from a command config's args and options schemas. */
export interface InferProps<T extends { args?: z.ZodType; options?: z.ZodType }> {
  args: z.output<NonNullable<T["args"]>>;
  options: z.output<NonNullable<T["options"]>>;
}

export type CommandInstance<
  TOptions extends ZodRawShape = ZodRawShape,
  TArgs extends z.ZodType = z.ZodType,
> = CommandConfig<TOptions, TArgs> & {
  registerComponent(
    component: React.ComponentType<InferProps<CommandConfig<TOptions, TArgs>>>,
  ): void;
};

export const PROGRAM_DESCRIPTION =
  "A configurable worktree management tool, with IDE workspace awareness";

export const commandRegistry = new Map<string, CommandDef>();

export const registerCommand = <TOptions extends ZodRawShape, TArgs extends z.ZodType>(
  config: CommandConfig<TOptions, TArgs>,
): CommandInstance<TOptions, TArgs> => {
  const instance = config as CommandInstance<TOptions, TArgs>;
  instance.registerComponent = (component) => {
    instance.component = component;
  };
  if (config.register !== false) {
    commandRegistry.set(config.name, instance as unknown as CommandDef);
  }
  return instance;
};

interface CommandDef {
  alias?: string;
  args?: z.ZodType;
  commands?: Map<string, CommandDef>;
  component?: unknown;
  description?: string;
  isDefault?: boolean;
  name: string;
  options?: ZodObject<ZodRawShape>;
  shortFlags?: Partial<Record<string, string>>;
}

/** Peel Optional → Default → Optional wrappers, returning the innermost schema. */
const unwrapSchema = (schema: z.ZodType): z.ZodType => {
  // Casts needed: Zod 4's $ZodType (returned by unwrap) is structurally
  // compatible with ZodType at runtime but not assignable at the type level.
  let inner: z.ZodType = schema;
  if (inner instanceof ZodOptional) {
    inner = inner.unwrap() as z.ZodType;
  }
  if (inner instanceof ZodDefault) {
    inner = inner.unwrap() as z.ZodType;
  }
  if (inner instanceof ZodOptional) {
    inner = inner.unwrap() as z.ZodType;
  }
  return inner;
};

const generateOptions = (
  schema: z.ZodType,
  shortFlags?: Partial<Record<string, string>>,
): Option[] => {
  const isOptionalByDefault = schema instanceof ZodOptional;
  const inner = unwrapSchema(schema);

  const options: Option[] = [];

  for (const [name, rawOptionSchema] of Object.entries((inner as ZodObject<ZodRawShape>).shape) as [
    string,
    unknown,
  ][]) {
    let defaultValue: unknown;
    let currentSchema = rawOptionSchema;
    const description: string = (currentSchema as { description?: string }).description ?? "";
    let isOptional = isOptionalByDefault;

    if (currentSchema instanceof ZodOptional) {
      isOptional = true;
      currentSchema = currentSchema.unwrap();
    }
    if (currentSchema instanceof ZodDefault) {
      isOptional = true;
      defaultValue = currentSchema.def.defaultValue;
      currentSchema = currentSchema.unwrap();
    }
    if (currentSchema instanceof ZodOptional) {
      isOptional = true;
      currentSchema = currentSchema.unwrap();
    }

    let flag = `--${name}`;
    if (currentSchema instanceof ZodBoolean && defaultValue === true) {
      flag = `--no-${name}`;
    }

    const short = shortFlags?.[name];
    if (short) {
      flag = `-${short}, ${flag}`;
    }

    const expectsValue = !(currentSchema instanceof ZodBoolean);
    if (expectsValue) {
      flag += isOptional || defaultValue ? ` [${name}]` : ` <${name}>`;
    }

    const option = new Option(flag, description);

    if (currentSchema instanceof ZodNumber) {
      option.argParser((value) => Number.parseFloat(value));
    }
    if (currentSchema instanceof ZodEnum) {
      option.choices(currentSchema.options as string[]);
    }
    if (currentSchema instanceof ZodBoolean && defaultValue === undefined) {
      defaultValue = false;
    }
    if (defaultValue !== undefined) {
      option.default(defaultValue);
    }

    options.push(option);
  }

  return options;
};

const generateArguments = (schema: z.ZodType): Argument[] => {
  const isOptionalByDefault = schema instanceof ZodOptional || schema instanceof ZodDefault;
  const inner = unwrapSchema(schema);

  const args: Argument[] = [];

  if (inner instanceof ZodTuple) {
    for (const rawArgSchema of inner.def.items) {
      let isOptional = isOptionalByDefault;
      let defaultValue: unknown;
      let currentSchema = rawArgSchema as unknown;
      let name: string = (currentSchema as { description?: string }).description ?? "arg";

      if (currentSchema instanceof ZodOptional) {
        isOptional = true;
        currentSchema = currentSchema.unwrap();
        name = (currentSchema as { description?: string }).description ?? name;
      }
      if (currentSchema instanceof ZodDefault) {
        isOptional = true;
        defaultValue = currentSchema.def.defaultValue;
        currentSchema = currentSchema.unwrap();
        name = (currentSchema as { description?: string }).description ?? name;
      }
      if (currentSchema instanceof ZodOptional) {
        isOptional = true;
        currentSchema = currentSchema.unwrap();
        name = (currentSchema as { description?: string }).description ?? name;
      }

      const argument = new Argument(isOptional ? `[${name}]` : `<${name}>`);

      if (currentSchema instanceof ZodNumber) {
        argument.argParser((value) => Number.parseFloat(value));
      }
      if (currentSchema instanceof ZodEnum) {
        argument.choices(currentSchema.options as string[]);
      }
      if (defaultValue !== undefined) {
        argument.default(defaultValue);
      }

      args.push(argument);
    }

    const restSchema = inner.def.rest;
    if (restSchema) {
      const name = (restSchema as { description?: string }).description ?? "arg";
      args.push(new Argument(`[${name}...]`));
    }
  }

  if (inner instanceof ZodArray) {
    const name = inner.description ?? "arg";
    args.push(new Argument(isOptionalByDefault ? `[${name}...]` : `<${name}...>`));
  }

  return args;
};

const renderValidationError = (error: unknown): never => {
  if (!(error instanceof z.ZodError)) {
    render(React.createElement(Text, { color: "red" }, "Invalid input"));
    process.exit(1);
  }
  render(React.createElement(Text, { color: "red" }, z.prettifyError(error)));
  process.exit(1);
};

export const setupCommand = (
  cmd: Command,
  def: CommandDef,
  appComponent: React.ComponentType<Record<string, unknown>>,
): void => {
  cmd.helpOption("-h, --help", "Show help");

  if (def.description) {
    cmd.description(def.description);
  }
  if (def.alias) {
    cmd.alias(def.alias);
  }

  if (def.options) {
    for (const option of generateOptions(def.options, def.shortFlags)) {
      cmd.addOption(option);
    }
  }

  let hasVariadicArgument = false;
  if (def.args) {
    for (const argument of generateArguments(def.args)) {
      if (argument.variadic) {
        hasVariadicArgument = true;
      }
      cmd.addArgument(argument);
    }
  }

  if (def.component) {
    cmd.action((...input: unknown[]) => {
      input.pop(); // Commander command instance
      const options = input.pop();

      let parsedOptions = {};
      if (def.options) {
        const result = def.options.safeParse(options);
        if (result.success) {
          parsedOptions = result.data ?? {};
        } else {
          renderValidationError(result.error);
        }
      }

      let parsedArgs: unknown[] = [];
      if (def.args) {
        const result = def.args.safeParse(hasVariadicArgument ? input.flat() : input);
        if (result.success) {
          parsedArgs = (result.data as unknown[]) ?? [];
        } else {
          renderValidationError(result.error);
        }
      }

      render(
        React.createElement(appComponent, {
          Component: def.component as React.ComponentType<Record<string, unknown>>,
          commandProps: {
            options: parsedOptions,
            args: parsedArgs,
          },
        }),
      );
    });
  }
};

export const setupCommands = (
  parent: Command,
  commands: Map<string, CommandDef>,
  appComponent: React.ComponentType<Record<string, unknown>>,
): void => {
  if (commands.size > 0) {
    parent.addHelpCommand(true);
  }

  for (const [name, def] of commands) {
    const sub = new Command(name);
    setupCommand(sub, def, appComponent);

    if (def.commands) {
      setupCommands(sub, def.commands, appComponent);
    }

    parent.addCommand(sub, { isDefault: def.isDefault });
  }
};

/** Extract arg display strings from a Zod tuple schema, e.g. `["[name]"]`. */
export const formatArgs = (schema: z.ZodType): string[] => {
  return generateArguments(schema).map((a) => a.name());
};

/** Return 0-based indices of tuple args whose innermost schema has `{ worktreeComplete: true }` in meta. */
export const worktreeCompleteIndices = (schema: z.ZodType): Set<number> => {
  const indices = new Set<number>();
  const inner = unwrapSchema(schema);

  if (inner instanceof ZodTuple) {
    for (let i = 0; i < inner.def.items.length; i++) {
      const item = inner.def.items[i] as z.ZodType | undefined;
      if (!item) {
        continue;
      }
      const s = unwrapSchema(item);
      if (s.meta()?.worktreeComplete) {
        indices.add(i);
      }
    }
  }
  return indices;
};

export interface OptionInfo {
  arg: string;
  description: string;
  long: string;
  short?: string;
}

/** Extract flag display info from a Zod object schema. */
export const formatOptions = (
  schema: z.ZodType,
  shortFlags?: Partial<Record<string, string>>,
): OptionInfo[] => {
  return generateOptions(schema, shortFlags).map((opt) => {
    const flags = opt.flags.split(", ");
    const last = flags.at(-1) ?? "";
    const short = flags.length > 1 ? flags[0] : undefined;

    // Separate the long flag name from its value placeholder
    const spaceIdx = last.indexOf(" ");
    const long = spaceIdx === -1 ? last : last.slice(0, spaceIdx);
    const arg = spaceIdx === -1 ? "" : last.slice(spaceIdx + 1);

    return { arg, description: opt.description, long, short };
  });
};

export type { CommandDef };
