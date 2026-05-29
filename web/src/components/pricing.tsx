export function Pricing() {
  return (
    <section id="pricing" className="py-20 md:py-[120px]">
      <div className="mx-auto w-[min(1200px,100%-48px)]">
        <div className="reveal max-w-[720px] mb-16 text-center mx-auto">
          <div className="text-[12px] font-semibold uppercase tracking-[0.12em] text-amber-deep mb-4">
            Pricing
          </div>
          <h2 className="text-[clamp(34px,4.4vw,52px)] font-semibold tracking-[-0.025em] leading-[1.05] m-0 mb-4">
            One subscription. <em className="font-serif italic font-normal text-amber-deep">Two ways.</em>
          </h2>
          <p className="text-[18px] text-ink-muted m-0 max-w-[580px] mx-auto leading-[1.55]">
            All features, all the time. Cancel from your phone, no questions asked.
          </p>
        </div>

        <div className="reveal-stagger grid grid-cols-1 sm:grid-cols-2 gap-[18px] max-w-[720px] mx-auto">
          <Plan
            name="Yearly"
            badge="20% off"
            featured
            price="$39.99"
            unit="/year"
            sub="Just $3.33 a month"
            features={[
              "Unlimited voice capture",
              "15-minute grid & overview",
              "Streaks & weekly digests",
              "Apple Watch & Wear OS",
              "Export to CSV / iCal",
            ]}
            cta="Start free for 7 days"
            ctaVariant="amber"
          />
          <Plan
            name="Weekly"
            price="$3.99"
            unit="/week"
            sub="Try it for a week"
            features={["Everything in Yearly", "Cancel anytime", "No long commitment"]}
            cta="Choose weekly"
            ctaVariant="ghost"
          />
        </div>
      </div>
    </section>
  );
}

type PlanProps = {
  name: string;
  badge?: string;
  featured?: boolean;
  price: string;
  unit: string;
  sub: string;
  features: string[];
  cta: string;
  ctaVariant: "amber" | "ghost";
};

function Plan({
  name,
  badge,
  featured,
  price,
  unit,
  sub,
  features,
  cta,
  ctaVariant,
}: PlanProps) {
  return (
    <div
      className={`bg-white border-[1.5px] rounded-[22px] p-8 flex flex-col transition-all duration-200 ${
        featured
          ? "border-amber bg-gradient-to-b from-[#FFFBF1] to-white"
          : "border-line"
      }`}
    >
      <div className="flex justify-between items-start">
        <div className="text-[14px] font-semibold tracking-[0.02em] uppercase text-ink-muted">
          {name}
        </div>
        {badge && (
          <div className="text-[10px] font-semibold tracking-[0.04em] uppercase bg-amber text-[#1a1a1a] px-2 py-1 rounded-md">
            {badge}
          </div>
        )}
      </div>
      <div className="flex items-baseline gap-1.5 mt-6">
        <span className="text-[56px] font-semibold tracking-[-0.03em] leading-none num">
          {price}
        </span>
        <span className="text-[16px] text-caption font-medium">{unit}</span>
      </div>
      <div className="text-[14px] text-ink-muted mt-1.5">{sub}</div>
      <ul className="list-none p-0 my-7 flex flex-col gap-2.5">
        {features.map((f, i) => (
          <li key={i} className="flex items-center gap-2.5 text-[14px] text-ink">
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="text-amber-deep shrink-0"
            >
              <path d="M5 12.5l4.5 4.5L19 7.5" />
            </svg>
            {f}
          </li>
        ))}
      </ul>
      <button
        className={`w-full justify-center inline-flex items-center gap-2 h-12 rounded-[10px] text-[14px] font-semibold tracking-[-0.01em] transition-all duration-150 active:translate-y-px mt-auto ${
          ctaVariant === "amber"
            ? "bg-amber text-[#1a1a1a] hover:shadow-[0_6px_18px_rgba(232,163,61,0.35)]"
            : "bg-transparent text-ink border border-line hover:bg-white"
        }`}
      >
        {cta}
      </button>
    </div>
  );
}
