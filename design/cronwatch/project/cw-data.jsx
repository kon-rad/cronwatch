// Sample data for a dense Tuesday May 5, 2026
// Each entry: { id, start: "HH:MM", end: "HH:MM", category, note }
// Times must align to 15-min slots.

const SEED_ENTRIES = [
  { id: 'e1',  start: '00:00', end: '07:15', category: 'Sleep',     note: 'Slept solid, woke before alarm' },
  { id: 'e2',  start: '07:15', end: '07:45', category: 'Personal',  note: 'Shower, get dressed' },
  { id: 'e3',  start: '07:45', end: '08:15', category: 'Meal',      note: 'Oatmeal + coffee' },
  { id: 'e4',  start: '08:15', end: '08:45', category: 'Commute',   note: 'Walk to coworking' },
  { id: 'e5',  start: '08:45', end: '09:00', category: 'Break',     note: 'Settled in, inbox triage' },
  { id: 'e6',  start: '09:00', end: '10:30', category: 'Deep',      note: 'Cronwatch onboarding redesign' },
  { id: 'e7',  start: '10:30', end: '10:45', category: 'Break',     note: 'Coffee + stretch' },
  { id: 'e8',  start: '10:45', end: '11:30', category: 'Meeting',   note: 'Standup + roadmap sync' },
  { id: 'e9',  start: '11:30', end: '12:30', category: 'Deep',      note: 'Capture sheet animations' },
  { id: 'e10', start: '12:30', end: '13:15', category: 'Meal',      note: 'Lunch — soba bowl' },
  { id: 'e11', start: '13:15', end: '13:45', category: 'Personal',  note: 'Errands — post office' },
  { id: 'e12', start: '13:45', end: '15:00', category: 'Work',      note: 'Code review + PR feedback' },
  { id: 'e13', start: '15:00', end: '15:45', category: 'Meeting',   note: '1:1 with Maya' },
  { id: 'e14', start: '15:45', end: '16:00', category: 'Break',     note: 'Tea, look out window' },
  { id: 'e15', start: '16:00', end: '17:30', category: 'Deep',      note: 'Paywall copy + plan structure' },
  { id: 'e16', start: '17:30', end: '18:30', category: 'Exercise',  note: 'Run along the river — 6.4km' },
  { id: 'e17', start: '18:30', end: '19:15', category: 'Meal',      note: 'Dinner — leftover pasta' },
  { id: 'e18', start: '19:15', end: '20:00', category: 'Study',     note: 'Reading — Designing Data-Intensive Apps' },
  { id: 'e19', start: '20:00', end: '21:30', category: 'Entertain', note: 'Show + couch decompression' },
  { id: 'e20', start: '21:30', end: '22:00', category: 'Personal',  note: 'Plan tomorrow, journal' },
  { id: 'e21', start: '22:00', end: '23:45', category: 'Sleep',     note: 'Wind-down, lights out' },
];

// Aggregate for dashboard — week averages (rough realistic split)
const WEEK_AVG = [
  { category: 'Sleep',     hours: 7.8 },
  { category: 'Work',      hours: 5.2 },
  { category: 'Deep',      hours: 3.4 },
  { category: 'Meeting',   hours: 1.8 },
  { category: 'Meal',      hours: 1.6 },
  { category: 'Exercise',  hours: 0.9 },
  { category: 'Study',     hours: 0.8 },
  { category: 'Entertain', hours: 1.4 },
  { category: 'Personal',  hours: 0.7 },
  { category: 'Commute',   hours: 0.4 },
];

// Helpers
function timeToMin(t) {
  const [h, m] = t.split(':').map(Number);
  return h * 60 + m;
}
function minToTime(m) {
  const h = Math.floor(m / 60), mm = m % 60;
  return `${String(h).padStart(2, '0')}:${String(mm).padStart(2, '0')}`;
}
function fmtTime12(t) {
  const [h, m] = t.split(':').map(Number);
  const ap = h >= 12 ? 'pm' : 'am';
  const h12 = h === 0 ? 12 : h > 12 ? h - 12 : h;
  return m === 0 ? `${h12} ${ap}` : `${h12}:${String(m).padStart(2,'0')} ${ap}`;
}
function durationMin(start, end) { return timeToMin(end) - timeToMin(start); }
function fmtDuration(min) {
  const h = Math.floor(min / 60), m = min % 60;
  if (h && m) return `${h}h ${m}m`;
  if (h) return `${h}h`;
  return `${m}m`;
}

// Generate 96 quarter-hour slots
function allSlots() {
  const out = [];
  for (let i = 0; i < 96; i++) {
    const m = i * 15;
    out.push(minToTime(m));
  }
  return out;
}

Object.assign(window, {
  SEED_ENTRIES, WEEK_AVG,
  timeToMin, minToTime, fmtTime12, durationMin, fmtDuration, allSlots,
});
