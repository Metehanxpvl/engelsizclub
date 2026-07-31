import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/diseases_data.dart';
import 'services/app_catalog_service.dart';

Map<String, dynamic> diseaseToRow(DiseaseInfo d, {int sortOrder = 0}) {
  return {
    'id': d.id,
    'name': d.name.trim(),
    'icon': d.icon,
    'color': d.color.toARGB32(),
    'bg': d.bg.toARGB32(),
    'photo': d.photo ?? '',
    'description': d.desc.trim(),
    'symptoms': d.symptoms,
    'diagnosis': d.diagnosis.trim(),
    'support': d.support,
    'faq': [
      for (final f in d.faq) {'q': f.q, 'a': f.a},
    ],
    'sort_order': sortOrder,
    'active': true,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

/// Admin: hastalık kartı + detay metinlerini `app_diseases` içine kaydeder.
Future<DiseaseInfo> upsertAppDisease(DiseaseInfo disease, {int? sortOrder}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw StateError('Giriş gerekli.');
  final id = disease.id.trim();
  if (id.isEmpty) throw StateError('Geçersiz hastalık.');
  if (disease.name.trim().isEmpty) throw StateError('Başlık gerekli.');

  final existing = AppCatalogService.instance.list(CatalogPack.diseases);
  var order = sortOrder ?? existing.length;
  if (sortOrder == null) {
    for (final e in existing) {
      if (e['id']?.toString() == id) {
        order = (e['sort_order'] as num?)?.toInt() ?? 0;
        break;
      }
    }
  }

  final payload = diseaseToRow(disease, sortOrder: order);
  final row = Map<String, dynamic>.from(
    await Supabase.instance.client
        .from('app_diseases')
        .upsert(payload)
        .select()
        .single(),
  );

  await AppCatalogService.instance.replaceDiseaseRow(row);
  return disease;
}
