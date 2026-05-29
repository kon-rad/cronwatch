// Cronwatch screens — composable, driven by props.
// Screens render INSIDE the iOS frame's content area (no nav title used).
// Each screen returns full-bleed content with its own bg.

const { useState, useEffect, useRef, useMemo } = React;

// ─────────────────────────────────────────────────────────────
// Shared chrome
// ─────────────────────────────────────────────────────────────
function ScreenShell({ children, bg = CW.bg }) {
  return (
    <div className="cw" style={{
      width: '100%', height: '100%', background: bg, color: CW.ink,
      display: 'flex', flexDirection: 'column',
      paddingTop: 60, // status bar clearance
      position: 'relative',
      overflow: 'hidden',
    }}>
      {children}
    </div>
  );
}

function BottomNav({ active = 'today', onTab }) {
  const tab = (key, label, IconCmp) => {
    const isActive = active === key;
    const color = isActive ? CW.amber : CW.caption;
    return (
      <button
        key={key}
        onClick={() => onTab && onTab(key)}
        style={{
          flex: 1, background: 'transparent', border: 'none',
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
          padding: '8px 0 6px', cursor: 'pointer',
          color, fontFamily: 'inherit',
        }}
      >
        <IconCmp s={22} c={color} filled={isActive} />
        <span style={{
          fontSize: 11, fontWeight: 500, letterSpacing: 0.1,
          color, fontFamily: 'inherit',
        }}>{label}</span>
      </button>
    );
  };
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0,
      paddingBottom: 28, paddingTop: 6,
      background: 'rgba(250,250,247,0.92)',
      backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
      borderTop: `1px solid ${CW.border}`,
      display: 'flex', zIndex: 5,
    }}>
      {tab('home', 'Overview', Icon.Home)}
      {tab('today', 'Today', Icon.Calendar)}
      {tab('profile', 'Profile', Icon.User)}
    </div>
  );
}

function FAB({ onClick, hidden = false }) {
  if (hidden) return null;
  return (
    <button
      onClick={onClick}
      style={{
        position: 'absolute', right: 20, bottom: 96,
        width: 60, height: 60, borderRadius: 28,
        background: CW.amber, border: 'none', cursor: 'pointer',
        boxShadow: '0 6px 18px rgba(232,163,61,0.35), 0 1px 2px rgba(0,0,0,0.06)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 6,
      }}
      aria-label="Capture"
    >
      <Icon.Mic s={26} c="#1a1a1a" />
    </button>
  );
}

// ─────────────────────────────────────────────────────────────
// 1. Sign-in
// ─────────────────────────────────────────────────────────────
function SignInScreen({ onSignIn }) {
  return (
    <ScreenShell>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: '0 24px' }}>
        <div style={{ flex: '0 0 28%' }} />
        <div style={{ textAlign: 'center' }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 10,
            marginBottom: 14,
          }}>
            <WordmarkGlyph />
          </div>
          <div className="display" style={{
            fontSize: 34, fontWeight: 600, letterSpacing: -0.8, color: CW.ink,
            lineHeight: 1.05,
          }}>Cronwatch</div>
          <div style={{
            marginTop: 14, fontSize: 15, color: CW.inkMuted, fontWeight: 450,
            letterSpacing: -0.1,
          }}>Speak your time. See your day.</div>
        </div>

        <div style={{ flex: 1 }} />

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, paddingBottom: 32 }}>
          <button
            onClick={onSignIn}
            style={{
              height: 52, borderRadius: 12, border: 'none', cursor: 'pointer',
              background: '#000', color: '#fff', fontFamily: 'inherit',
              fontSize: 15, fontWeight: 500, letterSpacing: -0.1,
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            }}>
            <Icon.Apple s={18} c="#fff" />
            Continue with Apple
          </button>
          <button
            onClick={onSignIn}
            style={{
              height: 52, borderRadius: 12, cursor: 'pointer',
              background: '#fff', color: CW.ink, fontFamily: 'inherit',
              border: `1px solid ${CW.border}`,
              fontSize: 15, fontWeight: 500, letterSpacing: -0.1,
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            }}>
            <Icon.Google s={18} />
            Continue with Google
          </button>
        </div>

        <div style={{
          textAlign: 'center', fontSize: 12, color: CW.caption, fontWeight: 500,
          paddingBottom: 40,
        }}>
          By continuing you agree to our <span style={{ color: CW.inkMuted, textDecoration: 'underline', textDecorationColor: CW.border }}>Terms</span> and <span style={{ color: CW.inkMuted, textDecoration: 'underline', textDecorationColor: CW.border }}>Privacy</span>.
        </div>
      </div>
    </ScreenShell>
  );
}

