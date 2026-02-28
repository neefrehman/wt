export interface WorktreeInfo {
  branch: string | null;
  head: string;
  isBare: boolean;
  isDetached: boolean;
  isPrunable: boolean;
  path: string;
}

export interface BranchInfo {
  gone: boolean;
  isHead: boolean;
  name: string;
  upstream: string | null;
}

export interface PRInfo {
  baseBranch: string;
  branch: string;
  forkOwner: string | null;
  forkRepo: string | null;
  isFork: boolean;
  number: number;
  title: string;
}

export type TaskState = "pending" | "running" | "done" | "error" | "skipped";

export interface TaskItem {
  id: string;
  label: string;
  message?: string;
  state: TaskState;
  subItems?: Array<{ label: string; state: TaskState; message?: string }>;
}
