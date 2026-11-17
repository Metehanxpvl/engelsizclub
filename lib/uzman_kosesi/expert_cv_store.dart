import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../kredi_store.dart';
import '../uzman_kosesi_profiles_store.dart';
import '../utils/async_timeout.dart';
import 'expert_cv_models.dart';
import 'uzman_kosesi_notify.dart';

bool _ready() {
  try {
    return Supabase.instance.isInitialized;
  } catch (_) {
    return false;
  }
}

Future<List<MeslekGrubu>> loadMeslekGruplari({
  bool includeInactive = false,
}) async {
  if (!_ready()) return const [];
  try {
    var q = Supabase.instance.client.from('meslek_gruplari').select();
    if (!includeInactive) q = q.eq('aktif', true);
    final rows = await withNetworkTimeout(q.order('sira'));
    final raw = rows is List ? rows : const [];
    return [
      for (final e in raw.whereType<Map>())
        MeslekGrubu.fromJson(Map<String, dynamic>.from(e)),
    ];
  } catch (_) {
    return const [];
  }
}

Future<List<MeslekAlanSablon>> loadMeslekAlanSablonlari({
  int? meslekGrubuId,
  bool includeInactive = false,
}) async {
  if (!_ready()) return const [];
  try {
    var q = Supabase.instance.client.from('meslek_alan_sablonlari').select();
    if (meslekGrubuId != null) {
      q = q.eq('meslek_grubu_id', meslekGrubuId);
    }
    if (!includeInactive) q = q.eq('aktif', true);
    final rows = await withNetworkTimeout(q.order('sira'));
    final raw = rows is List ? rows : const [];
    return [
      for (final e in raw.whereType<Map>())
        MeslekAlanSablon.fromJson(Map<String, dynamic>.from(e)),
    ];
  } catch (_) {
    return const [];
  }
}

Future<List<ExpertCvProfile>> loadPublishedExpertProfiles() async {
  if (!_ready()) return const [];
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client
          .from('expert_profiles')
          .select()
          .eq('status', 'published')
          .order('updated_at', ascending: false),
    );
    return _parseExperts(rows);
  } catch (_) {
    return const [];
  }
}

Future<List<ExpertCvProfile>> _parseExperts(dynamic rows) async {
  final raw = rows is List ? rows : const [];
  final parsed = [
    for (final e in raw.whereType<Map>())
      ExpertCvProfile.fromJson(Map<String, dynamic>.from(e)),
  ];
  if (parsed.isEmpty) return parsed;
  if (parsed.every((p) => p.meslekEtiket.isNotEmpty || p.meslekGrubuId == null)) {
    return parsed;
  }
  final gruplar = await loadMeslekGruplari();
  final byId = {for (final g in gruplar) g.id: g};
  return [
    for (final p in parsed)
      p.meslekEtiket.isNotEmpty || p.meslekGrubuId == null
          ? p
          : p.withMeslek(
              etiket: byId[p.meslekGrubuId]?.etiket,
              ustGrup: byId[p.meslekGrubuId]?.ustGrup,
            ),
  ];
}

Future<ExpertCvProfile?> _oneExpert(dynamic rows) async {
  final list = await _parseExperts(rows);
  return list.isEmpty ? null : list.first;
}

Future<ExpertCvProfile?> loadMyExpertProfile() async {
  if (!_ready()) return null;
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return null;
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client
          .from('expert_profiles')
          .select()
          .eq('owner_id', uid)
          .limit(1),
    );
    return _oneExpert(rows);
  } catch (_) {}
  return null;
}

