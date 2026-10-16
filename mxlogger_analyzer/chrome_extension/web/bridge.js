// One workspace owns the IndexedDB-backed SQLite cache at a time.
globalThis.mxAcquireWorkspace = () => new Promise((resolve, reject) => {
  navigator.locks.request("mxlogger-workspace", { ifAvailable: true }, (lock) => {
    resolve(Boolean(lock));
    if (lock) return new Promise(() => {});
  }).catch(reject);
});

// These functions also run in the SQLite worker. Logs stay in local IndexedDB.
const mxCacheName = 'mxlogger-analyzer-cache';
const mxLegacyCacheName = 'mxlogger-analyzer-prototype';
const mxDatabasePath = '/mxlogger_analyzer.db';
let mxLegacyCacheNeedsCleanup = true;

function mxIdbRequest(request) {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function mxIdbTransaction(transaction) {
  return new Promise((resolve, reject) => {
    transaction.oncomplete = resolve;
    transaction.onabort = () => reject(transaction.error || new Error('Log cache transaction aborted'));
    transaction.onerror = () => reject(transaction.error);
  });
}

function mxOpenLogCache(name, upgrade) {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(name, 1);
    request.onupgradeneeded = () => upgrade?.(request.result);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error('Log cache is busy'));
  });
}

async function mxReadCacheBlob(blob, progress) {
  const bytes = new Uint8Array(blob.size);
  const reader = blob.stream().getReader();
  let received = 0, lastPercent = -1;
  progress('cache', 0, blob.size);
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      bytes.set(value, received);
      received += value.length;
      const percent = Math.floor(received * 100 / blob.size);
      if (percent !== lastPercent) {
        lastPercent = percent;
        progress('cache', received, blob.size);
      }
    }
    if (received !== blob.size) throw new Error('Incomplete log cache read');
    return bytes;
  } finally {
    reader.releaseLock();
  }
}

globalThis.mxReadLogCache = async (progress = () => {}) => {
  progress('cache', 0, 0);
  const database = await mxOpenLogCache(mxCacheName, db => db.createObjectStore('snapshots'));
  let snapshot;
  try {
    const transaction = database.transaction('snapshots', 'readonly');
    const complete = mxIdbTransaction(transaction);
    [snapshot] = await Promise.all([
      mxIdbRequest(transaction.objectStore('snapshots').get(mxDatabasePath)), complete,
    ]);
  } finally {
    database.close();
  }
  if (snapshot !== undefined) {
    return snapshot.size ? [{name: mxDatabasePath, bytes: await mxReadCacheBlob(snapshot, progress)}] : [];
  }

  // Read existing installations before changing their cache. The old data is
  // removed only after its recovered snapshot has been committed successfully.
  // Bulk reads and a single Blob conversion per file also make the first
  // restore faster. Include the old journal so SQLite can recover interrupted
  // transactions before the first snapshot is saved.
  if (!(await indexedDB.databases()).some(db => db.name === mxLegacyCacheName)) return [];
  progress('migrate', 0, 0);
  const legacy = await mxOpenLogCache(mxLegacyCacheName);
  try {
    const transaction = legacy.transaction(['files', 'blocks'], 'readonly');
    const complete = mxIdbTransaction(transaction);
    const files = transaction.objectStore('files');
    const blocks = transaction.objectStore('blocks');
    const [entries, ids, keys, values] = await Promise.all([
      mxIdbRequest(files.getAll()), mxIdbRequest(files.getAllKeys()),
      mxIdbRequest(blocks.getAllKeys()), mxIdbRequest(blocks.getAll()), complete,
    ]);
    const parts = new Map(ids.map(id => [id, {offset: 0, blobs: []}]));
    for (let i = 0; i < keys.length; i++) {
      const [id, offset] = keys[i];
      const file = parts.get(id);
      if (!file) continue;
      if (offset > file.offset) file.blobs.push(new Uint8Array(offset - file.offset));
      file.blobs.push(values[i]);
      file.offset = offset + (values[i].size ?? values[i].byteLength);
    }
    const total = entries.reduce((sum, entry) => sum + entry.length, 0);
    const restored = [];
    let received = 0;
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const file = parts.get(ids[i]);
      if (entry.length > file.offset) file.blobs.push(new Uint8Array(entry.length - file.offset));
      const blob = new Blob(file.blobs).slice(0, entry.length);
      const bytes = await mxReadCacheBlob(blob, (stage, loaded) => progress(stage, received + loaded, total));
      restored.push({name: entry.name, bytes, legacy: true});
      received += bytes.length;
    }
    return restored;
  } finally {
    legacy.close();
  }
};

globalThis.mxWriteLogCache = async bytes => {
  const snapshot = new Blob([bytes]);
  const database = await mxOpenLogCache(mxCacheName, db => db.createObjectStore('snapshots'));
  try {
    const transaction = database.transaction('snapshots', 'readwrite');
    const complete = mxIdbTransaction(transaction);
    transaction.objectStore('snapshots').put(snapshot, mxDatabasePath);
    await complete;
  } finally {
    database.close();
  }
  if (mxLegacyCacheNeedsCleanup) {
    // Cleanup failure must not turn a successfully committed save into an
    // import failure. Retry on the next save if another page blocks deletion.
    mxLegacyCacheNeedsCleanup = !await new Promise(resolve => {
      const request = indexedDB.deleteDatabase(mxLegacyCacheName);
      request.onsuccess = () => resolve(true);
      request.onerror = request.onblocked = () => resolve(false);
    });
  }
};
