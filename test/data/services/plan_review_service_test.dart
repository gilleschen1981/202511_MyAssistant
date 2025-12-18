import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:myassistant/data/services/plan_review_service.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_review_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';

import 'plan_review_service_test.mocks.dart';

@GenerateMocks([IPlanRepository, ITaskRepository])
void main() {
  late PlanReviewService service;
  late MockIPlanRepository mockPlanRepository;
  late MockITaskRepository mockTaskRepository;

  setUp(() {
    mockPlanRepository = MockIPlanRepository();
    mockTaskRepository = MockITaskRepository();
    service = PlanReviewService(
      planRepository: mockPlanRepository,
      taskRepository: mockTaskRepository,
    );
  });

  // Helper function to create a test plan
  PlanModel createTestPlan({
    String id = 'plan-123',
    String userId = 'user-123',
    String goalId = 'goal-123',
    String name = 'Test Plan',
    PlanStatus status = PlanStatus.active,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    return PlanModel(
      id: id,
      userId: userId,
      name: name,
      goalId: goalId,
      startDate: startDate ?? now.subtract(const Duration(days: 7)),
      endDate: endDate ?? now.add(const Duration(days: 23)),
      repeatRule: const RepeatRule(type: RepeatType.weekly),
      taskConfig: const TaskConfiguration(durationMinutes: 30),
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Helper function to create a test task
  TaskModel createTestTask({
    String id = 'task-123',
    String planId = 'plan-123',
    TaskStatus status = TaskStatus.active,
    int? actualDurationMinutes,
    DateTime? completedAt,
    DateTime? skippedAt,
  }) {
    final now = DateTime.now();
    return TaskModel(
      id: id,
      userId: 'user-123',
      planId: planId,
      name: 'Test Task',
      config: const TaskConfiguration(),
      windowStartTime: now,
      windowEndTime: now.add(const Duration(days: 7)),
      status: status,
      actualDurationMinutes: actualDurationMinutes,
      completedAt: completedAt,
      skippedAt: skippedAt,
      createdAt: now,
    );
  }

  group('PlanReviewService - getPlanReview', () {
    test('should return plan review with statistics for existing plan', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);
      final tasks = [
        createTestTask(
          id: 'task-1',
          status: TaskStatus.completed,
          actualDurationMinutes: 25,
          completedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        createTestTask(
          id: 'task-2',
          status: TaskStatus.completed,
          actualDurationMinutes: 30,
          completedAt: DateTime.now(),
        ),
        createTestTask(
          id: 'task-3',
          status: TaskStatus.active,
        ),
        createTestTask(
          id: 'task-4',
          status: TaskStatus.skipped,
          skippedAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      ];

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);
      when(mockTaskRepository.getPlanTasks(planId))
          .thenAnswer((_) async => tasks);

      // Act
      final result = await service.getPlanReview(planId);

      // Assert
      expect(result, isNotNull);
      expect(result!.plan.id, planId);
      expect(result.statistics.totalTasks, 4);
      expect(result.statistics.completedTasks, 2);
      expect(result.statistics.activeTasks, 1);
      expect(result.statistics.skippedTasks, 1);
      expect(result.statistics.completionRate, 0.5);
      expect(result.statistics.avgDurationMinutes, 27.5);
      expect(result.statistics.lastCompletedTaskAt, isNotNull);
      expect(result.statistics.lastSkippedTaskAt, isNotNull);
    });

    test('should return null for non-existent plan', () async {
      // Arrange
      when(mockPlanRepository.getPlanById(any))
          .thenAnswer((_) async => null);

      // Act
      final result = await service.getPlanReview('non-existent');

      // Assert
      expect(result, isNull);
    });

    test('should handle plan with no tasks', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);
      when(mockTaskRepository.getPlanTasks(planId))
          .thenAnswer((_) async => []);

      // Act
      final result = await service.getPlanReview(planId);

      // Assert
      expect(result, isNotNull);
      expect(result!.statistics.totalTasks, 0);
      expect(result.statistics.completionRate, 0.0);
      expect(result.statistics.avgDurationMinutes, isNull);
    });
  });

  group('PlanReviewService - getUserPlanReviews', () {
    test('should return all plan reviews for user', () async {
      // Arrange
      const userId = 'user-123';
      final plan1 = createTestPlan(id: 'plan-1', userId: userId);
      final plan2 = createTestPlan(id: 'plan-2', userId: userId);
      final tasks1 = [
        createTestTask(id: 'task-1', planId: 'plan-1', status: TaskStatus.completed),
      ];
      final tasks2 = [
        createTestTask(id: 'task-2', planId: 'plan-2', status: TaskStatus.active),
      ];

      when(mockPlanRepository.getUserPlans(userId))
          .thenAnswer((_) async => [plan1, plan2]);
      when(mockPlanRepository.getPlanById('plan-1'))
          .thenAnswer((_) async => plan1);
      when(mockPlanRepository.getPlanById('plan-2'))
          .thenAnswer((_) async => plan2);
      when(mockTaskRepository.getPlanTasks('plan-1'))
          .thenAnswer((_) async => tasks1);
      when(mockTaskRepository.getPlanTasks('plan-2'))
          .thenAnswer((_) async => tasks2);

      // Act
      final result = await service.getUserPlanReviews(userId);

      // Assert
      expect(result.length, 2);
      expect(result[0].plan.id, 'plan-1');
      expect(result[1].plan.id, 'plan-2');
    });

    test('should handle user with no plans', () async {
      // Arrange
      const userId = 'user-123';
      when(mockPlanRepository.getUserPlans(userId))
          .thenAnswer((_) async => []);

      // Act
      final result = await service.getUserPlanReviews(userId);

      // Assert
      expect(result, isEmpty);
    });
  });

  group('PlanReviewService - getPlanReviewsByDateRange', () {
    test('should filter plans by date range', () async {
      // Arrange
      const userId = 'user-123';
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 10));
      final endDate = now.add(const Duration(days: 10));

      final planInRange = createTestPlan(
        id: 'plan-in-range',
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 5)),
      );
      final planOutOfRange = createTestPlan(
        id: 'plan-out-of-range',
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.subtract(const Duration(days: 20)),
      );

      when(mockPlanRepository.getPlansByDateRange(userId, startDate, endDate))
          .thenAnswer((_) async => [planInRange]);
      when(mockPlanRepository.getPlanById('plan-in-range'))
          .thenAnswer((_) async => planInRange);
      when(mockTaskRepository.getPlanTasks(any))
          .thenAnswer((_) async => []);

      // Act
      final result = await service.getPlanReviewsByDateRange(
        userId,
        startDate,
        endDate,
      );

      // Assert
      expect(result.length, 1);
      expect(result.first.plan.id, 'plan-in-range');
    });

    test('should handle empty date range', () async {
      // Arrange
      const userId = 'user-123';
      final now = DateTime.now();
      when(mockPlanRepository.getPlansByDateRange(userId, now, now))
          .thenAnswer((_) async => []);

      // Act
      final result = await service.getPlanReviewsByDateRange(
        userId,
        now,
        now,
      );

      // Assert
      expect(result, isEmpty);
    });
  });

  group('PlanReviewService - getGoalPlanReviews', () {
    test('should return plan reviews for specific goal', () async {
      // Arrange
      const goalId = 'goal-123';
      final plan1 = createTestPlan(id: 'plan-1', goalId: goalId);
      final plan2 = createTestPlan(id: 'plan-2', goalId: goalId);

      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => [plan1, plan2]);
      when(mockPlanRepository.getPlanById('plan-1'))
          .thenAnswer((_) async => plan1);
      when(mockPlanRepository.getPlanById('plan-2'))
          .thenAnswer((_) async => plan2);
      when(mockTaskRepository.getPlanTasks(any))
          .thenAnswer((_) async => []);

      // Act
      final result = await service.getGoalPlanReviews(goalId);

      // Assert
      expect(result.length, 2);
      expect(result[0].plan.goalId, goalId);
      expect(result[1].plan.goalId, goalId);
    });

    test('should handle goal with no plans', () async {
      // Arrange
      const goalId = 'goal-123';
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => []);

      // Act
      final result = await service.getGoalPlanReviews(goalId);

      // Assert
      expect(result, isEmpty);
    });
  });

  group('PlanReviewService - getUserSummaryStatistics', () {
    test('should calculate summary statistics for user', () async {
      // Arrange
      const userId = 'user-123';
      final plan1 = createTestPlan(id: 'plan-1');
      final plan2 = createTestPlan(id: 'plan-2');
      final tasks1 = [
        createTestTask(status: TaskStatus.completed, actualDurationMinutes: 30),
        createTestTask(status: TaskStatus.completed, actualDurationMinutes: 25),
      ];
      final tasks2 = [
        createTestTask(status: TaskStatus.active),
        createTestTask(status: TaskStatus.skipped),
      ];

      when(mockPlanRepository.getUserPlans(userId))
          .thenAnswer((_) async => [plan1, plan2]);
      when(mockPlanRepository.getPlanById('plan-1'))
          .thenAnswer((_) async => plan1);
      when(mockPlanRepository.getPlanById('plan-2'))
          .thenAnswer((_) async => plan2);
      when(mockTaskRepository.getPlanTasks('plan-1'))
          .thenAnswer((_) async => tasks1);
      when(mockTaskRepository.getPlanTasks('plan-2'))
          .thenAnswer((_) async => tasks2);

      // Act
      final result = await service.getUserSummaryStatistics(userId);

      // Assert
      expect(result['totalPlans'], 2);
      expect(result['activePlans'], greaterThanOrEqualTo(0));
      expect(result['totalTasks'], 4);
      expect(result['completedTasks'], 2);
      expect(result['skippedTasks'], 1);
      expect(result['averageCompletionRate'], closeTo(0.5, 0.01));
    });

    test('should handle user with no plans in summary', () async {
      // Arrange
      const userId = 'user-123';
      when(mockPlanRepository.getUserPlans(userId))
          .thenAnswer((_) async => []);

      // Act
      final result = await service.getUserSummaryStatistics(userId);

      // Assert
      expect(result['totalPlans'], 0);
      expect(result['totalTasks'], 0);
      expect(result['averageCompletionRate'], 0.0);
    });
  });

  group('PlanReviewService - getPlansSortedByCompletionRate', () {
    test('should sort plans by completion rate descending', () async {
      // Arrange
      const userId = 'user-123';
      final plan1 = createTestPlan(id: 'plan-1', name: 'Low Completion');
      final plan2 = createTestPlan(id: 'plan-2', name: 'High Completion');
      final plan3 = createTestPlan(id: 'plan-3', name: 'Medium Completion');

      final tasks1 = [
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.active),
        createTestTask(status: TaskStatus.active),
        createTestTask(status: TaskStatus.active),
      ]; // 25% completion
      final tasks2 = [
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.active),
      ]; // 75% completion
      final tasks3 = [
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.active),
      ]; // 50% completion

      when(mockPlanRepository.getUserPlans(userId))
          .thenAnswer((_) async => [plan1, plan2, plan3]);
      when(mockPlanRepository.getPlanById('plan-1'))
          .thenAnswer((_) async => plan1);
      when(mockPlanRepository.getPlanById('plan-2'))
          .thenAnswer((_) async => plan2);
      when(mockPlanRepository.getPlanById('plan-3'))
          .thenAnswer((_) async => plan3);
      when(mockTaskRepository.getPlanTasks('plan-1'))
          .thenAnswer((_) async => tasks1);
      when(mockTaskRepository.getPlanTasks('plan-2'))
          .thenAnswer((_) async => tasks2);
      when(mockTaskRepository.getPlanTasks('plan-3'))
          .thenAnswer((_) async => tasks3);

      // Act
      final result = await service.getPlansSortedByCompletionRate(userId);

      // Assert
      expect(result.length, 3);
      expect(result[0].plan.id, 'plan-2'); // 75%
      expect(result[1].plan.id, 'plan-3'); // 50%
      expect(result[2].plan.id, 'plan-1'); // 25%
    });
  });

  group('PlanReviewService - getPlansNeedingAttention', () {
    test('should identify plans needing attention', () async {
      // Arrange
      const userId = 'user-123';
      final planNeedsAttention1 = createTestPlan(id: 'plan-1', name: 'Low Completion');
      final planNeedsAttention2 = createTestPlan(id: 'plan-2', name: 'High Skip Rate');
      final planOk = createTestPlan(id: 'plan-3', name: 'Healthy Plan');

      // Low completion rate (20%)
      final tasks1 = [
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.active),
        createTestTask(status: TaskStatus.active),
        createTestTask(status: TaskStatus.active),
        createTestTask(status: TaskStatus.active),
      ];

      // High skip rate (60%)
      final tasks2 = [
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.skipped),
        createTestTask(status: TaskStatus.skipped),
        createTestTask(status: TaskStatus.skipped),
      ];

      // Healthy plan (60% completion, 10% skip)
      final tasks3 = [
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.active),
        createTestTask(status: TaskStatus.skipped),
      ];

      when(mockPlanRepository.getUserPlans(userId))
          .thenAnswer((_) async => [planNeedsAttention1, planNeedsAttention2, planOk]);
      when(mockPlanRepository.getPlanById('plan-1'))
          .thenAnswer((_) async => planNeedsAttention1);
      when(mockPlanRepository.getPlanById('plan-2'))
          .thenAnswer((_) async => planNeedsAttention2);
      when(mockPlanRepository.getPlanById('plan-3'))
          .thenAnswer((_) async => planOk);
      when(mockTaskRepository.getPlanTasks('plan-1'))
          .thenAnswer((_) async => tasks1);
      when(mockTaskRepository.getPlanTasks('plan-2'))
          .thenAnswer((_) async => tasks2);
      when(mockTaskRepository.getPlanTasks('plan-3'))
          .thenAnswer((_) async => tasks3);

      // Act
      final result = await service.getPlansNeedingAttention(
        userId,
        completionRateThreshold: 0.3,
        skippedRateThreshold: 0.5,
      );

      // Assert
      expect(result.length, 2);
      expect(result.any((r) => r.plan.id == 'plan-1'), true); // Low completion
      expect(result.any((r) => r.plan.id == 'plan-2'), true); // High skip rate
      expect(result.any((r) => r.plan.id == 'plan-3'), false); // Healthy plan
    });

    test('should return empty list when all plans are healthy', () async {
      // Arrange
      const userId = 'user-123';
      final healthyPlan = createTestPlan(id: 'plan-1');
      final tasks = [
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.completed),
        createTestTask(status: TaskStatus.active),
      ]; // 75% completion, 0% skip

      when(mockPlanRepository.getUserPlans(userId))
          .thenAnswer((_) async => [healthyPlan]);
      when(mockPlanRepository.getPlanById('plan-1'))
          .thenAnswer((_) async => healthyPlan);
      when(mockTaskRepository.getPlanTasks('plan-1'))
          .thenAnswer((_) async => tasks);

      // Act
      final result = await service.getPlansNeedingAttention(
        userId,
        completionRateThreshold: 0.3,
        skippedRateThreshold: 0.5,
      );

      // Assert
      expect(result, isEmpty);
    });
  });
}