Future<ExpertCvProfile?> loadPublicExpertProfile({
  String ownerId = '',
  String ownerEmail = '',
}) async {
  if (!_ready()) return null;
  final oid = ownerId.trim();
  final email = ownerEmail.trim().toLowerCase();
  if (oid.isNotEmpty) {
    try {
      final rows = await withNetworkTimeout(
        Supabase.instance.client
            .from('expert_profiles')
            .select()
            .eq('owner_id', oid)
            .eq('status', 'published')
            .limit(1),
      );
      final hit = await _oneExpert(rows);
      if (hit != null) return hit;
    } catch (_) {}
  }
  if (email.isNotEmpty) {
    try {
      final rows = await withNetworkTimeout(
        Supabase.instance.client
            .from('expert_profiles')
            .select()
            .eq('owner_email', email)
            .eq('status', 'published')
            .limit(1),
      );
      return _oneExpert(rows);
    } catch (_) {}
  }
  return null;
}

Future<ExpertCvProfile?> loadExpertProfileByOwnerId(String ownerId) =>
    loadPublicExpertProfile(ownerId: ownerId);

Future<ExpertCvProfile?> loadExpertProfileById(int id) async {
  if (!_ready() || id <= 0) return null;
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client.from('expert_profiles').select().eq('id', id).limit(1),
    );
    return _oneExpert(rows);
  } catch (_) {}
  return null;
}

Future<Map<String, String>> loadExpertFiles(int profileId) async {
  if (!_ready() || profileId <= 0) return {};
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client
          .from('expert_profile_files')
          .select()
          .eq('profile_id', profileId),
    );
    final map = <String, String>{};
    for (final e in (rows is List ? rows : const []).whereType<Map>()) {
      final k = e['alan_key']?.toString() ?? '';
      final u = e['file_url']?.toString() ?? '';
      if (k.isNotEmpty && u.isNotEmpty) map[k] = u;
    }
    return map;
  } catch (_) {
    return {};
  }
}

