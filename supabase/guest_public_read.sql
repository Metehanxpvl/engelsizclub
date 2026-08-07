-- Misafir (anon) kullanıcılar: ilan / forum sadece okuma
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın
-- Yazma (insert/update/delete) authenticated ile kalır.

-- İlanlar
drop policy if exists "ilanlar_select_anon" on public.ilanlar;
create policy "ilanlar_select_anon"
  on public.ilanlar for select
  to anon
  using (true);

-- Forum gönderileri
drop policy if exists "forum_select_anon" on public.forum_posts;
create policy "forum_select_anon"
  on public.forum_posts for select
  to anon
  using (true);

-- Forum yorumları
drop policy if exists "forum_comments_select_anon" on public.forum_comments;
create policy "forum_comments_select_anon"
  on public.forum_comments for select
  to anon
  using (true);

-- Duyurular / kayan story (yalnız aktif)
drop policy if exists "duyuru_select_anon" on public.duyurular;
create policy "duyuru_select_anon"
  on public.duyurular for select
  to anon
  using (is_active = true);

-- Profil fotoğrafları (avatar) — fonksiyon yoksa atlanır
do $$
begin
  grant execute on function public.get_user_photos(text[]) to anon;
exception
  when undefined_function then null;
end $$;

notify pgrst, 'reload schema';
