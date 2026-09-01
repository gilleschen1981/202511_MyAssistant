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

  group('Scenario: simple task complete → re-execute flow', () {
    test('complete simple task with note', () async {
      final task = createTask(
        config: const TaskConfiguration(),
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
        executionNote: 'Done!',
      );

      expect(result.completedTask.status, TaskStatus.completed);
      expect(result.statistics.todayCompleted, 1);
    });

    test('complete then re-execute creates new task instance', () async {
      final task = createTask(
        id: 'task-original',
        config: const TaskConfiguration(),
        status: TaskStatus.completed,
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

      final result = await executionService.reExecuteTask(task);

      expect(result, isNotNull);
      expect(result!.id, 'task-new');
      expect(result.id, isNot(task.id));
    });

    test('cannot complete already completed task', () async {
      final task = createTask(status: TaskStatus.completed);

      expect(
        () => executionService.completeTask(task: task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('cannot complete expired task', () async {
      final now = DateTime.now();
      final task = createTask(
        windowStartTime: now.subtract(const Duration(days: 2)),
        windowEndTime: now.subtract(const Duration(days: 1)),
      );

      expect(
        () => executionService.completeTask(task: task),
        throwsA(isA<BusinessException>()),
      );
    });

    test('statistics reflect all today tasks', () async {
      final task = createTask(id: 'task-1');
      final completedTask = task.copyWith(status: TaskStatus.completed);

      final todayTasks = [
        completedTask,
        createTask(id: 'task-2', status: TaskStatus.active),
        createTask(id: 'task-3', status: TaskStatus.active),
        createTask(id: 'task-4', status: TaskStatus.skipped),
      ];

      when(mockTaskRepo.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);
      when(mockTaskRepo.getTodayTasks(any))
          .thenAnswer((_) async => todayTasks);

      final result = await executionService.completeTask(task: task);

      expect(result.statistics.todayCompleted, 1);
      expect(result.statistics.todayRemaining, 2);
      expect(result.statistics.todaySkipped, 1);
      expect(result.statistics.completionRate, closeTo(0.25, 0.01));
    });
  });
}
