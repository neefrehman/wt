export const stripJsonComments = (text: string): string => {
  // Remove single-line comments
  let result = text.replaceAll(/\/\/[^\n]*/g, "");
  // Remove multi-line comments
  result = result.replaceAll(/\/\*[\s\S]*?\*\//g, "");
  // Remove trailing commas before } or ]
  result = result.replaceAll(/,\s*([\]}])/g, "$1");
  return result;
};

export const parseJsonc = (text: string): unknown => {
  return JSON.parse(stripJsonComments(text));
};

export const findWorkspaceFiles = async (root: string): Promise<string[]> => {
  const proc = Bun.spawn(
    [
      "find",
      root,
      "-maxdepth",
      "3",
      "-name",
      "*.code-workspace",
      "-not",
      "-path",
      "*/node_modules/*",
      "-not",
      "-path",
      "*/.git/*",
      "-not",
      "-path",
      "*/dist/*",
      "-not",
      "-path",
      "*/.next/*",
    ],
    { stdout: "pipe", stderr: "pipe" },
  );
  const output = await new Response(proc.stdout).text();
  await proc.exited;

  return output
    .split("\n")
    .filter(Boolean)
    .map((f) => f.replace(`${root}/`, ""));
};
