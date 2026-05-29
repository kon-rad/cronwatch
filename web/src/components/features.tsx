import { VoiceCard } from "./voice-card";

export function Features() {
  return (
    <section id="features" className="py-20 md:py-[120px]">
      <div className="mx-auto w-[min(1200px,100%-48px)]">
        <SectionHead
          kicker="Features"
          title={
            <>
              Built for the way you <em className="font-serif italic font-normal text-amber-deep">actually</em> talk about your time.
            </>
          }
          description="Most time trackers ask you to remember the start, the stop, the project, the tag. Cronwatch asks you to say what you did. Everything else is figured out."
        />

        <div className="reveal-stagger grid gap-[18px] grid-cols-1 sm:grid-cols-2 lg:grid-cols-[1.4fr_1fr_1fr] lg:[grid-template-rows:320px_320px]">
          {/* Voice — spans col 1, both rows */}
          <BentoTile className="lg:row-span-2 bg-gradient-to-b from-[#FFFCF5] to-[#FBF6E8] min-h-[360px] lg:min-h-0">
            <FeatHead
              title="Voice capture, structured out."
              text='Hold the mic and speak naturally — "spent the last 45 minutes in deep focus on the API." Cronwatch parses the duration, infers the category, and drops it into your day.'
            />
            <VoiceCard />
          </BentoTile>

          {/* 15-min grid */}
          <BentoTile className="min-h-[320px] lg:min-h-0">
            <FeatHead
              title="A 15-minute grid."
              text="Every block earns its place — or shows up empty."
            />
            <GridMini />
          </BentoTile>

          {/* Overview */}
          <BentoTile className="min-h-[320px] lg:min-h-0">
            <FeatHead
              title="Overview, at a glance."
              text="A weekly read on where it all goes."
            />
            <DonutMini />
            <div className="absolute bottom-6 left-6 right-6 flex items-center gap-2 px-2.5 py-2 bg-[#EEF1ED] rounded-lg text-[11px] font-semibold text-[#3F5440] tracking-[-0.01em]">
              <span className="w-1.5 h-1.5 rounded-full bg-[#7B9075]" />
              Most: Work · 4h 20m
            </div>
          </BentoTile>

          {/* Privacy */}
          <BentoTile className="min-h-[320px] lg:min-h-0">
            <FeatHead
              title="Private by default."
              text="On-device. No analytics, no ads, no resold data."
            />
            <LockArt />
          </BentoTile>

          {/* Categories */}
          <BentoTile className="min-h-[320px] lg:min-h-0">
            <FeatHead
              title="Categories that fit your life."
              text="Eleven defaults, considered. All editable."
            />
            <CategoryChips />
          </BentoTile>
        </div>
      </div>
    </section>
  );
}

function SectionHead({
  kicker,
  title,
  description,
}: {
  kicker: string;
  title: React.ReactNode;
  description: string;
}) {
  return (
    <div className="reveal max-w-[720px] mb-16">
      <div className="text-[12px] font-semibold uppercase tracking-[0.12em] text-amber-deep mb-4">
        {kicker}
      </div>
      <h2 className="text-[clamp(34px,4.4vw,52px)] font-semibold tracking-[-0.025em] leading-[1.05] m-0 mb-4">
        {title}
      </h2>
      <p className="text-[18px] text-ink-muted m-0 max-w-[580px] leading-[1.55]">
        {description}
      </p>
    </div>
  );
}

function BentoTile({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`bg-white border border-line rounded-[22px] overflow-hidden relative p-7 transition-all duration-[250ms] hover:-translate-y-0.5 hover:[border-color:#DCD9D2] hover:shadow-tile-md ${className}`}
    >
      {children}
    </div>
  );
}

function FeatHead({ title, text }: { title: string; text: string }) {
  return (
    <>
      <div className="text-[20px] font-semibold tracking-[-0.02em] mb-2">
        {title}
      </div>
      <p className="text-[14px] text-ink-muted leading-[1.5] m-0 max-w-[320px]">
        {text}
      </p>
    </>
  );
}

function GridMini() {
  return (
    <div className="absolute left-6 right-6 bottom-[22px] h-40 overflow-hidden">
      <Row time="09:00">
        <HourLine />
        <Block top={0} h={36} bg="#E9EEF3" color="#3D5066" dot="#6F89A8" label="Deep · API" />
      </Row>
      <Row />
      <Row time="10:00">
        <HourLine />
        <Block top={0} h={18} bg="#F2EDE6" color="#5C4A2E" dot="#9C7E4F" label="Standup" />
      </Row>
      <Row>
        <Block top={0} h={24} bg="#EEF1ED" color="#3F5440" dot="#7B9075" label="Inbox" />
      </Row>
      <Row time="11:00">
        <HourLine />
      </Row>
      <Row>
        <Block top={-6} h={30} bg="#EFF1EE" color="#4D5B4A" dot="#84957F" label="Coffee" />
      </Row>
      <Row time="12:00">
        <HourLine />
      </Row>
    </div>
  );
}

