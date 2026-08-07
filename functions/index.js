const { onRequest } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');

setGlobalOptions({ region: 'europe-west1', maxInstances: 20 });

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
