// FCM HTTP v1 (FIREBASE_SERVICE_ACCOUNT_JSON) + Legacy (FCM_SERVER_KEY).
// Service account asla Flutter uygulamasına konmaz — yalnız Edge Function secret.

export type FcmSendResult = {
  sent: number;
  failed: number;
  invalidTokens: string[];
  detail: unknown;
};

type ServiceAccount = {
  project_id?: string;
  client_email?: string;
  private_key?: string;
};

let cachedAccess: { token: string; exp: number } | null = null;

function b64url(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const raw = atob(b64);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(pem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function googleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccess && cachedAccess.exp - 60 > now) return cachedAccess.token;
  if (!sa.client_email || !sa.private_key) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON eksik alan");
  }
  const enc = new TextEncoder();
  const header = b64url(enc.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const payload = b64url(
    enc.encode(
      JSON.stringify({
        iss: sa.client_email,
        sub: sa.client_email,
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
      }),
    ),
  );
  const unsigned = `${header}.${payload}`;
  const key = await importPrivateKey(sa.private_key);
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    enc.encode(unsigned),
  );
  const jwt = `${unsigned}.${b64url(new Uint8Array(sig))}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const json = await res.json() as { access_token?: string; expires_in?: number };
  if (!res.ok || !json.access_token) {
    throw new Error(`Google OAuth: ${JSON.stringify(json)}`);
  }
  cachedAccess = {
    token: json.access_token,
    exp: now + (json.expires_in ?? 3600),
  };
  return json.access_token;
}

function parseServiceAccount(): ServiceAccount | null {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";
  if (!raw.trim()) return null;
  try {
    return JSON.parse(raw) as ServiceAccount;
  } catch {
    return null;
  }
}

export function fcmProjectId(sa?: ServiceAccount | null): string {
  return (sa?.project_id ||
    Deno.env.get("FCM_PROJECT_ID") ||
    "engelsizclub-e5842").trim();
}

function stringifyData(data: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(data)) {
    if (v == null) continue;
    out[k] = String(v);
  }
  return out;
}

export function buildLegacyPayload(opts: {
  to: string | string[];
  title: string;
  body: string;
  data: Record<string, string>;
}): Record<string, unknown> {
  const { to, title, body, data } = opts;
  const base: Record<string, unknown> = {
    priority: "high",
    notification: {
      title,
      body: body || title,
    },
    android: {
      priority: "high",
      notification: {
        channel_id: "engelsizclub_default",
        sound: "default",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          "mutable-content": 1,
        },
      },
    },
    data: {
      ...stringifyData(data),
      title,
      body: body || title,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
  };
  if (Array.isArray(to)) base.registration_ids = to;
  else base.to = to;
  return base;
}

function v1Message(opts: {
  token?: string;
  topic?: string;
  title: string;
  body: string;
  data: Record<string, string>;
}): Record<string, unknown> {
  const { token, topic, title, body, data } = opts;
  return {
    ...(token ? { token } : {}),
    ...(topic ? { topic } : {}),
    notification: { title, body: body || title },
    data: stringifyData({
      ...data,
      title,
      body: body || title,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    }),
    android: {
      priority: "HIGH",
      notification: {
        channel_id: "engelsizclub_default",
        sound: "default",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          "mutable-content": 1,
        },
      },
    },
  };
}

function isUnregisteredStatus(status: number, body: unknown): boolean {
  if (status === 404) return true;
  const s = JSON.stringify(body).toUpperCase();
  return s.includes("UNREGISTERED") ||
    s.includes("NOT_FOUND") ||
    s.includes("INVALID_ARGUMENT") && s.includes("TOKEN");
}

async function sendLegacy(
  serverKey: string,
  payload: Record<string, unknown>,
  tokens: string[],
): Promise<FcmSendResult> {
  const fcmRes = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      Authorization: `key=${serverKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const fcmText = await fcmRes.text();
  let fcmJson: unknown = fcmText;
  try {
    fcmJson = JSON.parse(fcmText);
  } catch {
    /* raw */
  }
  const invalidTokens: string[] = [];
  const obj = fcmJson as {
    results?: Array<{ error?: string; message_id?: string }>;
    success?: number;
    failure?: number;
  };
  if (Array.isArray(obj.results)) {
    obj.results.forEach((r, i) => {
      const err = (r.error ?? "").toLowerCase();
      if (
        err === "notregistered" ||
        err === "invalidregistration" ||
        err === "mismatchsenderid"
      ) {
        if (tokens[i]) invalidTokens.push(tokens[i]);
      }
    });
  }
  return {
    sent: obj.success ?? (fcmRes.ok ? tokens.length : 0),
    failed: obj.failure ?? (fcmRes.ok ? 0 : tokens.length),
    invalidTokens,
    detail: fcmJson,
  };
}

