-- Admin: ilanın ana kategorisini değiştir (uzman / bakici / ikinciel)
-- Supabase Dashboard → SQL Editor → bu dosyanın tamamını çalıştır
-- Admin: sakir.caykara@gmail.com

-- RLS: admin herhangi bir ilanı güncelleyebilir (kategori taşıma)
drop policy if exists "ilanlar_update_admin" on public.ilanlar;
create policy "ilanlar_update_admin"
  on public.ilanlar for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Kesin çözüm: SECURITY DEFINER RPC (RLS bypass, e-posta kontrolü içeride)
create or replace function public.admin_change_ilan_kind(
  p_id bigint,
  p_kind text,
  p_category text default null,
  p_uzmanlik text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_kind text;
  v_category text;
  v_uzmanlik text;
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'not allowed';
  end if;

  v_kind := lower(trim(coalesce(p_kind, '')));
  if v_kind not in ('uzman', 'bakici', 'ikinciel') then
    raise exception 'invalid kind';
  end if;

  v_category := nullif(trim(coalesce(p_category, '')), '');
  if v_category is null then
    v_category := 'Diğer';
  end if;
  v_uzmanlik := nullif(trim(coalesce(p_uzmanlik, '')), '');

  update public.ilanlar
  set
    kind = v_kind,
    category = case
      when v_kind = 'ikinciel' then v_category
      else category
    end,
    uzmanlik = case
      when v_kind = 'uzman' then coalesce(v_uzmanlik, nullif(trim(uzmanlik), ''), 'Uzman')
      else uzmanlik
    end,
    condition = case
      when v_kind = 'ikinciel' and (condition is null or trim(condition) = '') then 'İyi'
      else condition
    end,
    brand = case
      when v_kind = 'ikinciel' and (brand is null or trim(brand) = '') then '—'
      else brand
    end,
    emoji = case
      when v_kind = 'ikinciel' and (emoji is null or trim(emoji) = '') then '📦'
      else emoji
    end,
    price = case
      when v_kind = 'ikinciel' and (price is null or trim(price) = '') then coalesce(budget, '')
      else price
    end,
    budget = case
      when v_kind in ('uzman', 'bakici') and (budget is null or trim(budget) = '') then coalesce(price, '')
      else budget
    end,
    photos = case
      when v_kind in ('uzman', 'bakici')
        and jsonb_typeof(photos) = 'array'
        and jsonb_array_length(photos) > 2
      then (
        select coalesce(jsonb_agg(elem order by n), '[]'::jsonb)
        from jsonb_array_elements(photos) with ordinality as t(elem, n)
        where n <= 2
      )
      else photos
    end
  where id = p_id;

  if not found then
    raise exception 'ilan not found';
  end if;
end;
$$;

revoke all on function public.admin_change_ilan_kind(bigint, text, text, text) from public;
grant execute on function public.admin_change_ilan_kind(bigint, text, text, text) to authenticated;

notify pgrst, 'reload schema';
