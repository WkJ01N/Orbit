'use strict';

const crypto = require('crypto');
const cloudbase = require('@cloudbase/node-sdk');
const { visibleEntity, mergeFeaturePayload } = require('./sync-visibility');

const app = cloudbase.init({ env: cloudbase.SYMBOL_CURRENT_ENV });
const db = app.database();
const command = db.command;

const collections = {
  records: 'orbit_sync_records',
  changes: 'orbit_sync_changes',
  state: 'orbit_sync_state',
  mutations: 'orbit_sync_mutations',
};

function currentUid() {
  const context = cloudbase.getCloudbaseContext();
  const uid = context.TCB_UUID || context.UID || context.OPENID;
  if (!uid) throw codedError('UNAUTHENTICATED', 'Authentication required');
  return uid;
}

function codedError(code, message) {
  const error = new Error(message);
  error.code = code;
  return error;
}

function documentId(...parts) {
  return crypto.createHash('sha256').update(parts.join('|')).digest('hex');
}

function documentData(response) {
  const data = response && response.data;
  return Array.isArray(data) ? data[0] : data || null;
}

function validateEntity(entity) {
  const types = new Set([
    'courseSession',
    'importTemplate',
    'semesterPlan',
    'periodTimePlan',
    'deadline',
    'settingGroup',
    'statistic',
  ]);
  if (!entity || !types.has(entity.type) || typeof entity.id !== 'string') {
    throw codedError('INVALID_ARGUMENT', 'Invalid sync entity');
  }
  if (entity.id.length < 1 || entity.id.length > 512) {
    throw codedError('INVALID_ARGUMENT', 'Invalid entity id');
  }
  if (entity.type === 'settingGroup' && !['appearance','colors','display','reminders','strong','archive'].includes(entity.id)) {
    throw codedError('INVALID_ARGUMENT', 'Unknown settings group');
  }
  if (entity.type === 'courseSession' && entity.payload?.kind === 'exam' && (!entity.id.startsWith('exam|') || !Number.isInteger(entity.payload.examLeadMinutes) || entity.payload.examLeadMinutes < 0 || entity.payload.examLeadMinutes > 10080 || typeof entity.payload.examReminderEnabled !== 'boolean' || typeof entity.payload.examStrongReminder !== 'boolean')) throw codedError('INVALID_ARGUMENT', 'Invalid exam');
  if (entity.type === 'statistic') {
    const p = entity.payload;
    if (!p || !['day','course','exam','ddl','profile'].includes(p.kind) || typeof p.updatedAt !== 'string' || !Number.isFinite(Date.parse(p.updatedAt))) throw codedError('INVALID_ARGUMENT', 'Invalid statistic');
    if (p.kind === 'day' && (entity.id !== `day|${p.date}` || !/^\d{4}-\d{2}-\d{2}$/.test(p.date))) throw codedError('INVALID_ARGUMENT', 'Invalid activity date');
    if (p.kind === 'course' && (!entity.id.startsWith('course|') || typeof p.courseKey !== 'string' || typeof p.name !== 'string' || typeof p.semester !== 'string' || !Number.isInteger(p.minutes) || p.minutes < 0 || typeof p.counted !== 'boolean')) throw codedError('INVALID_ARGUMENT', 'Invalid course statistic');
    if (p.kind === 'exam' && (!entity.id.startsWith('exam|') || typeof p.name !== 'string' || typeof p.counted !== 'boolean' || !Number.isFinite(Date.parse(p.endAt)))) throw codedError('INVALID_ARGUMENT', 'Invalid exam statistic');
    if (p.kind === 'ddl' && !entity.id.startsWith('ddl|')) throw codedError('INVALID_ARGUMENT', 'Invalid DDL statistic');
    if (p.kind === 'profile' && (entity.id !== 'profile' || typeof p.firstUsedDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(p.firstUsedDate))) throw codedError('INVALID_ARGUMENT', 'Invalid first-use date');
    if (p.firstUsedDateAutomatic !== undefined && typeof p.firstUsedDateAutomatic !== 'boolean') throw codedError('INVALID_ARGUMENT', 'Invalid first-use mode');
    if (p.excluded !== undefined && typeof p.excluded !== 'boolean') throw codedError('INVALID_ARGUMENT', 'Invalid exclusion');
  }
  const payload = JSON.stringify(entity.payload || {});
  if (Buffer.byteLength(payload, 'utf8') > 256 * 1024) {
    throw codedError('PAYLOAD_TOO_LARGE', 'Entity exceeds 256 KiB');
  }
}

