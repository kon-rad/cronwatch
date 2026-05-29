import Link from "next/link";
import { BrandMark } from "@/components/brand-mark";

export default function BlogLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <>
      <nav className="sticky top-0 z-50 backdrop-blur-xl bg-[rgba(250,250,247,0.78)] border-b border-line">
        <div className="mx-auto w-[min(1200px,100%-48px)]">
          <div className="flex h-16 items-center justify-between">
            <Link
              href="/"
              className="flex items-center gap-2.5 font-semibold tracking-[-0.02em] text-[17px]"
            >
              <BrandMark />
              <span>Cronwatch</span>
            </Link>
            <div className="flex items-center gap-7 text-[14px] font-medium text-ink-muted">
              <Link href="/blog" className="hover:text-ink transition-colors">
                Blog
              </Link>
              <Link href="/support" className="hover:text-ink transition-colors">
                Support
              </Link>
              <Link href="/privacy" className="hover:text-ink transition-colors">
                Privacy
              </Link>
              <Link href="/terms" className="hover:text-ink transition-colors">
                Terms
              </Link>
            </div>
          </div>
        </div>
      </nav>

      <main className="mx-auto w-[min(760px,100%-48px)] py-16 md:py-24">
        {children}
      </main>

      <footer className="mx-auto w-[min(760px,100%-48px)] pb-16 text-caption text-[13px] border-t border-line-soft pt-8">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <span>© 2026 Cronwatch. Made quietly.</span>
          <span className="flex gap-5">
            <Link href="/" className="hover:text-ink transition-colors">
              Home
            </Link>
            <Link href="/blog" className="hover:text-ink transition-colors">
              Blog
            </Link>
            <Link href="/support" className="hover:text-ink transition-colors">
              Support
            </Link>
            <Link href="/privacy" className="hover:text-ink transition-colors">
              Privacy
            </Link>
            <Link href="/terms" className="hover:text-ink transition-colors">
              Terms
            </Link>
          </span>
        </div>
      </footer>
    </>
  );
}
