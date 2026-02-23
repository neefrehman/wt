```zsh
             .:;¦\¯`'¯`'¯\ :;/¯`'¯`;'/¦¦¯`'¯`'¯¦¦\¯`'¯`'¯\__
;/¯`'¯`'¯/¦.:;'¦;¦ -   --:;¦'/___:;/:;/  -  -.:;'/¦;¦__''__''¦
¦   -  .:;¦;'¦/¯\/    -.:;'/¦'¦¦`'¯`'`¦/     - ;/;'¦;¦.  '¯`¦¦
¦\   -  -:;\/;/\_____/:;¦¦L,  .:\__'___\ -:;'¦.:;/;¦L,__.:;'¦
¦:;\_____/:;¦¦¯`¯`'¦¦:;'¦  ¯¯¯;¦.     ;/    ¯¯¯¯¯
¦:;¦¦¯`'¯`'¦¦.:;;      ;¦;'/'     .:;¦;¦¦¯`'¯`'¦¦
;\;¦;      ;¦;/\L_ .:;'¦/'      .:;¦;¦;     :;¦
:;'¦L_ .:;'¦/'       ¯           .:;\¦L_  .:;¦
         ¯¯               '               ¯¯
```

# wt

A configurable Git worktree management tool for Zsh. Create, open, and delete worktrees with automatic dependency installation, editor theme differentiation, and gitignored file syncing.

![wt demo](public/demo.gif)

## Features

- 🌳 **One-command worktree creation**
- ⚙️ **Per-repo configuration**
- 🔀 **PR & branch checkout** — create worktree from a GitHub PR or existing branch/tag/commit
- 📦 **Workspace-aware** — auto-detects IDE workspaces to allow moving between them in a worktree
- 🔗 **Gitignored file syncing** — copies selected gitignored files (`.env`s`, build caches) from the main worktree
- 📥 **Dependency auto-install** — detects common package ecosystems and installs dependencies
- 🎨 **Easy differentiation** — each worktree gets an IDE theme to tell them apart at a glance, workspaces are renamed for easier scanning
- 🧹 **Stale worktree cleanup** — detect and delete worktrees whose branches have been merged or whose remote tracking branches are gone
- 📋 **Stash & move changes** — move uncommitted work to a new worktree automatically
- ⚡ **Parallel background tasks** — worktree initialization steps run concurrently, and are able to be completed in the background so you can start coding sooner

## Installation

```zsh
# Download
mkdir -p ~/.local/share/wt && curl -fsSL https://raw.githubusercontent.com/neefrehman/wt/main/wt.zsh -o ~/.local/share/wt/wt.zsh

# Add to your .zshrc
echo 'source ~/.local/share/wt/wt.zsh' >> ~/.zshrc
```

### Requirements

- **Zsh** (not Bash-compatible -- uses Zsh-specific features)
- **Git** with worktree support
- **Python 3** (used for theme manipulation and the ASCII banner)
- One or more of: `code` (VS Code), `cursor`, `windsurf`
- **`gh` CLI** (optional, required for `--pr`)

## Quick start

```zsh
wt init                          # wt i                    # configure wt behaviour for repo

wt create                        # wt c                    # create worktree/branch with autogened name
wt create feat/x --open          # wt c feat/x -o          # create named worktree/branch, open in IDE
wt create --from develop         # wt c -f develop         # create branch from ref
wt create --checkout feat/auth   # wt c -c feat/auth       # checkout feat/auth (do not create branch)
wt create --cd --pr 42           # wt c -d -p 42           # checkout GitHub PR, cd into worktree
wt create feat/x --stash         # wt c feat/x -s          # move uncommitted changes to new worktree
wt create feat/x --cd -x claude  # wt c feat/x -dx claude  # cd into created worktree and run claude

wt open                          # wt o                    # open worktree, or switch IDE workspace
wt open feat/x --open            # wt o feat/x -o          # open directly in IDE
wt open feat/x --cd              # wt o feat/x -d          # cd directly into worktree
wt open feat/x --cd -x claude    # wt o feat/x -dx claude  # cd into worktree and run claude

wt rename old new                # wt rn old new           # rename worktree
wt rename new                    # wt rn new               # rename current worktree

wt sync                          # wt s                    # re-sync gitignored files from main worktree
wt delete                        # wt d                    # delete current worktree, or select on main
wt clean                         # wt cl                   # delete worktrees with closed branches
wt list                          # wt ls                   # list worktrees
```

