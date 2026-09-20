-- Kampanya firma / şirket sitesi
-- Dart: KampanyaItem.companyUrl / normalizeKampanyaCompanyUrl

alter table public.kampanyalar
  add column if not exists company_url text not null default '';

notify pgrst, 'reload schema';
