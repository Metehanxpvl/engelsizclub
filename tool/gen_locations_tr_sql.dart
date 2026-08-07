// ignore_for_file: avoid_print
/// TR il/ilçe seed SQL üretir.
/// Kullanım: dart run tool/gen_locations_tr_sql.dart
import 'dart:io';

import 'package:engelsizclub/data/centers_data.dart' show kAllIlceler;
import 'package:engelsizclub/data/turkish_cities_data.dart';

void main() {
  final buf = StringBuffer();
  buf.writeln('-- GENERATED: dart run tool/gen_locations_tr_sql.dart');
  buf.writeln('-- Türkiye il / ilçe seed');
  buf.writeln();
  buf.writeln(r'''
create or replace function public._seed_loc_state(
  p_country text,
  p_state text,
  p_cities text[]
) returns void
language plpgsql
as $$
declare
  sid bigint;
  c text;
begin
  insert into public.locations_states (country_code, code, name)
  values (p_country, p_state, p_state)
  on conflict (country_code, name) do update set name = excluded.name
  returning id into sid;
  if sid is null then
    select id into sid from public.locations_states
    where country_code = p_country and name = p_state;
  end if;
  foreach c in array p_cities loop
    insert into public.locations_cities (country_code, state_id, name)
    values (p_country, sid, c)
    on conflict (state_id, name) do nothing;
  end loop;
end;
$$;
''');

  for (final il in kCityNames) {
    final info = kTurkishCities[il];
    if (info == null) continue;
    final ilceler = info.ilceler.where((e) => e != kAllIlceler).toList();
    final escaped = ilceler
        .map((e) => "'${e.replaceAll("'", "''")}'")
        .join(',');
    final ilEsc = il.replaceAll("'", "''");
    buf.writeln(
      "select public._seed_loc_state('TR', '$ilEsc', array[$escaped]);",
    );
  }
  buf.writeln();
  buf.writeln('drop function if exists public._seed_loc_state(text, text, text[]);');
  buf.writeln("notify pgrst, 'reload schema';");

  final out = File('supabase/locations_tr_seed.sql');
  out.writeAsStringSync(buf.toString());
  print('Wrote ${out.path} (${kCityNames.length} iller)');
}
