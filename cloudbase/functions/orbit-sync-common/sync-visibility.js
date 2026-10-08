'use strict';

function visibleEntity(entity, event) {
  if (entity?.type === 'deadline' && event.supportsDeadline !== true) return false;
  if (entity?.type === 'settingGroup' && event.supportsSettings !== true) return false;
  const category = { courseSession: 'courses', deadline: 'deadlines', importTemplate: 'templates',
    semesterPlan: 'semesters', periodTimePlan: 'periods' }[entity?.type] || (entity?.type === 'settingGroup' ? entity.id : null);
  if (!category) return false;
  return !event.selection || event.selection[category] === true;
}

function mergeFeaturePayload(type, incoming = {}, previous = {}) {
  if (type !== 'courseSession' && type !== 'deadline') return incoming;
  const next = { ...incoming };
  for (const key of ['archivedAt', 'archiveHidden', 'autoArchivePaused', 'linkedCourseKey', 'startPeriod', 'periodTimePlanId']) {
    if (!Object.prototype.hasOwnProperty.call(incoming, key) && Object.prototype.hasOwnProperty.call(previous, key)) {
      next[key] = previous[key];
    }
  }
  return next;
}

module.exports = { visibleEntity, mergeFeaturePayload };
