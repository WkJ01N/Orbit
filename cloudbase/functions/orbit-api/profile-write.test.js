'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { writableProfile, commitAvatar } = require('./profile-write');

test('profile writes never include database _id', () => {
  const result = writableProfile({
    _id: 'internal', userId: 'wrong', email: 'user@example.com',
    username: 'old', avatarFileId: 'old.png', createdAt: 123,
  }, { username: 'new', avatarFileId: 'new.png', _id: 'forged' }, 'uid');
  assert.deepEqual(result, {
    userId: 'uid', email: 'user@example.com', username: 'new',
    avatarFileId: 'new.png', createdAt: 123,
  });
});

test('failed avatar persistence removes only new file and preserves original', async () => {
  const removed = [];
  await assert.rejects(commitAvatar({
    fileId: 'new.png', oldFileId: 'old.png',
    persist: async () => { throw new Error('database failed'); },
    remove: async (id) => removed.push(id),
  }), /database failed/);
  assert.deepEqual(removed, ['new.png']);
});

test('successful avatar persistence removes old file after saving', async () => {
  const operations = [];
  const updated = await commitAvatar({
    fileId: 'new.png', oldFileId: 'old.png',
    persist: async () => { operations.push('save'); return { avatarFileId: 'new.png' }; },
    remove: async (id) => operations.push(`remove ${id}`),
  });
  assert.deepEqual(operations, ['save', 'remove old.png']);
  assert.equal(updated.avatarFileId, 'new.png');
});
