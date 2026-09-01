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

  group('Scenario: timer task execution flow', () {
    test('start timer → session created with correct duration', () async {
      final task = createTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );

      final session = await executionService.startTimer(task: task);

      expect(session.taskId, task.id);
      expect(session.targetDuration, const Duration(minutes: 25));
      expect(session.isRunning, true);
      expect(session.isPaused, false);
    });

    test('start timer → pause → resume → verify state', () async {
      final task = createTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );

      final session = await executionService.startTimer(task: task);
      expect(session.isRunning, true);

      session.pause();
      expect(session.isPaused, true);
      expect(session.isRunning, false);

      session.resume();
      expect(session.isPaused, false);
    });

    test('complete timer task stops timer session', () async {
      final task = createTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );
      final completedTask = task.copyWith(status: TaskStatus.completed);

      await executionService.startTimer(task: task);
      expect(executionService.getTimerSession(task.id), isNotNull);

      when(mockTaskRepo.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);
      when(mockTaskRepo.getTodayTasks(any))
          .thenAnswer((_) async => [completedTask]);

      await executionService.completeTask(
        task: task,
        actualDurationMinutes: 25,
      );

      expect(executionService.getTimerSession(task.id), isNull);
    });

    test('skip timer task stops timer session', () async {
      final task = createTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );
      final skippedTask = task.copyWith(status: TaskStatus.skipped);

      await executionService.startTimer(task: task);

      when(mockTaskRepo.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => skippedTask);

      await executionService.skipTask(task: task);

      expect(executionService.getTimerSession(task.id), isNull);
    });

    test('starting timer twice returns same session', () async {
      final task = createTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );

      final session1 = await executionService.startTimer(task: task);
      final session2 = await executionService.startTimer(task: task);

      expect(identical(session1, session2), true);
    });

    test('cannot start timer for non-active task', () async {
      final task = createTask(
        config: const TaskConfiguration(durationMinutes: 25),
        status: TaskStatus.completed,
      );

      expect(
        () => executionService.startTimer(task: task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('cannot start timer for non-timer task', () async {
      final task = createTask(
        config: const TaskConfiguration(), // simple
      );

      expect(
        () => executionService.startTimer(task: task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('multiple timer sessions tracked independently', () async {
      final task1 = createTask(
        id: 'timer-1',
        config: const TaskConfiguration(durationMinutes: 25),
      );
      final task2 = createTask(
        id: 'timer-2',
        config: const TaskConfiguration(durationMinutes: 45),
      );

      await executionService.startTimer(task: task1);
      await executionService.startTimer(task: task2);

      final sessions = executionService.getActiveSessions();
      expect(sessions.length, 2);
      expect(sessions['timer-1']!.targetDuration, const Duration(minutes: 25));
      expect(sessions['timer-2']!.targetDuration, const Duration(minutes: 45));
    });

    test('pauseAll and resumeAll affect all sessions', () async {
      final task1 = createTask(
        id: 'timer-1',
        config: const TaskConfiguration(durationMinutes: 25),
      );
      final task2 = createTask(
        id: 'timer-2',
        config: const TaskConfiguration(durationMinutes: 45),
      );

      await executionService.startTimer(task: task1);
      await executionService.startTimer(task: task2);

      executionService.pauseAllTimers();
      final sessions = executionService.getActiveSessions();
      expect(sessions.values.every((s) => s.isPaused), true);

      executionService.resumeAllTimers();
      final resumedSessions = executionService.getActiveSessions();
      expect(resumedSessions.values.every((s) => !s.isPaused), true);
    });

    test('timer with various durations (1min, 60min, 240min)', () async {
      for (final minutes in [1, 60, 240]) {
        final task = createTask(
          id: 'timer-$minutes',
          config: TaskConfiguration(durationMinutes: minutes),
        );

        final session = await executionService.startTimer(task: task);
        expect(session.targetDuration, Duration(minutes: minutes));
      }
    });
  });
}
