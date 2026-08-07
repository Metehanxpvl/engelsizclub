import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../meto_theme.dart';
import '../aile_kocu_store.dart';
import '../models/aile_kocu_models.dart';
import '../notification_service.dart';
import '../time_picker_24h.dart';
import '../widgets/ak_swipe_delete.dart';

const _tags = ['Acil', 'Market', 'Aranacak', 'Not'];

Color _tagColor(String tag) => switch (tag) {
      'Acil' => Colors.red.shade100,
      'Market' => Colors.green.shade100,
      'Aranacak' => Colors.blue.shade100,
      _ => Colors.grey.shade200,
    };

class NotlarimScreen extends StatefulWidget {
  const NotlarimScreen({super.key});

  @override
  State<NotlarimScreen> createState() => _NotlarimScreenState();
}

class _NotlarimScreenState extends State<NotlarimScreen> {
  Future<void> _addOrEdit([PersonalNote? existing]) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final detail = TextEditingController(text: existing?.detail ?? '');
    var tag = existing?.tag ?? 'Not';
    DateTime? reminder = existing?.reminderDateTime;

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
                    const Text(
                      'NOTLARIM',
                      style: TextStyle(
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final t in _tags)
                          ChoiceChip(
                            label: Text(t),
                            selected: tag == t,
                            selectedColor: _tagColor(t),
                            onSelected: (_) => setModal(() => tag = t),
                          ),
                      ],
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hatırlatıcı (opsiyonel)'),
                      subtitle: Text(
                        reminder == null
                            ? 'Kapalı'
                            : '${reminder!.day}.${reminder!.month} '
                                '${reminder!.hour.toString().padLeft(2, '0')}:'
                                '${reminder!.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.alarm),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: reminder ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (d == null || !ctx.mounted) return;
                          final t = await pickTime24h(
                            ctx,
                            initialTime: TimeOfDay.fromDateTime(
                              reminder ?? DateTime.now(),
                            ),
                          );
                          if (t == null) return;
                          setModal(() {
                            reminder = DateTime(
                              d.year,
                              d.month,
                              d.day,
                              t.hour,
                              t.minute,
                            );
                          });
                        },
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: Colors.green.shade700,
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
    final note = PersonalNote(
      id: id,
      title: title.text.trim().isEmpty ? 'Not' : title.text.trim(),
      detail: detail.text.trim(),
      reminderDateTime: reminder,
      tag: tag,
    );
    await personalNotesBox.put(id, note);
    if (reminder != null) {
      await AileKocuNotificationService.instance.showPersonalNoteNotification(
        title: note.title,
        body: note.detail,
        scheduledTime: reminder!,
        noteId: id,
      );
    } else {
      await AileKocuNotificationService.instance.cancelPersonalNote(id);
    }
    title.dispose();
    detail.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        title: const Text('Notlarım'),
        backgroundColor: MetoColors.card,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        backgroundColor: Colors.green.shade700,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Not'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'NOTLARIM',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: personalNotesBox.listenable(),
              builder: (context, Box<PersonalNote> box, _) {
                final notes = box.values.toList().reversed.toList();
                if (notes.isEmpty) {
                  return const Center(child: Text('Kişisel not yok.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  itemCount: notes.length,
                  itemBuilder: (context, i) {
                    final n = notes[i];
                    return AkSwipeToDelete(
                      itemKey: 'pnote_${n.id}',
                      confirmMessage: '"${n.title}" notu silinsin mi?',
                      onDelete: () async {
                        await personalNotesBox.delete(n.id);
                        await AileKocuNotificationService.instance
                            .cancelPersonalNote(n.id);
                      },
                      child: Card(
                        color: _tagColor(n.tag),
                        child: ListTile(
                          title: Text(
                            n.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            n.detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Chip(
                            label: Text(
                              n.tag,
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
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
