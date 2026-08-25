-- Engelsiz Club — Keşfet admin RPC
-- Yalnızca sakir.caykara@gmail.com (JWT e-posta)
-- Tablo RLS de aynı e-postayı kontrol eder; RPC liste/durum için ek yol.

create or replace function public.admin_kesfet_set_status(
  p_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'Yalnızca admin Keşfet içeriğini yönetebilir';
  end if;
  if p_status not in ('pending', 'approved', 'rejected', 'hidden') then
    raise exception 'Geçersiz durum';
  end if;
  update public.kesfet_videos
    set status = p_status,
        published_at = case
          when p_status = 'approved' then coalesce(published_at, now())
          else published_at
        end
    where id = p_id;
  if not found then
    raise exception 'Video bulunamadı';
  end if;
end;
$$;

create or replace function public.admin_kesfet_list_reports(p_limit int default 80)
returns table (
  id bigint,
  video_id uuid,
  video_title text,
  youtube_url text,
  reason text,
  owner_email text,
  status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'Yalnızca admin raporları görebilir';
  end if;
  return query
  select
    r.id,
    r.video_id,
    coalesce(v.title, '')::text,
    coalesce(v.youtube_url, '')::text,
    r.reason,
    r.owner_email,
    r.status,
    r.created_at
  from public.kesfet_reports r
  left join public.kesfet_videos v on v.id = r.video_id
  order by r.created_at desc
  limit greatest(1, least(coalesce(p_limit, 80), 200));
end;
$$;

revoke all on function public.admin_kesfet_set_status(uuid, text) from public;
revoke all on function public.admin_kesfet_list_reports(int) from public;
grant execute on function public.admin_kesfet_set_status(uuid, text) to authenticated;
grant execute on function public.admin_kesfet_list_reports(int) to authenticated;

notify pgrst, 'reload schema';
