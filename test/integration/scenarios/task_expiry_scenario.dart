import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:myassistant/data/services/task_refresh_service.dart';
import 'package:myassistant/data/services/task_generation_service.dart';
import 'package:myassistant/data/services/task_execution_service.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/core/errors/exceptions.dart';

import 'helpers/test_factories.dart';
import 'scenario_mocks.mocks.dart';

void main() {
  late TaskRefreshService refreshService;
  late TaskExecutionService executionService;
  late TaskGenerationService generationService;
  late MockITaskRepository mockTaskRepo;
  late MockIPlanRepository mockPlanRepo;

  setUp(() {
    mockTaskRepo = MockITaskRepository();
    mockPlanRepo = MockIPlanRepository();
    generationService = TaskGenerationService(
      taskRepository: mockTaskRepo,
      planRepository: mockPlanRepo,
    );
    refreshService = TaskRefreshService(
      taskRepository: mockTaskRepo,
      planRepository: mockPlanRepo,
      generationService: generationService,
    );
    executionService = TaskExecutionService(
      taskRepository: mockTaskRepo,
      planRepository: mockPlanRepo,
    );
  });

  tearDown(() {
    refreshService.dispose();
    executionService.dispose();
  });

  group('Scenario: expired tasks auto-skipped by refresh', () {
    test('refreshAllTasks marks expired active tasks as skipped', () async {
      final now = DateTime.now();
      final expiredTask = createTask(
        id: 'expired-1',
        config: const TaskConfiguration(durationMinutes: 30),
        status: TaskStatus.active,
        windowStartTime: now.subtract(const Duration(days: 2)),
        windowEndTime: now.subtract(const Duration(days: 1)),
      );

      when(mockTaskRepo.getOverdueTasks(testUserId))
          .thenAnswer((_) async => [expiredTask]);
      when(mockTaskRepo.skipTask(
        taskId: 'expired-1',
        reason: anyNamed('reason'),
      )).thenAnswer(
          (_) async => expiredTask.copyWith(status: TaskStatus.skipped));
      when(mockPlanRepo.getPlansNeedingTaskGeneration(testUserId))
          .thenAnswer((_) async => []);

      final result = await refreshService.refreshAllTasks(testUserId);

      expect(result.success, true);
      expect(result.expiredCount, 1);
      verify(mockTaskRepo.skipTask(
        taskId: 'expired-1',
        reason: anyNamed('reason'),
      )).called(1);
    });

    test('refreshAllTasks handles multiple expired tasks of different types',
        () async {
      final now = DateTime.now();
      final expiredTasks = [
        createTask(
          id: 'exp-simple',
          config: const TaskConfiguration(),
          status: TaskStatus.active,
          windowStartTime: now.subtract(const Duration(days: 2)),
          windowEndTime: now.subtract(const Duration(days: 1)),
        ),
        createTask(
          id: 'exp-timer',
          config: const TaskConfiguration(durationMinutes: 25),
          status: TaskStatus.active,
          windowStartTime: now.subtract(const Duration(days: 3)),
          windowEndTime: now.subtract(const Duration(days: 2)),
        ),
        createTask(
          id: 'exp-counter',
          config: const TaskConfiguration(repeatCount: 10),
          status: TaskStatus.active,
          windowStartTime: now.subtract(const Duration(days: 2)),
          windowEndTime: now.subtract(const Duration(hours: 1)),
          currentCount: 5,
        ),
      ];

      when(mockTaskRepo.getOverdueTasks(testUserId))
          .thenAnswer((_) async => expiredTasks);

      for (final task in expiredTasks) {
        when(mockTaskRepo.skipTask(
          taskId: task.id,
          reason: anyNamed('reason'),
        )).thenAnswer(
            (_) async => task.copyWith(status: TaskStatus.skipped));
      }

      when(mockPlanRepo.getPlansNeedingTaskGeneration(testUserId))
          .thenAnswer((_) async => []);

      final result = await refreshService.refreshAllTasks(testUserId);

      expect(result.success, true);
      expect(result.expiredCount, 3);
    });

    test('does not skip already completed tasks', () async {
      final now = DateTime.now();
      final completedTask = createTask(
        id: 'completed-old',
        status: TaskStatus.completed,
        windowStartTime: now.subtract(const Duration(days: 2)),
        windowEndTime: now.subtract(const Duration(days: 1)),
      );

      when(mockTaskRepo.getOverdueTasks(testUserId))
          .thenAnswer((_) async => [completedTask]);
      when(mockPlanRepo.getPlansNeedingTaskGeneration(testUserId))
          .thenAnswer((_) async => []);

      final result = await refreshService.refreshAllTasks(testUserId);

      expect(result.expiredCount, 0);
      verifyNever(mockTaskRepo.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      ));
    });

    test('expired task cannot be completed', () async {
      final now = DateTime.now();
      final expiredTask = createTask(
        config: const TaskConfiguration(),
        status: TaskStatus.active,
        windowStartTime: now.subtract(const Duration(days: 2)),
        windowEndTime: now.subtract(const Duration(days: 1)),
      );

      expect(
        () => executionService.completeTask(task: expiredTask),
        throwsA(isA<BusinessException>()),
      );
    });

    test('refreshOnResume handles expired tasks in current window', () async {
      final now = DateTime.now();
      final expiredTask = createTask(
        id: 'exp-resume',
        status: TaskStatus.active,
        windowStartTime: now.subtract(const Duration(days: 1)),
        windowEndTime: now.subtract(const Duration(hours: 1)),
      );

      when(mockTaskRepo.getTasksInCurrentWindow(testUserId))
          .thenAnswer((_) async => [expiredTask]);
      when(mockTaskRepo.skipTask(
        taskId: 'exp-resume',
        reason: anyNamed('reason'),
      )).thenAnswer(
          (_) async => expiredTask.copyWith(status: TaskStatus.skipped));
      when(mockPlanRepo.getActivePlans(testUserId))
          .thenAnswer((_) async => []);

      final result = await refreshService.refreshOnResume(testUserId);

      expect(result.success, true);
      expect(result.expiredCount, 1);
    });

    test('refresh generates new tasks after expiring old ones', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.daily),
        taskConfig: const TaskConfiguration(durationMinutes: 15),
      );

      // Yesterday's expired task
      final expiredTask = createTask(
        id: 'exp-yesterday',
        planId: plan.id,
        config: plan.taskConfig,
        status: TaskStatus.active,
        windowStartTime: startOfDay(now.subtract(const Duration(days: 1))),
        windowEndTime: endOfDay(now.subtract(const Duration(days: 1))),
      );

      when(mockTaskRepo.getOverdueTasks(testUserId))
          .thenAnswer((_) async => [expiredTask]);
      when(mockTaskRepo.skipTask(
        taskId: 'exp-yesterday',
        reason: anyNamed('reason'),
      )).thenAnswer(
          (_) async => expiredTask.copyWith(status: TaskStatus.skipped));

      // After expiring, generation service creates new task
      when(mockPlanRepo.getPlansNeedingTaskGeneration(testUserId))
          .thenAnswer((_) async => [plan]);
      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async =>
              [expiredTask.copyWith(status: TaskStatus.skipped)]);

      final newTask = createTask(
        id: 'new-today',
        planId: plan.id,
        config: plan.taskConfig,
      );
      when(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      )).thenAnswer((_) async => newTask);

      final result = await refreshService.refreshAllTasks(testUserId);

      expect(result.success, true);
      expect(result.expiredCount, 1);
      expect(result.generatedCount, 1);
    });
  });
}
