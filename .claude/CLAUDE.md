# wt

`wt` is a CLI for managing git worktrees, built with Bun, Ink (React for CLIs), and Commander. Commands live in `src/commands/` as React components rendered by Ink, with shared state provided through React Context (`ClientsProvider`) and data fetching via TanStack Query. The entry point (`src/cli.tsx`) wires up Commander for arg parsing and injects real or fake client implementations depending on the environment.

External integrations (git, gh, graphite, editor, config) are abstracted behind client interfaces in `src/clients/`, each with a base class defining the contract and Real/Fake implementations for production and development. This makes commands testable and decoupled from shell operations. Utility functions in `src/utils/` handle pure transformations like name derivation, lockfile detection, and sync pattern classification.

Prefer `remeda` for data transformations and `ts-pattern` for exhaustive matching over manual conditionals. Components should be composed from small, focused pieces — use Ink primitives and the shared components in `src/components/` rather than building monolithic command UIs.

Avoid premature abstraction into different components or files. Typically wait for multiple use cases or a significant complexity saving before you do this.

Do not add unnecessary comments to code.
