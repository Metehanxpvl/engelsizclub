'use strict';

const path = require('path');
const toolsRoot = path.join(
  process.env.APPDATA,
  'npm',
  'node_modules',
  'firebase-tools',
);
const hostingApi = require(path.join(toolsRoot, 'lib', 'hosting', 'api.js'));
const { Client } = require(path.join(toolsRoot, 'lib', 'apiv2.js'));
const { hostingApiOrigin } = require(path.join(toolsRoot, 'lib', 'api.js'));
const { getGlobalDefaultAccount } = require(path.join(toolsRoot, 'lib', 'auth.js'));
const { requireAuth } = require(path.join(toolsRoot, 'lib', 'requireAuth.js'));

const site = 'engelsizclub-e5842';
const project = 'engelsizclub-e5842';
const keepNewest = 2;
const concurrency = 12;

function versionId(name) {
  return String(name).split('/').pop();
}

async function mapPool(items, limit, fn) {
  let i = 0;
  let ok = 0;
  let fail = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (i < items.length) {
      const item = items[i++];
      try {
        await fn(item);
        ok += 1;
        if (ok % 25 === 0) console.log('Deleted', ok, '/', items.length);
      } catch (err) {
        fail += 1;
        if (fail <= 8) {
          console.error('Delete failed', versionId(item.name), err && err.message ? err.message : err);
        }
      }
    }
  });
  await Promise.all(workers);
  return { ok, fail };
}

async function main() {
  const account = getGlobalDefaultAccount();
  if (!account) {
    throw new Error('firebase login required');
  }
  await requireAuth({
    user: account.user,
    tokens: account.tokens,
    project,
  });

  const apiClient = new Client({
    urlPrefix: hostingApiOrigin(),
    apiVersion: 'v1beta1',
    auth: true,
  });

  const channels = await hostingApi.listChannels('-', site);
  console.log('Channels:', channels.length);
  for (const ch of channels) {
    const id = String(ch.name).split('/').pop();
    console.log(' Channel', id, ch.release?.version?.name || '(no release)');
    if (id && id !== 'live') {
      try {
        await hostingApi.deleteChannel('-', site, id);
        console.log(' Deleted preview channel', id);
      } catch (err) {
        console.error(' Channel delete failed', id, err && err.message ? err.message : err);
      }
    }
  }

  try {
    await apiClient.patch(
      `projects/-/sites/${site}/channels/live`,
      { retainedReleaseCount: 2 },
      { queryParams: { updateMask: 'retainedReleaseCount' } },
    );
    console.log('Set live retainedReleaseCount=2');
  } catch (err) {
    console.error('retainedReleaseCount patch failed:', err && err.message ? err.message : err);
  }

  const channel = await hostingApi.getChannel('-', site, 'live');
  const liveName = channel?.release?.version?.name || '';
  const versions = await hostingApi.listVersions(site);
  const counts = {};
  for (const v of versions) {
    const s = v.status || 'UNKNOWN';
    counts[s] = (counts[s] || 0) + 1;
  }
  console.log('Version status counts', counts);

  const active = versions.filter((v) => v.status && v.status !== 'DELETED');
  active.sort((a, b) => String(b.createTime || '').localeCompare(String(a.createTime || '')));
  const keep = new Set(active.slice(0, keepNewest).map((v) => v.name));
  if (liveName) keep.add(liveName);

  const toDelete = active.filter((v) => !keep.has(v.name));
  console.log(
    'Versions',
    versions.length,
    'active',
    active.length,
    'keep',
    keep.size,
    'delete',
    toDelete.length,
    'live',
    liveName,
  );

  const { ok, fail } = await mapPool(toDelete, concurrency, async (v) => {
    const id = versionId(v.name);
    try {
      await apiClient.delete(`sites/${site}/versions/${id}`);
      return;
    } catch (_) {
      await apiClient.delete(`projects/-/sites/${site}/versions/${id}`);
    }
  });
  console.log('Deleted', ok, 'failed', fail);
}

main().catch((err) => {
  console.error(err && err.message ? err.message : err);
  process.exit(1);
});
