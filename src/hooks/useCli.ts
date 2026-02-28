import { useApp } from "ink";

import { useClientsContext } from "#/context/ClientsContext.js";

export const useCli = () => {
  const clients = useClientsContext();
  const { exit } = useApp();
  return { exit, clients };
};