## Commands

### `wt init` · `wt i`

Interactive setup wizard for the current repo. Configures:

1. **Worktree location** -- choose where new worktrees are created: as a sibling of the repository (default) or a custom path
2. **Editor** -- auto-detects available editors (Cursor, Windsurf, VS Code) and lets you pick which one to open worktrees in
3. **Branch starting point** -- choose which branch or ref new worktrees branch from (e.g. `main`, `develop`)
4. **Workspace files** -- auto-detects `*.code-workspace` files to allow moving between IDE workspaces in a worktree
5. **Dependency directories** -- scans for lockfiles and lets you select which to auto-install in the new worktree
6. **Gitignored file sync categories** -- choose which categories of gitignored files to copy into new worktrees

Config is saved to `~/.config/wt/<repo-name>.conf`. Re-run `wt init` at any time to update.

### `wt create [<name>] [flags]` · `wt c`

Creates a new Git worktree in the configured worktree directory.

If no name is given, auto-generates one as `<repo>-wt-N` (incrementing).

**Flags:**

| Flag | Short | Description |
|------|-------|-------------|
| `--from <ref>` | `-f` | Start the new branch from a specific commit, branch, or tag |
| `--pr <number>` | `-p` | Create a worktree from a GitHub PR (requires `gh` CLI). Mutually exclusive with `--from` and `--checkout` |
| `--checkout <ref>` | `-c` | Check out an existing branch, tag, or commit into the worktree (checks locally first, falls back to origin). Does not create a new branch. Mutually exclusive with `--from` and `--pr` |
| `--editor <name>` | `-e` | Override the configured editor (`cursor`, `code`, `windsurf`) |
| `--cd` | `-d` | `cd` into the new worktree after creation |
| `--open` | `-o` | Open in the editor after creation |
| `--configure` | `-C` | Run the setup wizard for this worktree only (one-off, doesn't save to config) |
| `--stash` | `-s` | Stash uncommitted changes and apply them to the new worktree |
| `--execute <cmd>` | `-x` | Run a command in the worktree after opening (only runs with `--cd`) |
| `--no-prompt` | `-n` | Skip the interactive "What next?" prompt |
| `--no-init` | `-N` | Skip dependency install, theme setup, and file syncing |

**What happens on create:**

1. If there are uncommitted changes, you'll be asked if you want to stash and move them to the new worktree (use `--stash` to skip the prompt)
2. `git worktree add` creates the worktree with a new branch based on the configured starting point (set via `wt init`). The `--from` flag overrides the starting point
3. Gitignored files from configured sync categories are copied from the main worktree
4. A unique editor theme is assigned (from a rotating pool) and set in workspace/settings files
5. Modified workspace and settings files are marked with `git update-index --skip-worktree`
6. Dependencies are installed in parallel for all configured directories
7. If changes were stashed, they are popped into the new worktree. If there are conflicts, you'll be warned to resolve them manually
8. An interactive prompt asks whether to open in the editor, `cd`, or do nothing

Steps 3-6 run in parallel and you can open the worktree while they are completing. Press Enter at any point to move remaining tasks to the background.

### `wt open [<name>] [flags]` · `wt o`

Opens or navigates to an existing worktree.

- **No name, in main worktree** -- presents a picker to select from secondary worktrees
- **No name, in secondary worktree** -- uses the current worktree
- **Name given** -- uses that worktree directly

After selecting a worktree, choose between:
- **Open in editor** -- opens the workspace file (or worktree root) in your configured editor
- **cd into worktree** -- changes the shell's working directory

If multiple workspace files exist, a secondary picker lets you choose which one to open/cd into.

**Flags:**

| Flag | Short | Description |
|------|-------|-------------|
| `--open` | `-o` | Open in the editor |
| `--cd` | `-d` | `cd` into the worktree |
| `--editor <name>` | `-e` | Override the configured editor (`cursor`, `code`, `windsurf`) |
| `--execute <cmd>` | `-x` | Run a command in the worktree after opening (only runs with `--cd`) |

### `wt delete [<name>]` · `wt d`

Deletes a worktree and its branch.

- **No name, in a secondary worktree** -- deletes the current worktree (moves you to main)
- **No name, in the main worktree** -- presents a multi-select picker to delete one or more secondary worktrees
- **Name given** -- deletes that worktree directly

Worktrees with uncommitted changes will not be deleted (Git's safety check).

### `wt list` · `wt ls`

Lists all secondary worktrees for the current repo, showing:
- Worktree name
- Branch name
- Current editor theme
- **Status** -- dirty file count, ahead/behind remote (`↑2 ↓1`), or `clean`
- `(current)` marker for the worktree you're in

### `wt sync [<name>]` · `wt s`

Re-syncs gitignored files from the main worktree to an existing secondary worktree. Useful when `.env` files or local configs change in the main worktree after a secondary worktree was created.

- **No name, in secondary worktree** -- syncs to the current worktree
- **No name, in main worktree** -- presents a picker to select a worktree
- **Name given** -- syncs to that worktree directly

### `wt rename [<old>] <new>` · `wt rn`

Renames a worktree's directory and optionally its Git branch.

- **Two args** -- renames `<old>` to `<new>`
- **One arg, in secondary worktree** -- renames the current worktree to the given name
- **One arg, in main worktree** -- presents a picker, then renames the selected worktree

After moving the directory, prompts to also rename the branch to match. If you're inside the worktree being renamed, your shell is moved to the new path.

### `wt clean` · `wt cl`

Detects and bulk-deletes stale worktrees whose branches have been merged or whose remote tracking branches are gone.

1. Runs `git fetch --prune` to update remote state
2. Checks each secondary worktree's branch against the default branch (merged) and remote tracking status (gone)
3. Presents a multi-select picker of stale worktrees with their reason (merged/gone)
4. Deletes selected worktrees and their branches

## Configuration

### Config file

Stored at `~/.config/wt/<repo-basename>.conf` as simple `key=value` pairs:

```
worktree_dir=/Users/you/repos
editor=cursor
branch_start=main
branch_tool=git
dep_dirs=.,packages/api
sync_categories=dotenv,config
workspaces=my-project.code-workspace
```

### Gitignore file sync categories

Control which gitignored files are copied from the main worktree to new worktrees:

| Category | Examples | Default |
|----------|----------|---------|
| `deps` | `node_modules`, `.venv`, `venv`, `vendor`, `.terraform` | Excluded (installed separately) |
| `dotenv` | `.env` files (`.env`, `.env.local`, etc.) | Synced |
| `config` | `.claude/`, `.vscode/`, `.cursor/`, `.tool-versions` | Synced |
| `build` | `dist`, `build`, `.next`, `out`, `target` | Not synced |
| `cache` | `.mypy_cache`, `.ruff_cache` | Not synced |

### Theme rotation

Worktrees cycle through these VS Code themes to provide visual differentiation. Themes are set in both workspace files and the editor's settings directory, and marked as `--skip-worktree` to avoid polluting Git status.

## A note on post-creation hooks

For one-off commands after creating or opening a worktree (e.g. starting a dev server, running migrations), use the `--execute` / `-x` flag with `--cd`:

```zsh
wt create my-feature --cd -x "pnpm run dev"
```

For persistent post-creation hooks that should run automatically every time, use Git's built-in `post-checkout` hook which fires after `git worktree add`. See [this post on using git hooks when creating worktrees](https://mskelton.dev/bytes/using-git-hooks-when-creating-worktrees) for a walkthrough.
