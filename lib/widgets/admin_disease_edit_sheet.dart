import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../data/diseases_data.dart';
import '../disease_catalog_store.dart';
import '../condition_store.dart';
import '../meto_theme.dart';
import 'catalog_media.dart';

/// Admin: kart + detay (belirti, tanı, destek, SSS) düzenleme.
class AdminDiseaseEditSheet extends StatefulWidget {
  const AdminDiseaseEditSheet({super.key, required this.disease});

  final DiseaseInfo disease;

  @override
  State<AdminDiseaseEditSheet> createState() => _AdminDiseaseEditSheetState();
}

class _AdminDiseaseEditSheetState extends State<AdminDiseaseEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _icon;
  late final TextEditingController _photo;
  late final TextEditingController _desc;
  late final TextEditingController _symptoms;
  late final TextEditingController _diagnosis;
  late final TextEditingController _support;
  late final TextEditingController _faq;
  Uint8List? _pickedBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.disease;
    _name = TextEditingController(text: d.name);
    _icon = TextEditingController(text: d.icon);
    _photo = TextEditingController(text: d.photo ?? '');
    _desc = TextEditingController(text: d.desc);
    _symptoms = TextEditingController(text: d.symptoms.join('\n'));
    _diagnosis = TextEditingController(text: d.diagnosis);
    _support = TextEditingController(text: d.support.join('\n'));
    _faq = TextEditingController(
      text: [
        for (final f in d.faq) '${f.q} | ${f.a}',
      ].join('\n'),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    _photo.dispose();
    _desc.dispose();
    _symptoms.dispose();
    _diagnosis.dispose();
    _support.dispose();
    _faq.dispose();
    super.dispose();
  }

  List<String> _lines(String raw) => raw
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<FaqItem> _parseFaq(String raw) {
    final out = <FaqItem>[];
    for (final line in _lines(raw)) {
      final parts = line.split('|');
      if (parts.length < 2) continue;
      final q = parts.first.trim();
      final a = parts.sublist(1).join('|').trim();
      if (q.isNotEmpty) out.add(FaqItem(q, a));
    }
    return out;
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 82,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedBytes = bytes;
      _photo.clear();
    });
  }

  String _resolvePhoto() {
    if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
      return 'data:image/jpeg;base64,${base64Encode(_pickedBytes!)}';
    }
    return _photo.text.trim();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık gerekli.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final photo = _resolvePhoto();
      final updated = DiseaseInfo(
        id: widget.disease.id,
        name: name,
        icon: _icon.text.trim().isEmpty ? widget.disease.icon : _icon.text.trim(),
        color: widget.disease.color,
        bg: widget.disease.bg,
        photo: photo.isEmpty ? null : photo,
        desc: _desc.text.trim(),
        symptoms: _lines(_symptoms.text),
        diagnosis: _diagnosis.text.trim(),
        support: _lines(_support.text),
        faq: _parseFaq(_faq.text),
      );

      DiseaseInfo saved;
      if (updated.id.startsWith('cond_')) {
        final condId = int.tryParse(updated.id.substring(5));
        if (condId == null || condId <= 0) {
          throw StateError('Geçersiz kart kaydı.');
        }
        final item = await updateCondition(
          id: condId,
          title: updated.name,
          imageUrl: updated.photo ?? '',
          description: updated.desc,
          icon: updated.icon,
          symptoms: updated.symptoms,
          diagnosis: updated.diagnosis,
          support: updated.support,
          faq: updated.faq,
        );
        saved = item.toDiseaseInfo(enrichFrom: updated);
      } else {
        saved = await upsertAppDisease(updated);
      }
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('conditions') ||
                    e.toString().contains('app_diseases') ||
                    e.toString().contains('PGRST') ||
                    e.toString().contains('schema') ||
                    e.toString().contains('column')
                ? 'Supabase şema eksik. conditions_detail.sql / app_catalog.sql çalıştırın.'
                : 'Kaydedilemedi: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final preview = _pickedBytes != null
        ? null
        : _photo.text.trim().isEmpty
            ? widget.disease.photo
            : _photo.text.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MetoColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Hastalık düzenle',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kart metni ve detay içeriği',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: MetoColors.mutedFg,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Başlık (kart)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _icon,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'İkon (emoji)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _desc,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Kısa açıklama (kart + üst detay)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickImage,
                      icon: const Icon(Icons.photo_outlined),
                      label: const Text('Kapak fotoğrafı seç'),
                    ),
                    if (_pickedBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _pickedBytes!,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else if (preview != null && preview.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CatalogImage(
                            source: preview,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _photo,
                      enabled: !_saving && _pickedBytes == null,
                      decoration: const InputDecoration(
                        labelText: 'veya görsel URL / asset yolu',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Detay içeriği',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _symptoms,
                      enabled: !_saving,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Belirtiler (her satır bir madde)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _diagnosis,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Tanı süreci',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _support,
                      enabled: !_saving,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Destek yolları (her satır bir madde)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _faq,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'SSS (satır: soru | cevap)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: MetoColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _saving ? 'Kaydediliyor…' : 'Kaydet',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
