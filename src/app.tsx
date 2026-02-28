import type React from "react";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";

import type { ConfigClient } from "#/clients/config.js";
import type { EditorClient } from "#/clients/editor.js";
import type { GhClient } from "#/clients/gh.js";
import type { GitClient } from "#/clients/git.js";
import type { GtClient } from "#/clients/gt.js";
import { ClientsProvider } from "#/context/ClientsContext.js";

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: false } },
});

interface AppProps {
  Component: React.ComponentType<Record<string, unknown>>;
  commandProps: Record<string, unknown>;
  config: ConfigClient;
  editor: EditorClient;
  gh: GhClient;
  git: GitClient;
  gt: GtClient;
}

export default function App({ Component, commandProps, config, editor, gh, git, gt }: AppProps) {
  return (
    <QueryClientProvider client={queryClient}>
      <ClientsProvider config={config} editor={editor} gh={gh} git={git} gt={gt}>
        <Component {...commandProps} />
      </ClientsProvider>
    </QueryClientProvider>
  );
}
