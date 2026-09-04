/// İlaç küpür / prospektüs özeti (Supabase `medicines`).
/// Teşhis veya tedavi tavsiyesi değildir; yalnız etiket bilgisi.
class MedicineRecord {
  const MedicineRecord({
    this.id,
    this.barcode,
    this.medicineName = '',
    this.activeIngredient = '',
    this.indications = '',
    this.usageText = '',
    this.sideEffects = const [],
    this.drugInteractions = const [],
    this.safetyWarnings = '',
    this.prospectusUrl,
    this.imageUrl,
    this.rawReport = const {},
    this.source = 'llm',
    this.createdAt,
    this.fromCache = false,
  });

  final String? id;
  final String? barcode;
  final String medicineName;
  final String activeIngredient;
  /// Prospektüs: ne için kullanılır.
  final String indications;
  final String usageText;
  final List<String> sideEffects;
  /// Prospektüste yer alan etkileşimler / birlikte dikkat edilmesi gerekenler.
  final List<String> drugInteractions;
  final String safetyWarnings;
  /// Resmi KT / e-KT HTTPS (TİTCK PDF veya karekod URL).
  final String? prospectusUrl;
  final String? imageUrl;
  final Map<String, dynamic> rawReport;
  final String source;
  final DateTime? createdAt;
  final bool fromCache;

  bool get isFound =>
      hasUsefulName ||
      activeIngredient.trim().isNotEmpty ||
      !isUnknownText(usageText);

  /// SKRS ürün no (41513) ad değildir; ada aramada / Gemini tohumunda kullanılmaz.
  bool get hasUsefulName =>
      medicineName.trim().length >= 2 && !isNumericName(medicineName);

  /// Ne işe yarar veya kullanım doluysa prospektüs var sayılır.
  /// Tek başına "Yok" listesi / uyarı kartı tam kayıt değildir.
  bool get isComplete =>
      hasUsefulName &&
      (!isUnknownText(indications) || !isUnknownText(usageText));

  bool get needsEnrichment => isFound && !isComplete;

  /// Boş, "Yok", "Bilinmiyor", tire — yeşil Yok uydurma.
  static bool isUnknownText(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return true;
    final compact = s.toLowerCase().replaceAll(RegExp(r'[.!\s]+$'), '');
    if (compact.isEmpty) return true;
    return compact == 'yok' ||
        compact == 'yoktur' ||
        compact == 'bilinmiyor' ||
        compact == 'n/a' ||
        compact == 'na' ||
        compact == 'none' ||
        compact == 'null' ||
        compact == '-' ||
        compact == '—' ||
        compact == '–';
  }

  static bool isNumericName(String raw) =>
      RegExp(r'^\d{3,}$').hasMatch(raw.trim());

