/** Create a temporary directory, like node's mkdtemp */
export async function mkdtemp(prefix: string): Promise<string> {
  const template = `${Bun.env.TMPDIR ?? "/tmp/"}${prefix}XXXXXX`;
  const proc = Bun.spawn(["mktemp", "-d", template], { stdout: "pipe" });
  return (await new Response(proc.stdout).text()).trim();
}
