-- Tüm aile rolü üyelerinin iyilik puanı = 1
-- Tablo zaten var, RLS zaten açık. Bu dosya tablo OLUŞTURMAZ.
-- Uyarı penceresi çıkarsa: "Run without RLS" (turuncu) seçin.
-- Admin (sakir.caykara@gmail.com) dokunulmaz
-- Supabase Dashboard → SQL Editor → Run (tek seferlik)

update public.user_profiles up
set
  kredi = 1,
  kredi_welcome_gift = true,
  updated_at = now()
from auth.users au
where up.owner_id = au.id
  and lower(trim(coalesce(au.email, ''))) <> 'sakir.caykara@gmail.com'
  and lower(
    coalesce(nullif(trim(au.raw_user_meta_data ->> 'user_type'), ''), 'aile')
  ) = 'aile';

select count(*)::int as aile_kredi_1
from public.user_profiles up
join auth.users au on au.id = up.owner_id
where up.kredi = 1
  and lower(trim(coalesce(au.email, ''))) <> 'sakir.caykara@gmail.com'
  and lower(
    coalesce(nullif(trim(au.raw_user_meta_data ->> 'user_type'), ''), 'aile')
  ) = 'aile';
