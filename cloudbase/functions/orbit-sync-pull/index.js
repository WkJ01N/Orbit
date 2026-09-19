'use strict';

const sync = require('./sync-common');

exports.main = async (event) => {
  try {
    return sync.success(await sync.pull(sync.currentUid(), event || {}));
  } catch (error) {
    return sync.failure(error);
  }
};
