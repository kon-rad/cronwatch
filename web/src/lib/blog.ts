import fs from "node:fs";
import path from "node:path";
import matter from "gray-matter";
import { marked } from "marked";

const POSTS_DIR = path.join(process.cwd(), "src", "content", "blog");

export type PostMeta = {
  slug: string;
  title: string;
  description: string;
  date: string;
  author: string;
  tags: string[];
  cover?: string;
  coverAlt?: string;
  readingMinutes: number;
};

export type Post = PostMeta & {
  html: string;
};

function readPostFile(slug: string): { data: matter.GrayMatterFile<string>["data"]; content: string } {
  const full = path.join(POSTS_DIR, `${slug}.md`);
  const raw = fs.readFileSync(full, "utf8");
  return matter(raw);
}

function estimateMinutes(markdown: string): number {
  const words = markdown.trim().split(/\s+/).length;
  return Math.max(1, Math.round(words / 220));
}

function buildMeta(slug: string, data: Record<string, unknown>, markdown: string): PostMeta {
  const title = String(data.title ?? slug);
  const description = String(data.description ?? "");
  const date = String(data.date ?? "");
  const author = String(data.author ?? "Konrad Gnat");
  const tags = Array.isArray(data.tags) ? (data.tags as unknown[]).map(String) : [];
  const cover = typeof data.cover === "string" ? data.cover : undefined;
  const coverAlt = typeof data.coverAlt === "string" ? data.coverAlt : undefined;
  return {
    slug,
    title,
    description,
    date,
    author,
    tags,
    cover,
    coverAlt,
    readingMinutes: estimateMinutes(markdown),
  };
}

marked.setOptions({ gfm: true, breaks: false });

function openExternalLinks(html: string): string {
  return html.replace(
    /<a\s+href="(https?:\/\/[^"]+)"/g,
    (match, href: string) => {
      if (href.includes("cronwatch.xyz")) return match;
      return `<a href="${href}" target="_blank" rel="noopener noreferrer"`;
    },
  );
}

export function getAllSlugs(): string[] {
  if (!fs.existsSync(POSTS_DIR)) return [];
  return fs
    .readdirSync(POSTS_DIR)
    .filter((f) => f.endsWith(".md"))
    .map((f) => f.replace(/\.md$/, ""));
}

export function getAllPosts(): PostMeta[] {
  return getAllSlugs()
    .map((slug) => {
      const { data, content } = readPostFile(slug);
      return buildMeta(slug, data, content);
    })
    .sort((a, b) => (a.date < b.date ? 1 : -1));
}

export function getPostBySlug(slug: string): Post | null {
  if (!getAllSlugs().includes(slug)) return null;
  const { data, content } = readPostFile(slug);
  const meta = buildMeta(slug, data, content);
  const rawHtml = marked.parse(content, { async: false }) as string;
  const html = openExternalLinks(rawHtml);
  return { ...meta, html };
}

export function formatPostDate(iso: string): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}
