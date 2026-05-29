export function Marquee() {
  return (
    <div className="border-y border-line bg-bg py-7 flex items-center justify-center gap-10 flex-wrap text-caption text-[13px] font-medium tracking-[0.04em] uppercase">
      <span>Featured in</span>
      <Sep />
      <span className="font-serif text-[22px] normal-case tracking-normal text-ink-muted">
        The Time Letter
      </span>
      <Sep />
      <span>Product Hunt #1</span>
      <Sep />
      <span className="font-mono normal-case">indie&nbsp;hackers</span>
      <Sep />
      <span>Sidebar.io</span>
      <Sep />
      <span>Minimalist&nbsp;Mac</span>
    </div>
  );
}

function Sep() {
  return <span className="w-1 h-1 rounded-full bg-line block" />;
}
