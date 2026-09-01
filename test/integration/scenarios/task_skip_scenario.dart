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

  group('Scenario: skip task with various configs', () {
    test('skip simple task without reason', () async {
      final task = createTask(config: const TaskConfiguration());
      final skippedTask = task.copyWith(status: TaskStatus.skipped);

      when(mockTaskRepo.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => skippedTask);

      final result = await executionService.skipTask(task: task);
      expect(result.status, TaskStatus.skipped);
    });

    test('skip simple task with reason', () async {
      final task = createTask(config: const TaskConfiguration());
      final skippedTask = task.copyWith(status: TaskStatus.skipped);

      when(mockTaskRepo.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => skippedTask);

      final result = await executionService.skipTask(
        task: task,
        skipReason: 'Too busy today',
      );
      expect(result.status, TaskStatus.skipped);
      verify(mockTaskRepo.skipTask(
        taskId: task.id,
        reason: 'Too busy today',
      )).called(1);
    });

    test('skip timer task stops active timer', () async {
      final task = createTask(
        config: const TaskConfiguration(durationMinutes: 25),
      );
      final skippedTask = task.copyWith(status: TaskStatus.skipped);

      await executionService.startTimer(task: task);
      expect(executionService.getTimerSession(task.id), isNotNull);

      when(mockTaskRepo.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => skippedTask);

      await executionService.skipTask(
        task: task,
        skipReason: 'No time',
      );

      expect(executionService.getTimerSession(task.id), isNull);
    });

    test('skip counter task (mid-progress)', () async {
      final task = createTask(
        config: const TaskConfiguration(repeatCount: 10),
        currentCount: 5,
      );
      final skippedTask = task.copyWith(status: TaskStatus.skipped);

      when(mockTaskRepo.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => skippedTask);

      final result = await executionService.skipTask(task: task);
      expect(result.status, TaskStatus.skipped);
    });

    test('skip evaluation task', () async {
      final task = createTask(
        config: const TaskConfiguration(
          evaluationOptions: ['A', 'B', 'C'],
        ),
      );
      final skippedTask = task.copyWith(status: TaskStatus.skipped);

      when(mockTaskRepo.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => skippedTask);

      final result = await executionService.skipTask(task: task);
      expect(result.status, TaskStatus.skipped);
    });

    test('skip timerWithCount task stops timer', () async {
      final task = createTask(
        config: const TaskConfiguration(durationMinutes: 25, repeatCount: 5),
        currentCount: 3,
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

    test('skip counterWithEval task', () async {
      final task = createTask(
        config: const TaskConfiguration(
          repeatCount: 5,
          evaluationOptions: ['Good', 'Bad'],
        ),
        currentCount: 2,
      );
      final skippedTask = task.copyWith(status: TaskStatus.skipped);

      when(mockTaskRepo.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => skippedTask);

      final result = await executionService.skipTask(task: task);
      expect(result.status, TaskStatus.skipped);
    });

    test('cannot skip already completed task', () async {
      final task = createTask(status: TaskStatus.completed);

      expect(
        () => executionService.skipTask(task: task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('cannot skip already skipped task', () async {
      final task = createTask(status: TaskStatus.skipped);

      expect(
        () => executionService.skipTask(task: task),
        throwsA(isA<BusinessException>()),
      );
    });
  });
}