  bool get hasOfficialProspectus {
    final u = (prospectusUrl ?? '').trim();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  factory MedicineRecord.fromJson(
    Map<String, dynamic> json, {
    bool fromCache = false,
  }) {
    return MedicineRecord(
      id: json['id']?.toString(),
      barcode: _nullableText(json['barcode']),
      medicineName: _text(
        json['medicine_name'] ??
            json['medicineName'] ??
            json['product_name'] ??
            json['productName'] ??
            json['name'],
      ),
      activeIngredient: _text(
        json['active_ingredient'] ??
            json['activeIngredient'] ??
            json['etken_madde'],
      ),
      indications: _realText(_indicationsFrom(json)),
      usageText: _realText(
        _text(json['usage_text'] ?? json['usage'] ?? json['kullanim']),
      ),
      sideEffects: _realList(
        stringList(
          json['side_effects'] ?? json['sideEffects'] ?? json['yan_etkiler'],
        ),
      ),
      drugInteractions: _realList(_drugInteractionsFrom(json)),
      safetyWarnings: _realText(
        _text(
          json['safety_warnings'] ??
              json['safetyWarnings'] ??
              json['kritik_uyarilar'] ??
              _nestedReportField(json, 'summary'),
        ),
      ),
      prospectusUrl: _nullableText(
        json['prospectus_url'] ?? json['prospectusUrl'] ?? json['kt_url'],
      ),
      imageUrl: _nullableText(json['image_url'] ?? json['imageUrl']),
      rawReport: json['raw_report'] is Map
          ? Map<String, dynamic>.from(json['raw_report'] as Map)
          : (json['rawReport'] is Map
              ? Map<String, dynamic>.from(json['rawReport'] as Map)
              : const {}),
      source: _text(json['source']).isEmpty ? 'llm' : _text(json['source']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      fromCache: fromCache,
    );
  }

  /// Gemini JSON → kayıt (markdown sarmalı gevşek parse sonrası).
  factory MedicineRecord.fromGemini(
    Map<String, dynamic> map, {
    String? barcode,
    String? imageUrl,
  }) {
    return MedicineRecord(
      barcode: _nullableText(barcode) ?? _nullableText(map['barcode']),
      medicineName: _text(
        map['product_name'] ??
            map['productName'] ??
            map['medicine_name'] ??
            map['medicineName'] ??
            map['ilac_adi'] ??
            map['ilaç_adı'] ??
            map['name'],
      ),
      activeIngredient: _text(
        map['active_ingredient'] ??
            map['activeIngredient'] ??
            map['etken_madde'] ??
            map['etkenMadde'],
      ),
      indications: _realText(_indicationsFrom(map)),
      usageText: _realText(
        _text(
          map['usage'] ??
              map['usage_text'] ??
              map['usageText'] ??
              map['kullanim'] ??
              map['kullanım'],
        ),
      ),
      sideEffects: _realList(
        stringList(
          map['side_effects'] ??
              map['sideEffects'] ??
              map['yan_etkiler'] ??
              map['yanEtkiler'],
        ),
      ),
      drugInteractions: _realList(_drugInteractionsFrom(map)),
      safetyWarnings: _realText(
        _text(
          map['safety_warnings'] ??
              map['safetyWarnings'] ??
              map['kritik_uyarilar'] ??
              map['warnings'] ??
              _nestedReportField(map, 'summary'),
        ),
      ),
      imageUrl: imageUrl,
      rawReport: Map<String, dynamic>.from(map),
      source: 'llm',
    );
  }

  Map<String, dynamic> toInsertJson() {
    final code = (barcode ?? '').trim();
    return <String, dynamic>{
      if (code.length >= 4) 'barcode': code,
      'medicine_name': medicineName.trim().isEmpty ? null : medicineName.trim(),
      'active_ingredient':
          activeIngredient.trim().isEmpty ? null : activeIngredient.trim(),
      'indications': indications.trim().isEmpty ? null : indications.trim(),
      'usage_text': usageText.trim().isEmpty ? null : usageText.trim(),
      'side_effects': sideEffects,
      'drug_interactions': drugInteractions,
      'safety_warnings':
          safetyWarnings.trim().isEmpty ? null : safetyWarnings.trim(),
      'prospectus_url':
          (prospectusUrl ?? '').trim().isEmpty ? null : prospectusUrl!.trim(),
      'image_url': (imageUrl ?? '').trim().isEmpty ? null : imageUrl!.trim(),
      'raw_report': rawReport,
      'source': source.trim().isEmpty ? 'llm' : source.trim(),
    };
  }

  MedicineRecord copyWith({
    String? id,
    String? barcode,
    String? medicineName,
    String? activeIngredient,
    String? indications,
    String? usageText,
    List<String>? sideEffects,
    List<String>? drugInteractions,
    String? safetyWarnings,
    String? prospectusUrl,
    String? imageUrl,
    Map<String, dynamic>? rawReport,
    String? source,
    DateTime? createdAt,
    bool? fromCache,
  }) {
    return MedicineRecord(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      medicineName: medicineName ?? this.medicineName,
      activeIngredient: activeIngredient ?? this.activeIngredient,
      indications: indications ?? this.indications,
      usageText: usageText ?? this.usageText,
      sideEffects: sideEffects ?? this.sideEffects,
      drugInteractions: drugInteractions ?? this.drugInteractions,
      safetyWarnings: safetyWarnings ?? this.safetyWarnings,
      prospectusUrl: prospectusUrl ?? this.prospectusUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      rawReport: rawReport ?? this.rawReport,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  static String _indicationsFrom(Map<String, dynamic> json) {
    final direct = _text(
      json['indications'] ??
          json['indication'] ??
          json['ne_icin'] ??
          json['ne_icin_kullanilir'],
    );
    if (direct.isNotEmpty) return direct;
    final nested = _nestedReportMap(json);
    if (nested != null) {
      final fromReport = _text(
        nested['indications'] ?? nested['ingredients'],
      );
      if (fromReport.isNotEmpty) return fromReport;
    }
    return _text(json['ingredients']);
  }

  static List<String> _drugInteractionsFrom(Map<String, dynamic> json) {
    final direct = stringList(
      json['drug_interactions'] ??
          json['drugInteractions'] ??
          json['etkilesimler'] ??
          json['etkileşimler'] ??
          json['interactions'],
    );
    if (direct.isNotEmpty) return direct;
    final nested = _nestedReportMap(json);
    if (nested != null) {
      final fromReport = stringList(
        nested['drug_interactions'] ?? nested['drugInteractions'],
      );
      if (fromReport.isNotEmpty) return fromReport;
    }
    final raw = json['raw_report'] ?? json['rawReport'];
    if (raw is Map) {
      return _drugInteractionsFrom(Map<String, dynamic>.from(raw));
    }
    return const [];
  }

  static Map<String, dynamic>? _nestedReportMap(Map<String, dynamic> json) {
    final report = json['safety_report'] ?? json['safetyReport'];
    if (report is Map) return Map<String, dynamic>.from(report);
    return null;
  }

  static Object? _nestedReportField(Map<String, dynamic> json, String key) {
    final nested = _nestedReportMap(json);
    return nested?[key];
  }

  static List<String> stringList(Object? raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map(_listItemText).where((s) => s.isNotEmpty).toList();
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return const [];
    return s
        .split(RegExp(r'[\n;•]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String _listItemText(Object? e) {
    if (e == null) return '';
    if (e is Map) {
      final m = Map<String, dynamic>.from(e);
      final t = _text(
        m['name'] ??
            m['label'] ??
            m['text'] ??
            m['ingredient'] ??
            m['title'] ??
            m['summary'],
      );
      final note = _text(m['note'] ?? m['warning'] ?? m['detail']);
      if (t.isNotEmpty && note.isNotEmpty) return '$t: $note';
      return t;
    }
    return e.toString().trim();
  }

  static String _text(Object? raw) {
    if (raw == null) return '';
    return raw.toString().trim();
  }

  static String _realText(String raw) => isUnknownText(raw) ? '' : raw.trim();

  static List<String> _realList(List<String> items) => items
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && !isUnknownText(e))
      .toList();

  static String? _nullableText(Object? raw) {
    final s = _text(raw);
    return s.isEmpty ? null : s;
  }
}
