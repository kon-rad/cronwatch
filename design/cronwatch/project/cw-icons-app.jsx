// Cronwatch icon explorations — 6 variations.
// Each Icon component renders into a 1024x1024 viewBox. AppIcon wraps it
// in a 22% iOS-style rounded square ("squircle approximation").

const { useState } = React;

// ─────────────────────────────────────────────────────────────
// Icon variations — each takes nothing, renders <g> for 1024 viewbox
// ─────────────────────────────────────────────────────────────

// 1. Classic clock hand on amber — calm, on-brand
function IconClock() {
  return (
    <>
      <rect width="1024" height="1024" fill="#E8A33D" />
      {/* subtle radial sheen */}
      <defs>
        <radialGradient id="cl-sheen" cx="35%" cy="28%" r="80%">
          <stop offset="0%" stopColor="#FFE7B5" stopOpacity="0.5" />
          <stop offset="100%" stopColor="#E8A33D" stopOpacity="0" />
        </radialGradient>
      </defs>
      <rect width="1024" height="1024" fill="url(#cl-sheen)" />
      <circle cx="512" cy="512" r="300" fill="none" stroke="#111" strokeWidth="36" />
      {/* hour ticks at 12,3,6,9 */}
      {[0, 90, 180, 270].map(a => (
        <rect
          key={a}
          x="506" y="232" width="12" height="34" rx="6" fill="#111"
          transform={`rotate(${a} 512 512)`}
        />
      ))}
      {/* hands at ~10:08 — friendly classic clock pose */}
      <line x1="512" y1="512" x2="512" y2="312" stroke="#111" strokeWidth="34" strokeLinecap="round" />
      <line x1="512" y1="512" x2="660" y2="430" stroke="#111" strokeWidth="34" strokeLinecap="round" />
      <circle cx="512" cy="512" r="22" fill="#111" />
    </>
  );
}

// 2. Voice waveform inside circle — speak your time
function IconWave() {
  return (
    <>
      <rect width="1024" height="1024" fill="#FAFAF7" />
      <circle cx="512" cy="512" r="360" fill="#E8A33D" />
      {/* bars */}
      {[
        [380, 90],  [445, 180], [512, 260],
        [579, 180], [644, 90],
      ].map(([x, h], i) => (
        <rect
          key={i} x={x - 22} y={512 - h} width="44" height={h * 2}
          rx="22" fill="#111"
        />
      ))}
    </>
  );
}

// 3. Time block — a 15-min grid block, the core unit
function IconBlock() {
  return (
    <>
      <rect width="1024" height="1024" fill="#FAFAF7" />
      {/* Faint grid lines */}
      {[1, 2, 3, 4, 5, 6, 7].map(i => (
        <line
          key={'h' + i}
          x1="80" x2="944" y1={128 * i} y2={128 * i}
          stroke="#E5E3DD" strokeWidth="2"
        />
      ))}
      {/* Time gutter */}
      {[
        ['09', 220], ['10', 348], ['11', 476], ['12', 604], ['13', 732],
      ].map(([t, y]) => (
        <text key={t} x="150" y={y} fontFamily="Inter, system-ui" fontSize="42" fontWeight="500" fill="#9A9A95" textAnchor="end">
          {t}:00
        </text>
      ))}
      {/* The block — Deep Work, 1.5h */}
      <rect x="220" y="240" width="680" height="380" rx="44" fill="#E8A33D" />
      <circle cx="290" cy="320" r="14" fill="#111" />
      <text x="320" y="334" fontFamily="Inter, system-ui" fontSize="48" fontWeight="700" fill="#111" letterSpacing="-1">
        Deep work
      </text>
      <text x="290" y="410" fontFamily="Inter, system-ui" fontSize="38" fontWeight="500" fill="#111" opacity="0.7" letterSpacing="-0.5">
        90 min
      </text>
    </>
  );
}

// 4. Pure wordmark — the lowercase "c" as a clock
function IconC() {
  return (
    <>
      <rect width="1024" height="1024" fill="#111" />
      {/* glowing C — open arc with hand */}
      <path
        d="M 760 312 A 280 280 0 1 0 760 712"
        fill="none" stroke="#E8A33D" strokeWidth="80" strokeLinecap="round"
      />
      {/* tick at the open end */}
      <circle cx="760" cy="512" r="20" fill="#E8A33D" />
      {/* small minute hand inside */}
      <line x1="512" y1="512" x2="640" y2="412" stroke="#FAFAF7" strokeWidth="40" strokeLinecap="round" />
      <circle cx="512" cy="512" r="20" fill="#FAFAF7" />
    </>
  );
}

