import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/forum_topic.dart';
import '../providers/forum_providers.dart';
import '../../../meto_theme.dart';
import '../../../l10n/app_strings.dart';
import '../../../l10n/l10n_text.dart';

/// Sticky arama + hızlı filtre çipleri (ana hastalıklar).
class ForumFilterBar extends ConsumerStatefulWidget {
  const ForumFilterBar({super.key});

  @override
  ConsumerState<ForumFilterBar> createState() => _ForumFilterBarState();
}

class _ForumFilterBarState extends ConsumerState<ForumFilterBar> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(forumFilterProvider);
    final diseasesAsync = ref.watch(forumDiseasesProvider);
    final subsAsync = ref.watch(forumSubCategoriesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 1,
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (v) =>
                  ref.read(forumFilterProvider.notifier).setQuery(v),
              decoration: InputDecoration(
                hintText: S.auto('Konu, içerik veya etiket ara…'),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: filter.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _search.clear();
                          ref.read(forumFilterProvider.notifier).setQuery('');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: diseasesAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (diseases) {
                // Ana sayfada yalnız ana hastalıklar (+ Tümü)
                final main =
                    diseases.where((d) => (d.id) != 'genel').toList();
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const L10nText('Tümü'),
                        selected: filter.diseaseId == null,
                        onSelected: (_) => ref
                            .read(forumFilterProvider.notifier)
                            .setDisease(null),
                        selectedColor: MetoColors.primary.withValues(alpha: 0.18),
                        checkmarkColor: MetoColors.primary,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: filter.diseaseId == null
                              ? MetoColors.primary
                              : MetoColors.mutedFg,
                        ),
                      ),
                    ),
                    for (final d in main)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(d.chipLabel),
                          selected: filter.diseaseId == d.id,
                          onSelected: (on) => ref
                              .read(forumFilterProvider.notifier)
                              .setDisease(on ? d.id : null),
                          selectedColor:
                              MetoColors.primary.withValues(alpha: 0.18),
                          checkmarkColor: MetoColors.primary,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: filter.diseaseId == d.id
                                ? MetoColors.primary
                                : MetoColors.mutedFg,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final s in ForumSortMode.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(s.label, style: const TextStyle(fontSize: 11)),
                      selected: filter.sort == s,
                      onSelected: (_) =>
                          ref.read(forumFilterProvider.notifier).setSort(s),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const L10nText('Çözüldü', style: TextStyle(fontSize: 11)),
                    selected: filter.resolvedOnly == true,
                    onSelected: (on) => ref
                        .read(forumFilterProvider.notifier)
                        .setResolved(on ? true : null),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                for (final age in kForumAgeGroups)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(age, style: const TextStyle(fontSize: 11)),
                      selected: filter.ageGroup == age,
                      onSelected: (on) => ref
                          .read(forumFilterProvider.notifier)
                          .setAgeGroup(on ? age : null),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          if (filter.diseaseId != null)
            subsAsync.when(
              loading: () => const SizedBox(height: 4),
              error: (_, __) => const SizedBox.shrink(),
              data: (subs) {
                if (subs.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final s in subs)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(
                                s.label,
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: filter.subCategoryId == s.id,
                              onSelected: (on) => ref
                                  .read(forumFilterProvider.notifier)
                                  .setSubCategory(on ? s.id : null),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
