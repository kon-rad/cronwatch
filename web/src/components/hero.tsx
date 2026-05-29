import { PhoneMock } from "./phone-mock";
import { FloatCards } from "./float-cards";
import { StoreButtons } from "./store-buttons";

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

          <div className="hero-reveal d5 mt-8 flex items-center gap-3.5 text-caption text-[13px] font-medium">
            <div className="flex">
              {[
                "#EEF1ED",
                "#F2EDE6",
                "#F0EEF5",
                "#FBEFD6",
              ].map((c, i) => (
                <div
                  key={i}
                  className="w-[26px] h-[26px] rounded-full border-2 border-bg"
                  style={{ background: c, marginLeft: i === 0 ? 0 : -8 }}
                />
              ))}
            </div>
            <span className="inline-flex gap-px text-amber">
              {Array.from({ length: 5 }).map((_, i) => (
                <svg key={i} width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 2l2.9 6.9L22 10l-5.5 4.8L18 22l-6-3.6L6 22l1.5-7.2L2 10l7.1-1.1z" />
                </svg>
              ))}
            </span>
            <span>
              <strong className="text-ink">4.8</strong> · 12,400+ days tracked
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
