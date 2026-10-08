export const SCANNER_UA =
  'EngelsizClubNewsScanner/1.0 (+https://engelsizclub.com)';

export async function fetchText(
  url,
  { timeoutMs = 12000, maxBytes = 400_000 } = {},
) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: ctrl.signal,
      redirect: 'follow',
      headers: {
        'user-agent': SCANNER_UA,
        accept:
          'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
      },
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
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

export function looksLikeHtml(text) {
  const head = String(text || '').slice(0, 2500).toLowerCase();
  return head.includes('<!doctype html') || /<html[\s>]/.test(head);
}

export function looksLikeRssOrAtom(text) {
  if (looksLikeHtml(text)) return false;
  const head = String(text || '').slice(0, 2500).toLowerCase();
  return (
    head.includes('<rss') ||
    head.includes('<feed') ||
    head.includes('<rdf:rdf')
  );
}
