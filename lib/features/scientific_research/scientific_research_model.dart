// Bilimsel araştırma satırı + admin kuyruk yardımcıları.
// Kullanıcı kütüphanesi (Phase C) burada yok.

const kScientificResearchStatuses = <String>{
  'pending_review',
  'published',
  'rejected',
};

/// Onayla → addDuyuru (Güncel Duyurular story). Fırsatlar ile aynı notify.
const kScientificResearchApproveCreatesDuyuru = true;
const kScientificResearchApproveNotify = true;

const kScientificResearchApproveNeedImageMessage = 'Önce görsel ekle';

const kHighTreatmentScoreThreshold = 70;

const kScientificResearchesMissingSqlMessage =
    'scientific_researches tablosu yok. Supabase SQL Editor’de scientific_researches.sql çalıştırın.';

enum ScienceAdminFilter {
  pending,
  published,
  rejected,
  highValue,
  clinical,
  pediatric,
}

String normalizeScienceStatus(String raw) {
  final s = raw.trim().toLowerCase();
  if (s == 'pending' || s == 'review' || s == 'draft') return 'pending_review';
  if (s == 'approved' || s == 'approve') return 'published';
  if (s == 'withdrawn' || s == 'unpublished') return 'rejected';
  if (kScientificResearchStatuses.contains(s)) return s;
  return s;
}

String normalizeTreatmentPotential(String raw) {
  return raw.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
}

bool isBlankOrUnspecified(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return true;
  final lower = s.toLowerCase();
  return lower == 'çalışmada belirtilmemiş' ||
      lower == 'belirtilmemiş' ||
      lower == 'unspecified' ||
      lower == 'n/a' ||
      lower == 'na' ||
      lower == 'null';
}

const kScientificResearchTitleTrFallback =
    'Kaynak başlığı aşağıdadır; özet çevrilemedi.';

final _trTitleChars = RegExp(r'[çğıöşüÇĞİÖŞÜ]');
final _trTitleWords = RegExp(
  r'\b(ve|bir|ile|bu|olan|için|icin|çalışma|calisma|deneme|özet|ozet|çocuk|cocuk|serebral|palsi|tedavi|rehabilitasyon|hayvan|insan|faz|klinik|erken|küçük|kucuk|örneklem|orneklem|sonuç|sonuc|değil|degil|yok|var|başlık|baslik|kaynak|aşağıdadır|çevrilemedi|üzerine|yürüyüş)\b',
  caseSensitive: false,
);
final _enTitleWords = RegExp(
  r'\b(the|and|for|with|from|of|in|a|an|on|to|by|or|as|at|study|studies|trial|trials|review|effect|effects|children|child|infant|autism|treatment|therapy|clinical|patients?|disorder|syndrome|randomized|randomised|intervention|developmental|outcomes?|analysis|among|between|cerebral|palsy|stem|cells?|gait|training|efficacy|safety|phase|remyelination)\b',
  caseSensitive: false,
);
final _unicodeLetters = RegExp(r'\p{L}', unicode: true);
final _asciiLetters = RegExp(r'[A-Za-z]');

bool looksTurkishResearchCopy(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return false;
  if (_trTitleChars.hasMatch(s)) return true;
  return _trTitleWords.hasMatch(s);
}

bool looksEnglishResearchCopy(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return false;
  if (looksTurkishResearchCopy(s)) return false;
  if (!_enTitleWords.hasMatch(s)) return false;
  final letters = _unicodeLetters.allMatches(s).length;
  if (letters < 8) return false;
  final ascii = _asciiLetters.allMatches(s).length;
  return ascii / letters >= 0.9;
}

bool isScientificResearchesTableMissing(Object error) {
  final s = error.toString().toLowerCase();
  final mentionsTable = s.contains('scientific_researches') ||
      s.contains('scientific_research');
  final missing = s.contains('does not exist') ||
      s.contains('schema cache') ||
      s.contains('pgrst205') ||
      s.contains('42p01') ||
      s.contains('could not find the table');
  return missing && (mentionsTable || s.contains('pgrst205') || s.contains('42p01'));
}

String scientificResearchLoadError(Object error) {
  if (error is StateError) {
    final m = error.message;
    if (m == kScientificResearchesMissingSqlMessage ||
        m.contains('scientific_researches.sql')) {
      return m;
    }
    if (isScientificResearchesTableMissing(m)) {
      return kScientificResearchesMissingSqlMessage;
    }
    return m;
  }
  if (isScientificResearchesTableMissing(error)) {
    return kScientificResearchesMissingSqlMessage;
  }
  return error.toString();
}

