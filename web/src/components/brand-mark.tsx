"use client";

import { useEffect, useRef } from "react";

export function BrandMark() {
  const hourRef = useRef<SVGPathElement | null>(null);
  const minRef = useRef<SVGPathElement | null>(null);

  useEffect(() => {
    const update = () => {
      const d = new Date();
      const h = d.getHours() % 12;
      const m = d.getMinutes();
      const s = d.getSeconds();
      const hourDeg = (h + m / 60) * 30;
      const minDeg = (m + s / 60) * 6;
      hourRef.current?.setAttribute("transform", `rotate(${hourDeg} 12 12)`);
      minRef.current?.setAttribute("transform", `rotate(${minDeg - 90} 12 12)`);
    };
    update();
    const id = setInterval(update, 1000);
    return () => clearInterval(id);
  }, []);

  return (
    <span className="grid h-8 w-8 place-items-center rounded-full bg-amber shadow-[0_1px_0_rgba(0,0,0,0.04),inset_0_-1px_0_rgba(0,0,0,0.06)]">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
        <circle cx="12" cy="12" r="9.2" stroke="#1a1a1a" strokeWidth="1.6" />
        <circle cx="12" cy="12" r="0.9" fill="#1a1a1a" />
        <path
          ref={hourRef}
          d="M12 12 L12 7.2"
          stroke="#1a1a1a"
          strokeWidth="1.8"
          strokeLinecap="round"
        />
        <path
          ref={minRef}
          d="M12 12 L15.6 12"
          stroke="#1a1a1a"
          strokeWidth="1.4"
          strokeLinecap="round"
        />
      </svg>
    </span>
  );
}
