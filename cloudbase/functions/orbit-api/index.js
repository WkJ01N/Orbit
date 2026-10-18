'use strict';

const crypto = require('crypto');
const zlib = require('zlib');
const cloudbase = require('@cloudbase/node-sdk');
const sessions = require('./session-core');
const sync = require('./sync-common');
const validation = require('./http-validation');
const syncPolicy = require('./sync-policy');
const updates = require('./updates');
const { createCollectionBootstrap } = require('./collection-bootstrap');
const { writableProfile, commitAvatar } = require('./profile-write');

const app = cloudbase.init({ env: cloudbase.SYMBOL_CURRENT_ENV });
const db = app.database();
const collections = {
  sessions: 'orbit_auth_sessions',
  profiles: 'orbit_user_profiles',
  policy: 'orbit_sync_policy',
  updates: 'orbit_update_cache',
};
const ensureCollections = createCollectionBootstrap(db, Object.values(collections));
const MAX_HTTP_BODY = 5 * 1024 * 1024;
const MAX_AVATAR_BODY = 2 * 1024 * 1024;

function currentUid() {
  const context = cloudbase.getCloudbaseContext();
  const uid = context.TCB_UUID || context.UID || context.OPENID;
  if (!uid) throw sessions.codedError('UNAUTHENTICATED', 'Authentication required');
  return uid;
}

function documentId(value) {
  return sessions.sha256(value);
}

function documentData(response) {
  const data = response && response.data;
  return Array.isArray(data) ? data[0] : data || null;
}

async function registryFor(uid) {
  return documentData(
    await db.collection(collections.sessions).doc(documentId(uid)).get(),
  );
}

async function updateRegistry(uid, updater) {
  const result = await db.runTransaction(async (transaction) => {
    const reference = transaction.collection(collections.sessions).doc(documentId(uid));
    const current = documentData(await reference.get());
    const updated = updater(current);
    await reference.set({
      ...updated.registry,
      updatedAt: db.serverDate(),
    });
    return updated;
  });
  return result?.result ?? result;
}

function normalizeProfile(uid, userInfo) {
  const source = userInfo || {};
  const username = source.nickName || source.nickname || source.userName || source.username || '';
  const avatarFileId = source.avatarUrl || source.avatarURL || source.picture || null;
  return {
    userId: uid,
    email: source.email || source.Email || '',
    username: String(username || '').trim(),
    avatarFileId: avatarFileId ? String(avatarFileId) : null,
  };
}

function publicProfile(profile) {
  return {
    uid: profile.userId,
    email: profile.email || '',
    username: profile.username || null,
    avatarFileId: profile.avatarFileId || null,
  };
}

async function profileFor(uid) {
  return documentData(
    await db.collection(collections.profiles).doc(documentId(uid)).get(),
  );
}

async function ensureProfile(uid) {
  const existing = await profileFor(uid);
  if (existing) return existing;
  const response = await app.auth().getEndUserInfo(uid);
  const profile = normalizeProfile(uid, response?.userInfo);
  await db.collection(collections.profiles).doc(documentId(uid)).set({
    ...profile,
    createdAt: db.serverDate(),
    updatedAt: db.serverDate(),
  });
  return profile;
}

async function callable(event) {
  const uid = currentUid();
  if (event.action === 'bootstrapSession') {
    const profile = await ensureProfile(uid);
    const issued = await updateRegistry(uid, (registry) =>
      sessions.issueSession(registry, {
        uid,
        deviceId: event.deviceId,
        platform: event.platform,
        appVersion: event.appVersion,
      }));
    return {
      result: {
        account: publicProfile(profile),
        session: issued.session,
      },
    };
  }
  if (event.action === 'revokeAllSessions') {
    await updateRegistry(uid, () => ({ registry: { userId: uid, sessions: [] } }));
    return { result: { revoked: true } };
  }
  throw sessions.codedError('INVALID_ARGUMENT', 'Unknown callable action');
}

function lowerHeaders(headers) {
  return Object.fromEntries(
    Object.entries(headers || {}).map(([key, value]) => [key.toLowerCase(), value]),
  );
}

