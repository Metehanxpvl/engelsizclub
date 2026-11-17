-- Görünen ad: Uzman Köşesi → Uzman Profilleri Köşesi
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

update public.app_sections
set title = 'Uzman Profilleri Köşesi'
where section_key = 'uzman_kosesi'
  and title in ('Uzman Köşesi', '');
