import { PhoneMock } from "./phone-mock";
import { FloatCards } from "./float-cards";
import { StoreButtons } from "./store-buttons";
import { GITHUB_URL } from "@/lib/site";

export function Hero() {
  return (
    <section className="relative pt-14 pb-20 md:pt-20 md:pb-[120px] overflow-hidden">
      <div
        aria-hidden
        className="absolute z-0 pointer-events-none"
        style={{
          inset: "-10% -20% auto -20%",
          height: "80%",
          background:
            "radial-gradient(ellipse at 25% 30%, rgba(232,163,61,0.18), transparent 55%), radial-gradient(ellipse at 80% 60%, rgba(232,163,61,0.10), transparent 55%)",
        }}
      />
      <div className="relative z-[1] mx-auto w-[min(1200px,100%-48px)] grid items-center gap-[60px] md:gap-20 lg:grid-cols-[1.1fr_1fr]">
        <div>
          <div className="hero-reveal inline-flex items-center gap-2 py-1.5 pl-2 pr-3 rounded-full bg-white border border-line text-[12px] font-medium text-ink-muted tracking-[-0.005em] shadow-tile-sm">
            <span className="w-3.5 h-3.5 rounded-full bg-amber grid place-items-center">
              <span className="w-1 h-1 rounded-full bg-[#1a1a1a] block" />
            </span>
            <span>New — voice-first time tracking</span>
          </div>

          <h1 className="hero-reveal d2 mt-[22px] mb-[18px] font-semibold tracking-[-0.035em] leading-[0.98] text-ink text-[clamp(44px,6.5vw,76px)]">
            Speak your time.
            <br />
            <em className="font-serif italic font-normal text-amber-deep tracking-[-0.01em]">
              See your day.
            </em>
          </h1>

          <p className="hero-reveal d3 max-w-[480px] mb-8 text-ink-muted leading-[1.55] text-[clamp(16px,1.4vw,19px)]">
            Cronwatch turns a sentence into a structured time entry. Hold the mic, talk like a person, and watch your day fill in — every fifteen minutes accounted for, nothing fudged.
          </p>

          <div className="hero-reveal d4 flex gap-3 flex-wrap items-center">
            <StoreButtons />
          </div>

          <div className="hero-reveal d5 mt-7 flex items-center gap-2 text-[13px] font-medium text-ink-muted">
            <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor" aria-hidden className="text-ink">
              <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z" />
            </svg>
            <span>
              Free and open source —{" "}
              <a
                href={GITHUB_URL}
                target="_blank"
                rel="noopener"
                className="text-ink underline underline-offset-2 decoration-line hover:decoration-ink transition-colors"
              >
                view the code on GitHub
              </a>
            </span>
          </div>
        </div>

        <div className="relative flex justify-center items-center min-h-[560px] md:min-h-[620px]">
          <div
            aria-hidden
            className="absolute left-1/2 top-1/2 w-[480px] h-[480px] -translate-x-1/2 -translate-y-1/2 z-0"
            style={{
              background:
                "radial-gradient(circle, rgba(232,163,61,0.22), transparent 60%)",
              filter: "blur(20px)",
            }}
          />
          <PhoneMock />
          <FloatCards />
        </div>
      </div>
    </section>
  );
}
