import { parseWorktreeList } from "#/clients/git.js";

import { describe, expect, it } from "bun:test";

describe("parseWorktreeList", () => {
  it("parses porcelain output with multiple worktrees", () => {
    const output = `worktree /Users/me/repos/myproject
HEAD abc1234567890
branch refs/heads/main

worktree /Users/me/repos/myproject-wt-1
HEAD def4567890123
branch refs/heads/feature/cool-thing

worktree /Users/me/repos/myproject-wt-2
HEAD 789012345abcd
detached

`;
    const result = parseWorktreeList(output);
    expect(result).toHaveLength(3);

    expect(result[0]).toEqual({
      path: "/Users/me/repos/myproject",
      head: "abc1234567890",
      branch: "main",
      isBare: false,
      isDetached: false,
      isPrunable: false,
    });

    expect(result[1]).toEqual({
      path: "/Users/me/repos/myproject-wt-1",
      head: "def4567890123",
      branch: "feature/cool-thing",
      isBare: false,
      isDetached: false,
      isPrunable: false,
    });

    expect(result[2]).toEqual({
      path: "/Users/me/repos/myproject-wt-2",
      head: "789012345abcd",
      branch: null,
      isBare: false,
      isDetached: true,
      isPrunable: false,
    });
  });

  it("handles bare worktree", () => {
    const output = `worktree /Users/me/repos/myproject.git
HEAD abc1234567890
bare

`;
    const result = parseWorktreeList(output);
    expect(result).toHaveLength(1);
    expect(result.at(0)?.isBare).toBe(true);
    expect(result.at(0)?.branch).toBeNull();
  });

  it("handles prunable worktree", () => {
    const output = `worktree /Users/me/repos/myproject-wt-old
HEAD abc1234567890
branch refs/heads/old-branch
prunable

`;
    const result = parseWorktreeList(output);
    expect(result).toHaveLength(1);
    expect(result.at(0)?.isPrunable).toBe(true);
  });

  it("returns empty array for empty output", () => {
    expect(parseWorktreeList("")).toHaveLength(0);
  });

  it("handles output without trailing newline", () => {
    const output = `worktree /Users/me/repos/myproject
HEAD abc1234567890
branch refs/heads/main`;
    const result = parseWorktreeList(output);
    expect(result).toHaveLength(1);
    expect(result.at(0)?.branch).toBe("main");
  });
});
