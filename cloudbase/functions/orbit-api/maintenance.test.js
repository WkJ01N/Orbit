'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');

function loadSyncCommon() {
  const originalLoad = Module._load;
  const fakeDb = {
    command: { gt: (v) => ({ gt: v }), lt: (v) => ({ lt: v }) },
    serverDate: () => 'now',
    collection: () => ({}),
    runTransaction: async () => ({}),
  };
  Module._load = function (request, ...rest) {
    if (request === '@cloudbase/node-sdk') {
      return {
        SYMBOL_CURRENT_ENV: 'env',
        init: () => ({ database: () => fakeDb }),
        getCloudbaseContext: () => ({}),
      };
    }
    return originalLoad.call(this, request, ...rest);
  };
  try {
    delete require.cache[require.resolve('./sync-common')];
    return require('./sync-common');
  } finally {
    Module._load = originalLoad;
  }
}

test('pruneExpiredMutations removes only old receipts for one user', async () => {
  const sync = loadSyncCommon();
  const removed = [];
  const queries = [];
  const database = {
    command: { lt: (value) => ({ lt: value }) },
    collection: () => ({
      where(query) {
        queries.push(query);
        return {
          limit: (n) => ({
            get: async () => ({
              data: [{ _id: 'old-1' }, { _id: 'old-2' }].slice(0, n),
            }),
          }),
        };
      },
      doc: (id) => ({ remove: async () => removed.push(id) }),
    }),
  };

  const count = await sync.pruneExpiredMutations('user-1', {
    now: 10_000_000,
    maxAgeMs: 1_000,
    limit: 20,
    database,
  });

  assert.equal(count, 2);
  assert.deepEqual(removed, ['old-1', 'old-2']);
  assert.equal(queries[0].userId, 'user-1');
  assert.deepEqual(queries[0].createdAtMs, { lt: 10_000_000 - 1_000 });
  assert.equal(sync.MUTATION_RECEIPT_TTL_MS, 14 * 24 * 60 * 60 * 1000);
});

test('pruneExpiredMutations respects the per-call limit', async () => {
  const sync = loadSyncCommon();
  const database = {
    command: { lt: (value) => ({ lt: value }) },
    collection: () => ({
      where: () => ({
        limit: (n) => ({
          get: async () => ({ data: [{ _id: 'a' }, { _id: 'b' }].slice(0, n) }),
        }),
      }),
      doc: () => ({ remove: async () => {} }),
    }),
  };
  assert.equal(await sync.pruneExpiredMutations('u', { limit: 1, database }), 1);
});

test('a missing GitHub release is reported as NOT_FOUND, not as an outage', async () => {
  const { release } = require('./updates');
  await assert.rejects(
    release('v9.9.9', async () => {
      const error = new Error('GitHub metadata unavailable');
      error.code = 'NOT_FOUND';
      throw error;
    }),
    { code: 'NOT_FOUND' },
  );
});
