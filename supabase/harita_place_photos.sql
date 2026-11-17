-- Engelsiz Harita fotoğrafları — yalnızca URL metadata (BLOB/base64 YOK).
-- Dosyalar Cloudflare R2’de; istemci Worker /sign presigned PUT ile doğrudan yükler.
-- Ana API / Supabase Edge Function dosya trafiği taşımaz.
-- Dashboard → SQL Editor → çalıştırın (idempotent).
-- Dart: lib/harita_foto_store.dart  Worker: POST /sign { purpose: "map-photo" }

create table if not exists public.accessible_places (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'map',
  source_key text not null,
  name text not null default '',
  city text not null default '',
  category text not null default '',
  lat double precision not null default 0,
  lng double precision not null default 0,
  created_at timestamptz not null default now(),
  unique (source, source_key)
);

create index if not exists accessible_places_city_idx
  on public.accessible_places (city);

create table if not exists public.place_photos (
  id bigint generated always as identity primary key,
  place_id uuid not null references public.accessible_places (id) on delete cascade,
  owner_id uuid references auth.users (id) on delete set null,
  owner_email text not null default '',
  photo_url text not null,
  thumbnail_url text not null default '',
  alt_text text not null default '',
  object_key text not null default '',
  bytes_est int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists place_photos_place_idx
  on public.place_photos (place_id, created_at desc);

create index if not exists place_photos_owner_idx
  on public.place_photos (owner_id, created_at desc);

alter table public.accessible_places enable row level security;
alter table public.place_photos enable row level security;

drop policy if exists "accessible_places_select" on public.accessible_places;
create policy "accessible_places_select"
  on public.accessible_places for select
  to anon, authenticated
  using (true);

drop policy if exists "place_photos_select" on public.place_photos;
create policy "place_photos_select"
  on public.place_photos for select
  to anon, authenticated
  using (true);

grant select on public.accessible_places to anon, authenticated;
grant select on public.place_photos to anon, authenticated;

create or replace function public._harita_foto_url_ok(p text)
returns boolean
language sql
immutable
as $$
  select
    coalesce(p, '') ~ '^https://'
    and char_length(p) between 16 and 500
    and position(' ' in p) = 0
    and position('..' in p) = 0
    and p ~* '(r2\.dev|r2\.cloudflarestorage\.com|engelsizclub\.com)';
$$;

drop function if exists public.harita_foto_liste(text, text);

create or replace function public.harita_foto_liste(
  p_source text,
  p_source_key text
)
returns table (
  id bigint,
  photo_url text,
  thumbnail_url text,
  alt_text text,
  created_at timestamptz,
  is_mine boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_place uuid;
  v_user uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  select ap.id into v_place
  from public.accessible_places ap
  where ap.source = coalesce(nullif(trim(p_source), ''), 'map')
    and ap.source_key = trim(p_source_key)
  limit 1;

  if v_place is null then
    return;
  end if;

  return query
  select
    ph.id,
    ph.photo_url,
    ph.thumbnail_url,
    ph.alt_text,
    ph.created_at,
    (
      (v_user is not null and ph.owner_id = v_user)
      or (v_email <> '' and lower(ph.owner_email) = v_email)
    ) as is_mine
  from public.place_photos ph
  where ph.place_id = v_place
  order by ph.created_at desc
  limit 24;
end;
$$;

create or replace function public.harita_foto_onayla(
  p_source text,
  p_source_key text,
  p_name text,
  p_city text,
  p_category text,
  p_lat double precision,
  p_lng double precision,
  p_photo_url text,
  p_thumbnail_url text default '',
  p_alt_text text default '',
  p_object_key text default '',
  p_bytes_est int default 0
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_source text := coalesce(nullif(trim(p_source), ''), 'map');
  v_key text := trim(coalesce(p_source_key, ''));
  v_photo text := trim(coalesce(p_photo_url, ''));
  v_thumb text := trim(coalesce(p_thumbnail_url, ''));
  v_obj text := trim(coalesce(p_object_key, ''));
  v_place uuid;
  v_count int;
  v_today int;
  v_id bigint;
begin
  if v_user is null then
    raise exception 'Fotoğraf yüklemek için giriş yapın.';
  end if;
  if char_length(v_key) < 4 then
    raise exception 'Mekan bilgisi eksik.';
  end if;
  if not public._harita_foto_url_ok(v_photo) then
    raise exception 'Geçersiz fotoğraf URL’si.';
  end if;
  if v_thumb <> '' and not public._harita_foto_url_ok(v_thumb) then
    raise exception 'Geçersiz küçük görsel URL’si.';
  end if;
  if v_thumb = '' then
    v_thumb := v_photo;
  end if;
  if v_obj <> '' and left(v_obj, 11) <> 'map-photos/' then
    raise exception 'Geçersiz depolama anahtarı.';
  end if;

  select count(*)::int into v_today
  from public.place_photos
  where owner_id = v_user
    and created_at > now() - interval '1 day';
  if v_today >= 12 then
    raise exception 'Günlük fotoğraf sınırına ulaştınız (12).';
  end if;

  insert into public.accessible_places (
    source, source_key, name, city, category, lat, lng
  ) values (
    v_source,
    v_key,
    left(btrim(coalesce(p_name, '')), 160),
    left(btrim(coalesce(p_city, '')), 80),
    left(btrim(coalesce(p_category, '')), 40),
    coalesce(p_lat, 0),
    coalesce(p_lng, 0)
  )
  on conflict (source, source_key) do update
    set name = excluded.name,
        city = excluded.city,
        category = excluded.category
  returning id into v_place;

  select count(*)::int into v_count
  from public.place_photos
  where place_id = v_place;
  if v_count >= 8 then
    raise exception 'Bu mekanda en fazla 8 fotoğraf olabilir.';
  end if;

  insert into public.place_photos (
    place_id, owner_id, owner_email,
    photo_url, thumbnail_url, alt_text, object_key, bytes_est
  ) values (
    v_place,
    v_user,
    v_email,
    v_photo,
    v_thumb,
    left(btrim(coalesce(p_alt_text, '')), 160),
    left(v_obj, 200),
    least(greatest(coalesce(p_bytes_est, 0), 0), 2000000)
  )
  returning id into v_id;

  return json_build_object(
    'id', v_id,
    'place_id', v_place,
    'photo_url', v_photo,
    'thumbnail_url', v_thumb
  );
end;
$$;

drop policy if exists "place_photos_delete_own" on public.place_photos;
create policy "place_photos_delete_own"
  on public.place_photos for delete
  to authenticated
  using (
    owner_id = auth.uid()
    or (
      owner_email <> ''
      and lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    )
  );

grant select, delete on public.place_photos to authenticated;

create or replace function public.harita_foto_sil(p_id bigint)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_id bigint;
begin
  if v_user is null then
    raise exception 'Fotoğraf silmek için giriş yapın.';
  end if;
  if p_id is null or p_id <= 0 then
    raise exception 'Geçersiz fotoğraf.';
  end if;

  delete from public.place_photos
  where id = p_id
    and (
      owner_id = v_user
      or (owner_email <> '' and lower(owner_email) = v_email)
    )
  returning id into v_id;

  if v_id is null then
    raise exception 'Bu fotoğrafı silme yetkiniz yok.';
  end if;

  return json_build_object('id', v_id);
end;
$$;

revoke all on function public._harita_foto_url_ok(text) from public;
revoke all on function public.harita_foto_sil(bigint) from public;
grant execute on function public.harita_foto_sil(bigint) to authenticated;
revoke all on function public.harita_foto_onayla(text, text, text, text, text, double precision, double precision, text, text, text, text, int) from public;

grant execute on function public.harita_foto_liste(text, text) to anon, authenticated;
grant execute on function public.harita_foto_onayla(text, text, text, text, text, double precision, double precision, text, text, text, text, int) to authenticated;

notify pgrst, 'reload schema';
