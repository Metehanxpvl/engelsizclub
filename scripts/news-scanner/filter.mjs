export function stripHtml(raw) {
  const text = String(raw ?? '');
  if (!text) return '';
  return text
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&#(\d+);/g, (_, n) => {
      const code = Number(n);
      return Number.isFinite(code) ? String.fromCharCode(code) : ' ';
    })
    .replace(/\s+/g, ' ')
    .trim();
}

export function foldTr(text) {
  return String(text ?? '')
    .toLowerCase()
    .replace(/\u0130/g, 'i')
    .replace(/\u0307/g, '')
    .replace(/ı/g, 'i')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ş/g, 's')
    .replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
    .replace(/â/g, 'a')
    .replace(/î/g, 'i')
    .replace(/û/g, 'u')
    .replace(/[''`´’]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

const STRONG = [
  'engelli',
  'engelsiz',
  'engellilik',
  'ozel gereksinim',
  'ozel egitim',
  'serebral palsi',
  'otizm',
  'down sendrom',
  'gorme engel',
  'isitme engel',
  'ortopedik engel',
  'zihinsel engel',
  'bedensel engel',
  'engelli cocuk',
  'engelli birey',
  'engelli vatandas',
  'erisilebilir',
  'engelli hak',
  'engelli aylik',
  'engelli maas',
  'evde bakim',
  'bakim yardimi',
  'bakim ayligi',
  'otv',
  'otvsiz',
  'ekpss',
  'rehabilitasyon',
  'fizyoterapi',
  'ortez',
  'protez',
  'tekerlekli sandalye',
  'akulu sandalye',
  'medikal cihaz',
  'cozger',
  'kaynastirma',
  'isaret dili',
  'paralimpik',
];

const SOFT = [
  'sosyal yardim',
  'kamu destegi',
  'sosyal destek',
  'hibe',
  'burs',
  'istihdam',
  'is destegi',
  'ucretsiz ulasim',
  'bakim merkezi',
  'ozel egitim',
];

const SOFT_CONTEXT = [
  'vatandas',
  'aile',
  'cocuk',
  'hasta',
  'muafiyet',
  'duzenleme',
  'kanun',
  'mevzuat',
  'sgk',
  'belediye',
  'bakanlik',
];

const HARD_DROP = [
  'magazin',
  'unlu',
  'dizi final',
  'mac sonucu',
  'spor toto',
  'hava durumu',
  'burc yorum',
  'ilan: satilik',
];

export function haystack(item) {
  return foldTr(`${item.title || ''} ${item.summary || ''}`);
}

export function passesKeywordFilter(item) {
  const hay = haystack(item);
  if (!hay) return false;
  if (HARD_DROP.some((k) => hay.includes(k))) return false;
  if (STRONG.some((k) => hay.includes(k))) return true;
  if (SOFT.some((k) => hay.includes(k)) && SOFT_CONTEXT.some((k) => hay.includes(k))) {
    return true;
  }
  return false;
}
