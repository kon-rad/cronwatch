import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import {
  formatPostDate,
  getAllSlugs,
  getPostBySlug,
} from "@/lib/blog";

type Params = Promise<{ slug: string }>;

export function generateStaticParams() {
  return getAllSlugs().map((slug) => ({ slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Params;
}): Promise<Metadata> {
  const { slug } = await params;
  const post = getPostBySlug(slug);
  if (!post) return {};
  return {
    title: `${post.title} — Cronwatch`,
    description: post.description,
    openGraph: {
      title: post.title,
      description: post.description,
      type: "article",
      authors: [post.author],
      publishedTime: post.date,
      tags: post.tags,
      images: post.cover ? [post.cover] : undefined,
    },
    twitter: {
      card: "summary_large_image",
      title: post.title,
      description: post.description,
      images: post.cover ? [post.cover] : undefined,
    },
  };
}

export default async function BlogPostPage({ params }: { params: Params }) {
  const { slug } = await params;
  const post = getPostBySlug(slug);
  if (!post) notFound();

  return (
    <article className="blog-post">
      <p className="blog-eyebrow">
        <Link href="/blog">Cronwatch journal</Link>
      </p>
      <h1>{post.title}</h1>
      <p className="blog-lede">{post.description}</p>

      <div className="blog-byline">
        <span className="blog-byline-author">{post.author}</span>
        <span aria-hidden>·</span>
        <time dateTime={post.date}>{formatPostDate(post.date)}</time>
        <span aria-hidden>·</span>
        <span>{post.readingMinutes} min read</span>
      </div>

      {post.tags.length > 0 && (
        <div className="blog-tags">
          {post.tags.map((t) => (
            <span key={t} className="blog-tag">
              {t}
            </span>
          ))}
        </div>
      )}

      {post.cover && (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          className="blog-cover"
          src={post.cover}
          alt={post.coverAlt ?? ""}
          loading="eager"
        />
      )}

      <div
        className="blog-prose"
        dangerouslySetInnerHTML={{ __html: post.html }}
      />

      <hr />

      <div className="blog-back">
        <Link href="/blog">← All posts</Link>
      </div>
    </article>
  );
}
