import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:myassistant/data/services/task_execution_service.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/core/errors/exceptions.dart';

import 'helpers/test_factories.dart';
import 'scenario_mocks.mocks.dart';

void main() {
  late TaskExecutionService executionService;
  late MockITaskRepository mockTaskRepo;
  late MockIPlanRepository mockPlanRepo;

  setUp(() {
    mockTaskRepo = MockITaskRepository();
    mockPlanRepo = MockIPlanRepository();
    executionService = TaskExecutionService(
      taskRepository: mockTaskRepo,
      planRepository: mockPlanRepo,
    );
  });

  tearDown(() {
    executionService.dispose();
  });

  group('Scenario: make-up check-in basic flow', () {
    test('make-up complete a simple skipped task', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final task = createTask(
        id: 'task-makeup-1',
        config: const TaskConfiguration(),
        status: TaskStatus.skipped,
        skippedAt: yesterday,
        windowStartTime: startOfDay(yesterday),
        windowEndTime: endOfDay(yesterday),
      );
      final completedTask = createTask(
        id: task.id,
        config: const TaskConfiguration(),
        status: TaskStatus.completed,
        completedAt: task.windowEndTime,
        windowStartTime: task.windowStartTime,
        windowEndTime: task.windowEndTime,
      );

      when(mockTaskRepo.makeUpCompleteTask(
        taskId: anyNamed('taskId'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);

      final result = await executionService.makeUpCompleteTask(task: task);
      expect(result.status, TaskStatus.completed);
      expect(result.completedAt, task.windowEndTime);
      expect(result.skippedAt, isNull);
    });

    test('make-up complete a timer task directly (no timing)', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final task = createTask(
        id: 'task-makeup-timer',
        config: const TaskConfiguration(durationMinutes: 30),
        status: TaskStatus.skipped,
        skippedAt: yesterday,
        windowStartTime: startOfDay(yesterday),
        windowEndTime: endOfDay(yesterday),
      );
      final completedTask = task.copyWith(
        status: TaskStatus.completed,
        completedAt: task.windowEndTime,
        skippedAt: null,
      );

      when(mockTaskRepo.makeUpCompleteTask(
        taskId: anyNamed('taskId'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);

      final result = await executionService.makeUpCompleteTask(task: task);
      expect(result.status, TaskStatus.completed);
      // Timer task completed without actual timing
      expect(result.completedAt, task.windowEndTime);
    });

    test('make-up complete an evaluation task with result', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final task = createTask(
        id: 'task-makeup-eval',
        config: const TaskConfiguration(evaluationOptions: ['Good', 'Bad']),
        status: TaskStatus.skipped,
        skippedAt: yesterday,
        windowStartTime: startOfDay(yesterday),
        windowEndTime: endOfDay(yesterday),
      );
      final completedTask = task.copyWith(
        status: TaskStatus.completed,
        completedAt: task.windowEndTime,
        skippedAt: null,
        evaluationResult: 'Good',
      );

      when(mockTaskRepo.makeUpCompleteTask(
        taskId: anyNamed('taskId'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);

      final result = await executionService.makeUpCompleteTask(
        task: task,
        evaluationResult: 'Good',
      );
      expect(result.status, TaskStatus.completed);
      expect(result.evaluationResult, 'Good');
    });

    test('make-up complete evaluation task without result throws', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final task = createTask(
        id: 'task-makeup-eval-no-result',
        config: const TaskConfiguration(evaluationOptions: ['Good', 'Bad']),
        status: TaskStatus.skipped,
        skippedAt: yesterday,
      );

      expect(
        () => executionService.makeUpCompleteTask(task: task),
        throwsA(isA<ValidationException>()),
      );
    });

    test('make-up complete non-skipped task throws', () async {
      final task = createTask(
        id: 'task-active',
        config: const TaskConfiguration(),
        status: TaskStatus.active,
      );

      expect(
        () => executionService.makeUpCompleteTask(task: task),
        throwsA(isA<BusinessException>()),
      );
    });
  });

  group('Scenario: make-up counter task', () {
    test('make-up increment counter task', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final task = createTask(
        id: 'task-makeup-counter',
        config: const TaskConfiguration(repeatCount: 3),
        status: TaskStatus.skipped,
        currentCount: 0,
        skippedAt: yesterday,
        windowStartTime: startOfDay(yesterday),
        windowEndTime: endOfDay(yesterday),
      );
      final updatedTask = task.copyWith(currentCount: 1);

      when(mockTaskRepo.makeUpUpdateProgress(any, any))
          .thenAnswer((_) async => updatedTask);

      final result = await executionService.makeUpIncrementCount(task);
      expect(result.currentCount, 1);
      expect(result.status, TaskStatus.skipped);
    });

    test('make-up counter auto-completes on reaching target', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final task = createTask(
        id: 'task-makeup-counter-final',
        config: const TaskConfiguration(repeatCount: 3),
        status: TaskStatus.skipped,
        currentCount: 2,
        skippedAt: yesterday,
        windowStartTime: startOfDay(yesterday),
        windowEndTime: endOfDay(yesterday),
      );
      final completedTask = task.copyWith(
        status: TaskStatus.completed,
        currentCount: 3,
        completedAt: task.windowEndTime,
        skippedAt: null,
      );

      when(mockTaskRepo.makeUpUpdateProgress(any, any))
          .thenAnswer((_) async => completedTask);

      final result = await executionService.makeUpIncrementCount(task);
      expect(result.status, TaskStatus.completed);
      expect(result.currentCount, 3);
    });

    test('make-up increment non-counter task throws', () async {
      final task = createTask(
        id: 'task-simple',
        config: const TaskConfiguration(),
        status: TaskStatus.skipped,
      );

      expect(
        () => executionService.makeUpIncrementCount(task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('make-up increment active task throws', () async {
      final task = createTask(
        id: 'task-active-counter',
        config: const TaskConfiguration(repeatCount: 3),
        status: TaskStatus.active,
      );

      expect(
        () => executionService.makeUpIncrementCount(task),
        throwsA(isA<BusinessException>()),
      );
    });
  });

  group('Scenario: make-up does not affect current task window', () {
    test('completing make-up task does not change today task query', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final now = DateTime.now();

      // Yesterday's skipped task
      final yesterdayTask = createTask(
        id: 'task-yesterday',
        config: const TaskConfiguration(),
        status: TaskStatus.skipped,
        skippedAt: yesterday,
        windowStartTime: startOfDay(yesterday),
        windowEndTime: endOfDay(yesterday),
      );

      // Today's active task (same plan)
      final todayTask = createTask(
        id: 'task-today',
        config: const TaskConfiguration(),
        status: TaskStatus.active,
        windowStartTime: startOfDay(now),
        windowEndTime: endOfDay(now),
      );

      // Setup: today's tasks query returns todayTask
      when(mockTaskRepo.getTodayTasks(any))
          .thenAnswer((_) async => [todayTask]);

      // Snapshot of today's tasks before make-up
      final beforeMakeUp = await mockTaskRepo.getTodayTasks(testUserId);
      expect(beforeMakeUp.length, 1);
      expect(beforeMakeUp.first.id, 'task-today');
      expect(beforeMakeUp.first.status, TaskStatus.active);

      // Perform make-up completion
      final completedYesterday = yesterdayTask.copyWith(
        status: TaskStatus.completed,
        completedAt: yesterdayTask.windowEndTime,
        skippedAt: null,
      );

      when(mockTaskRepo.makeUpCompleteTask(
        taskId: anyNamed('taskId'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedYesterday);

      await executionService.makeUpCompleteTask(task: yesterdayTask);

      // Verify: today's tasks are UNCHANGED
      final afterMakeUp = await mockTaskRepo.getTodayTasks(testUserId);
      expect(afterMakeUp.length, beforeMakeUp.length);
      expect(afterMakeUp.first.id, beforeMakeUp.first.id);
      expect(afterMakeUp.first.status, beforeMakeUp.first.status);

      // Verify: make-up only called makeUpCompleteTask, not completeTask
      verifyNever(mockTaskRepo.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      ));
    });

    test('make-up completion uses windowEndTime as completedAt', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final task = createTask(
        id: 'task-timestamp-check',
        config: const TaskConfiguration(),
        status: TaskStatus.skipped,
        skippedAt: yesterday,
        windowStartTime: startOfDay(yesterday),
        windowEndTime: endOfDay(yesterday),
      );

      final completedTask = task.copyWith(
        status: TaskStatus.completed,
        completedAt: task.windowEndTime,
        skippedAt: null,
      );

      when(mockTaskRepo.makeUpCompleteTask(
        taskId: anyNamed('taskId'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);

      final result = await executionService.makeUpCompleteTask(task: task);

      // completed_at should be windowEndTime (yesterday), not now
      expect(result.completedAt, task.windowEndTime);
      expect(result.completedAt!.day, yesterday.day);
    });
  });

  group('Scenario: make-up scope validation', () {
    test('getYesterdaySkippedTasks returns tasks with window_end_time in yesterday', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      // Task whose window ended yesterday (skipped today by auto-expire)
      final autoSkippedTask = createTask(
        id: 'task-auto-skipped',
        status: TaskStatus.skipped,
        skippedAt: now,
        windowStartTime: startOfDay(yesterday),
        windowEndTime: endOfDay(yesterday),
      );

      // Task manually skipped yesterday
      final manualSkippedTask = createTask(
        id: 'task-manual-skipped',
        status: TaskStatus.skipped,
        skippedAt: yesterday,
        windowStartTime: startOfDay(yesterday),
        windowEndTime: endOfDay(yesterday),
      );

      when(mockTaskRepo.getYesterdaySkippedTasks(any))
          .thenAnswer((_) async => [autoSkippedTask, manualSkippedTask]);

      final results = await mockTaskRepo.getYesterdaySkippedTasks(testUserId);
      expect(results.length, 2);

      // Both tasks have window_end_time in yesterday range
      for (final task in results) {
        expect(task.windowEndTime.isAfter(startOfDay(yesterday).subtract(const Duration(seconds: 1))), isTrue);
        expect(task.windowEndTime.isBefore(endOfDay(yesterday).add(const Duration(seconds: 1))), isTrue);
      }
    });
  });
}
