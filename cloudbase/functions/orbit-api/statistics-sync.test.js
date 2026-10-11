const test = require('node:test');
const assert = require('node:assert/strict');
const {visibleEntity, mergeFeaturePayload} = require('./sync-visibility');
test('old clients never receive statistics; new clients can disable them', () => {
  const entity = {type:'statistic',id:'day|2026-10-11'};
  assert.equal(visibleEntity(entity,{supportsSettings:true}),false);
  assert.equal(visibleEntity(entity,{supportsStatistics:true}),true);
  assert.equal(visibleEntity(entity,{supportsStatistics:true,selection:{statistics:false}}),false);
});
test('legacy DDL edits preserve opt-out and batch association', () => {
  const merged = mergeFeaturePayload('deadline',{title:'Edited'},{countsTowardStatistics:false,batchId:'batch'});
  assert.equal(merged.countsTowardStatistics,false);
  assert.equal(merged.batchId,'batch');
  assert.equal(mergeFeaturePayload('deadline',{countsTowardStatistics:true},{countsTowardStatistics:false}).countsTowardStatistics,true);
});
test('concurrent statistic changes converge, keep completion and respect exclusion', () => {
  const earlier = {kind:'course',counted:true,updatedAt:'2026-10-10T00:00:00Z'};
  const later = {kind:'course',counted:false,excluded:true,updatedAt:'2026-10-11T00:00:00Z'};
  assert.deepEqual(mergeFeaturePayload('statistic',earlier,later),mergeFeaturePayload('statistic',later,earlier));
  assert.equal(mergeFeaturePayload('statistic',earlier,later).excluded,true);
  assert.equal(mergeFeaturePayload('statistic',earlier,later).counted,true);
  const restored = {...later,excluded:false,updatedAt:'2026-10-12T00:00:00Z'};
  assert.equal(mergeFeaturePayload('statistic',restored,later).excluded,false);
});

test('automatic first-use dates take the earliest device date; manual overrides persist', () => {
  const early = {kind:'profile', firstUsedDate:'2025-01-01', firstUsedDateAutomatic:true, updatedAt:'2026-01-01T00:00:00Z'};
  const late = {...early, firstUsedDate:'2026-01-01', updatedAt:'2026-02-01T00:00:00Z'};
  assert.equal(mergeFeaturePayload('statistic',late,early).firstUsedDate,'2025-01-01');
  assert.deepEqual(mergeFeaturePayload('statistic',late,early),mergeFeaturePayload('statistic',early,late));
  const manual = {...early, firstUsedDate:'2025-12-01', firstUsedDateAutomatic:false};
  assert.equal(mergeFeaturePayload('statistic',late,manual).firstUsedDate,'2025-12-01');
});
