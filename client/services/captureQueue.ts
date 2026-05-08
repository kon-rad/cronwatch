import { captureFromAudio } from '@/services/capture';
import { createEntry } from '@/services/entries';

export type JobStatus = 'queued' | 'running' | 'done' | 'error';

export type Job = {
  id: string;
  uid: string;
  uri: string;
  status: JobStatus;
  error?: string;
};

type Listener = (jobs: Job[]) => void;

let jobs: Job[] = [];
const listeners = new Set<Listener>();
let working = false;

function emit() {
  const snap = [...jobs];
  for (const l of listeners) l(snap);
}

function nextJobId(): string {
  return `j_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
}

async function tick(): Promise<void> {
  if (working) return;
  const job = jobs.find((j) => j.status === 'queued');
  if (!job) return;
  working = true;
  job.status = 'running';
  job.error = undefined;
  emit();
  try {
    const result = await captureFromAudio(job.uri);
    await createEntry(job.uid, {
      ...result.draft,
      source: 'voice',
      transcript: result.transcript,
      audioUrl: result.audioUrl,
    });
    job.status = 'done';
    emit();
    setTimeout(() => {
      jobs = jobs.filter((j) => j.id !== job.id);
      emit();
    }, 0);
  } catch (err) {
    job.status = 'error';
    job.error = err instanceof Error ? err.message : 'Unknown error';
    emit();
  } finally {
    working = false;
    if (jobs.some((j) => j.status === 'queued')) {
      void tick();
    }
  }
}

export function enqueue(uid: string, uri: string): string {
  const job: Job = { id: nextJobId(), uid, uri, status: 'queued' };
  jobs.push(job);
  emit();
  void tick();
  return job.id;
}

export function retry(jobId: string): void {
  const job = jobs.find((j) => j.id === jobId);
  if (!job || job.status !== 'error') return;
  job.status = 'queued';
  job.error = undefined;
  emit();
  void tick();
}

export function subscribe(cb: Listener): () => void {
  listeners.add(cb);
  cb([...jobs]);
  return () => {
    listeners.delete(cb);
  };
}

export function __reset(): void {
  jobs = [];
  listeners.clear();
  working = false;
}
