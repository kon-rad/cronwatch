import type { Response } from 'express';
import Together from 'together-ai';
import { z } from 'zod';
import { env } from './env';
import type { AuthedRequest } from './auth';
import { WEEK_REPORT_SYSTEM_PROMPT } from './prompts';

const together = new Together({ apiKey: env.together.apiKey });

const requestSchema = z.object({
  goals: z.array(z.string().max(200)).length(3),
  weekStart: z.string().min(1),
  weekEnd: z.string().min(1),
  tz: z.string().optional(),
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
    .length(7),
});

const responseSchema = z.object({
  goalAnalyses: z.array(
    z.object({
      goal: z.string().min(1),
      summary: z.string().min(1),
    }),
  ),
  ideas: z.array(z.string().min(1)),
});

type ReportResponse = z.infer<typeof responseSchema>;

const SYSTEM_PROMPT = WEEK_REPORT_SYSTEM_PROMPT;

export async function weekReportHandler(req: AuthedRequest, res: Response): Promise<void> {
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
  const { goals, weekStart, weekEnd, days, tz } = parsed.data;

  const nonEmptyGoals = goals.map((g) => g.trim()).filter((g) => g.length > 0);
  if (nonEmptyGoals.length === 0) {
    res.status(400).json({ error: 'Set at least one goal before generating a report.' });
    return;
  }

  const userPrompt = buildUserPrompt(goals, weekStart, weekEnd, tz, days);

  try {
    const completion = await together.chat.completions.create({
      model: env.together.model,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.7,
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
    const cleaned = clampResponse(validated, nonEmptyGoals);
    res.json(cleaned satisfies ReportResponse);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Week report failed';
    console.error('[week-report] error:', err);
    res.status(500).json({ error: message });
  }
}

function buildUserPrompt(
  goals: string[],
  weekStart: string,
  weekEnd: string,
  tz: string | undefined,
  days: z.infer<typeof requestSchema>['days'],
): string {
  const goalLines = goals
    .map((goal, idx) => `  ${idx + 1}. ${goal.trim() === '' ? '(blank — skip)' : goal.trim()}`)
    .join('\n');

  const dayLines = days
    .map((day) => {
      const cats =
        day.categories.length === 0
          ? '(nothing tracked)'
          : day.categories
              .map((c) => `${c.name} ${c.minutes}m (${formatHm(c.minutes)})`)
              .join(', ');
      return `  ${day.date}: ${cats}`;
    })
    .join('\n');

  const totals = aggregateTotals(days);
  const totalLines = totals.length === 0
    ? '(no time tracked this week)'
    : totals
        .map((t) => `  ${t.name}: ${t.minutes}m (${formatHm(t.minutes)}), avg ${formatHm(Math.round(t.minutes / 7))}/day`)
        .join('\n');

  return `Week range: ${weekStart} → ${weekEnd}${tz ? ` (timezone ${tz})` : ''}

Goals:
${goalLines}

Daily breakdown (minutes by category):
${dayLines}

7-day totals:
${totalLines}

Now produce the JSON described in the system prompt.`;
}

function aggregateTotals(days: z.infer<typeof requestSchema>['days']): { name: string; minutes: number }[] {
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

// Defensive cleanup: ensure non-empty goals are reflected verbatim, drop blanks,
// pad/truncate ideas to 10 to keep the client contract stable.
function clampResponse(report: ReportResponse, nonEmptyGoals: string[]): ReportResponse {
  const wanted = new Set(nonEmptyGoals);
  const filteredAnalyses = report.goalAnalyses.filter((a) => wanted.has(a.goal.trim()));

  // Reorder to match the original non-empty goals order; tolerate the LLM
  // dropping or duplicating an entry (fall back to a placeholder summary).
  const byGoal = new Map(filteredAnalyses.map((a) => [a.goal.trim(), a]));
  const orderedAnalyses = nonEmptyGoals.map(
    (goal) => byGoal.get(goal) ?? { goal, summary: 'No summary available for this goal.' },
  );

  let ideas = report.ideas.map((s) => s.trim()).filter((s) => s.length > 0);
  if (ideas.length > 10) ideas = ideas.slice(0, 10);
  while (ideas.length < 10) ideas.push('Reflect on which activity gave you the most energy this week and protect time for more of it.');

  return { goalAnalyses: orderedAnalyses, ideas };
}
