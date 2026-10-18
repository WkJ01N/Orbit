'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {visibleEntity, mergeFeaturePayload} = require('./sync-visibility');

test('all deployment bundles match the shared compatibility source', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const shared = path.join(__dirname, '..', 'orbit-sync-common');
  for (const target of ['orbit-api', 'orbit-sync-pull', 'orbit-sync-push', 'orbit-sync-delete-data']) {
    for (const [source, destination] of [['index.js', 'sync-common.js'], ['sync-visibility.js', 'sync-visibility.js']]) {
      assert.equal(fs.readFileSync(path.join(shared, source), 'utf8'), fs.readFileSync(path.join(__dirname, '..', target, destination), 'utf8'), `${target}/${destination}`);
    }
  }
});

test('old clients cannot receive exams, exam statistics or their tombstones', () => {
  const events = {supportsStatistics: true};
  const entities = [
    {type: 'courseSession', id: 'exam|one', payload: {kind: 'exam'}},
    {type: 'courseSession', id: 'exam|one', deleted: true, payload: {}},
    {type: 'statistic', id: 'exam|exam|one', payload: {kind: 'exam'}},
  ];
  for (const e of entities) {
    assert.equal(visibleEntity(e, events), false);
    assert.equal(visibleEntity(e, {...events, supportsExams: true}), true);
  }
  assert.equal(visibleEntity(entities[0], {supportsExams:true, selection:{courses:false}}), false);
});

test('exam completion is monotonic while exclusions and semester assignments merge', () => {
  const old = {kind:'exam', counted:true, semesterId:'old', updatedAt:'2026-10-17T00:00:00Z'};
  const next = {kind:'exam', counted:false, excluded:true, semesterId:'new', updatedAt:'2026-10-18T00:00:00Z'};
  const merged = mergeFeaturePayload('statistic', next, old);
  assert.equal(merged.counted, true); assert.equal(merged.excluded, true); assert.equal(merged.semesterId, 'new');
  assert.deepEqual(merged, mergeFeaturePayload('statistic', old, next));
});

test('old clients preserve stable semester identity, ranges and per-exam settings', () => {
  assert.deepEqual(mergeFeaturePayload('semesterPlan', {name:'Term'}, {rangeStart:'2026-08-01', rangeEnd:'2027-01-31', source:'manual'}), {name:'Term', rangeStart:'2026-08-01', rangeEnd:'2027-01-31', source:'manual'});
  assert.equal(mergeFeaturePayload('courseSession', {courseName:'Math'}, {semesterId:'stable'}).semesterId, 'stable');
});
