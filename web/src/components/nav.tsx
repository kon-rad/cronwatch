"use client";

import { useEffect, useState } from "react";
import { BrandMark } from "./brand-mark";

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
            <button className="inline-flex h-10 items-center gap-2 rounded-[10px] bg-ink px-4 text-[14px] font-semibold tracking-[-0.01em] text-white whitespace-nowrap transition-all duration-150 hover:bg-black hover:shadow-[0_6px_18px_rgba(0,0,0,0.15)] active:translate-y-px">
              Get the app
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
}
