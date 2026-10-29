export async function fetchText(
  url,
  { timeoutMs = 12000, maxBytes = 500_000, userAgent, accept } = {},
) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: ctrl.signal,
      redirect: 'follow',
      headers: {
        'user-agent': userAgent || 'EngelsizClub-ContentScan/1.0',
        accept: accept || 'application/json, application/xml, text/xml, */*',
      },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    if (maxBytes > 0 && res.body) {
      const reader = res.body.getReader();
      const chunks = [];
      let n = 0;
      while (n < maxBytes) {
        const { done, value } = await reader.read();
        if (done) break;
        chunks.push(value);
        n += value.byteLength;
      }
      try {
        await reader.cancel();
      } catch {
        /* ignore */
      }
      return Buffer.concat(chunks.map((c) => Buffer.from(c))).toString('utf8');
    }
    return await res.text();
  } finally {
    clearTimeout(t);
  }
}

export async function fetchJson(url, opts = {}) {
  const text = await fetchText(url, {
    ...opts,
    accept: opts.accept || 'application/json, */*',
  });
  try {
    return JSON.parse(text);
  } catch {
    throw new Error('JSON değil');
  }
}

export function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}
