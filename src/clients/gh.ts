import type { PRInfo } from "#/types/worktree.js";

import type { GitClient } from "./git.js";

export interface GhClient {
  fetchPR(number: number, opts?: { cwd?: string }): Promise<PRInfo>;
  fetchPRBranch(prNumber: number, mainWtCwd: string): Promise<{ branch: string; isFork: boolean }>;
  isInstalled(): Promise<boolean>;
}

export class RealGhClient implements GhClient {
  private readonly git: GitClient;

  constructor(git: GitClient) {
    this.git = git;
  }

  async isInstalled(): Promise<boolean> {
    try {
      const proc = Bun.spawn(["which", "gh"], {
        stdout: "pipe",
        stderr: "pipe",
      });
      const exitCode = await proc.exited;
      return exitCode === 0;
    } catch {
      return false;
    }
  }

  async fetchPR(number: number, opts?: { cwd?: string }): Promise<PRInfo> {
    const installed = await this.isInstalled();
    if (!installed) {
      throw new Error("gh CLI is required for --pr. Install it from https://cli.github.com");
    }

    const proc = Bun.spawn(
      [
        "gh",
        "pr",
        "view",
        String(number),
        "--json",
        "headRefName,baseRefName,title,headRepositoryOwner,isCrossRepository",
      ],
      { cwd: opts?.cwd, stdout: "pipe", stderr: "pipe" },
    );
    const [stdout, stderr] = await Promise.all([
      new Response(proc.stdout).text(),
      new Response(proc.stderr).text(),
    ]);
    const exitCode = await proc.exited;

    if (exitCode !== 0) {
      throw new Error(stderr.trim() || `gh exited with code ${exitCode}`);
    }

    const data = JSON.parse(stdout);
    const isFork = data.isCrossRepository ?? false;

    return {
      number,
      title: data.title ?? "",
      branch: data.headRefName,
      baseBranch: data.baseRefName ?? "main",
      isFork,
      forkOwner: isFork ? (data.headRepositoryOwner?.login ?? null) : null,
      forkRepo: null,
    } satisfies PRInfo;
  }

  async fetchPRBranch(
    prNumber: number,
    mainWtCwd: string,
  ): Promise<{ branch: string; isFork: boolean }> {
    const pr = await this.fetchPR(prNumber, { cwd: mainWtCwd });

    const refspec = pr.isFork ? `pull/${prNumber}/head:${pr.branch}` : undefined;
    await this.git.fetchRef(pr.branch, { cwd: mainWtCwd, refspec });

    if (!pr.isFork) {
      try {
        await this.git.revParse(["--verify", `refs/heads/${pr.branch}`], {
          cwd: mainWtCwd,
        });
      } catch {
        await this.git.branchCreate(pr.branch, `origin/${pr.branch}`, {
          cwd: mainWtCwd,
        });
      }
    }

    return { branch: pr.branch, isFork: pr.isFork };
  }
}

export class FakeGhClient implements GhClient {
  isInstalled() {
    return Promise.resolve(true);
  }

  fetchPR(number: number) {
    return Promise.resolve({
      number,
      title: `Fake PR #${number}`,
      branch: `pr-${number}`,
      baseBranch: "main",
      isFork: false,
      forkOwner: null,
      forkRepo: null,
    } as PRInfo);
  }

  fetchPRBranch(prNumber: number) {
    return Promise.resolve({ branch: `pr-${prNumber}`, isFork: false });
  }
}
