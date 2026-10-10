-- Aynı şehirde farklı harita pinleri "zaten bildirdiniz" olmasın.
-- Eski kural: (kullanıcı, ad, il) — isimsiz pinler çakışıyordu.
-- Yeni kural: konum (lat/lng 4 hane) de dahil.
-- Dashboard → SQL Editor → çalıştır.

drop index if exists public.harita_yer_bildirimleri_user_yer_idx;
alter table public.harita_yer_bildirimleri
  drop constraint if exists harita_yer_bildirimleri_user_id_name_norm_city_norm_key;

create unique index if not exists harita_yer_bildirimleri_user_yer_idx
  on public.harita_yer_bildirimleri (
    user_id,
    name_norm,
    city_norm,
    (round(lat::numeric, 4)),
    (round(lng::numeric, 4))
  );

notify pgrst, 'reload schema';
