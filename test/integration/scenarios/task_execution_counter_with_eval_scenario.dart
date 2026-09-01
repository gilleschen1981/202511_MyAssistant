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

  group('Scenario: counterWithEval (counter + evaluation combined)', () {
    test('config produces correct taskType', () {
      const config = TaskConfiguration(
        repeatCount: 5,
        evaluationOptions: ['Good', 'OK', 'Bad'],
      );
      expect(config.taskType, TaskType.counterWithEval);
      expect(config.isValid, true);
    });

    test('increment with evaluationResult on last count', () async {
      final task = createTask(
        id: 'cwe-task',
        config: const TaskConfiguration(
          repeatCount: 3,
          evaluationOptions: ['Good', 'OK', 'Bad'],
        ),
        currentCount: 2,
      );

      // Last increment with evaluation
      when(mockTaskRepo.updateTaskProgress(
        'cwe-task',
        3,
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: 'Good',
      )).thenAnswer((_) async =>
          task.copyWith(currentCount: 3, status: TaskStatus.completed));

      final result = await executionService.incrementCount(
        task,
        evaluationResult: 'Good',
      );

      expect(result.status, TaskStatus.completed);
      expect(result.currentCount, 3);
    });

    test('complete counterWithEval requires evaluation result', () async {
      final task = createTask(
        config: const TaskConfiguration(
          repeatCount: 5,
          evaluationOptions: ['Good', 'Bad'],
        ),
      );

      expect(
        () => executionService.completeTask(task: task),
        throwsA(isA<ValidationException>()),
      );
    });

    test('complete counterWithEval with valid evaluation', () async {
      final task = createTask(
        config: const TaskConfiguration(
          repeatCount: 5,
          evaluationOptions: ['Good', 'Bad'],
        ),
      );
      final completedTask = task.copyWith(status: TaskStatus.completed);

      when(mockTaskRepo.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: 'Good',
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);
      when(mockTaskRepo.getTodayTasks(any))
          .thenAnswer((_) async => [completedTask]);

      final result = await executionService.completeTask(
        task: task,
        evaluationResult: 'Good',
      );

      expect(result.completedTask.status, TaskStatus.completed);
    });

    test('invalid evaluation result rejected', () async {
      final task = createTask(
        config: const TaskConfiguration(
          repeatCount: 5,
          evaluationOptions: ['Good', 'Bad'],
        ),
      );

      expect(
        () => executionService.completeTask(
          task: task,
          evaluationResult: 'Invalid',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('re-execute resets repeatCount, preserves evaluationOptions',
        () async {
      final task = createTask(
        status: TaskStatus.completed,
        config: const TaskConfiguration(
          repeatCount: 5,
          evaluationOptions: ['A', 'B', 'C'],
        ),
        currentCount: 5,
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
      expect(capturedConfig.evaluationOptions, ['A', 'B', 'C']);
      // After reset: no repeatCount + evaluationOptions → evaluation type
      expect(capturedConfig.taskType, TaskType.evaluation);
    });

    test('counter increment flow without evaluation (intermediate steps)',
        () async {
      final task = createTask(
        id: 'cwe-task',
        config: const TaskConfiguration(
          repeatCount: 3,
          evaluationOptions: ['Good', 'OK', 'Bad'],
        ),
        currentCount: 0,
      );

      // Increment without evaluation (not final step)
      when(mockTaskRepo.updateTaskProgress(
        'cwe-task',
        1,
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
      )).thenAnswer((_) async => task.copyWith(currentCount: 1));

      final result = await executionService.incrementCount(task);
      expect(result.currentCount, 1);
      expect(result.status, TaskStatus.active);
    });
  });
}