Future<ExpertCvProfile> saveExpertProfile({
  required ExpertCvProfile draft,
  required Map<String, String> fileUrls,
  required bool publish,
}) async {
  if (!_ready()) throw StateError('Bağlantı yok.');
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw StateError('Giriş yapın.');
  final email = (user.email ?? '').trim().toLowerCase();
  try {
    await Supabase.instance.client.auth.refreshSession();
  } catch (_) {}
  if (!isProfUserType(currentAuthUserType()) && !isAppAdmin(email)) {
    throw StateError('Yalnızca Destek Veren profil oluşturabilir.');
  }

  final detay = Map<String, dynamic>.from(draft.meslekDetaylari);
  for (final e in fileUrls.entries) {
    if (e.value.trim().isNotEmpty) detay[e.key] = 'yuklendi';
  }

  final wasPending = draft.status == 'pending';
  var status = draft.status;
  if (publish) {
    status = draft.isExpired ? 'published' : 'pending';
  } else if (status == 'published' || status == 'pending') {
    // Unvan/meslek/belge değişince yeniden onay.
    status = 'pending';
  } else {
    status = 'draft';
  }

  final kartSpan = draft.kartSpan >= 2 ? 2 : 1;
  detay['kart_span'] = kartSpan;
  var ucretBitis = draft.ucretBitis;
  var ilkAy = draft.ilkAyKullanildi;
  var charged = 0;
  var odenenPuan = draft.odenenPuan < 0 ? 0 : draft.odenenPuan;
  if (publish && !isAppAdmin(email)) {
    final now = DateTime.now();
    final covered = ucretBitis != null && ucretBitis.isAfter(now);
    if (!ilkAy) {
      ilkAy = true;
      ucretBitis = now.add(const Duration(days: kUzmanKartIlkUcretsizGun));
    } else if (!covered) {
      charged = uzmanKartPuan(kartSpan);
      final next = await spendKredi(email: email, amount: charged);
      if (next == null) {
        throw StateError(
          '$kUzmanKartYetersizUyarisi '
          '${kartSpan >= 2 ? kUzmanKartSatirPuan : kUzmanKartTekPuan} puan gerekir.',
        );
      }
      ucretBitis = now.add(const Duration(days: kUzmanKartAyGun));
      odenenPuan += charged;
    }
  } else if (publish && isAppAdmin(email) && !ilkAy) {
    ilkAy = true;
    ucretBitis = DateTime.now().add(const Duration(days: kUzmanKartIlkUcretsizGun));
  }
  detay['odenen_puan'] = odenenPuan;

  final payload = <String, dynamic>{
    'owner_id': user.id,
    'owner_email': email,
    'full_name': draft.fullName.trim(),
    'photo_url': draft.photoUrl.trim(),
    'meslek_grubu_id': draft.meslekGrubuId,
    'il': draft.il.trim(),
    'ilce': draft.ilce.trim(),
    'country_code': draft.countryCode.trim().isEmpty ? 'TR' : draft.countryCode,
    'deneyim_yili': draft.deneyimYili,
    'kisa_tanitim': draft.kisaTanitim.trim(),
    'calisma_sekli': draft.calismaSekli,
    'musaitlik': draft.musaitlik,
    'diller': draft.diller,
    'isaret_dili': draft.isaretDili,
    'engelli_deneyimi': draft.engelliDeneyimi,
    'engelli_deneyim_aciklama': draft.engelliDeneyimAciklama.trim(),
    'referanslar': draft.referanslar.trim(),
    'iletisim_tercihi': draft.iletisimTercihi,
    'telefon_izin': draft.telefonIzin,
    'eposta_izin': draft.epostaIzin,
    'meslek_detaylari': detay,
    'dogrulandi': draft.dogrulandi ||
        belgeAlaniYuklendi(detay) ||
        fileUrls.entries.any(
          (e) => isOpsiyonelBelgeAlani(e.key) && e.value.trim().isNotEmpty,
        ),
    'kvkk_onay': draft.kvkkOnay,
    if (draft.kvkkOnay) 'kvkk_onay_at': DateTime.now().toIso8601String(),
    'status': status,
    'kart_span': kartSpan,
    'ilk_ay_kullanildi': ilkAy,
    'odenen_puan': odenenPuan,
    if (ucretBitis != null) 'ucret_bitis': ucretBitis.toUtc().toIso8601String(),
  };

  Future<dynamic> upsertProfile(Map<String, dynamic> body) => withNetworkTimeout(
        Supabase.instance.client
            .from('expert_profiles')
            .upsert(body, onConflict: 'owner_id')
            .select(),
      );

  try {
    dynamic rows;
    try {
      rows = await upsertProfile(payload);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('kart_span') ||
          msg.contains('ucret_bitis') ||
          msg.contains('ilk_ay') ||
          msg.contains('pgrst204')) {
        payload.remove('kart_span');
        payload.remove('ucret_bitis');
        payload.remove('ilk_ay_kullanildi');
        payload.remove('odenen_puan');
        rows = await upsertProfile(payload);
      } else {
        rethrow;
      }
    }
    final raw = rows is List ? rows : const [];
    ExpertCvProfile? saved;
    for (final e in raw.whereType<Map>()) {
      saved = ExpertCvProfile.fromJson(Map<String, dynamic>.from(e));
      break;
    }
    if (saved == null) throw StateError('Profil kaydedilemedi.');
    invalidateUzmanKosesProfilesCache();

    for (final e in fileUrls.entries) {
      if (e.value.trim().isEmpty) continue;
      await withNetworkTimeout(
        Supabase.instance.client.from('expert_profile_files').upsert(
          {
            'profile_id': saved.id,
            'owner_id': user.id,
            'alan_key': e.key,
            'file_url': e.value.trim(),
          },
          onConflict: 'profile_id,alan_key',
        ),
      );
    }
    if (saved.status == 'pending' && !wasPending && !isAppAdmin(email)) {
      unawaited(notifyAdminUzmanOnay(saved));
    }
    return saved;
  } catch (e) {
    if (charged > 0) {
      try {
        final prefsBal = await spendKredi(email: email, amount: 0);
        if (prefsBal != null) {
          await saveUserKredi(
            email: email,
            balance: prefsBal + charged,
            welcomeGiftGiven: true,
          );
        }
      } catch (_) {}
    }
    if (e is StateError) rethrow;
    throw StateError(_expertSaveError(e));
  }
}

