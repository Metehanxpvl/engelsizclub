const { onRequest } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const { defineString } = require('firebase-functions/params');

setGlobalOptions({ region: 'europe-west1', maxInstances: 20 });

const geminiApiKey = defineString('GEMINI_API_KEY', { default: '' });

// Client'taki ile aynı anahtar — Cloud'da HTTP referrer kısıtı OLMAMALI
// (Application restriction: None, API restriction: Places API + Maps).
const PLACES_KEY =
  process.env.GOOGLE_PLACES_API_KEY ||
  'AIzaSyAHDu7hYJInYdPhrg8i0YdEzgfl0lL502o';

const NEARBY =
  'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
const TEXT = 'https://maps.googleapis.com/maps/api/place/textsearch/json';
const DETAILS = 'https://maps.googleapis.com/maps/api/place/details/json';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json; charset=utf-8',
};

exports.placesProxy = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(cors).status(204).send('');
    return;
  }
  if (req.method !== 'GET') {
    res.set(cors).status(405).json({ status: 'INVALID_REQUEST', error_message: 'GET only' });
    return;
  }

  try {
    const q = req.query || {};
    const mode = String(q.mode || 'nearby');
    let url;

    if (mode === 'nearby') {
      const params = new URLSearchParams({
        location: String(q.location || ''),
        radius: String(q.radius || '5000'),
        keyword: String(q.keyword || ''),
        language: 'tr',
        key: PLACES_KEY,
      });
      url = `${NEARBY}?${params}`;
    } else if (mode === 'text') {
      const params = new URLSearchParams({
        query: String(q.query || ''),
        location: String(q.location || ''),
        radius: String(q.radius || '5000'),
        language: 'tr',
        region: 'tr',
        key: PLACES_KEY,
      });
      url = `${TEXT}?${params}`;
    } else if (mode === 'details') {
      const params = new URLSearchParams({
        place_id: String(q.place_id || ''),
        fields:
          'formatted_phone_number,opening_hours,formatted_address,international_phone_number',
        language: 'tr',
        key: PLACES_KEY,
      });
      url = `${DETAILS}?${params}`;
    } else {
      res.set(cors).status(400).json({
        status: 'INVALID_REQUEST',
        error_message: 'mode=nearby|text|details',
      });
      return;
    }

    const upstream = await fetch(url, {
      headers: {
        Accept: 'application/json',
        Referer: 'https://engelsizclub-e5842.web.app/',
      },
    });
    const text = await upstream.text();
    res.set(cors).status(upstream.status).send(text);
  } catch (e) {
    res.set(cors).status(500).json({
      status: 'UNKNOWN_ERROR',
      error_message: String(e && e.message ? e.message : e),
    });
  }
});

const geminiCors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

/** Web CORS bypass: Flutter POST /api/gemini → Google generateContent. */
exports.geminiProxy = onRequest(
  {
    cors: true,
    timeoutSeconds: 120,
    memory: '512MiB',
    maxInstances: 20,
  },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.set(geminiCors).status(204).send('');
      return;
    }
    if (req.method !== 'POST') {
      res.set(geminiCors).status(405).json({ error: 'POST only' });
      return;
    }

    let key = '';
    try {
      key = String(geminiApiKey.value() || '').trim();
    } catch (_) {}
    if (!key) key = String(process.env.GEMINI_API_KEY || '').trim();
    if (!key) {
      console.error('geminiProxy: GEMINI_API_KEY missing');
      res.set(geminiCors).status(503).json({
        error: { message: 'GEMINI_API_KEY tanımlı değil', status: 'FAILED_PRECONDITION' },
      });
      return;
    }

    let payload = req.body;
    if (!payload || typeof payload !== 'object') {
      try {
        const raw = req.rawBody ? req.rawBody.toString() : '';
        payload = raw ? JSON.parse(raw) : {};
      } catch (e) {
        res.set(geminiCors).status(400).json({
          error: { message: 'JSON gövde okunamadı', status: 'INVALID_ARGUMENT' },
        });
        return;
      }
    }

    const DEFAULT_MODEL = 'gemini-flash-latest';
    const FALLBACK_MODELS = [
      'gemini-flash-latest',
      'gemini-3.8-flash',
      'gemini-flash-lite-latest',
      'gemini-3.6-flash',
    ];
    const modelRaw = String(payload.model || req.query.model || DEFAULT_MODEL);
    const requested = modelRaw.replace(/[^a-zA-Z0-9._-]/g, '') || DEFAULT_MODEL;
    const contents = payload.contents;
    const generationConfig = payload.generationConfig;
    if (!contents) {
      res.set(geminiCors).status(400).json({
        error: { message: 'contents gerekli', status: 'INVALID_ARGUMENT' },
      });
      return;
    }

    const models = [];
    for (const m of [...FALLBACK_MODELS, requested]) {
      if (m && !models.includes(m)) models.push(m);
    }
    const googleBody = JSON.stringify({ contents, generationConfig });
    try {
      let lastStatus = 502;
      let lastText = '';
      for (const model of models) {
        const url =
          'https://generativelanguage.googleapis.com/v1beta/models/' +
          encodeURIComponent(model) +
          ':generateContent?key=' +
          encodeURIComponent(key);
        const ac = new AbortController();
        const timer = setTimeout(() => ac.abort(), 12000);
        let upstream;
        try {
          upstream = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: googleBody,
            signal: ac.signal,
          });
        } catch (e) {
          lastStatus = 504;
          lastText = JSON.stringify({
            error: { message: String(e && e.message ? e.message : e), status: 'UNAVAILABLE' },
          });
          continue;
        } finally {
          clearTimeout(timer);
        }
        const text = await upstream.text();
        lastStatus = upstream.status;
        lastText = text;
        if (upstream.ok) {
          res.set({ ...geminiCors, 'Content-Type': 'application/json; charset=utf-8' })
            .status(upstream.status)
            .send(text);
          return;
        }
        const lower = text.toLowerCase();
        const missingFn = lower.includes('requested function was not found');
        const model404 =
          !missingFn &&
          (upstream.status === 404 ||
            (lower.includes('not_found') &&
              (lower.includes('model') || lower.includes('gemini-'))));
        if (!model404 && upstream.status !== 429 && upstream.status !== 504) {
          res.set({ ...geminiCors, 'Content-Type': 'application/json; charset=utf-8' })
            .status(upstream.status)
            .send(text);
          return;
        }
      }
      res.set(geminiCors).status(503).json({
        error: {
          message: 'Analiz modeli şu an yanıt vermedi, tekrar deneyin.',
          status: 'UNAVAILABLE',
        },
      });
    } catch (e) {
      console.error('geminiProxy upstream', e);
      res.set(geminiCors).status(502).json({
        error: {
          message: String(e && e.message ? e.message : e),
          status: 'UNAVAILABLE',
        },
      });
    }
  },
);
