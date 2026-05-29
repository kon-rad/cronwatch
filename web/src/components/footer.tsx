import { BrandMark } from "./brand-mark";

export function Footer() {
  return (
    <footer className="text-caption text-[13px] border-t border-line">
      <div className="grid gap-8 md:gap-10 grid-cols-2 md:grid-cols-[2fr_1fr_1fr_1fr] py-14">
        <div>
          <a href="#" className="flex items-center gap-2.5 font-semibold tracking-[-0.02em] text-[17px] text-ink mb-4">
            <BrandMark />
            <span>Cronwatch</span>
          </a>
          <p className="m-0 max-w-[280px] leading-[1.55]">
            Voice-first time tracking. Made quietly, in a small studio, with care.
          </p>
        </div>
        <FooterCol heading="Product" links={[
          { label: "Features", href: "#features" },
          { label: "How it works", href: "#how" },
          { label: "Pricing", href: "#pricing" },
          { label: "Changelog", href: "#" },
        ]} />
        <FooterCol heading="Company" links={[
          { label: "About", href: "#" },
          { label: "Blog", href: "/blog" },
          { label: "Press kit", href: "#" },
          { label: "Support", href: "/support" },
        ]} />
        <FooterCol heading="Legal" links={[
          { label: "Privacy", href: "/privacy" },
          { label: "Terms", href: "/terms" },
        ]} />
      </div>
      <div className="flex justify-between items-center pt-7 pb-14 border-t border-line-soft">
        <span>© 2026 Cronwatch. Made quietly.</span>
        <span className="font-mono text-[12px]">v1.4.0</span>
      </div>
    </footer>
  );
}

function FooterCol({
  heading,
  links,
}: {
  heading: string;
  links: { label: string; href: string }[];
}) {
  return (
    <div>
      <h4 className="text-[12px] uppercase tracking-[0.08em] m-0 mb-4 text-ink font-semibold">
        {heading}
      </h4>
      {links.map((l) => (
        <a
          key={l.label}
          href={l.href}
          className="block py-1 text-ink-muted text-[14px] hover:text-ink transition-colors"
          style={{ fontWeight: 450 }}
        >
          {l.label}
        </a>
      ))}
    </div>
  );
}
