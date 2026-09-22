'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  createCollectionBootstrap,
  isExistingCollection,
  isMissingCollection,
} = require('./collection-bootstrap');

function missingCollection() {
  const error = new Error('[ResourceNotFound] Db or Table not exist');
  error.code = 'DATABASE_COLLECTION_NOT_EXIST';
  return error;
}

test('recognizes CloudBase collection errors', () => {
  assert.equal(isMissingCollection(missingCollection()), true);
  assert.equal(isExistingCollection({ code: 'DATABASE_COLLECTION_EXIST' }), true);
  assert.equal(isMissingCollection(new Error('network failed')), false);
});

test('creates only missing collections and caches successful setup', async () => {
  const existing = new Set(['sessions']);
  const probes = [];
  const creates = [];
  const database = {
    collection(name) {
      return {
        limit() { return this; },
        async get() {
          probes.push(name);
          if (!existing.has(name)) throw missingCollection();
          return { data: [] };
        },
      };
    },
    async createCollection(name) {
      creates.push(name);
      existing.add(name);
    },
  };

  const ensureCollections = createCollectionBootstrap(database, ['sessions', 'profiles']);
  await Promise.all([ensureCollections(), ensureCollections()]);
  await ensureCollections();

  assert.deepEqual(probes.sort(), ['profiles', 'sessions']);
  assert.deepEqual(creates, ['profiles']);
});

test('accepts a concurrent already-exists result', async () => {
  const database = {
    collection() {
      return { limit() { return this; }, async get() { throw missingCollection(); } };
    },
    async createCollection() {
      const error = new Error('namespace already exists');
      error.code = 'DATABASE_COLLECTION_EXIST';
      throw error;
    },
  };
  await createCollectionBootstrap(database, ['profiles'])();
});

test('retries setup after a transient failure', async () => {
  let attempts = 0;
  const database = {
    collection() {
      return {
        limit() { return this; },
        async get() {
          attempts += 1;
          if (attempts === 1) throw new Error('network failed');
          return { data: [] };
        },
      };
    },
    async createCollection() { throw new Error('unexpected create'); },
  };
  const ensureCollections = createCollectionBootstrap(database, ['profiles']);
  await assert.rejects(ensureCollections(), /network failed/);
  await ensureCollections();
  assert.equal(attempts, 2);
});
