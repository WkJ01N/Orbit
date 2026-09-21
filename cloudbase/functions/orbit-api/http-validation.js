'use strict';

const MAX_SYNC_BODY = 4 * 1024 * 1024;
const MAX_SYNC_ITEMS = 100;

function codedError(code, message) {
  const error = new Error(message);
  error.code = code;
  return error;
}

function validatePng(bytes) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (bytes.length < 24 || !bytes.subarray(0, 8).equals(signature)) {
    throw codedError('AVATAR_TYPE_INVALID', 'Avatar must be PNG');
  }
  const width = bytes.readUInt32BE(16);
  const height = bytes.readUInt32BE(20);
  if (width < 1 || height < 1 || width > 512 || height > 512) {
    throw codedError('AVATAR_DIMENSIONS_INVALID', 'Avatar exceeds 512 pixels');
  }
}

function validateSyncPayload(value) {
  const mutations = value.mutations;
  if (mutations != null && (!Array.isArray(mutations) || mutations.length > MAX_SYNC_ITEMS)) {
    throw codedError('INVALID_ARGUMENT', 'A sync batch may contain at most 100 items');
  }
  if (Buffer.byteLength(JSON.stringify(value), 'utf8') > MAX_SYNC_BODY) {
    throw codedError('PAYLOAD_TOO_LARGE', 'Uncompressed sync request exceeds 4 MiB');
  }
  return value;
}

module.exports = {
  MAX_SYNC_BODY,
  MAX_SYNC_ITEMS,
  validatePng,
  validateSyncPayload,
};

