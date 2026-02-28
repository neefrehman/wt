export interface GtClient {
  isInstalled(): Promise<boolean>;
  trackBranch(parent: string, opts?: { cwd?: string }): Promise<void>;
}

export class RealGtClient implements GtClient {
  async isInstalled() {
    try {
      const proc = Bun.spawn(["which", "gt"], {
        stdout: "pipe",
        stderr: "pipe",
      });
      const exitCode = await proc.exited;
      return exitCode === 0;
    } catch {
      return false;
    }
  }

  async trackBranch(parent: string, opts?: { cwd?: string }): Promise<void> {
    const installed = await this.isInstalled();
    if (!installed) {
      return;
    }

    const proc = Bun.spawn(["gt", "track", "--parent", parent], {
      cwd: opts?.cwd,
      stdout: "pipe",
      stderr: "pipe",
    });
    await proc.exited;
  }
}

export class FakeGtClient implements GtClient {
  isInstalled() {
    return Promise.resolve(true);
  }

  trackBranch() {
    return Promise.resolve();
  }
}
