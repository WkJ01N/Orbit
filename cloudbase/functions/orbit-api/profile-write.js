'use strict';

function writableProfile(current, changes, uid) {
  const profile = {
    userId: uid,
    email: current.email || '',
    username: changes.username ?? current.username ?? '',
    avatarFileId: changes.avatarFileId ?? current.avatarFileId ?? null,
  };
  if (current.createdAt) profile.createdAt = current.createdAt;
  return profile;
}

async function commitAvatar({ fileId, oldFileId, persist, remove }) {
  let updated;
  try {
    updated = await persist();
  } catch (error) {
    try { await remove(fileId); } catch (_) { /* best effort cleanup */ }
    throw error;
  }
  if (oldFileId && oldFileId !== fileId) {
    try { await remove(oldFileId); } catch (_) { /* best effort cleanup */ }
  }
  return updated;
}

module.exports = { writableProfile, commitAvatar };
