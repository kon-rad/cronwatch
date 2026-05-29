"use client";

import { useEffect, useRef, useState } from "react";

const PHRASES = [
  "Spent the last 45 minutes in deep focus on the API.",
  "Half-hour run along the river, felt great.",
  "Quick coffee break — fifteen minutes.",
  "Met with the design team about the roadmap, 30 mins.",
];

const round = (n: number) => Math.round(n * 1000) / 1000;

const WAVE_BARS = Array.from({ length: 36 }, (_, i) => {
  const seed = (Math.sin(i * 1.7) + 1) / 2;
  const baseH = round(6 + seed * 22);
  const dur = round(0.6 + seed * 0.6);
  return { h: baseH, dur, delay: round(i * 0.04) };
});

export function VoiceCard() {
  const [text, setText] = useState("");
  const phraseIdx = useRef(0);
  const charIdx = useRef(0);
  const phase = useRef<"typing" | "pause" | "deleting">("typing");

  useEffect(() => {
    let timeoutId: ReturnType<typeof setTimeout>;
    const tick = () => {
      const phrase = PHRASES[phraseIdx.current];
      if (phase.current === "typing") {
        charIdx.current++;
        setText(phrase.slice(0, charIdx.current));
        if (charIdx.current >= phrase.length) {
          phase.current = "pause";
          timeoutId = setTimeout(tick, 1700);
          return;
        }
        timeoutId = setTimeout(tick, 30 + Math.random() * 50);
      } else if (phase.current === "pause") {
        phase.current = "deleting";
        timeoutId = setTimeout(tick, 200);
      } else {
        charIdx.current -= 2;
        if (charIdx.current <= 0) {
          charIdx.current = 0;
          phase.current = "typing";
          phraseIdx.current = (phraseIdx.current + 1) % PHRASES.length;
          timeoutId = setTimeout(tick, 350);
          return;
        }
        setText(phrase.slice(0, charIdx.current));
        timeoutId = setTimeout(tick, 14);
      }
    };
    tick();
    return () => clearTimeout(timeoutId);
  }, []);

  return (
    <div className="absolute left-1/2 bottom-[30px] -translate-x-1/2 w-[calc(100%-56px)] max-w-[400px] bg-white border border-line rounded-[18px] pt-[22px] pr-[22px] pl-[22px] pb-[26px] shadow-tile-md">
      <div className="text-[14px] text-ink leading-[1.4] min-h-[44px] tracking-[-0.01em]">
        <span>{text}</span>
        <span className="inline-block w-0.5 h-[14px] bg-amber ml-px align-middle animate-blink" />
      </div>
      <div className="mt-3.5 flex items-center gap-[3px] h-7">
        {WAVE_BARS.map((b, i) => (
          <div
            key={i}
            className="w-[3px] rounded-[2px] bg-amber"
            style={{
              height: `${b.h}px`,
              animation: `wave ${b.dur}s ease-in-out ${b.delay}s infinite`,
            }}
          />
        ))}
      </div>
    </div>
  );
}
