import * as R from "remeda";
import { z } from "zod";

import { SYNC_CATEGORY_KEYS } from "#/constants";
import { cached } from "#/utils/cached.js";

import { EDITORS } from "./editor.js";
import type { GitClient } from "./git.js";

export const configSchema = z.object({
  worktreeDir: z.string().nonempty(),
  branchStart: z.string().nonempty(),
  useGraphite: z.literal(["yes", "no"]),
  depDirsSelected: z.array(z.string()),
  editor: z.literal(R.keys(EDITORS)),
  ignoredFileCategories: z.array(z.literal(SYNC_CATEGORY_KEYS)),
  theming: z.literal(["on", "off"]),
  workspaces: z.array(z.string()),
  defaultWorkspace: z.string(),
  onCreateAction: z.literal(["ask", "cd", "editor", "nothing"]),
});

export type ConfigValues = z.infer<typeof configSchema>;
export type ConfigKey = keyof ConfigValues;

export const configDefaults = {
  useGraphite: "no",
  depDirsSelected: ["."],
  editor: "code",
  ignoredFileCategories: ["config"],
  theming: "off",
  workspaces: [],
  defaultWorkspace: "",
  onCreateAction: "ask",
} satisfies Omit<ConfigValues, "worktreeDir" | "branchStart">;

export interface ConfigClient {
  path(): Promise<string>;
  read(): Promise<ConfigValues>;
  setValue(key: string, value: string): Promise<void>;
  write(config: ConfigValues): Promise<void>;
}

export class RealConfigClient implements ConfigClient {
  private readonly git: GitClient;

  constructor({ git }: { git: GitClient }) {
    this.git = git;
  }

  dir(): string {
    const home = process.env.HOME ?? process.env.USERPROFILE ?? "~";
    return `${home}/.config/wt`;
  }

  async path(): Promise<string> {
    const mainWorktree = await this.git.mainWorktree();
    const name = mainWorktree.split("/").pop() ?? mainWorktree;
    const home = process.env.HOME ?? process.env.USERPROFILE ?? "~";
    const dir = `${home}/.config/wt`;
    return `${dir}/${name}.json`;
  }

  private defaults = cached(async () => {
    const [mainWt, defaultBranch] = await Promise.all([
      this.git.mainWorktree(),
      this.git.defaultBranch(),
    ]);
    return {
      ...configDefaults,
      worktreeDir: mainWt.split("/").slice(0, -1).join("/"),
      branchStart: defaultBranch,
    } as ConfigValues;
  });

  private codec = cached(async () => {
    const defaults = await this.defaults();
    return z.codec(z.string(), configSchema, {
      decode: (s) => ({ ...defaults, ...JSON.parse(s) }),
      encode: (v) => JSON.stringify(v, null, 2),
    });
  });

  async read() {
    const path = await this.path();
    if (!(await Bun.file(path).exists())) {
      const defaults = await this.defaults();
      await this.write(defaults);
      return defaults;
    }
    const content = await Bun.file(path).text();
    return (await this.codec()).decode(content);
  }

  async write(config: ConfigValues) {
    const path = await this.path();
    const dir = path.substring(0, path.lastIndexOf("/"));
    if (!(await Bun.file(dir).exists())) {
      await Bun.spawn(["mkdir", "-p", dir]).exited;
    }
    await Bun.write(path, `${(await this.codec()).encode(config)}\n`);
  }

  async setValue(key: string, value: string) {
    const path = await this.path();
    const dir = path.substring(0, path.lastIndexOf("/"));
    if (!(await Bun.file(dir).exists())) {
      await Bun.spawn(["mkdir", "-p", dir]).exited;
    }
    let config = await this.defaults();
    if (await Bun.file(path).exists()) {
      const content = await Bun.file(path).text();
      config = (await this.codec()).decode(content);
    }
    await this.write({ ...config, [key]: value });
  }
}

const fakeDefaults: ConfigValues = {
  ...configDefaults,
  worktreeDir: "/tmp/fake-wt",
  branchStart: "main",
};

export class FakeConfigClient implements ConfigClient {
  private readonly tmpDir = "./tmp/.config/wt";

  private defaults = cached(async () => fakeDefaults);

  private codec = cached(async () => {
    const defaults = await this.defaults();
    return z.codec(z.string(), configSchema, {
      decode: (s) => ({ ...defaults, ...JSON.parse(s) }),
      encode: (v) => JSON.stringify(v, null, 2),
    });
  });

  async path(): Promise<string> {
    return Promise.resolve(`${this.tmpDir}/repo.json`);
  }

  async read(): Promise<ConfigValues> {
    if (!(await Bun.file(await this.path()).exists())) {
      await this.write(fakeDefaults);
      return fakeDefaults;
    }
    const content = await Bun.file(await this.path()).text();
    return (await this.codec()).decode(content);
  }

  async write(config: ConfigValues): Promise<void> {
    await Bun.spawn(["mkdir", "-p", this.tmpDir]).exited;
    await Bun.write(await this.path(), `${(await this.codec()).encode(config)}\n`);
  }

  async setValue(key: string, value: string): Promise<void> {
    let config: ConfigValues = fakeDefaults;
    if (await Bun.file(await this.path()).exists()) {
      const content = await Bun.file(await this.path()).text();
      config = (await this.codec()).decode(content);
    }
    await this.write({ ...config, [key]: value });
  }
}
