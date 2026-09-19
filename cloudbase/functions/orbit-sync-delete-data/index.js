'use strict';

const sync = require('./sync-common');

exports.main = async () => {
  try {
    return sync.success(await sync.deleteData(sync.currentUid()));
  } catch (error) {
    return sync.failure(error);
  }
};
