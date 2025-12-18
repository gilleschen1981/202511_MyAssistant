import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:myassistant/data/services/task_execution_service.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/core/errors/exceptions.dart';

import 'task_execution_service_test.mocks.dart';

@GenerateMocks([ITaskRepository])
void main() {
  late TaskExecutionService service;
  late MockITaskRepository mockTaskRepository;

  setUp(() {
    mockTaskRepository = MockITaskRepository();
    service = TaskExecutionService(
      taskRepository: mockTaskRepository,
    );
  });

  tearDown(() {
    // Clean up timer sessions after each test
    service.dispose();
  });

  // Helper function to create a test task
  TaskModel createTestTask({
    String id = 'task-123',
    String userId = 'user-123',
    String planId = 'plan-123',
    String name = 'Test Task',
    TaskStatus status = TaskStatus.active,
    TaskConfiguration? config,
    int currentCount = 0,
    DateTime? windowStartTime,
    DateTime? windowEndTime,
  }) {
    final now = DateTime.now();
    return TaskModel(
      id: id,
      userId: userId,
      planId: planId,
      name: name,
      config: config ?? const TaskConfiguration(),
      status: status,
      currentCount: currentCount,
      windowStartTime: windowStartTime ?? now.subtract(const Duration(hours: 1)),
      windowEndTime: windowEndTime ?? now.add(const Duration(hours: 23)),
      createdAt: now,
    );
  }

  group('TaskExecutionService - startTimer', () {
    test('should successfully start timer for valid timer task', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );

      // Act
      final session = await service.startTimer(task: task);

      // Assert
      expect(session, isNotNull);
      expect(session.taskId, task.id);
      expect(session.targetDuration, const Duration(minutes: 25));
      expect(session.isRunning, true);
      expect(session.isPaused, false);
    });

    test('should return existing session if timer already started', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );

      // Act
      final session1 = await service.startTimer(task: task);
      final session2 = await service.startTimer(task: task);

      // Assert
      expect(identical(session1, session2), true);
    });

    test('should throw BusinessException for non-active task', () async {
      // Arrange
      final task = createTestTask(
        status: TaskStatus.completed,
        config: const TaskConfiguration(durationMinutes: 25),
      );

      // Act & Assert
      expect(
        () => service.startTimer(task: task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('should throw BusinessException for non-timer task', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(), // No durationMinutes
      );

      // Act & Assert
      expect(
        () => service.startTimer(task: task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('should call onTick callback during timer execution', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );
      Duration? lastTickValue;

      // Act
      await service.startTimer(
        task: task,
        onTick: (remaining) {
          lastTickValue = remaining;
        },
      );

      // Wait for at least one tick
      await Future.delayed(const Duration(seconds: 2));

      // Assert
      expect(lastTickValue, isNotNull);
    });
  });

  group('TaskExecutionService - completeTask', () {
    test('should successfully complete simple task', () async {
      // Arrange
      final task = createTestTask();
      final completedTask = task.copyWith(status: TaskStatus.completed);
      final todayTasks = [completedTask];

      when(mockTaskRepository.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);
      when(mockTaskRepository.getTodayTasks(any))
          .thenAnswer((_) async => todayTasks);

      // Act
      final result = await service.completeTask(task: task);

      // Assert
      expect(result.completedTask.status, TaskStatus.completed);
      expect(result.statistics.todayCompleted, 1);
      verify(mockTaskRepository.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).called(1);
    });

    test('should successfully complete timer task with duration', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );
      final completedTask = task.copyWith(status: TaskStatus.completed);

      when(mockTaskRepository.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);
      when(mockTaskRepository.getTodayTasks(any))
          .thenAnswer((_) async => [completedTask]);

      // Act
      final result = await service.completeTask(
        task: task,
        actualDurationMinutes: 25,
      );

      // Assert
      expect(result.completedTask.status, TaskStatus.completed);
    });

    test('should successfully complete evaluation task with result', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(
          evaluationOptions: ['Good', 'Bad'],
        ),
      );
      final completedTask = task.copyWith(status: TaskStatus.completed);

      when(mockTaskRepository.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);
      when(mockTaskRepository.getTodayTasks(any))
          .thenAnswer((_) async => [completedTask]);

      // Act
      final result = await service.completeTask(
        task: task,
        evaluationResult: 'Good',
      );

      // Assert
      expect(result.completedTask.status, TaskStatus.completed);
    });

    test('should throw BusinessException for already completed task', () async {
      // Arrange
      final task = createTestTask(status: TaskStatus.completed);

      // Act & Assert
      expect(
        () => service.completeTask(task: task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('should throw BusinessException for expired task', () async {
      // Arrange
      final task = createTestTask(
        windowStartTime: DateTime.now().subtract(const Duration(days: 2)),
        windowEndTime: DateTime.now().subtract(const Duration(days: 1)),
      );

      // Act & Assert
      expect(
        () => service.completeTask(task: task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('should throw ValidationException for evaluation task without result', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(
          evaluationOptions: ['Good', 'Bad'],
        ),
      );

      // Act & Assert
      expect(
        () => service.completeTask(task: task),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for invalid evaluation result', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(
          evaluationOptions: ['Good', 'Bad'],
        ),
      );

      // Act & Assert
      expect(
        () => service.completeTask(
          task: task,
          evaluationResult: 'Invalid',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should stop timer when completing timer task', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );
      final completedTask = task.copyWith(status: TaskStatus.completed);

      await service.startTimer(task: task);

      when(mockTaskRepository.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);
      when(mockTaskRepository.getTodayTasks(any))
          .thenAnswer((_) async => [completedTask]);

      // Act
      await service.completeTask(task: task);

      // Assert
      expect(service.getTimerSession(task.id), isNull);
    });

    test('should calculate statistics correctly', () async {
      // Arrange
      final task = createTestTask();
      final completedTask = task.copyWith(status: TaskStatus.completed);
      final todayTasks = [
        completedTask,
        createTestTask(id: 'task-2', status: TaskStatus.active),
        createTestTask(id: 'task-3', status: TaskStatus.skipped),
      ];

      when(mockTaskRepository.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);
      when(mockTaskRepository.getTodayTasks(any))
          .thenAnswer((_) async => todayTasks);

      // Act
      final result = await service.completeTask(task: task);

      // Assert
      expect(result.statistics.todayCompleted, 1);
      expect(result.statistics.todayRemaining, 1);
      expect(result.statistics.todaySkipped, 1);
      expect(result.statistics.completionRate, closeTo(1.0 / 3.0, 0.01));
    });
  });

  group('TaskExecutionService - skipTask', () {
    test('should successfully skip active task', () async {
      // Arrange
      final task = createTestTask();
      final skippedTask = task.copyWith(status: TaskStatus.skipped);

      when(mockTaskRepository.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => skippedTask);

      // Act
      final result = await service.skipTask(task: task);

      // Assert
      expect(result.status, TaskStatus.skipped);
      verify(mockTaskRepository.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).called(1);
    });

    test('should skip task with reason', () async {
      // Arrange
      final task = createTestTask();
      final skippedTask = task.copyWith(status: TaskStatus.skipped);

      when(mockTaskRepository.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => skippedTask);

      // Act
      final result = await service.skipTask(
        task: task,
        skipReason: 'Too busy today',
      );

      // Assert
      expect(result.status, TaskStatus.skipped);
    });

    test('should throw BusinessException for non-active task', () async {
      // Arrange
      final task = createTestTask(status: TaskStatus.completed);

      // Act & Assert
      expect(
        () => service.skipTask(task: task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('should stop timer when skipping timer task', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );
      final skippedTask = task.copyWith(status: TaskStatus.skipped);

      await service.startTimer(task: task);

      when(mockTaskRepository.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => skippedTask);

      // Act
      await service.skipTask(task: task);

      // Assert
      expect(service.getTimerSession(task.id), isNull);
    });
  });

  group('TaskExecutionService - incrementCount', () {
    test('should successfully increment counter', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(repeatCount: 10),
        currentCount: 5,
      );
      final updatedTask = task.copyWith(currentCount: 6);

      when(mockTaskRepository.updateTaskProgress(
        any,
        any,
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
      )).thenAnswer((_) async => updatedTask);

      // Act
      final result = await service.incrementCount(task);

      // Assert
      expect(result.currentCount, 6);
      verify(mockTaskRepository.updateTaskProgress(
        task.id,
        6,
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
      )).called(1);
    });

    test('should auto-complete when reaching target count', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(repeatCount: 10),
        currentCount: 9,
      );
      final completedTask = task.copyWith(
        currentCount: 10,
        status: TaskStatus.completed,
      );

      when(mockTaskRepository.updateTaskProgress(
        any,
        any,
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
      )).thenAnswer((_) async => completedTask);

      // Act
      final result = await service.incrementCount(task);

      // Assert
      expect(result.status, TaskStatus.completed);
      expect(result.currentCount, 10);
    });

    test('should throw BusinessException for non-counter task', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(), // No repeatCount
      );

      // Act & Assert
      expect(
        () => service.incrementCount(task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('should throw BusinessException for non-active task', () async {
      // Arrange
      final task = createTestTask(
        status: TaskStatus.completed,
        config: const TaskConfiguration(repeatCount: 10),
      );

      // Act & Assert
      expect(
        () => service.incrementCount(task),
        throwsA(isA<BusinessException>()),
      );
    });
  });

  group('TaskExecutionService - decrementCount', () {
    test('should successfully decrement counter', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(repeatCount: 10),
        currentCount: 5,
      );
      final updatedTask = task.copyWith(currentCount: 4);

      when(mockTaskRepository.updateTaskProgress(any, any))
          .thenAnswer((_) async => updatedTask);

      // Act
      final result = await service.decrementCount(task);

      // Assert
      expect(result.currentCount, 4);
      verify(mockTaskRepository.updateTaskProgress(task.id, 4)).called(1);
    });

    test('should not decrement below zero', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(repeatCount: 10),
        currentCount: 0,
      );
      final updatedTask = task.copyWith(currentCount: 0);

      when(mockTaskRepository.updateTaskProgress(any, any))
          .thenAnswer((_) async => updatedTask);

      // Act
      final result = await service.decrementCount(task);

      // Assert
      expect(result.currentCount, 0);
    });

    test('should throw BusinessException for non-counter task', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(),
      );

      // Act & Assert
      expect(
        () => service.decrementCount(task),
        throwsA(isA<BusinessException>()),
      );
    });
  });

  group('TaskExecutionService - reExecuteTask', () {
    test('should create new task for re-execution', () async {
      // Arrange
      final task = createTestTask(status: TaskStatus.completed);
      final newTask = createTestTask(id: 'task-new');

      when(mockTaskRepository.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      )).thenAnswer((_) async => newTask);

      // Act
      final result = await service.reExecuteTask(task);

      // Assert
      expect(result, isNotNull);
      expect(result!.id, 'task-new');
      verify(mockTaskRepository.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      )).called(1);
    });

    test('should reset repeatCount for counter tasks', () async {
      // Arrange
      final task = createTestTask(
        status: TaskStatus.completed,
        config: const TaskConfiguration(
          repeatCount: 10,
          durationMinutes: 25,
        ),
      );
      final newTask = createTestTask(id: 'task-new');

      when(mockTaskRepository.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      )).thenAnswer((_) async => newTask);

      // Act
      await service.reExecuteTask(task);

      // Assert
      final captured = verify(mockTaskRepository.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: captureAnyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      )).captured;

      final capturedConfig = captured.first as TaskConfiguration;
      expect(capturedConfig.repeatCount, isNull);
      expect(capturedConfig.durationMinutes, 25);
    });

    test('should return null for non-completed task', () async {
      // Arrange
      final task = createTestTask(status: TaskStatus.active);

      // Act
      final result = await service.reExecuteTask(task);

      // Assert
      expect(result, isNull);
      verifyNever(mockTaskRepository.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      ));
    });
  });

  group('TaskExecutionService - timer session management', () {
    test('should get active timer session', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );

      // Act
      await service.startTimer(task: task);
      final session = service.getTimerSession(task.id);

      // Assert
      expect(session, isNotNull);
      expect(session!.taskId, task.id);
    });

    test('should stop timer session', () async {
      // Arrange
      final task = createTestTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );

      // Act
      await service.startTimer(task: task);
      service.stopTimer(task.id);

      // Assert
      expect(service.getTimerSession(task.id), isNull);
    });

    test('should get all active sessions', () async {
      // Arrange
      final task1 = createTestTask(
        id: 'task-1',
        config: const TaskConfiguration(durationMinutes: 25),
      );
      final task2 = createTestTask(
        id: 'task-2',
        config: const TaskConfiguration(durationMinutes: 30),
      );

      // Act
      await service.startTimer(task: task1);
      await service.startTimer(task: task2);
      final sessions = service.getActiveSessions();

      // Assert
      expect(sessions.length, 2);
      expect(sessions.containsKey('task-1'), true);
      expect(sessions.containsKey('task-2'), true);
    });

    test('should pause all timers', () async {
      // Arrange
      final task1 = createTestTask(
        id: 'task-1',
        config: const TaskConfiguration(durationMinutes: 25),
      );
      final task2 = createTestTask(
        id: 'task-2',
        config: const TaskConfiguration(durationMinutes: 30),
      );

      await service.startTimer(task: task1);
      await service.startTimer(task: task2);

      // Act
      service.pauseAllTimers();

      // Assert
      final sessions = service.getActiveSessions();
      expect(sessions.values.every((s) => s.isPaused), true);
    });

    test('should resume all timers', () async {
      // Arrange
      final task1 = createTestTask(
        id: 'task-1',
        config: const TaskConfiguration(durationMinutes: 25),
      );
      final task2 = createTestTask(
        id: 'task-2',
        config: const TaskConfiguration(durationMinutes: 30),
      );

      await service.startTimer(task: task1);
      await service.startTimer(task: task2);
      service.pauseAllTimers();

      // Act
      service.resumeAllTimers();

      // Assert
      final sessions = service.getActiveSessions();
      expect(sessions.values.every((s) => !s.isPaused), true);
    });

    test('should dispose all sessions', () async {
      // Arrange
      final task1 = createTestTask(
        id: 'task-1',
        config: const TaskConfiguration(durationMinutes: 25),
      );
      final task2 = createTestTask(
        id: 'task-2',
        config: const TaskConfiguration(durationMinutes: 30),
      );

      await service.startTimer(task: task1);
      await service.startTimer(task: task2);

      // Act
      service.dispose();

      // Assert
      expect(service.getActiveSessions().length, 0);
    });
  });

  group('TimerSession', () {
    test('should calculate elapsed duration correctly', () {
      // Arrange
      final now = DateTime.now();
      final session = TimerSession(
        taskId: 'task-1',
        startTime: now.subtract(const Duration(seconds: 30)),
        targetDuration: const Duration(minutes: 1),
      );

      // Act
      final elapsed = session.elapsedDuration;

      // Assert
      expect(elapsed.inSeconds, greaterThanOrEqualTo(29));
      expect(elapsed.inSeconds, lessThanOrEqualTo(31));
    });

    test('should calculate remaining duration correctly', () {
      // Arrange
      final now = DateTime.now();
      final session = TimerSession(
        taskId: 'task-1',
        startTime: now.subtract(const Duration(seconds: 30)),
        targetDuration: const Duration(minutes: 1),
      );

      // Act
      final remaining = session.remainingDuration;

      // Assert
      expect(remaining.inSeconds, greaterThanOrEqualTo(29));
      expect(remaining.inSeconds, lessThanOrEqualTo(31));
    });

    test('should return zero for negative remaining duration', () {
      // Arrange
      final now = DateTime.now();
      final session = TimerSession(
        taskId: 'task-1',
        startTime: now.subtract(const Duration(minutes: 2)),
        targetDuration: const Duration(minutes: 1),
      );

      // Act
      final remaining = session.remainingDuration;

      // Assert
      expect(remaining, Duration.zero);
    });

    test('should detect completion correctly', () {
      // Arrange
      final now = DateTime.now();
      final session = TimerSession(
        taskId: 'task-1',
        startTime: now.subtract(const Duration(minutes: 2)),
        targetDuration: const Duration(minutes: 1),
      );

      // Act & Assert
      expect(session.isCompleted, true);
    });

    test('should pause and resume correctly', () {
      // Arrange
      final session = TimerSession(
        taskId: 'task-1',
        startTime: DateTime.now(),
        targetDuration: const Duration(minutes: 1),
      );
      session.start();

      // Act
      session.pause();

      // Assert
      expect(session.isPaused, true);
      expect(session.isRunning, false);

      // Resume
      session.resume();
      expect(session.isPaused, false);
    });
  });
}
