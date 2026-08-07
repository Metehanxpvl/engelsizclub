import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/forum_repository_impl.dart';
import '../../domain/entities/forum_disease.dart';
import '../../domain/entities/forum_topic.dart';
import '../../domain/repositories/forum_repository.dart';

final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  return ForumRepositoryImpl();
});

/// Çoklu filtre state.
class ForumFilterNotifier extends StateNotifier<ForumFilterParams> {
  ForumFilterNotifier() : super(ForumFilterParams.empty);

  void setDisease(String? id) {
    state = state.copyWith(
      diseaseId: id,
      clearDisease: id == null || id.isEmpty,
      clearSubCategory: true,
    );
  }

  void setSubCategory(String? id) {
    state = state.copyWith(
      subCategoryId: id,
      clearSubCategory: id == null || id.isEmpty,
    );
  }

  void setAgeGroup(String? age) {
    state = state.copyWith(
      ageGroup: age,
      clearAgeGroup: age == null || age.isEmpty,
    );
  }

  void setTag(String? tag) {
    state = state.copyWith(
      tag: tag,
      clearTag: tag == null || tag.isEmpty,
    );
  }

  void setResolved(bool? value) {
    state = state.copyWith(
      resolvedOnly: value,
      clearResolved: value == null,
    );
  }

  void setQuery(String q) {
    state = state.copyWith(query: q);
  }

  void setSort(ForumSortMode sort) {
    state = state.copyWith(sort: sort);
  }

  void reset() => state = ForumFilterParams.empty;
}

final forumFilterProvider =
    StateNotifierProvider<ForumFilterNotifier, ForumFilterParams>((ref) {
  return ForumFilterNotifier();
});

final forumDiseasesProvider = FutureProvider<List<ForumDisease>>((ref) async {
  return ref.watch(forumRepositoryProvider).fetchDiseases();
});

final forumSubCategoriesProvider =
    FutureProvider.autoDispose<List<ForumSubCategory>>((ref) async {
  final diseaseId = ref.watch(forumFilterProvider).diseaseId;
  return ref
      .watch(forumRepositoryProvider)
      .fetchSubCategories(diseaseId: diseaseId);
});

class ForumTopicsState {
  const ForumTopicsState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final List<ForumTopic> items;
  final int page;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;
  final String? error;

  ForumTopicsState copyWith({
    List<ForumTopic>? items,
    int? page,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
  }) =>
      ForumTopicsState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class ForumTopicsNotifier extends StateNotifier<ForumTopicsState> {
  ForumTopicsNotifier(this._ref) : super(const ForumTopicsState()) {
    _sub = _ref.listen<ForumFilterParams>(forumFilterProvider, (prev, next) {
      if (prev != next) {
        refresh();
      }
    });
    refresh();
  }

  final Ref _ref;
  ProviderSubscription<ForumFilterParams>? _sub;
  static const _pageSize = 20;

  ForumRepository get _repo => _ref.read(forumRepositoryProvider);

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true, page: 0);
    try {
      final filter = _ref.read(forumFilterProvider);
      final pageData = await _repo.fetchTopics(
        filter: filter,
        page: 0,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      state = ForumTopicsState(
        items: pageData.items,
        page: 0,
        hasMore: pageData.hasMore,
        loading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final nextPage = state.page + 1;
      final filter = _ref.read(forumFilterProvider);
      final pageData = await _repo.fetchTopics(
        filter: filter,
        page: nextPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      state = state.copyWith(
        items: [...state.items, ...pageData.items],
        page: nextPage,
        hasMore: pageData.hasMore,
        loadingMore: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loadingMore: false, error: '$e');
    }
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}

final forumTopicsProvider =
    StateNotifierProvider<ForumTopicsNotifier, ForumTopicsState>((ref) {
  return ForumTopicsNotifier(ref);
});
