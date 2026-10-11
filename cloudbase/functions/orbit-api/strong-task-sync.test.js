const test = require('node:test');
const assert = require('node:assert/strict');
const {mergeFeaturePayload} = require('./sync-visibility');
test('older clients preserve global and per-rule challenge options', () => {
  const options = {mixedRounds:10, sequenceNumberCount:25, arithmeticDifficulty:'hard', arithmeticAnswerMode:'choice6', arithmeticRounds:4, sequenceRounds:5};
  const previous = {strong:{...options,enabled:true},ruleOverrides:{a:{strength:'strong',strongOverride:{...options}}}};
  const incoming = {strong:{enabled:false},ruleOverrides:{a:{strength:'strong',strongOverride:{answerSeconds:45}}}};
  const merged = mergeFeaturePayload('settingGroup',incoming,previous);
  assert.deepEqual(merged.strong,{enabled:false,...options});
  assert.deepEqual(merged.ruleOverrides.a.strongOverride,{answerSeconds:45,...options});
  assert.equal(incoming.strong.mixedRounds,undefined);
  const explicit = mergeFeaturePayload('settingGroup',{strong:{sequenceNumberCount:4,arithmeticDifficulty:'simple',arithmeticAnswerMode:'input'},ruleOverrides:{a:{strength:'normal'}}},previous);
  assert.equal(explicit.strong.sequenceNumberCount,4);
  assert.equal(explicit.strong.arithmeticDifficulty,'simple');
  assert.equal(explicit.strong.arithmeticAnswerMode,'input');
  assert.deepEqual(explicit.ruleOverrides.a,{strength:'normal'});
});
