import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medicine_report.dart';
import '../utils/async_timeout.dart';
import 'gemini_service.dart';
import 'open_food_facts_service.dart';
import 'r2_storage_service.dart';

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
      'Bu barkod ilaç önbelleğinde yok. Küpür veya prospektüs fotoğrafı çekin.';

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
    final ean = OpenFoodFactsService.normalizeBarcode(barcode) ??
        (barcode.trim().length >= 4 ? barcode.trim() : null);

    if (!hasPhoto && text.isEmpty && ean == null) {
      return const MedicineLookupResult(
        error: 'Barkod veya küpür / prospektüs fotoğrafı gerekli.',
        needsPhoto: true,
      );
    }

    try {
      if (ean != null) {
        final cached = await findByBarcode(ean);
        if (cached != null && cached.isComplete && !hasPhoto) {
          return MedicineLookupResult(
            record: cached,
            barcode: ean,
            fromCache: true,
          );
        }
      }

      if (!hasPhoto && text.isEmpty) {
        return MedicineLookupResult(
          barcode: ean,
          needsPhoto: true,
          error: needsPhotoMessage,
        );
      }

      if (!GeminiService.hasVision && !GeminiService.canCall) {
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

      final llm = await GeminiService.analyzeMedicine(
        barcode: ean ?? '',
        ocrText: text,
        imageBytes: photoBytes,
        imageMimeType: imageContentType,
      );
      var record = llm.record;
      if (record == null || !record.isFound) {
        final err = llm.error ??
            GeminiService.lastError ??
            'Küpür / prospektüs okunamadı. Daha net bir fotoğraf deneyin.';
        return MedicineLookupResult(
          barcode: ean,
          error: err,
          needsKey: GeminiService.isTransportError(err) &&
              err.toLowerCase().contains('anahtar'),
        );
      }

      if (imageUrl != null) {
        record = record.copyWith(imageUrl: imageUrl);
      }
      if (ean != null && (record.barcode ?? '').trim().isEmpty) {
        record = record.copyWith(barcode: ean);
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
    final code = barcode.trim();
    if (code.length < 4) return null;
    try {
      final row = await withNetworkTimeout(
        _db.from('medicines').select().eq('barcode', code).maybeSingle(),
        message: 'İlaç önbelleği okunamadı.',
      );
      if (row == null) return null;
      return MedicineRecord.fromJson(row, fromCache: true);
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
            source: 'cache',
          ),
        );
      }
    } catch (e, st) {
      debugPrint('medicines ada arama: $e\n$st');
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

    if (!GeminiService.canCall) {
      return const MedicineLookupResult(
        needsKey: true,
        error: needsKeyMessage,
      );
    }

    try {
      final llm = await GeminiService.analyzeMedicine(medicineName: name);
      var record = llm.record;
      if (record == null || !record.isFound) {
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
      if (_isMissingInteractionsColumn(e)) {
        return _insertWithoutInteractions(medicine);
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

  /// SQL henüz çalışmadıysa (drug_interactions yok) eski sütunlarla yaz.
  static Future<MedicineRecord> _insertWithoutInteractions(
    MedicineRecord medicine,
  ) async {
    final payload = Map<String, dynamic>.from(medicine.toInsertJson())
      ..remove('drug_interactions');
    try {
      final row = await withNetworkTimeout(
        _db.from('medicines').insert(payload).select().single(),
        message: 'İlaç önbelleğe yazılamadı.',
      );
      return MedicineRecord.fromJson(row, fromCache: true)
          .copyWith(drugInteractions: medicine.drugInteractions);
    } on PostgrestException catch (e) {
      debugPrint('medicines INSERT (no interactions col): ${e.message}');
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
      if (_isMissingInteractionsColumn(e)) {
        return _updateWithoutInteractions(id, medicine);
      }
      debugPrint('medicines UPDATE atlandı: ${e.message}');
      return medicine;
    } catch (e, st) {
      debugPrint('medicines UPDATE atlandı: $e\n$st');
      return medicine;
    }
  }

  static Future<MedicineRecord> _updateWithoutInteractions(
    String id,
    MedicineRecord medicine,
  ) async {
    final payload = Map<String, dynamic>.from(medicine.toInsertJson())
      ..remove('drug_interactions');
    try {
      final row = await withNetworkTimeout(
        _db.from('medicines').update(payload).eq('id', id).select().maybeSingle(),
        message: 'İlaç önbelleği güncellenemedi.',
      );
      if (row != null) {
        return MedicineRecord.fromJson(row, fromCache: true)
            .copyWith(drugInteractions: medicine.drugInteractions);
      }
      return medicine;
    } on PostgrestException catch (e) {
      debugPrint('medicines UPDATE (no interactions col): ${e.message}');
      return medicine;
    }
  }

  static bool _isMissingInteractionsColumn(PostgrestException e) {
    final m = '${e.message} ${e.code} ${e.details}'.toLowerCase();
    return m.contains('drug_interactions') &&
        (m.contains('does not exist') ||
            m.contains('schema cache') ||
            m.contains('pgrst204') ||
            e.code == 'PGRST204' ||
            e.code == '42703');
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
