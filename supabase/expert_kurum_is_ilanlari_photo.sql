-- Additive: kurum görseli + adres. Mevcut kolonlara dokunmaz.
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

alter table public.expert_kurum_is_ilanlari
  add column if not exists adres text not null default '';
alter table public.expert_kurum_is_ilanlari
  add column if not exists photo_url text not null default '';

notify pgrst, 'reload schema';
