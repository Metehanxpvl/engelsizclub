import 'package:flutter/material.dart';

import '../../meto_theme.dart';
import '../aile_kocu_store.dart';
import '../models/aile_kocu_models.dart';
import '../time_picker_24h.dart';

class IlacEkleScreen extends StatefulWidget {
  const IlacEkleScreen({super.key, this.existing});

  final Medicine? existing;

  @override
  State<IlacEkleScreen> createState() => _IlacEkleScreenState();
}

class _IlacEkleScreenState extends State<IlacEkleScreen> {
  late final TextEditingController _name;
  late final TextEditingController _dose;
  final List<TimeOfDay> _times = [];
  final Set<int> _days = {};
  bool _everyDay = true;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _dose = TextEditingController(text: e?.dosage ?? '');
    if (e != null) {
      for (final t in e.times) {
        final p = t.split(':');
        _times.add(TimeOfDay(
          hour: int.tryParse(p[0]) ?? 8,
          minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
        ));
      }
      if (e.days.isEmpty) {
        _everyDay = true;
      } else {
        _everyDay = false;
        _days.addAll(e.days);
      }
      _end = e.endDate;
    }
    if (_times.isEmpty) {
      _times.add(const TimeOfDay(hour: 8, minute: 0));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final name = _name.text.trim();
    final dose = _dose.text.trim();
    if (name.isEmpty || dose.isEmpty || _times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad, doz ve en az bir saat gerekli.')),
      );
      return;
    }
    if (!_everyDay && _days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gün seçin veya Her Gün işaretleyin.')),
      );
      return;
    }
    final id = widget.existing?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final med = Medicine(
      id: id,
      name: name,
      dosage: dose,
      times: _times.map(_fmt).toList(),
      days: _everyDay ? <int>[] : (_days.toList()..sort()),
      endDate: _end,
      takenDatesMap: widget.existing?.takenDatesMap ?? {},
    );
    await medicinesBox.put(id, med);
    if (mounted) Navigator.pop(context, med);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Yeni İlaç' : 'İlacı Düzenle'),
        backgroundColor: MetoColors.card,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'İlaç adı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dose,
            decoration: const InputDecoration(
              labelText: 'Doz (ör. 5ml)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Saatler',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final t = await pickTime24h(
                    context,
                    initialTime: const TimeOfDay(hour: 12, minute: 0),
                  );
                  if (t != null) setState(() => _times.add(t));
                },
                icon: const Icon(Icons.add),
                label: const Text('Saat ekle'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < _times.length; i++)
                InputChip(
                  label: Text(_fmt(_times[i])),
                  onDeleted: () => setState(() => _times.removeAt(i)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Her gün'),
            value: _everyDay,
            onChanged: (v) => setState(() => _everyDay = v),
          ),
          if (!_everyDay)
            Wrap(
              spacing: 8,
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
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bitiş tarihi (opsiyonel)'),
            subtitle: Text(
              _end == null
                  ? 'Yok'
                  : '${_end!.day}.${_end!.month}.${_end!.year}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.event),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _end ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (d != null) setState(() => _end = d);
              },
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Kaydet', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
