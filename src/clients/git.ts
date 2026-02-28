import * as R from "remeda";
import { simpleGit } from "simple-git";

import type { SyncCategoryKey } from "#/constants";
import type { BranchInfo, WorktreeInfo } from "#/types/worktree.js";
import { cached } from "#/utils/cached.js";
import { classifyCategory, SYNC_NOISE_RE } from "#/utils/sync-patterns.js";

const REFS_HEADS_RE = /^refs\/heads\//;
const BRANCH_PREFIX_RE = /^\*?\s+/;
const WORKTREE_PREFIX_RE = /^worktree /;
const REFS_REMOTES_ORIGIN_RE = /^refs\/remotes\/origin\//;

const git = (cwd?: string) => simpleGit(cwd);

export interface GitClient {
  aheadBehind(opts?: { cwd?: string }): Promise<{ ahead: number; behind: number }>;
  branchCreate(name: string, startPoint: string, opts?: { cwd?: string }): Promise<void>;
  branchDelete(name: string, opts?: { force?: boolean; cwd?: string }): Promise<void>;
  branchList(opts?: { cwd?: string; verbose?: boolean }): Promise<BranchInfo[]>;
  branchListMerged(target: string, opts?: { cwd?: string }): Promise<string[]>;
  branchRename(oldName: string, newName: string, opts?: { cwd?: string }): Promise<void>;
  currentBranch(cwd?: string): Promise<string>;
  defaultBranch(): Promise<string>;
  detectIgnoredFileCategories(opts?: { cwd?: string }): Promise<SyncCategoryKey[]>;
  fetch(opts?: { prune?: boolean; cwd?: string }): Promise<void>;
  fetchRef(ref: string, opts?: { cwd?: string; refspec?: string }): Promise<void>;
  hasChanges(cwd?: string): Promise<boolean>;
  listIgnoredFiles(opts?: { cwd?: string }): Promise<string[]>;
  mainWorktree(cwd?: string): Promise<string>;
  repoRoot(cwd?: string): Promise<string>;
  revParse(args: string[], opts?: { cwd?: string }): Promise<string>;
  stashPop(opts?: { cwd?: string }): Promise<void>;
  stashPush(message: string, opts?: { cwd?: string }): Promise<void>;
  statusCount(opts?: { cwd?: string }): Promise<number>;
  worktreeAdd(
    path: string,
    branch: string,
    opts?: { base?: string; cwd?: string; newBranch?: boolean },
  ): Promise<void>;
  worktreeList(cwd?: string): Promise<WorktreeInfo[]>;
  worktreeMove(oldPath: string, newPath: string, opts?: { cwd?: string }): Promise<void>;
  worktreeRemove(path: string, opts?: { force?: boolean; cwd?: string }): Promise<void>;
}

export const parseWorktreeList = (output: string): WorktreeInfo[] =>
  R.pipe(
    output,
    R.split("\n\n"),
    R.map((block: string) => {
      const lines = block.split("\n");
      const worktreeLine = lines.find((l) => l.startsWith("worktree "));
      if (!worktreeLine) {
        return null;
      }

      const headLine = lines.find((l) => l.startsWith("HEAD "));
      const branchLine = lines.find((l) => l.startsWith("branch "));

      return {
        path: worktreeLine.slice(9),
        head: headLine?.slice(5) ?? "",
        branch: branchLine?.slice(7).replace(REFS_HEADS_RE, "") ?? null,
        isBare: lines.includes("bare"),
        isDetached: lines.includes("detached"),
        isPrunable: lines.includes("prunable"),
      };
    }),
    R.filter(R.isNonNullish),
  );

export class RealGitClient implements GitClient {
  async worktreeList(cwd?: string) {
    const output = await git(cwd).raw("worktree", "list", "--porcelain");
    return parseWorktreeList(output);
  }

