-- MetoBot: eski 1.1.11 uygulamalar açılışta geçmiş görmesin.
-- Satırları silmez; yalnızca SELECT’i gizler.
-- Supabase Dashboard → SQL Editor → Run.
--
-- Neden: Eski APK loadLatestThread() ile
--   metobot_threads (latest) + metobot_messages SELECT eder.
-- Yeni web/istemci bunu atlıyor; mağaza sürümü gerekmez.
--
-- INSERT / UPDATE kullanıcı JWT ile çalışmaya devam eder
-- (Edge Function mesaj/thread yazar).
-- Gemini bağlamı istemcinin POST body’sindeki lastN mesajlardan gelir.
-- Günlük kota + thread sahipliği okuması için Edge Function
-- service role kullanmalı (yalnız o kullanıcının satırları).
--
-- metobot.sql tekrar çalıştırılırsa eski SELECT politikaları geri gelir;
-- o zaman bu dosyayı yeniden çalıştırın.

-- İstemci SELECT: 0 satır (izin hatası yok, boş sonuç).
drop policy if exists "metobot_threads_select_own" on public.metobot_threads;
drop policy if exists "metobot_threads_select_hidden" on public.metobot_threads;
create policy "metobot_threads_select_hidden"
  on public.metobot_threads for select
  to authenticated
  using (false);

drop policy if exists "metobot_messages_select_own" on public.metobot_messages;
drop policy if exists "metobot_messages_select_hidden" on public.metobot_messages;
create policy "metobot_messages_select_hidden"
  on public.metobot_messages for select
  to authenticated
  using (false);

-- Mesaj INSERT politikasındaki EXISTS, thread SELECT RLS’ine takılmasın.
create or replace function public.metobot_user_owns_thread(p_thread_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.metobot_threads t
    where t.id = p_thread_id
      and t.user_id = auth.uid()
  );
$$;

revoke all on function public.metobot_user_owns_thread(uuid) from public;
grant execute on function public.metobot_user_owns_thread(uuid) to authenticated;

drop policy if exists "metobot_messages_insert_own" on public.metobot_messages;
create policy "metobot_messages_insert_own"
  on public.metobot_messages for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.metobot_user_owns_thread(thread_id)
  );

-- Thread INSERT / UPDATE aynı kalır (kullanıcı JWT).
drop policy if exists "metobot_threads_insert_own" on public.metobot_threads;
create policy "metobot_threads_insert_own"
  on public.metobot_threads for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "metobot_threads_update_own" on public.metobot_threads;
create policy "metobot_threads_update_own"
  on public.metobot_threads for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update on table public.metobot_threads to authenticated;
grant select, insert on table public.metobot_messages to authenticated;

notify pgrst, 'reload schema';
