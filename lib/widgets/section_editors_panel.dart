import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../meto_theme.dart';
import '../section_editors.dart';

/// Profil → Bölüm yöneticileri (yalnız isAppAdmin).
class SectionEditorsPanel extends StatefulWidget {
  const SectionEditorsPanel({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<SectionEditorsPanel> createState() => _SectionEditorsPanelState();
}

class _SectionEditorsPanelState extends State<SectionEditorsPanel> {
  final _email = TextEditingController();
  final Set<SectionKey> _selected = {};
  List<SectionEditorEntry> _items = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _editingEmail;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await loadAllSectionEditors();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _fill(SectionEditorEntry e) {
    _email.text = e.email;
    setState(() {
      _editingEmail = e.email;
      _selected
        ..clear()
        ..addAll(e.sections);
    });
  }

  void _clearForm() {
    _email.clear();
    setState(() {
      _editingEmail = null;
      _selected.clear();
    });
  }

  Future<void> _save() async {
    final sections = Set<SectionKey>.from(_selected);
    if (sections.isEmpty && _editingEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir bölüm seçin.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await saveSectionEditor(
        email: _email.text,
        sections: sections,
      );
      if (!mounted) return;
      _clearForm();
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sections.isEmpty
                ? 'Yetkiler kaldırıldı.'
                : 'Bölüm yöneticisi kaydedildi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(String email) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Yetkileri kaldır?',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '$email artık hiçbir bölümü yönetemez.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await removeSectionEditor(email);
      if (!mounted) return;
      if (_editingEmail == email) _clearForm();
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
              Expanded(
                child: Text(
                  'Bölüm yöneticileri',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Yenile',
                onPressed: _loading ? null : _reload,
                icon: const Icon(Icons.refresh, color: MetoColors.primary),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: MetoColors.primary),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Text(
                      'E-posta ekleyin, bölümleri işaretleyin. Kişi yalnız o bölümü yönetir; kullanıcı / keşfet / ilan panelleri açılmaz.',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: MetoColors.mutedFg,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enabled: !_saving,
                      style: GoogleFonts.nunito(),
                      decoration: InputDecoration(
                        labelText: 'E-posta',
                        hintText: 'ornek@posta.com',
                        filled: true,
                        fillColor: MetoColors.muted,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final k in SectionKey.all)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _selected.contains(k),
                        onChanged: _saving
                            ? null
                            : (v) => setState(() {
                                  if (v == true) {
                                    _selected.add(k);
                                  } else {
                                    _selected.remove(k);
                                  }
                                }),
                        title: Text(
                          k.label,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: MetoColors.primary,
                      ),
                    const SizedBox(height: 4),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: MetoColors.primary,
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        _editingEmail == null
                            ? 'Kaydet'
                            : 'Güncelle',
                      ),
                    ),
                    if (_editingEmail != null)
                      TextButton(
                        onPressed: _saving ? null : _clearForm,
                        child: const Text('Formu temizle'),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Atananlar',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_items.isEmpty)
                      Text(
                        'Henüz bölüm yöneticisi yok.',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: MetoColors.mutedFg,
                        ),
                      )
                    else
                      for (final e in _items)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: MetoColors.card,
                          child: ListTile(
                            onTap: () => _fill(e),
                            title: Text(
                              e.email,
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              e.sections.map((s) => s.label).join(' · '),
                              style: GoogleFonts.nunito(fontSize: 12),
                            ),
                            trailing: IconButton(
                              tooltip: 'Kaldır',
                              onPressed:
                                  _saving ? null : () => _remove(e.email),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
        ),
      ],
    );
  }
}