// Wordmark glyph: a clock-face inspired mark — three concentric arcs.
function WordmarkGlyph({ size = 44 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: size / 2,
      background: CW.amber, position: 'relative',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <svg width={size * 0.6} height={size * 0.6} viewBox="0 0 24 24" fill="none">
        <circle cx="12" cy="12" r="9" stroke="#111" strokeWidth="1.6" />
        <path d="M12 7v5l3.5 2" stroke="#111" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 2. Today (15-min grid)
// ─────────────────────────────────────────────────────────────
const SLOT_PX = 22; // each 15-min slot

function todayDateLine() { return 'Tuesday, May 5'; }

function TodayScreen({
  entries, onTab, onFab, onEntryTap, scrollToNow = true, nowLine = true,
  flashId = null, hideFab = false,
}) {
  const scrollRef = useRef(null);
  const trackedMin = entries.reduce((s, e) => s + durationMin(e.start, e.end), 0);

  // Auto-scroll to current time on mount
  useEffect(() => {
    if (!scrollToNow || !scrollRef.current) return;
    const now = new Date();
    const nowMin = now.getHours() * 60 + now.getMinutes();
    const slotIdx = Math.floor(nowMin / 15);
    const target = slotIdx * SLOT_PX - 180;
    scrollRef.current.scrollTop = Math.max(0, target);
  }, [scrollToNow]);

  // Build slot map
  const entryByStart = useMemo(() => {
    const m = {};
    for (const e of entries) m[timeToMin(e.start)] = e;
    return m;
  }, [entries]);

  const slots = allSlots();

  // Now indicator position
  const nowMin = (() => {
    const n = new Date();
    return n.getHours() * 60 + n.getMinutes();
  })();
  const nowOffset = (nowMin / 15) * SLOT_PX;

  return (
    <ScreenShell>
      {/* Header */}
      <div style={{ padding: '6px 24px 14px' }}>
        <div className="display" style={{
          fontSize: 26, fontWeight: 600, letterSpacing: -0.6, color: CW.ink,
          lineHeight: 1.1,
        }}>{todayDateLine()}</div>
        <div style={{
          marginTop: 4, fontSize: 13, color: CW.caption, fontWeight: 500,
          display: 'flex', alignItems: 'center', gap: 6,
        }}>
          <span className="num">{fmtDuration(trackedMin)}</span> tracked
          <span style={{ color: CW.border }}>·</span>
          <span className="num">{fmtDuration(24*60 - trackedMin)}</span> open
        </div>
      </div>

      {/* Grid */}
      <div ref={scrollRef} className="cw-scroll" style={{
        flex: 1, overflowY: 'auto',
        padding: '0 16px 120px',
        position: 'relative',
      }}>
        <div style={{ position: 'relative' }}>
          {slots.map((t, i) => {
            const min = timeToMin(t);
            const onHour = min % 60 === 0;
            const entry = entries.find(e => timeToMin(e.start) <= min && timeToMin(e.end) > min);
            const isStart = entry && timeToMin(entry.start) === min;
            const isEnd = entry && timeToMin(entry.end) - 15 === min;
            return (
              <SlotRow
                key={t}
                time={t}
                onHour={onHour}
                entry={entry}
                isStart={isStart}
                isEnd={isEnd}
                onTap={onEntryTap}
                flash={flashId === (entry && entry.id)}
              />
            );
          })}

          {/* Now line */}
          {nowLine && (
            <div style={{
              position: 'absolute', left: 56, right: 8, top: nowOffset,
              height: 0, pointerEvents: 'none', zIndex: 3,
            }}>
              <div style={{
                position: 'absolute', left: -8, top: -4,
                width: 8, height: 8, borderRadius: 4, background: CW.amber,
              }} />
              <div style={{
                position: 'absolute', left: 0, right: 0, top: 0,
                height: 1.5, background: CW.amber,
              }} />
            </div>
          )}
        </div>
      </div>

      <FAB onClick={onFab} hidden={hideFab} />
      <BottomNav active="today" onTab={onTab} />
    </ScreenShell>
  );
}

function SlotRow({ time, onHour, entry, isStart, isEnd, onTap, flash }) {
  const [h, m] = time.split(':').map(Number);
  const cat = entry ? CW.cats[entry.category] : null;

  // Show time label only on the hour
  const timeLabel = m === 0 ? `${String(h).padStart(2,'0')}:00` : '';

  return (
    <div style={{
      height: SLOT_PX,
      display: 'flex', alignItems: 'stretch',
      position: 'relative',
      animation: flash ? 'cw-flash 1.2s ease-out' : undefined,
    }}>
      {/* Time gutter */}
      <div className="num" style={{
        width: 56, paddingTop: onHour ? 0 : 0, paddingRight: 10,
        textAlign: 'right', flexShrink: 0,
        fontSize: 11, fontWeight: 500, color: CW.caption,
        lineHeight: '14px',
        display: 'flex', alignItems: onHour ? 'flex-start' : 'center',
        justifyContent: 'flex-end',
        transform: onHour ? 'translateY(-1px)' : 'none',
      }}>{timeLabel}</div>

      {/* Slot body */}
      <div style={{
        flex: 1, position: 'relative',
        padding: '0 4px',
      }}>
        {entry ? (
          <div
            onClick={() => onTap && onTap(entry)}
            style={{
              position: 'absolute', left: 4, right: 4,
              top: isStart ? 1 : 0,
              bottom: isEnd ? 1 : 0,
              background: cat.bg,
              borderTopLeftRadius: isStart ? 10 : 0,
              borderTopRightRadius: isStart ? 10 : 0,
              borderBottomLeftRadius: isEnd ? 10 : 0,
              borderBottomRightRadius: isEnd ? 10 : 0,
              padding: isStart ? '6px 12px 0' : '0 12px',
              overflow: 'hidden',
              cursor: 'pointer',
              display: 'flex', alignItems: isStart ? 'flex-start' : 'center',
            }}
          >
            {isStart && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, width: '100%' }}>
                <div style={{
                  width: 6, height: 6, borderRadius: 3,
                  background: cat.dot, flexShrink: 0,
                }} />
                <div style={{ minWidth: 0, flex: 1 }}>
                  <div style={{
                    fontSize: 13, fontWeight: 600, color: cat.ink,
                    letterSpacing: -0.1, lineHeight: 1.2,
                    whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                  }}>
                    {entry.category}
                    <span style={{ fontWeight: 450, color: cat.ink, opacity: 0.7 }}>
                      {' · '}{entry.note}
                    </span>
                  </div>
                </div>
                <div className="num" style={{
                  fontSize: 11, fontWeight: 500, color: cat.ink, opacity: 0.6,
                  flexShrink: 0,
                }}>
                  {fmtDuration(durationMin(entry.start, entry.end))}
                </div>
              </div>
            )}
          </div>
        ) : (
          // Empty slot — faint dotted divider on the hour
          onHour ? (
            <div style={{
              position: 'absolute', left: 4, right: 4, top: 0,
              borderTop: `1px dashed ${CW.border}`,
            }} />
          ) : null
        )}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 3. Capture sheet
// ─────────────────────────────────────────────────────────────
const TRANSCRIPT_PHRASES = [
  'Spent the last hour in deep focus on the capture sheet animations',
  'Met with the design team for forty-five minutes about the roadmap',
  'Quick coffee break, fifteen minutes, then back to it',
  'Half-hour run along the river — felt great',
  'Reading for an hour, mostly Designing Data Intensive Apps',
];

function CaptureSheet({ onCancel, onSave }) {
  const [recording, setRecording] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [typed, setTyped] = useState('');
  const [savedFlash, setSavedFlash] = useState(false);
  const phraseIdx = useRef(Math.floor(Math.random() * TRANSCRIPT_PHRASES.length));
  const tickRef = useRef(null);

  // Hold-to-record: simulate Deepgram streaming words in.
  useEffect(() => {
    if (!recording) return;
    const phrase = TRANSCRIPT_PHRASES[phraseIdx.current];
    const words = phrase.split(' ');
    let i = 0;
    setTranscript('');
    tickRef.current = setInterval(() => {
      i++;
      setTranscript(words.slice(0, i).join(' '));
      if (i >= words.length) {
        clearInterval(tickRef.current);
      }
    }, 140);
    return () => clearInterval(tickRef.current);
  }, [recording]);

  const startHold = () => { setRecording(true); };
  const endHold = () => { setRecording(false); };

  const content = transcript || typed;
  const canSave = content.trim().length > 0;

  const doSave = () => {
    if (!canSave) return;
    setSavedFlash(true);
    setTimeout(() => {
      onSave && onSave({
        category: inferCategory(content),
        note: content.trim(),
      });
    }, 650);
  };

  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0,
      height: '74%',
      background: CW.bg,
      borderTopLeftRadius: 24, borderTopRightRadius: 24,
      boxShadow: '0 -12px 40px rgba(0,0,0,0.18)',
      animation: 'cw-sheet-in 280ms cubic-bezier(0.2, 0.9, 0.3, 1)',
      display: 'flex', flexDirection: 'column',
      zIndex: 10,
      overflow: 'hidden',
    }}>
      {/* Drag handle */}
      <div style={{ display: 'flex', justifyContent: 'center', padding: '10px 0 0' }}>
        <div style={{ width: 36, height: 4, borderRadius: 2, background: '#D6D6D2' }} />
      </div>

      {/* Header */}
      <div style={{
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        padding: '14px 20px 10px',
      }}>
        <button onClick={onCancel} style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          fontFamily: 'inherit', fontSize: 15, color: CW.inkMuted, fontWeight: 450,
          padding: 0,
        }}>Cancel</button>
        <div style={{
          fontSize: 14, fontWeight: 600, color: CW.ink, letterSpacing: -0.1,
        }}>New entry</div>
        <button
          onClick={doSave}
          disabled={!canSave}
          style={{
            background: 'transparent', border: 'none',
            cursor: canSave ? 'pointer' : 'default',
            fontFamily: 'inherit', fontSize: 15, fontWeight: 600,
            color: canSave ? CW.amber : CW.caption,
            padding: 0, opacity: canSave ? 1 : 0.6,
          }}
        >Save</button>
      </div>

      {/* Body */}
      <div style={{ flex: 1, padding: '8px 24px 0', display: 'flex', flexDirection: 'column' }}>

        {/* Transcript area */}
        <div style={{
          minHeight: 100, padding: '14px 0',
          fontSize: 18, fontWeight: 450, color: CW.ink,
          letterSpacing: -0.2, lineHeight: 1.45,
          textAlign: 'center',
        }}>
          {transcript ? (
            <span>{transcript}<span style={{
              display: 'inline-block', width: 2, height: 18, marginLeft: 2,
              background: CW.amber, verticalAlign: 'middle',
              animation: recording ? 'cw-typing 0.8s ease-in-out infinite alternate' : 'none',
            }} /></span>
          ) : (
            <span style={{ color: CW.caption, fontWeight: 450, fontSize: 15 }}>
              {recording ? 'Listening…' : 'Hold to record, or type below.'}
            </span>
          )}
        </div>

        {/* Waveform / record */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
          <Waveform active={recording} />
          <button
            onMouseDown={startHold}
            onMouseUp={endHold}
            onMouseLeave={endHold}
            onTouchStart={(e) => { e.preventDefault(); startHold(); }}
            onTouchEnd={(e) => { e.preventDefault(); endHold(); }}
            style={{
              marginTop: 28,
              width: 80, height: 80, borderRadius: 40,
              background: CW.amber, border: 'none', cursor: 'pointer',
              boxShadow: '0 6px 18px rgba(232,163,61,0.35)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              animation: recording ? 'cw-pulse 1.2s ease-in-out infinite' : 'none',
              transition: 'transform 150ms ease-out',
              userSelect: 'none', WebkitUserSelect: 'none',
            }}
          >
            <Icon.Mic s={32} c="#1a1a1a" />
          </button>
          <div style={{
            marginTop: 14, fontSize: 12, color: CW.caption, fontWeight: 500,
            letterSpacing: 0.2,
          }}>
            {recording ? 'Recording…' : 'HOLD TO RECORD'}
          </div>
        </div>

        {/* Type fallback */}
        <div style={{
          marginTop: 'auto', marginBottom: 24,
          display: 'flex', alignItems: 'center', gap: 10,
          padding: '10px 14px',
          background: '#fff',
          border: `1px solid ${CW.border}`,
          borderRadius: 12,
        }}>
          <Icon.Type s={16} c={CW.caption} />
          <input
            value={typed}
            onChange={(e) => setTyped(e.target.value)}
            placeholder="Or type an entry…"
            disabled={recording}
            style={{
              flex: 1, border: 'none', outline: 'none', background: 'transparent',
              fontSize: 15, fontWeight: 450, color: CW.ink, fontFamily: 'inherit',
              letterSpacing: -0.1, padding: 0,
            }}
          />
          {typed && (
            <button onClick={doSave} style={{
              background: 'transparent', border: 'none', cursor: 'pointer',
              padding: 4, color: CW.amber,
            }}>
              <Icon.Send s={18} c={CW.amber} />
            </button>
          )}
        </div>
      </div>

      {savedFlash && (
        <div style={{
          position: 'absolute', inset: 0, background: 'rgba(250,250,247,0.92)',
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
          gap: 12, animation: 'cw-fadein-up 200ms ease-out',
        }}>
          <div style={{
            width: 56, height: 56, borderRadius: 28, background: CW.amber,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Icon.Check s={26} c="#1a1a1a" />
          </div>
          <div style={{ fontSize: 16, fontWeight: 600, color: CW.ink }}>Logged.</div>
        </div>
      )}
    </div>
  );
}

function Waveform({ active }) {
  const bars = 32;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 4, height: 36 }}>
      {Array.from({ length: bars }).map((_, i) => {
        const seed = (Math.sin(i * 1.7) + 1) / 2;
        const h = active ? 8 + seed * 24 : 6;
        return (
          <div
            key={i}
            style={{
              width: 3, height: h, borderRadius: 2,
              background: active ? CW.amber : CW.border,
              transformOrigin: 'center',
              animation: active
                ? `cw-wave ${0.6 + seed * 0.6}s ease-in-out ${i * 0.04}s infinite`
                : 'none',
            }}
          />
        );
      })}
    </div>
  );
}