async function sendV1Tokens(
  sa: ServiceAccount,
  opts: { title: string; body: string; data: Record<string, string> },
  tokens: string[],
): Promise<FcmSendResult> {
  const access = await googleAccessToken(sa);
  const project = fcmProjectId(sa);
  const invalidTokens: string[] = [];
  let sent = 0;
  let failed = 0;
  const details: unknown[] = [];
  for (const token of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${project}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${access}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: v1Message({
            token,
            title: opts.title,
            body: opts.body,
            data: opts.data,
          }),
        }),
      },
    );
    const text = await res.text();
    let json: unknown = text;
    try {
      json = JSON.parse(text);
    } catch {
      /* raw */
    }
    details.push(json);
    if (res.ok) {
      sent++;
    } else {
      failed++;
      if (isUnregisteredStatus(res.status, json)) invalidTokens.push(token);
    }
  }
  return { sent, failed, invalidTokens, detail: details };
}

async function sendV1Topic(
  sa: ServiceAccount,
  opts: { topic: string; title: string; body: string; data: Record<string, string> },
): Promise<FcmSendResult> {
  const access = await googleAccessToken(sa);
  const project = fcmProjectId(sa);
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${project}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${access}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: v1Message({
          topic: opts.topic,
          title: opts.title,
          body: opts.body,
          data: opts.data,
        }),
      }),
    },
  );
  const text = await res.text();
  let json: unknown = text;
  try {
    json = JSON.parse(text);
  } catch {
    /* raw */
  }
  return {
    sent: res.ok ? 1 : 0,
    failed: res.ok ? 0 : 1,
    invalidTokens: [],
    detail: json,
  };
}

/** Token listesine gönder; geçersizleri döndür (çağıran siler). */
export async function sendFcmToTokens(opts: {
  tokens: string[];
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<FcmSendResult> {
  const tokens = opts.tokens.map((t) => t.trim()).filter((t) => t.length > 20);
  if (tokens.length === 0) {
    return { sent: 0, failed: 0, invalidTokens: [], detail: "no_token" };
  }
  const sa = parseServiceAccount();
  if (sa?.private_key) {
    return await sendV1Tokens(sa, opts, tokens);
  }
  const serverKey = Deno.env.get("FCM_SERVER_KEY") ?? "";
  if (!serverKey) {
    throw new Error(
      "FCM yok: FIREBASE_SERVICE_ACCOUNT_JSON veya FCM_SERVER_KEY secret ayarlayın.",
    );
  }
  const chunk = tokens.slice(0, 100);
  return await sendLegacy(
    serverKey,
    buildLegacyPayload({
      to: chunk,
      title: opts.title,
      body: opts.body,
      data: opts.data,
    }),
    chunk,
  );
}

export async function sendFcmToTopic(opts: {
  topic: string;
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<FcmSendResult> {
  const sa = parseServiceAccount();
  if (sa?.private_key) {
    return await sendV1Topic(sa, opts);
  }
  const serverKey = Deno.env.get("FCM_SERVER_KEY") ?? "";
  if (!serverKey) {
    throw new Error(
      "FCM yok: FIREBASE_SERVICE_ACCOUNT_JSON veya FCM_SERVER_KEY secret ayarlayın.",
    );
  }
  return await sendLegacy(
    serverKey,
    buildLegacyPayload({
      to: `/topics/${opts.topic}`,
      title: opts.title,
      body: opts.body,
      data: opts.data,
    }),
    [],
  );
}

export async function deleteInvalidTokens(
  // deno-lint-ignore no-explicit-any
  admin: { from: (t: string) => any },
  tokens: string[],
): Promise<void> {
  if (tokens.length === 0) return;
  try {
    await admin.from("user_push_tokens").delete().in("token", tokens);
  } catch (e) {
    console.error("invalid token cleanup", e);
  }
}
