import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../meto_theme.dart';

class IyilikLiderEntry {
  const IyilikLiderEntry({
    required this.rank,
    required this.ownerEmail,
    required this.displayName,
    required this.kredi,
  });

  final int rank;
  final String ownerEmail;
  final String displayName;
  final int kredi;

  /// Paylaşım / ekran görüntüsü için maskeli e-posta.
  String get maskedEmail {
    final e = ownerEmail.trim().toLowerCase();
    final at = e.indexOf('@');
    if (at <= 1) return e;
    final local = e.substring(0, at);
    final domain = e.substring(at);
    if (local.length <= 2) return '${local[0]}***$domain';
    return '${local.substring(0, 2)}***$domain';
  }
}

Future<List<IyilikLiderEntry>> fetchAdminTopIyilikPuani({int limit = 10}) async {
  if (!isAppAdmin(Supabase.instance.client.auth.currentUser?.email)) {
    throw StateError('Yalnızca admin bu listeyi görebilir.');
  }
  final rows = await Supabase.instance.client.rpc(
    'admin_top_iyilik_puani',
    params: {'p_limit': limit},
  );
  if (rows is! List) return const [];
  return [
    for (final raw in rows)
      if (raw is Map)
        IyilikLiderEntry(
          rank: (raw['rank'] as num?)?.toInt() ?? 0,
          ownerEmail: raw['owner_email']?.toString() ?? '',
          displayName: (raw['display_name']?.toString() ?? '').trim().isEmpty
              ? (raw['owner_email']?.toString() ?? 'Kullanıcı')
              : raw['display_name'].toString().trim(),
          kredi: (raw['kredi'] as num?)?.toInt() ?? 0,
        ),
  ];
}

/// Ekran görüntüsü için temiz liderlik panosu (admin).
class AdminIyilikLiderleriPanel extends StatefulWidget {
  const AdminIyilikLiderleriPanel({
    super.key,
    required this.onBack,
    this.limit = 10,
  });

  final VoidCallback onBack;
  final int limit;

  @override
  State<AdminIyilikLiderleriPanel> createState() =>
      _AdminIyilikLiderleriPanelState();
}

class _AdminIyilikLiderleriPanelState extends State<AdminIyilikLiderleriPanel> {
  late Future<List<IyilikLiderEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchAdminTopIyilikPuani(limit: widget.limit);
  }

  Future<void> _reload() async {
    setState(() {
      _future = fetchAdminTopIyilikPuani(limit: widget.limit);
    });
    await _future;
  }

  Color _medalColor(int rank) {
    return switch (rank) {
      1 => const Color(0xFFF4A832),
      2 => const Color(0xFF94A3B8),
      3 => const Color(0xFFB45309),
      _ => MetoColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                style: IconButton.styleFrom(backgroundColor: MetoColors.muted),
                icon: const Icon(Icons.arrow_back, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'İyilik Puanı Sıralaması',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Yenile',
                onPressed: _reload,
                icon: const Icon(Icons.refresh, color: MetoColors.primary),
              ),
            ],
          ),
        ),
        // Screenshot alanı
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F3D2E), Color(0xFF1A6B4A)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Engelsiz Club',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '💚 İyilik Puanı Liderleri',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'En yüksek ${widget.limit} · Teşekkürler',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<IyilikLiderEntry>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    final msg = snap.error.toString();
                    final sqlHint = msg.contains('function') ||
                        msg.contains('PGRST') ||
                        msg.contains('404') ||
                        msg.contains('Could not find');
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        sqlHint
                            ? 'Liste için Supabase’de admin_top_iyilik_puani.sql dosyasını çalıştırın.'
                            : 'Liste yüklenemedi: $msg',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    );
                  }
                  final list = snap.data ?? const <IyilikLiderEntry>[];
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Henüz puanlı kullanıcı yok.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final e in list) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _medalColor(e.rank),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${e.rank}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      e.maskedEmail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.65),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${e.kredi}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'puan',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Bu yeşil kartı ekran görüntüsü alıp hikâye / gönderi olarak paylaşabilirsin.',
          style: TextStyle(
            fontSize: 12,
            color: MetoColors.mutedFg,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