/// Story görseli yoksa Onayla’dan önce foto gerekir (Instagram istisnası yok).
bool scientificResearchNeedsStoryImage(ScientificResearch item) {
  return item.imageUrl.trim().isEmpty;
}

String scientificResearchStoryImageUrl(ScientificResearch item) {
  return item.imageUrl.trim();
}

/// Story başlığı: Türkçe `title`. İngilizce `original_title` duyuruya yazılmaz.
String scientificResearchDuyuruTitle(
  ScientificResearch item, {
  String? title,
}) {
  const fallback = 'Bilimsel araştırma';
  final original = item.originalTitle.trim();
  bool usable(String raw) {
    final t = raw.trim();
    if (isBlankOrUnspecified(t)) return false;
    if (looksEnglishResearchCopy(t)) return false;
    if (original.isNotEmpty && t.toLowerCase() == original.toLowerCase()) {
      return false;
    }
    return true;
  }

  final override = (title ?? '').trim();
  if (usable(override)) return override;
  if (usable(item.title)) return item.title.trim();
  return fallback;
}

/// Duyuru gövdesi: Türkçe özet. "Tedavi bulundu" üretilmez.
String scientificResearchDuyuruBody(
  ScientificResearch item, {
  String? summary,
}) {
  final s = (summary ?? item.summary).trim();
  if (!isBlankOrUnspecified(s)) return s;
  if (!isBlankOrUnspecified(item.whyImportant)) {
    return item.whyImportant.trim();
  }
  return item.sourceUrl.trim();
}

/// Onayla → addDuyuru alanları (notify = fırsat / birey paylaşınca).
({
  String title,
  String body,
  String imageUrl,
  String? sourceUrl,
  bool requireImage,
  bool notify,
}) scientificResearchToDuyuruDraft(
  ScientificResearch item, {
  String imageUrl = '',
  String? title,
  String? summary,
}) {
  var photo = imageUrl.trim();
  if (photo.isEmpty) photo = scientificResearchStoryImageUrl(item);
  final src = item.sourceUrl.trim();
  return (
    title: scientificResearchDuyuruTitle(item, title: title),
    body: scientificResearchDuyuruBody(item, summary: summary),
    imageUrl: photo,
    sourceUrl: src.isEmpty ? null : src,
    requireImage: true,
    notify: kScientificResearchApproveNotify,
  );
}

void ensureScientificResearchStoryImage(String imageUrl) {
  if (imageUrl.trim().isEmpty) {
    throw StateError(kScientificResearchApproveNeedImageMessage);
  }
}

bool isScientificResearchImageUrlColumnMissing(Object error) {
  final s = error.toString().toLowerCase();
  if (!s.contains('image_url')) return false;
  return s.contains('does not exist') ||
      s.contains('schema cache') ||
      s.contains('pgrst204') ||
      s.contains('42703');
}

/// Onay yaması: status. image_url ayrı eklenir (kolon yoksa düşülür).
Map<String, dynamic> scientificResearchApprovePatch() {
  return const {'status': 'published'};
}

Map<String, dynamic> scientificResearchRejectPatch() {
  return const {'status': 'rejected'};
}

/// Yayından kaldır: withdrawn kolonu yok; rejected kullanılır.
Map<String, dynamic> scientificResearchUnpublishPatch() {
  return const {'status': 'rejected'};
}

bool isHighTreatmentPotential(ScientificResearch item) {
  if (normalizeTreatmentPotential(item.treatmentPotential) == 'HIGH_VALUE') {
    return true;
  }
  final scores = <int?>[
    item.treatmentPotentialScore,
    item.clinicalReadinessScore,
  ];
  return scores.any((s) => s != null && s >= kHighTreatmentScoreThreshold);
}

bool isClinicalResearch(ScientificResearch item) {
  if (item.nctId.trim().isNotEmpty) return true;
  final blob = [
    item.studyType,
    item.sourceName,
    item.sourceUrl,
    ...item.categories,
  ].join(' ').toLowerCase();
  return blob.contains('clinical') ||
      blob.contains('klinik') ||
      blob.contains('trial') ||
      blob.contains('clinicaltrials') ||
      blob.contains('nct');
}

