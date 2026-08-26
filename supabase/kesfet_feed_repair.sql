-- Engelsiz Club — Keşfet akışı teşhis + onarım
-- Supabase SQL Editor'de tek parça çalıştırın. Tekrar çalıştırmak güvenlidir.
--
-- Ne zaman kullanılır: Keşfet açılıyor ama aşağı/yukarı kaydırma yapılamıyor.
-- Uygulama akışı bir PageView'dir; ekranda tek video varsa kaydırılacak
-- sayfa olmaz ve kaydırma "çalışmıyor" gibi görünür. Bu dosya akışın kaç
-- videoyla açıldığını gösterir ve seed videolarını onaylı duruma çeker.
--
-- Sıra (tablolar hiç kurulmadıysa önce bunlar):
--   kesfet_schema.sql → kesfet_scoring.sql → kesfet_seed.sql → kesfet_admin.sql
--   → kesfet_seed_videos.sql → kesfet_seed_videos_batch2.sql → bu dosya

-- ── 1) Teşhis: akış kaç videoyla açılıyor ───────────────────────────
select
  count(*) as toplam_video,
  count(*) filter (where status = 'approved') as onayli,
  count(*) filter (where status = 'pending') as bekleyen,
  count(*) filter (where status = 'rejected') as reddedilen,
  count(*) filter (where status = 'hidden') as gizli,
  count(*) filter (
    where status = 'approved' and coalesce(youtube_video_id, '') <> ''
  ) as akista_gorunen
from public.kesfet_videos;

-- Uygulama `status = 'approved'` + `youtube_video_id` dolu satırları alır ve
-- en fazla 80 tanesini gösterir. `akista_gorunen` 0 ise "Henüz onaylanmış
-- video yok" ekranı gelir; 1 ise video açılır ama kaydırma yapılamaz.

-- ── 2) Onarım: seed videolarını onayla ──────────────────────────────
-- Yalnızca depodaki seed dosyalarından gelen satırlara dokunur
-- (crawl_source = 'seed'). Admin panelinden elle eklenen bekleyen
-- içerik moderasyonda kalsın diye kapsam dışıdır.
update public.kesfet_videos
set status = 'approved',
    published_at = coalesce(published_at, now())
where crawl_source = 'seed'
  and status in ('pending', 'hidden')
  and coalesce(youtube_video_id, '') <> '';

-- Onaylı ama published_at boş satırlar: sıralama (published_at desc)
-- bozulmasın diye doldurulur.
update public.kesfet_videos
set published_at = coalesce(created_at, now())
where status = 'approved'
  and published_at is null;

-- Videosu olmayan satır akışta boş sayfa açar; akış dışına alınır.
update public.kesfet_videos
set status = 'rejected'
where status = 'approved'
  and coalesce(youtube_video_id, '') = '';

-- ── 3) Doğrulama: uygulamanın attığı sorgunun aynısı ────────────────
-- kesfet_store.dart -> fetchApproved(): status = 'approved',
-- order by published_at desc, limit 80.
select count(*) as uygulamaya_donen_satir
from (
  select id
  from public.kesfet_videos
  where status = 'approved'
    and coalesce(youtube_video_id, '') <> ''
  order by published_at desc
  limit 80
) q;

-- 2 veya daha fazlaysa kaydırma için yeterli sayfa vardır.
-- 0 / 1 çıkıyorsa seed dosyaları hiç çalıştırılmamıştır:
--   kesfet_seed_videos.sql ve kesfet_seed_videos_batch2.sql (toplam 1000 video)

select
  category,
  count(*) as onayli_video
from public.kesfet_videos
where status = 'approved'
group by category
order by onayli_video desc;

notify pgrst, 'reload schema';