// 5. Day arc — a single day as a 24-hour ring with categories
function IconArc() {
  // Arcs around a circle at r=340, stroke 80
  // Segments (start angle, end angle, color) — start at -90 (top)
  const segs = [
    [0,    100, '#3F4458'], // Sleep (00–07)
    [105,  130, '#A88752'], // Meal/morning
    [135,  220, '#3D5066'], // Deep work
    [225,  255, '#9C7E4F'], // Meeting
    [260,  330, '#7B9075'], // Work
    [335,  360, '#B07469'], // Exercise
  ];
  const r = 340, cx = 512, cy = 512;
  const polar = (deg) => {
    const a = (deg - 90) * Math.PI / 180;
    return [cx + r * Math.cos(a), cy + r * Math.sin(a)];
  };
  const arc = (start, end, color, i) => {
    const [x1, y1] = polar(start);
    const [x2, y2] = polar(end);
    const large = end - start > 180 ? 1 : 0;
    return (
      <path
        key={i}
        d={`M ${x1} ${y1} A ${r} ${r} 0 ${large} 1 ${x2} ${y2}`}
        fill="none" stroke={color} strokeWidth="80" strokeLinecap="butt"
      />
    );
  };
  return (
    <>
      <rect width="1024" height="1024" fill="#FAFAF7" />
      {/* faint ring underneath */}
      <circle cx={cx} cy={cy} r={r} fill="none" stroke="#ECECEA" strokeWidth="80" />
      {segs.map(([s, e, c], i) => arc(s, e, c, i))}
      {/* Now indicator — small amber dot */}
      <circle cx={polar(232)[0]} cy={polar(232)[1]} r="32" fill="#E8A33D" stroke="#FAFAF7" strokeWidth="12" />
      {/* center mark */}
      <text x={cx} y={cx + 22} fontFamily="Instrument Serif, serif" fontSize="200" fill="#111" textAnchor="middle" fontStyle="italic">
        c
      </text>
    </>
  );
}

// 6. Mic + ring — voice-first, very direct
function IconMic() {
  return (
    <>
      <defs>
        <linearGradient id="mc-bg" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#FBEFD6" />
          <stop offset="100%" stopColor="#F5D69A" />
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" fill="url(#mc-bg)" />
      {/* outer ring */}
      <circle cx="512" cy="460" r="240" fill="none" stroke="#111" strokeWidth="28" />
      {/* mic body */}
      <rect x="432" y="280" width="160" height="280" rx="80" fill="#111" />
      {/* mic stand */}
      <line x1="512" y1="700" x2="512" y2="800" stroke="#111" strokeWidth="28" strokeLinecap="round" />
      <line x1="402" y1="800" x2="622" y2="800" stroke="#111" strokeWidth="28" strokeLinecap="round" />
      {/* amber rec dot */}
      <circle cx="512" cy="380" r="34" fill="#E8A33D" />
    </>
  );
}

const VARIATIONS = [
  { id: 'clock',  title: '01 · Classic clock', sub: 'Amber face · friendly', Cmp: IconClock },
  { id: 'wave',   title: '02 · Voice waveform', sub: '"Speak your time"', Cmp: IconWave },
  { id: 'block',  title: '03 · Time block', sub: 'A 15-min grid moment', Cmp: IconBlock },
  { id: 'c',      title: '04 · C-mark', sub: 'Wordmark · dark', Cmp: IconC },
  { id: 'arc',    title: '05 · Day arc', sub: '24h ring of categories', Cmp: IconArc },
  { id: 'mic',    title: '06 · Mic ring', sub: 'Voice-first · direct', Cmp: IconMic },
];

// ─────────────────────────────────────────────────────────────
// Frames
// ─────────────────────────────────────────────────────────────

// AppIcon — the canonical iOS rounded-square at any size
function AppIcon({ size = 220, Cmp }) {
  // iOS 26 squircle approximation = 22.37% radius
  const r = size * 0.2237;
  return (
    <div style={{
      width: size, height: size, borderRadius: r,
      overflow: 'hidden',
      boxShadow: '0 1px 2px rgba(0,0,0,0.08), 0 12px 32px rgba(0,0,0,0.12)',
      background: '#fff',
    }}>
      <svg width={size} height={size} viewBox="0 0 1024 1024">
        <Cmp />
      </svg>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Variation card — large icon + size ladder + label panel
// ─────────────────────────────────────────────────────────────
function VariationCard({ v }) {
  return (
    <div style={{
      width: '100%', height: '100%', background: '#f0eee9',
      padding: 32, boxSizing: 'border-box',
      display: 'flex', flexDirection: 'column', gap: 24,
    }}>
      <div>
        <div style={{ fontSize: 13, fontWeight: 600, color: '#9A9A95', letterSpacing: 0.6, textTransform: 'uppercase' }}>
          {v.title}
        </div>
        <div style={{ fontSize: 18, fontWeight: 500, color: '#111', letterSpacing: -0.3, marginTop: 4 }}>
          {v.sub}
        </div>
      </div>

      <div style={{ display: 'flex', gap: 32, alignItems: 'flex-end' }}>
        <AppIcon size={260} Cmp={v.Cmp} />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <SizeLadder Cmp={v.Cmp} />
        </div>
      </div>

      <HomeScreenStrip Cmp={v.Cmp} v={v} />
    </div>
  );
}

function SizeLadder({ Cmp }) {
  const sizes = [120, 76, 60, 40];
  const labels = ['180', '120', '87', '58'];
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 14 }}>
      {sizes.map((s, i) => (
        <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
          <AppIcon size={s} Cmp={Cmp} />
          <div style={{ fontSize: 10, color: '#9A9A95', fontWeight: 500, letterSpacing: 0.3 }}>
            {labels[i]}px
          </div>
        </div>
      ))}
    </div>
  );
}

