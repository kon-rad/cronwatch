import Together from 'together-ai';
import { z } from 'zod';
import { env } from './env';

const together = new Together({ apiKey: env.together.apiKey });

const CATEGORIES = [
  'work',
  'deep',
  'meeting',
  'study',
  'exercise',
  'sleep',
  'meal',
  'break',
  'commute',
  'entertain',
  'personal',
] as const;

type Category = (typeof CATEGORIES)[number];
const CATEGORY_SET: ReadonlySet<string> = new Set(CATEGORIES);

const CATEGORY_ALIASES: Record<string, Category> = {
  // common synonyms the model might emit
  workout: 'exercise',
  gym: 'exercise',
  run: 'exercise',
  running: 'exercise',
  yoga: 'exercise',
  walk: 'exercise',
  reading: 'study',
  read: 'study',
  learn: 'study',
  course: 'study',
  lunch: 'meal',
  breakfast: 'meal',
  dinner: 'meal',
  food: 'meal',
  eating: 'meal',
  eat: 'meal',
  coffee: 'break',
  rest: 'break',
  pause: 'break',
  drive: 'commute',
  driving: 'commute',
  train: 'commute',
  bus: 'commute',
  travel: 'commute',
  meet: 'meeting',
  standup: 'meeting',
  sync: 'meeting',
  call: 'meeting',
  '1:1': 'meeting',
  focus: 'deep',
  refactor: 'deep',
  coding: 'deep',
  writing: 'deep',
  design: 'deep',
  nap: 'sleep',
  movie: 'entertain',
  tv: 'entertain',
  game: 'entertain',
  gaming: 'entertain',
  social: 'entertain',
  errand: 'personal',
  errands: 'personal',
  chores: 'personal',
  family: 'personal',
};

function normalizeCategory(raw: string): Category {
  const cleaned = raw.trim().toLowerCase();
  if (CATEGORY_SET.has(cleaned)) return cleaned as Category;
  if (CATEGORY_ALIASES[cleaned]) return CATEGORY_ALIASES[cleaned];
  // try first token (e.g., "deep work" → "deep")
  const first = cleaned.split(/[\s_-]+/)[0] ?? '';
  if (CATEGORY_SET.has(first)) return first as Category;
  if (CATEGORY_ALIASES[first]) return CATEGORY_ALIASES[first];
  return 'work';
}

const isoDateTime = z.string().refine(
  (s) => !Number.isNaN(new Date(s).getTime()),
  { message: 'Invalid ISO datetime' },
);

export const draftSchema = z.object({
  category: z.string().min(1),
  note: z.string(),
  startTime: isoDateTime,
  endTime: isoDateTime,
});

export type Draft = z.infer<typeof draftSchema>;

const SYSTEM_PROMPT = `You convert a single short time-tracking memo (typed or voice-transcribed) into a JSON entry.

Allowed categories (return one of these as "category", lowercase, exact match): ${CATEGORIES.join(', ')}.
If the memo doesn't match any, pick the closest one. Never invent new categories.

Rules:
- "note" is a short human-readable label (under 80 chars) describing what the user did. Strip filler words and meta phrases like "I just" or "log that".
- "startTime" and "endTime" are ISO 8601 strings WITH the user's local timezone offset (e.g. "2026-05-08T09:00:00-07:00"). Never return naked times without an offset.
- Anchor every relative phrase to the user's LOCAL "now" provided below.
- If the memo names explicit clock times ("from 9 to 10:30"), anchor them to today's date in the user's timezone. If only a single time is given, treat it as the start and set endTime to local now.
- If the memo says "just now", "the last hour", "for X minutes", or omits times, set endTime = local now and set startTime = endTime minus the implied duration (default 30 minutes if unspecified).
- endTime MUST be >= startTime. If they collide, end = start + 1 minute.
- Never return a time more than 24 hours away from local now.

Return ONLY a JSON object with keys: category, note, startTime, endTime. No prose, no markdown.`;

function formatLocal(date: Date, tz?: string): { local: string; offset: string } {
  if (!tz) {
    return { local: date.toISOString(), offset: 'Z' };
  }
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: tz,
      year: 'numeric',
      month: 'short',
      day: '2-digit',
      weekday: 'short',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false,
      timeZoneName: 'longOffset',
    }).formatToParts(date);
    const local = parts
      .filter((p) => p.type !== 'timeZoneName')
      .map((p) => p.value)
      .join('')
      .trim();
    const offset = parts.find((p) => p.type === 'timeZoneName')?.value ?? '';
    // longOffset gives e.g. "GMT-07:00" — strip the "GMT" prefix
    const cleanOffset = offset.replace(/^GMT/, '') || 'Z';
    return { local, offset: cleanOffset };
  } catch {
    return { local: date.toISOString(), offset: 'Z' };
  }
}

export async function structure(
  transcript: string,
  now: Date,
  tz?: string,
): Promise<Draft> {
  const { local, offset } = formatLocal(now, tz);
  const userPrompt = `User local now: ${local}
User timezone: ${tz ?? 'unknown'} (offset ${offset})
UTC now: ${now.toISOString()}

Memo: """${transcript}"""`;

  const completion = await together.chat.completions.create({
    model: env.together.model,
    messages: [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: userPrompt },
    ],
    temperature: 0.1,
    response_format: { type: 'json_object' },
  });

  const content = completion.choices?.[0]?.message?.content;
  if (typeof content !== 'string' || content.trim() === '') {
    throw new Error('Together AI returned empty content');
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    throw new Error(`Together AI returned non-JSON content: ${content.slice(0, 200)}`);
  }

  const draft = draftSchema.parse(parsed);

  // Normalize category to the allowed enum so downstream rendering and
  // analytics never see freeform strings.
  draft.category = normalizeCategory(draft.category);

  // Enforce endTime >= startTime. Models occasionally swap or collide them.
  const start = new Date(draft.startTime).getTime();
  const end = new Date(draft.endTime).getTime();
  if (end < start) {
    draft.endTime = new Date(start + 60 * 1000).toISOString();
  } else if (end === start) {
    draft.endTime = new Date(start + 60 * 1000).toISOString();
  }

  return draft;
}