function bodyBuffer(event) {
  const raw = event.body || '';
  const bytes = event.isBase64Encoded
    ? Buffer.from(raw, 'base64')
    : Buffer.from(raw, 'utf8');
  if (bytes.length > MAX_HTTP_BODY) {
    throw sessions.codedError('PAYLOAD_TOO_LARGE', 'Request exceeds 5 MiB');
  }
  return bytes;
}

function jsonBody(event) {
  const headers = lowerHeaders(event.headers);
  let bytes = bodyBuffer(event);
  if (String(headers['content-encoding'] || '').toLowerCase() === 'gzip') {
    bytes = zlib.gunzipSync(bytes, { maxOutputLength: MAX_HTTP_BODY });
  }
  if (!bytes.length) return {};
  return JSON.parse(bytes.toString('utf8'));
}

function syncBody(event) {
  return validation.validateSyncPayload(jsonBody(event));
}

function bearer(event) {
  const authorization = String(lowerHeaders(event.headers).authorization || '');
  const match = /^Bearer\s+(.+)$/i.exec(authorization);
  if (!match) throw sessions.codedError('UNAUTHENTICATED', 'Bearer token required');
  return match[1];
}

async function authenticate(event) {
  const accessToken = bearer(event);
  const parsed = sessions.parseToken(accessToken, 'a');
  const registry = await registryFor(parsed.uid);
  return sessions.authenticateAccess(registry, accessToken);
}

function routePath(event) {
  const path = String(event.path || '/');
  const marker = path.indexOf('/v1/');
  return marker >= 0 ? path.slice(marker) : path;
}

function jsonResponse(statusCode, value, { gzip = false } = {}) {
  const json = Buffer.from(JSON.stringify(value), 'utf8');
  if (!gzip) {
    return {
      statusCode,
      headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
      body: json.toString('utf8'),
    };
  }
  const compressed = zlib.gzipSync(json);
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Encoding': 'gzip',
      'Cache-Control': 'no-store',
    },
    body: compressed.toString('base64'),
    isBase64Encoded: true,
  };
}

async function refresh(event) {
  const payload = jsonBody(event);
  const parsed = sessions.parseToken(payload.refreshToken, 'r');
  const refreshed = await updateRegistry(parsed.uid, (registry) =>
    sessions.refreshSession(registry, payload.refreshToken));
  return jsonResponse(200, { session: refreshed.session });
}

async function revoke(event) {
  let tokenValue;
  try {
    tokenValue = bearer(event);
  } catch (_) {
    tokenValue = jsonBody(event).refreshToken;
  }
  const parsed = (() => {
    try { return sessions.parseToken(tokenValue, 'a'); } catch (_) {
      return sessions.parseToken(tokenValue, 'r');
    }
  })();
  await updateRegistry(parsed.uid, (registry) => sessions.revokeSession(registry, tokenValue));
  return jsonResponse(200, { revoked: true });
}

function validateUsername(value) {
  const username = String(value || '').trim();
  if ([...username].length > 24 || /[\r\n\t]/.test(username)) {
    throw sessions.codedError('INVALID_USERNAME', 'Invalid username');
  }
  return username;
}

async function saveProfile(uid, changes) {
  const current = await ensureProfile(uid);
  const updated = writableProfile(current, changes, uid);
  await db.collection(collections.profiles).doc(documentId(uid)).set({
    ...updated,
    createdAt: updated.createdAt || db.serverDate(),
    updatedAt: db.serverDate(),
  });
  return updated;
}

