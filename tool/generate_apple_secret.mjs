#!/usr/bin/env node
/**
 * Apple Sign in client secret (JWT) for Supabase OAuth.
 *
 * Usage:
 *   node tool/generate_apple_secret.mjs \
 *     --team-id YOUR_TEAM_ID \
 *     --key-id YOUR_KEY_ID \
 *     --client-id com.sakircaykara.engelsizclub.auth \
 *     --p8 ./AuthKey_XXXXXX.p8
 *
 * iOS native-only (signInWithIdToken): Secret gerekmez — Client IDs yeterli.
 * Web/Android OAuth kullanıyorsanız JWT'yi Supabase → Apple → Secret Key'e yapıştırın.
 * JWT ~6 ay geçerlidir; süresi dolunca yeniden üretin.
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

function parseArgs(argv) {
  const out = {};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--team-id') out.teamId = argv[++i];
    else if (a === '--key-id') out.keyId = argv[++i];
    else if (a === '--client-id') out.clientId = argv[++i];
    else if (a === '--p8') out.p8 = argv[++i];
    else if (a === '--help' || a === '-h') out.help = true;
  }
  return out;
}

function b64url(buf) {
  return Buffer.from(buf)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function usage() {
  console.log(`Apple client secret (JWT) generator for Supabase

Required:
  --team-id     Apple Team ID (Membership sayfası)
  --key-id      Sign in with Apple Key ID (AuthKey_XXXX.p8 içindeki XXXX)
  --client-id   Services ID (OAuth için, örn. com.sakircaykara.engelsizclub.auth)
  --p8          AuthKey_XXXX.p8 dosya yolu

Example:
  node tool/generate_apple_secret.mjs \\
    --team-id ABCDE12345 \\
    --key-id X1Y2Z3A4B5 \\
    --client-id com.sakircaykara.engelsizclub.auth \\
    --p8 ./AuthKey_X1Y2Z3A4B5.p8
`);
}

const args = parseArgs(process.argv);
if (args.help || !args.teamId || !args.keyId || !args.clientId || !args.p8) {
  usage();
  process.exit(args.help ? 0 : 1);
}

const p8Path = path.resolve(args.p8);
if (!fs.existsSync(p8Path)) {
  console.error(`p8 dosyası bulunamadı: ${p8Path}`);
  process.exit(1);
}

const privateKey = fs.readFileSync(p8Path, 'utf8');
const iat = Math.floor(Date.now() / 1000);
const exp = iat + 86400 * 180; // Apple max ~6 ay

const header = b64url(JSON.stringify({ alg: 'ES256', kid: args.keyId, typ: 'JWT' }));
const payload = b64url(
  JSON.stringify({
    iss: args.teamId,
    iat,
    exp,
    aud: 'https://appleid.apple.com',
    sub: args.clientId,
  }),
);

const signingInput = `${header}.${payload}`;
const sign = crypto.createSign('SHA256');
sign.update(signingInput);
sign.end();
const signature = sign.sign({ key: privateKey, dsaEncoding: 'ieee-p1363' });
const jwt = `${signingInput}.${b64url(signature)}`;

console.log('\n--- Apple Secret Key (JWT) — Supabase\'e yapıştırın ---\n');
console.log(jwt);
console.log('\n--- Bitiş (yaklaşık) ---');
console.log(new Date(exp * 1000).toISOString());
console.log('\nNOT: .p8 dosyasını repoya eklemeyin.\n');
