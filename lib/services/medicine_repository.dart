import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medicine_report.dart';
import '../utils/async_timeout.dart';
import '../utils/gs1_barcode.dart';
import 'gemini_service.dart';
import 'open_food_facts_service.dart';
import 'r2_storage_service.dart';
import 'titck_kubkt_service.dart';
import 'titck_skrs_index.dart';

class MedicineLookupResult {
  const MedicineLookupResult({
    this.record,
    this.error,
    this.barcode,
    this.fromCache = false,
    this.needsPhoto = false,
    this.needsKey = false,
  });

  final MedicineRecord? record;
  final String? error;
  final String? barcode;
  final bool fromCache;
  final bool needsPhoto;
  final bool needsKey;

  bool get isFound => record?.isFound == true;
}

class MedicineNameHit {
  const MedicineNameHit({
    required this.name,
    this.activeIngredient = '',
    this.record,
    this.source = 'cache',
  });

  final String name;
  final String activeIngredient;
  final MedicineRecord? record;
  final String source;
}

/// İlaç küpür / prospektüs önbelleği (Supabase `medicines`).
/// Gıda `products` tablosuna yazılmaz.
class MedicineRepository {
  MedicineRepository._();

  static const needsPhotoMessage =
      'Bu barkod için özet bulunamadı. İsterseniz küpür veya prospektüs fotoğrafı ekleyebilirsiniz (isteğe bağlı).';

  static const notInIndexMessage =
      'Bu karekod indeksde yok, etiket/küpür fotoğrafı deneyin.';

