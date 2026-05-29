const STREAK_DAYS = [0.4, 0.7, 0.5, 0.8, 0.9, 0, 0.6, 0.85, 0.7, 1, 0.9, 0.5];

function streakColor(v: number) {
  if (v === 0) return "#F2F2EF";
  const intensity = Math.round(v * 100);
  return `color-mix(in srgb, #E8A33D ${intensity}%, #FBEFD6)`;
}

export function FloatCards() {
  return (
    <>
      {/* Capture card */}
      <div className="absolute top-[120px] -left-5 lg:-left-2.5 hidden md:flex bg-white border border-line rounded-[14px] py-3.5 px-4 shadow-tile-md items-center gap-3 z-[3] animate-float-up">
        <div className="w-9 h-9 rounded-[10px] bg-amber-faint grid place-items-center">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#C7842A" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
            <rect x="9" y="3" width="6" height="12" rx="3" />
            <path d="M5 11a7 7 0 0 0 14 0" />
            <path d="M12 18v3" />
          </svg>
        </div>
        <div className="text-[13px] leading-[1.3]">
          <strong className="font-semibold tracking-[-0.01em]">&ldquo;Quick coffee, 15 min.&rdquo;</strong>
          <div className="text-[11px] text-caption mt-0.5">Logged · just now</div>
        </div>
      </div>

      {/* Streak card */}
      <div
        className="absolute bottom-[120px] -right-7 lg:-right-2.5 hidden md:flex bg-white border border-line rounded-[14px] py-3.5 px-4 shadow-tile-md flex-col items-start gap-2 z-[3] animate-float-up"
        style={{ animationDelay: "1s" }}
      >
        <div className="flex items-baseline gap-2">
          <span className="text-[22px] font-semibold tracking-[-0.02em] num">14</span>
          <span className="text-[11px] text-caption font-medium">day streak</span>
        </div>
        <div className="flex gap-[3px]">
          {STREAK_DAYS.map((v, i) => (
            <span
              key={i}
              className="w-3 h-[22px] rounded-[3px]"
              style={{ background: streakColor(v) }}
            />
          ))}
        </div>
      </div>
    </>
  );
}
