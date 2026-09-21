'use strict';

const crypto = require('crypto');

const ACCESS_LIFETIME_MS = 60 * 60 * 1000;
const REFRESH_LIFETIME_MS = 30 * 24 * 60 * 60 * 1000;
const REFRESH_RETRY_GRACE_MS = 60 * 1000;
const MAX_SESSIONS = 5;

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function safeEqual(left, right) {
  if (typeof left !== 'string' || typeof right !== 'string') return false;
  const a = Buffer.from(left);
  const b = Buffer.from(right);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function randomSecret() {
  return crypto.randomBytes(32).toString('base64url');
}

function randomId() {
  return crypto.randomBytes(16).toString('base64url');
}

function encodedUid(uid) {
  return Buffer.from(uid, 'utf8').toString('base64url');
}

function token(kind, uid, sessionId, secret = randomSecret()) {
  return `orbit_${kind}1.${encodedUid(uid)}.${sessionId}.${secret}`;
}

function parseToken(value, expectedKind) {
  if (typeof value !== 'string') throw codedError('SESSION_INVALID', 'Invalid token');
  const parts = value.split('.');
  if (parts.length !== 4 || parts[0] !== `orbit_${expectedKind}1`) {
    throw codedError('SESSION_INVALID', 'Invalid token');
  }
  let uid;
  try {
    uid = Buffer.from(parts[1], 'base64url').toString('utf8');
  } catch (_) {
    throw codedError('SESSION_INVALID', 'Invalid token');
  }
  if (!uid || !parts[2] || parts[3].length < 32) {
    throw codedError('SESSION_INVALID', 'Invalid token');
  }
  return { uid, sessionId: parts[2], hash: sha256(value) };
}

function codedError(code, message) {
  const error = new Error(message);
  error.code = code;
  return error;
}

function normalizedRegistry(uid, value) {
  return {
    userId: uid,
    sessions: Array.isArray(value?.sessions) ? value.sessions : [],
  };
}

function issueSession(value, options) {
  const { uid, deviceId, platform = 'unknown', appVersion = '', now = Date.now() } = options;
  if (!uid || typeof deviceId !== 'string' || deviceId.length < 16 || deviceId.length > 256) {
    throw codedError('INVALID_ARGUMENT', 'Invalid device identifier');
  }
  const registry = normalizedRegistry(uid, value);
  const deviceIdHash = sha256(deviceId);
  const previous = registry.sessions.find((entry) => entry.deviceIdHash === deviceIdHash);
  const sessionId = previous?.id || randomId();
  const accessToken = token('a', uid, sessionId);
  const refreshToken = token('r', uid, sessionId);
  const entry = {
    id: sessionId,
    deviceIdHash,
    platform: String(platform).slice(0, 32),
    appVersion: String(appVersion).slice(0, 32),
    accessHash: sha256(accessToken),
    accessExpiresAt: now + ACCESS_LIFETIME_MS,
    refreshHash: sha256(refreshToken),
    previousRefreshHashes: [],
    refreshExpiresAt: now + REFRESH_LIFETIME_MS,
    createdAt: Number(previous?.createdAt || now),
    lastRefreshedAt: now,
  };
  const sessions = registry.sessions
    .filter((candidate) => candidate.deviceIdHash !== deviceIdHash)
    .filter((candidate) => Number(candidate.refreshExpiresAt || 0) > now);
  sessions.push(entry);
  sessions.sort((a, b) => Number(a.createdAt) - Number(b.createdAt));
  while (sessions.length > MAX_SESSIONS) sessions.shift();
  return {
    registry: { userId: uid, sessions },
    session: responseSession(accessToken, refreshToken, entry),
  };
}

function authenticateAccess(value, accessToken, now = Date.now()) {
  const parsed = parseToken(accessToken, 'a');
  const registry = normalizedRegistry(parsed.uid, value);
  const entry = registry.sessions.find((candidate) => candidate.id === parsed.sessionId);
  if (!entry || !safeEqual(entry.accessHash, parsed.hash)) {
    throw codedError('SESSION_INVALID', 'Session is no longer active');
  }
  if (Number(entry.accessExpiresAt || 0) <= now) {
    throw codedError('ACCESS_EXPIRED', 'Access token expired');
  }
  return { uid: parsed.uid, sessionId: parsed.sessionId, entry };
}

function refreshSession(value, refreshToken, now = Date.now()) {
  const parsed = parseToken(refreshToken, 'r');
  const registry = normalizedRegistry(parsed.uid, value);
  const index = registry.sessions.findIndex((candidate) => candidate.id === parsed.sessionId);
  if (index < 0) throw codedError('SESSION_INVALID', 'Session is no longer active');
  const existing = registry.sessions[index];
  if (Number(existing.refreshExpiresAt || 0) <= now) {
    throw codedError('SESSION_INVALID', 'Refresh token expired');
  }
  const legacyPrevious = existing.previousRefreshHash
    ? [{ hash: existing.previousRefreshHash, validUntil: existing.previousRefreshValidUntil }]
    : [];
  const previous = [...(existing.previousRefreshHashes || []), ...legacyPrevious]
    .filter((candidate) => Number(candidate.validUntil || 0) > now);
  const current = safeEqual(existing.refreshHash, parsed.hash);
  const retryEntry = previous.find((candidate) => safeEqual(candidate.hash, parsed.hash));
  const retry = Boolean(retryEntry);
  if (!current && !retry) throw codedError('SESSION_INVALID', 'Refresh token invalid');

  const accessToken = token('a', parsed.uid, parsed.sessionId);
  const nextRefreshToken = token('r', parsed.uid, parsed.sessionId);
  const retryHashes = previous.filter((candidate) => candidate.hash !== parsed.hash);
  retryHashes.push({
    hash: existing.refreshHash,
    validUntil: now + REFRESH_RETRY_GRACE_MS,
  });
  if (retryEntry) retryHashes.push(retryEntry);
  const entry = {
    ...existing,
    accessHash: sha256(accessToken),
    accessExpiresAt: now + ACCESS_LIFETIME_MS,
    refreshHash: sha256(nextRefreshToken),
    previousRefreshHashes: retryHashes
      .sort((a, b) => Number(b.validUntil) - Number(a.validUntil))
      .slice(0, 8),
    previousRefreshHash: null,
    previousRefreshValidUntil: 0,
    refreshExpiresAt: now + REFRESH_LIFETIME_MS,
    lastRefreshedAt: now,
  };
  const sessions = [...registry.sessions];
  sessions[index] = entry;
  return {
    registry: { userId: parsed.uid, sessions },
    session: responseSession(accessToken, nextRefreshToken, entry),
    uid: parsed.uid,
  };
}

function revokeSession(value, tokenValue, now = Date.now()) {
  let parsed;
  try {
    parsed = parseToken(tokenValue, 'a');
  } catch (_) {
    parsed = parseToken(tokenValue, 'r');
  }
  const registry = normalizedRegistry(parsed.uid, value);
  const entry = registry.sessions.find((candidate) => candidate.id === parsed.sessionId);
  if (!entry) return { registry, uid: parsed.uid };
  const tokenHash = parsed.hash;
  const valid = safeEqual(entry.accessHash, tokenHash) ||
    safeEqual(entry.refreshHash, tokenHash) ||
    safeEqual(entry.previousRefreshHash, tokenHash) ||
    (entry.previousRefreshHashes || []).some((candidate) =>
      Number(candidate.validUntil || 0) > now && safeEqual(candidate.hash, tokenHash));
  if (!valid) throw codedError('SESSION_INVALID', 'Session token invalid');
  return {
    registry: {
      userId: parsed.uid,
      sessions: registry.sessions.filter((candidate) => candidate.id !== parsed.sessionId),
    },
    uid: parsed.uid,
  };
}

function responseSession(accessToken, refreshToken, entry) {
  return {
    accessToken,
    accessExpiresAt: entry.accessExpiresAt,
    refreshToken,
    refreshExpiresAt: entry.refreshExpiresAt,
  };
}

module.exports = {
  ACCESS_LIFETIME_MS,
  REFRESH_LIFETIME_MS,
  REFRESH_RETRY_GRACE_MS,
  MAX_SESSIONS,
  sha256,
  codedError,
  parseToken,
  issueSession,
  authenticateAccess,
  refreshSession,
  revokeSession,
};
