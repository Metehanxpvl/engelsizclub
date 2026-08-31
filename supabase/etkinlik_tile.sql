-- Ana sayfa kutucuğu: tile_key = etkinlik
-- (etkinlikler.sql bunu da içerir — yalnız kapak satırı eksikse bunu çalıştırın)
-- Dashboard SQL Editor → çalıştırın (additive)
-- Önkoşul: gezi_kampanya_tiles.sql (tablo mevcut)
-- Dart: gezi_kampanya_store kEtkinlikTileKey = 'etkinlik'

alter table public.gezi_kampanya_tiles
  drop constraint if exists gezi_kampanya_tiles_key_chk;

alter table public.gezi_kampanya_tiles
  add constraint gezi_kampanya_tiles_key_chk
    check (tile_key in ('gezi', 'kampanya', 'etkinlik'));

insert into public.gezi_kampanya_tiles (tile_key, image_url)
values ('etkinlik', '')
on conflict (tile_key) do nothing;

notify pgrst, 'reload schema';