bool isPediatricResearch(ScientificResearch item) {
  final blob = [
    item.pediatricRelevance,
    item.title,
    item.summary,
    ...item.categories,
    ...item.conditions,
  ].join(' ').toLowerCase();
  const keys = <String>[
    'çocuk',
    'cocuk',
    'pediatric',
    'paediatric',
    'pediatri',
    'infant',
    'neonat',
    'child',
    'children',
    'newborn',
    'yenidoğan',
    'yenidogan',
    'bebek',
  ];
  if (keys.any(blob.contains)) return true;
  final p = item.pediatricRelevance.trim().toLowerCase();
  if (isBlankOrUnspecified(p)) return false;
  return p.contains('high') ||
      p.contains('yes') ||
      p.contains('evet') ||
      p.contains('relevant');
}

bool matchesScienceAdminFilter(
  ScientificResearch item,
  ScienceAdminFilter filter,
) {
  switch (filter) {
    case ScienceAdminFilter.pending:
      return item.status == 'pending_review';
    case ScienceAdminFilter.published:
      return item.status == 'published';
    case ScienceAdminFilter.rejected:
      return item.status == 'rejected';
    case ScienceAdminFilter.highValue:
      return isHighTreatmentPotential(item);
    case ScienceAdminFilter.clinical:
      return isClinicalResearch(item);
    case ScienceAdminFilter.pediatric:
      return isPediatricResearch(item);
  }
}

/// Aşama etiketi. "Tedavi bulundu" asla üretilmez.
String scienceStageLabel(ScientificResearch item) {
  final parts = <String>[];
  final ha = item.humanOrAnimal.trim().toLowerCase();
  if (ha.contains('animal') ||
      ha.contains('hayvan') ||
      ha.contains('in vitro') ||
      ha.contains('in-vitro') ||
      ha.contains('invitro')) {
    parts.add('Hayvan');
  } else if (ha.contains('both') || ha.contains('her ikisi')) {
    parts.add('İnsan + hayvan');
  } else if (ha.contains('human') || ha.contains('insan')) {
    parts.add('İnsan');
  }

  final phase = normalizeSciencePhase(item.studyPhase);
  if (phase.isNotEmpty) parts.add(phase);
  if (parts.isEmpty) return 'Aşama belirtilmemiş';
  return parts.join(' · ');
}

String normalizeSciencePhase(String raw) {
  if (isBlankOrUnspecified(raw)) return '';
  final s = raw.trim().toLowerCase();
  if (RegExp(r'(phase|faz)\s*(1|i)\b').hasMatch(s)) return 'Faz 1';
  if (RegExp(r'(phase|faz)\s*(2|ii)\b').hasMatch(s)) return 'Faz 2';
  if (RegExp(r'(phase|faz)\s*(3|iii)\b').hasMatch(s)) return 'Faz 3';
  if (RegExp(r'(phase|faz)\s*(4|iv)\b').hasMatch(s)) return 'Faz 4';
  if (s.contains('preclinical') || s.contains('klinik öncesi')) {
    return 'Klinik öncesi';
  }
  return raw.trim();
}

class ScientificResearch {
  const ScientificResearch({
    required this.id,
    required this.title,
    required this.originalTitle,
    required this.summary,
    required this.whyImportant,
    required this.limitations,
    required this.conditions,
    required this.categories,
    required this.studyType,
    required this.evidenceLevel,
    required this.studyPhase,
    required this.humanOrAnimal,
    required this.pediatricRelevance,
    this.relevanceScore,
    this.scientificImportanceScore,
    this.treatmentPotentialScore,
    this.clinicalReadinessScore,
    required this.treatmentPotential,
    required this.recruitmentStatus,
    this.publicationDate,
    required this.country,
    required this.journal,
    required this.doi,
    required this.pmid,
    required this.nctId,
    required this.sourceName,
    required this.sourceUrl,
    this.imageUrl = '',
    this.externalId,
    required this.contentHash,
    required this.status,
    required this.aiNotes,
    this.createdAt,
  });

  final String id;
  final String title;
  final String originalTitle;
  final String summary;
  final String whyImportant;
  final String limitations;
  final List<String> conditions;
  final List<String> categories;
  final String studyType;
  final String evidenceLevel;
  final String studyPhase;
  final String humanOrAnimal;
  final String pediatricRelevance;
  final int? relevanceScore;
  final int? scientificImportanceScore;
  final int? treatmentPotentialScore;
  final int? clinicalReadinessScore;
  final String treatmentPotential;
  final String recruitmentStatus;
  final DateTime? publicationDate;
  final String country;
  final String journal;
  final String doi;
  final String pmid;
  final String nctId;
  final String sourceName;
  final String sourceUrl;
  final String imageUrl;
  final String? externalId;
  final String contentHash;
  final String status;
  final String aiNotes;
  final DateTime? createdAt;

