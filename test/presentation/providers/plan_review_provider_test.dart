import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:myassistant/presentation/providers/plan_review_provider.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/plan_review_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/data/services/plan_review_service.dart';

import 'plan_review_provider_test.mocks.dart';

@GenerateMocks([PlanReviewService])
void main() {
  late MockPlanReviewService mockService;
  late PlanReviewListNotifier notifier;

  const testUserId = 'test-user-123';

  setUp(() {
    mockService = MockPlanReviewService();
    notifier = PlanReviewListNotifier(
      service: mockService,
      userId: testUserId,
    );
  });

  /// Helper to create a test PlanModel
  PlanModel createTestPlan({
    String id = 'plan-123',
    String name = 'Test Plan',
    PlanStatus status = PlanStatus.active,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    return PlanModel(
      id: id,
      userId: testUserId,
      goalId: 'goal-123',
      name: name,
      startDate: startDate ?? now.subtract(const Duration(days: 7)),
      endDate: endDate ?? now.add(const Duration(days: 23)),
      repeatRule: const RepeatRule(type: RepeatType.daily),
      taskConfig: const TaskConfiguration(durationMinutes: 30),
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Helper to create a test PlanReviewModel
  PlanReviewModel createTestReview({
    String planId = 'plan-123',
    String planName = 'Test Plan',
    double completionRate = 0.7,
    int totalTasks = 10,
    int completedTasks = 7,
    int skippedTasks = 1,
    int activeTasks = 2,
  }) {
    return PlanReviewModel(
      plan: createTestPlan(id: planId, name: planName),
      statistics: PlanReviewStatistics(
        totalTasks: totalTasks,
        completedTasks: completedTasks,
        skippedTasks: skippedTasks,
        activeTasks: activeTasks,
        completionRate: completionRate,
      ),
      tasks: const [],
    );
  }

  group('PlanReviewListNotifier - loadPlanReviews', () {
    test('should load reviews and summary stats successfully', () async {
      // Arrange
      final reviews = [
        createTestReview(planId: 'plan-1', planName: 'Plan 1'),
        createTestReview(planId: 'plan-2', planName: 'Plan 2'),
      ];

      final summaryStats = {
        'totalPlans': 2,
        'activePlans': 2,
        'completedPlans': 0,
        'totalTasks': 20,
        'completedTasks': 14,
        'skippedTasks': 2,
        'averageCompletionRate': 0.7,
      };

      when(mockService.getUserPlanReviews(testUserId))
          .thenAnswer((_) async => reviews);
      when(mockService.getUserSummaryStatistics(testUserId))
          .thenAnswer((_) async => summaryStats);

      // Act
      await notifier.loadPlanReviews();

      // Assert
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.reviews.length, equals(2));
      expect(notifier.state.summaryStats, isNotNull);
      expect(notifier.state.summaryStats!['totalPlans'], equals(2));
      verify(mockService.getUserPlanReviews(testUserId)).called(1);
      verify(mockService.getUserSummaryStatistics(testUserId)).called(1);
    });

    test('should handle empty review list', () async {
      // Arrange
      when(mockService.getUserPlanReviews(testUserId))
          .thenAnswer((_) async => []);
      when(mockService.getUserSummaryStatistics(testUserId))
          .thenAnswer((_) async => {});

      // Act
      await notifier.loadPlanReviews();

      // Assert
      expect(notifier.state.reviews, isEmpty);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('should handle error during loadPlanReviews', () async {
      // Arrange
      when(mockService.getUserPlanReviews(testUserId))
          .thenThrow(Exception('Network error'));

      // Act
      await notifier.loadPlanReviews();

      // Assert
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('Network error'));
      expect(notifier.state.reviews, isEmpty);
    });
  });

  group('PlanReviewListNotifier - loadPlanReviewsByDateRange', () {
    test('should load reviews for a date range', () async {
      // Arrange
      final startDate = DateTime(2026, 1, 1);
      final endDate = DateTime(2026, 6, 30);
      final reviews = [
        createTestReview(planId: 'plan-1', planName: 'Q1 Plan'),
      ];

      when(mockService.getPlanReviewsByDateRange(
              testUserId, startDate, endDate))
          .thenAnswer((_) async => reviews);

      // Act
      await notifier.loadPlanReviewsByDateRange(startDate, endDate);

      // Assert
      expect(notifier.state.reviews.length, equals(1));
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      verify(mockService.getPlanReviewsByDateRange(
              testUserId, startDate, endDate))
          .called(1);
    });

    test('should handle error during loadPlanReviewsByDateRange', () async {
      // Arrange
      final startDate = DateTime(2026, 1, 1);
      final endDate = DateTime(2026, 6, 30);

      when(mockService.getPlanReviewsByDateRange(
              testUserId, startDate, endDate))
          .thenThrow(Exception('Invalid date range'));

      // Act
      await notifier.loadPlanReviewsByDateRange(startDate, endDate);

      // Assert
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('Invalid date range'));
    });
  });

  group('PlanReviewListNotifier - loadGoalPlanReviews', () {
    test('should load reviews for a specific goal', () async {
      // Arrange
      final reviews = [
        createTestReview(planId: 'plan-1', planName: 'Goal Plan 1'),
        createTestReview(planId: 'plan-2', planName: 'Goal Plan 2'),
      ];

      when(mockService.getGoalPlanReviews('goal-456'))
          .thenAnswer((_) async => reviews);

      // Act
      await notifier.loadGoalPlanReviews('goal-456');

      // Assert
      expect(notifier.state.reviews.length, equals(2));
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      verify(mockService.getGoalPlanReviews('goal-456')).called(1);
    });

    test('should handle error during loadGoalPlanReviews', () async {
      // Arrange
      when(mockService.getGoalPlanReviews('goal-456'))
          .thenThrow(Exception('Goal not found'));

      // Act
      await notifier.loadGoalPlanReviews('goal-456');

      // Assert
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('Goal not found'));
    });
  });

  group('PlanReviewListNotifier - sortByCompletionRate', () {
    test('should sort reviews descending by default', () async {
      // Arrange - load reviews with different completion rates
      final reviews = [
        createTestReview(planId: 'low', completionRate: 0.3),
        createTestReview(planId: 'high', completionRate: 0.9),
        createTestReview(planId: 'mid', completionRate: 0.6),
      ];

      when(mockService.getUserPlanReviews(testUserId))
          .thenAnswer((_) async => reviews);
      when(mockService.getUserSummaryStatistics(testUserId))
          .thenAnswer((_) async => {});

      await notifier.loadPlanReviews();

      // Act
      notifier.sortByCompletionRate();

      // Assert - descending order (highest first)
      expect(notifier.state.reviews.length, equals(3));
      expect(
          notifier.state.reviews[0].statistics.completionRate, equals(0.9));
      expect(
          notifier.state.reviews[1].statistics.completionRate, equals(0.6));
      expect(
          notifier.state.reviews[2].statistics.completionRate, equals(0.3));
    });

    test('should sort reviews ascending when specified', () async {
      // Arrange
      final reviews = [
        createTestReview(planId: 'high', completionRate: 0.9),
        createTestReview(planId: 'low', completionRate: 0.3),
        createTestReview(planId: 'mid', completionRate: 0.6),
      ];

      when(mockService.getUserPlanReviews(testUserId))
          .thenAnswer((_) async => reviews);
      when(mockService.getUserSummaryStatistics(testUserId))
          .thenAnswer((_) async => {});

      await notifier.loadPlanReviews();

      // Act
      notifier.sortByCompletionRate(ascending: true);

      // Assert - ascending order (lowest first)
      expect(
          notifier.state.reviews[0].statistics.completionRate, equals(0.3));
      expect(
          notifier.state.reviews[1].statistics.completionRate, equals(0.6));
      expect(
          notifier.state.reviews[2].statistics.completionRate, equals(0.9));
    });

    test('should handle empty list when sorting', () {
      // Act - sort on initial empty state
      notifier.sortByCompletionRate();

      // Assert
      expect(notifier.state.reviews, isEmpty);
    });
  });

  group('PlanReviewListNotifier - filterByCompletionRate', () {
    test('should filter reviews by min completion rate', () async {
      // Arrange
      final reviews = [
        createTestReview(planId: 'low', completionRate: 0.2),
        createTestReview(planId: 'mid', completionRate: 0.5),
        createTestReview(planId: 'high', completionRate: 0.8),
      ];

      when(mockService.getUserPlanReviews(testUserId))
          .thenAnswer((_) async => reviews);
      when(mockService.getUserSummaryStatistics(testUserId))
          .thenAnswer((_) async => {});

      await notifier.loadPlanReviews();

      // Act
      notifier.filterByCompletionRate(minRate: 0.5);

      // Assert - only reviews with rate >= 0.5
      expect(notifier.state.reviews.length, equals(2));
      expect(
        notifier.state.reviews
            .every((r) => r.statistics.completionRate >= 0.5),
        isTrue,
      );
    });

    test('should filter reviews by max completion rate', () async {
      // Arrange
      final reviews = [
        createTestReview(planId: 'low', completionRate: 0.2),
        createTestReview(planId: 'mid', completionRate: 0.5),
        createTestReview(planId: 'high', completionRate: 0.8),
      ];

      when(mockService.getUserPlanReviews(testUserId))
          .thenAnswer((_) async => reviews);
      when(mockService.getUserSummaryStatistics(testUserId))
          .thenAnswer((_) async => {});

      await notifier.loadPlanReviews();

      // Act
      notifier.filterByCompletionRate(maxRate: 0.5);

      // Assert - only reviews with rate <= 0.5
      expect(notifier.state.reviews.length, equals(2));
      expect(
        notifier.state.reviews
            .every((r) => r.statistics.completionRate <= 0.5),
        isTrue,
      );
    });

    test('should filter reviews by min and max rate', () async {
      // Arrange
      final reviews = [
        createTestReview(planId: 'very-low', completionRate: 0.1),
        createTestReview(planId: 'low', completionRate: 0.3),
        createTestReview(planId: 'mid', completionRate: 0.5),
        createTestReview(planId: 'high', completionRate: 0.8),
        createTestReview(planId: 'very-high', completionRate: 1.0),
      ];

      when(mockService.getUserPlanReviews(testUserId))
          .thenAnswer((_) async => reviews);
      when(mockService.getUserSummaryStatistics(testUserId))
          .thenAnswer((_) async => {});

      await notifier.loadPlanReviews();

      // Act
      notifier.filterByCompletionRate(minRate: 0.3, maxRate: 0.8);

      // Assert - only reviews with 0.3 <= rate <= 0.8
      expect(notifier.state.reviews.length, equals(3));
      expect(
        notifier.state.reviews.every(
            (r) =>
                r.statistics.completionRate >= 0.3 &&
                r.statistics.completionRate <= 0.8),
        isTrue,
      );
    });

    test('should return empty list when no reviews match filter', () async {
      // Arrange
      final reviews = [
        createTestReview(planId: 'low', completionRate: 0.2),
      ];

      when(mockService.getUserPlanReviews(testUserId))
          .thenAnswer((_) async => reviews);
      when(mockService.getUserSummaryStatistics(testUserId))
          .thenAnswer((_) async => {});

      await notifier.loadPlanReviews();

      // Act
      notifier.filterByCompletionRate(minRate: 0.9, maxRate: 1.0);

      // Assert
      expect(notifier.state.reviews, isEmpty);
    });
  });

  group('PlanReviewListNotifier - loadPlansNeedingAttention', () {
    test('should load plans needing attention', () async {
      // Arrange
      final reviews = [
        createTestReview(
          planId: 'struggling-plan',
          planName: 'Struggling',
          completionRate: 0.3,
        ),
      ];

      when(mockService.getPlansNeedingAttention(testUserId))
          .thenAnswer((_) async => reviews);

      // Act
      await notifier.loadPlansNeedingAttention();

      // Assert
      expect(notifier.state.reviews.length, equals(1));
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      verify(mockService.getPlansNeedingAttention(testUserId)).called(1);
    });

    test('should handle empty list when no plans need attention', () async {
      // Arrange
      when(mockService.getPlansNeedingAttention(testUserId))
          .thenAnswer((_) async => []);

      // Act
      await notifier.loadPlansNeedingAttention();

      // Assert
      expect(notifier.state.reviews, isEmpty);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('should handle error during loadPlansNeedingAttention', () async {
      // Arrange
      when(mockService.getPlansNeedingAttention(testUserId))
          .thenThrow(Exception('Service unavailable'));

      // Act
      await notifier.loadPlansNeedingAttention();

      // Assert
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('Service unavailable'));
    });
  });

  group('PlanReviewListState', () {
    test('initial state should have defaults', () {
      const state = PlanReviewListState();

      expect(state.reviews, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.summaryStats, isNull);
    });

    test('copyWith should update specified fields', () {
      const initial = PlanReviewListState();
      final review = createTestReview();

      final updated = initial.copyWith(
        reviews: [review],
        isLoading: true,
        error: 'test error',
      );

      expect(updated.reviews.length, equals(1));
      expect(updated.isLoading, isTrue);
      expect(updated.error, equals('test error'));
      expect(updated.summaryStats, isNull); // unchanged
    });

    test('copyWith with error null clears error', () {
      final withError =
          const PlanReviewListState().copyWith(error: 'an error');
      expect(withError.error, equals('an error'));

      // copyWith without error param clears it because error defaults to null
      final cleared = withError.copyWith(isLoading: false);
      expect(cleared.error, isNull);
    });
  });

  group('PlanReviewListNotifier - sequential operations', () {
    test('loading then sorting should work correctly', () async {
      // Arrange
      final reviews = [
        createTestReview(planId: 'a', completionRate: 0.3),
        createTestReview(planId: 'b', completionRate: 0.9),
        createTestReview(planId: 'c', completionRate: 0.6),
      ];

      when(mockService.getUserPlanReviews(testUserId))
          .thenAnswer((_) async => reviews);
      when(mockService.getUserSummaryStatistics(testUserId))
          .thenAnswer((_) async => {});

      // Act - load then sort
      await notifier.loadPlanReviews();
      notifier.sortByCompletionRate(ascending: true);

      // Assert - sorted ascending
      expect(notifier.state.reviews.length, equals(3));
      expect(
          notifier.state.reviews[0].statistics.completionRate, equals(0.3));
      expect(
          notifier.state.reviews[2].statistics.completionRate, equals(0.9));
    });

    test('loading then filtering should work correctly', () async {
      // Arrange
      final reviews = [
        createTestReview(planId: 'a', completionRate: 0.2),
        createTestReview(planId: 'b', completionRate: 0.5),
        createTestReview(planId: 'c', completionRate: 0.9),
      ];

      when(mockService.getUserPlanReviews(testUserId))
          .thenAnswer((_) async => reviews);
      when(mockService.getUserSummaryStatistics(testUserId))
          .thenAnswer((_) async => {});

      // Act - load then filter
      await notifier.loadPlanReviews();
      notifier.filterByCompletionRate(minRate: 0.5);

      // Assert - filtered to >= 0.5
      expect(notifier.state.reviews.length, equals(2));
    });

    test('filter reduces list and cannot be undone without reload', () async {
      // Arrange
      final reviews = [
        createTestReview(planId: 'a', completionRate: 0.2),
        createTestReview(planId: 'b', completionRate: 0.8),
      ];

      when(mockService.getUserPlanReviews(testUserId))
          .thenAnswer((_) async => reviews);
      when(mockService.getUserSummaryStatistics(testUserId))
          .thenAnswer((_) async => {});

      await notifier.loadPlanReviews();
      expect(notifier.state.reviews.length, equals(2));

      // Act - filter to only high rate
      notifier.filterByCompletionRate(minRate: 0.7);
      expect(notifier.state.reviews.length, equals(1));

      // Further filter should work on the already-filtered list
      notifier.filterByCompletionRate(minRate: 0.9);
      expect(notifier.state.reviews.length, equals(0));

      // Reload restores all reviews
      await notifier.loadPlanReviews();
      expect(notifier.state.reviews.length, equals(2));
    });
  });
}
