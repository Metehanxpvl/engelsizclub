import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/forum_data.dart';
import '../../../meto_theme.dart';
import '../providers/forum_providers.dart';
import 'forum_filter_bar.dart';
import 'forum_topic_card.dart';
import '../../../l10n/l10n_text.dart';

/// Server-side filtre + sonsuz kaydırma forum listesi.
class ForumScaledFeed extends ConsumerStatefulWidget {
  const ForumScaledFeed({
    super.key,
    required this.onOpenTopic,
    this.header,
  });

  final ValueChanged<ForumPost> onOpenTopic;
  final Widget? header;

  @override
  ConsumerState<ForumScaledFeed> createState() => _ForumScaledFeedState();
}

class _ForumScaledFeedState extends ConsumerState<ForumScaledFeed> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 420) {
      ref.read(forumTopicsProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    await ref.read(forumTopicsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forumTopicsProvider);
    final filter = ref.watch(forumFilterProvider);
    final filterHeight = filter.diseaseId == null ? 168.0 : 208.0;

    return ColoredBox(
      color: MetoColors.background,
      child: RefreshIndicator(
        color: MetoColors.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.header != null)
              SliverToBoxAdapter(child: widget.header!),
            SliverPersistentHeader(
              pinned: true,
              delegate: _FilterHeaderDelegate(
                child: const ForumFilterBar(),
                height: filterHeight,
              ),
            ),
            if (state.loading && state.items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: MetoColors.primary),
                ),
              )
            else if (state.error != null && state.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorBox(
                  message: state.error!,
                  onRetry: _refresh,
                ),
              )
            else if (state.items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: L10nText(
                      'Bu filtrelerle konu bulunamadı.\nFiltreleri temizleyip tekrar deneyin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MetoColors.mutedFg),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverList.builder(
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= state.items.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: state.loadingMore
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: MetoColors.primary,
                                  ),
                                )
                              : TextButton(
                                  onPressed: () => ref
                                      .read(forumTopicsProvider.notifier)
                                      .loadMore(),
                                  child: const L10nText('Daha fazla yükle'),
                                ),
                        ),
                      );
                    }
                    final topic = state.items[i];
                    return ForumTopicCard(
                      topic: topic,
                      onTap: () {
                        ref
                            .read(forumRepositoryProvider)
                            .incrementViews(topic.id);
                        widget.onOpenTopic(topic.toForumPost());
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Liste yüklenemedi.\nSupabase’de forum_scale_taxonomy.sql çalıştırın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: MetoColors.mutedFg),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const L10nText('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  _FilterHeaderDelegate({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 2 : 0,
      child: SizedBox(height: height, child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}
