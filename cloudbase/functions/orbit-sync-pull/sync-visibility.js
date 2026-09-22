'use strict';

function visibleEntity(entity, event) {
  return event.supportsDeadline === true || entity?.type !== 'deadline';
}

module.exports = { visibleEntity };
