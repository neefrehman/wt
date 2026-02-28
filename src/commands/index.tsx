import React from "react";

import { Box, Text, useApp } from "ink";

import {
  PROGRAM_DESCRIPTION,
  commandRegistry,
  formatArgs,
  formatOptions,
  registerCommand,
} from "#/cli-setup.js";
import { Banner } from "#/components/Banner.js";

const CMD_WIDTH = 20;
const ARGS_WIDTH = 22;

export const command = registerCommand({
  name: "index",
  description: "check usage",
  register: false,
});

export default function Index() {
  const { exit } = useApp();

  React.useEffect(exit, [exit]);

  const commandRegistryEntries = [...commandRegistry.entries()];
  return (
    <Box flexDirection="column" gap={1} paddingLeft={2} paddingY={1}>
      <Banner />

      <Text bold>{PROGRAM_DESCRIPTION}</Text>

      <Box flexDirection="column">
        <Text bold>Usage:</Text>
        <Box>
          <Box flexShrink={0} width={CMD_WIDTH}>
            <Text color="cyan">wt</Text>
          </Box>
          <Box flexShrink={0} width={ARGS_WIDTH}>
            <Text />
          </Box>
          <Text>check usage</Text>
        </Box>
        {commandRegistryEntries.map(([name, def]) => {
          const args = def.args ? formatArgs(def.args).join(" ") : "";
          const argsDisplay = args ? `${args} [flags]` : "";
          const display = def.options ? argsDisplay || "[flags]" : args;
          return (
            <Box key={name}>
              <Box flexShrink={0} width={CMD_WIDTH}>
                <Text color="cyan">wt {name}</Text>
              </Box>
              <Box flexShrink={0} width={ARGS_WIDTH}>
                <Text>{display}</Text>
              </Box>
              <Box flexDirection="row" gap={2}>
                <Text>{def.description ?? ""}</Text>
                {def.alias ? <Text dimColor># wt {def.alias}</Text> : null}
              </Box>
            </Box>
          );
        })}
      </Box>

      {commandRegistryEntries
        .filter(([_, v]) => Boolean(v.options))
        .map(([k, v]) => (
          <Box flexDirection="column" key={k}>
            <Text bold>{k} flags:</Text>
            {v.options &&
              formatOptions(v.options, v.shortFlags).map(
                ({ short: s, long: l, arg, description }) => (
                  <Box key={l}>
                    <Box flexShrink={0} width={CMD_WIDTH}>
                      <Text>
                        <Text color="green">{l}</Text>
                        {s ? (
                          <>
                            , <Text color="green">{s}</Text>
                          </>
                        ) : null}
                      </Text>
                    </Box>
                    <Box flexShrink={0} width={ARGS_WIDTH}>
                      <Text>{arg}</Text>
                    </Box>
                    <Text>{description}</Text>
                  </Box>
                ),
              )}
          </Box>
        ))}
    </Box>
  );
}

command.registerComponent(Index);
