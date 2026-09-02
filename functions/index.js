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

    const modelRaw = String(payload.model || req.query.model || 'gemini-3.6-flash');
    const model = modelRaw.replace(/[^a-zA-Z0-9._-]/g, '') || 'gemini-3.6-flash';
    const contents = payload.contents;
    const generationConfig = payload.generationConfig;
    if (!contents) {
      res.set(geminiCors).status(400).json({
        error: { message: 'contents gerekli', status: 'INVALID_ARGUMENT' },
      });
      return;
    }

    const url =
      'https://generativelanguage.googleapis.com/v1beta/models/' +
      encodeURIComponent(model) +
      ':generateContent?key=' +
      encodeURIComponent(key);

    try {
      const upstream = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents, generationConfig }),
      });
      const text = await upstream.text();
      res.set({ ...geminiCors, 'Content-Type': 'application/json; charset=utf-8' })
        .status(upstream.status)
        .send(text);
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
