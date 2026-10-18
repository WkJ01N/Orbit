'use strict';

function visibleEntity(entity, event) {
  if (event.supportsExams !== true && ((entity?.type === 'courseSession' && (entity.payload?.kind === 'exam' || entity.id?.startsWith('exam|'))) || (entity?.type === 'statistic' && (entity.payload?.kind === 'exam' || entity.id?.startsWith('exam|'))))) return false;
  if (entity?.type === 'statistic' && event.supportsStatistics !== true) return false;
  if (entity?.type === 'deadline' && event.supportsDeadline !== true) return false;
  if (entity?.type === 'settingGroup' && event.supportsSettings !== true) return false;
  const category = { statistic: 'statistics', courseSession: 'courses', deadline: 'deadlines', importTemplate: 'templates',
    semesterPlan: 'semesters', periodTimePlan: 'periods' }[entity?.type] || (entity?.type === 'settingGroup' ? entity.id : null);
  if (!category) return false;
  return !event.selection || event.selection[category] === true;
}

function mergeFeaturePayload(type, incoming = {}, previous = {}) {
  if (type === 'statistic') {
    if (!previous.kind) return incoming;
    const incomingTime = Date.parse(incoming.updatedAt || '') || 0;
    const previousTime = Date.parse(previous.updatedAt || '') || 0;
    const next = {...(incomingTime > previousTime || (incomingTime === previousTime && JSON.stringify(incoming) > JSON.stringify(previous)) ? incoming : previous)};
    if (next.kind === 'course' || next.kind === 'exam') next.counted = previous.counted === true || incoming.counted === true;
    if (next.kind === 'profile') {
      const oldAutomatic = previous.firstUsedDateAutomatic === true;
      const incomingAutomatic = incoming.firstUsedDateAutomatic === true;
      if (oldAutomatic !== incomingAutomatic) return oldAutomatic ? incoming : previous;
      if (oldAutomatic) next.firstUsedDate = [previous.firstUsedDate, incoming.firstUsedDate].sort()[0];
    }
    return next;
  }
  if (type === 'settingGroup' && incoming.strong) {
    const preserve = (value, old = {}) => {
      const next = {...value};
      for (const key of ['arithmeticRounds', 'sequenceRounds', 'mixedRounds', 'sequenceNumberCount', 'arithmeticDifficulty', 'arithmeticAnswerMode']) {
        if (!Object.prototype.hasOwnProperty.call(value, key) && Object.prototype.hasOwnProperty.call(old, key)) next[key] = old[key];
      }
      return next;
    };
    const next = {...incoming, strong: preserve(incoming.strong, previous.strong)};
    if (incoming.ruleOverrides) {
      next.ruleOverrides = Object.fromEntries(Object.entries(incoming.ruleOverrides).map(([id, rule]) => [id,
        rule.strongOverride ? {...rule, strongOverride: preserve(rule.strongOverride, previous.ruleOverrides?.[id]?.strongOverride)} : rule]));
    }
    return next;
  }
  if (type === 'settingGroup' && previous.scheduleDisplay && !incoming.scheduleDisplay) return {...incoming, scheduleDisplay: previous.scheduleDisplay};
  if (type === 'settingGroup' && incoming.scheduleDisplay) {
    const display = {...incoming.scheduleDisplay};
    for (const key of ['hideUpcomingPage', 'hideImportPage']) {
      if (!Object.prototype.hasOwnProperty.call(display, key) && Object.prototype.hasOwnProperty.call(previous.scheduleDisplay || {}, key)) {
        display[key] = previous.scheduleDisplay[key];
      }
    }
    return {...incoming, scheduleDisplay: display};
  }
  if (type === 'semesterPlan') {
    const next = {...incoming};
    for (const key of ['rangeStart', 'rangeEnd', 'source']) if (!(key in incoming) && key in previous) next[key] = previous[key];
    return next;
  }
  if (type !== 'courseSession' && type !== 'deadline') return incoming;
  const next = { ...incoming };
  for (const key of ['kind', 'semesterId', 'examReminderEnabled', 'examStrongReminder', 'examLeadMinutes', 'archivedAt', 'archiveHidden', 'autoArchivePaused', 'linkedCourseKey', 'startPeriod', 'periodTimePlanId', 'countsTowardStatistics', 'batchId', 'statisticsSourceId', 'strongReminderEnabled', 'strongLeadMinutes', 'disabledReminderLeadMinutes']) {
    if (!Object.prototype.hasOwnProperty.call(incoming, key) && Object.prototype.hasOwnProperty.call(previous, key)) {
      next[key] = previous[key];
    }
  }
  return next;
}

module.exports = { visibleEntity, mergeFeaturePayload };
