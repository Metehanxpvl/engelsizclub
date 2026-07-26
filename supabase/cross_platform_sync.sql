-- Engelsiz Club — teklif veren kendi gönderdiği bildirimleri görebilsin
-- (cihazlar arası "bu ilana teklif verdim" senkronu)

drop policy if exists "bildirim_select_actor" on public.bildirimler;
create policy "bildirim_select_actor"
  on public.bildirimler for select
  to authenticated
  using (
    lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Realtime: inbox / sohbet anlık güncellensin
do $$
begin
  alter publication supabase_realtime add table public.bildirimler;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.forum_posts;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.forum_comments;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

notify pgrst, 'reload schema';