function recordToEntity(record) {
  return {
    type: record.entityType,
    id: record.entityId,
    schemaVersion: record.schemaVersion,
    revision: record.revision,
    deleted: record.deleted,
    payload: record.payload || {},
  };
}

async function push(uid, event) {
  const mutations = Array.isArray(event.mutations) ? event.mutations : [];
  if (mutations.some((m) => !visibleEntity(m.entity, { ...event, supportsDeadline: true, supportsSettings: true, supportsStatistics: true, supportsExams: true }))) throw codedError('SYNC_CATEGORY_DISABLED', 'Category disabled');
  if (mutations.length > 100) {
    throw codedError('BATCH_TOO_LARGE', 'At most 100 mutations per request');
  }
  for (const mutation of mutations) {
    validateEntity(mutation.entity);
    if (
      typeof mutation.mutationId !== 'string' ||
      mutation.mutationId.length < 1 ||
      mutation.mutationId.length > 128
    ) {
      throw codedError('INVALID_ARGUMENT', 'Invalid mutation id');
    }
  }
  const accepted = [];
  const conflicts = [];
  let finalCursor = Number(event.cursor) || 0;
  // Keep each transaction comfortably below CloudBase operation limits while
  // avoiding one transaction and several database round-trips per lesson.
  // A new mutation uses up to five document operations. Fifteen mutations,
  // plus the state read/write, stay below CloudBase's 100-operation limit.
  const transactionBatchSize = 15;
  for (let offset = 0; offset < mutations.length; offset += transactionBatchSize) {
    const batch = mutations.slice(offset, offset + transactionBatchSize);
    const transactionResult = await db.runTransaction(async (transaction) => {
      const stateId = documentId(uid);
      const stateResult = await transaction
        .collection(collections.state)
        .doc(stateId)
        .get();
      const initialCursor = Number(documentData(stateResult)?.cursor || 0);
      let cursor = initialCursor;
      const results = [];
      for (const mutation of batch) {
        const receiptId = documentId(uid, mutation.mutationId);
        const receiptResult = await transaction
          .collection(collections.mutations)
          .doc(receiptId)
          .get();
        const receipt = documentData(receiptResult);
        if (receipt) {
          results.push(receipt.result);
          continue;
        }

        const entity = mutation.entity;
        const recordId = documentId(uid, entity.type, entity.id);
        const recordResult = await transaction
          .collection(collections.records)
          .doc(recordId)
          .get();
        const current = documentData(recordResult);
        const currentRevision = current ? Number(current.revision) : 0;
        if (entity.type !== 'statistic' && currentRevision !== Number(mutation.baseRevision || 0)) {
          const conflict = {
            kind: 'conflict',
            mutationId: mutation.mutationId,
            conflictId: documentId(uid, entity.type, entity.id, currentRevision),
            remote: current
              ? recordToEntity(current)
              : {
                  type: entity.type,
                  id: entity.id,
                  schemaVersion: entity.schemaVersion || 1,
                  revision: 0,
                  deleted: true,
                  payload: {},
                },
          };
          await transaction.collection(collections.mutations).doc(receiptId).set({
            userId: uid,
            result: conflict,
            createdAt: db.serverDate(),
          });
          results.push(conflict);
          continue;
        }

        cursor += 1;
        const revision = currentRevision + 1;
        const record = {
          userId: uid,
          entityType: entity.type,
          entityId: entity.id,
          schemaVersion: Number(entity.schemaVersion || 1),
          revision,
          deleted: mutation.operation === 'delete',
          payload: mutation.operation === 'delete' ? {} : mergeFeaturePayload(entity.type, entity.payload || {}, current?.payload || {}),
          updatedAt: db.serverDate(),
        };
        await transaction.collection(collections.records).doc(recordId).set(record);
        await transaction
          .collection(collections.changes)
          .doc(documentId(uid, cursor))
          .set({
            userId: uid,
            cursor,
            entity: recordToEntity(record),
            createdAt: db.serverDate(),
          });
        const response = {
          kind: 'accepted',
          mutationId: mutation.mutationId,
          revision,
          cursor,
        };
        await transaction.collection(collections.mutations).doc(receiptId).set({
          userId: uid,
          result: response,
          createdAt: db.serverDate(),
        });
        results.push(response);
      }
      if (cursor !== initialCursor) {
        await transaction.collection(collections.state).doc(stateId).set({
          userId: uid,
          cursor,
          updatedAt: db.serverDate(),
        });
      }
      return results;
    });
    const results = transactionResult?.result ?? transactionResult;
    for (const result of results) {
      if (result.kind === 'conflict') conflicts.push(result);
      else {
        accepted.push({
          mutationId: result.mutationId,
          revision: result.revision,
        });
        finalCursor = Math.max(finalCursor, result.cursor);
      }
    }
  }
  return { accepted, conflicts, cursor: finalCursor };
}

