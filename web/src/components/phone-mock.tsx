type Entry = {
  start: number;
  end: number;
  cat: string;
  note: string;
  bg: string;
  ink: string;
  dot: string;
};

const SLOT = 22;
const START_H = 8;
const END_H = 18;
const NOW_HOURS = 11.5;

const ENTRIES: Entry[] = [
  { start: 8 * 60 + 30, end: 10 * 60 + 45, cat: "Deep", note: "Onboarding flow", bg: "#E9EEF3", ink: "#3D5066", dot: "#6F89A8" },
  { start: 10 * 60 + 45, end: 11 * 60, cat: "Meeting", note: "Standup", bg: "#F2EDE6", ink: "#5C4A2E", dot: "#9C7E4F" },
  { start: 11 * 60, end: 11 * 60 + 15, cat: "Break", note: "Coffee", bg: "#EFF1EE", ink: "#4D5B4A", dot: "#84957F" },
  { start: 11 * 60 + 15, end: 12 * 60 + 30, cat: "Work", note: "Inbox & reviews", bg: "#EEF1ED", ink: "#3F5440", dot: "#7B9075" },
  { start: 12 * 60 + 30, end: 13 * 60 + 15, cat: "Meal", note: "Lunch", bg: "#F4EFE6", ink: "#6B5530", dot: "#A88752" },
  { start: 13 * 60 + 30, end: 16 * 60, cat: "Deep", note: "Capture sheet anim.", bg: "#E9EEF3", ink: "#3D5066", dot: "#6F89A8" },
  { start: 16 * 60, end: 17 * 60, cat: "Study", note: "DDIA, ch.7", bg: "#F0EEF5", ink: "#4E456B", dot: "#8579A8" },
];

function formatDur(min: number) {
  const h = Math.floor(min / 60);
  const m = min % 60;
  if (h && m) return `${h}h ${m}m`;
  if (h) return `${h}h`;
  return `${m}m`;
}

function ScheduleGrid() {
  const slots = (END_H - START_H) * 4;
  const rows = [];
  for (let i = 0; i < slots; i++) {
    const min = START_H * 60 + i * 15;
    const onHour = min % 60 === 0;
    const hh = Math.floor(min / 60);
    rows.push(
      <div key={i} className="flex h-[22px] items-stretch relative">
        <div className="w-11 pr-2 text-right shrink-0 text-[10px] font-medium text-caption num flex items-start justify-end">
          {onHour ? `${String(hh).padStart(2, "0")}:00` : ""}
        </div>
        <div className="flex-1 px-1 relative">
          {onHour && (
            <div className="absolute left-1 right-1 top-0 border-t border-dashed border-line" />
          )}
        </div>
      </div>,
    );
  }

  const nowTop = (NOW_HOURS - START_H) * 4 * SLOT;

  return (
    <div className="px-3.5 pt-0 relative overflow-hidden" style={{ height: "calc(100% - 200px)" }}>
      {rows}
      <div className="absolute left-[58px] right-1 top-0 pointer-events-none">
        {ENTRIES.map((e, idx) => {
          const top = ((e.start - START_H * 60) / 15) * SLOT + 1;
          const height = ((e.end - e.start) / 15) * SLOT - 2;
          return (
            <div
              key={idx}
              className="absolute left-1 right-1 px-2.5 py-1.5 rounded-lg text-[11px] font-semibold tracking-[-0.01em] flex items-start gap-1.5 overflow-hidden"
              style={{ top, height, background: e.bg, color: e.ink }}
            >
              <span
                className="w-[5px] h-[5px] rounded-full shrink-0 mt-[5px]"
                style={{ background: e.dot }}
              />
              <span className="flex-1 min-w-0 leading-[1.25] whitespace-nowrap overflow-hidden text-ellipsis">
                {e.cat}
                <span className="font-[450] opacity-70"> · {e.note}</span>
              </span>
              <span className="text-[9px] font-medium opacity-60 shrink-0 pt-[1px] num">
                {formatDur(e.end - e.start)}
              </span>
            </div>
          );
        })}
        <div
          className="absolute left-14 right-4 h-[1.5px] bg-amber z-[3]"
          style={{ top: nowTop }}
        >
          <span className="absolute -left-2 -top-[3.5px] w-2 h-2 rounded-full bg-amber animate-pulse-dot" />
        </div>
      </div>
    </div>
  );
}

