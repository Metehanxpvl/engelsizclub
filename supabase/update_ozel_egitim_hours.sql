-- Ücretsiz özel eğitim: haftalık 8 → aylık 8 bireysel + 4 grup (toplam 12)
-- Supabase SQL Editor'da bir kez çalıştırın.

update public.app_rights
set
  amount = 'Aylık 12 saat (8+4)',
  description = 'MEB''e bağlı özel eğitim ve rehabilitasyon merkezlerinde aylık 8 saat bireysel + 4 saat grup eğitimi (toplam 12 saat) ücretsiz hizmet. RAM raporu zorunludur.'
where id = 'ozel-egitim';