async function uploadAvatar(event, uid) {
  const bytes = bodyBuffer(event);
  if (!bytes.length || bytes.length > MAX_AVATAR_BODY) {
    throw sessions.codedError('AVATAR_TOO_LARGE', 'Avatar exceeds 2 MiB');
  }
  validation.validatePng(bytes);
  const username = validateUsername(event.queryStringParameters?.username || '');
  const current = await ensureProfile(uid);
  const cloudPath = `orbit-user-avatars/${uid}/avatar-${Date.now()}-${crypto.randomBytes(6).toString('hex')}.png`;
  const uploaded = await app.uploadFile({ cloudPath, fileContent: bytes });
  if (!uploaded?.fileID) throw sessions.codedError('AVATAR_UPLOAD_FAILED', 'Upload failed');
  const updated = await commitAvatar({
    fileId: uploaded.fileID,
    oldFileId: current.avatarFileId,
    persist: () => saveProfile(uid, { username, avatarFileId: uploaded.fileID }),
    remove: (fileId) => app.deleteFile({ fileList: [fileId] }),
  });
  return publicProfile(updated);
}

async function avatarUrl(uid, fileId) {
  const profile = await ensureProfile(uid);
  if (!fileId || profile.avatarFileId !== fileId) {
    throw sessions.codedError('NOT_FOUND', 'Avatar version not found');
  }
  const response = await app.getTempFileURL({
    fileList: [{ fileID: fileId, maxAge: 600 }],
  });
  const item = response?.fileList?.[0];
  if (!item?.tempFileURL) throw sessions.codedError('NOT_FOUND', 'Avatar not found');
  return item.tempFileURL;
}

async function deleteAccountData(uid) {
  const profile = await profileFor(uid);
  await sync.deleteData(uid);
  if (profile?.avatarFileId) {
    try { await app.deleteFile({ fileList: [profile.avatarFileId] }); } catch (_) { /* best effort */ }
  }
  await db.collection(collections.profiles).doc(documentId(uid)).remove();
  await db.collection(collections.sessions).doc(documentId(uid)).remove();
  await db.collection(collections.policy).doc(documentId(uid)).remove();
}