  static const needsKeyMessage =
      'Analiz anahtarı tanımlı değil (GEMINI_API_KEY veya proxy).';

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<MedicineLookupResult> lookup({
    String barcode = '',
    Uint8List? imageBytes,
    String imageContentType = 'image/jpeg',
    String? ocrText,
  }) async {
    final photoBytes =
        (imageBytes != null && imageBytes.isNotEmpty) ? imageBytes : null;
    final hasPhoto = photoBytes != null;
    final text = (ocrText ?? '').trim();
    final scannedUrl = Gs1Barcode.prospectusHttpUrl(barcode);
    final parsed = Gs1Barcode.lookupCode(barcode);
    final ean = parsed ??
        OpenFoodFactsService.normalizeBarcode(barcode) ??
        (barcode.trim().length >= 4 && barcode.trim().length <= 18
            ? barcode.trim()
            : null);

    if (!hasPhoto && text.isEmpty && ean == null && scannedUrl == null) {
      return const MedicineLookupResult(
        error: 'Barkod veya küpür / prospektüs fotoğrafı gerekli.',
        needsPhoto: true,
      );
    }

    try {
      MedicineRecord? cached;
      if (ean != null) {
        cached = await findByBarcode(ean);
        if (cached != null && cached.isComplete && !hasPhoto) {
          var withUrl = cached;
          if (scannedUrl != null &&
              scannedUrl.trim().isNotEmpty &&
              (cached.prospectusUrl ?? '').trim().isEmpty) {
            withUrl = cached.copyWith(prospectusUrl: scannedUrl.trim());
            if (cached.id != null) {
              withUrl = await _updateById(
                cached.id!,
                withUrl.copyWith(id: cached.id),
              );
            }
          }
          return MedicineLookupResult(
            record: withUrl,
            barcode: ean,
            fromCache: true,
          );
        }
      }

      final skrs = ean == null ? null : await TitckSkrsIndex.findByBarcode(ean);
      var seed = cached;
      if (skrs != null) {
        debugPrint(
          'GTIN lookup used form=${TitckSkrsIndex.lastMatchForm} '
          'ean=$ean stored=${skrs.barcode}',
        );
        seed = _mergeIdentity(
          seed,
          _fromSkrs(skrs, barcode: ean, prospectusUrl: scannedUrl),
        );
      } else {
        if (ean != null) debugPrint('GTIN lookup index miss ean=$ean');
        if (scannedUrl != null && seed != null) {
          seed = seed.copyWith(prospectusUrl: scannedUrl);
        } else if (scannedUrl != null && seed == null) {
          seed = MedicineRecord(
            barcode: ean,
            medicineName:
                ean == null ? 'Elektronik kullanma talimatı' : '',
            prospectusUrl: scannedUrl,
            source: 'titck',
          );
        }
      }

      if (seed != null &&
          seed.medicineName.trim().isNotEmpty &&
          (seed.prospectusUrl == null || seed.prospectusUrl!.trim().isEmpty)) {
        seed = await _attachLeaflet(seed);
      }

      // GTIN / SKRS kimliği bulundu. Özet tam ise Gemini’ye gitme;
      // eksikse aşağıdaki yol ne işe yarar / etkileşim kartlarını doldurur.
      if (seed != null &&
          seed.isFound &&
          seed.isComplete &&
          !hasPhoto &&
          text.isEmpty) {
        if ((seed.prospectusUrl == null ||
                seed.prospectusUrl!.trim().isEmpty) &&
            seed.medicineName.trim().isNotEmpty) {
          seed = await _attachLeaflet(seed);
        }
        final stored = await save(seed);
        return MedicineLookupResult(
          record: stored,
          barcode: stored.barcode ?? ean,
          fromCache: cached != null,
        );
      }

      final thin = seed == null || !seed.isComplete;
      if (thin &&
          !hasPhoto &&
          text.isEmpty &&
          !GeminiService.canCall &&
          seed != null &&
          seed.isFound) {
        final stored = await save(seed);
        return MedicineLookupResult(
          record: stored,
          barcode: stored.barcode ?? ean,
          fromCache: false,
        );
      }

      if (thin && !hasPhoto && text.isEmpty && ean != null && !GeminiService.canCall) {
        if (seed != null && seed.isFound) {
          final stored = await save(seed);
          return MedicineLookupResult(
            record: stored,
            barcode: stored.barcode ?? ean,
            fromCache: false,
          );
        }
        return MedicineLookupResult(
          barcode: ean,
          needsKey: true,
          error: needsKeyMessage,
        );
      }

      if (thin && !GeminiService.hasVision && !GeminiService.canCall) {
        if (seed != null && seed.isFound) {
          final stored = await save(seed);
          return MedicineLookupResult(
            record: stored,
            barcode: stored.barcode ?? ean,
            fromCache: false,
          );
        }
        return MedicineLookupResult(
          barcode: ean,
          needsKey: true,
          error: needsKeyMessage,
        );
      }

      String? imageUrl;
      if (photoBytes != null) {
        try {
          imageUrl = await _uploadLabel(
            code: ean ?? 'photo',
            bytes: photoBytes,
            contentType: imageContentType,
          );
        } catch (e, st) {
          debugPrint('R2 ilaç görseli atlandı, Gemini devam: $e\n$st');
        }
      }

      MedicineRecord? record = seed;
      if (thin && (GeminiService.canCall || hasPhoto)) {
        final llm = await GeminiService.analyzeMedicine(
          barcode: ean ?? '',
          ocrText: text,
          medicineName: seed?.medicineName ?? '',
          imageBytes: photoBytes,
          imageMimeType: imageContentType,
        );
        if (llm.record != null && llm.record!.isFound) {
          record = _mergeProspectus(seed, llm.record!);
        } else if (seed == null || !seed.isFound) {
          final err = llm.error ??
              GeminiService.lastError ??
              (hasPhoto
                  ? 'Küpür / prospektüs okunamadı. Daha net bir fotoğraf deneyin.'
                  : notInIndexMessage);
          return MedicineLookupResult(
            barcode: ean,
            error: !hasPhoto && (ean ?? '').isNotEmpty
                ? notInIndexMessage
                : err,
            needsPhoto: !hasPhoto,
            needsKey: GeminiService.isTransportError(err) &&
                err.toLowerCase().contains('anahtar'),
          );
        }
      }

      if (record == null || !record.isFound) {
        return MedicineLookupResult(
          barcode: ean,
          error: (!hasPhoto && (ean ?? '').isNotEmpty)
              ? notInIndexMessage
              : needsPhotoMessage,
          needsPhoto: !hasPhoto,
        );
      }

      if (imageUrl != null) {
        record = record.copyWith(imageUrl: imageUrl);
      }
      if (ean != null && (record.barcode ?? '').trim().isEmpty) {
        record = record.copyWith(barcode: ean);
      }
      if (scannedUrl != null &&
          (record.prospectusUrl == null ||
              record.prospectusUrl!.trim().isEmpty)) {
        record = record.copyWith(prospectusUrl: scannedUrl);
      }
      if ((record.prospectusUrl == null ||
              record.prospectusUrl!.trim().isEmpty) &&
          record.medicineName.trim().isNotEmpty) {
        record = await _attachLeaflet(record);
      }

      final stored = await save(record);
      return MedicineLookupResult(
        record: stored,
        barcode: stored.barcode ?? ean,
        fromCache: false,
      );
    } catch (e, st) {
      debugPrint('İlaç arama hatası: $e\n$st');
      return MedicineLookupResult(
        barcode: ean,
        error: 'Arama hatası: $e',
      );
    }
  }

