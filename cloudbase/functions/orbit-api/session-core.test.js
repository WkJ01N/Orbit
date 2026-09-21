'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const core = require('./session-core');

function issue(registry, uid, deviceId, now) {
  return core.issueSession(registry, { uid, deviceId, platform: 'test', now });
}

test('same device replaces its session without consuming another slot', () => {
  const first = issue(null, 'user-1', 'device-0000000001', 1000);
  const second = issue(first.registry, 'user-1', 'device-0000000001', 2000);
  assert.equal(second.registry.sessions.length, 1);
  assert.equal(second.registry.sessions[0].createdAt, 1000);
  assert.throws(
    () => core.authenticateAccess(second.registry, first.session.accessToken, 2001),
    { code: 'SESSION_INVALID' },
  );
});

test('sixth device evicts the oldest and invalidates it immediately', () => {
  let registry;
  const tokens = [];
  for (let index = 0; index < 6; index += 1) {
    const result = issue(registry, 'user-1', `device-000000000${index}`, 1000 + index);
    registry = result.registry;
    tokens.push(result.session.accessToken);
  }
  assert.equal(registry.sessions.length, core.MAX_SESSIONS);
  assert.throws(() => core.authenticateAccess(registry, tokens[0], 2000), {
    code: 'SESSION_INVALID',
  });
  assert.equal(core.authenticateAccess(registry, tokens[5], 2000).uid, 'user-1');
});

test('refresh rotates both tokens and accepts one retry during grace', () => {
  const issued = issue(null, 'user-1', 'device-0000000001', 1000);
  const refreshed = core.refreshSession(issued.registry, issued.session.refreshToken, 2000);
  assert.throws(
    () => core.authenticateAccess(refreshed.registry, issued.session.accessToken, 2001),
    { code: 'SESSION_INVALID' },
  );
  assert.equal(
    core.authenticateAccess(refreshed.registry, refreshed.session.accessToken, 2001).uid,
    'user-1',
  );
  const retried = core.refreshSession(
    refreshed.registry,
    issued.session.refreshToken,
    2000 + core.REFRESH_RETRY_GRACE_MS - 1,
  );
  assert.ok(retried.session.refreshToken);
  assert.throws(
    () => core.refreshSession(retried.registry, issued.session.refreshToken, 2000 + core.REFRESH_RETRY_GRACE_MS + 1),
    { code: 'SESSION_INVALID' },
  );
});

test('refresh lifetime slides and an idle session expires', () => {
  const issued = issue(null, 'user-1', 'device-0000000001', 1000);
  const nearExpiry = 1000 + core.REFRESH_LIFETIME_MS - 1;
  const refreshed = core.refreshSession(issued.registry, issued.session.refreshToken, nearExpiry);
  assert.equal(
    refreshed.session.refreshExpiresAt,
    nearExpiry + core.REFRESH_LIFETIME_MS,
  );
  assert.throws(
    () => core.refreshSession(issued.registry, issued.session.refreshToken, 1000 + core.REFRESH_LIFETIME_MS),
    { code: 'SESSION_INVALID' },
  );
});

test('revoke removes only the addressed device', () => {
  const first = issue(null, 'user-1', 'device-0000000001', 1000);
  const second = issue(first.registry, 'user-1', 'device-0000000002', 1001);
  const revoked = core.revokeSession(second.registry, first.session.refreshToken);
  assert.equal(revoked.registry.sessions.length, 1);
  assert.equal(
    core.authenticateAccess(revoked.registry, second.session.accessToken, 1002).uid,
    'user-1',
  );
});

test('expired and forged access tokens are rejected', () => {
  const issued = issue(null, 'user-1', 'device-0000000001', 1000);
  assert.throws(
    () => core.authenticateAccess(
      issued.registry,
      issued.session.accessToken,
      1000 + core.ACCESS_LIFETIME_MS,
    ),
    { code: 'ACCESS_EXPIRED' },
  );
  const forged = issued.session.accessToken.replace(
    Buffer.from('user-1').toString('base64url'),
    Buffer.from('user-2').toString('base64url'),
  );
  assert.throws(() => core.authenticateAccess(issued.registry, forged, 1001), {
    code: 'SESSION_INVALID',
  });
});

test('concurrent refresh retries leave both returned refresh tokens usable', () => {
  const issued = issue(null, 'user-1', 'device-0000000001', 1000);
  const first = core.refreshSession(issued.registry, issued.session.refreshToken, 2000);
  const second = core.refreshSession(first.registry, issued.session.refreshToken, 2001);
  assert.doesNotThrow(() =>
    core.refreshSession(second.registry, first.session.refreshToken, 2002));
  assert.doesNotThrow(() =>
    core.refreshSession(second.registry, second.session.refreshToken, 2002));
});
