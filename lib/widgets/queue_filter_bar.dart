import 'package:flutter/material.dart';

import '../meto_theme.dart';

/// Admin onay kuyrukları için ortak filtre: tarih, kategori, sıralama.
/// Sadece ekranda yüklü listeyi süzer; veritabanı sorgularına dokunmaz.

enum QueueDateRange { all, today, yesterday }

enum QueueSort { newest, score }

class QueueFilterState {
  const QueueFilterState({
    this.date = QueueDateRange.all,
    this.category,
    this.sort = QueueSort.newest,
  });

  final QueueDateRange date;
  final String? category;
  final QueueSort sort;

  QueueFilterState copyWith({
    QueueDateRange? date,
    String? category,
    bool clearCategory = false,
    QueueSort? sort,
  }) {
    return QueueFilterState(
      date: date ?? this.date,
      category: clearCategory ? null : (category ?? this.category),
      sort: sort ?? this.sort,
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<T> applyQueueFilter<T>(
  List<T> items,
  QueueFilterState state, {
  required DateTime? Function(T) createdAt,
  required String? Function(T) category,
  num? Function(T)? score,
  DateTime? now,
}) {
  final today = (now ?? DateTime.now()).toLocal();
  final yesterday = today.subtract(const Duration(days: 1));
  final out = items.where((e) {
    if (state.date != QueueDateRange.all) {
      final c = createdAt(e)?.toLocal();
      if (c == null) return false;
      final target =
          state.date == QueueDateRange.today ? today : yesterday;
      if (!_sameDay(c, target)) return false;
    }
    if (state.category != null && category(e) != state.category) return false;
    return true;
  }).toList();
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  if (state.sort == QueueSort.score && score != null) {
    out.sort((a, b) => (score(b) ?? -1).compareTo(score(a) ?? -1));
  } else {
    out.sort((a, b) => (createdAt(b) ?? epoch).compareTo(createdAt(a) ?? epoch));
  }
  return out;
}

/// Listedeki kategorileri alfabetik, tekrarsız çıkarır.
List<String> queueCategories<T>(List<T> items, String? Function(T) category) {
  final set = <String>{};
  for (final e in items) {
    final c = category(e)?.trim();
    if (c != null && c.isNotEmpty) set.add(c);
  }
  final list = set.toList()..sort();
  return list;
}

class QueueFilterBar extends StatelessWidget {
  const QueueFilterBar({
    super.key,
    required this.state,
    required this.categories,
    required this.onChanged,
    this.showScoreSort = true,
  });

  final QueueFilterState state;
  final List<String> categories;
  final ValueChanged<QueueFilterState> onChanged;
  final bool showScoreSort;

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: MetoColors.selectedBg,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: selected ? MetoColors.primary : MetoColors.mutedFg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = categories.contains(state.category) ? state.category : null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          _chip('Tümü', state.date == QueueDateRange.all,
              () => onChanged(state.copyWith(date: QueueDateRange.all))),
          _chip('Bugün', state.date == QueueDateRange.today,
              () => onChanged(state.copyWith(date: QueueDateRange.today))),
          _chip('Dün', state.date == QueueDateRange.yesterday,
              () => onChanged(state.copyWith(date: QueueDateRange.yesterday))),
          if (categories.isNotEmpty) ...[
            const SizedBox(width: 6),
            DropdownButton<String?>(
              value: cat,
              hint: const Text('Kategori'),
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tüm kategoriler'),
                ),
                for (final c in categories)
                  DropdownMenuItem<String?>(value: c, child: Text(c)),
              ],
              onChanged: (v) => onChanged(
                v == null
                    ? state.copyWith(clearCategory: true)
                    : state.copyWith(category: v),
              ),
            ),
          ],
          if (showScoreSort) ...[
            const SizedBox(width: 10),
            _chip(
              state.sort == QueueSort.score ? 'Sıra: Alaka puanı' : 'Sıra: En yeni',
              state.sort == QueueSort.score,
              () => onChanged(state.copyWith(
                sort: state.sort == QueueSort.score
                    ? QueueSort.newest
                    : QueueSort.score,
              )),
            ),
          ],
        ],
      ),
    );
  }
}
