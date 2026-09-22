'use strict';

function errorText(error) {
  return [error?.code, error?.message, error?.name]
    .filter(Boolean)
    .join(' ')
    .toUpperCase();
}

function isMissingCollection(error) {
  const text = errorText(error);
  return text.includes('DATABASE_COLLECTION_NOT_EXIST')
    || text.includes('NAMESPACE NOT FOUND')
    || text.includes('NAMESPACENOTFOUND');
}

function isExistingCollection(error) {
  const text = errorText(error);
  return text.includes('DATABASE_COLLECTION_EXIST')
    || text.includes('ALREADY EXISTS')
    || text.includes('NAMESPACE EXISTS')
    || text.includes('NAMESPACEEXISTS');
}

function createCollectionBootstrap(database, collectionNames) {
  let pending;

  async function probeOrCreate(name) {
    try {
      await database.collection(name).limit(1).get();
      return;
    } catch (error) {
      if (!isMissingCollection(error)) throw error;
    }

    try {
      await database.createCollection(name);
    } catch (error) {
      // Two cold starts can race to create the same collection.
      if (!isExistingCollection(error)) throw error;
    }
  }

  return async function ensureCollections() {
    if (!pending) {
      pending = Promise.all(collectionNames.map(probeOrCreate)).catch((error) => {
        pending = null;
        throw error;
      });
    }
    await pending;
  };
}

module.exports = {
  createCollectionBootstrap,
  isExistingCollection,
  isMissingCollection,
};