  async worktreeAdd(
    path: string,
    branch: string,
    opts?: { base?: string; cwd?: string; newBranch?: boolean },
  ) {
    const args = ["worktree", "add"];
    if (opts?.newBranch) {
      args.push("-b", branch, path, opts.base ?? "HEAD");
    } else {
      args.push(path, branch);
    }
    await git(opts?.cwd).raw(args);
  }

  async worktreeRemove(path: string, opts?: { force?: boolean; cwd?: string }) {
    const args = ["worktree", "remove", path];
    if (opts?.force) {
      args.push("--force");
    }
    await git(opts?.cwd).raw(args);
  }

  async worktreeMove(oldPath: string, newPath: string, opts?: { cwd?: string }) {
    await git(opts?.cwd).raw("worktree", "move", oldPath, newPath);
  }

  async branchList(opts?: { cwd?: string; verbose?: boolean }) {
    const output = await git(opts?.cwd).raw(
      "for-each-ref",
      "--format=%(refname:short)\t%(upstream:short)\t%(upstream:track)\t%(HEAD)",
      "refs/heads/",
    );
    return R.pipe(
      output,
      R.split("\n"),
      R.filter((line) => line.trim() !== ""),
      R.flatMap((line) => {
        const [name, upstream, track, head] = line.split("\t");
        if (!name) {
          return [];
        }
        return [
          {
            name,
            isHead: head === "*",
            upstream: upstream ?? null,
            gone: track?.includes("[gone]") ?? false,
          },
        ];
      }),
    );
  }

  async branchDelete(name: string, opts?: { force?: boolean; cwd?: string }) {
    await git(opts?.cwd).deleteLocalBranch(name, opts?.force);
  }

  async branchCreate(name: string, startPoint: string, opts?: { cwd?: string }) {
    await git(opts?.cwd).branch([name, startPoint]);
  }

  async branchRename(oldName: string, newName: string, opts?: { cwd?: string }) {
    await git(opts?.cwd).raw("branch", "-m", oldName, newName);
  }

  async branchListMerged(target: string, opts?: { cwd?: string }) {
    const output = await git(opts?.cwd).raw("branch", "--merged", target);
    return R.pipe(
      output,
      R.split("\n"),
      R.map((l) => l.replace(BRANCH_PREFIX_RE, "").trim()),
      R.filter(Boolean),
    );
  }

  async stashPush(message: string, opts?: { cwd?: string }) {
    await git(opts?.cwd).stash(["push", "-m", message]);
  }

  async stashPop(opts?: { cwd?: string }) {
    await git(opts?.cwd).stash(["pop"]);
  }

  async fetch(opts?: { prune?: boolean; cwd?: string }) {
    await git(opts?.cwd).fetch(opts?.prune ? ["--prune"] : []);
  }

  async revParse(args: string[], opts?: { cwd?: string }) {
    const output = await git(opts?.cwd).raw("rev-parse", ...args);
    return output.trim();
  }

  repoRoot(cwd?: string) {
    return this.revParse(["--show-toplevel"], { cwd });
  }

  mainWorktree = cached((cwd?: string) =>
    git(cwd)
      .raw("worktree", "list", "--porcelain")
      .then((output) => {
        const firstLine = output.split("\n")[0] ?? "";
        return firstLine.replace(WORKTREE_PREFIX_RE, "");
      }),
  );

  defaultBranch = cached(() => {
    return git()
      .raw("symbolic-ref", "refs/remotes/origin/HEAD")
      .then((ref) => ref.trim().replace(REFS_REMOTES_ORIGIN_RE, ""))
      .catch(async () => {
        await git().raw("rev-parse", "--verify", "refs/heads/main");
        return "main";
      })
      .catch(async () => {
        await git().raw("rev-parse", "--verify", "refs/heads/master");
        return "master";
      })
      .catch(() => "main");
  });

  async hasChanges(cwd?: string) {
    const result = await git(cwd).status();
    return !result.isClean();
  }

