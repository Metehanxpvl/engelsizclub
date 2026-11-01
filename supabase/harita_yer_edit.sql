-- Yer bildirimi sahibi: düzenle / sil
-- Dashboard → SQL Editor → çalıştırın (idempotent).
-- Ana dosya: harita_yer_bildirimleri.sql

grant select, update, delete on table public.harita_yer_bildirimleri to authenticated;
grant select on table public.harita_yer_bildirimleri to anon;

drop policy if exists "harita_yer_update_own" on public.harita_yer_bildirimleri;
create policy "harita_yer_update_own"
  on public.harita_yer_bildirimleri for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "harita_yer_delete_own" on public.harita_yer_bildirimleri;
create policy "harita_yer_delete_own"
  on public.harita_yer_bildirimleri for delete
  to authenticated
  using (user_id = auth.uid());

create or replace function public.harita_yer_guncelle(
  p_id bigint,
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_note text := btrim(coalesce(p_note, ''));
  v_id bigint;
begin
  if v_user is null then
    raise exception 'Yer bildirimini değiştirmek için giriş yapın.';
  end if;
  if p_id is null or p_id <= 0 then
    raise exception 'Geçersiz yer bildirimi.';
  end if;

  update public.harita_yer_bildirimleri
  set note = v_note
  where id = p_id
    and user_id = v_user
  returning id into v_id;

  if v_id is null then
    raise exception 'Bu bildirimi değiştirme yetkiniz yok.';
  end if;

  return jsonb_build_object('id', v_id, 'note', v_note);
end;
$$;

create or replace function public.harita_yer_sil(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_id bigint;
begin
  if v_user is null then
    raise exception 'Yer bildirimini silmek için giriş yapın.';
  end if;
  if p_id is null or p_id <= 0 then
    raise exception 'Geçersiz yer bildirimi.';
  end if;

  delete from public.harita_yer_bildirimleri
  where id = p_id
    and user_id = v_user
  returning id into v_id;

  if v_id is null then
    raise exception 'Bu bildirimi silme yetkiniz yok.';
  end if;

  return jsonb_build_object('id', v_id);
end;
$$;

revoke all on function public.harita_yer_guncelle(bigint, text) from public;
grant execute on function public.harita_yer_guncelle(bigint, text) to authenticated;

revoke all on function public.harita_yer_sil(bigint) from public;
grant execute on function public.harita_yer_sil(bigint) to authenticated;

notify pgrst, 'reload schema';
