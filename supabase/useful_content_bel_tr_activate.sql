-- Kısa UPSERT: mevcut .bel.tr ana sayfa kaynaklarını scrape + aktif yap.
-- 900 satırlık seed’i yeniden çalıştırmayın. İçerik silinmez.
-- SQL Editor → Run, sonra Actions → Useful content collector → Run workflow (main).
-- Collector yalnız content_sources.url kullanır; rastgele web araması yok.

update public.content_sources
set
  is_active = true,
  method = 'scrape',
  fetch_interval_hours = 24,
  notes = 'Faz 2: site tarama (haberler/duyurular/ilanlar/sosyal). Admin onay; yayın yok.',
  updated_at = now()
where method = 'scrape'
  and (
    url ~* '\.bel\.tr([/?#]|$)'
    or url ~* 'ibb\.istanbul'
  )
  and url !~* 'tbb\.gov\.tr';

-- Bursa genel haber RSS kapalı kalsın (aynı filtreyle scrape etmek isterseniz
-- ayrı bir https://www.bursa.bel.tr scrape satırı gerekir; RSS’i açmayın).
update public.content_sources
set
  is_active = false,
  updated_at = now()
where url ilike '%bursa.bel.tr%rss%';
