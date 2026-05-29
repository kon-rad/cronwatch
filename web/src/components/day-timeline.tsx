type Item = {
  time: string;
  cat: string;
  note: string;
  dur: string;
  dot: string;
  catColor: string;
};

const ITEMS: Item[] = [
  { time: "7:00 AM", cat: "Exercise", note: "River run, half-hour", dur: "30m", dot: "#B07469", catColor: "#6E4339" },
  { time: "8:30 AM", cat: "Deep", note: "Onboarding redesign", dur: "2h 15m", dot: "#6F89A8", catColor: "#3D5066" },
  { time: "10:45", cat: "Meeting", note: "Standup with the team", dur: "15m", dot: "#9C7E4F", catColor: "#5C4A2E" },
  { time: "11:00", cat: "Break", note: "Coffee & a chapter", dur: "15m", dot: "#84957F", catColor: "#4D5B4A" },
  { time: "12:30 PM", cat: "Meal", note: "Lunch — soba, leftovers", dur: "45m", dot: "#A88752", catColor: "#6B5530" },
  { time: "2:00", cat: "Work", note: "Inbox & PR reviews", dur: "1h 30m", dot: "#7B9075", catColor: "#3F5440" },
  { time: "4:00", cat: "Study", note: "Designing Data-Intensive Apps", dur: "1h", dot: "#8579A8", catColor: "#4E456B" },
  { time: "7:30", cat: "Entertain", note: "Watched two episodes", dur: "1h 30m", dot: "#9C7686", catColor: "#5E4350" },
];

export function DayTimeline() {
  return (
    <section className="py-20 md:py-[120px] bg-bg-cream border-y border-line">
      <div className="mx-auto w-[min(1200px,100%-48px)]">
        <div className="reveal max-w-[720px] mb-16">
          <div className="text-[12px] font-semibold uppercase tracking-[0.12em] text-amber-deep mb-4">
            A day, in Cronwatch
          </div>
          <h2 className="text-[clamp(34px,4.4vw,52px)] font-semibold tracking-[-0.025em] leading-[1.05] m-0 mb-4">
            What Tuesday <em className="font-serif italic font-normal text-amber-deep">looked&nbsp;like.</em>
          </h2>
          <p className="text-[18px] text-ink-muted m-0 max-w-[580px] leading-[1.55]">
            Eight things, said out loud across a working day. Eight rows on the grid. No editing required.
          </p>
        </div>

        <div className="reveal-stagger relative pl-[50px] sm:pl-[60px]">
          <div className="absolute left-6 sm:left-8 top-2 bottom-2 w-px bg-line" />
          {ITEMS.map((it, i) => (
            <div
              key={i}
              className={`grid grid-cols-[70px_1fr] sm:grid-cols-[100px_1fr] gap-4 sm:gap-6 py-6 items-center ${
                i < ITEMS.length - 1 ? "border-b border-line-soft" : ""
              }`}
            >
              <div className="num text-[14px] sm:text-[18px] font-medium text-ink-muted tracking-[-0.01em] relative">
                <span className="absolute -left-7 sm:-left-9 top-1/2 -translate-y-1/2 w-2.5 h-2.5 rounded-full bg-white border-2 border-amber" />
                {it.time}
              </div>
              <div className="bg-white border border-line rounded-[14px] py-4 px-5 flex items-center gap-3.5 transition-transform duration-200 hover:translate-x-1">
                <span className="w-2 h-2 rounded-full shrink-0" style={{ background: it.dot }} />
                <div>
                  <div
                    className="text-[12px] font-semibold tracking-[0.04em] uppercase"
                    style={{ color: it.catColor }}
                  >
                    {it.cat}
                  </div>
                  <div className="text-[15px] font-medium text-ink tracking-[-0.01em]">
                    {it.note}
                  </div>
                </div>
                <div className="ml-auto text-[13px] text-caption font-medium num">
                  {it.dur}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
