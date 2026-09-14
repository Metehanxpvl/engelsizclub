-- MetoBot threads + messages. SQL Editor → Run.
-- Optional: app_settings.metobot_limits (new key only).

create table if not exists public.metobot_threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.metobot_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.metobot_threads (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists metobot_threads_user_idx
  on public.metobot_threads (user_id, updated_at desc);

create index if not exists metobot_messages_thread_idx
  on public.metobot_messages (thread_id, created_at);

create index if not exists metobot_messages_user_created_idx
  on public.metobot_messages (user_id, created_at desc);

alter table public.metobot_threads enable row level security;
alter table public.metobot_messages enable row level security;

drop policy if exists "metobot_threads_select_own" on public.metobot_threads;
create policy "metobot_threads_select_own"
  on public.metobot_threads for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "metobot_threads_insert_own" on public.metobot_threads;
create policy "metobot_threads_insert_own"
  on public.metobot_threads for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "metobot_threads_update_own" on public.metobot_threads;
create policy "metobot_threads_update_own"
  on public.metobot_threads for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "metobot_messages_select_own" on public.metobot_messages;
create policy "metobot_messages_select_own"
  on public.metobot_messages for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "metobot_messages_insert_own" on public.metobot_messages;
create policy "metobot_messages_insert_own"
  on public.metobot_messages for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.metobot_threads t
      where t.id = thread_id and t.user_id = auth.uid()
    )
  );

grant select, insert, update on table public.metobot_threads to authenticated;
grant select, insert on table public.metobot_messages to authenticated;

insert into public.app_settings (key, value, description)
values (
  'metobot_limits',
  jsonb_build_object(
    'dailyUserMessages', 40,
    'maxOutputTokens', 512,
    'lastN', 12
  ),
  'MetoBot günlük mesaj tavanı'
)
on conflict (key) do nothing;

notify pgrst, 'reload schema';
