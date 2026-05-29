// Lucide-style icons, 1.5 stroke, rounded caps. Pure SVG, no deps.
const Icon = {
  Mic: ({ s = 22, c = 'currentColor', fill = 'none' }) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={fill === 'none' ? 'none' : fill} stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <rect x="9" y="3" width="6" height="12" rx="3" />
      <path d="M5 11a7 7 0 0 0 14 0" />
      <path d="M12 18v3" />
    </svg>
  ),
  Plus: ({ s = 22, c = 'currentColor' }) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 5v14M5 12h14" />
    </svg>
  ),
  Home: ({ s = 22, c = 'currentColor', filled = false }) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={filled ? c : 'none'} stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z" />
    </svg>
  ),
  Calendar: ({ s = 22, c = 'currentColor', filled = false }) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={filled ? c : 'none'} stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="5" width="18" height="16" rx="2" />
      <path d="M3 9h18M8 3v4M16 3v4" />
    </svg>
  ),
  User: ({ s = 22, c = 'currentColor', filled = false }) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={filled ? c : 'none'} stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="8" r="4" />
      <path d="M4 21a8 8 0 0 1 16 0" />
    </svg>
  ),
  Chevron: ({ s = 18, c = 'currentColor', dir = 'right' }) => {
    const d = { right: 'M9 6l6 6-6 6', left: 'M15 6l-6 6 6 6', down: 'M6 9l6 6 6-6', up: 'M6 15l6-6 6 6' }[dir];
    return (
      <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <path d={d} />
      </svg>
    );
  },
  Close: ({ s = 20, c = 'currentColor' }) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M6 6l12 12M18 6l-12 12" />
    </svg>
  ),
  Check: ({ s = 18, c = 'currentColor' }) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 12.5l4.5 4.5L19 7.5" />
    </svg>
  ),
  Trash: ({ s = 18, c = 'currentColor' }) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 7h16M9 7V4h6v3M6 7l1 13a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1l1-13M10 11v6M14 11v6" />
    </svg>
  ),
  Apple: ({ s = 18, c = 'currentColor' }) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={c}>
      <path d="M16.5 12.6c0-2.5 2-3.7 2.1-3.8-1.2-1.7-3-1.9-3.7-1.9-1.5-.2-3 .9-3.8.9-.8 0-2-.9-3.3-.9-1.7 0-3.3 1-4.2 2.5-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.2 2.5 1.3-.1 1.8-.8 3.4-.8s2 .8 3.3.8c1.4 0 2.3-1.2 3.1-2.5.6-.9 1.1-1.9 1.4-2.9-1.4-.6-2.8-2-2.8-4.1zM14.6 5.3c.7-.9 1.2-2.1 1-3.3-1.1.1-2.4.7-3.1 1.6-.7.8-1.3 2-1.1 3.2 1.2.1 2.4-.6 3.2-1.5z"/>
    </svg>
  ),
  Google: ({ s = 18 }) => (
    <svg width={s} height={s} viewBox="0 0 24 24">
      <path fill="#4285F4" d="M23 12.3c0-.8-.1-1.6-.2-2.3H12v4.4h6.2c-.3 1.4-1.1 2.6-2.3 3.4v2.8h3.7c2.2-2 3.4-4.9 3.4-8.3z"/>
      <path fill="#34A853" d="M12 23c3.1 0 5.7-1 7.6-2.8l-3.7-2.8c-1 .7-2.4 1.1-3.9 1.1-3 0-5.5-2-6.4-4.7H1.8v2.9C3.7 20.5 7.6 23 12 23z"/>
      <path fill="#FBBC05" d="M5.6 13.8c-.2-.7-.3-1.4-.3-2.2s.1-1.5.3-2.2V6.5H1.8C1 8.1.6 9.9.6 11.6s.4 3.5 1.2 5.1l3.8-2.9z"/>
      <path fill="#EA4335" d="M12 4.7c1.7 0 3.2.6 4.4 1.7l3.3-3.3C17.7 1.2 15.1 0 12 0 7.6 0 3.7 2.5 1.8 6.5l3.8 2.9C6.5 6.7 9 4.7 12 4.7z"/>
    </svg>
  ),
  GitHub: ({ s = 18, c = 'currentColor' }) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={c}>
      <path d="M12 .5C5.6.5.5 5.6.5 12c0 5.1 3.3 9.4 7.9 11 .6.1.8-.3.8-.6v-2c-3.2.7-3.9-1.5-3.9-1.5-.5-1.4-1.3-1.7-1.3-1.7-1.1-.7.1-.7.1-.7 1.2.1 1.8 1.2 1.8 1.2 1 1.8 2.7 1.3 3.4 1 .1-.8.4-1.3.7-1.6-2.6-.3-5.3-1.3-5.3-5.7 0-1.3.5-2.3 1.2-3.1-.1-.3-.5-1.5.1-3.1 0 0 1-.3 3.3 1.2 1-.3 2-.4 3-.4s2 .1 3 .4c2.3-1.5 3.3-1.2 3.3-1.2.7 1.6.2 2.8.1 3.1.8.8 1.2 1.9 1.2 3.1 0 4.4-2.7 5.4-5.3 5.7.4.4.8 1.1.8 2.2v3.3c0 .3.2.7.8.6 4.6-1.5 7.9-5.9 7.9-11C23.5 5.6 18.4.5 12 .5z"/>
    </svg>
  ),
  Lock: ({ s = 16, c = 'currentColor' }) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <rect x="4" y="11" width="16" height="10" rx="2" />
      <path d="M8 11V7a4 4 0 0 1 8 0v4" />
    </svg>
  ),
  Send: ({ s = 18, c = 'currentColor' }) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={c} stroke="none">
      <path d="M3 11l18-8-8 18-2-7-8-3z" />
    </svg>
  ),
  Type: ({ s = 18, c = 'currentColor' }) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 5h14M12 5v14M9 19h6" />
    </svg>
  ),
};

Object.assign(window, { Icon });