Future<void> deleteMyExpertProfile() async {
  if (!_ready()) throw StateError('Bağlantı yok.');
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw StateError('Giriş yapın.');
  final client = Supabase.instance.client;
  try {
    await withNetworkTimeout(client.rpc('delete_own_expert_profile'));
    invalidateUzmanKosesProfilesCache();
    return;
  } catch (_) {}

  Object? last;
  try {
    await withNetworkTimeout(
      client.from('expert_profiles').delete().eq('owner_id', user.id),
    );
  } catch (e) {
    last = e;
  }
  try {
    await withNetworkTimeout(
      client.from('uzman_kosesi_profiles').delete().eq('owner_id', user.id),
    );
    last = null;
  } catch (e) {
    last ??= e;
  }
  invalidateUzmanKosesProfilesCache();
  if (last == null) return;
  final lower = last.toString().toLowerCase();
  if (lower.contains('row-level security') || lower.contains('42501')) {
    throw StateError(
      'İlan silinemedi. supabase/expert_cv_delete_own.sql dosyasını çalıştırın.',
    );
  }
  throw StateError('İlan silinemedi. Lütfen tekrar deneyin.');
}

Future<void> deleteExpertProfileAsAdmin({required String ownerId}) async {
  if (!_ready()) throw StateError('Bağlantı yok.');
  final email =
      (Supabase.instance.client.auth.currentUser?.email ?? '')
          .trim()
          .toLowerCase();
  if (!isAppAdmin(email)) {
    throw StateError('Bu işlem için admin yetkisi gerekir.');
  }
  final oid = ownerId.trim();
  if (oid.isEmpty) throw StateError('İlan silinemedi.');
  final client = Supabase.instance.client;
  Object? last;
  try {
    await withNetworkTimeout(
      client.from('expert_profiles').delete().eq('owner_id', oid),
    );
  } catch (e) {
    last = e;
  }
  try {
    await withNetworkTimeout(
      client.from('uzman_kosesi_profiles').delete().eq('owner_id', oid),
    );
    last = null;
  } catch (e) {
    last ??= e;
  }
  invalidateUzmanKosesProfilesCache();
  if (last == null) return;
  final lower = last.toString().toLowerCase();
  if (lower.contains('row-level security') || lower.contains('42501')) {
    throw StateError(
      'İlan silinemedi. supabase/expert_cv_delete_own.sql dosyasını çalıştırın.',
    );
  }
  throw StateError('İlan silinemedi. Lütfen tekrar deneyin.');
}

Future<List<ExpertCvProfile>> loadPendingExpertProfiles() async {
  if (!_ready() ||
      !isAppAdmin(Supabase.instance.client.auth.currentUser?.email)) {
    return const [];
  }
  final rows = await withNetworkTimeout(
    Supabase.instance.client
        .from('expert_profiles')
        .select()
        .eq('status', 'pending')
        .order('updated_at'),
  );
  return _parseExperts(rows);
}

Future<void> adminReviewExpertProfile({
  required int id,
  required bool approve,
  String reason = '',
  bool dogrulandi = false,
}) async {
  await withNetworkTimeout(
    Supabase.instance.client.rpc(
      'admin_review_expert_profile',
      params: {
        'p_id': id,
        'p_approve': approve,
        'p_reason': reason,
        'p_dogrulandi': dogrulandi,
      },
    ),
  );
  invalidateUzmanKosesProfilesCache();
}

