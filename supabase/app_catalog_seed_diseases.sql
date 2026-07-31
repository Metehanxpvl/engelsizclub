-- Ana sayfa hastalık kartları — sort_order seed / güncelleme
-- Supabase SQL Editor'da çalıştırın (mevcut satırları bozmaz: ON CONFLICT)

insert into public.app_diseases (
  id, name, icon, color, bg, photo, description, sort_order, active
) values
  ('otizm', 'Otizm Spektrum Bozukluğu', '🧩', 4284123609, 4293784572, 'assets/images/otizm.png', '', 0, true),
  ('serebral', 'Serebral Palsi', '🌟', 4281568586, 4293457390, 'assets/images/serebral_palsi.png', '', 1, true),
  ('down', 'Down Sendromu', '💛', 4294191154, 4294965485, 'assets/images/down_sendromu.png', '', 2, true),
  ('sma', 'SMA (Spinal Müsküler Atrofi)', '💪', 4286380781, 4294111487, 'assets/images/SMA_.png', '', 3, true),
  ('dehb', 'DEHB', '⚡', 4293326346, 4294964187, 'assets/images/DEHB.png', '', 4, true),
  ('gelisim', 'Gelişim Geriliği', '🌱', 4284122754, 4293193961, 'assets/images/geli_im_gerili_i.png', '', 5, true),
  ('duyu', 'Duyu Bütünleme Sorunları', '✋', 4288327091, 4294110971, 'assets/images/duyu_b_t_nleme_sorunlar_.png', '', 6, true),
  ('iletisim', 'İletişim Bozuklukları', '💬', 4292917855, 4294955244, 'assets/images/ileti_im_bozukluklar_.png', '', 7, true),
  ('nadir', 'Nadir Hastalıklar', '🔬', 4286380781, 4293783295, 'assets/images/nadir_hastal_klar.png', '', 8, true)
on conflict (id) do update set
  sort_order = excluded.sort_order,
  name = excluded.name,
  icon = excluded.icon,
  color = excluded.color,
  bg = excluded.bg,
  photo = excluded.photo,
  active = true,
  updated_at = now();

-- Katalog sürümünü artır — istemciler yeni sırayı çeksin
update public.app_catalog_versions
set version = version + 1, updated_at = now()
where name = 'diseases';
