-- Çift kilit ekranı bildirimi: uygulama zaten FCM yolluyor,
-- bu tetikleyiciler aynı haberi / mesajı ikinci kez gönderiyordu.
-- SQL Editor → Run. forum yorum/beğeni tetikleyicilerine dokunmaz.

drop trigger if exists sohbet_mesajlari_fcm on public.sohbet_mesajlari;
drop trigger if exists duyurular_fcm on public.duyurular;
drop trigger if exists ilanlar_fcm on public.ilanlar;
drop trigger if exists forum_posts_fcm on public.forum_posts;
