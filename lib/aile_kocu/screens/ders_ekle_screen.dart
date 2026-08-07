import 'package:flutter/material.dart';

import '../../meto_theme.dart';
import '../aile_kocu_store.dart';
import '../models/aile_kocu_models.dart';
import '../time_picker_24h.dart';

class DersEkleScreen extends StatefulWidget {
  const DersEkleScreen({super.key, this.existing});

  final Lesson? existing;

  @override
  State<DersEkleScreen> createState() => _DersEkleScreenState();
}

class _DersEkleScreenState extends State<DersEkleScreen> {
  late final TextEditingController _name;
  late final TextEditingController _place;
  late final TextEditingController _note;
  final Set<int> _days = {};
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _place = TextEditingController(text: e?.location ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    if (e != null) {
      _days.addAll(e.days);
      final p = e.time.split(':');
      if (p.length == 2) {
        _time = TimeOfDay(
          hour: int.tryParse(p[0]) ?? 18,
          minute: int.tryParse(p[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ders adı ve en az bir gün seçin.')),
      );
      return;
    }
    final time =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    final id = widget.existing?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final lesson = Lesson(
      id: id,
      name: name,
      days: _days.toList()..sort(),
      time: time,
      location: _place.text.trim(),
      note: _note.text.trim(),
      doneDates: widget.existing?.doneDates ?? {},
    );
    await lessonsBox.put(id, lesson);
    if (mounted) Navigator.pop(context, lesson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Yeni Ders' : 'Dersi Düzenle'),
        backgroundColor: MetoColors.card,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Ders / Etkinlik adı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Günler', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(dayLabel(d).substring(0, 3)),
                  selected: _days.contains(d),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _days.add(d);
                    } else {
                      _days.remove(d);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Saat'),
            subtitle: Text(
              '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            trailing: const Icon(Icons.schedule),
            onTap: () async {
              final t = await pickTime24h(context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _place,
            decoration: const InputDecoration(
              labelText: 'Yer',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Not',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: MetoColors.primary,
            ),
            child: const Text('Kaydet', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
