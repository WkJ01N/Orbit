'use strict';
const categories = ['courses','deadlines','templates','semesters','periods','appearance','colors','display','reminders','strong','archive'];
function normalize(input = {}) {
  if (input.mode !== undefined && !['perDevice','shared'].includes(input.mode)) throw Object.assign(new Error('Invalid scope mode'), {code:'INVALID_ARGUMENT'});
  const selection = Object.fromEntries(categories.map((c,i) => [c, input.selection ? input.selection[c] === true : i < 5]));
  return { mode: input.mode || 'perDevice', selection, revision: Number(input.revision) || 0 };
}
function effectiveInput(input, policy) {
  const effective = { ...input };
  if (policy.mode === 'shared') effective.selection = policy.selection;
  // Complete snapshots may be previewed without uploading or receiving changes.
  if (input.snapshot && input.previewAll && input.supportsSettings) delete effective.selection;
  return effective;
}
module.exports = { normalize, effectiveInput };
