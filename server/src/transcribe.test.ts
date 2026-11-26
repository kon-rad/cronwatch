import { test } from 'node:test';
import assert from 'node:assert/strict';

// The provider module initializes the Together client when imported.
process.env.TOGETHER_API_KEY ||= 'test-only';
const { parseProvider } = require('./transcribe') as typeof import('./transcribe');

test('missing or unknown provider uses Together transcription', () => {
  assert.equal(parseProvider(undefined), 'together');
  assert.equal(parseProvider('retired-provider'), 'together');
});

test('explicit supported provider is preserved', () => {
  assert.equal(parseProvider('together'), 'together');
  assert.equal(parseProvider('deepgram'), 'deepgram');
});
