import { z } from 'zod';

export const capturedEntryDraftSchema = z.object({
  category: z.string().min(1),
  note: z.string(),
  startTime: z.string(),
  endTime: z.string(),
});

export type CapturedEntryDraft = z.infer<typeof capturedEntryDraftSchema>;
