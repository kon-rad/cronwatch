"use client";

import { useEffect, useRef } from "react";

const round = (n: number) => Math.round(n * 1000) / 1000;

const TICKS = Array.from({ length: 60 }, (_, i) => {
  const major = i % 5 === 0;
  const ang = ((i * 6 - 90) * Math.PI) / 180;
  const r1 = major ? 80 : 84;
  const r2 = 88;
  return {
    x1: round(100 + Math.cos(ang) * r1),
    y1: round(100 + Math.sin(ang) * r1),
    x2: round(100 + Math.cos(ang) * r2),
    y2: round(100 + Math.sin(ang) * r2),
    major,
  };
});

export function CtaClock() {
  const hourRef = useRef<SVGLineElement | null>(null);
  const minRef = useRef<SVGLineElement | null>(null);
  const secRef = useRef<SVGLineElement | null>(null);

  useEffect(() => {
    const update = () => {
      const d = new Date();
      const h = d.getHours() % 12;
      const m = d.getMinutes();
      const s = d.getSeconds();
      const hourDeg = (h + m / 60) * 30;
      const minDeg = (m + s / 60) * 6;
      const secDeg = s * 6;
      hourRef.current?.setAttribute("transform", `rotate(${hourDeg} 100 100)`);
      minRef.current?.setAttribute("transform", `rotate(${minDeg} 100 100)`);
      secRef.current?.setAttribute("transform", `rotate(${secDeg} 100 100)`);
    };
    update();
    const id = setInterval(update, 1000);
    return () => clearInterval(id);
  }, []);

  return (
    <div
      className="w-full aspect-square max-w-[320px] ml-auto rounded-full relative"
      style={{
        background: "linear-gradient(180deg, #fffbf1 0%, #fbe9c4 100%)",
        boxShadow: "0 30px 60px rgba(0,0,0,0.4), inset 0 -2px 6px rgba(199,132,42,0.2)",
      }}
    >
      <svg
        viewBox="0 0 200 200"
        className="absolute inset-0 w-full h-full"
      >
        <circle cx="100" cy="100" r="92" fill="#fffdf6" stroke="#C7842A" strokeWidth="4" />
        <circle cx="100" cy="100" r="86" fill="none" stroke="#E8A33D" strokeWidth="0.8" opacity="0.4" />
        <g>
          {TICKS.map((t, i) => (
            <line
              key={i}
              x1={t.x1}
              y1={t.y1}
              x2={t.x2}
              y2={t.y2}
              stroke="#1a1a1a"
              strokeWidth={t.major ? 1.4 : 0.6}
              opacity={t.major ? 0.85 : 0.5}
              strokeLinecap="round"
            />
          ))}
        </g>
        <g fontFamily="var(--font-instrument-serif), serif" fontSize="18" fill="#1a1a1a" textAnchor="middle" fontWeight="400">
          <text x="100" y="32">12</text>
          <text x="166" y="106">3</text>
          <text x="100" y="178">6</text>
          <text x="34" y="106">9</text>
        </g>
        <line ref={hourRef} x1="100" y1="100" x2="100" y2="55" stroke="#1a1a1a" strokeWidth="4" strokeLinecap="round" />
        <line ref={minRef} x1="100" y1="100" x2="100" y2="35" stroke="#1a1a1a" strokeWidth="2.5" strokeLinecap="round" />
        <line ref={secRef} x1="100" y1="100" x2="100" y2="28" stroke="#C7842A" strokeWidth="1.2" strokeLinecap="round" />
        <circle cx="100" cy="100" r="4.5" fill="#1a1a1a" />
        <circle cx="100" cy="100" r="1.5" fill="#C7842A" />
      </svg>
    </div>
  );
}
