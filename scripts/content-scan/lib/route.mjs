const SUB_TO_USEFUL = {
  burs: 'burs',
  hibe: 'firsat',
  istihdam: 'istihdam',
  egitim: 'egitim',
  saglik: 'destek',
  mevzuat: 'hak',
  etkinlik: 'firsat',
  tedavi: 'destek',
  cihaz: 'destek',
};

const NEWS_CATEGORY = {
  haber: 'Haber',
  firsat: 'Fırsat',
  destek: 'Destek',
  bilim: 'Bilim',
  burs: 'Burs',
  hibe: 'Hibe',
  istihdam: 'İstihdam',
  egitim: 'Eğitim',
  saglik: 'Sağlık',
  mevzuat: 'Mevzuat',
  etkinlik: 'Etkinlik',
  tedavi: 'Sağlık',
  cihaz: 'Cihaz',
};

export function heuristicCategory(item) {
  const hay = `${item.title || ''} ${item.raw_snippet || ''} ${item.summary || ''}`.toLowerCase();
  if (item.group === 'science' || item.kind === 'science') return 'bilim';
  if (/(burs|hibe|başvuru|basvuru|son tarih|deadline)/i.test(hay)) return 'firsat';
  if (/(maaş|maas|aylık|aylik|yardım|yardim|mevzuat|hakk|ötv|otv|bakım|bakim)/i.test(hay)) {
    return 'destek';
  }
  return 'haber';
}

export function routeRecord(item) {
  const category = String(item.category || heuristicCategory(item)).toLowerCase();
  const sub = String(item.subcategory || '').toLowerCase();
  if (category === 'bilim') {
    return { table: 'scientific_researches', category: 'bilim', usefulCategory: null };
  }
  if (category === 'firsat' || ['burs', 'hibe', 'istihdam', 'egitim', 'etkinlik'].includes(sub)) {
    return {
      table: 'useful_content',
      category: 'firsat',
      usefulCategory: SUB_TO_USEFUL[sub] || 'firsat',
    };
  }
  if (category === 'destek' || ['mevzuat', 'saglik', 'tedavi', 'cihaz'].includes(sub)) {
    return {
      table: 'useful_content',
      category: 'destek',
      usefulCategory: SUB_TO_USEFUL[sub] || (sub === 'mevzuat' ? 'hak' : 'destek'),
    };
  }
  return { table: 'news_candidates', category: 'haber', usefulCategory: null };
}

export function newsCategoryLabel(item) {
  const key = String(item.subcategory || item.category || 'haber').toLowerCase();
  return NEWS_CATEGORY[key] || 'Diğer';
}

export function usefulRowCategory(item, routed) {
  return routed.usefulCategory || 'diger';
}
