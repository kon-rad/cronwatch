// App — composes all screens onto a DesignCanvas with iOS frames.
// Also registers the Tweaks panel for typography pairings.

const { useState: useAState } = React;

const FONT_PAIRINGS = {
  'inter': {
    label: 'Inter',
    sub: 'Default · humanist sans',
    display: "'Inter', -apple-system, system-ui, sans-serif",
    body:    "'Inter', -apple-system, system-ui, sans-serif",
    num:     "'Inter', -apple-system, system-ui, sans-serif",
  },
  'sf': {
    label: 'SF Pro',
    sub: 'iOS native',
    display: "-apple-system, 'SF Pro', system-ui, sans-serif",
    body:    "-apple-system, 'SF Pro', system-ui, sans-serif",
    num:     "-apple-system, 'SF Pro', system-ui, sans-serif",
  },
  'geist': {
    label: 'Geist',
    sub: 'Modern, neutral',
    display: "'Geist', system-ui, sans-serif",
    body:    "'Geist', system-ui, sans-serif",
    num:     "'JetBrains Mono', ui-monospace, monospace",
  },
  'serif': {
    label: 'Instrument Serif × Inter',
    sub: 'Editorial flourish',
    display: "'Instrument Serif', Georgia, serif",
    body:    "'Inter', system-ui, sans-serif",
    num:     "'Inter', system-ui, sans-serif",
  },
};

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "typography": "inter"
}/*EDITMODE-END*/;

function applyTypography(key) {
  const pair = FONT_PAIRINGS[key] || FONT_PAIRINGS.inter;
  const root = document.documentElement.style;
  root.setProperty('--cw-font-display', pair.display);
  root.setProperty('--cw-font-body', pair.body);
  root.setProperty('--cw-font-num', pair.num);
}

function App() {
  const [tweaks, setTweak] = useTweaks(TWEAK_DEFAULTS);

  React.useEffect(() => {
    applyTypography(tweaks.typography);
  }, [tweaks.typography]);

  // Phone frame size — slightly tighter than starter default for canvas density
  const W = 360, H = 780;

  return (
    <>
      <DesignCanvas>
        <DCSection
          id="prototype"
          title="Cronwatch — Interactive Prototype"
          subtitle="Voice-first time tracking · iOS · tap the FAB, hold to record, save to see it animate in"
        >
          <DCArtboard id="proto" label="Live prototype · start on Today" width={W + 24} height={H + 24}>
            <PhoneFrame w={W} h={H}>
              <CronwatchPrototype initialScreen="today" />
            </PhoneFrame>
          </DCArtboard>
          <DCArtboard id="proto-home" label="Live prototype · start on Overview" width={W + 24} height={H + 24}>
            <PhoneFrame w={W} h={H}>
              <CronwatchPrototype initialScreen="home" />
            </PhoneFrame>
          </DCArtboard>
          <DCArtboard id="proto-signin" label="Live prototype · from Sign-in" width={W + 24} height={H + 24}>
            <PhoneFrame w={W} h={H}>
              <CronwatchPrototype signedIn={false} />
            </PhoneFrame>
          </DCArtboard>
        </DCSection>

        <DCSection
          id="screens"
          title="All seven screens"
          subtitle="Static views — for layout review"
        >
          <DCArtboard id="signin" label="1 · Sign-in" width={W + 24} height={H + 24}>
            <PhoneFrame w={W} h={H}><StaticScreen kind="signin" /></PhoneFrame>
          </DCArtboard>
          <DCArtboard id="home" label="2 · Overview / Home" width={W + 24} height={H + 24}>
            <PhoneFrame w={W} h={H}><StaticScreen kind="home" /></PhoneFrame>
          </DCArtboard>
          <DCArtboard id="today" label="3 · Today (15-min grid)" width={W + 24} height={H + 24}>
            <PhoneFrame w={W} h={H}><StaticScreen kind="today" /></PhoneFrame>
          </DCArtboard>
          <DCArtboard id="capture" label="4 · Capture sheet" width={W + 24} height={H + 24}>
            <PhoneFrame w={W} h={H}><StaticScreen kind="today" withSheet="capture" /></PhoneFrame>
          </DCArtboard>
          <DCArtboard id="edit" label="5 · Entry edit" width={W + 24} height={H + 24}>
            <PhoneFrame w={W} h={H}><StaticScreen kind="today" withSheet="edit" /></PhoneFrame>
          </DCArtboard>
          <DCArtboard id="profile" label="6 · Profile" width={W + 24} height={H + 24}>
            <PhoneFrame w={W} h={H}><StaticScreen kind="profile" /></PhoneFrame>
          </DCArtboard>
          <DCArtboard id="paywall" label="7 · Paywall" width={W + 24} height={H + 24}>
            <PhoneFrame w={W} h={H}><StaticScreen kind="paywall" /></PhoneFrame>
          </DCArtboard>
        </DCSection>

        <DCSection
          id="system"
          title="Design language"
          subtitle="Tokens, type, swatches"
        >
          <DCArtboard id="palette" label="Palette & type" width={620} height={420}>
            <SystemSheet />
          </DCArtboard>
          <DCArtboard id="categories" label="Category swatches" width={420} height={420}>
            <CategorySheet />
          </DCArtboard>
        </DCSection>
      </DesignCanvas>

      <TweaksPanel title="Tweaks">
        <TweakSection title="Typography">
          <TweakRadio
            label="Pairing"
            value={tweaks.typography}
            onChange={(v) => setTweak('typography', v)}
            options={[
              { value: 'inter', label: 'Inter' },
              { value: 'sf', label: 'SF Pro' },
              { value: 'geist', label: 'Geist' },
              { value: 'serif', label: 'Serif/Sans' },
            ]}
          />
          <div style={{
            marginTop: 8, padding: '10px 12px', borderRadius: 8,
            background: 'rgba(0,0,0,0.04)', fontSize: 12, color: '#5C5C58',
            fontFamily: 'var(--cw-font-body)', lineHeight: 1.5,
          }}>
            <div style={{ fontFamily: 'var(--cw-font-display)', fontSize: 16, fontWeight: 600, color: '#111', letterSpacing: -0.3 }}>
              {FONT_PAIRINGS[tweaks.typography]?.label}
            </div>
            <div>{FONT_PAIRINGS[tweaks.typography]?.sub}</div>
            <div className="num" style={{ marginTop: 6, fontFamily: 'var(--cw-font-num)', letterSpacing: 0.4 }}>
              09:45 · 6h 15m tracked
            </div>
          </div>
        </TweakSection>
      </TweaksPanel>
    </>
  );
}

