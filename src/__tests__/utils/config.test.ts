import { mkdtemp } from "#/__tests__/helpers.js";
import { type ConfigValues, RealConfigClient } from "#/clients/config.js";
import { FakeGitClient } from "#/clients/git.js";

import { afterEach, beforeAll, beforeEach, describe, expect, it } from "bun:test";

const git = new FakeGitClient();

/** A RealConfigClient whose path() is overridden to a fixed location. */
class TestConfigClient extends RealConfigClient {
  private fixedPath: string;

  constructor(path: string) {
    super({ git });
    this.fixedPath = path;
  }

  setPath(path: string) {
    this.fixedPath = path;
  }

  override path() {
    return Promise.resolve(this.fixedPath);
  }
}

let defaults: ConfigValues;
let client: TestConfigClient;

beforeAll(async () => {
  client = new TestConfigClient("/tmp/init.json");
  // @ts-ignore -- TODO
  defaults = await client.defaults();
});

describe("ConfigClient.defaults", () => {
  it("resolves defaults with git-derived values", () => {
    expect(defaults.useGraphite).toBe("no");
    expect(defaults.onCreateAction).toBe("ask");
    expect(defaults.worktreeDir).toBeTruthy();
    expect(defaults.branchStart).toBeTruthy();
  });
});

describe("ConfigClient.serialize", () => {
  it("round-trips config", async () => {
    const cfg: ConfigValues = {
      ...defaults,
      editor: "cursor",
      branchStart: "develop",
    };

    await client.write(cfg);
    const readBack = await client.read();
    expect(readBack).toEqual(cfg);
  });

  it("handles defaults", async () => {
    await client.write(defaults);
    const readBack = await client.read();
    expect(readBack).toEqual(defaults);
  });
});

describe("config.read / config.write", () => {
  let tmpDir: string;
  let testClient: TestConfigClient;

  beforeEach(async () => {
    tmpDir = await mkdtemp("wt-test-");
    testClient = new TestConfigClient(`${tmpDir}/test.json`);
  });

  afterEach(() => {
    Bun.spawn(["rm", "-rf", tmpDir]);
  });

  it("returns defaults for missing file", async () => {
    testClient.setPath(`${tmpDir}/nonexistent.json`);
    const result = await testClient.read();
    expect(result).toEqual(defaults);
  });

  it("reads existing config file", async () => {
    const path = `${tmpDir}/test.json`;
    await Bun.write(path, JSON.stringify({ editor: "code", theming: "on" }));

    const result = await testClient.read();
    expect(result.editor).toBe("code");
    expect(result.theming).toBe("on");
    expect(result.branchStart).toBe(defaults.branchStart);
  });

  it("writes config file", async () => {
    const cfg: ConfigValues = {
      ...defaults,
      editor: "cursor",
      branchStart: "develop",
    };

    await testClient.write(cfg);

    const readResult = await testClient.read();
    expect(readResult).toEqual(cfg);
  });

  it("creates directories as needed", async () => {
    const path = `${tmpDir}/sub/dir/test.json`;
    testClient.setPath(path);

    await testClient.write(defaults);
    expect(await Bun.file(path).exists()).toBe(true);
  });
});

describe("config.setValue", () => {
  let tmpDir: string;
  let testClient: TestConfigClient;

  beforeEach(async () => {
    tmpDir = await mkdtemp("wt-test-");
    testClient = new TestConfigClient(`${tmpDir}/test.json`);
  });

  afterEach(() => {
    Bun.spawn(["rm", "-rf", tmpDir]);
  });

  it("creates new config file with value", async () => {
    await testClient.setValue("editor", "cursor");

    const result = await testClient.read();
    expect(result.editor).toBe("cursor");
  });

  it("updates existing value", async () => {
    await Bun.write(
      `${tmpDir}/test.json`,
      JSON.stringify({ editor: "code", branchStart: "develop" }),
    );

    await testClient.setValue("editor", "cursor");

    const result = await testClient.read();
    expect(result.editor).toBe("cursor");
    expect(result.branchStart).toBe("develop");
  });

  it("adds new key to existing config", async () => {
    await Bun.write(`${tmpDir}/test.json`, JSON.stringify({ editor: "code" }));

    await testClient.setValue("theming", "on");

    const result = await testClient.read();
    expect(result.editor).toBe("code");
    expect(result.theming).toBe("on");
  });
});
