import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import Together from 'together-ai';
import { z } from 'zod';
import { env } from './env';
import { buildTranscriptSystemPrompt } from './prompts';

const together = new Together({ apiKey: env.together.apiKey });

// Single source of truth shared with the client. See shared/categories.json.
const categoriesData = JSON.parse(
  readFileSync(join(__dirname, '../../shared/categories.json'), 'utf-8'),
) as Array<{ key: string; label: string }>;

const CATEGORIES: readonly string[] = categoriesData.map((c) => c.key);
const CATEGORY_SET: ReadonlySet<string> = new Set(CATEGORIES);

const CATEGORY_ALIASES: Record<string, string> = {
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

function normalizeCategory(raw: string): string {
  const cleaned = raw.trim().toLowerCase();
  if (CATEGORY_SET.has(cleaned)) return cleaned;
  if (CATEGORY_ALIASES[cleaned]) return CATEGORY_ALIASES[cleaned];
  // try first token (e.g., "deep work" → "deep")
  const first = cleaned.split(/[\s_-]+/)[0] ?? '';
  if (CATEGORY_SET.has(first)) return first;
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

export const draftsResponseSchema = z.object({
  entries: z.array(draftSchema).min(1),
});

export type Draft = z.infer<typeof draftSchema>;

const SYSTEM_PROMPT = buildTranscriptSystemPrompt(CATEGORIES);

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
): Promise<Draft[]> {
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

  const drafts = coerceDrafts(parsed);

  const normalized = drafts.map((draft) => {
    // Normalize category to the allowed enum so downstream rendering and
    // analytics never see freeform strings.
    draft.category = normalizeCategory(draft.category);

    // Enforce endTime > startTime. The model occasionally anchors both clock
    // times to the same day even when the memo crosses midnight ("11pm to
    // 9am" said in the morning). Back-dating the start by 24h recovers the
    // intended span when it would otherwise fit within a day.
    const start = new Date(draft.startTime).getTime();
    const end = new Date(draft.endTime).getTime();
    if (end <= start) {
      const dayMs = 24 * 60 * 60 * 1000;
      const startMinusDay = start - dayMs;
      if (end - startMinusDay > 0 && end - startMinusDay <= dayMs) {
        draft.startTime = new Date(startMinusDay).toISOString();
      } else {
        draft.endTime = new Date(start + 60 * 1000).toISOString();
      }
    }

    return draft;
  });

  // Backstop: enforce non-overlap between entries. Gaps are allowed; if a
  // later entry's start falls inside an earlier entry's span, shift its start
  // forward to the earlier entry's end (preserving its endTime when possible).
  normalized.sort(
    (a, b) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime(),
  );
  for (let i = 1; i < normalized.length; i++) {
    const prevEnd = new Date(normalized[i - 1].endTime).getTime();
    const curStart = new Date(normalized[i].startTime).getTime();
    if (curStart < prevEnd) {
      normalized[i].startTime = new Date(prevEnd).toISOString();
      const curEnd = new Date(normalized[i].endTime).getTime();
      if (curEnd <= prevEnd) {
        normalized[i].endTime = new Date(prevEnd + 60 * 1000).toISOString();
      }
    }
  }

  return normalized;
}

// Older prompt iterations and lenient models sometimes return a bare draft object
// or a bare array instead of {entries: [...]}. Accept all three shapes.
function coerceDrafts(parsed: unknown): Draft[] {
  if (Array.isArray(parsed)) {
    return z.array(draftSchema).min(1).parse(parsed);
  }
  if (parsed && typeof parsed === 'object' && 'entries' in parsed) {
    return draftsResponseSchema.parse(parsed).entries;
  }
  return [draftSchema.parse(parsed)];
}
