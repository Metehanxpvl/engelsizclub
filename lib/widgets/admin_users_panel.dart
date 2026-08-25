import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../meto_theme.dart';

class AdminUserStats {
  const AdminUserStats({
    this.total = 0,
    this.online = 0,
    this.last24h = 0,
    this.aile = 0,
    this.uzman = 0,
    this.bakici = 0,
  });

  final int total;
  final int online;
  final int last24h;
  final int aile;
  final int uzman;
  final int bakici;

  factory AdminUserStats.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num?)?.toInt() ?? 0;
    return AdminUserStats(
      total: n('total'),
      online: n('online'),
      last24h: n('last_24h'),
      aile: n('aile'),
      uzman: n('uzman'),
      bakici: n('bakici'),
    );
  }
}

class AdminUserRow {
  const AdminUserRow({
    required this.email,
    required this.displayName,
    required this.userType,
    required this.sehir,
    required this.kredi,
    required this.isOnline,
    this.lastSeen,
    this.createdAt,
  });

  final String email;
  final String displayName;
  final String userType;
  final String sehir;
  final int kredi;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;

  String get roleLabel => switch (userType) {
        'aile' => 'Aile',
        'uzman' => 'Uzman',
        'bakici' || 'bakıcı' => 'Bakıcı',
        _ => userType.isEmpty ? '—' : userType,
      };
}

Future<AdminUserStats> fetchAdminUserStats() async {
  if (!isAppAdmin(Supabase.instance.client.auth.currentUser?.email)) {
    throw StateError('Yalnızca admin bu verileri görebilir.');
  }
  final raw = await Supabase.instance.client.rpc('admin_user_stats');
  if (raw is Map<String, dynamic>) return AdminUserStats.fromJson(raw);
  if (raw is Map) {
    return AdminUserStats.fromJson(Map<String, dynamic>.from(raw));
  }
  return const AdminUserStats();
}

Future<List<AdminUserRow>> fetchAdminUserList({
  String query = '',
  String filter = 'all',
}) async {
  if (!isAppAdmin(Supabase.instance.client.auth.currentUser?.email)) {
    throw StateError('Yalnızca admin bu listeyi görebilir.');
  }
  final rows = await Supabase.instance.client.rpc(
    'admin_list_users',
    params: {
      'p_q': query.trim(),
      'p_filter': filter,
      'p_limit': 400,
    },
  );
  if (rows is! List) return const [];
  return [
    for (final raw in rows)
      if (raw is Map) _rowFromMap(raw),
  ];
}

AdminUserRow _rowFromMap(Map raw) {
  return AdminUserRow(
    email: (raw['owner_email']?.toString() ?? '').toLowerCase(),
    displayName: (raw['display_name']?.toString() ?? '').trim().isEmpty
        ? (raw['owner_email']?.toString() ?? 'Kullanıcı')
        : raw['display_name'].toString().trim(),
    userType: (raw['user_type']?.toString() ?? '').toLowerCase(),
    sehir: (raw['sehir']?.toString() ?? '').trim(),
    kredi: (raw['kredi'] as num?)?.toInt() ?? 0,
    isOnline: raw['is_online'] == true ||
        raw['is_online']?.toString() == 'true',
    lastSeen: DateTime.tryParse(raw['last_seen']?.toString() ?? ''),
    createdAt: DateTime.tryParse(raw['created_at']?.toString() ?? ''),
  );
}

/// Presence tablosundan anlık kimler açık (isim + e-posta).
Future<List<AdminUserRow>> fetchAdminOnlineUsers() async {
  if (!isAppAdmin(Supabase.instance.client.auth.currentUser?.email)) {
    throw StateError('Yalnızca admin bu listeyi görebilir.');
  }
  try {
    final rows = await Supabase.instance.client.rpc('admin_online_users');
    if (rows is List) {
      return [
        for (final raw in rows)
          if (raw is Map) _rowFromMap(raw),
      ];
    }
  } catch (_) {}
  return fetchAdminUserList(filter: 'online');
}

String _relativeTr(DateTime? at) {
  if (at == null) return 'Hiç görülmedi';
  final d = DateTime.now().toUtc().difference(at.toUtc());
  if (d.isNegative || d.inSeconds < 45) return 'Şimdi aktif';
  if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
  if (d.inHours < 24) return '${d.inHours} sa önce';
  if (d.inDays == 1) return 'Dün';
  if (d.inDays < 30) return '${d.inDays} gün önce';
  return '${at.day}.${at.month}.${at.year}';
}

