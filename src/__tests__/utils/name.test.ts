import { sanitizeBranchName, validateWorktreeName } from "#/utils/name.js";

import { describe, expect, test } from "bun:test";

describe("sanitizeBranchName", () => {
  test("replaces slashes with hyphens", () => {
    expect(sanitizeBranchName("feature/my-branch")).toBe("feature-my-branch");
  });

  test("replaces special characters", () => {
    expect(sanitizeBranchName("my branch!@#$%")).toBe("my-branch");
  });

  test("collapses multiple hyphens", () => {
    expect(sanitizeBranchName("a//b///c")).toBe("a-b-c");
  });

  test("strips leading and trailing hyphens", () => {
    expect(sanitizeBranchName("-foo-")).toBe("foo");
  });

  test("preserves dots and underscores", () => {
    expect(sanitizeBranchName("v1.0_release")).toBe("v1.0_release");
  });

  test("handles complex PR branch names", () => {
    expect(sanitizeBranchName("user/feature/add-auth")).toBe("user-feature-add-auth");
  });
});

describe("validateWorktreeName", () => {
  test("returns null for valid names", () => {
    expect(validateWorktreeName("my-worktree")).toBeNull();
    expect(validateWorktreeName("v1.0")).toBeNull();
    expect(validateWorktreeName("feat_test")).toBeNull();
  });

  test("rejects names starting with hyphen", () => {
    expect(validateWorktreeName("-bad")).toContain("cannot start with");
  });

  test("rejects names with double dots", () => {
    expect(validateWorktreeName("a..b")).toContain("cannot contain '..'");
  });

  test("rejects names with invalid characters", () => {
    expect(validateWorktreeName("a b")).toContain("Only alphanumeric");
    expect(validateWorktreeName("a@b")).toContain("Only alphanumeric");
  });

  test("allows slashes in names", () => {
    expect(validateWorktreeName("feat/auth")).toBeNull();
  });
});
