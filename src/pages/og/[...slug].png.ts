// Social preview images (Open Graph), one per page, rendered at build time.
// satori turns a small element tree into SVG; resvg turns the SVG into PNG.
import type { APIRoute, GetStaticPaths } from "astro";
import satori from "satori";
import { Resvg } from "@resvg/resvg-js";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const font = (pkg: string, file: string) =>
  readFileSync(require.resolve(`@fontsource/${pkg}/files/${file}`));

const fonts = [
  { name: "Inter", data: font("inter", "inter-latin-400-normal.woff"), weight: 400 as const, style: "normal" as const },
  { name: "Inter", data: font("inter", "inter-latin-700-normal.woff"), weight: 700 as const, style: "normal" as const },
  { name: "Mono", data: font("jetbrains-mono", "jetbrains-mono-latin-400-normal.woff"), weight: 400 as const, style: "normal" as const },
  { name: "Mono", data: font("jetbrains-mono", "jetbrains-mono-latin-600-normal.woff"), weight: 600 as const, style: "normal" as const },
];

type Card = { slug: string; title: string; kind: string; date?: string; description?: string };

const KIND_COLOR: Record<string, string> = {
  postmortem: "#f87171",
  method: "#a78bfa",
  "case study": "#a78bfa",
  note: "#60a5fa",
};

export const getStaticPaths: GetStaticPaths = () => {
  const md = Object.values(import.meta.glob("../**/*.md", { eager: true })) as any[];
  const cards: Card[] = md.map((m) => ({
    slug: m.url.replace(/^\/|\/$/g, ""),
    title: m.frontmatter.title,
    kind: m.frontmatter.kind ?? "Page",
    date: m.frontmatter.date,
    description: m.frontmatter.description,
  }));
  cards.push(
    { slug: "index", title: "I make shared infrastructure fair, observable and boring.", kind: "DevOps · SRE · GPU platforms", description: "Kubernetes, AWS, Terraform, GitOps and observability. Every incident becomes a postmortem, every decision a written record." },
    { slug: "projects", title: "Projects", kind: "Index", description: "Systems I have built and run, with the decisions behind them, the numbers, and what broke." },
    { slug: "methods", title: "Methods", kind: "Index", description: "Patterns I use and can defend, each with the reasoning and the evidence behind it." },
    { slug: "postmortems", title: "Postmortems", kind: "Index", description: "Blameless write-ups of real incidents. Every one changed an alert, a default or a design." },
    { slug: "notes", title: "Notes", kind: "Index", description: "Short notes from building and running platforms." },
  );
  return cards.map((c) => ({ params: { slug: c.slug }, props: c }));
};

const clip = (s = "", n: number) => (s.length > n ? s.slice(0, n - 1).trimEnd() + "…" : s);

function tree(c: Card) {
  const accent = KIND_COLOR[c.kind.toLowerCase()] ?? "#5eead4";
  const kicker = [c.kind, c.date].filter(Boolean).join(" · ").toUpperCase();
  const titleSize = c.title.length > 70 ? 54 : c.title.length > 40 ? 62 : 72;
  const div = (style: Record<string, unknown>, children: unknown) => ({ type: "div", props: { style, children } });
  return div(
    {
      // content box: 1200 - 2*72 wide, 630 - 52 - 48 - 10 (top border) tall
      width: 1056, height: 520, display: "flex", flexDirection: "column", justifyContent: "space-between",
      background: "#07090d", color: "#e7ecf3", padding: "52px 72px 48px", fontFamily: "Inter",
      borderTop: `10px solid ${accent}`,
    },
    [
      div({ display: "flex", alignItems: "center", gap: 14, fontFamily: "Mono", fontSize: 26, fontWeight: 600 }, [
        div({ width: 16, height: 16, borderRadius: 8, background: "#5eead4" }, ""),
        div({ display: "flex" }, "vbuyan"),
      ]),
      div({ display: "flex", flexDirection: "column", gap: 20, width: 1056 }, [
        div({ display: "flex", fontFamily: "Mono", fontSize: 24, letterSpacing: 3, color: accent }, kicker),
        div({ display: "flex", width: 1056, fontSize: titleSize, fontWeight: 700, lineHeight: 1.08, letterSpacing: -1.5 }, clip(c.title, 110)),
        c.description
          ? div({ display: "flex", width: 1056, fontSize: 27, lineHeight: 1.4, color: "#8b97a8" }, clip(c.description, 140))
          : div({ display: "flex" }, ""),
        div({ display: "flex", flexDirection: "row", justifyContent: "space-between", width: 1056, marginTop: 26, paddingTop: 22, borderTop: "1px solid #1d2633", fontFamily: "Mono", fontSize: 22, color: "#8b97a8" }, [
          div({ display: "flex" }, "Vitalii Buyan · DevOps / Site Reliability Engineer"),
          div({ display: "flex", color: "#5eead4" }, "vbuyan.com"),
        ]),
      ]),
    ],
  );
}

export const GET: APIRoute = async ({ props }) => {
  const svg = await satori(tree(props as Card) as any, { width: 1200, height: 630, fonts });
  const png = new Resvg(svg, { fitTo: { mode: "width", value: 1200 } }).render().asPng();
  return new Response(png, { headers: { "Content-Type": "image/png" } });
};
