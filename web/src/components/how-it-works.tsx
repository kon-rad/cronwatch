export function HowItWorks() {
  return (
    <section id="how" className="pt-0 pb-20 md:pb-[120px]">
      <div className="mx-auto w-[min(1200px,100%-48px)]">
        <div className="reveal max-w-[720px] mb-16">
          <div className="text-[12px] font-semibold uppercase tracking-[0.12em] text-amber-deep mb-4">
            How it works
          </div>
          <h2 className="text-[clamp(34px,4.4vw,52px)] font-semibold tracking-[-0.025em] leading-[1.05] m-0 mb-4">
            Three taps. <em className="font-serif italic font-normal text-amber-deep">That&rsquo;s it.</em>
          </h2>
          <p className="text-[18px] text-ink-muted m-0 max-w-[580px] leading-[1.55]">
            No projects to set up. No timers to forget. Open the app, hold the mic, get on with your day.
          </p>
        </div>

        <div className="reveal-stagger grid gap-6 grid-cols-1 md:grid-cols-3">
          <Step
            num="01"
            title="Hold the mic."
            text="One persistent button across every screen. No menus, no navigation, no forms."
            visual={
              <div className="flex items-center gap-3.5">
                <div className="w-14 h-14 rounded-[28px] bg-amber grid place-items-center shadow-[0_6px_18px_rgba(232,163,61,0.35)]">
                  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#1a1a1a" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="9" y="3" width="6" height="12" rx="3" />
                    <path d="M5 11a7 7 0 0 0 14 0" />
                    <path d="M12 18v3" />
                  </svg>
                </div>
                <div className="font-mono text-[12px] text-caption">HOLD&nbsp;TO&nbsp;RECORD</div>
              </div>
            }
          />
          <Step
            num="02"
            title="Speak naturally."
            text='"Spent the last hour on the new onboarding flow." That&rsquo;s the whole interaction.'
            visual={
              <div className="block w-full">
                <div className="text-[14px] text-ink leading-[1.45] tracking-[-0.01em]">
                  &ldquo;Half-hour run along the river
                  <span className="inline-block w-0.5 h-[14px] bg-amber align-middle ml-px animate-blink" />
                </div>
                <div className="font-mono text-[11px] text-caption mt-2 tracking-[0.04em]">
                  → Exercise · 30m · 7:00 AM
                </div>
              </div>
            }
          />
          <Step
            num="03"
            title="See it placed."
            text="Cronwatch parses the duration, picks the category, and drops it onto your timeline — all in under a second."
            visual={
              <div className="w-full px-3 py-2.5 bg-[#F3ECEA] rounded-lg flex items-center gap-2 text-[12px] font-semibold text-[#6E4339] tracking-[-0.01em]">
                <span className="w-1.5 h-1.5 rounded-full bg-[#B07469]" />
                Exercise · River run
                <span className="num ml-auto font-medium opacity-60">30m</span>
              </div>
            }
          />
        </div>
      </div>
    </section>
  );
}

function Step({
  num,
  title,
  text,
  visual,
}: {
  num: string;
  title: string;
  text: string;
  visual: React.ReactNode;
}) {
  return (
    <div className="bg-white border border-line rounded-[22px] p-7 sm:p-8 relative overflow-hidden">
      <div className="font-serif text-[64px] italic font-normal text-amber leading-[0.9] tracking-[-0.02em]">
        {num}
      </div>
      <h3 className="mt-4 mb-2 text-[22px] font-semibold tracking-[-0.02em]">
        {title}
      </h3>
      <p className="m-0 text-[14px] text-ink-muted leading-[1.55]">{text}</p>
      <div className="mt-6 h-[110px] border-t border-line-soft pt-5 flex items-center">
        {visual}
      </div>
    </div>
  );
}
