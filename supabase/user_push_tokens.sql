-- Token’lar: girişte upsert, çıkışta DELETE (istemci unregisterCurrentToken).
-- Supabase SQL Editor’da bir kez çalıştırın.

create table if not exists public.user_push_tokens (
  token text primary key,
  owner_email text not null,
  owner_id uuid references auth.users (id) on delete cascade,
  platform text not null default 'android',
  updated_at timestamptz not null default now()
);

-- Eski tablo create if not exists ile kolon eklemez; upsert owner_id düşmesin.
alter table public.user_push_tokens
  add column if not exists owner_id uuid references auth.users (id) on delete cascade;
alter table public.user_push_tokens
  add column if not exists platform text not null default 'android';
alter table public.user_push_tokens
  add column if not exists updated_at timestamptz not null default now();

create index if not exists user_push_tokens_email_idx
  on public.user_push_tokens (owner_email);

alter table public.user_push_tokens enable row level security;

grant select, insert, update, delete on table public.user_push_tokens to authenticated;

drop policy if exists "user_push_tokens_select_own" on public.user_push_tokens;
create policy "user_push_tokens_select_own"
  on public.user_push_tokens for select
  to authenticated
  using (lower(owner_email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "user_push_tokens_insert_own" on public.user_push_tokens;
create policy "user_push_tokens_insert_own"
  on public.user_push_tokens for insert
  to authenticated
  with check (lower(owner_email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "user_push_tokens_update_own" on public.user_push_tokens;
create policy "user_push_tokens_update_own"
  on public.user_push_tokens for update
  to authenticated
  using (lower(owner_email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "user_push_tokens_delete_own" on public.user_push_tokens;
create policy "user_push_tokens_delete_own"
  on public.user_push_tokens for delete
  to authenticated
  using (lower(owner_email) = lower(auth.jwt() ->> 'email'));

notify pgrst, 'reload schema';
