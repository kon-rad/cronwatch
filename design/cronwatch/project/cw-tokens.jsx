// Cronwatch design tokens
const CW = {
  bg: '#FAFAF7',
  ink: '#111111',
  inkMuted: '#5C5C58',
  caption: '#9A9A95',
  border: '#ECECEA',
  borderSoft: '#F2F2EF',
  amber: '#E8A33D',
  amberSoft: '#F5D69A',
  amberFaint: '#FBEFD6',
  amberDeep: '#C7842A',
  red: '#C5483D',
  shadow: '0 1px 2px rgba(0,0,0,0.04)',
  shadowMd: '0 1px 2px rgba(0,0,0,0.04), 0 8px 24px rgba(0,0,0,0.06)',
  // Category palette — muted, considered. Each has a tinted bg + ink.
  cats: {
    Work:        { bg: '#EEF1ED', ink: '#3F5440', dot: '#7B9075' },
    Deep:        { bg: '#E9EEF3', ink: '#3D5066', dot: '#6F89A8' },
    Meeting:     { bg: '#F2EDE6', ink: '#5C4A2E', dot: '#9C7E4F' },
    Study:       { bg: '#F0EEF5', ink: '#4E456B', dot: '#8579A8' },
    Exercise:    { bg: '#F3ECEA', ink: '#6E4339', dot: '#B07469' },
    Sleep:       { bg: '#ECEDF2', ink: '#3F4458', dot: '#6B7290' },
    Meal:        { bg: '#F4EFE6', ink: '#6B5530', dot: '#A88752' },
    Break:       { bg: '#EFF1EE', ink: '#4D5B4A', dot: '#84957F' },
    Commute:     { bg: '#EEEFEA', ink: '#535A47', dot: '#8B947A' },
    Entertain:   { bg: '#F1ECEE', ink: '#5E4350', dot: '#9C7686' },
    Personal:    { bg: '#EEEFEC', ink: '#4B524A', dot: '#7F8779' },
  },
};

Object.assign(window, { CW });
