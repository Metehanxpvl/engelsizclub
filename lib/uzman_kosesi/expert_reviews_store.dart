import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../utils/async_timeout.dart';
import 'expert_cv_models.dart';

class ExpertReview {
  const ExpertReview({
    this.id = 0,
    this.profileId = 0,
    this.expertOwnerId = '',
    this.authorId = '',
    this.authorEmail = '',
    this.authorName = '',
    this.rating = 0,
    this.body = '',
    this.createdAt,
  });

  final int id;
  final int profileId;
  final String expertOwnerId;
  final String authorId;
  final String authorEmail;
  final String authorName;
  final int rating;
  final String body;
  final DateTime? createdAt;

  factory ExpertReview.fromJson(Map<String, dynamic> json) => ExpertReview(
        id: (json['id'] as num?)?.toInt() ?? 0,
        profileId: (json['profile_id'] as num?)?.toInt() ?? 0,
        expertOwnerId: json['expert_owner_id']?.toString() ?? '',
        authorId: json['author_id']?.toString() ?? '',
        authorEmail: (json['author_email']?.toString() ?? '').trim().toLowerCase(),
        authorName: json['author_name']?.toString().trim() ?? '',
        rating: ((json['rating'] as num?)?.toInt() ?? 0).clamp(1, 5),
        body: json['body']?.toString().trim() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );
}

double expertReviewOrtalama(List<ExpertReview> list) =>
    uzmanYildizOrtalama(list.map((r) => r.rating));

bool canDeleteExpertReview({
  required String viewerEmail,
  required String authorEmail,
}) {
  if (isAppAdmin(viewerEmail)) return true;
  final viewer = viewerEmail.trim().toLowerCase();
  final author = authorEmail.trim().toLowerCase();
  return viewer.isNotEmpty && viewer == author;
}

bool _ready() {
  try {
    return Supabase.instance.isInitialized;
  } catch (_) {
    return false;
  }
}

Future<List<ExpertReview>> loadExpertReviews(int profileId) async {
  if (!_ready() || profileId <= 0) return const [];
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client
          .from('expert_profile_reviews')
          .select()
          .eq('profile_id', profileId)
          .order('created_at', ascending: false),
    );
    final raw = rows is List ? rows : const [];
    return [
      for (final e in raw.whereType<Map>())
        ExpertReview.fromJson(Map<String, dynamic>.from(e)),
    ];
  } catch (_) {
    return const [];
  }
}

Future<ExpertReview> upsertExpertReview({
  required int profileId,
  required String expertOwnerId,
  required int rating,
  required String body,
  String authorName = '',
}) async {
  if (!_ready()) throw StateError('Bağlantı yok.');
  final user = Supabase.instance.client.auth.currentUser;
  final email = (user?.email ?? '').trim().toLowerCase();
  if (user == null || email.isEmpty) {
    throw StateError('Yorum için giriş yapın.');
  }
  if (user.id == expertOwnerId) {
    throw StateError('Kendi profilinize yorum yazamazsınız.');
  }
  final stars = rating.clamp(1, 5);
  final text = body.trim();
  if (text.length < 3) throw StateError('Yorum en az 3 karakter olmalı.');
  final name = authorName.trim().isEmpty ? 'Üye' : authorName.trim();
  try {
    final row = await withNetworkTimeout(
      Supabase.instance.client.from('expert_profile_reviews').upsert(
        {
          'profile_id': profileId,
          'expert_owner_id': expertOwnerId,
          'author_id': user.id,
          'author_email': email,
          'author_name': name,
          'rating': stars,
          'body': text,
        },
        onConflict: 'profile_id,author_id',
      ).select().single(),
    );
    return ExpertReview.fromJson(Map<String, dynamic>.from(row as Map));
  } catch (e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('does not exist') || msg.contains('schema cache')) {
      throw StateError(
        'Yorum tablosu yok. supabase/expert_profile_reviews.sql çalıştırın.',
      );
    }
    if (e is StateError) rethrow;
    throw StateError('Yorum kaydedilemedi.');
  }
}

Future<void> deleteExpertReview(int id) async {
  if (!_ready()) throw StateError('Bağlantı yok.');
  if (id <= 0) throw StateError('Yorum silinemedi.');
  final user = Supabase.instance.client.auth.currentUser;
  final email = (user?.email ?? '').trim().toLowerCase();
  if (user == null || email.isEmpty) {
    throw StateError('Yorum silmek için giriş yapın.');
  }
  if (!isAppAdmin(email)) {
    await withNetworkTimeout(
      Supabase.instance.client
          .from('expert_profile_reviews')
          .delete()
          .eq('id', id)
          .eq('author_id', user.id),
    );
    return;
  }
  await withNetworkTimeout(
    Supabase.instance.client.from('expert_profile_reviews').delete().eq('id', id),
  );
}
