import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:myassistant/data/services/task_execution_service.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
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

  group('Scenario: re-execute task across all config types', () {
    test('re-execute simple task creates new instance', () async {
      final task = createTask(
        id: 'orig-simple',
        status: TaskStatus.completed,
        config: const TaskConfiguration(),
      );
      final newTask = createTask(id: 'new-simple');

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

      final result = await executionService.reExecuteTask(task);
      expect(result, isNotNull);
      expect(result!.id, isNot(task.id));
    });

    test('re-execute timer task preserves durationMinutes', () async {
      final task = createTask(
        status: TaskStatus.completed,
        config: const TaskConfiguration(durationMinutes: 45),
      );
      final newTask = createTask(id: 'new-timer');

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

      final config = captured.first as TaskConfiguration;
      expect(config.durationMinutes, 45);
      expect(config.repeatCount, isNull); // No counter to reset
    });

    test('re-execute counter task: repeatCount → null, becomes simple',
        () async {
      final task = createTask(
        status: TaskStatus.completed,
        config: const TaskConfiguration(repeatCount: 10),
      );
      final newTask = createTask(id: 'new-counter');

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

      final config = captured.first as TaskConfiguration;
      expect(config.repeatCount, isNull);
      expect(config.taskType, TaskType.simple);
    });

    test(
        're-execute timerWithCount: repeatCount → null, becomes timer',
        () async {
      final task = createTask(
        status: TaskStatus.completed,
        config: const TaskConfiguration(durationMinutes: 25, repeatCount: 5),
      );
      final newTask = createTask(id: 'new-twc');

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

      final config = captured.first as TaskConfiguration;
      expect(config.durationMinutes, 25);
      expect(config.repeatCount, isNull);
      expect(config.taskType, TaskType.timer);
    });

    test(
        're-execute counterWithEval: repeatCount → null, becomes evaluation',
        () async {
      final task = createTask(
        status: TaskStatus.completed,
        config: const TaskConfiguration(
          repeatCount: 5,
          evaluationOptions: ['A', 'B', 'C'],
        ),
      );
      final newTask = createTask(id: 'new-cwe');

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

      final config = captured.first as TaskConfiguration;
      expect(config.repeatCount, isNull);
      expect(config.evaluationOptions, ['A', 'B', 'C']);
      expect(config.taskType, TaskType.evaluation);
    });

    test('re-execute evaluation task preserves evaluationOptions', () async {
      final task = createTask(
        status: TaskStatus.completed,
        config: const TaskConfiguration(
          evaluationOptions: ['Good', 'OK', 'Bad'],
        ),
      );
      final newTask = createTask(id: 'new-eval');

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

      final config = captured.first as TaskConfiguration;
      expect(config.evaluationOptions, ['Good', 'OK', 'Bad']);
    });

    test('cannot re-execute active task', () async {
      final task = createTask(status: TaskStatus.active);

      final result = await executionService.reExecuteTask(task);
      expect(result, isNull);
    });

    test('daysOfWeek task can only be re-executed on same day', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final plan = createPlan(
        repeatRule: RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [yesterday.weekday],
        ),
      );

      final task = createTask(
        status: TaskStatus.completed,
        planId: plan.id,
        windowStartTime: startOfDay(yesterday),
        windowEndTime: endOfDay(yesterday),
      );

      when(mockPlanRepo.getPlanById(plan.id))
          .thenAnswer((_) async => plan);

      expect(
        () => executionService.reExecuteTask(task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('re-execute preserves original window times', () async {
      final now = DateTime.now();
      final task = createTask(
        status: TaskStatus.completed,
        config: const TaskConfiguration(),
        windowStartTime: startOfDay(now),
        windowEndTime: endOfDay(now),
      );
      final newTask = createTask(id: 'new-task');

      when(mockPlanRepo.getPlanById(any)).thenAnswer((_) async => null);
      when(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: captureAnyNamed('windowStartTime'),
        windowEndTime: captureAnyNamed('windowEndTime'),
      )).thenAnswer((_) async => newTask);

      await executionService.reExecuteTask(task);

      final captured = verify(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: captureAnyNamed('windowStartTime'),
        windowEndTime: captureAnyNamed('windowEndTime'),
      )).captured;

      final capturedStart = captured[captured.length - 2] as DateTime;
      final capturedEnd = captured[captured.length - 1] as DateTime;
      expect(capturedStart, task.windowStartTime);
      expect(capturedEnd, task.windowEndTime);
    });
  });
}
