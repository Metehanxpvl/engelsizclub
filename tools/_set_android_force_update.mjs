import { readFileSync } from 'node:fs';

function env(name) {
  const fromProcess = process.env[name];
  if (fromProcess && fromProcess.trim()) return fromProcess.trim();
  for (const file of ['.env', '.env.local']) {
    let text = '';
    try {
      text = readFileSync(file, 'utf8');
    } catch {
      continue;
    }
    for (const raw of text.split(/\r?\n/)) {
      const line = raw.trim();
      if (!line || line.startsWith('#')) continue;
      const eq = line.indexOf('=');
      if (eq < 1) continue;
      const k = line.slice(0, eq).trim();
      if (k !== name) continue;
      let v = line.slice(eq + 1).trim();
      if (
        (v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))
      ) {
        v = v.slice(1, -1);
      }
      if (v) return v;
    }
  }
  return '';
}

const url = env('SUPABASE_URL').replace(/\/$/, '');
const key = env('SUPABASE_SERVICE_ROLE_KEY') || env('SUPABASE_ANON_KEY');
if (!url || !key) {
  console.error('missing_supabase_env');
  process.exit(1);
}

const headers = {
  apikey: key,
  Authorization: `Bearer ${key}`,
  'Content-Type': 'application/json',
};

const getRes = await fetch(
  `${url}/rest/v1/app_settings?key=eq.force_update&select=value`,
  { headers },
);
if (!getRes.ok) {
  console.error('get_failed', getRes.status);
  process.exit(1);
}
const rows = await getRes.json();
const value =
  rows[0]?.value && typeof rows[0].value === 'object' ? { ...rows[0].value } : {};

value.latestVersionAndroid = '1.1.4';
if (!String(value.minimumSupportedVersion || '').trim()) {
  value.minimumSupportedVersion = '1.0.0';
}
value.android_url =
  'https://play.google.com/store/apps/details?id=com.sakircaykara.engelsizclub';
if (!String(value.ios_url || '').trim()) {
  value.ios_url = 'https://apps.apple.com/tr/app/engelsiz-club/id6799422264';
}
if (!String(value.latestVersionIOS || '').trim()) {
  value.latestVersionIOS = '1.1.16';
}

const patchRes = await fetch(
  `${url}/rest/v1/app_settings?key=eq.force_update`,
  {
    method: rows[0] ? 'PATCH' : 'POST',
    headers: { ...headers, Prefer: 'return=representation' },
    body: rows[0]
      ? JSON.stringify({ value, updated_at: new Date().toISOString() })
      : JSON.stringify({
          key: 'force_update',
          value,
          description: 'Android uyarısı yalnız Play yayını sonrası (In-App Update).',
        }),
  },
);
if (!patchRes.ok) {
  console.error('patch_failed', patchRes.status, await patchRes.text());
  process.exit(1);
}
const patched = await patchRes.json();
const next = patched[0]?.value ?? value;
console.log(
  JSON.stringify({
    latestVersionAndroid: next.latestVersionAndroid,
    latestVersionIOS: next.latestVersionIOS,
    minimumSupportedVersion: next.minimumSupportedVersion,
  }),
);
