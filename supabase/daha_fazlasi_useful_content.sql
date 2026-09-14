-- Fırsatlar ve Destekler Daha Fazlası menüsünden çıksın (admin profilde).
-- SQL Editor → Run.

update public.daha_fazlasi_menu
set is_active = false,
    updated_at = now()
where lower(trim(link)) in (
    'firsatlar',
    '/firsatlar',
    'route:firsatlar',
    'useful_content',
    'useful_opportunities'
  )
  or lower(trim(title)) = 'fırsatlar ve destekler';

notify pgrst, 'reload schema';
