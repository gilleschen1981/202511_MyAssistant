import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/plan_review_model.dart';
import 'package:myassistant/data/services/plan_review_service.dart';
import 'package:myassistant/di/providers/repository_providers.dart';
import 'package:myassistant/core/utils/app_logger.dart';

/// Provider for Plan Review Service
final planReviewServiceProvider = Provider<PlanReviewService>((ref) {
  return PlanReviewService(
    planRepository: ref.watch(planRepositoryProvider),
    taskRepository: ref.watch(taskRepositoryProvider),
  );
});

/// Plan Review List State
class PlanReviewListState {
  final List<PlanReviewModel> reviews;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? summaryStats;

  const PlanReviewListState({
    this.reviews = const [],
    this.isLoading = false,
    this.error,
    this.summaryStats,
  });

  PlanReviewListState copyWith({
    List<PlanReviewModel>? reviews,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? summaryStats,
  }) {
    return PlanReviewListState(
      reviews: reviews ?? this.reviews,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      summaryStats: summaryStats ?? this.summaryStats,
    );
  }
}

/// Plan Review List Notifier
class PlanReviewListNotifier extends StateNotifier<PlanReviewListState> {
  final PlanReviewService _service;
  final String _userId;

  PlanReviewListNotifier({
    required PlanReviewService service,
    required String userId,
  })  : _service = service,
        _userId = userId,
        super(const PlanReviewListState());

  /// Load all plan reviews for user
  Future<void> loadPlanReviews() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final reviews = await _service.getUserPlanReviews(_userId);
      final summaryStats = await _service.getUserSummaryStatistics(_userId);

      state = state.copyWith(
        reviews: reviews,
        summaryStats: summaryStats,
        isLoading: false,
      );

      AppLogger.i(
        'Loaded ${reviews.length} plan reviews',
        tag: 'PlanReviewListNotifier',
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to load plan reviews',
        error: e,
        stackTrace: stackTrace,
        tag: 'PlanReviewListNotifier',
      );
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load plan reviews by date range
  Future<void> loadPlanReviewsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final reviews = await _service.getPlanReviewsByDateRange(
        _userId,
        startDate,
        endDate,
      );

      state = state.copyWith(
        reviews: reviews,
        isLoading: false,
      );

      AppLogger.i(
        'Loaded ${reviews.length} plan reviews for date range',
        tag: 'PlanReviewListNotifier',
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to load plan reviews by date range',
        error: e,
        stackTrace: stackTrace,
        tag: 'PlanReviewListNotifier',
      );
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load plan reviews for a specific goal
  Future<void> loadGoalPlanReviews(String goalId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final reviews = await _service.getGoalPlanReviews(goalId);

      state = state.copyWith(
        reviews: reviews,
        isLoading: false,
      );

      AppLogger.i(
        'Loaded ${reviews.length} plan reviews for goal',
        tag: 'PlanReviewListNotifier',
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to load goal plan reviews',
        error: e,
        stackTrace: stackTrace,
        tag: 'PlanReviewListNotifier',
      );
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Sort reviews by completion rate
  void sortByCompletionRate({bool ascending = false}) {
    final sorted = List<PlanReviewModel>.from(state.reviews);
    sorted.sort((a, b) {
      final comparison = a.statistics.completionRate.compareTo(
        b.statistics.completionRate,
      );
      return ascending ? comparison : -comparison;
    });

    state = state.copyWith(reviews: sorted);
  }

  /// Filter reviews by completion rate threshold
  void filterByCompletionRate({double minRate = 0.0, double maxRate = 1.0}) {
    final filtered = state.reviews.where((review) {
      final rate = review.statistics.completionRate;
      return rate >= minRate && rate <= maxRate;
    }).toList();

    state = state.copyWith(reviews: filtered);
  }

  /// Get plans needing attention
  Future<void> loadPlansNeedingAttention() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final reviews = await _service.getPlansNeedingAttention(_userId);

      state = state.copyWith(
        reviews: reviews,
        isLoading: false,
      );

      AppLogger.i(
        'Loaded ${reviews.length} plans needing attention',
        tag: 'PlanReviewListNotifier',
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to load plans needing attention',
        error: e,
        stackTrace: stackTrace,
        tag: 'PlanReviewListNotifier',
      );
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// Plan Review List Provider
final planReviewListProvider = StateNotifierProvider.family<
    PlanReviewListNotifier,
    PlanReviewListState,
    String>((ref, userId) {
  return PlanReviewListNotifier(
    service: ref.watch(planReviewServiceProvider),
    userId: userId,
  );
});

/// Single Plan Review Provider
final planReviewProvider = FutureProvider.family<PlanReviewModel?, String>(
  (ref, planId) async {
    final service = ref.watch(planReviewServiceProvider);
    return await service.getPlanReview(planId);
  },
);
