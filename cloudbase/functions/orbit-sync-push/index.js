'use strict';

const sync = require('./sync-common');

exports.main = async (event) => {
  try {
    const input = event || {};
    const uid = sync.currentUid();
    const pushed = await sync.push(uid, input);
    const pulled = await sync.pull(uid, {
      cursor: input.cursor,
      limit: input.pullLimit || 200,
    });
    return sync.success({ ...pushed, pull: pulled });
  } catch (error) {
    return sync.failure(error);
  }
};
