-- Kendi yüklediği harita fotoğrafını sil
-- Dashboard → SQL Editor → çalıştırın (idempotent).

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

revoke all on function public.harita_foto_liste(text, text) from public;
grant execute on function public.harita_foto_liste(text, text) to anon, authenticated;

revoke all on function public.harita_foto_sil(bigint) from public;
grant execute on function public.harita_foto_sil(bigint) to authenticated;

notify pgrst, 'reload schema';
