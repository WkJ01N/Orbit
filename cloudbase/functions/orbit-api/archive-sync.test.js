'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { mergeFeaturePayload } = require('./sync-visibility');

test('legacy course edits retain archive, association and period metadata', () => {
  const previous = { archivedAt: '2026-10-08', archiveHidden: true, autoArchivePaused: false,
    linkedCourseKey: 'original', startPeriod: 1, periodTimePlanId: 'plan', room: 'Old' };
  const merged = mergeFeaturePayload('courseSession', { room: 'New' }, previous);
  assert.equal(merged.room, 'New');
  for (const key of Object.keys(previous).filter(k => k !== 'room')) assert.equal(merged[key], previous[key]);
});
test('modern explicit unarchive is honored', () => {
  assert.deepEqual(mergeFeaturePayload('deadline', { archivedAt: null, archiveHidden: false },
    { archivedAt: '2026-10-08', archiveHidden: true }), { archivedAt: null, archiveHidden: false });
});
test('legacy completed DDL edits retain archive metadata', () => {
  assert.deepEqual(mergeFeaturePayload('deadline', { title: 'Edited' }, { archiveHidden: true }),
    { title: 'Edited', archiveHidden: true });
});
test('unrelated sync entities and source objects are unchanged', () => {
  const source = { name: 'Plan' };
  assert.equal(mergeFeaturePayload('periodTimePlan', source, { archiveHidden: true }), source);
  mergeFeaturePayload('courseSession', source, { archiveHidden: true });
  assert.deepEqual(source, { name: 'Plan' });
});
