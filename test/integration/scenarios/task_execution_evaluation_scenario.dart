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

  group('Scenario: evaluation task requires valid selection', () {
    test('complete with valid evaluation option', () async {
      final task = createTask(
        config: const TaskConfiguration(
          evaluationOptions: ['Excellent', 'Good', 'Fair', 'Poor'],
        ),
      );
      final completedTask = task.copyWith(status: TaskStatus.completed);

      when(mockTaskRepo.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);
      when(mockTaskRepo.getTodayTasks(any))
          .thenAnswer((_) async => [completedTask]);

      final result = await executionService.completeTask(
        task: task,
        evaluationResult: 'Good',
      );

      expect(result.completedTask.status, TaskStatus.completed);
      verify(mockTaskRepo.completeTask(
        taskId: task.id,
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: 'Good',
        executionNote: anyNamed('executionNote'),
      )).called(1);
    });

    test('throws when no evaluation result provided', () async {
      final task = createTask(
        config: const TaskConfiguration(
          evaluationOptions: ['Good', 'Bad'],
        ),
      );

      expect(
        () => executionService.completeTask(task: task),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws when evaluation result not in options', () async {
      final task = createTask(
        config: const TaskConfiguration(
          evaluationOptions: ['Good', 'Bad'],
        ),
      );

      expect(
        () => executionService.completeTask(
          task: task,
          evaluationResult: 'Unknown',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('each valid option can be selected', () async {
      final options = ['Excellent', 'Good', 'Fair', 'Poor'];
      final config = TaskConfiguration(evaluationOptions: options);

      for (final option in options) {
        final task = createTask(
          id: 'eval-$option',
          config: config,
        );
        final completedTask = task.copyWith(status: TaskStatus.completed);

        when(mockTaskRepo.completeTask(
          taskId: 'eval-$option',
          actualDurationMinutes: anyNamed('actualDurationMinutes'),
          evaluationResult: option,
          executionNote: anyNamed('executionNote'),
        )).thenAnswer((_) async => completedTask);
        when(mockTaskRepo.getTodayTasks(any))
            .thenAnswer((_) async => [completedTask]);

        final result = await executionService.completeTask(
          task: task,
          evaluationResult: option,
        );
        expect(result.completedTask.status, TaskStatus.completed);
      }
    });

    test('evaluation with exactly 2 options (minimum)', () async {
      final task = createTask(
        config: const TaskConfiguration(
          evaluationOptions: ['Yes', 'No'],
        ),
      );
      final completedTask = task.copyWith(status: TaskStatus.completed);

      when(mockTaskRepo.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);
      when(mockTaskRepo.getTodayTasks(any))
          .thenAnswer((_) async => [completedTask]);

      final result = await executionService.completeTask(
        task: task,
        evaluationResult: 'Yes',
      );
      expect(result.completedTask.status, TaskStatus.completed);
    });

    test('re-execute evaluation task preserves evaluationOptions', () async {
      final task = createTask(
        status: TaskStatus.completed,
        config: const TaskConfiguration(
          evaluationOptions: ['A', 'B', 'C'],
        ),
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
      expect(capturedConfig.evaluationOptions, ['A', 'B', 'C']);
    });
  });
}
