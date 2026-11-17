import rss from "@astrojs/rss";

export async function GET(context) {
  const modules = import.meta.glob(["./notes/*.md", "./postmortems/*.md", "./methods/*.md"], { eager: true });
  const items = Object.values(modules)
    .map((m) => ({
      title: m.frontmatter.title,
      description: m.frontmatter.description,
      pubDate: new Date(m.frontmatter.date),
      link: m.url + "/",
    }))
    .sort((a, b) => b.pubDate - a.pubDate);
  return rss({
    title: "Vitalii Buyan",
    description: "Notes, methods and postmortems on Kubernetes, reliability and GPU platforms.",
    site: context.site,
    items,
  });
}
