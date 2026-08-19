-- İlan paylaşma / teklif verme rol kısıtları
-- Aile: ilan paylaşır · Uzman/Bakıcı: teklif verir · Aile: 2.el / iş arıyorum iletişimi

create or replace function public.auth_user_type()
returns text
language sql
stable
as $$
  select coalesce(
    nullif(trim(auth.jwt() -> 'user_metadata' ->> 'user_type'), ''),
    'aile'
  );
$$;

-- Yalnızca aile rolü ilan ekleyebilir
drop policy if exists "ilanlar_insert_own" on public.ilanlar;
create policy "ilanlar_insert_own"
  on public.ilanlar for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and public.auth_user_type() = 'aile'
  );
-- Teklif: aile → yalnızca 2.el · uzman/bakıcı → uzman ve bakıcı ilanları
drop policy if exists "bildirim_insert_actor" on public.bildirimler;
create policy "bildirim_insert_actor"
  on public.bildirimler for insert
  to authenticated
  with check (
    lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    and (
      type is distinct from 'teklif'
      or public.auth_user_type() in ('uzman', 'bakici')
      or (
        type = 'teklif'
        and public.auth_user_type() = 'aile'
        and ilan_id is not null
        and exists (
          select 1
          from public.ilanlar i
          where i.id = ilan_id
            and i.kind = 'ikinciel'
        )
      )
    )
  );
notify pgrst, 'reload schema';
