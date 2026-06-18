"use client";

import { useEffect, useState } from "react";
import { BrandMark } from "./brand-mark";
import { GITHUB_URL } from "@/lib/site";

export function Nav() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <nav
      className={`sticky top-0 z-50 backdrop-blur-xl bg-[rgba(250,250,247,0.78)] border-b transition-colors duration-200 ${
        scrolled ? "border-line" : "border-transparent"
      }`}
    >
      <div className="mx-auto w-[min(1200px,100%-48px)]">
        <div className="flex h-16 items-center justify-between">
          <a href="#" className="flex items-center gap-2.5 font-semibold tracking-[-0.02em] text-[17px]">
            <BrandMark />
            <span>Cronwatch</span>
          </a>
          <div className="flex items-center gap-7">
            <a
              href="#features"
              className="hidden md:inline text-[14px] font-medium text-ink-muted hover:text-ink transition-colors"
            >
              Features
            </a>
            <a
              href="#how"
              className="hidden md:inline text-[14px] font-medium text-ink-muted hover:text-ink transition-colors"
            >
              How it works
            </a>
            <a
              href="#pricing"
              className="hidden md:inline text-[14px] font-medium text-ink-muted hover:text-ink transition-colors"
            >
              Pricing
            </a>
            <a
              href={GITHUB_URL}
              target="_blank"
              rel="noopener"
              aria-label="Cronwatch on GitHub"
              className="inline-flex items-center gap-1.5 text-[14px] font-medium text-ink-muted hover:text-ink transition-colors"
            >
              <svg width="18" height="18" viewBox="0 0 16 16" fill="currentColor" aria-hidden>
                <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z" />
              </svg>
              <span className="hidden md:inline">GitHub</span>
            </a>
            <button className="inline-flex h-10 items-center gap-2 rounded-[10px] bg-ink px-4 text-[14px] font-semibold tracking-[-0.01em] text-white whitespace-nowrap transition-all duration-150 hover:bg-black hover:shadow-[0_6px_18px_rgba(0,0,0,0.15)] active:translate-y-px">
              Get the app
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
}
