import type { Metadata } from "next";
import Link from "next/link";
import { formatPostDate, getAllPosts } from "@/lib/blog";

export const metadata: Metadata = {
  title: "Blog — Cronwatch",
  description:
    "Notes on time, attention, voice-first interfaces, and how AI can quietly help people use their hours better.",
};

export default function BlogIndexPage() {
  const posts = getAllPosts();

  return (
    <article className="blog-index">
      <p className="blog-eyebrow">Cronwatch journal</p>
      <h1>Writing</h1>
      <p className="blog-lede">
        Short essays on time, attention, and how voice-first AI can help people
        live more of their day on purpose.
      </p>

      {posts.length === 0 ? (
        <p className="blog-empty">No posts yet. Check back soon.</p>
      ) : (
        <ul className="blog-list">
          {posts.map((p) => (
            <li key={p.slug}>
              <Link href={`/blog/${p.slug}`} className="blog-card">
                <div className="blog-card-meta">
                  <time dateTime={p.date}>{formatPostDate(p.date)}</time>
                  <span aria-hidden>·</span>
                  <span>{p.readingMinutes} min read</span>
                </div>
                <h2>{p.title}</h2>
                <p>{p.description}</p>
                {p.tags.length > 0 && (
                  <div className="blog-card-tags">
                    {p.tags.map((t) => (
                      <span key={t} className="blog-tag">
                        {t}
                      </span>
                    ))}
                  </div>
                )}
              </Link>
            </li>
          ))}
        </ul>
      )}
    </article>
  );
}