  /// Türkçe `title` varsa onu; İngilizce title asla birincil başlık değil.
  String get displayTitle {
    final t = title.trim();
    if (!isBlankOrUnspecified(t) && looksTurkishResearchCopy(t)) return t;
    if (!isBlankOrUnspecified(t) && !looksEnglishResearchCopy(t)) return t;
    return kScientificResearchTitleTrFallback;
  }

  String get stageLabel => scienceStageLabel(this);

  ScientificResearch copyWith({
    String? title,
    String? summary,
    String? status,
    String? imageUrl,
  }) =>
      ScientificResearch(
        id: id,
        title: title ?? this.title,
        originalTitle: originalTitle,
        summary: summary ?? this.summary,
        whyImportant: whyImportant,
        limitations: limitations,
        conditions: conditions,
        categories: categories,
        studyType: studyType,
        evidenceLevel: evidenceLevel,
        studyPhase: studyPhase,
        humanOrAnimal: humanOrAnimal,
        pediatricRelevance: pediatricRelevance,
        relevanceScore: relevanceScore,
        scientificImportanceScore: scientificImportanceScore,
        treatmentPotentialScore: treatmentPotentialScore,
        clinicalReadinessScore: clinicalReadinessScore,
        treatmentPotential: treatmentPotential,
        recruitmentStatus: recruitmentStatus,
        publicationDate: publicationDate,
        country: country,
        journal: journal,
        doi: doi,
        pmid: pmid,
        nctId: nctId,
        sourceName: sourceName,
        sourceUrl: sourceUrl,
        imageUrl: imageUrl ?? this.imageUrl,
        externalId: externalId,
        contentHash: contentHash,
        status: status ?? this.status,
        aiNotes: aiNotes,
        createdAt: createdAt,
      );

  factory ScientificResearch.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(Object? raw) {
      final s = raw?.toString().trim() ?? '';
      if (s.isEmpty) return null;
      return DateTime.tryParse(s)?.toLocal();
    }

    int? parseScore(Object? raw) {
      if (raw == null) return null;
      if (raw is int) return raw;
      if (raw is num) return raw.round();
      return int.tryParse(raw.toString().trim());
    }

    List<String> parseList(Object? raw) {
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    return ScientificResearch(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString().trim() ?? '',
      originalTitle: json['original_title']?.toString().trim() ?? '',
      summary: json['summary']?.toString().trim() ?? '',
      whyImportant: json['why_important']?.toString().trim() ?? '',
      limitations: json['limitations']?.toString().trim() ?? '',
      conditions: parseList(json['conditions']),
      categories: parseList(json['categories']),
      studyType: json['study_type']?.toString().trim() ?? '',
      evidenceLevel: json['evidence_level']?.toString().trim() ?? '',
      studyPhase: json['study_phase']?.toString().trim() ?? '',
      humanOrAnimal: json['human_or_animal']?.toString().trim() ?? '',
      pediatricRelevance: json['pediatric_relevance']?.toString().trim() ?? '',
      relevanceScore: parseScore(json['relevance_score']),
      scientificImportanceScore:
          parseScore(json['scientific_importance_score']),
      treatmentPotentialScore: parseScore(json['treatment_potential_score']),
      clinicalReadinessScore: parseScore(json['clinical_readiness_score']),
      treatmentPotential: normalizeTreatmentPotential(
        json['treatment_potential']?.toString() ?? '',
      ),
      recruitmentStatus: json['recruitment_status']?.toString().trim() ?? '',
      publicationDate: parseTs(json['publication_date']),
      country: json['country']?.toString().trim() ?? '',
      journal: json['journal']?.toString().trim() ?? '',
      doi: json['doi']?.toString().trim() ?? '',
      pmid: json['pmid']?.toString().trim() ?? '',
      nctId: json['nct_id']?.toString().trim() ?? '',
      sourceName: json['source_name']?.toString().trim() ?? '',
      sourceUrl: json['source_url']?.toString().trim() ?? '',
      imageUrl: json['image_url']?.toString().trim() ?? '',
      externalId: json['external_id']?.toString().trim(),
      contentHash: json['content_hash']?.toString().trim() ?? '',
      status: normalizeScienceStatus(
        json['status']?.toString() ?? 'pending_review',
      ),
      aiNotes: json['ai_notes']?.toString().trim() ?? '',
      createdAt: parseTs(json['created_at']),
    );
  }
}
