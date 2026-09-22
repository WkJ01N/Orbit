'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { visibleEntity } = require('./sync-visibility');

test('older clients do not receive deadline entities', () => {
  assert.equal(visibleEntity({ type: 'deadline' }, {}), false);
  assert.equal(visibleEntity({ type: 'deadline' }, { supportsDeadline: false }), false);
  assert.equal(visibleEntity({ type: 'courseSession' }, {}), true);
  assert.equal(visibleEntity({ type: 'deadline' }, { supportsDeadline: true }), true);
});
