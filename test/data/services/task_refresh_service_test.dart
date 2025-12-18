import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:myassistant/data/services/task_refresh_service.dart';
import 'package:myassistant/data/services/task_generation_service.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';

import 'task_refresh_service_test.mocks.dart';

@GenerateMocks([ITaskRepository, IPlanRepository, TaskGenerationService])
void main() {
  late TaskRefreshService service;
  late MockITaskRepository mockTaskRepository;
  late MockIPlanRepository mockPlanRepository;
  late MockTaskGenerationService mockGenerationService;

  setUp(() {
    mockTaskRepository = MockITaskRepository();
    mockPlanRepository = MockIPlanRepository();
    mockGenerationService = MockTaskGenerationService();
    service = TaskRefreshService(
      taskRepository: mockTaskRepository,
      planRepository: mockPlanRepository,
      generationService: mockGenerationService,
    );
  });

  tearDown(() {
    service.dispose();
  });

  // Helper function to create a test task
  TaskModel createTestTask({
    String id = 'task-123',
    String userId = 'user-123',
    String planId = 'plan-123',
    String name = 'Test Task',
    TaskStatus status = TaskStatus.active,
    DateTime? windowStartTime,
    DateTime? windowEndTime,
  }) {
    final now = DateTime.now();
    return TaskModel(
      id: id,
      userId: userId,
      planId: planId,
      name: name,
      config: const TaskConfiguration(),
      status: status,
      windowStartTime: windowStartTime ?? now.subtract(const Duration(hours: 1)),
      windowEndTime: windowEndTime ?? now.add(const Duration(hours: 23)),
      createdAt: now,
    );
  }

  // Helper function to create a test plan
  PlanModel createTestPlan({
    String id = 'plan-123',
    String userId = 'user-123',
    String goalId = 'goal-123',
    String name = 'Test Plan',
    PlanStatus status = PlanStatus.active,
  }) {
    final now = DateTime.now();
    return PlanModel(
      id: id,
      userId: userId,
      name: name,
      goalId: goalId,
      startDate: now.subtract(const Duration(days: 7)),
      endDate: now.add(const Duration(days: 23)),
      repeatRule: const RepeatRule(type: RepeatType.weekly),
      taskConfig: const TaskConfiguration(durationMinutes: 30),
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('TaskRefreshService - refreshAllTasks', () {
    test('should successfully refresh all tasks', () async {
      // Arrange
      const userId = 'user-123';
      final expiredTasks = [
        createTestTask(
          id: 'task-1',
          windowStartTime: DateTime.now().subtract(const Duration(days: 2)),
          windowEndTime: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
      final newTasks = [
        createTestTask(id: 'task-new-1'),
        createTestTask(id: 'task-new-2'),
      ];

      when(mockTaskRepository.getOverdueTasks(userId))
          .thenAnswer((_) async => expiredTasks);
      when(mockTaskRepository.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => expiredTasks.first.copyWith(status: TaskStatus.skipped));
      when(mockGenerationService.generateAllPendingTasks(userId))
          .thenAnswer((_) async => newTasks);

      // Act
      final result = await service.refreshAllTasks(userId);

      // Assert
      expect(result.success, true);
      expect(result.expiredCount, 1);
      expect(result.generatedCount, 2);
      expect(result.newTasks.length, 2);
      expect(result.lastRefreshTime, isNotNull);
      expect(result.error, isNull);
    });

    test('should handle no expired tasks', () async {
      // Arrange
      const userId = 'user-123';
      when(mockTaskRepository.getOverdueTasks(userId))
          .thenAnswer((_) async => []);
      when(mockGenerationService.generateAllPendingTasks(userId))
          .thenAnswer((_) async => []);

      // Act
      final result = await service.refreshAllTasks(userId);

      // Assert
      expect(result.success, true);
      expect(result.expiredCount, 0);
      expect(result.generatedCount, 0);
    });

    test('should handle no new tasks', () async {
      // Arrange
      const userId = 'user-123';
      when(mockTaskRepository.getOverdueTasks(userId))
          .thenAnswer((_) async => []);
      when(mockGenerationService.generateAllPendingTasks(userId))
          .thenAnswer((_) async => []);

      // Act
      final result = await service.refreshAllTasks(userId);

      // Assert
      expect(result.success, true);
      expect(result.newTasks.isEmpty, true);
    });

    test('should handle errors gracefully', () async {
      // Arrange
      const userId = 'user-123';
      when(mockTaskRepository.getOverdueTasks(userId))
          .thenThrow(Exception('Database error'));

      // Act
      final result = await service.refreshAllTasks(userId);

      // Assert
      expect(result.success, false);
      expect(result.error, isNotNull);
      expect(result.error, contains('Database error'));
    });

    test('should skip only active expired tasks', () async {
      // Arrange
      const userId = 'user-123';
      final expiredTasks = [
        createTestTask(
          id: 'task-1',
          status: TaskStatus.active,
          windowStartTime: DateTime.now().subtract(const Duration(days: 2)),
          windowEndTime: DateTime.now().subtract(const Duration(days: 1)),
        ),
        createTestTask(
          id: 'task-2',
          status: TaskStatus.completed,
          windowStartTime: DateTime.now().subtract(const Duration(days: 2)),
          windowEndTime: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

      when(mockTaskRepository.getOverdueTasks(userId))
          .thenAnswer((_) async => expiredTasks);
      when(mockTaskRepository.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => expiredTasks.first.copyWith(status: TaskStatus.skipped));
      when(mockGenerationService.generateAllPendingTasks(userId))
          .thenAnswer((_) async => []);

      // Act
      final result = await service.refreshAllTasks(userId);

      // Assert
      expect(result.expiredCount, 1);
      verify(mockTaskRepository.skipTask(
        taskId: 'task-1',
        reason: anyNamed('reason'),
      )).called(1);
      verifyNever(mockTaskRepository.skipTask(
        taskId: 'task-2',
        reason: anyNamed('reason'),
      ));
    });
  });

  group('TaskRefreshService - refreshOnResume', () {
    test('should refresh on resume successfully', () async {
      // Arrange
      const userId = 'user-123';
      final expiredTask = createTestTask(
        id: 'task-expired',
        windowStartTime: DateTime.now().subtract(const Duration(days: 1)),
        windowEndTime: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final plans = [createTestPlan()];
      final newTask = createTestTask(id: 'task-new');

      when(mockTaskRepository.getTasksInCurrentWindow(userId))
          .thenAnswer((_) async => [expiredTask]);
      when(mockTaskRepository.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => expiredTask.copyWith(status: TaskStatus.skipped));
      when(mockPlanRepository.getActivePlans(userId))
          .thenAnswer((_) async => plans);
      when(mockTaskRepository.getActivePlanTask(any))
          .thenAnswer((_) async => null);
      when(mockGenerationService.generateNextTask(any))
          .thenAnswer((_) async => newTask);

      // Act
      final result = await service.refreshOnResume(userId);

      // Assert
      expect(result.success, true);
      expect(result.expiredCount, 1);
      expect(result.generatedCount, 1);
      expect(result.newTasks.length, 1);
    });

    test('should not generate task if plan already has active task', () async {
      // Arrange
      const userId = 'user-123';
      final plans = [createTestPlan()];
      final activeTask = createTestTask();

      when(mockTaskRepository.getTasksInCurrentWindow(userId))
          .thenAnswer((_) async => []);
      when(mockPlanRepository.getActivePlans(userId))
          .thenAnswer((_) async => plans);
      when(mockTaskRepository.getActivePlanTask(any))
          .thenAnswer((_) async => activeTask);

      // Act
      final result = await service.refreshOnResume(userId);

      // Assert
      expect(result.success, true);
      expect(result.generatedCount, 0);
      verifyNever(mockGenerationService.generateNextTask(any));
    });

    test('should generate new task if existing task is expired', () async {
      // Arrange
      const userId = 'user-123';
      final plans = [createTestPlan()];
      final expiredTask = createTestTask(
        windowStartTime: DateTime.now().subtract(const Duration(days: 1)),
        windowEndTime: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final newTask = createTestTask(id: 'task-new');

      when(mockTaskRepository.getTasksInCurrentWindow(userId))
          .thenAnswer((_) async => []);
      when(mockPlanRepository.getActivePlans(userId))
          .thenAnswer((_) async => plans);
      when(mockTaskRepository.getActivePlanTask(any))
          .thenAnswer((_) async => expiredTask);
      when(mockGenerationService.generateNextTask(any))
          .thenAnswer((_) async => newTask);

      // Act
      final result = await service.refreshOnResume(userId);

      // Assert
      expect(result.success, true);
      expect(result.generatedCount, 1);
      verify(mockGenerationService.generateNextTask(any)).called(1);
    });

    test('should handle errors during resume refresh', () async {
      // Arrange
      const userId = 'user-123';
      when(mockTaskRepository.getTasksInCurrentWindow(userId))
          .thenThrow(Exception('Network error'));

      // Act
      final result = await service.refreshOnResume(userId);

      // Assert
      expect(result.success, false);
      expect(result.error, contains('Network error'));
    });
  });

  group('TaskRefreshService - refreshPlanTasks', () {
    test('should refresh plan tasks successfully', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);
      final newTask = createTestTask();

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);
      when(mockTaskRepository.getActivePlanTask(planId))
          .thenAnswer((_) async => null);
      when(mockGenerationService.generateNextTask(any))
          .thenAnswer((_) async => newTask);

      // Act
      final result = await service.refreshPlanTasks(planId);

      // Assert
      expect(result, isNotNull);
      expect(result!.id, newTask.id);
    });

    test('should return null for non-existent plan', () async {
      // Arrange
      const planId = 'non-existent';
      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => null);

      // Act
      final result = await service.refreshPlanTasks(planId);

      // Assert
      expect(result, isNull);
    });

    test('should return null for inactive plan', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId, status: PlanStatus.paused);

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);

      // Act
      final result = await service.refreshPlanTasks(planId);

      // Assert
      expect(result, isNull);
    });

    test('should return existing active task', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);
      final activeTask = createTestTask();

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);
      when(mockTaskRepository.getActivePlanTask(planId))
          .thenAnswer((_) async => activeTask);

      // Act
      final result = await service.refreshPlanTasks(planId);

      // Assert
      expect(result, isNotNull);
      expect(result!.id, activeTask.id);
    });
  });

  group('TaskRefreshService - cleanupOldTasks', () {
    test('should count old completed tasks', () async {
      // Arrange
      const userId = 'user-123';
      final oldTasks = [
        createTestTask(id: 'task-1', status: TaskStatus.completed),
        createTestTask(id: 'task-2', status: TaskStatus.completed),
        createTestTask(id: 'task-3', status: TaskStatus.skipped),
        createTestTask(id: 'task-4', status: TaskStatus.active),
      ];

      when(mockTaskRepository.getTasksByDateRange(
        any,
        any,
        any,
      )).thenAnswer((_) async => oldTasks);

      // Act
      final count = await service.cleanupOldTasks(
        userId: userId,
        daysOld: 30,
      );

      // Assert
      expect(count, 3); // 2 completed + 1 skipped
    });

    test('should handle no old tasks', () async {
      // Arrange
      const userId = 'user-123';
      when(mockTaskRepository.getTasksByDateRange(
        any,
        any,
        any,
      )).thenAnswer((_) async => []);

      // Act
      final count = await service.cleanupOldTasks(userId: userId);

      // Assert
      expect(count, 0);
    });
  });

  group('TaskRefreshService - periodic refresh', () {
    test('should start periodic refresh', () async {
      // Arrange
      const userId = 'user-123';
      when(mockTaskRepository.getOverdueTasks(userId))
          .thenAnswer((_) async => []);
      when(mockGenerationService.generateAllPendingTasks(userId))
          .thenAnswer((_) async => []);

      // Act
      service.startPeriodicRefresh(
        userId: userId,
        interval: const Duration(milliseconds: 100),
      );

      // Wait a bit for the immediate refresh
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      verify(mockTaskRepository.getOverdueTasks(userId)).called(1);
    });

    test('should stop periodic refresh', () {
      // Arrange
      const userId = 'user-123';
      when(mockTaskRepository.getOverdueTasks(userId))
          .thenAnswer((_) async => []);
      when(mockGenerationService.generateAllPendingTasks(userId))
          .thenAnswer((_) async => []);

      service.startPeriodicRefresh(userId: userId);

      // Act
      service.stopPeriodicRefresh();

      // Assert - Timer should be stopped (no way to verify directly)
      // But we can call it again and it should work
      service.startPeriodicRefresh(userId: userId);
    });

    test('should call onRefresh callback', () async {
      // Arrange
      const userId = 'user-123';
      RefreshResult? callbackResult;
      when(mockTaskRepository.getOverdueTasks(userId))
          .thenAnswer((_) async => []);
      when(mockGenerationService.generateAllPendingTasks(userId))
          .thenAnswer((_) async => []);

      // Act
      service.startPeriodicRefresh(
        userId: userId,
        interval: const Duration(milliseconds: 100),
        onRefresh: (result) {
          callbackResult = result;
        },
      );

      // Wait for immediate refresh
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(callbackResult, isNotNull);
      expect(callbackResult!.success, true);
    });
  });

  group('TaskRefreshService - dispose', () {
    test('should dispose resources', () {
      // Arrange
      const userId = 'user-123';
      when(mockTaskRepository.getOverdueTasks(userId))
          .thenAnswer((_) async => []);
      when(mockGenerationService.generateAllPendingTasks(userId))
          .thenAnswer((_) async => []);

      service.startPeriodicRefresh(userId: userId);

      // Act
      service.dispose();

      // Assert - No direct way to verify, but should not throw
    });
  });
}
