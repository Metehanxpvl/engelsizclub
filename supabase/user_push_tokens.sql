-- Kullanıcı cihaz FCM token’ları (kişisel push: forum yanıtı, mesaj vb.)
-- Supabase SQL Editor’da bir kez çalıştırın.

create table if not exists public.user_push_tokens (
  token text primary key,
  owner_email text not null,
  owner_id uuid references auth.users (id) on delete cascade,
  platform text not null default 'android',
  updated_at timestamptz not null default now()
);

create index if not exists user_push_tokens_email_idx
  on public.user_push_tokens (owner_email);

alter table public.user_push_tokens enable row level security;

drop policy if exists "user_push_tokens_select_own" on public.user_push_tokens;
create policy "user_push_tokens_select_own"
  on public.user_push_tokens for select
  using (lower(owner_email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "user_push_tokens_insert_own" on public.user_push_tokens;
create policy "user_push_tokens_insert_own"
  on public.user_push_tokens for insert
  with check (lower(owner_email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "user_push_tokens_update_own" on public.user_push_tokens;
create policy "user_push_tokens_update_own"
  on public.user_push_tokens for update
  using (lower(owner_email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "user_push_tokens_delete_own" on public.user_push_tokens;
create policy "user_push_tokens_delete_own"
  on public.user_push_tokens for delete
  using (lower(owner_email) = lower(auth.jwt() ->> 'email'));

notify pgrst, 'reload schema';