/// Admin: anlık aktif kullanıcılar ve üye listesi.
class AdminUsersPanel extends StatefulWidget {
  const AdminUsersPanel({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AdminUsersPanel> createState() => _AdminUsersPanelState();
}

class _AdminUsersPanelState extends State<AdminUsersPanel> {
  AdminUserStats _stats = const AdminUserStats();
  List<AdminUserRow> _online = const [];
  List<AdminUserRow> _users = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  final _search = TextEditingController();
  Timer? _poll;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _reload();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) unawaited(_reload(silent: true));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final stats = await fetchAdminUserStats();
      final online = await fetchAdminOnlineUsers();
      final users = await fetchAdminUserList(
        query: _search.text,
        filter: _filter,
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _online = online;
        _users = users;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_reload());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
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
                  'Kullanıcılar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Yenile',
                onPressed: () => _reload(),
                icon: const Icon(Icons.refresh, color: MetoColors.primary),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Şimdi aktif',
                value: '${_stats.online}',
                accent: const Color(0xFF16A34A),
                live: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'Son 24 saat',
                value: '${_stats.last24h}',
                accent: MetoColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'Toplam üye',
                value: '${_stats.total}',
                accent: MetoColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _RoleChip(label: 'Aile ${_stats.aile}'),
            _RoleChip(label: 'Uzman ${_stats.uzman}'),
            _RoleChip(label: 'Bakıcı ${_stats.bakici}'),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Ad, e-posta veya şehir ara',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: MetoColors.muted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final e in const [
                ('all', 'Tümü'),
                ('online', 'Çevrimiçi'),
                ('aile', 'Aile'),
                ('uzman', 'Uzman'),
                ('bakici', 'Bakıcı'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(e.$2),
                    selected: _filter == e.$1,
                    onSelected: (_) {
                      setState(() => _filter = e.$1);
                      unawaited(_reload());
                    },
                    selectedColor: MetoColors.selectedBg,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: _filter == e.$1
                          ? MetoColors.primary
                          : MetoColors.mutedFg,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!.contains('admin_user_stats') ||
                      _error!.contains('Could not find') ||
                      _error!.contains('PGRST')
                  ? 'Supabase’de admin_users_dashboard.sql çalıştırın.'
                  : _error!,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: MetoColors.primary),
                )
              : RefreshIndicator(
                  color: MetoColors.primary,
                  onRefresh: () => _reload(),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _OnlinePeopleCard(users: _online, count: _stats.online),
                      const SizedBox(height: 14),
                      Text(
                        _filter == 'online'
                            ? 'Çevrimiçi üye listesi'
                            : 'Tüm üyeler (${_users.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_users.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Kayıt bulunamadı.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: MetoColors.mutedFg),
                          ),
                        )
                      else
                        for (final u in _users) ...[
                          _UserTile(user: u),
                          const SizedBox(height: 8),
                        ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _OnlinePeopleCard extends StatelessWidget {
  const _OnlinePeopleCard({required this.users, required this.count});

  final List<AdminUserRow> users;
  final int count;

  @override
  Widget build(BuildContext context) {
    final n = users.length > count ? users.length : count;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Şu an uygulamada ($n)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (users.isEmpty)
            const Text(
              'Şu an kimse çevrimiçi görünmüyor. (Uygulama açık olanlar 90 sn içinde burada listelenir.)',
              style: TextStyle(fontSize: 12, color: Color(0xFF15803D), height: 1.35),
            )
          else
            for (final u in users)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      child: Text(
                        u.displayName.isEmpty
                            ? '?'
                            : u.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF166534),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Color(0xFF14532D),
                            ),
                          ),
                          Text(
                            [
                              u.email,
                              u.roleLabel,
                              if (u.sehir.isNotEmpty) u.sehir,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
    this.live = false,
  });

  final String label;
  final String value;
  final Color accent;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (live) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.mutedFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: MetoColors.muted,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: MetoColors.foreground,
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final AdminUserRow user;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: () async {
          await Clipboard.setData(ClipboardData(text: user.email));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.email} kopyalandı')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: MetoColors.muted,
                    child: Text(
                      user.displayName.isEmpty
                          ? '?'
                          : user.displayName[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: MetoColors.primary,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: user.isOnline
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: MetoColors.foreground,
                      ),
                    ),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                    Text(
                      [
                        user.roleLabel,
                        if (user.sehir.isNotEmpty) user.sehir,
                        if (user.kredi > 0) '${user.kredi} puan',
                        _relativeTr(user.lastSeen),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: user.isOnline
                            ? const Color(0xFF15803D)
                            : MetoColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