async function http(event) {
  const method = String(event.httpMethod || '').toUpperCase();
  const path = routePath(event);
  if (method === 'POST' && path === '/v1/session/refresh') return refresh(event);
  if (method === 'DELETE' && path === '/v1/session') return revoke(event);

  if (method === 'GET' && path === '/v1/updates/latest') {
    const ref = db.collection(collections.updates).doc('latest');
    const cached = documentData(await ref.get());
    if (cached && Date.now() - cached.cachedAt < 15 * 60 * 1000) return jsonResponse(200, cached.release);
    const release = await updates.latest();
    await ref.set({ cachedAt: Date.now(), release });
    return jsonResponse(200, release);
  }
  if (method === 'GET' && path === '/v1/updates/releases') {
    const page = Number(event.queryStringParameters?.page || 1);
    if (!Number.isInteger(page) || page < 1 || page > 1000) return jsonResponse(400, { error: 'Invalid page' });
    const ref = db.collection(collections.updates).doc(`history_${page}`);
    const cached = documentData(await ref.get());
    if (cached && Date.now() - cached.cachedAt < 15 * 60 * 1000) return jsonResponse(200, cached.release);
    const release = await updates.history(page);
    await ref.set({ cachedAt: Date.now(), release });
    return jsonResponse(200, release);
  }
  const releaseMatch = /^\/v1\/updates\/releases\/(v\d+\.\d+\.\d+)$/.exec(path);
  if (method === 'GET' && releaseMatch) {
    const ref = db.collection(collections.updates).doc(`tag_${releaseMatch[1].replaceAll('.', '_')}`);
    const cached = documentData(await ref.get());
    if (cached && Date.now() - cached.cachedAt < 15 * 60 * 1000) return jsonResponse(200, cached.release);
    const release = await updates.release(releaseMatch[1]);
    await ref.set({ cachedAt: Date.now(), release });
    return jsonResponse(200, release);
  }
  const identity = await authenticate(event);
  if (method === 'GET' && path === '/v1/profile') {
    return jsonResponse(200, { account: publicProfile(await ensureProfile(identity.uid)) });
  }
  if (method === 'PATCH' && path === '/v1/profile') {
    const profile = await saveProfile(identity.uid, {
      username: validateUsername(jsonBody(event).username),
    });
    return jsonResponse(200, { account: publicProfile(profile) });
  }
  if (method === 'PUT' && path === '/v1/profile/avatar') {
    return jsonResponse(200, { account: await uploadAvatar(event, identity.uid) });
  }
  if (method === 'GET' && path === '/v1/profile/avatar-url') {
    const url = await avatarUrl(identity.uid, event.queryStringParameters?.fileId);
    return jsonResponse(200, { url });
  }
  const policyRef = db.collection(collections.policy).doc(documentId(identity.uid));
  const policy = syncPolicy.normalize(documentData(await policyRef.get()) || {});
  if (path === '/v1/sync/policy' && method === 'GET') return jsonResponse(200, {...policy, supportsExams: true});
  if (path === '/v1/sync/policy' && method === 'PUT') {
    const requested = syncPolicy.normalize(jsonBody(event));
    const saved = await db.runTransaction(async (transaction) => {
      const ref = transaction.collection(collections.policy).doc(documentId(identity.uid));
      const current = syncPolicy.normalize(documentData(await ref.get()) || {});
      if (requested.revision !== current.revision) throw sessions.codedError('SYNC_POLICY_CONFLICT', 'Reload scope before saving');
      const next = { ...requested, revision: current.revision + 1 };
      await ref.set(next); return next;
    });
    return jsonResponse(200, saved?.result ?? saved);
  }
  if (method === 'POST' && path === '/v1/sync/push') {
    return jsonResponse(200, await sync.push(identity.uid, syncPolicy.effectiveInput(syncBody(event), policy)), { gzip: true });
  }
  if (method === 'POST' && path === '/v1/sync/pull') {
    return jsonResponse(200, await sync.pull(identity.uid, syncPolicy.effectiveInput(jsonBody(event), policy)), { gzip: true });
  }
  if (method === 'POST' && path === '/v1/sync/exchange') {
    const input = syncPolicy.effectiveInput(syncBody(event), policy);
    const pushed = await sync.push(identity.uid, input);
    const pulled = await sync.pull(identity.uid, {
      cursor: input.cursor,
      limit: input.pullLimit || 200,
      supportsDeadline: input.supportsDeadline === true,
      supportsSettings: input.supportsSettings === true,
      supportsStatistics: input.supportsStatistics === true,
      supportsExams: input.supportsExams === true,
      selection: input.selection,
    });
    return jsonResponse(200, { ...pushed, pull: pulled }, { gzip: true });
  }
  if (method === 'POST' && path === '/v1/sync/snapshot') {
    const input = syncPolicy.effectiveInput({ ...jsonBody(event), snapshot: true }, policy);
    return jsonResponse(200, await sync.pull(identity.uid, {
      snapshot: true,
      offset: input.offset,
      limit: Math.min(Number(input.limit) || 500, 500),
      supportsDeadline: input.supportsDeadline === true,
      supportsSettings: input.supportsSettings === true,
      supportsStatistics: input.supportsStatistics === true,
      supportsExams: input.supportsExams === true,
      selection: input.selection,
    }), { gzip: true });
  }
  if (method === 'DELETE' && path === '/v1/account') {
    await deleteAccountData(identity.uid);
    return jsonResponse(200, { deleted: true });
  }
  return jsonResponse(404, { code: 'NOT_FOUND', message: 'Route not found' });
}

function statusFor(code) {
  if (code === 'UNAUTHENTICATED' || code === 'SESSION_INVALID' || code === 'ACCESS_EXPIRED') return 401;
  if (code === 'NOT_FOUND') return 404;
  if (code === 'PAYLOAD_TOO_LARGE' || code === 'AVATAR_TOO_LARGE') return 413;
  if (code?.startsWith('INVALID_') || code === 'AVATAR_TYPE_INVALID') return 400;
  return 500;
}

exports.main = async (event) => {
  try {
    await ensureCollections();
    if (event?.httpMethod) return await http(event);
    return await callable(event || {});
  } catch (error) {
    if (event?.httpMethod) {
      const code = error.code || 'INTERNAL';
      return jsonResponse(statusFor(code), {
        code,
        message: error.code ? error.message : 'Request failed',
      });
    }
    return {
      code: error.code || 'INTERNAL',
      message: error.code ? error.message : 'Request failed',
    };
  }
};
