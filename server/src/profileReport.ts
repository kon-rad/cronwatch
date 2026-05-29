import type { Response } from 'express';
import Together from 'together-ai';
import { z } from 'zod';
import { env } from './env';
import type { AuthedRequest } from './auth';
import { PROFILE_REPORT_SYSTEM_PROMPT } from './prompts';

const together = new Together({ apiKey: env.together.apiKey });

const MAX_RANGE_DAYS = 92;

const requestSchema = z.object({
  rangeStart: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  rangeEnd: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  tz: z.string().optional(),
  customPrompt: z.string().max(500).optional(),
  goals: z.array(z.string().max(200)).optional(),
  days: z
    .array(
      z.object({
        date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
        categories: z.array(
          z.object({
            name: z.string().min(1).max(40),
            minutes: z.number().int().nonnegative().max(24 * 60),
          }),
        ),
      }),
    )
    .min(1)
    .max(MAX_RANGE_DAYS),
});

const responseSchema = z.object({
  title: z.string().min(1).max(120),
  html: z.string().min(20),
});

type ReportResponse = z.infer<typeof responseSchema>;

const SYSTEM_PROMPT = PROFILE_REPORT_SYSTEM_PROMPT;

export async function profileReportHandler(req: AuthedRequest, res: Response): Promise<void> {
  const uid = req.uid;
  if (!uid) {
    res.status(401).json({ error: 'Unauthenticated' });
    return;
  }

  const parsed = requestSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: `Invalid request: ${parsed.error.message}` });
    return;
  }
  const { rangeStart, rangeEnd, tz, customPrompt, goals, days } = parsed.data;

  const nonEmptyGoals = (goals ?? []).map((g) => g.trim()).filter((g) => g.length > 0);
  const trimmedPrompt = (customPrompt ?? '').trim();

  const userPrompt = buildUserPrompt(rangeStart, rangeEnd, tz, nonEmptyGoals, trimmedPrompt, days);

  try {
    const completion = await together.chat.completions.create({
      model: env.together.reportModel,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.7,
      max_tokens: 8000,
      response_format: { type: 'json_object' },
    });

    const content = completion.choices?.[0]?.message?.content;
    if (typeof content !== 'string' || content.trim() === '') {
      throw new Error('LLM returned empty content');
    }

    let raw: unknown;
    try {
      raw = JSON.parse(content);
    } catch {
      throw new Error(`LLM returned non-JSON: ${content.slice(0, 200)}`);
    }

    const validated = responseSchema.parse(raw);
    res.json(validated satisfies ReportResponse);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Profile report failed';
    console.error('[profile-report] error:', err);
    res.status(500).json({ error: message });
  }
}

function buildUserPrompt(
  rangeStart: string,
  rangeEnd: string,
  tz: string | undefined,
  nonEmptyGoals: string[],
  customPrompt: string,
  days: z.infer<typeof requestSchema>['days'],
): string {
  const goalsBlock = nonEmptyGoals.length === 0
    ? '(no goals provided)'
    : nonEmptyGoals.map((g, i) => `  ${i + 1}. ${g}`).join('\n');

  const promptBlock = customPrompt === ''
    ? '(none)'
    : customPrompt;

  const dayLines = days
    .map((day) => {
      const cats = day.categories.length === 0
        ? '(nothing tracked)'
        : day.categories.map((c) => `${c.name} ${c.minutes}m`).join(', ');
      return `  ${day.date}: ${cats}`;
    })
    .join('\n');

  const totals = aggregateTotals(days);
  const totalLines = totals.length === 0
    ? '(no time tracked)'
    : totals
        .map((t) => `  ${t.name}: ${t.minutes}m (${formatHm(t.minutes)})`)
        .join('\n');

  const totalMinutes = totals.reduce((sum, t) => sum + t.minutes, 0);
  const numDays = days.length;

  return `Date range: ${rangeStart} → ${rangeEnd}${tz ? ` (timezone ${tz})` : ''}
Days in range: ${numDays}
Total minutes tracked: ${totalMinutes} (${formatHm(totalMinutes)})

Goals:
${goalsBlock}

User request / comment:
${promptBlock}

Per-category totals:
${totalLines}

Daily breakdown:
${dayLines}

Now produce the JSON described in the system prompt.`;
}

function aggregateTotals(
  days: z.infer<typeof requestSchema>['days'],
): { name: string; minutes: number }[] {
  const totals: Record<string, number> = {};
  const order: string[] = [];
  for (const day of days) {
    for (const cat of day.categories) {
      if (totals[cat.name] === undefined) order.push(cat.name);
      totals[cat.name] = (totals[cat.name] ?? 0) + cat.minutes;
    }
  }
  return order
    .map((name) => ({ name, minutes: totals[name] ?? 0 }))
    .sort((a, b) => b.minutes - a.minutes);
}

function formatHm(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m}m`;
  if (m === 0) return `${h}h`;
  return `${h}h${String(m).padStart(2, '0')}`;
}