  static Future<MedicineRecord?> findByBarcode(String barcode) async {
    final keys = <String>{};
    for (final cand in Gs1Barcode.lookupCandidates(barcode)) {
      keys.addAll(Gs1Barcode.cacheKeys(cand.value));
    }
    keys.removeWhere((c) => c.length < 4);
    if (keys.isEmpty) return null;
    try {
      final rows = await withNetworkTimeout(
        _db.from('medicines').select().inFilter('barcode', keys.toList()).limit(1),
        message: 'İlaç önbelleği okunamadı.',
      );
      if (rows.isEmpty) return null;
      return MedicineRecord.fromJson(
        Map<String, dynamic>.from(rows.first),
        fromCache: true,
      );
    } on PostgrestException catch (e) {
      debugPrint('medicines SELECT: ${e.message}');
      return null;
    }
  }

  /// Aynı ad, barkodsuz kayıt (isteğe bağlı eşleşme).
  static Future<MedicineRecord?> findByNameWithoutBarcode(String name) async {
    final n = name.trim();
    if (n.length < 2) return null;
    try {
      final rows = await withNetworkTimeout(
        _db
            .from('medicines')
            .select()
            .ilike('medicine_name', n)
            .isFilter('barcode', null)
            .limit(1),
        message: 'İlaç adı önbelleği okunamadı.',
      );
      if (rows.isEmpty) return null;
      return MedicineRecord.fromJson(
        Map<String, dynamic>.from(rows.first),
        fromCache: true,
      );
    } on PostgrestException catch (e) {
      debugPrint('medicines name SELECT: ${e.message}');
      return null;
    }
  }

  static String _ilikeContains(String raw) {
    final s = raw
        .trim()
        .replaceAll('%', '')
        .replaceAll('_', '')
        .replaceAll(',', ' ')
        .replaceAll("'", '')
        .replaceAll(RegExp(r'\s+'), ' ');
    return '%$s%';
  }

