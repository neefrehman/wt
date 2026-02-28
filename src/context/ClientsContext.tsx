import type React from "react";
import { createContext, useContext } from "react";

import type { ConfigClient } from "#/clients/config.js";
import type { EditorClient } from "#/clients/editor.js";
import type { GhClient } from "#/clients/gh.js";
import type { GitClient } from "#/clients/git.js";
import type { GtClient } from "#/clients/gt.js";

interface ClientsContextValue {
  config: ConfigClient;
  editor: EditorClient;
  gh: GhClient;
  git: GitClient;
  gt: GtClient;
}

const ClientsContext = createContext<ClientsContextValue | null>(null);

export const ClientsProvider = ({
  children,
  config,
  editor,
  gh,
  git,
  gt,
}: ClientsContextValue & { children: React.ReactNode }) => {
  return (
    <ClientsContext.Provider value={{ config, editor, gh, git, gt }}>
      {children}
    </ClientsContext.Provider>
  );
};

export const useClientsContext = (): ClientsContextValue => {
  const ctx = useContext(ClientsContext);
  if (!ctx) {
    throw new Error("useClientsContext must be used within a ClientsProvider");
  }
  return ctx;
};
