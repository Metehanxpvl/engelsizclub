import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';

/// Atanabilir bölümler — SQL `section_editors.section_key` ile birebir.
enum SectionKey {
  duyurular('duyurular', 'Güncel Duyurular'),
  gezi('gezi', 'Gezi Rehberi'),
  kampanya('kampanya', 'Kampanyalar'),
  etkinlik('etkinlik', 'Etkinlikler');

  const SectionKey(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static const all = <SectionKey>[
    duyurular,
    gezi,
    kampanya,
    etkinlik,
  ];

  static SectionKey? tryParse(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    for (final k in all) {
      if (k.dbValue == v) return k;
    }
    return null;
  }
}

String _normEmail(String? email) => (email ?? '').trim().toLowerCase();

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool looksLikeEditorEmail(String? email) => _emailRe.hasMatch(_normEmail(email));

String? _loadedFor;
Set<String> _loadedKeys = {};
DateTime? _loadedAt;
const _cacheTtl = Duration(minutes: 5);

void invalidateSectionEditorsCache() {
  _loadedFor = null;
  _loadedKeys = {};
  _loadedAt = null;
}

/// Super admin veya `section_editors` kaydı. Senkron; önce
/// [ensureSectionEditorsLoaded] çağrılmış olmalı (store yüklemeleri yapar).
bool canEditSection(String? email, SectionKey key) {
  if (isAppAdmin(email)) return true;
  final e = _normEmail(email);
  if (e.isEmpty) return false;
  if (_loadedFor != e) return false;
  return _loadedKeys.contains(key.dbValue);
}

SectionKey? sectionKeyForTile(String tileKey) {
  return SectionKey.tryParse(tileKey.trim().toLowerCase());
}

Future<void> ensureSectionEditorsLoaded(String? email) async {
  final e = _normEmail(email);
  if (e.isEmpty || isAppAdmin(e)) return;
  if (_loadedFor == e &&
      _loadedAt != null &&
      DateTime.now().difference(_loadedAt!) < _cacheTtl) {
    return;
  }
  try {
    final rows = await Supabase.instance.client
        .from('section_editors')
        .select('section_key')
        .eq('email', e);
    _loadedKeys = {
      for (final r in (rows as List).whereType<Map>())
        (r['section_key']?.toString() ?? '').trim().toLowerCase(),
    }..removeWhere((s) => s.isEmpty);
    _loadedFor = e;
    _loadedAt = DateTime.now();
  } catch (_) {
    _loadedKeys = {};
    _loadedFor = null;
    _loadedAt = null;
  }
}

class SectionEditorEntry {
  const SectionEditorEntry({
    required this.email,
    required this.sections,
  });

  final String email;
  final Set<SectionKey> sections;
}

Future<List<SectionEditorEntry>> loadAllSectionEditors() async {
  final me = Supabase.instance.client.auth.currentUser?.email;
  if (!isAppAdmin(me)) {
    throw StateError('Yalnızca super admin bölüm yöneticisi atayabilir.');
  }
  try {
    final rows = await Supabase.instance.client
        .from('section_editors')
        .select('email, section_key')
        .order('email');
    final map = <String, Set<SectionKey>>{};
    for (final r in (rows as List).whereType<Map>()) {
      final email = _normEmail(r['email']?.toString());
      final key = SectionKey.tryParse(r['section_key']?.toString());
      if (email.isEmpty || key == null) continue;
      map.putIfAbsent(email, () => <SectionKey>{}).add(key);
    }
    final list = [
      for (final e in map.entries)
        SectionEditorEntry(email: e.key, sections: e.value),
    ];
    list.sort((a, b) => a.email.compareTo(b.email));
    return list;
  } catch (e) {
    final raw = e.toString();
    if (raw.contains('section_editors') ||
        raw.contains('PGRST') ||
        raw.contains('schema cache') ||
        raw.contains('42P01')) {
      throw StateError(
        'Bölüm yöneticileri tablosu yok. Supabase’de section_editors.sql çalıştırın.',
      );
    }
    rethrow;
  }
}

Future<void> saveSectionEditor({
  required String email,
  required Set<SectionKey> sections,
}) async {
  final client = Supabase.instance.client;
  final me = client.auth.currentUser?.email;
  if (!isAppAdmin(me)) {
    throw StateError('Yalnızca super admin bölüm yöneticisi atayabilir.');
  }
  final e = _normEmail(email);
  if (!looksLikeEditorEmail(e)) {
    throw StateError('Geçerli bir e-posta girin.');
  }
  await client.from('section_editors').delete().eq('email', e);
  if (sections.isEmpty) {
    invalidateSectionEditorsCache();
    return;
  }
  await client.from('section_editors').insert([
    for (final k in sections)
      {
        'email': e,
        'section_key': k.dbValue,
        'created_by': _normEmail(me),
      },
  ]);
  invalidateSectionEditorsCache();
}

Future<void> removeSectionEditor(String email) {
  return saveSectionEditor(email: email, sections: {});
}
