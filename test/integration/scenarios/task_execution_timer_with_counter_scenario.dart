import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:myassistant/data/services/task_execution_service.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
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

  group('Scenario: timerWithCount task (timer + counter combined)', () {
    test('config produces correct taskType', () {
      const config = TaskConfiguration(durationMinutes: 25, repeatCount: 5);
      expect(config.taskType, TaskType.timerWithCount);
      expect(config.isValid, true);
    });

    test('can start timer for timerWithCount task', () async {
      final task = createTask(
        config: const TaskConfiguration(durationMinutes: 25, repeatCount: 5),
      );

      final session = await executionService.startTimer(task: task);
      expect(session.taskId, task.id);
      expect(session.targetDuration, const Duration(minutes: 25));
    });

    test('can increment counter for timerWithCount task', () async {
      final task = createTask(
        id: 'twc-task',
        config: const TaskConfiguration(durationMinutes: 25, repeatCount: 5),
        currentCount: 2,
      );

      when(mockTaskRepo.updateTaskProgress(
        'twc-task',
        3,
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
      )).thenAnswer((_) async => task.copyWith(currentCount: 3));

      final result = await executionService.incrementCount(task);
      expect(result.currentCount, 3);
    });

    test('counter reaching target auto-completes timerWithCount task',
        () async {
      final task = createTask(
        id: 'twc-task',
        config: const TaskConfiguration(durationMinutes: 25, repeatCount: 3),
        currentCount: 2,
      );

      when(mockTaskRepo.updateTaskProgress(
        'twc-task',
        3,
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
      )).thenAnswer((_) async =>
          task.copyWith(currentCount: 3, status: TaskStatus.completed));

      final result = await executionService.incrementCount(task);
      expect(result.status, TaskStatus.completed);
    });

    test('complete timerWithCount stops timer session', () async {
      final task = createTask(
        config: const TaskConfiguration(durationMinutes: 25, repeatCount: 5),
      );
      final completedTask = task.copyWith(status: TaskStatus.completed);

      await executionService.startTimer(task: task);

      when(mockTaskRepo.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);
      when(mockTaskRepo.getTodayTasks(any))
          .thenAnswer((_) async => [completedTask]);

      await executionService.completeTask(task: task, actualDurationMinutes: 25);

      expect(executionService.getTimerSession(task.id), isNull);
    });

    test('re-execute resets repeatCount but preserves durationMinutes',
        () async {
      final task = createTask(
        status: TaskStatus.completed,
        config: const TaskConfiguration(durationMinutes: 25, repeatCount: 5),
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
      expect(capturedConfig.durationMinutes, 25);
    });
  });
}