  static String _normName(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Ada göre önbellek (Gemini yok). `medicine_name` ILIKE.
  static Future<List<MedicineNameHit>> searchByName(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final hits = <MedicineNameHit>[];
    final seen = <String>{};

    void add(MedicineNameHit hit) {
      final key = _normName(hit.name);
      if (key.isEmpty || !seen.add(key)) return;
      hits.add(hit);
    }

    try {
      final pattern = _ilikeContains(q);
      final rows = await withNetworkTimeout(
        _db
            .from('medicines')
            .select()
            .ilike('medicine_name', pattern)
            .order('created_at', ascending: false)
            .limit(8),
        message: 'İlaç adı araması yanıt vermedi.',
      );
      for (final row in rows) {
        final rec = MedicineRecord.fromJson(
          Map<String, dynamic>.from(row),
          fromCache: true,
        );
        final name = rec.medicineName.trim();
        if (name.isEmpty || !rec.isFound) continue;
        add(
          MedicineNameHit(
            name: name,
            activeIngredient: rec.activeIngredient.trim(),
            record: rec,
            source: rec.source == 'titck' ? 'titck' : 'cache',
          ),
        );
      }
    } catch (e, st) {
      debugPrint('medicines ada arama: $e\n$st');
    }

    if (hits.length < 8) {
      try {
        final skrs = await TitckSkrsIndex.searchByName(q, limit: 8);
        for (final hit in skrs) {
          add(
            MedicineNameHit(
              name: hit.name,
              activeIngredient: hit.activeIngredient,
              record: _fromSkrs(hit),
              source: 'titck',
            ),
          );
          if (hits.length >= 8) break;
        }
      } catch (e, st) {
        debugPrint('TİTCK SKRS ada arama: $e\n$st');
      }
    }
    return hits;
  }

  /// Yazılan ad → Gemini metin (fotoğraf yok) → `medicines` INSERT veya aynı ad.
  static Future<MedicineLookupResult> lookupByName(String rawName) async {
    final name = rawName.trim();
    if (name.length < 2) {
      return const MedicineLookupResult(error: 'En az 2 karakter yazın.');
    }

    final exact = await findByNameWithoutBarcode(name);
    if (exact != null && exact.isComplete) {
      return MedicineLookupResult(record: exact, fromCache: true);
    }

    TitckSkrsHit? skrsHit;
    try {
      final skrsHits = await TitckSkrsIndex.searchByName(name, limit: 1);
      if (skrsHits.isNotEmpty) skrsHit = skrsHits.first;
    } catch (e, st) {
      debugPrint('TİTCK SKRS ad: $e\n$st');
    }

    var seed = exact;
    if (skrsHit != null) {
      seed = _mergeIdentity(seed, _fromSkrs(skrsHit));
    }

    if (!GeminiService.canCall) {
      if (seed != null && seed.isFound) {
        final stored = await save(seed);
        return MedicineLookupResult(record: stored, fromCache: false);
      }
      return const MedicineLookupResult(
        needsKey: true,
        error: needsKeyMessage,
      );
    }

    try {
      final llm = await GeminiService.analyzeMedicine(
        medicineName: seed?.medicineName.trim().isNotEmpty == true
            ? seed!.medicineName.trim()
            : name,
        barcode: seed?.barcode ?? '',
      );
      var record = llm.record;
      if (record == null || !record.isFound) {
        if (seed != null && seed.isFound) {
          record = await _attachLeaflet(seed);
          final stored = await save(record);
          return MedicineLookupResult(
            record: stored,
            barcode: stored.barcode,
            fromCache: false,
          );
        }
        final err = llm.error ?? GeminiService.lastError;
        if (GeminiService.isTransportError(err)) {
          return MedicineLookupResult(
            error: err,
            needsKey: (err ?? '').toLowerCase().contains('anahtar'),
          );
        }
        return MedicineLookupResult(
          error: err ??
              'Bu ada yakın ilaç bilgisi bulunamadı. '
                  'İsterseniz küpür fotoğrafı ekleyebilirsiniz (isteğe bağlı).',
        );
      }
      if (record.medicineName.trim().isEmpty) {
        record = record.copyWith(medicineName: name);
      }
      record = _mergeProspectus(seed, record);
      if ((record.prospectusUrl == null ||
              record.prospectusUrl!.trim().isEmpty) &&
          record.medicineName.trim().isNotEmpty) {
        record = await _attachLeaflet(record);
      }
      final stored = await save(record);
      return MedicineLookupResult(
        record: stored,
        barcode: stored.barcode,
        fromCache: false,
      );
    } catch (e, st) {
      debugPrint('İlaç adı Gemini: $e\n$st');
      return MedicineLookupResult(error: 'Arama hatası: $e');
    }
  }

  static MedicineRecord _fromSkrs(
    TitckSkrsHit hit, {
    String? barcode,
    String? prospectusUrl,
  }) {
    return MedicineRecord(
      barcode: (barcode ?? hit.barcode).trim().isEmpty
          ? null
          : (barcode ?? hit.barcode).trim(),
      medicineName: hit.name,
      activeIngredient: hit.activeIngredient,
      prospectusUrl: prospectusUrl,
      source: 'titck',
      rawReport: {
        'titck_skrs': true,
        'public_index': true,
        'barcode': hit.barcode,
        if (TitckSkrsIndex.lastMatchForm != null)
          'gtin_form': TitckSkrsIndex.lastMatchForm,
      },
    );
  }

  static MedicineRecord _mergeIdentity(
    MedicineRecord? existing,
    MedicineRecord incoming,
  ) {
    if (existing == null) return incoming;
    return existing.copyWith(
      barcode: (existing.barcode ?? '').trim().length >= 4
          ? existing.barcode
          : incoming.barcode,
      medicineName: existing.medicineName.trim().isNotEmpty
          ? existing.medicineName
          : incoming.medicineName,
      activeIngredient: existing.activeIngredient.trim().isNotEmpty
          ? existing.activeIngredient
          : incoming.activeIngredient,
      prospectusUrl: (existing.prospectusUrl ?? '').trim().isNotEmpty
          ? existing.prospectusUrl
          : incoming.prospectusUrl,
      source: existing.source.trim().isNotEmpty
          ? existing.source
          : incoming.source,
    );
  }

  static MedicineRecord _mergeProspectus(
    MedicineRecord? identity,
    MedicineRecord prospectus,
  ) {
    if (identity == null) return prospectus;
    final name = identity.medicineName.trim().isNotEmpty
        ? identity.medicineName
        : prospectus.medicineName;
    final ingredient = prospectus.activeIngredient.trim().isNotEmpty
        ? prospectus.activeIngredient
        : identity.activeIngredient;
    final raw = <String, dynamic>{
      ...identity.rawReport,
      ...prospectus.rawReport,
      if (identity.source == 'titck') 'titck_skrs': true,
    };
    return prospectus.copyWith(
      id: identity.id,
      barcode: (identity.barcode ?? '').trim().length >= 4
          ? identity.barcode
          : prospectus.barcode,
      medicineName: name,
      activeIngredient: ingredient,
      indications: prospectus.indications.trim().isNotEmpty
          ? prospectus.indications
          : identity.indications,
      usageText: prospectus.usageText.trim().isNotEmpty
          ? prospectus.usageText
          : identity.usageText,
      sideEffects: prospectus.sideEffects.isNotEmpty
          ? prospectus.sideEffects
          : identity.sideEffects,
      drugInteractions: prospectus.drugInteractions.isNotEmpty
          ? prospectus.drugInteractions
          : identity.drugInteractions,
      safetyWarnings: prospectus.safetyWarnings.trim().isNotEmpty
          ? prospectus.safetyWarnings
          : identity.safetyWarnings,
      prospectusUrl: (identity.prospectusUrl ?? '').trim().isNotEmpty
          ? identity.prospectusUrl
          : prospectus.prospectusUrl,
      imageUrl: (prospectus.imageUrl ?? '').trim().isNotEmpty
          ? prospectus.imageUrl
          : identity.imageUrl,
      rawReport: raw,
      source: prospectus.isComplete ? 'llm' : identity.source,
    );
  }

  static Future<MedicineRecord> _attachLeaflet(MedicineRecord record) async {
    if ((record.prospectusUrl ?? '').trim().isNotEmpty) return record;
    final name = record.medicineName.trim();
    if (name.length < 3) return record;
    final leaflet = await TitckKubktService.findLeaflet(name);
    final url = leaflet?.prospectusUrl;
    if (url == null || url.isEmpty) return record;
    final ingredient = record.activeIngredient.trim().isNotEmpty
        ? record.activeIngredient
        : (leaflet!.activeIngredient);
    return record.copyWith(
      prospectusUrl: url,
      activeIngredient: ingredient,
    );
  }

  static Future<MedicineRecord> save(MedicineRecord medicine) async {
    final code = (medicine.barcode ?? '').trim();
    if (code.length >= 4) {
      final byCode = await findByBarcode(code);
      if (byCode != null && byCode.isComplete) {
        return byCode;
      }
      if (byCode != null && byCode.id != null) {
        return _updateById(byCode.id!, medicine.copyWith(id: byCode.id));
      }
    }

    final nameHit = await findByNameWithoutBarcode(medicine.medicineName);
    if (nameHit != null && nameHit.id != null) {
      final incomingHasImage = (medicine.imageUrl ?? '').trim().isNotEmpty;
      if (nameHit.isComplete && !incomingHasImage) {
        return nameHit;
      }
      return _updateById(
        nameHit.id!,
        medicine.copyWith(
          id: nameHit.id,
          barcode: code.length >= 4 ? code : nameHit.barcode,
          imageUrl: incomingHasImage ? medicine.imageUrl : nameHit.imageUrl,
        ),
      );
    }

    return insertIfAbsent(medicine);
  }

  static Future<MedicineRecord> insertIfAbsent(MedicineRecord medicine) async {
    final code = (medicine.barcode ?? '').trim();
    if (code.length >= 4) {
      final existing = await findByBarcode(code);
      if (existing != null) return existing;
    }

    try {
      final row = await withNetworkTimeout(
        _db
            .from('medicines')
            .insert(medicine.toInsertJson())
            .select()
            .single(),
        message: 'İlaç önbelleğe yazılamadı.',
      );
      return MedicineRecord.fromJson(row, fromCache: true);
    } on PostgrestException catch (e) {
      if (_isMissingColumn(e, 'drug_interactions') ||
          _isMissingColumn(e, 'prospectus_url') ||
          _isMissingColumn(e, 'indications')) {
        return _insertStripped(medicine, e);
      }
      if (_isSourceConstraint(e)) {
        return _insertStripped(
          medicine.copyWith(source: 'cache'),
          e,
        );
      }
      if (e.code == '23505' && code.length >= 4) {
        final again = await findByBarcode(code);
        if (again != null) return again;
      }
      debugPrint('medicines INSERT atlandı: ${e.message}');
      return medicine;
    } catch (e, st) {
      debugPrint('medicines INSERT atlandı: $e\n$st');
      return medicine;
    }
  }

  /// SQL henüz çalışmadıysa yeni sütunları düşürerek yaz.
  static Future<MedicineRecord> _insertStripped(
    MedicineRecord medicine,
    PostgrestException cause,
  ) async {
    final payload = Map<String, dynamic>.from(medicine.toInsertJson());
    if (_isMissingColumn(cause, 'drug_interactions')) {
      payload.remove('drug_interactions');
    }
    if (_isMissingColumn(cause, 'prospectus_url')) {
      payload.remove('prospectus_url');
    }
    if (_isMissingColumn(cause, 'indications')) {
      payload.remove('indications');
    }
    if (_isSourceConstraint(cause)) {
      payload['source'] = 'cache';
    }
    try {
      final row = await withNetworkTimeout(
        _db.from('medicines').insert(payload).select().single(),
        message: 'İlaç önbelleğe yazılamadı.',
      );
      return MedicineRecord.fromJson(row, fromCache: true).copyWith(
        drugInteractions: medicine.drugInteractions,
        indications: medicine.indications,
        prospectusUrl: medicine.prospectusUrl,
      );
    } on PostgrestException catch (e) {
      if ((_isMissingColumn(e, 'drug_interactions') ||
              _isMissingColumn(e, 'prospectus_url') ||
              _isMissingColumn(e, 'indications') ||
              _isSourceConstraint(e)) &&
          e.message != cause.message) {
        return _insertStripped(medicine, e);
      }
      debugPrint('medicines INSERT (stripped): ${e.message}');
      return medicine;
    }
  }

  static Future<MedicineRecord> _updateById(
    String id,
    MedicineRecord medicine,
  ) async {
    try {
      final row = await withNetworkTimeout(
        _db
            .from('medicines')
            .update(medicine.toInsertJson())
            .eq('id', id)
            .select()
            .maybeSingle(),
        message: 'İlaç önbelleği güncellenemedi.',
      );
      if (row != null) {
        return MedicineRecord.fromJson(row, fromCache: true);
      }
      debugPrint('medicines UPDATE boş döndü (RLS veya satır yok).');
      return medicine;
    } on PostgrestException catch (e) {
      if (_isMissingColumn(e, 'drug_interactions') ||
          _isMissingColumn(e, 'prospectus_url') ||
          _isMissingColumn(e, 'indications') ||
          _isSourceConstraint(e)) {
        return _updateStripped(id, medicine, e);
      }
      debugPrint('medicines UPDATE atlandı: ${e.message}');
      return medicine;
    } catch (e, st) {
      debugPrint('medicines UPDATE atlandı: $e\n$st');
      return medicine;
    }
  }

  static Future<MedicineRecord> _updateStripped(
    String id,
    MedicineRecord medicine,
    PostgrestException cause,
  ) async {
    final payload = Map<String, dynamic>.from(medicine.toInsertJson());
    if (_isMissingColumn(cause, 'drug_interactions')) {
      payload.remove('drug_interactions');
    }
    if (_isMissingColumn(cause, 'prospectus_url')) {
      payload.remove('prospectus_url');
    }
    if (_isMissingColumn(cause, 'indications')) {
      payload.remove('indications');
    }
    if (_isSourceConstraint(cause)) {
      payload['source'] = 'cache';
    }
    try {
      final row = await withNetworkTimeout(
        _db.from('medicines').update(payload).eq('id', id).select().maybeSingle(),
        message: 'İlaç önbelleği güncellenemedi.',
      );
      if (row != null) {
        return MedicineRecord.fromJson(row, fromCache: true).copyWith(
          drugInteractions: medicine.drugInteractions,
          indications: medicine.indications,
          prospectusUrl: medicine.prospectusUrl,
        );
      }
      return medicine;
    } on PostgrestException catch (e) {
      debugPrint('medicines UPDATE (stripped): ${e.message}');
      return medicine;
    }
  }

  static bool _isMissingColumn(PostgrestException e, String column) {
    final m = '${e.message} ${e.code} ${e.details}'.toLowerCase();
    return m.contains(column.toLowerCase()) &&
        (m.contains('does not exist') ||
            m.contains('schema cache') ||
            m.contains('pgrst204') ||
            e.code == 'PGRST204' ||
            e.code == '42703');
  }

  static bool _isSourceConstraint(PostgrestException e) {
    final m = '${e.message} ${e.code} ${e.details}'.toLowerCase();
    return m.contains('medicines_source_chk') ||
        (m.contains('source') &&
            (m.contains('violat') || m.contains('check')));
  }

  static Future<String?> _uploadLabel({
    required String code,
    required Uint8List bytes,
    required String contentType,
  }) {
    final key =
        'medicine-labels/$code/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return R2StorageService.upload(
      bytes: bytes,
      objectKey: key,
      contentType: contentType,
    );
  }
}
