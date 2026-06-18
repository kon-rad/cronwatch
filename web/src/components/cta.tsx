import { CtaClock } from "./cta-clock";
import { StoreButtons } from "./store-buttons";

export function Cta() {
  return (
    <div className="reveal bg-ink text-white rounded-[32px] py-12 px-7 md:py-[72px] md:px-14 relative overflow-hidden mb-20">
      <div
        aria-hidden
        className="absolute -right-[120px] -top-[120px] w-[380px] h-[380px] rounded-full"
        style={{
          background: "radial-gradient(circle, rgba(232,163,61,0.35), transparent 60%)",
        }}
      />
      <div className="grid gap-10 lg:grid-cols-[1.2fr_1fr] items-center relative z-[1]">
        <div>
          <h2 className="text-[clamp(32px,4vw,48px)] font-semibold tracking-[-0.025em] leading-[1.05] m-0 mb-3">
            Your time is <em className="font-serif italic font-normal text-amber">yours.</em>
            <br />
            Start tracking it like it.
          </h2>
          <p className="text-[16px] text-white/70 m-0 mb-7 max-w-[480px] leading-[1.55]">
            Available on iOS. Free to try, no credit card required.
          </p>
          <div className="flex gap-3 flex-wrap items-center">
            <StoreButtons variant="light" />
          </div>
        </div>
        <CtaClock />
      </div>
    </div>
  );
}
