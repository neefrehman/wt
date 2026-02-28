import { Static, Text } from "ink";

const BANNER_ART = `\
             .:;¦\\¯\`'¯\`'¯\\ :;/¯\`'¯\`;'/¦¦¯\`'¯\`'¯¦¦\\¯\`'¯\`'¯\\__
;/¯\`'¯\`'¯/¦.:;'¦;¦ -   --:;¦'/___:;/:;/  -  -.:;'/¦;¦__''__''¦
¦   -  .:;¦;'¦/¯\\/    -.:;'/¦'¦¦\`'¯\`'\`¦/     - ;/;'¦;¦.  '¯\`¦¦
¦\\   -  -:;\\/;/\\_____/:;¦¦L,  .:\\__'___\\ -:;'¦.:;/;¦L,__.:;'¦
¦:;\\_____/:;¦¦¯\`¯\`'¦¦:;'¦  ¯¯¯;¦.     ;/    ¯¯¯¯¯
¦:;¦¦¯\`'¯\`'¦¦.:;;      ;¦;'/'     .:;¦;¦¦¯\`'¯\`'¦¦
;\\;¦;      ;¦;/\\L_ .:;'¦/'      .:;¦;¦;     :;¦
:;'¦L_ .:;'¦/'       ¯           .:;\\¦L_  .:;¦
         ¯¯               '               ¯¯`;

const hexToRgb = (hex: string): [number, number, number] => {
  const normalized = hex.replace("#", "");
  return [
    Number.parseInt(normalized.slice(0, 2), 16),
    Number.parseInt(normalized.slice(2, 4), 16),
    Number.parseInt(normalized.slice(4, 6), 16),
  ];
};

const SOFT_CHARS = new Set(".:;'-`");
const SPLIT = 30;
const RESET = "\x1B[0m";

const PALETTES = [
  ["#06b6d4", "#818cf8", "#34d399"],
  ["#f472b6", "#c084fc", "#818cf8"],
  ["#34d399", "#2dd4bf", "#60a5fa"],
  ["#fb923c", "#f472b6", "#c084fc"],
  ["#a78bfa", "#60a5fa", "#34d399"],
  ["#fbbf24", "#fb923c", "#f472b6"],
  ["#4ade80", "#22d3ee", "#a78bfa"],
  ["#f87171", "#fbbf24", "#34d399"],
] as const;

const renderBanner = (): string => {
  const idx = Math.floor(Math.random() * PALETTES.length);
  const palette = PALETTES[idx] ?? PALETTES[0];

  const ansiColors = palette.map((hex) => {
    const [r, g, b] = hexToRgb(hex);
    return `\x1B[38;2;${r};${g};${b}m`;
  });

  const [c0 = "", c1 = "", c2 = ""] = ansiColors;
  const lines = BANNER_ART.split("\n");
  const output: string[] = [];

  for (const line of lines) {
    let out = "";
    let prev = "";

    for (let i = 0; i < line.length; i++) {
      const ch = line[i] ?? "";
      if (ch === " ") {
        out += ch;
        continue;
      }

      const pri = i < SPLIT ? c0 : c1;
      const alt = i < SPLIT ? c1 : c0;
      const r = Math.random();

      let color: string;
      if (SOFT_CHARS.has(ch)) {
        if (r < 0.18) {
          color = c2;
        } else if (r < 0.28) {
          color = alt;
        } else {
          color = pri;
        }
      } else if (r < 0.07) {
        color = c2;
      } else if (r < 0.1) {
        color = alt;
      } else {
        color = pri;
      }

      if (color !== prev) {
        out += color;
        prev = color;
      }
      out += ch;
    }
    out += RESET;
    output.push(out);
  }

  return output.join("\n");
};

const banner = renderBanner();

export const Banner = () => (
  <Static items={[{ id: "banner" }]}>{(item) => <Text key={item.id}>{banner}</Text>}</Static>
);