function Row({
  time,
  children,
}: {
  time?: string;
  children?: React.ReactNode;
}) {
  return (
    <div className="flex h-[18px]">
      <div className="w-8 text-[9px] text-caption font-medium pr-1.5 text-right">
        {time}
      </div>
      <div className="flex-1 relative px-0.5">{children}</div>
    </div>
  );
}

function HourLine() {
  return <div className="absolute left-0 right-0 top-0 border-t border-dashed border-line" />;
}

function Block({
  top,
  h,
  bg,
  color,
  dot,
  label,
}: {
  top: number;
  h: number;
  bg: string;
  color: string;
  dot: string;
  label: string;
}) {
  return (
    <div
      className="absolute left-0.5 right-0.5 rounded-md px-2 py-1 text-[10px] font-semibold leading-[1.1] flex items-center gap-1.5"
      style={{ top, height: h, background: bg, color }}
    >
      <span className="w-1 h-1 rounded-full" style={{ background: dot }} />
      {label}
    </div>
  );
}

function DonutMini() {
  return (
    <div className="absolute left-1/2 top-[56%] -translate-x-1/2 -translate-y-1/2">
      <svg width="140" height="140" viewBox="0 0 140 140" style={{ transform: "rotate(-90deg)" }}>
        <circle cx="70" cy="70" r="56" fill="none" stroke="#F2F2EF" strokeWidth="18" />
        <circle cx="70" cy="70" r="56" fill="none" stroke="#6F89A8" strokeWidth="18" strokeDasharray="135 217" strokeDashoffset="0" />
        <circle cx="70" cy="70" r="56" fill="none" stroke="#7B9075" strokeWidth="18" strokeDasharray="80 272" strokeDashoffset="-135" />
        <circle cx="70" cy="70" r="56" fill="none" stroke="#9C7E4F" strokeWidth="18" strokeDasharray="55 297" strokeDashoffset="-215" />
        <circle cx="70" cy="70" r="56" fill="none" stroke="#84957F" strokeWidth="18" strokeDasharray="38 314" strokeDashoffset="-270" />
      </svg>
    </div>
  );
}

function LockArt() {
  return (
    <div className="absolute left-1/2 bottom-9 -translate-x-1/2 w-[120px] h-[120px] grid place-items-center">
      <div className="absolute inset-0 border-[1.5px] border-dashed border-line rounded-full animate-spin-slow" />
      <div className="absolute inset-4 border-[1.5px] border-line-soft rounded-full" />
      <div className="w-14 h-14 rounded-2xl bg-ink grid place-items-center relative">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#FAFAF7" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
          <rect x="4" y="11" width="16" height="10" rx="2" />
          <path d="M8 11V7a4 4 0 0 1 8 0v4" />
        </svg>
      </div>
    </div>
  );
}

function CategoryChips() {
  const chips: Array<{ label: string; bg: string; color: string; dot: string }> = [
    { label: "Work", bg: "#EEF1ED", color: "#3F5440", dot: "#7B9075" },
    { label: "Deep", bg: "#E9EEF3", color: "#3D5066", dot: "#6F89A8" },
    { label: "Meeting", bg: "#F2EDE6", color: "#5C4A2E", dot: "#9C7E4F" },
    { label: "Study", bg: "#F0EEF5", color: "#4E456B", dot: "#8579A8" },
    { label: "Exercise", bg: "#F3ECEA", color: "#6E4339", dot: "#B07469" },
    { label: "Meal", bg: "#F4EFE6", color: "#6B5530", dot: "#A88752" },
    { label: "Break", bg: "#EFF1EE", color: "#4D5B4A", dot: "#84957F" },
    { label: "Entertain", bg: "#F1ECEE", color: "#5E4350", dot: "#9C7686" },
  ];

  return (
    <div className="absolute left-6 right-6 bottom-7 flex flex-wrap gap-1.5">
      {chips.map((c) => (
        <span
          key={c.label}
          className="h-7 px-3 rounded-full inline-flex items-center gap-1.5 text-[12px] font-medium tracking-[-0.01em]"
          style={{ background: c.bg, color: c.color }}
        >
          <span className="w-1.5 h-1.5 rounded-full" style={{ background: c.dot }} />
          {c.label}
        </span>
      ))}
    </div>
  );
}
