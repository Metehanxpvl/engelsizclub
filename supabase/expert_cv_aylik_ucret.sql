-- Uzman Profilleri Köşesi: ilk 2 ay ücretsiz, sonra her ay 3/5 puan.
-- Bakiye yoksa ilan expired olur (yayından kalkar) + bildirim.
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

create or replace function public.uzman_kosesi_aylik_ucret()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_fee int;
  v_paid int;
  v_charged int := 0;
  v_expired int := 0;
  v_email text;
  v_title text;
  v_body text;
begin
  for r in
    select *
    from public.expert_profiles
    where status = 'published'
      and ucret_bitis is not null
      and ucret_bitis <= now()
    for update skip locked
  loop
    v_email := lower(trim(coalesce(r.owner_email, '')));
    if v_email = 'sakir.caykara@gmail.com' then
      update public.expert_profiles
        set ucret_bitis = now() + interval '30 days',
            updated_at = now()
      where id = r.id;
      continue;
    end if;

    v_fee := case when coalesce(r.kart_span, 1) >= 2 then 5 else 3 end;

    update public.user_profiles
      set kredi = kredi - v_fee,
          updated_at = now()
    where owner_id = r.owner_id
      and coalesce(kredi, 0) >= v_fee;
    get diagnostics v_paid = row_count;

    if v_paid > 0 then
      update public.expert_profiles
        set ucret_bitis = now() + interval '30 days',
            odenen_puan = coalesce(odenen_puan, 0) + v_fee,
            updated_at = now()
      where id = r.id;
      v_charged := v_charged + 1;
    else
      update public.expert_profiles
        set status = 'expired',
            reject_reason = 'Bakiyeniz yetersiz olduğu için ilanınız yayından kaldırıldı.',
            updated_at = now()
      where id = r.id
        and status = 'published';
      v_expired := v_expired + 1;
      v_title := 'İlanınız yayından kalktı';
      v_body := 'Bakiyeniz yetersiz olduğu için Uzman Profilleri Köşesi ilanınız yayından kaldırıldı. Puan yükleyip tekrar yayınlayın; aksi halde ilanınız yayında kalmaz.';
      if v_email <> '' then
        begin
          insert into public.bildirimler (
            owner_email, actor_email, actor_name, type, title, body, read
          ) values (
            v_email, 'sistem@engelsizclub.com', 'Engelsiz Club',
            'duyuru', v_title, v_body, false
          );
        exception when others then
          null;
        end;
      end if;
    end if;
  end loop;

  return jsonb_build_object('charged', v_charged, 'expired', v_expired);
end;
$$;

grant execute on function public.uzman_kosesi_aylik_ucret()
  to anon, authenticated;

notify pgrst, 'reload schema';
