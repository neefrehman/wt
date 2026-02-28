import { mkdtemp } from "#/__tests__/helpers.js";
import { EDITOR_THEMES, RealEditorClient } from "#/clients/editor.js";

import { describe, expect, test } from "bun:test";

const FIRST_THEME = EDITOR_THEMES.at(0) ?? "";
const SECOND_THEME = EDITOR_THEMES.at(1) ?? "";
const editorClient = new RealEditorClient();

describe("readThemeFromFileAsync", () => {
  test("reads theme from settings.json", async () => {
    const dir = await mkdtemp("wt-theme-");
    const file = `${dir}/settings.json`;
    await Bun.write(file, '{\n  "workbench.colorTheme": "One Dark Pro"\n}');
    expect(await editorClient.readThemeFromFile(file)).toBe("One Dark Pro");
  });

  test("returns null for missing file", async () => {
    expect(await editorClient.readThemeFromFile("/nonexistent/settings.json")).toBeNull();
  });

  test("returns null when no theme key", async () => {
    const dir = await mkdtemp("wt-theme-");
    const file = `${dir}/settings.json`;
    await Bun.write(file, '{\n  "editor.fontSize": 14\n}');
    expect(await editorClient.readThemeFromFile(file)).toBeNull();
  });
});

describe("setThemeInFile", () => {
  test("sets theme in empty JSON", async () => {
    const dir = await mkdtemp("wt-theme-");
    const file = `${dir}/settings.json`;
    await Bun.write(file, "{}");
    await editorClient.setThemeInFile(file, "Dracula");
    const text = await Bun.file(file).text();
    expect(text).toContain('"workbench.colorTheme": "Dracula"');
  });

  test("replaces existing theme", async () => {
    const dir = await mkdtemp("wt-theme-");
    const file = `${dir}/settings.json`;
    await Bun.write(file, '{\n  "workbench.colorTheme": "Old Theme"\n}');
    await editorClient.setThemeInFile(file, "New Theme");
    const text = await Bun.file(file).text();
    expect(text).toContain('"workbench.colorTheme": "New Theme"');
    expect(text).not.toContain("Old Theme");
  });
});

describe("nextTheme", () => {
  test("returns first theme when no worktrees exist", async () => {
    const dir = await mkdtemp("wt-theme-");
    const mainWt = `${dir}/main`;
    await Bun.spawn(["mkdir", "-p", mainWt]).exited;
    const theme = await editorClient.nextTheme(mainWt, dir);
    expect(theme).toBe(FIRST_THEME);
  });

  test("skips themes already in use", async () => {
    const dir = await mkdtemp("wt-theme-");
    const mainWt = `${dir}/main`;
    await Bun.spawn(["mkdir", "-p", mainWt]).exited;

    // Create a worktree with the first theme
    const wt1 = `${dir}/wt1`;
    await Bun.spawn(["mkdir", "-p", `${wt1}/.vscode`]).exited;
    await Bun.write(`${wt1}/.vscode/settings.json`, `{"workbench.colorTheme": "${FIRST_THEME}"}`);

    const theme = await editorClient.nextTheme(mainWt, dir);
    expect(theme).toBe(SECOND_THEME);
  });
});
