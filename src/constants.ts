import * as R from "remeda";

// Lockfile → install command mapping. Order controls detection priority.
export const LOCKFILE_COMMANDS: Record<string, string> = {
  "pnpm-lock.yaml": "pnpm install",
  "yarn.lock": "yarn install",
  "bun.lock": "bun install",
  "bun.lockb": "bun install",
  "package-lock.json": "npm install",
  "uv.lock": "uv sync",
  "poetry.lock": "poetry install",
  "Pipfile.lock": "pipenv install",
  "Gemfile.lock": "bundle install",
  "go.sum": "go mod download",
  "Cargo.lock": "cargo fetch",
  "composer.lock": "composer install",
};

// Ordered lockfile names (detection priority)
export const LOCKFILE_NAMES = Object.keys(LOCKFILE_COMMANDS);

// Dependency directories (excluded from sync — installed separately)
export const DEP_DIRS = [
  "node_modules",
  ".venv",
  "venv",
  "__pycache__",
  ".tox",
  ".eggs",
  ".terraform",
  ".terragrunt-cache",
  "vendor",
];

// Config files/directories to sync
export const CONFIG_DIRS = [".claude", ".vscode", ".cursor", ".windsurf", ".idea"];
export const CONFIG_FILES = [
  "lefthook-local.yml",
  ".tool-versions",
  ".nvmrc",
  ".node-version",
  ".python-version",
  ".ruby-version",
  ".go-version",
];

// Build artifact directories
export const BUILD_DIRS = ["dist", "build", ".next", "out", "target"];

// Tool cache directories
export const CACHE_DIRS = [
  ".mypy_cache",
  ".ruff_cache",
  ".pytest_cache",
  ".import_linter_cache",
  ".cache",
];

// Noise files — excluded from sync operations
export const NOISE_FILES = [".DS_Store", ".tsbuildinfo", "CACHEDIR.TAG"];
export const NOISE_PATTERN =
  /(\\.DS_Store|\\.tsbuildinfo|next-env\\.d\\.ts|CACHEDIR\\.TAG|\\.gitignore|chromium-pack\\.tar)$/;

// Sync category definitions
export type SyncCategoryKey = "deps" | "dotenv" | "config" | "build" | "cache";

export interface SyncCategory {
  default: "on" | "off" | "fixed";
  description?: string;
  label: string;
}

export const SYNC_CATEGORIES: Record<SyncCategoryKey, SyncCategory> = {
  deps: {
    label: "Installed dependencies",
    description: "will be installed separately",
    default: "fixed",
  },
  dotenv: { label: "Dotenv files", default: "on" },
  config: {
    label: "Local config",
    description: "e.g. .claude/*, .vscode/*, lefthook-local.yml",
    default: "on",
  },
  build: {
    label: "Build artifacts",
    description: "e.g. .next, out",
    default: "off",
  },
  cache: {
    label: "Tool caches",
    description: "e.g. ruff_cache, import_linter_cache",
    default: "off",
  },
};

export const SYNC_CATEGORY_KEYS = R.keys(SYNC_CATEGORIES);
