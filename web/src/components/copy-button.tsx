"use client";

import { useState } from "react";

export function CopyButton({ text, label = "Copy" }: { text: string; label?: string }) {
  const [copied, setCopied] = useState(false);

  return (
    <button
      type="button"
      onClick={() => {
        navigator.clipboard.writeText(text).then(() => {
          setCopied(true);
          setTimeout(() => setCopied(false), 1800);
        });
      }}
      className="inline-flex items-center gap-1.5 rounded-md border border-line bg-white px-2.5 py-1 text-[12px] font-medium text-ink-muted transition-colors hover:text-ink hover:border-amber-soft"
    >
      {copied ? "Copied" : label}
    </button>
  );
}
