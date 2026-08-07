import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../meto_theme.dart';
import '../aile_kocu_store.dart';
import '../child_photo.dart';
import '../models/aile_kocu_models.dart';
import '../widgets/ak_swipe_delete.dart';

class CocukNotlariScreen extends StatefulWidget {
  const CocukNotlariScreen({super.key});

  @override
  State<CocukNotlariScreen> createState() => _CocukNotlariScreenState();
}

class _CocukNotlariScreenState extends State<CocukNotlariScreen> {
  final _search = TextEditingController();


  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _exportPdf(List<ChildNote> notes) async {
    final s = loadSettings();
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (c) => [
          pw.Header(level: 0, text: '${s.childName} hakkında notlar'),
          for (final n in notes)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${n.date.day}.${n.date.month}.${n.date.year} — ${n.title}'
                    '${n.isImportant ? " ★" : ""}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(n.detail),
                ],
              ),
            ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'cocuk_notlari.pdf',
    );
  }

  Future<void> _addOrEdit([ChildNote? existing]) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final detail = TextEditingController(text: existing?.detail ?? '');
    var date = existing?.date ?? DateTime.now();
    var important = existing?.isImportant ?? false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      existing == null ? 'Yeni Not' : 'Notu Düzenle',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Başlık',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: detail,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Detay',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Önemli'),
                      value: important,
                      onChanged: (v) => setModal(() => important = v),
                    ),
                    ListTile(
                      title: Text(
                        'Tarih: ${date.day}.${date.month}.${date.year}',
                      ),
                      trailing: const Icon(Icons.event),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setModal(() => date = d);
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (ok != true) return;
    final id = existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    await childNotesBox.put(
      id,
      ChildNote(
        id: id,
        date: date,
        title: title.text.trim().isEmpty ? 'Not' : title.text.trim(),
        detail: detail.text.trim(),
        imagePath: null,
        isImportant: important,
      ),
    );
    title.dispose();
    detail.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = loadSettings();
    final photo = childPhotoProvider(s.photoPath);
    final q = _search.text.trim().toLowerCase();
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        title: Text(childPageTitle('Notları')),
        backgroundColor: MetoColors.card,
        actions: [
          IconButton(
            tooltip: 'PDF paylaş',
            onPressed: () {
              final notes = childNotesBox.values.toList()
                ..sort((a, b) => b.date.compareTo(a.date));
              _exportPdf(notes);
            },
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Not'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.orange.shade100,
                  backgroundImage: photo,
                  child: photo == null
                      ? const Icon(Icons.child_care, color: Colors.orange)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    childPageTitle('Notları'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Ara…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: childNotesBox.listenable(),
              builder: (context, Box<ChildNote> box, _) {
                var notes = box.values.toList()
                  ..sort((a, b) => b.date.compareTo(a.date));
                if (q.isNotEmpty) {
                  notes = notes
                      .where(
                        (n) =>
                            n.title.toLowerCase().contains(q) ||
                            n.detail.toLowerCase().contains(q),
                      )
                      .toList();
                }
                if (notes.isEmpty) {
                  return const Center(child: Text('Not yok.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: notes.length,
                  itemBuilder: (context, i) {
                    final n = notes[i];
                    return AkSwipeToDelete(
                      itemKey: 'cnote_${n.id}',
                      confirmMessage: '"${n.title}" notu silinsin mi?',
                      onDelete: () => childNotesBox.delete(n.id),
                      child: Card(
                        child: ListTile(
                          leading: n.isImportant
                              ? const Icon(Icons.star, color: Colors.amber)
                              : null,
                          title: Text(
                            n.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            n.detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            '${n.date.day}.${n.date.month}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => _addOrEdit(n),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