async function pull(uid, event) {
  const limit = Math.min(Math.max(Number(event.limit) || 200, 1), 10000);
  if (event.snapshot === true) {
    const offset = Math.max(Number(event.offset) || 0, 0);
    const records = [];
    while (records.length < limit) {
      const pageSize = Math.min(100, limit - records.length);
      const result = await db
        .collection(collections.records)
        .where({ userId: uid })
        .skip(offset + records.length)
        .limit(pageSize)
        .get();
      const page = result.data || [];
      records.push(...page);
      if (page.length < pageSize) break;
    }
    const state = await db
      .collection(collections.state)
      .doc(documentId(uid))
      .get();
    return {
      entities: records.map(recordToEntity).filter((entity) => visibleEntity(entity, event)),
      cursor: Number(documentData(state)?.cursor || 0),
      hasMore: records.length === limit,
      nextOffset: offset + records.length,
    };
  }
  const cursor = Number(event.cursor) || 0;
  const result = await db
    .collection(collections.changes)
    .where({ userId: uid, cursor: command.gt(cursor) })
    .orderBy('cursor', 'asc')
    .limit(limit)
    .get();
  const rows = result.data || [];
  return {
    entities: rows.map((row) => row.entity).filter((entity) => visibleEntity(entity, event)),
    cursor: rows.length ? Number(rows[rows.length - 1].cursor) : cursor,
    hasMore: rows.length === limit,
  };
}

async function removeWhere(collection, uid) {
  while (true) {
    const result = await db
      .collection(collection)
      .where({ userId: uid })
      .limit(100)
      .get();
    const rows = result.data || [];
    if (!rows.length) return;
    await Promise.all(
      rows.map((row) => db.collection(collection).doc(row._id).remove()),
    );
  }
}

async function deleteData(uid) {
  await removeWhere(collections.changes, uid);
  await removeWhere(collections.mutations, uid);
  await removeWhere(collections.records, uid);
  await removeWhere(collections.state, uid);
  return { deleted: true };
}

function success(result) {
  return { result };
}

function failure(error) {
  return {
    code: error.code || 'INTERNAL',
    message: error.code ? error.message : 'Sync operation failed',
  };
}

module.exports = {
  currentUid,
  push,
  pull,
  deleteData,
  success,
  failure,
};
