/// Forum ana hastalığı (dinamik katalog).
class ForumDisease {
  const ForumDisease({
    required this.id,
    required this.label,
    required this.shortLabel,
    this.icon = '',
    this.sortOrder = 0,
  });

  final String id;
  final String label;
  final String shortLabel;
  final String icon;
  final int sortOrder;

  String get chipLabel => shortLabel.trim().isEmpty ? label : shortLabel;

  factory ForumDisease.fromJson(Map<String, dynamic> json) => ForumDisease(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        shortLabel: json['short_label']?.toString() ??
            json['label']?.toString() ??
            '',
        icon: json['icon']?.toString() ?? '',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );
}

/// Hastalığa bağlı alt kategori.
class ForumSubCategory {
  const ForumSubCategory({
    required this.id,
    required this.diseaseId,
    required this.label,
    this.sortOrder = 0,
  });

  final String id;
  final String diseaseId;
  final String label;
  final int sortOrder;

  factory ForumSubCategory.fromJson(Map<String, dynamic> json) =>
      ForumSubCategory(
        id: json['id']?.toString() ?? '',
        diseaseId: json['disease_id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );
}
