// Font data only. This bridge never receives logs or decryption parameters.
window.mxFontStore = async (action, record) => {
  const database = await new Promise((resolve, reject) => {
    const request = indexedDB.open('mxlogger-font-packs', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('fonts', {keyPath: 'id'});
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error('Font storage is busy'));
  });
  try {
    return await new Promise((resolve, reject) => {
      const transaction = database.transaction('fonts', action === 'list' ? 'readonly' : 'readwrite');
      const store = transaction.objectStore('fonts');
      const request = action === 'list' ? store.getAll()
        : action === 'put' ? store.put(record) : store.delete(record);
      let result;
      request.onsuccess = () => { result = request.result; };
      transaction.oncomplete = () => resolve(result);
      transaction.onabort = () => reject(transaction.error || new Error('Font storage failed'));
      transaction.onerror = () => reject(transaction.error);
    });
  } finally {
    database.close();
  }
};

window.mxFontDigest = async bytes => {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map(value => value.toString(16).padStart(2, '0')).join('');
};

window.mxInspectFont = async bytes => {
  const kit = window.flutterCanvasKit;
  const face = kit.Typeface.MakeFreeTypeFaceFromData(bytes);
  if (!face) throw new Error('Invalid font');
  const font = new kit.Font(face, 16);
  const ranges = [];
  try {
    // Inspect actual glyph coverage, including supplementary Unicode planes.
    // Yield between chunks so font installation keeps the UI responsive.
    for (let start = 32; start <= 0x10ffff; start += 8192) {
      const points = [];
      for (let cp = start; cp < Math.min(start + 8192, 0x110000); cp++) {
        if (cp < 0xd800 || cp > 0xdfff) points.push(cp);
      }
      const glyphs = font.getGlyphIDs(String.fromCodePoint(...points), points.length);
      if (glyphs.length !== points.length) throw new Error('Cannot inspect font coverage');
      for (let i = 0; i < points.length; i++) {
        if (!glyphs[i]) continue;
        const cp = points[i], previous = ranges[ranges.length - 1];
        if (previous && previous[1] + 1 === cp) previous[1] = cp;
        else ranges.push([cp, cp]);
      }
      await new Promise(resolve => setTimeout(resolve, 0));
    }
    if (ranges.length === 0) throw new Error('Empty font');
    return JSON.stringify(ranges);
  } finally {
    font.delete();
    face.delete();
  }
};

let fontDownload;
window.mxDownloadFont = async (urls, expectedHash, progress) => {
  const download = {cancelled: false, controller: null};
  fontDownload = download;
  const attempts = [];
  try {
    for (let index = 0; index < urls.length; index++) {
      if (download.cancelled) break;
      const controller = new AbortController();
      download.controller = controller;
      let timedOut = false;
      let idleTimer;
      const abortTimeout = () => { timedOut = true; controller.abort(); };
      const resetIdle = ms => {
        clearTimeout(idleTimer);
        idleTimer = setTimeout(abortTimeout, ms);
      };
      const totalTimer = setTimeout(abortTimeout, 120000);
      const fail = (code, status) => Object.assign(new Error(code), {code, status});
      progress(0, index);
      // A stalled source should not leave the user waiting two minutes before
      // trying the alternative. Active downloads get a longer overall limit.
      resetIdle(12000);
      try {
        const response = await fetch(urls[index], {
          method: 'GET', credentials: 'omit', referrerPolicy: 'no-referrer', signal: controller.signal,
        });
        if (!response.ok) throw fail('http', response.status);
        if (!response.body) throw fail('incomplete');
        const reader = response.body.getReader();
        const chunks = [];
        let count = 0;
        resetIdle(20000);
        while (true) {
          const {done, value} = await reader.read();
          if (done) break;
          count += value.length;
          if (count > 32 * 1024 * 1024) throw fail('size');
          chunks.push(value);
          progress(count, index);
          resetIdle(20000);
        }
        clearTimeout(idleTimer);
        clearTimeout(totalTimer);
        if (!count) throw fail('incomplete');
        const bytes = new Uint8Array(count);
        let offset = 0;
        for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
        if (await window.mxFontDigest(bytes) !== expectedHash) throw fail('integrity');
        if (download.cancelled) break;
        return {bytes, error: null, attempts: JSON.stringify(attempts)};
      } catch (error) {
        // Stop the response body as well as its timers before retrying.
        controller.abort();
        if (download.cancelled) break;
        attempts.push({index, code: timedOut ? 'timeout' : error.code || 'network', status: error.status || null});
      } finally {
        clearTimeout(idleTimer);
        clearTimeout(totalTimer);
      }
    }
    return {bytes: null, error: download.cancelled ? 'cancelled' : 'download', attempts: JSON.stringify(attempts)};
  } finally {
    if (fontDownload === download) fontDownload = null;
  }
};
window.mxCancelFontDownload = () => {
  if (!fontDownload) return;
  fontDownload.cancelled = true;
  fontDownload.controller?.abort();
};
