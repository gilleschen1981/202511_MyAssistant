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

  group('Scenario: counter task increment to completion', () {
    test('increment from 0 to target auto-completes', () async {
      const config = TaskConfiguration(repeatCount: 3);

      // Simulate increments: 0→1, 1→2, 2→3 (auto-complete)
      var task = createTask(
        id: 'counter-task',
        config: config,
        currentCount: 0,
      );

      // Increment 1
      when(mockTaskRepo.updateTaskProgress(
        'counter-task',
        1,
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
      )).thenAnswer((_) async => task.copyWith(currentCount: 1));

      var result = await executionService.incrementCount(task);
      expect(result.currentCount, 1);
      expect(result.status, TaskStatus.active);

      // Increment 2
      task = result;
      when(mockTaskRepo.updateTaskProgress(
        'counter-task',
        2,
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
      )).thenAnswer((_) async => task.copyWith(currentCount: 2));

      result = await executionService.incrementCount(task);
      expect(result.currentCount, 2);

      // Increment 3 → auto-complete
      task = result;
      when(mockTaskRepo.updateTaskProgress(
        'counter-task',
        3,
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
      )).thenAnswer(
          (_) async => task.copyWith(currentCount: 3, status: TaskStatus.completed));

      result = await executionService.incrementCount(task);
      expect(result.currentCount, 3);
      expect(result.status, TaskStatus.completed);
    });

    test('decrement does not go below 0', () async {
      final task = createTask(
        config: const TaskConfiguration(repeatCount: 10),
        currentCount: 0,
      );

      when(mockTaskRepo.updateTaskProgress(task.id, 0))
          .thenAnswer((_) async => task.copyWith(currentCount: 0));

      final result = await executionService.decrementCount(task);
      expect(result.currentCount, 0);
    });

    test('increment then decrement maintains correct count', () async {
      final task = createTask(
        id: 'counter-task',
        config: const TaskConfiguration(repeatCount: 10),
        currentCount: 5,
      );

      // Increment: 5→6
      when(mockTaskRepo.updateTaskProgress(
        'counter-task',
        6,
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
      )).thenAnswer((_) async => task.copyWith(currentCount: 6));

      final incremented = await executionService.incrementCount(task);
      expect(incremented.currentCount, 6);

      // Decrement: 6→5
      when(mockTaskRepo.updateTaskProgress('counter-task', 5))
          .thenAnswer((_) async => task.copyWith(currentCount: 5));

      final decremented = await executionService.decrementCount(incremented);
      expect(decremented.currentCount, 5);
    });

    test('cannot increment non-counter task', () async {
      final task = createTask(config: const TaskConfiguration());

      expect(
        () => executionService.incrementCount(task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('cannot decrement non-counter task', () async {
      final task = createTask(config: const TaskConfiguration());

      expect(
        () => executionService.decrementCount(task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('cannot increment completed task', () async {
      final task = createTask(
        config: const TaskConfiguration(repeatCount: 10),
        status: TaskStatus.completed,
      );

      expect(
        () => executionService.incrementCount(task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('re-execute counter task resets repeatCount to null', () async {
      final task = createTask(
        status: TaskStatus.completed,
        config: const TaskConfiguration(repeatCount: 10),
        currentCount: 10,
      );
      final newTask = createTask(id: 'task-new');

      when(mockPlanRepo.getPlanById(any)).thenAnswer((_) async => null);
      when(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      )).thenAnswer((_) async => newTask);

      await executionService.reExecuteTask(task);

      final captured = verify(mockTaskRepo.createTask(
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
    });

    test('counter with repeatCount=1 completes on first increment', () async {
      final task = createTask(
        id: 'one-count',
        config: const TaskConfiguration(repeatCount: 1),
        currentCount: 0,
      );

      when(mockTaskRepo.updateTaskProgress(
        'one-count',
        1,
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
      )).thenAnswer(
          (_) async => task.copyWith(currentCount: 1, status: TaskStatus.completed));

      final result = await executionService.incrementCount(task);
      expect(result.status, TaskStatus.completed);
    });
  });
}