Future<void> saveExpertFile({
  required int profileId,
  required String ownerId,
  required String alanKey,
  required String fileUrl,
}) async {
  if (profileId <= 0 || fileUrl.trim().isEmpty) return;
  await withNetworkTimeout(
    Supabase.instance.client.from('expert_profile_files').upsert(
      {
        'profile_id': profileId,
        'owner_id': ownerId,
        'alan_key': alanKey,
        'file_url': fileUrl.trim(),
      },
      onConflict: 'profile_id,alan_key',
    ),
  );
}

String _slugKey(String raw) {
  return raw
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

Future<MeslekGrubu> insertMeslekGrubu({
  required String etiket,
  String ustGrup = 'Sağlık Uzmanları',
  int? sira,
}) async {
  final label = etiket.trim();
  if (label.isEmpty) throw StateError('Meslek adı yazın.');
  if (ustGrup != 'Sağlık Uzmanları' && ustGrup != 'Bakım ve Ev Desteği') {
    throw StateError('Üst grup geçersiz.');
  }
  var key = _slugKey(label);
  if (key.isEmpty) key = 'meslek_${DateTime.now().millisecondsSinceEpoch}';
  final payload = {
    'grup_key': key,
    'etiket': label,
    'ust_grup': ustGrup,
    'sira': sira ?? 0,
    'aktif': true,
  };
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client
          .from('meslek_gruplari')
          .insert(payload)
          .select(),
    );
    final raw = rows is List ? rows : const [];
    for (final e in raw.whereType<Map>()) {
      return MeslekGrubu.fromJson(Map<String, dynamic>.from(e));
    }
    throw StateError('Meslek eklenemedi.');
  } catch (e) {
    if (e is StateError) rethrow;
    final msg = e.toString().toLowerCase();
    if (msg.contains('duplicate') || msg.contains('unique')) {
      throw StateError('Bu meslek adı zaten var.');
    }
    if (msg.contains('row-level security')) {
      throw StateError('Meslek ekleme yetkisi yok.');
    }
    throw StateError('Meslek eklenemedi.');
  }
}

Future<void> upsertMeslekAlanSablon(MeslekAlanSablon s) async {
  final payload = {
    if (s.id > 0) 'id': s.id,
    'meslek_grubu_id': s.meslekGrubuId,
    'alan_key': s.alanKey,
    'etiket': s.etiket,
    'tip': s.tip,
    'secenekler': s.secenekler,
    'zorunlu': s.zorunlu,
    'sira': s.sira,
    'aktif': s.aktif,
  };
  await withNetworkTimeout(
    Supabase.instance.client.from('meslek_alan_sablonlari').upsert(payload),
  );
}

Future<void> setMeslekAlanAktif({required int id, required bool aktif}) async {
  await withNetworkTimeout(
    Supabase.instance.client
        .from('meslek_alan_sablonlari')
        .update({'aktif': aktif}).eq('id', id),
  );
}

String _expertSaveError(Object e) {
  var msg = e is PostgrestException ? e.message.trim() : e.toString().trim();
  msg = msg
      .replaceFirst(RegExp(r'^PostgrestException\([^)]*message:\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r', code:.*$'), '')
      .replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^Bad state:\s*', caseSensitive: false), '')
      .trim();
  final lower = msg.toLowerCase();
  if (lower.contains('300') && lower.contains('tanıtım')) {
    return 'Kısa tanıtım en az 10 karakter olmalı. Eski veritabanı kuralı hâlâ açık; supabase/expert_cv_less_required.sql çalıştırın.';
  }
  if (lower.contains('row-level security')) {
    return 'Kayıt yetkisi yok. Destek Veren rolünde olun.';
  }
  if (lower.contains('does not exist') || lower.contains('schema cache')) {
    return 'CV tabloları kurulmadı. supabase/expert_cv.sql ve expert_cv_seed.sql çalıştırın.';
  }
  if (msg.isEmpty) return 'Profil kaydedilemedi.';
  return msg;
}
