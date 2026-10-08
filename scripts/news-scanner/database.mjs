const PAGE = 500;

export function supabaseConfig() {
  const url = String(process.env.SUPABASE_URL || '')
    .replace(/\/+$/, '')
    .replace('qycrkqwqrysypvqipqn', 'qycrkqwqrysypvqaipqn')
    .replace('ypvqipqn.supabase.co', 'ypvqaipqn.supabase.co');
  const key = String(process.env.SUPABASE_SERVICE_ROLE_KEY || '').trim();
  return { url, key };
}

function headers(key) {
  return {
    apikey: key,
    authorization: `Bearer ${key}`,
    'content-type': 'application/json',
    prefer: 'return=representation',
  };
}

export async function sb(url, key, path, { method = 'GET', body } = {}) {
  const res = await fetch(`${url}/rest/v1/${path}`, {
    method,
    headers: headers(key),
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`Supabase ${method} ${path}: ${res.status} ${text.slice(0, 400)}`);
  }
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

export async function loadLastOkRun(url, key) {
  const rows =
    (await sb(
      url,
      key,
      'news_scan_runs?ok=eq.true&finished_at=not.is.null&select=finished_at&order=finished_at.desc&limit=1',
    )) || [];
  return rows[0]?.finished_at || null;
}

export async function loadExistingCandidates(url, key) {
  const out = [];
  let offset = 0;
  for (;;) {
    const rows =
      (await sb(
        url,
        key,
        `news_candidates?select=id,canonical_url,content_hash,title,title_fingerprint,duplicate_group_id&order=created_at.desc&limit=${PAGE}&offset=${offset}`,
      )) || [];
    if (!Array.isArray(rows) || !rows.length) break;
    out.push(...rows);
    if (rows.length < PAGE) break;
    offset += rows.length;
    if (offset > 8000) break;
  }
  return out;
}

export async function insertCandidate(url, key, row) {
  return sb(url, key, 'news_candidates', { method: 'POST', body: row });
}

export async function insertScanRun(url, key, row) {
  return sb(url, key, 'news_scan_runs', { method: 'POST', body: row });
}
