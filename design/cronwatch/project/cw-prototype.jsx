// Interactive prototype — manages screen state and sheet overlays.
// Used both inside artboards on the canvas and standalone.

const { useState: usePState, useEffect: usePEffect, useRef: usePRef } = React;

function CronwatchPrototype({ initialScreen = 'today', signedIn = true }) {
  const [screen, setScreen] = usePState(signedIn ? initialScreen : 'signin');
  const [entries, setEntries] = usePState(SEED_ENTRIES);
  const [recentCats, setRecentCats] = usePState(['Deep', 'Meeting', 'Break']);

  // Overlay state
  const [showCapture, setShowCapture] = usePState(false);
  const [editEntry, setEditEntry] = usePState(null);
  const [showPaywall, setShowPaywall] = usePState(false);
  const [toast, setToast] = usePState(null);
  const [flashId, setFlashId] = usePState(null);

  const fireToast = (text) => {
    setToast(text);
    setTimeout(() => setToast(null), 1800);
  };

  // Find next open 15-min slot starting from "now" (mocked to a likely-empty slot)
  const findNextOpenSlot = () => {
    // Use an explicit slot likely to be empty in our seed: 13:15 area is
    // filled. Try a 30-min block starting 30 min after the latest end that is
    // still in the day.
    const sortedEnds = entries.map(e => timeToMin(e.end)).sort((a, b) => a - b);
    const latest = sortedEnds[sortedEnds.length - 1] || (12 * 60);
    let start = Math.min(23 * 60 + 0, latest);
    // Snap forward to a free slot
    for (let m = start; m < 24 * 60 - 30; m += 15) {
      const isFree = !entries.some(e => timeToMin(e.start) <= m && timeToMin(e.end) > m)
                  && !entries.some(e => timeToMin(e.start) <= m + 15 && timeToMin(e.end) > m + 15);
      if (isFree) return { start: minToTime(m), end: minToTime(m + 30) };
    }
    return { start: '23:00', end: '23:30' };
  };

  const handleSaveCapture = ({ category, note }) => {
    const slot = findNextOpenSlot();
    const id = 'n' + Date.now();
    const fresh = { id, ...slot, category, note: note || category };
    setEntries(es => [...es, fresh]);
    setRecentCats(prev => [category, ...prev.filter(c => c !== category)].slice(0, 5));
    setShowCapture(false);
    fireToast('Logged.');
    setFlashId(id);
    setTimeout(() => setFlashId(null), 1400);
    // Make sure we land on Today so user sees the new entry
    setScreen('today');
  };

  const handleSaveEdit = (updated) => {
    setEntries(es => es.map(e => e.id === updated.id ? updated : e));
    setEditEntry(null);
    fireToast('Updated.');
  };
  const handleDelete = () => {
    if (!editEntry) return;
    setEntries(es => es.filter(e => e.id !== editEntry.id));
    setEditEntry(null);
    fireToast('Deleted.');
  };

  const handleTab = (key) => {
    if (key === 'today') setScreen('today');
    if (key === 'home') setScreen('home');
    if (key === 'profile') setScreen('profile');
  };

  // Render base screen
  let body = null;
  if (screen === 'signin') {
    body = <SignInScreen onSignIn={() => setScreen('today')} />;
  } else if (screen === 'home') {
    body = <HomeScreen onTab={handleTab} onFab={() => setShowCapture(true)} entries={entries} />;
  } else if (screen === 'today') {
    body = <TodayScreen
      entries={entries}
      onTab={handleTab}
      onFab={() => setShowCapture(true)}
      onEntryTap={(e) => setEditEntry(e)}
      flashId={flashId}
      hideFab={showCapture || editEntry || showPaywall}
    />;
  } else if (screen === 'profile') {
    body = <ProfileScreen onTab={handleTab} onUpgrade={() => setShowPaywall(true)} plan="Free" />;
  }

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      {body}
      {showCapture && (
        <>
          <div onClick={() => setShowCapture(false)} style={{
            position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.18)',
            zIndex: 9, animation: 'cw-fadein-up 200ms ease-out',
          }} />
          <CaptureSheet
            onCancel={() => setShowCapture(false)}
            onSave={handleSaveCapture}
          />
        </>
      )}
      {editEntry && (
        <>
          <div onClick={() => setEditEntry(null)} style={{
            position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.18)',
            zIndex: 9, animation: 'cw-fadein-up 200ms ease-out',
          }} />
          <EditSheet
            entry={editEntry}
            recentCats={recentCats}
            onCancel={() => setEditEntry(null)}
            onSave={handleSaveEdit}
            onDelete={handleDelete}
          />
        </>
      )}
      {showPaywall && (
        <div style={{
          position: 'absolute', inset: 0, zIndex: 11, background: CW.bg,
          animation: 'cw-fadein-up 220ms ease-out',
        }}>
          <PaywallScreen
            onClose={() => setShowPaywall(false)}
            onSubscribe={() => { setShowPaywall(false); fireToast('Subscribed (mock).'); }}
          />
        </div>
      )}
      {toast && <Toast text={toast} />}
    </div>
  );
}

// Static screen (no interactive sheets) — used to show specific screens on the canvas
function StaticScreen({ kind, withSheet, entries = SEED_ENTRIES }) {
  const noop = () => {};
  let body;
  if (kind === 'signin') body = <SignInScreen onSignIn={noop} />;
  else if (kind === 'today') body = <TodayScreen entries={entries} onTab={noop} onFab={noop} onEntryTap={noop} />;
  else if (kind === 'home') body = <HomeScreen onTab={noop} onFab={noop} entries={entries} />;
  else if (kind === 'profile') body = <ProfileScreen onTab={noop} onUpgrade={noop} plan="Free" />;
  else if (kind === 'paywall') body = <PaywallScreen onClose={noop} onSubscribe={noop} />;
  else body = null;

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      {body}
      {withSheet === 'capture' && <StaticCaptureSheet />}
      {withSheet === 'edit' && <StaticEditSheet entry={entries.find(e => e.category === 'Meeting') || entries[12]} />}
    </div>
  );
}

function StaticCaptureSheet() {
  return (
    <>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.18)', zIndex: 9 }} />
      <CaptureSheet onCancel={() => {}} onSave={() => {}} />
    </>
  );
}
function StaticEditSheet({ entry }) {
  return (
    <>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.18)', zIndex: 9 }} />
      <EditSheet entry={entry} onCancel={() => {}} onSave={() => {}} onDelete={() => {}} recentCats={['Deep','Meeting','Break']} />
    </>
  );
}

Object.assign(window, { CronwatchPrototype, StaticScreen });
