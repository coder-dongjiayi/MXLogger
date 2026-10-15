// One workspace owns the IndexedDB-backed SQLite cache at a time.
window.mxAcquireWorkspace = () => new Promise((resolve, reject) => {
  navigator.locks.request("mxlogger-workspace", { ifAvailable: true }, (lock) => {
    resolve(Boolean(lock));
    if (lock) return new Promise(() => {});
  }).catch(reject);
});