function inferCategory(text) {
  const t = text.toLowerCase();
  if (/\b(deep|focus|focus block|building)\b/.test(t)) return 'Deep';
  if (/\b(meet|standup|1:1|sync|call|meeting)\b/.test(t)) return 'Meeting';
  if (/\b(run|gym|workout|exercise|walk|ride)\b/.test(t)) return 'Exercise';
  if (/\b(coffee|break|stretch)\b/.test(t)) return 'Break';
  if (/\b(lunch|dinner|breakfast|meal|eat|ate)\b/.test(t)) return 'Meal';
  if (/\b(read|reading|study)\b/.test(t)) return 'Study';
  if (/\b(show|tv|game|netflix)\b/.test(t)) return 'Entertain';
  if (/\b(sleep|nap|bed)\b/.test(t)) return 'Sleep';
  return 'Work';
}

// ─────────────────────────────────────────────────────────────
// 4. Entry edit
// ─────────────────────────────────────────────────────────────
function EditSheet({ entry, onCancel, onSave, onDelete, recentCats = [] }) {
  const [category, setCategory] = useState(entry.category);
  const [note, setNote] = useState(entry.note);
  const [start, setStart] = useState(entry.start);
  const [end, setEnd] = useState(entry.end);

  const cats = ['Work', 'Deep', 'Meeting', 'Study', 'Exercise', 'Meal', 'Break', 'Personal', 'Sleep', 'Entertain', 'Commute'];
  const ordered = [...new Set([...recentCats, ...cats])];

  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0,
      height: '78%',
      background: CW.bg,
      borderTopLeftRadius: 24, borderTopRightRadius: 24,
      boxShadow: '0 -12px 40px rgba(0,0,0,0.18)',
      animation: 'cw-sheet-in 280ms cubic-bezier(0.2, 0.9, 0.3, 1)',
      display: 'flex', flexDirection: 'column', zIndex: 10, overflow: 'hidden',
    }}>
      <div style={{ display: 'flex', justifyContent: 'center', padding: '10px 0 0' }}>
        <div style={{ width: 36, height: 4, borderRadius: 2, background: '#D6D6D2' }} />
      </div>
      <div style={{
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        padding: '14px 20px 10px',
      }}>
        <button onClick={onCancel} style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          fontFamily: 'inherit', fontSize: 15, color: CW.inkMuted, padding: 0,
        }}>Cancel</button>
        <div style={{ fontSize: 14, fontWeight: 600, color: CW.ink }}>Edit entry</div>
        <button
          onClick={() => onSave({ ...entry, category, note, start, end })}
          style={{
            background: 'transparent', border: 'none', cursor: 'pointer',
            fontFamily: 'inherit', fontSize: 15, fontWeight: 600, color: CW.amber, padding: 0,
          }}
        >Save</button>
      </div>

      <div className="cw-scroll" style={{
        flex: 1, overflowY: 'auto', padding: '8px 20px 24px',
        display: 'flex', flexDirection: 'column', gap: 18,
      }}>
        <FieldLabel>Category</FieldLabel>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {ordered.map(c => {
            const sel = c === category;
            const tone = CW.cats[c] || { bg: '#fff', ink: CW.ink, dot: CW.caption };
            return (
              <button
                key={c}
                onClick={() => setCategory(c)}
                style={{
                  height: 32, padding: '0 12px', borderRadius: 16,
                  border: sel ? `1.5px solid ${CW.amber}` : `1px solid ${CW.border}`,
                  background: sel ? CW.amberFaint : '#fff',
                  cursor: 'pointer', fontFamily: 'inherit',
                  fontSize: 13, fontWeight: 500, color: CW.ink,
                  display: 'flex', alignItems: 'center', gap: 6,
                  letterSpacing: -0.1,
                }}
              >
                <span style={{ width: 6, height: 6, borderRadius: 3, background: tone.dot }} />
                {c}
              </button>
            );
          })}
        </div>

        <FieldLabel>Note</FieldLabel>
        <textarea
          value={note}
          onChange={(e) => setNote(e.target.value)}
          rows={3}
          style={{
            width: '100%', boxSizing: 'border-box', resize: 'none',
            padding: '12px 14px', borderRadius: 12,
            border: `1px solid ${CW.border}`, background: '#fff',
            fontFamily: 'inherit', fontSize: 15, fontWeight: 450, color: CW.ink,
            letterSpacing: -0.1, lineHeight: 1.4, outline: 'none',
          }}
        />

        <div style={{ display: 'flex', gap: 12 }}>
          <div style={{ flex: 1 }}>
            <FieldLabel>Start</FieldLabel>
            <TimePicker value={start} onChange={setStart} />
          </div>
          <div style={{ flex: 1 }}>
            <FieldLabel>End</FieldLabel>
            <TimePicker value={end} onChange={setEnd} />
          </div>
        </div>

        <div style={{ flex: 1 }} />

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingTop: 12 }}>
          <button onClick={onDelete} style={{
            background: 'transparent', border: 'none', cursor: 'pointer',
            color: CW.red, fontFamily: 'inherit', fontSize: 14, fontWeight: 500,
            display: 'flex', alignItems: 'center', gap: 6, padding: 0,
          }}>
            <Icon.Trash s={16} c={CW.red} />
            Delete entry
          </button>
        </div>
      </div>
    </div>
  );
}

