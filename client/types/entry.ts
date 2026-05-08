export type EntrySource = 'voice' | 'text';

export interface Entry {
  id: string;
  category: string;
  note: string;
  startTime: string;
  endTime: string;
  source: EntrySource;
  transcript?: string;
  audioUrl?: string;
  createdAt: string;
}

export interface CapturedEntryDraft {
  category: string;
  note: string;
  startTime: string;
  endTime: string;
}
