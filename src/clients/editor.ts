import * as R from "remeda";

export const EDITORS = {
  code: { command: "code", name: "VS Code", settingsDir: ".vscode" },
  cursor: { command: "cursor", name: "Cursor", settingsDir: ".vscode" },
  windsurf: { command: "windsurf", name: "Windsurf", settingsDir: ".vscode" },
} as const;

export type EditorKey = keyof typeof EDITORS;

type EditorInfo = (typeof EDITORS)[EditorKey];

export const EDITOR_THEMES = [
  "Solarized Dark",
  "Abyss",
  "Kimbie Dark",
  "Quiet Light",
  "Monokai",
  "Tomorrow Night Blue",
  "Red",
  "Solarized Light",
  "Monokai Dimmed",
];

const THEME_RE = /"workbench\.colorTheme"\s*:\s*"([^"]*)"/;
const THEME_REPLACE_RE = /("workbench\.colorTheme"\s*:\s*)"[^"]*"/;
const SETTINGS_BLOCK_RE = /"settings"\s*:\s*\{/;
const SETTINGS_BLOCK_CAPTURE_RE = /("settings"\s*:\s*\{)/;
const FIRST_BRACE_RE = /(\{)/;

export const editorDisplayName = (editor: EditorKey): string => {
  return EDITORS[editor].name;
};

export interface EditorClient {
  getDisplayName(editor: EditorKey): string;
  getInstalledEditors(): Promise<EditorInfo[]>;
  isInstalled(editor: EditorKey): Promise<boolean>;
  nextTheme(mainWt: string, parentDir: string): Promise<string>;
  open(path: string, editor: EditorKey, opts?: { newWindow?: boolean }): Promise<void>;
  readThemeFromFile(filePath: string): Promise<string | null>;
  setTheme(wtPath: string, theme: string, editor?: string): Promise<void>;
  setThemeInFile(filePath: string, theme: string): Promise<void>;
}

export class RealEditorClient implements EditorClient {
  getDisplayName(editor: EditorKey): string {
    return EDITORS[editor].name;
  }

  async getInstalledEditors(): Promise<EditorInfo[]> {
    const editors = R.keys(EDITORS);
    const installedEditors = await Promise.all(
      editors.map((editor) => this.isInstalled(editor)),
    ).then((results) =>
      editors.filter((_, index) => results[index]).map((editor) => EDITORS[editor]),
    );

    return installedEditors;
  }

  async isInstalled(editor: string): Promise<boolean> {
    try {
      const proc = Bun.spawn(["which", editor], {
        stdout: "pipe",
        stderr: "pipe",
      });
      const exitCode = await proc.exited;
      return exitCode === 0;
    } catch {
      return false;
    }
  }

  async open(path: string, editor: EditorKey, opts?: { newWindow?: boolean }): Promise<void> {
    const args: string[] = [editor];
    if (opts?.newWindow !== false) {
      args.push("-n");
    }
    args.push(path);
    const proc = Bun.spawn(args, { stdout: "ignore", stderr: "pipe" });
    const exitCode = await proc.exited;
    if (exitCode !== 0) {
      throw new Error(`${editor} exited with code ${exitCode}`);
    }
  }

  async readThemeFromFile(filePath: string): Promise<string | null> {
    try {
      const file = Bun.file(filePath);
      if (!(await file.exists())) {
        return null;
      }
      const text = await file.text();
      const match = text.match(THEME_RE);
      return match?.[1] ?? null;
    } catch {
      return null;
    }
  }

  async setThemeInFile(filePath: string, theme: string): Promise<void> {
    try {
      const file = Bun.file(filePath);
      let text: string;
      if (await file.exists()) {
        text = await file.text();
      } else {
        text = "{}";
      }

      if (text.includes('"workbench.colorTheme"')) {
        text = text.replace(THEME_REPLACE_RE, `$1"${theme}"`);
      } else if (SETTINGS_BLOCK_RE.test(text)) {
        text = text.replace(
          SETTINGS_BLOCK_CAPTURE_RE,
          `$1\n    "workbench.colorTheme": "${theme}",`,
        );
      } else {
        text = text.replace(FIRST_BRACE_RE, `$1\n    "workbench.colorTheme": "${theme}",`);
      }

      await Bun.write(filePath, text);
    } catch {
      // best effort
    }
  }

  async nextTheme(mainWt: string, parentDir: string): Promise<string> {
    const usedThemes = new Set<string>();

    try {
      const entries = Array.from(new Bun.Glob("*").scanSync({ cwd: parentDir, onlyFiles: false }));
      const settingsDirs = Object.values(EDITORS).map((e) => e.settingsDir);
      for (const entry of entries) {
        const wtPath = `${parentDir}/${entry}`;
        if (wtPath === mainWt) {
          continue;
        }
        for (const dir of settingsDirs) {
          const theme = await this.readThemeFromFile(`${wtPath}/${dir}/settings.json`);
          if (theme) {
            usedThemes.add(theme);
            break;
          }
        }
      }
    } catch {
      // ignore
    }

    for (const theme of EDITOR_THEMES) {
      if (!usedThemes.has(theme)) {
        return theme;
      }
    }

    return EDITOR_THEMES[0] ?? "";
  }

  async setTheme(wtPath: string, theme: string, editor = "code"): Promise<void> {
    const settingsDir = EDITORS[editor as EditorKey]?.settingsDir ?? ".vscode";
    const dir = `${wtPath}/${settingsDir}`;
    const filePath = `${dir}/settings.json`;

    await Bun.spawn(["mkdir", "-p", dir]).exited;

    const file = Bun.file(filePath);
    if (!(await file.exists())) {
      await Bun.write(filePath, "{}\n");
    }

    await this.setThemeInFile(filePath, theme);
  }
}

export class FakeEditorClient implements EditorClient {
  getDisplayName(editor: EditorKey): string {
    return EDITORS[editor].name;
  }

  getInstalledEditors() {
    return Promise.resolve([EDITORS.code, EDITORS.cursor]);
  }

  isInstalled() {
    return Promise.resolve(true);
  }

  open() {
    return Promise.resolve();
  }

  readThemeFromFile() {
    return Promise.resolve(null);
  }

  setThemeInFile() {
    return Promise.resolve();
  }

  nextTheme() {
    return Promise.resolve(EDITOR_THEMES[0] ?? "");
  }

  setTheme() {
    return Promise.resolve();
  }
}