// Phone frame wrapper — adds the iOS bezel + status bar
function PhoneFrame({ w, h, children }) {
  return (
    <div style={{
      width: '100%', height: '100%',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: 12, boxSizing: 'border-box',
      background: 'transparent',
    }}>
      <IOSDevice width={w} height={h}>{children}</IOSDevice>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Design language sheets
// ─────────────────────────────────────────────────────────────
function SystemSheet() {
  const swatches = [
    { name: 'Background', hex: '#FAFAF7', val: CW.bg },
    { name: 'Ink',        hex: '#111111', val: CW.ink },
    { name: 'Ink muted',  hex: '#5C5C58', val: CW.inkMuted },
    { name: 'Caption',    hex: '#9A9A95', val: CW.caption },
    { name: 'Border',     hex: '#ECECEA', val: CW.border },
    { name: 'Amber',      hex: '#E8A33D', val: CW.amber },
  ];
  return (
    <div className="cw" style={{
      width: '100%', height: '100%', background: CW.bg, padding: 24,
      boxSizing: 'border-box', overflow: 'hidden',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18 }}>
        <WordmarkGlyph size={36} />
        <div className="display" style={{ fontSize: 22, fontWeight: 600, letterSpacing: -0.5, color: CW.ink }}>Cronwatch</div>
      </div>

      <div style={{
        fontSize: 11, fontWeight: 600, color: CW.caption, textTransform: 'uppercase',
        letterSpacing: 0.6, marginBottom: 10,
      }}>Palette</div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, marginBottom: 22 }}>
        {swatches.map(s => (
          <div key={s.name} style={{
            display: 'flex', flexDirection: 'column', gap: 6,
          }}>
            <div style={{
              height: 48, borderRadius: 10, background: s.val,
              border: `1px solid ${CW.border}`,
            }} />
            <div style={{ fontSize: 11, fontWeight: 500, color: CW.ink, letterSpacing: -0.1 }}>{s.name}</div>
            <div className="num" style={{ fontSize: 10, color: CW.caption, fontWeight: 500 }}>{s.hex}</div>
          </div>
        ))}
      </div>

      <div style={{
        fontSize: 11, fontWeight: 600, color: CW.caption, textTransform: 'uppercase',
        letterSpacing: 0.6, marginBottom: 10,
      }}>Type scale</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        <div className="display" style={{ fontSize: 22, fontWeight: 600, color: CW.ink, letterSpacing: -0.5, lineHeight: 1.1 }}>
          Title · 22 / 600
        </div>
        <div style={{ fontSize: 15, fontWeight: 450, color: CW.ink, letterSpacing: -0.1 }}>
          Body · 15 / 450 · the quiet line that does the work
        </div>
        <div style={{ fontSize: 12, fontWeight: 500, color: CW.caption, letterSpacing: 0.1 }}>
          Caption · 12 / 500
        </div>
        <div className="num" style={{ fontSize: 14, fontWeight: 500, color: CW.ink, letterSpacing: -0.1, marginTop: 4 }}>
          Tabular · 09:45 · 6h 15m · 23:45
        </div>
      </div>
    </div>
  );
}

function CategorySheet() {
  return (
    <div className="cw" style={{
      width: '100%', height: '100%', background: CW.bg, padding: 24,
      boxSizing: 'border-box', overflow: 'auto',
    }}>
      <div style={{
        fontSize: 11, fontWeight: 600, color: CW.caption, textTransform: 'uppercase',
        letterSpacing: 0.6, marginBottom: 12,
      }}>Categories</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {Object.entries(CW.cats).map(([name, t]) => (
          <div key={name} style={{
            display: 'flex', alignItems: 'center', gap: 10,
            padding: '10px 14px', background: t.bg, borderRadius: 10,
          }}>
            <span style={{ width: 8, height: 8, borderRadius: 4, background: t.dot }} />
            <span style={{ fontSize: 13, fontWeight: 600, color: t.ink, letterSpacing: -0.1 }}>{name}</span>
            <span style={{ flex: 1 }} />
            <span className="num" style={{ fontSize: 11, color: t.ink, opacity: 0.6, fontWeight: 500 }}>{t.dot}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// Mount
const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