  async currentBranch(cwd?: string) {
    const output = await git(cwd).revparse(["--abbrev-ref", "HEAD"]);
    return output.trim();
  }

  async fetchRef(ref: string, opts?: { cwd?: string; refspec?: string }) {
    await git(opts?.cwd).fetch("origin", opts?.refspec ?? ref);
  }

  async detectIgnoredFileCategories(opts?: { cwd?: string }) {
    const files = await this.listIgnoredFiles(opts);
    return R.pipe(
      files,
      R.filter((e) => e !== "" && !SYNC_NOISE_RE.test(e)),
      R.flatMap((entry) => {
        const cat = classifyCategory(entry);
        return cat ? [cat] : [];
      }),
      R.unique(),
    );
  }

  async listIgnoredFiles(opts?: { cwd?: string }) {
    const output = await git(opts?.cwd).raw(
      "ls-files",
      "--others",
      "--ignored",
      "--directory",
      "--exclude-standard",
    );
    return R.pipe(output, R.split("\n"), R.filter(Boolean));
  }

  async statusCount(opts?: { cwd?: string }) {
    const result = await git(opts?.cwd).status();
    return result.files.length;
  }

  async aheadBehind(opts?: { cwd?: string }) {
    const result = await git(opts?.cwd).status();
    return { ahead: result.ahead, behind: result.behind };
  }
}

export class FakeGitClient implements GitClient {
  worktreeList() {
    return Promise.resolve([
      {
        path: "/fake/repo",
        head: "abc1234",
        branch: "main",
        isBare: false,
        isDetached: false,
        isPrunable: false,
      },
      {
        path: "/fake/repo-feature",
        head: "def5678",
        branch: "feature/login",
        isBare: false,
        isDetached: false,
        isPrunable: false,
      },
      {
        path: "/fake/repo-bugfix",
        head: "ghi9012",
        branch: "fix/header",
        isBare: false,
        isDetached: false,
        isPrunable: false,
      },
    ]);
  }
  worktreeAdd() {
    return Promise.resolve();
  }
  worktreeRemove() {
    return Promise.resolve();
  }
  worktreeMove() {
    return Promise.resolve();
  }
  branchList() {
    return Promise.resolve([
      { name: "main", isHead: true, upstream: "origin/main", gone: false },
      {
        name: "feature/login",
        isHead: false,
        upstream: "origin/feature/login",
        gone: false,
      },
      {
        name: "fix/header",
        isHead: false,
        upstream: "origin/fix/header",
        gone: false,
      },
    ]);
  }
  branchDelete() {
    return Promise.resolve();
  }
  branchCreate() {
    return Promise.resolve();
  }
  branchRename() {
    return Promise.resolve();
  }
  branchListMerged() {
    return Promise.resolve(["feature/old-merged"]);
  }
  stashPush() {
    return Promise.resolve();
  }
  stashPop() {
    return Promise.resolve();
  }
  fetch() {
    return Promise.resolve();
  }
  fetchRef() {
    return Promise.resolve();
  }
  revParse() {
    return Promise.resolve("abc1234def5678");
  }
  repoRoot() {
    return Promise.resolve("/fake/repo");
  }
  mainWorktree() {
    return Promise.resolve("/fake/repo");
  }
  defaultBranch() {
    return Promise.resolve("main");
  }
  hasChanges() {
    return Promise.resolve(false);
  }
  currentBranch() {
    return Promise.resolve("main");
  }
  statusCount() {
    return Promise.resolve(0);
  }
  aheadBehind() {
    return Promise.resolve({ ahead: 0, behind: 0 });
  }
  detectIgnoredFileCategories() {
    return Promise.resolve([
      "deps",
      "dotenv",
      "build",
      "cache",
      "config",
    ] satisfies SyncCategoryKey[]);
  }
  listIgnoredFiles() {
    return Promise.resolve(["node_modules/", ".env"]);
  }
}
