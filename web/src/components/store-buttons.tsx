type StoreButtonsProps = {
  variant?: "dark" | "light";
};

export function StoreButtons({ variant = "dark" }: StoreButtonsProps) {
  const dark = variant === "dark";
  const bg = dark ? "bg-[#1a1a1a]" : "bg-white";
  const nameColor = dark ? "text-white" : "text-[#1a1a1a]";
  const labelColor = dark ? "text-white/75" : "text-black/60";
  const fill = dark ? "#fff" : "#1a1a1a";

  const linkClasses = `${bg} h-[52px] px-[18px] rounded-xl inline-flex items-center gap-3 cursor-pointer leading-[1.1] transition-transform duration-150 hover:-translate-y-px hover:shadow-[0_10px_24px_rgba(0,0,0,0.18)]`;
  const labelClasses = `text-[10px] uppercase tracking-[0.04em] leading-[1.1] ${labelColor}`;
  const nameClasses = `text-[16px] font-semibold tracking-[-0.01em] leading-[1.1] ${nameColor}`;

  return (
    <>
      <a href="#" className={linkClasses}>
        <svg width="22" height="22" viewBox="0 0 24 24" fill={fill}>
          <path d="M16.5 12.6c0-2.5 2-3.7 2.1-3.8-1.2-1.7-3-1.9-3.7-1.9-1.5-.2-3 .9-3.8.9-.8 0-2-.9-3.3-.9-1.7 0-3.3 1-4.2 2.5-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.2 2.5 1.3-.1 1.8-.8 3.4-.8s2 .8 3.3.8c1.4 0 2.3-1.2 3.1-2.5.6-.9 1.1-1.9 1.4-2.9-1.4-.6-2.8-2-2.8-4.1zM14.6 5.3c.7-.9 1.2-2.1 1-3.3-1.1.1-2.4.7-3.1 1.6-.7.8-1.3 2-1.1 3.2 1.2.1 2.4-.6 3.2-1.5z" />
        </svg>
        <span className="flex flex-col gap-px leading-[1.1] whitespace-nowrap">
          <span className={labelClasses}>Download on the</span>
          <span className={nameClasses}>App Store</span>
        </span>
      </a>
      <a href="#" className={linkClasses}>
        <svg width="22" height="22" viewBox="0 0 24 24">
          <path d="M3.6 2.3v19.4l10.5-9.7z" fill={fill} />
          <path d="M3.6 2.3l10.5 9.7L17.7 8.5z" fill={fill} opacity="0.85" />
          <path d="M3.6 21.7l10.5-9.7 3.6 3.5z" fill={fill} opacity="0.7" />
          <path d="M14.1 12l3.6 3.5 3.5-2c1.1-.6 1.1-2.4 0-3.0l-3.5-2z" fill={fill} opacity="0.55" />
        </svg>
        <span className="flex flex-col gap-px leading-[1.1] whitespace-nowrap">
          <span className={labelClasses}>Get it on</span>
          <span className={nameClasses}>Google Play</span>
        </span>
      </a>
    </>
  );
}
