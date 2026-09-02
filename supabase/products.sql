-- Barkod / ürün içerik analizi önbelleği
-- Sütunlar: id (uuid PK), barcode (UNIQUE), product_name, ingredients,
--           image_url (public HTTPS — R2), safety_report (jsonb), created_at
-- Tıbbi teşhis değildir.
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın
-- https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
--
-- Fotoğraf / base64 bu tabloda YOKTUR. image_url yalnız public HTTPS (R2).
-- Akış: barkod → SELECT; tam kayıt (içindekiler veya dolu safety_report) → bitir.
-- Eksik (yalnız ad / boş içindekiler) → Open Food Facts → Gemini metin (foto zorunlu değil) → UPDATE.
-- Fotoğraf isteğe bağlı netleştirme. Ad-only satır “ürün bulunamadı” sayılmaz.
-- Gemini / R2 anahtarları burada tutulmaz.

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  barcode text not null,
  product_name text,
  ingredients text,
  safety_report jsonb not null default '{}'::jsonb,
  image_url text,
  source text not null default 'openfoodfacts',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint products_barcode_chk check (char_length(trim(barcode)) >= 4),
  constraint products_source_chk check (
    source in ('openfoodfacts', 'manual', 'cache', 'llm')
  )
);

-- Mevcut kurulum: image_url + source kısıtı
alter table public.products add column if not exists image_url text;
alter table public.products drop constraint if exists products_source_chk;
alter table public.products add constraint products_source_chk check (
  source in ('openfoodfacts', 'manual', 'cache', 'llm')
);

create unique index if not exists products_barcode_key
  on public.products (barcode);

-- Kullanıcı isteği: named INDEX (UNIQUE zaten indeks üretir; yine de açık indeks)
create index if not exists products_barcode_idx
  on public.products (barcode);

create index if not exists products_created_idx
  on public.products (created_at desc);

create or replace function public.products_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  new.barcode := trim(new.barcode);
  return new;
end;
$$;

drop trigger if exists products_touch_updated_at_tg on public.products;
create trigger products_touch_updated_at_tg
  before insert or update on public.products
  for each row execute function public.products_touch_updated_at();

alter table public.products enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant all on table public.products to postgres, service_role;
grant select on table public.products to anon, authenticated;
grant insert on table public.products to anon, authenticated;
grant update on table public.products to anon, authenticated;
grant update, delete on table public.products to authenticated;

-- Ürün gerçekleri herkese açık okunur (önbellek hit)
drop policy if exists "products_select_all" on public.products;
create policy "products_select_all"
  on public.products for select
  to anon, authenticated
  using (true);

-- Eksik barkodu bir kez yaz (cache). Rastgele UPDATE yok.
drop policy if exists "products_insert_cache" on public.products;
create policy "products_insert_cache"
  on public.products for insert
  to anon, authenticated
  with check (true);

-- Eksik satır (içindekiler boş / yer tutucu): Gemini metin ile doldur. Tam kayıt ezilmez.
drop policy if exists "products_update_enrich_incomplete" on public.products;
create policy "products_update_enrich_incomplete"
  on public.products for update
  to anon, authenticated
  using (
    coalesce(char_length(btrim(ingredients)), 0) < 4
    or btrim(ingredients) ~* '^(unknown|n/a|none|not available|içindekiler metni yok|içindekiler metni sınırlı|icerik bilgisi sınırlı|içerik bilgisi sınırlı)[. ;]*$'
  )
  with check (true);

-- Tam satır güncelleme / silme yalnız super admin
drop policy if exists "products_update_admin" on public.products;
create policy "products_update_admin"
  on public.products for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "products_delete_admin" on public.products;
create policy "products_delete_admin"
  on public.products for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Daha Fazlası menü satırı (tablo yoksa atlanır)
do $$
begin
  if to_regclass('public.daha_fazlasi_menu') is null then
    return;
  end if;

  insert into public.daha_fazlasi_menu (
    title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin
  )
  select
    'Barkod / Ürün Analizi',
    'İçerik, olası alerjenler ve katkı bilgisi (teşhis değildir)',
    'route',
    'barkod',
    'barcode',
    70,
    true,
    true
  where not exists (
    select 1 from public.daha_fazlasi_menu
    where lower(trim(link)) in ('barkod', '/barkod', 'route:barkod')
  );

  update public.daha_fazlasi_menu
  set
    title = 'Barkod / Ürün Analizi',
    subtitle = 'İçerik, olası alerjenler ve katkı bilgisi (teşhis değildir)',
    updated_at = now()
  where lower(trim(link)) in ('barkod', '/barkod', 'route:barkod');
end $$;

notify pgrst, 'reload schema';
