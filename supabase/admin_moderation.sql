-- Engelsiz Club — admin moderasyon (silme) yetkileri
-- Supabase Dashboard → SQL Editor → New query → bu dosyanın tamamını çalıştır
-- Admin: sakir.caykara@gmail.com
--
-- ÖNEMLİ: Sadece RLS policy yetmezse (silindi görünüp yenilemede geri geliyorsa)
-- aşağıdaki SECURITY DEFINER fonksiyonlar kesin çözüm sağlar.

-- ── RLS: admin silme politikaları ──────────────────────────────────────────

-- Sohbet: admin tüm mesajları görür / siler
drop policy if exists "sohbet_select_admin" on public.sohbet_mesajlari;
create policy "sohbet_select_admin"
  on public.sohbet_mesajlari for select
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "sohbet_delete_admin" on public.sohbet_mesajlari;
create policy "sohbet_delete_admin"
  on public.sohbet_mesajlari for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- İlanlar: admin herhangi bir ilanı silebilir
drop policy if exists "ilanlar_delete_admin" on public.ilanlar;
create policy "ilanlar_delete_admin"
  on public.ilanlar for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Forum gönderileri
drop policy if exists "forum_delete_admin" on public.forum_posts;
create policy "forum_delete_admin"
  on public.forum_posts for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Forum yorumları
drop policy if exists "forum_comments_delete_admin" on public.forum_comments;
create policy "forum_comments_delete_admin"
  on public.forum_comments for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- ── Kesin çözüm: admin RPC (RLS’yi bypass eder, e-posta kontrolü içeride) ──

create or replace function public.admin_delete_forum_post(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'not allowed';
  end if;
  delete from public.forum_posts where id = p_id;
end;
$$;

create or replace function public.admin_delete_forum_comment(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'not allowed';
  end if;
  delete from public.forum_comments where id = p_id;
end;
$$;

revoke all on function public.admin_delete_forum_post(bigint) from public;
revoke all on function public.admin_delete_forum_comment(bigint) from public;
grant execute on function public.admin_delete_forum_post(bigint) to authenticated;
grant execute on function public.admin_delete_forum_comment(bigint) to authenticated;

notify pgrst, 'reload schema';
