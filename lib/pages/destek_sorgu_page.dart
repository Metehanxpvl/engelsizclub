import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/destek_sorgu_data.dart';
import '../meto_theme.dart';
import '../services/destek_sorgu_store.dart' show loadDestekSorguUrunler;
import '../widgets/guest_timed_guard.dart';

/// Daha Fazlası URL’si HTML’dir; bu sayfa sonraki uygulama sürümü içindir.
class DestekSorguPage extends StatefulWidget {
  const DestekSorguPage({super.key});

  static Future<void> open(
    BuildContext context, {
    bool isGuest = false,
    VoidCallback? onRequireLogin,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GuestTimedGuard(
          isGuest: isGuest,
          tab: 'daha_fazlasi',
          onRequireLogin: onRequireLogin,
          child: const DestekSorguPage(),
        ),
      ),
    );
  }

  @override
  State<DestekSorguPage> createState() => _DestekSorguPageState();
}

class _DestekSorguPageState extends State<DestekSorguPage> {
  final _money = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  final _quoteCtrl = TextEditingController();
  List<DestekSorguUrun> _items = kDestekSorguFallback;
  DestekSorguUrun? _item;
  DateTime _start = DateTime.now();
  DateTime? _end;
  var _endTouched = false;

  DestekSorguUrun get _current => _item ?? _items.first;

  @override
  void initState() {
    super.initState();
    _item = _items.first;
    _end = addRenewMonths(_start, _current.renewMonths);
    _quoteCtrl.addListener(() => setState(() {}));
    _loadCatalog();
  }

  @override
  void dispose() {
    _quoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final items = await loadDestekSorguUrunler();
    if (!mounted || items.isEmpty) return;
    setState(() {
      _items = items;
      _item = items.firstWhere(
        (e) => e.id == _current.id,
        orElse: () => items.first,
      );
      if (!_endTouched) {
        _end = addRenewMonths(_start, _current.renewMonths);
      }
    });
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _start : (_end ?? _start);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2018),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (!_endTouched) _end = addRenewMonths(picked, _current.renewMonths);
      } else {
        _end = picked;
        _endTouched = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final quote = double.tryParse(_quoteCtrl.text.replaceAll(',', '.'));
    final calc = DestekSorguHesap.fromQuote(_current.sutPrice, quote);
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: const Text('Destek Sorgu'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Text(
            'Gösterilen tutar SGK SUT eklerinin SUT FİYATI (TL) sütunudur '
            '(EK-3/C-2–C-5, Yür. 24.01.2026). Sağlık Bakanlığı fiyat tarifesi değildir. '
            'KDV eklenmemiştir. Tebliğ değişirse tebliğ esas alınır.',
            style: TextStyle(color: Colors.brown.shade800, height: 1.45),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(_current.id),
            initialValue: _current.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Malzeme / cihaz',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final item in _items)
                DropdownMenuItem(
                  value: item.id,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) {
              final next = _items.firstWhere((e) => e.id == id);
              setState(() {
                _item = next;
                _endTouched = false;
                _end = addRenewMonths(_start, next.renewMonths);
              });
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MetoColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yenileme süresi',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  _current.renewLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _stat('SUT fiyatı (tablo)', _money.format(_current.sutPrice)),
          _stat(
            'SGK katkısı (üst sınır)',
            calc == null ? 'Teklif girin' : _money.format(calc.sgkPay),
          ),
          _stat(
            'Cebinizden çıkacak fark',
            calc == null ? 'Teklif girin' : _money.format(calc.pocket),
            danger: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quoteCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Teklif fiyatı (TL)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Teslim / rapor başlangıcı'),
            subtitle: Text(DateFormat('dd.MM.yyyy').format(_start)),
            onTap: () => _pickDate(start: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rapor bitiş tarihi'),
            subtitle: Text(
              _end == null ? 'Seçin' : DateFormat('dd.MM.yyyy').format(_end!),
            ),
            onTap: () => _pickDate(start: false),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {bool danger = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFDECEA) : MetoColors.selectedBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: MetoColors.mutedFg, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: danger ? const Color(0xFF8C1D18) : MetoColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
