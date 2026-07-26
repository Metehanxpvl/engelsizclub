// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:engelsizclub/data/rights_data.dart';

String sqlStr(String s) => "'${s.replaceAll("'", "''")}'";

void main() {
  final buf = StringBuffer();
  buf.writeln('-- Otomatik seed: app_rights (Flutter allRights)');
  buf.writeln('-- Supabase SQL Editor → Run');
  buf.writeln();
  buf.writeln('truncate table public.app_rights restart identity cascade;');
  buf.writeln();

  var sort = 0;
  for (final r in allRights) {
    sort++;
    final stepsJson = jsonEncode(r.steps);
    buf.writeln('insert into public.app_rights (');
    buf.writeln(
      '  id, title, amount, category, icon, color, bg, min_rate, max_age,',
    );
    buf.writeln(
      '  income_limit, description, steps, where_text, sort_order, active',
    );
    buf.writeln(') values (');
    buf.writeln('  ${sqlStr(r.id)},');
    buf.writeln('  ${sqlStr(r.title)},');
    buf.writeln('  ${sqlStr(r.amount)},');
    buf.writeln('  ${sqlStr(r.category)},');
    buf.writeln('  ${sqlStr(r.icon)},');
    buf.writeln('  ${r.color.toARGB32()},');
    buf.writeln('  ${r.bg.toARGB32()},');
    buf.writeln('  ${r.minRate},');
    buf.writeln('  ${r.maxAge},');
    buf.writeln('  ${r.incomeLimit},');
    buf.writeln('  ${sqlStr(r.desc)},');
    buf.writeln("  '${stepsJson.replaceAll("'", "''")}'::jsonb,");
    buf.writeln('  ${sqlStr(r.where)},');
    buf.writeln('  $sort,');
    buf.writeln('  true');
    buf.writeln(');');
    buf.writeln();
  }

  buf.writeln(
    "update public.app_catalog_versions set version = version + 1, updated_at = now() where name = 'rights';",
  );
  buf.writeln("notify pgrst, 'reload schema';");
  print(buf.toString());
}