function FieldLabel({ children }) {
  return (
    <div style={{
      fontSize: 11, fontWeight: 600, color: CW.caption,
      textTransform: 'uppercase', letterSpacing: 0.6,
      marginBottom: -10,
    }}>{children}</div>
  );
}

function TimePicker({ value, onChange }) {
  // 15-minute snapping picker — display only (controlled).
  const change = (delta) => {
    const m = timeToMin(value) + delta;
    const clamped = Math.max(0, Math.min(24*60 - 15, m));
    onChange(minToTime(clamped));
  };
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      height: 44, padding: '0 6px 0 14px',
      borderRadius: 12, border: `1px solid ${CW.border}`, background: '#fff',
    }}>
      <div className="num" style={{ fontSize: 16, fontWeight: 500, color: CW.ink, letterSpacing: -0.1 }}>
        {fmtTime12(value)}
      </div>
      <div style={{ display: 'flex' }}>
        <button onClick={() => change(-15)} style={{
          width: 32, height: 32, borderRadius: 8, border: 'none', background: 'transparent',
          cursor: 'pointer', color: CW.inkMuted, display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>−</button>
        <button onClick={() => change(15)} style={{
          width: 32, height: 32, borderRadius: 8, border: 'none', background: 'transparent',
          cursor: 'pointer', color: CW.inkMuted, display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>+</button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 5. Profile
// ─────────────────────────────────────────────────────────────
function ProfileScreen({ onTab, onUpgrade, plan = 'Free' }) {
  return (
    <ScreenShell>
      <div className="cw-scroll" style={{ flex: 1, overflowY: 'auto', padding: '6px 20px 130px' }}>
        {/* Header */}
        <div style={{ padding: '4px 4px 24px', display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{
            width: 56, height: 56, borderRadius: 28, background: CW.amberFaint,
            color: CW.amberDeep, display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 20, fontWeight: 600, letterSpacing: -0.4,
          }}>EM</div>
          <div>
            <div className="display" style={{ fontSize: 18, fontWeight: 600, color: CW.ink, letterSpacing: -0.3 }}>Emma Mori</div>
            <div style={{ fontSize: 13, color: CW.caption, fontWeight: 450, marginTop: 2 }}>emma@cronwatch.app</div>
          </div>
        </div>

        <SectionLabel>Subscription</SectionLabel>
        <div style={{
          background: '#fff', border: `1px solid ${CW.border}`, borderRadius: 12,
          padding: '16px 16px', marginBottom: 28,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div>
              <div style={{ fontSize: 15, fontWeight: 600, color: CW.ink, letterSpacing: -0.1 }}>{plan} plan</div>
              <div style={{ fontSize: 13, color: CW.caption, marginTop: 4, fontWeight: 450 }}>
                {plan === 'Free' ? 'No active subscription' : 'Renews May 12, 2026'}
              </div>
            </div>
            <button onClick={onUpgrade} style={{
              height: 36, padding: '0 16px', borderRadius: 10,
              background: plan === 'Free' ? CW.amber : '#fff',
              color: plan === 'Free' ? '#1a1a1a' : CW.ink,
              border: plan === 'Free' ? 'none' : `1px solid ${CW.border}`,
              fontFamily: 'inherit', fontSize: 13, fontWeight: 600, cursor: 'pointer',
              letterSpacing: -0.1,
            }}>
              {plan === 'Free' ? 'Upgrade' : 'Manage'}
            </button>
          </div>
        </div>

        <SectionLabel>Account</SectionLabel>
        <RowList>
          <Row label="Sign out" />
          <Row label="Delete account" muted />
        </RowList>

        <SectionLabel>About</SectionLabel>
        <RowList>
          <Row label="Version" detail="1.4.0" />
          <Row label="Source on GitHub" trailing={<Icon.GitHub s={16} c={CW.caption} />} />
          <Row label="Privacy" />
          <Row label="Terms" />
        </RowList>

        <div style={{
          textAlign: 'center', fontSize: 11, color: CW.caption, fontWeight: 500,
          letterSpacing: 0.4, marginTop: 28, textTransform: 'uppercase',
        }}>
          Made quietly · Cronwatch
        </div>
      </div>

      <FAB onClick={() => onTab && onTab('today')} />
      <BottomNav active="profile" onTab={onTab} />
    </ScreenShell>
  );
}

function SectionLabel({ children }) {
  return (
    <div style={{
      fontSize: 11, fontWeight: 600, color: CW.caption,
      textTransform: 'uppercase', letterSpacing: 0.6,
      padding: '0 4px 8px',
    }}>{children}</div>
  );
}
function RowList({ children }) {
  const arr = React.Children.toArray(children);
  return (
    <div style={{
      background: '#fff', border: `1px solid ${CW.border}`, borderRadius: 12,
      overflow: 'hidden', marginBottom: 28,
    }}>
      {arr.map((c, i) => React.cloneElement(c, { isLast: i === arr.length - 1, key: i }))}
    </div>
  );
}
function Row({ label, detail, trailing, muted, isLast }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '14px 16px',
      borderBottom: isLast ? 'none' : `1px solid ${CW.borderSoft}`,
      cursor: 'pointer',
    }}>
      <div style={{
        fontSize: 15, fontWeight: 450, color: muted ? CW.inkMuted : CW.ink,
        letterSpacing: -0.1,
      }}>{label}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        {detail && <span className="num" style={{ fontSize: 14, color: CW.caption, fontWeight: 500 }}>{detail}</span>}
        {trailing}
        <Icon.Chevron s={16} c={CW.caption} dir="right" />
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 6. Paywall
// ─────────────────────────────────────────────────────────────
function PaywallScreen({ onClose, onSubscribe }) {
  const [plan, setPlan] = useState('yearly');
  return (
    <ScreenShell>
      <div style={{
        position: 'absolute', top: 60, right: 16, zIndex: 4,
      }}>
        <button onClick={onClose} style={{
          width: 32, height: 32, borderRadius: 16,
          background: '#fff', border: `1px solid ${CW.border}`, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          padding: 0,
        }}>
          <Icon.Close s={16} c={CW.ink} />
        </button>
      </div>

      <div className="cw-scroll" style={{ flex: 1, overflowY: 'auto', padding: '20px 24px 32px' }}>
        <div style={{ paddingTop: 12 }}>
          <div className="display" style={{
            fontSize: 26, fontWeight: 600, color: CW.ink, letterSpacing: -0.6, lineHeight: 1.15,
          }}>Track your time without thinking about it.</div>
          <div style={{
            marginTop: 10, fontSize: 15, color: CW.inkMuted, fontWeight: 450,
            letterSpacing: -0.1, lineHeight: 1.4,
          }}>Voice in. Structured time out.</div>
        </div>

        <div style={{ marginTop: 28, display: 'flex', flexDirection: 'column', gap: 16 }}>
          <Feature
            icon={<Icon.Mic s={20} c={CW.ink} />}
            title="Voice capture"
            text="Hold the button, speak naturally. Cronwatch turns it into a structured entry."
          />
          <Feature
            icon={<Icon.Calendar s={20} c={CW.ink} />}
            title="15-minute grid"
            text="Your day at a glance — every block accounted for, nothing fudged."
          />
          <Feature
            icon={<Icon.Lock s={18} c={CW.ink} />}
            title="Private by default"
            text="Your entries stay on-device. No analytics, no ads, no resold data."
          />
        </div>

        <div style={{ marginTop: 28, display: 'flex', gap: 10 }}>
          <PlanCard
            selected={plan === 'yearly'}
            onClick={() => setPlan('yearly')}
            title="Yearly"
            price="$40"
            unit="/yr"
            sub="$3.33/month"
            badge="Best value · 20% off"
          />
          <PlanCard
            selected={plan === 'weekly'}
            onClick={() => setPlan('weekly')}
            title="Weekly"
            price="$4"
            unit="/wk"
            sub="Try a week"
          />
        </div>

        <button
          onClick={onSubscribe}
          style={{
            marginTop: 24, width: '100%', height: 52, borderRadius: 12,
            background: CW.amber, border: 'none', cursor: 'pointer',
            color: '#1a1a1a', fontFamily: 'inherit', fontSize: 15, fontWeight: 600,
            letterSpacing: -0.1,
          }}
        >Start subscription</button>

        <div style={{
          marginTop: 14, textAlign: 'center', fontSize: 12, color: CW.caption,
          fontWeight: 500, lineHeight: 1.5,
        }}>
          Cancel anytime · <span style={{ color: CW.inkMuted, textDecoration: 'underline' }}>Restore purchases</span> · <span style={{ color: CW.inkMuted, textDecoration: 'underline' }}>Terms</span>
        </div>
      </div>
    </ScreenShell>
  );
}

function Feature({ icon, title, text }) {
  return (
    <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
      <div style={{
        width: 36, height: 36, borderRadius: 10,
        background: '#fff', border: `1px solid ${CW.border}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        flexShrink: 0,
      }}>{icon}</div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 15, fontWeight: 600, color: CW.ink, letterSpacing: -0.1 }}>{title}</div>
        <div style={{ fontSize: 13, color: CW.inkMuted, fontWeight: 450, marginTop: 2, lineHeight: 1.4 }}>{text}</div>
      </div>
    </div>
  );
}

function PlanCard({ selected, onClick, title, price, unit, sub, badge }) {
  return (
    <button
      onClick={onClick}
      style={{
        flex: 1, padding: '16px 14px', borderRadius: 14,
        background: selected ? CW.amberFaint : '#fff',
        border: selected ? `1.5px solid ${CW.amber}` : `1px solid ${CW.border}`,
        cursor: 'pointer', fontFamily: 'inherit', textAlign: 'left',
        position: 'relative', minHeight: 124,
        display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
      }}
    >
      <div>
        {badge && (
          <div style={{
            display: 'inline-block', fontSize: 10, fontWeight: 600,
            color: CW.amberDeep, background: '#fff',
            border: `1px solid ${CW.amberSoft}`,
            padding: '3px 8px', borderRadius: 6, letterSpacing: 0.2,
            marginBottom: 8,
          }}>{badge}</div>
        )}
        <div style={{ fontSize: 13, fontWeight: 500, color: CW.inkMuted, letterSpacing: -0.1 }}>{title}</div>
      </div>
      <div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 2 }}>
          <span className="num display" style={{ fontSize: 28, fontWeight: 600, color: CW.ink, letterSpacing: -0.8 }}>{price}</span>
          <span style={{ fontSize: 13, color: CW.caption, fontWeight: 500 }}>{unit}</span>
        </div>
        <div style={{ fontSize: 12, color: CW.caption, fontWeight: 500, marginTop: 2 }}>{sub}</div>
      </div>
    </button>
  );
}

// ─────────────────────────────────────────────────────────────
// 7. Home / Overview Dashboard
// ─────────────────────────────────────────────────────────────
function HomeScreen({ onTab, onFab, entries }) {
  // Today's split
  const todayByCat = useMemo(() => {
    const m = {};
    for (const e of entries) {
      m[e.category] = (m[e.category] || 0) + durationMin(e.start, e.end);
    }
    return Object.entries(m).map(([category, min]) => ({ category, min }))
      .sort((a, b) => b.min - a.min);
  }, [entries]);

  const totalToday = todayByCat.reduce((s, c) => s + c.min, 0);
  const totalWeek = WEEK_AVG.reduce((s, c) => s + c.hours * 60, 0);

  return (
    <ScreenShell>
      <div className="cw-scroll" style={{ flex: 1, overflowY: 'auto', padding: '6px 20px 130px' }}>
        <div style={{ padding: '4px 4px 22px' }}>
          <div className="display" style={{
            fontSize: 26, fontWeight: 600, color: CW.ink, letterSpacing: -0.6, lineHeight: 1.1,
          }}>Overview</div>
          <div style={{ marginTop: 4, fontSize: 13, color: CW.caption, fontWeight: 500 }}>
            How you've been spending your time
          </div>
        </div>

        {/* Hero — today donut */}
        <div style={{
          background: '#fff', border: `1px solid ${CW.border}`, borderRadius: 14,
          padding: 20, marginBottom: 18,
          display: 'flex', alignItems: 'center', gap: 18,
        }}>
          <DonutChart data={todayByCat} size={130} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 12, fontWeight: 600, color: CW.caption, textTransform: 'uppercase', letterSpacing: 0.6 }}>Today</div>
            <div className="num display" style={{ fontSize: 28, fontWeight: 600, color: CW.ink, letterSpacing: -0.6, marginTop: 4 }}>
              {fmtDuration(totalToday)}
            </div>
            <div style={{ fontSize: 12, color: CW.caption, fontWeight: 500, marginTop: 4 }}>tracked of 24h</div>
            {todayByCat[0] && (
              <div style={{
                marginTop: 12, padding: '8px 10px', borderRadius: 8,
                background: CW.cats[todayByCat[0].category]?.bg, display: 'inline-flex',
                alignItems: 'center', gap: 8,
              }}>
                <span style={{ width: 6, height: 6, borderRadius: 3, background: CW.cats[todayByCat[0].category]?.dot }} />
                <span style={{ fontSize: 12, fontWeight: 600, color: CW.cats[todayByCat[0].category]?.ink, letterSpacing: -0.1 }}>
                  Most: {todayByCat[0].category}
                </span>
              </div>
            )}
          </div>
        </div>

        {/* Week averages */}
        <div style={{
          display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
          padding: '0 4px 10px',
        }}>
          <SectionLabel>This week · daily average</SectionLabel>
          <div style={{ fontSize: 11, fontWeight: 500, color: CW.caption, letterSpacing: 0.2 }}>
            <span className="num">{fmtDuration(Math.round(totalWeek))}</span>/day
          </div>
        </div>
        <div style={{
          background: '#fff', border: `1px solid ${CW.border}`, borderRadius: 14,
          padding: '14px 16px', marginBottom: 22,
          display: 'flex', flexDirection: 'column', gap: 10,
        }}>
          {WEEK_AVG.map(c => {
            const tone = CW.cats[c.category];
            const pct = (c.hours * 60 / totalWeek) * 100;
            return (
              <div key={c.category} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{
                  width: 88, fontSize: 13, fontWeight: 500, color: CW.ink, letterSpacing: -0.1,
                  display: 'flex', alignItems: 'center', gap: 6,
                  flexShrink: 0,
                }}>
                  <span style={{ width: 6, height: 6, borderRadius: 3, background: tone?.dot, flexShrink: 0 }} />
                  {c.category}
                </div>
                <div style={{ flex: 1, height: 8, borderRadius: 4, background: CW.borderSoft, overflow: 'hidden' }}>
                  <div style={{
                    width: `${pct}%`, height: '100%',
                    background: tone?.dot, borderRadius: 4,
                  }} />
                </div>
                <div className="num" style={{
                  width: 52, textAlign: 'right', fontSize: 12, fontWeight: 500,
                  color: CW.inkMuted, letterSpacing: -0.1,
                }}>{c.hours}h</div>
              </div>
            );
          })}
        </div>

        {/* Streak / consistency strip */}
        <SectionLabel>Tracking streak</SectionLabel>
        <div style={{
          background: '#fff', border: `1px solid ${CW.border}`, borderRadius: 14,
          padding: '16px 16px',
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 12 }}>
            <div className="num display" style={{ fontSize: 22, fontWeight: 600, color: CW.ink, letterSpacing: -0.4 }}>
              14 days
            </div>
            <div style={{ fontSize: 12, color: CW.caption, fontWeight: 500 }}>last 21 days</div>
          </div>
          <StreakStrip />
        </div>
      </div>

      <FAB onClick={onFab} />
      <BottomNav active="home" onTab={onTab} />
    </ScreenShell>
  );
}

// Donut: SVG arcs, no library.
function DonutChart({ data, size = 130, thickness = 18 }) {
  const total = data.reduce((s, d) => s + d.min, 0);
  const r = (size - thickness) / 2;
  const c = 2 * Math.PI * r;
  const cx = size / 2, cy = size / 2;
  let acc = 0;
  return (
    <div style={{ width: size, height: size, position: 'relative', flexShrink: 0 }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={cx} cy={cy} r={r} fill="none" stroke={CW.borderSoft} strokeWidth={thickness} />
        {data.map((d, i) => {
          const frac = d.min / total;
          const dash = frac * c;
          const offset = -acc * c;
          acc += frac;
          const tone = CW.cats[d.category];
          return (
            <circle
              key={d.category}
              cx={cx} cy={cy} r={r} fill="none"
              stroke={tone?.dot || CW.caption} strokeWidth={thickness}
              strokeDasharray={`${dash} ${c - dash}`}
              strokeDashoffset={offset}
            />
          );
        })}
      </svg>
      <div style={{
        position: 'absolute', inset: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        flexDirection: 'column',
      }}>
        <div className="num display" style={{ fontSize: 18, fontWeight: 600, color: CW.ink, letterSpacing: -0.3 }}>
          {data.length}
        </div>
        <div style={{ fontSize: 10, color: CW.caption, fontWeight: 500, letterSpacing: 0.3, textTransform: 'uppercase' }}>
          categories
        </div>
      </div>
    </div>
  );
}

function StreakStrip() {
  // 21 cells, mostly tracked
  const days = Array.from({ length: 21 }).map((_, i) => {
    const v = i < 7 ? 0.3 : (i === 8 || i === 13 ? 0 : 0.5 + Math.random() * 0.5);
    return v;
  });
  return (
    <div style={{ display: 'flex', gap: 4 }}>
      {days.map((v, i) => (
        <div key={i} style={{
          flex: 1, height: 28, borderRadius: 4,
          background: v === 0
            ? CW.borderSoft
            : `color-mix(in srgb, ${CW.amber} ${Math.round(v * 100)}%, ${CW.amberFaint})`,
        }} />
      ))}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Toast
// ─────────────────────────────────────────────────────────────
function Toast({ text }) {
  return (
    <div style={{
      position: 'absolute', left: '50%', bottom: 180, transform: 'translateX(-50%)',
      background: '#1a1a1a', color: '#fff', padding: '10px 16px',
      borderRadius: 12, fontSize: 13, fontWeight: 500, letterSpacing: -0.1,
      display: 'flex', alignItems: 'center', gap: 8,
      animation: 'cw-toast-in 1800ms ease-out forwards',
      zIndex: 20, boxShadow: '0 8px 24px rgba(0,0,0,0.18)',
    }}>
      <Icon.Check s={14} c={CW.amber} />
      {text}
    </div>
  );
}

Object.assign(window, {
  ScreenShell, BottomNav, FAB,
  SignInScreen, TodayScreen, CaptureSheet, EditSheet, ProfileScreen, PaywallScreen, HomeScreen,
  Toast, WordmarkGlyph, SLOT_PX,
});
