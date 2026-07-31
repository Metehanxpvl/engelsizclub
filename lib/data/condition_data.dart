import 'package:flutter/material.dart';

import '../meto_theme.dart';
import 'diseases_data.dart';

List<String> _stringListFromJson(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final s in raw)
      if (s.toString().trim().isNotEmpty) s.toString().trim(),
  ];
}

List<FaqItem> _faqFromJson(dynamic raw) {
  if (raw is! List) return const [];
  final out = <FaqItem>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final q = item['q']?.toString() ?? item['question']?.toString() ?? '';
    final a = item['a']?.toString() ?? item['answer']?.toString() ?? '';
    if (q.isNotEmpty) out.add(FaqItem(q, a));
  }
  return out;
}

/// Supabase `conditions` satırı — ana sayfa Hastalıklar & Durumlar.
class ConditionItem {
  const ConditionItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.description,
    required this.createdAt,
    this.sortOrder = 0,
    this.isActive = true,
    this.catalogId = '',
    this.icon = '🩺',
    this.symptoms = const [],
    this.diagnosis = '',
    this.support = const [],
    this.faq = const [],
  });

  final int id;
  final String title;
  final String imageUrl;
  final String description;
  final DateTime createdAt;
  final int sortOrder;
  final bool isActive;
  final String catalogId;
  final String icon;
  final List<String> symptoms;
  final String diagnosis;
  final List<String> support;
  final List<FaqItem> faq;

  factory ConditionItem.fromRow(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now();
    return ConditionItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAt: created,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
      catalogId: json['catalog_id']?.toString() ?? '',
      icon: (json['icon']?.toString().trim().isNotEmpty == true)
          ? json['icon'].toString()
          : '🩺',
      symptoms: _stringListFromJson(json['symptoms']),
      diagnosis: json['diagnosis']?.toString() ?? '',
      support: _stringListFromJson(json['support']),
      faq: _faqFromJson(json['faq']),
    );
  }

  /// Detay ekranı ile uyum için DiseaseInfo'ya dönüştürür.
  DiseaseInfo toDiseaseInfo({DiseaseInfo? enrichFrom}) {
    final photo = imageUrl.trim();
    final base = enrichFrom;
    final useSymptoms =
        symptoms.isNotEmpty ? symptoms : (base?.symptoms ?? const <String>[]);
    final useSupport =
        support.isNotEmpty ? support : (base?.support ?? const <String>[]);
    final useFaq = faq.isNotEmpty ? faq : (base?.faq ?? const <FaqItem>[]);
    final useDiagnosis =
        diagnosis.trim().isNotEmpty ? diagnosis : (base?.diagnosis ?? '');
    final useDesc =
        description.trim().isNotEmpty ? description : (base?.desc ?? '');
    final usePhoto = photo.isNotEmpty ? photo : base?.photo;
    return DiseaseInfo(
      id: 'cond_$id',
      name: title,
      icon: icon.trim().isNotEmpty ? icon : (base?.icon ?? '🩺'),
      color: base?.color ?? MetoColors.primary,
      bg: base?.bg ?? const Color(0xFFE8F5EE),
      photo: usePhoto,
      desc: useDesc,
      symptoms: useSymptoms,
      diagnosis: useDiagnosis,
      support: useSupport,
      faq: useFaq,
    );
  }

  ConditionItem copyWith({
    String? title,
    String? imageUrl,
    String? description,
    int? sortOrder,
    bool? isActive,
    String? catalogId,
    String? icon,
    List<String>? symptoms,
    String? diagnosis,
    List<String>? support,
    List<FaqItem>? faq,
  }) =>
      ConditionItem(
        id: id,
        title: title ?? this.title,
        imageUrl: imageUrl ?? this.imageUrl,
        description: description ?? this.description,
        createdAt: createdAt,
        sortOrder: sortOrder ?? this.sortOrder,
        isActive: isActive ?? this.isActive,
        catalogId: catalogId ?? this.catalogId,
        icon: icon ?? this.icon,
        symptoms: symptoms ?? this.symptoms,
        diagnosis: diagnosis ?? this.diagnosis,
        support: support ?? this.support,
        faq: faq ?? this.faq,
      );
}
