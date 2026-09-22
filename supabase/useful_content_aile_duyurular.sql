-- ASHB bakanlık duyurular + Aile Çocuk Dergisi → public.content_sources
-- SQL Editor → Run, sonra Actions → Useful content collector → Run workflow (main).
-- 900 satırlık seed’i yeniden çalıştırmayın. İçerik silinmez. Ana sayfa kapalı kalır.

insert into public.content_sources (name, url, method, is_active, fetch_interval_hours, notes)
select * from (values
  (
    'ASHB duyurular',
    'https://www.aile.gov.tr/duyurular',
    'scrape',
    true,
    24,
    'Bakanlık https://aile.gov.tr/duyurular HTML kartları. RSS yok. Engelli süzgeci + 15 gün.'
  ),
  (
    'ASHB Aile Çocuk Dergisi',
    'https://ailecocuk.aile.gov.tr/dergimiz?lang=tr',
    'scrape',
    true,
    24,
    'https://ailecocuk.aile.gov.tr/dergimiz?lang=tr PDF sayıları. Dar parser Sayı N tutar.'
  )
) as v(name, url, method, is_active, fetch_interval_hours, notes)
where not exists (
  select 1 from public.content_sources s where s.url = v.url
);

update public.content_sources
set
  is_active = true,
  method = 'scrape',
  fetch_interval_hours = 24,
  name = case
    when url ilike '%dergimiz%' then 'ASHB Aile Çocuk Dergisi'
    else 'ASHB duyurular'
  end,
  notes = case
    when url ilike '%dergimiz%' then 'https://ailecocuk.aile.gov.tr/dergimiz?lang=tr PDF sayıları. Dar parser Sayı N tutar.'
    else 'Bakanlık https://aile.gov.tr/duyurular HTML kartları. RSS yok. Engelli süzgeci + 15 gün.'
  end,
  updated_at = now()
where url in (
  'https://www.aile.gov.tr/duyurular',
  'https://www.aile.gov.tr/duyurular/',
  'https://aile.gov.tr/duyurular',
  'https://aile.gov.tr/duyurular/',
  'https://ailecocuk.aile.gov.tr/dergimiz?lang=tr',
  'https://ailecocuk.aile.gov.tr/dergimiz'
);
