'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const validation = require('./http-validation');

function png(width, height) {
  const bytes = Buffer.alloc(24);
  Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]).copy(bytes);
  bytes.writeUInt32BE(width, 16);
  bytes.writeUInt32BE(height, 20);
  return bytes;
}

test('avatar accepts PNG up to 512 pixels', () => {
  assert.doesNotThrow(() => validation.validatePng(png(512, 320)));
});

test('avatar rejects a forged type and oversized dimensions', () => {
  assert.throws(() => validation.validatePng(Buffer.alloc(24)), {
    code: 'AVATAR_TYPE_INVALID',
  });
  assert.throws(() => validation.validatePng(png(513, 10)), {
    code: 'AVATAR_DIMENSIONS_INVALID',
  });
});

test('sync batches enforce item and uncompressed byte limits', () => {
  assert.doesNotThrow(() => validation.validateSyncPayload({ mutations: Array(100).fill({ id: 1 }) }));
  assert.throws(
    () => validation.validateSyncPayload({ mutations: Array(101).fill({ id: 1 }) }),
    { code: 'INVALID_ARGUMENT' },
  );
  assert.throws(
    () => validation.validateSyncPayload({ value: 'x'.repeat(validation.MAX_SYNC_BODY) }),
    { code: 'PAYLOAD_TOO_LARGE' },
  );
});

