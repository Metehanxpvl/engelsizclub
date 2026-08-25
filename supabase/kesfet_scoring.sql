-- Engelsiz Club — Keşfet alaka skoru (Phase 2 tarama da bunu kullanır)
-- Tek zayıf negatif (ör. "gündem") otomatik red DEĞİL.
-- Sağlık iddiası → safety_flag; asla otomatik onay yok (status buradan değişmez).

create or replace function public.kesfet_score_text(
  p_title text,
  p_description text,
  p_tags text[],
  p_channel text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_haystack text;
  v_score int := 0;
  v_safety boolean := false;
  v_note text := '';
  v_matched_pos text[] := '{}';
  v_matched_neg text[] := '{}';
  v_cat text := 'engellilik';
  v_cat_best int := 0;
  r record;
  v_hits int;
begin
  v_haystack := lower(concat_ws(' ',
    coalesce(p_title, ''),
    coalesce(p_description, ''),
    coalesce(array_to_string(p_tags, ' '), ''),
    coalesce(p_channel, '')
  ));

  for r in
    select phrase, polarity, weight, category_hint, is_weak
    from public.kesfet_keywords
    where is_active = true
  loop
    if position(lower(r.phrase) in v_haystack) = 0 then
      continue;
    end if;

    if r.polarity = 'positive' then
      v_score := v_score + r.weight;
      v_matched_pos := array_append(v_matched_pos, r.phrase);
      if coalesce(r.category_hint, '') <> '' then
        select count(*)::int into v_hits
        from unnest(v_matched_pos) x
        where x in (
          select phrase from public.kesfet_keywords
          where is_active and polarity = 'positive' and category_hint = r.category_hint
        );
        -- kategori oyu: bu hint’e bağlı pozitif eşleşme sayısı * weight
        if r.weight >= v_cat_best then
          v_cat_best := r.weight;
          v_cat := r.category_hint;
        end if;
      end if;
    elsif r.polarity = 'negative' then
      v_matched_neg := array_append(v_matched_neg, r.phrase);
      if r.is_weak then
        v_score := v_score - greatest(1, r.weight / 2);
      else
        v_score := v_score - r.weight;
      end if;
    elsif r.polarity = 'safety' then
      v_safety := true;
      v_score := v_score - 5;
      if v_note = '' then
        v_note := 'Sağlık iddiası tespit edildi: ' || r.phrase;
      else
        v_note := v_note || ', ' || r.phrase;
      end if;
    end if;
  end loop;

  if v_cat is null or v_cat = '' then
    v_cat := 'engellilik';
  end if;

  return jsonb_build_object(
    'score', v_score,
    'safety_flag', v_safety,
    'safety_note', v_note,
    'suggested_category', v_cat,
    'matched_positives', to_jsonb(v_matched_pos),
    'matched_negatives', to_jsonb(v_matched_neg),
    'auto_approve', false
  );
end;
$$;

revoke all on function public.kesfet_score_text(text, text, text[], text) from public;
grant execute on function public.kesfet_score_text(text, text, text[], text)
  to anon, authenticated;

notify pgrst, 'reload schema';
