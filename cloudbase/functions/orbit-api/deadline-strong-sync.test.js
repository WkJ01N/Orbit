const test=require('node:test');
const assert=require('node:assert/strict');
const {mergeFeaturePayload}=require('./sync-visibility');
test('legacy DDL updates preserve strong configuration and future cancellations',()=>{
  const previous={strongReminderEnabled:true,strongLeadMinutes:[180,60],disabledReminderLeadMinutes:[60]};
  assert.deepEqual(mergeFeaturePayload('deadline',{title:'Edited'},previous),{title:'Edited',...previous});
  const cleared=mergeFeaturePayload('deadline',{strongReminderEnabled:false,strongLeadMinutes:[],disabledReminderLeadMinutes:[]},previous);
  assert.equal(cleared.strongReminderEnabled,false);assert.deepEqual(cleared.strongLeadMinutes,[]);assert.deepEqual(cleared.disabledReminderLeadMinutes,[]);
});
test('old display settings preserve independent navigation preferences',()=>{
  const previous={scheduleDisplay:{hideUpcomingPage:true,hideImportPage:true}};
  assert.deepEqual(mergeFeaturePayload('settingGroup',{gridDensity:'standard'},previous).scheduleDisplay,previous.scheduleDisplay);
  const edited=mergeFeaturePayload('settingGroup',{scheduleDisplay:{fitToPage:true}},previous);
  assert.deepEqual(edited.scheduleDisplay,{fitToPage:true,hideUpcomingPage:true,hideImportPage:true});
  const explicit=mergeFeaturePayload('settingGroup',{scheduleDisplay:{hideUpcomingPage:false,hideImportPage:false}},previous);
  assert.equal(explicit.scheduleDisplay.hideUpcomingPage,false);assert.equal(explicit.scheduleDisplay.hideImportPage,false);
});
