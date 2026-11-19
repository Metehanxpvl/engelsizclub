import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../meto_theme.dart';
import '../services/app_catalog_service.dart';
import 'hak_dosyasi.dart';

/// Admin: app_rights dosya / kaynaklar / son_guncelleme / uzman_onayi düzenleme.
Future<bool?> showHakDosyasiAdminSheet(
  BuildContext context, {
  required String hakId,
  String? title,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => HakDosyasiAdminSheet(
      hakId: hakId,
      title: title,
    ),
  );
}

class HakDosyasiAdminSheet extends StatefulWidget {
  const HakDosyasiAdminSheet({
    super.key,
    required this.hakId,
    this.title,
  });

  final String hakId;
  final String? title;

  @override
  State<HakDosyasiAdminSheet> createState() => _HakDosyasiAdminSheetState();
}

class _HakDosyasiAdminSheetState extends State<HakDosyasiAdminSheet> {
  late final TextEditingController _dosya;
  late final TextEditingController _kaynaklar;
  late final TextEditingController _uzman;
  DateTime? _sonGuncelleme;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final row = _findRow();
    final dosya = row?['dosya'];
    final kaynaklar = row?['kaynaklar'];
    _dosya = TextEditingController(text: _prettyJson(dosya) ?? '{\n  \n}');
    _kaynaklar =
        TextEditingController(text: _prettyJson(kaynaklar) ?? '[\n  \n]');
    _uzman = TextEditingController(
      text: row?['uzman_onayi']?.toString() ?? '',
    );
    _sonGuncelleme = _parseDate(row?['son_guncelleme']);
  }

  @override
  void dispose() {
    _dosya.dispose();
    _kaynaklar.dispose();
    _uzman.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _findRow() {
    final id = widget.hakId.trim();
    for (final r in AppCatalogService.instance.list(CatalogPack.rights)) {
      if (r['id']?.toString() == id) return r;
    }
    return null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString().trim());
  }

  static String? _prettyJson(dynamic raw) {
    if (raw == null) return null;
    try {
      dynamic value = raw;
      if (raw is String) {
        final t = raw.trim();
        if (t.isEmpty) return null;
        value = jsonDecode(t);
      }
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return raw.toString();
    }
  }

  String get _dateLabel {
    final d = _sonGuncelleme;
    if (d == null) return 'Tarih seç';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _sonGuncelleme ?? now;
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('tr'),
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 5),
      helpText: 'Son güncelleme',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked == null || !mounted) return;
    setState(() => _sonGuncelleme = picked);
  }

  Future<void> _save() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || !isAppAdmin(user.email)) {
      setState(() => _error = 'Yalnızca admin kaydedebilir.');
      return;
    }

    final dosyaText = _dosya.text.trim();
    final kaynaklarText = _kaynaklar.text.trim();
    final errors = <String>[];

    dynamic dosyaDecoded;
    dynamic kaynaklarDecoded;

    if (dosyaText.isEmpty) {
      dosyaDecoded = <String, dynamic>{};
    } else {
      try {
        dosyaDecoded = jsonDecode(dosyaText);
      } catch (e) {
        errors.add('Hak dosyası JSON geçersiz: $e');
      }
    }

    if (kaynaklarText.isEmpty) {
      kaynaklarDecoded = <dynamic>[];
    } else {
      try {
        kaynaklarDecoded = jsonDecode(kaynaklarText);
      } catch (e) {
        errors.add('Kaynaklar JSON geçersiz: $e');
      }
    }

    if (dosyaDecoded != null) {
      errors.addAll(validateHakDosyaJson(dosyaDecoded));
    }
    if (kaynaklarDecoded != null) {
      errors.addAll(validateHakKaynaklarJson(kaynaklarDecoded));
    }

    if (errors.isNotEmpty) {
      setState(() => _error = errors.join('\n'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final payload = <String, dynamic>{
        'dosya': dosyaDecoded,
        'kaynaklar': kaynaklarDecoded,
        'son_guncelleme':
            _sonGuncelleme?.toIso8601String().split('T').first,
        'uzman_onayi': _uzman.text.trim().isEmpty ? null : _uzman.text.trim(),
      };

      final row = Map<String, dynamic>.from(
        await Supabase.instance.client
            .from('app_rights')
            .update(payload)
            .eq('id', widget.hakId)
            .select()
            .single(),
      );
      await AppCatalogService.instance.replaceRightRow(row);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Bad state: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        builder: (ctx, scroll) {
          return Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetoColors.muted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title == null || widget.title!.trim().isEmpty
                              ? 'Hak dosyası'
                              : 'Hak dosyası · ${widget.title}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _saving ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      const Text(
                        'Hak dosyası (JSON)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _dosya,
                        maxLines: 14,
                        minLines: 8,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '{ "ozet": "...", "kimler": [] }',
                        ),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Kaynaklar (JSON)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _kaynaklar,
                        maxLines: 8,
                        minLines: 4,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '[ { "ad": "...", "url": "..." } ]',
                        ),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Son güncelleme',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(_dateLabel),
                      ),
                      if (_sonGuncelleme != null)
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _sonGuncelleme = null),
                          child: const Text('Tarihi temizle'),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Uzman onayı',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _uzman,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Örn. Av. … / uzman notu',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: MetoColors.primary,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Kaydet'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