// Home-screen strip — shows the icon among neighbors with a label
function HomeScreenStrip({ Cmp }) {
  const neighbors = [
    { bg: '#34C759', glyph: '☎', label: 'Phone' },
    { bg: '#FF3B30', glyph: '✕', label: 'Photos' },
  ];
  return (
    <div style={{
      marginTop: 'auto',
      background: 'linear-gradient(180deg, #2a2a2e 0%, #1a1a1e 100%)',
      borderRadius: 28, padding: '24px 28px',
      display: 'flex', alignItems: 'center', gap: 28,
    }}>
      <IconWithLabel icon={<AppIcon size={62} Cmp={Cmp} />} label="Cronwatch" />
      {neighbors.map((n, i) => (
        <IconWithLabel
          key={i}
          icon={<div style={{
            width: 62, height: 62, borderRadius: 14, background: n.bg,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', fontSize: 28, fontWeight: 600,
            boxShadow: '0 1px 2px rgba(0,0,0,0.1)',
          }}>{n.glyph}</div>}
          label={n.label}
        />
      ))}
      <div style={{ flex: 1 }} />
      <div style={{
        fontSize: 10, fontWeight: 500, color: 'rgba(255,255,255,0.4)',
        letterSpacing: 0.5, textTransform: 'uppercase',
      }}>On home</div>
    </div>
  );
}

function IconWithLabel({ icon, label }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
      {icon}
      <div style={{ fontSize: 11, color: '#fff', fontWeight: 450, letterSpacing: -0.1 }}>{label}</div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// App
// ─────────────────────────────────────────────────────────────
function App() {
  return (
    <DesignCanvas>
      <DCSection
        id="icons"
        title="Cronwatch · iPhone app icon explorations"
        subtitle="Six directions. Each card shows the 1024 master, the iOS size ladder (180/120/87/58), and a home-screen mock."
      >
        {VARIATIONS.map(v => (
          <DCArtboard
            key={v.id}
            id={v.id}
            label={v.title}
            width={680}
            height={520}
          >
            <VariationCard v={v} />
          </DCArtboard>
        ))}
      </DCSection>

      <DCSection
        id="grid"
        title="Side by side · same size"
        subtitle="Compare the six directions at one canonical size"
      >
        <DCArtboard id="grid" label="All six · 180px" width={680} height={420}>
          <div style={{
            width: '100%', height: '100%', background: '#f0eee9',
            padding: 32, boxSizing: 'border-box',
            display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 24,
            placeItems: 'center',
          }}>
            {VARIATIONS.map(v => (
              <div key={v.id} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
                <AppIcon size={140} Cmp={v.Cmp} />
                <div style={{ fontSize: 11, fontWeight: 500, color: '#5C5C58', letterSpacing: 0.2 }}>
                  {v.title.replace(/^\d+ · /, '')}
                </div>
              </div>
            ))}
          </div>
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