export function PhoneMock() {
  return (
    <div className="phone-reveal relative z-[2] w-[320px] h-[660px] rounded-[52px] bg-[#1a1a1a] p-3 shadow-[0_0_0_1px_rgba(0,0,0,0.08),0_30px_60px_-20px_rgba(40,30,10,0.35),0_60px_120px_-30px_rgba(40,30,10,0.25)] -rotate-2 transition-transform duration-[600ms] ease-[cubic-bezier(0.2,0.9,0.3,1)]">
      <div className="relative w-full h-full rounded-[40px] bg-bg overflow-hidden">
        {/* Notch */}
        <div className="absolute top-2 left-1/2 -translate-x-1/2 w-[100px] h-7 rounded-[14px] bg-[#1a1a1a] z-[5]" />
        {/* Status bar */}
        <div className="h-11 px-[22px] pb-1.5 flex items-end justify-between text-[14px] font-semibold text-ink">
          <span className="num">9:41</span>
          <span className="flex items-center gap-[5px]">
            <svg width="17" height="11" viewBox="0 0 17 11" fill="currentColor">
              <rect x="0" y="7" width="3" height="4" rx="0.5" />
              <rect x="4" y="5" width="3" height="6" rx="0.5" />
              <rect x="8" y="3" width="3" height="8" rx="0.5" />
              <rect x="12" y="0" width="3" height="11" rx="0.5" />
            </svg>
            <svg width="15" height="11" viewBox="0 0 15 11" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round">
              <path d="M1 4.5C3 3 5 2 7.5 2s4.5 1 6.5 2.5" />
              <path d="M3 7C4.5 6 6 5.3 7.5 5.3s3 .7 4.5 1.7" />
              <path d="M5.5 9.3c.6-.5 1.3-.8 2-.8s1.4.3 2 .8" />
            </svg>
            <svg width="25" height="11" viewBox="0 0 25 11" fill="none">
              <rect x="0.5" y="0.5" width="22" height="10" rx="2.5" stroke="currentColor" opacity="0.4" />
              <rect x="2" y="2" width="19" height="7" rx="1.5" fill="currentColor" />
              <rect x="23" y="3.5" width="1.5" height="4" rx="0.7" fill="currentColor" opacity="0.5" />
            </svg>
          </span>
        </div>
        {/* Today header */}
        <div className="px-[22px] pt-3 pb-3.5">
          <div className="text-[22px] font-semibold tracking-[-0.02em] leading-[1.1]">Tuesday, May 5</div>
          <div className="mt-1 text-[12px] text-caption font-medium">
            <span className="num">7h 30m</span> tracked · <span className="num">16h 30m</span> open
          </div>
        </div>
        <ScheduleGrid />
        {/* FAB */}
        <div className="absolute right-[18px] bottom-[92px] w-14 h-14 rounded-[28px] bg-amber grid place-items-center z-[6] animate-fab-float">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#1a1a1a" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
            <rect x="9" y="3" width="6" height="12" rx="3" />
            <path d="M5 11a7 7 0 0 0 14 0" />
            <path d="M12 18v3" />
          </svg>
        </div>
        {/* Bottom nav */}
        <div className="absolute bottom-0 left-0 right-0 h-20 pt-2 pb-6 bg-[rgba(250,250,247,0.92)] backdrop-blur-md border-t border-line flex z-[5]">
          <BNavItem
            label="Overview"
            icon={
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                <path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z" />
              </svg>
            }
          />
          <BNavItem
            label="Today"
            active
            icon={
              <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                <rect x="3" y="5" width="18" height="16" rx="2" />
                <path d="M3 9h18M8 3v4M16 3v4" stroke="#FAFAF7" strokeWidth="1.5" fill="none" />
              </svg>
            }
          />
          <BNavItem
            label="Profile"
            icon={
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                <circle cx="12" cy="8" r="4" />
                <path d="M4 21a8 8 0 0 1 16 0" />
              </svg>
            }
          />
        </div>
      </div>
    </div>
  );
}

function BNavItem({
  label,
  icon,
  active,
}: {
  label: string;
  icon: React.ReactNode;
  active?: boolean;
}) {
  return (
    <div
      className={`flex-1 flex flex-col items-center gap-[3px] text-[9.5px] font-medium ${
        active ? "text-amber" : "text-caption"
      }`}
    >
      {icon}
      <span>{label}</span>
    </div>
  );
}
