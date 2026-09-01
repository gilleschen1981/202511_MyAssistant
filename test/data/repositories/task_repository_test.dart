import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:myassistant/data/repositories/task_repository.dart';
import 'package:myassistant/data/data_sources/local/dao/task_dao.dart';
import 'package:myassistant/data/data_sources/local/dao/plan_dao.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';

import 'task_repository_test.mocks.dart';

@GenerateMocks([TaskDao, PlanDao])
void main() {
  late TaskRepository repository;
  late MockTaskDao mockTaskDao;
  late MockPlanDao mockPlanDao;

  setUp(() {
    mockTaskDao = MockTaskDao();
    mockPlanDao = MockPlanDao();
    repository = TaskRepository(
      taskDao: mockTaskDao,
      planDao: mockPlanDao,
    );
  });

  // Helper: create a test PlanModel
  PlanModel createTestPlan({
    String id = 'plan-1',
    String userId = 'user-1',
    String goalId = 'goal-1',
    String name = 'Test Plan',
    RepeatType repeatType = RepeatType.weekly,
  }) {
    final now = DateTime.now();
    return PlanModel(
      id: id,
      userId: userId,
      name: name,
      goalId: goalId,
      startDate: now.subtract(const Duration(days: 30)),
      endDate: now.add(const Duration(days: 30)),
      repeatRule: RepeatRule(type: repeatType),
      taskConfig: const TaskConfiguration(durationMinutes: 30),
      status: PlanStatus.active,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
    );
  }

  // Helper: create a test TaskModel
  TaskModel createTestTask({
    String id = 'task-1',
    String userId = 'user-1',
    String planId = 'plan-1',
    String name = 'Test Task',
    TaskConfiguration config = const TaskConfiguration(durationMinutes: 30),
    TaskStatus status = TaskStatus.active,
    DateTime? windowStartTime,
    DateTime? windowEndTime,
  }) {
    final now = DateTime.now();
    return TaskModel(
      id: id,
      userId: userId,
      planId: planId,
      name: name,
      config: config,
      windowStartTime: windowStartTime ?? now,
      windowEndTime: windowEndTime ?? now.add(const Duration(days: 7)),
      status: status,
      createdAt: now,
    );
  }

  // =========================================================================
  // createTask
  // =========================================================================
  group('createTask', () {
    test('should create task successfully when plan exists and no active task', () async {
      final plan = createTestPlan();
      final now = DateTime.now();
      final windowStart = now;
      final windowEnd = now.add(const Duration(days: 7));
      const config = TaskConfiguration(durationMinutes: 30);

      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => plan);
      when(mockTaskDao.getActivePlanTask('plan-1')).thenAnswer((_) async => null);
      when(mockTaskDao.insertTask(any)).thenAnswer((inv) async {
        final task = inv.positionalArguments[0] as TaskModel;
        return task;
      });

      final result = await repository.createTask(
        userId: 'user-1',
        planId: 'plan-1',
        name: 'New Task',
        config: config,
        windowStartTime: windowStart,
        windowEndTime: windowEnd,
      );

      expect(result.userId, 'user-1');
      expect(result.planId, 'plan-1');
      expect(result.name, 'New Task');
      expect(result.status, TaskStatus.active);
      verify(mockTaskDao.insertTask(any)).called(1);
    });

    test('should throw when plan does not exist', () async {
      when(mockPlanDao.getPlanById('plan-999')).thenAnswer((_) async => null);

      expect(
        () => repository.createTask(
          userId: 'user-1',
          planId: 'plan-999',
          name: 'Task',
          config: const TaskConfiguration(),
          windowStartTime: DateTime.now(),
          windowEndTime: DateTime.now().add(const Duration(days: 1)),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Plan not found'),
        )),
      );
    });

    test('should throw when window end time is before start time', () async {
      final plan = createTestPlan();
      final now = DateTime.now();

      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => plan);

      expect(
        () => repository.createTask(
          userId: 'user-1',
          planId: 'plan-1',
          name: 'Task',
          config: const TaskConfiguration(),
          windowStartTime: now.add(const Duration(days: 1)),
          windowEndTime: now,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Window end time must be after start time'),
        )),
      );
    });

    test('should throw when task configuration is invalid', () async {
      final plan = createTestPlan();
      final now = DateTime.now();

      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => plan);

      // durationMinutes and evaluationOptions cannot coexist
      expect(
        () => repository.createTask(
          userId: 'user-1',
          planId: 'plan-1',
          name: 'Task',
          config: const TaskConfiguration(
            durationMinutes: 30,
            evaluationOptions: ['Good', 'Bad'],
          ),
          windowStartTime: now,
          windowEndTime: now.add(const Duration(days: 1)),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid task configuration'),
        )),
      );
    });

    test('should throw when non-daysOfWeek plan already has active task', () async {
      final plan = createTestPlan(repeatType: RepeatType.weekly);
      final now = DateTime.now();
      final existingTask = createTestTask();

      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => plan);
      when(mockTaskDao.getActivePlanTask('plan-1')).thenAnswer((_) async => existingTask);

      expect(
        () => repository.createTask(
          userId: 'user-1',
          planId: 'plan-1',
          name: 'Task',
          config: const TaskConfiguration(),
          windowStartTime: now,
          windowEndTime: now.add(const Duration(days: 1)),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('该计划已有活跃任务'),
        )),
      );
    });

    test('should allow multiple active tasks for daysOfWeek plan', () async {
      final plan = createTestPlan(repeatType: RepeatType.daysOfWeek);
      // Override to make the plan have a valid daysOfWeek repeat rule
      final daysOfWeekPlan = PlanModel(
        id: plan.id,
        userId: plan.userId,
        name: plan.name,
        goalId: plan.goalId,
        startDate: plan.startDate,
        endDate: plan.endDate,
        repeatRule: const RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [1, 3, 5],
        ),
        taskConfig: plan.taskConfig,
        status: plan.status,
        createdAt: plan.createdAt,
        updatedAt: plan.updatedAt,
      );
      final now = DateTime.now();

      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => daysOfWeekPlan);
      // Note: for daysOfWeek, getActivePlanTask is NOT called
      when(mockTaskDao.insertTask(any)).thenAnswer((inv) async {
        final task = inv.positionalArguments[0] as TaskModel;
        return task;
      });

      final result = await repository.createTask(
        userId: 'user-1',
        planId: 'plan-1',
        name: 'Task',
        config: const TaskConfiguration(),
        windowStartTime: now,
        windowEndTime: now.add(const Duration(days: 1)),
      );

      expect(result, isNotNull);
      // Should NOT check for active plan task
      verifyNever(mockTaskDao.getActivePlanTask(any));
    });
  });

  // =========================================================================
  // completeTask
  // =========================================================================
  group('completeTask', () {
    test('should complete an active task successfully', () async {
      final task = createTestTask(
        config: const TaskConfiguration(),
        status: TaskStatus.active,
      );
      final completedTask = task.copyWith(status: TaskStatus.completed);

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);
      when(mockTaskDao.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);

      final result = await repository.completeTask(taskId: 'task-1');

      expect(result.status, TaskStatus.completed);
      verify(mockTaskDao.completeTask(
        taskId: 'task-1',
        actualDurationMinutes: null,
        evaluationResult: null,
        executionNote: null,
      )).called(1);
    });

    test('should throw when task not found', () async {
      when(mockTaskDao.getTaskById('task-999')).thenAnswer((_) async => null);

      expect(
        () => repository.completeTask(taskId: 'task-999'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Task not found'),
        )),
      );
    });

    test('should throw when task is not active', () async {
      final task = createTestTask(status: TaskStatus.completed);

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);

      expect(
        () => repository.completeTask(taskId: 'task-1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Only active tasks can be completed'),
        )),
      );
    });

    test('should throw when timer task is completed without actual duration', () async {
      final task = createTestTask(
        config: const TaskConfiguration(durationMinutes: 30),
        status: TaskStatus.active,
      );

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);

      expect(
        () => repository.completeTask(taskId: 'task-1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Timer task requires actual duration'),
        )),
      );
    });

    test('should complete timer task when actual duration is provided', () async {
      final task = createTestTask(
        config: const TaskConfiguration(durationMinutes: 30),
        status: TaskStatus.active,
      );
      final completedTask = task.copyWith(
        status: TaskStatus.completed,
        actualDurationMinutes: 25,
      );

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);
      when(mockTaskDao.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);

      final result = await repository.completeTask(
        taskId: 'task-1',
        actualDurationMinutes: 25,
      );

      expect(result.status, TaskStatus.completed);
    });

    test('should throw when evaluation task is completed without evaluation result', () async {
      final task = createTestTask(
        config: const TaskConfiguration(evaluationOptions: ['Good', 'Bad']),
        status: TaskStatus.active,
      );

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);

      expect(
        () => repository.completeTask(taskId: 'task-1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Evaluation task requires evaluation result'),
        )),
      );
    });

    test('should complete evaluation task when evaluation result is provided', () async {
      final task = createTestTask(
        config: const TaskConfiguration(evaluationOptions: ['Good', 'Bad']),
        status: TaskStatus.active,
      );
      final completedTask = task.copyWith(
        status: TaskStatus.completed,
        evaluationResult: 'Good',
      );

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);
      when(mockTaskDao.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);

      final result = await repository.completeTask(
        taskId: 'task-1',
        evaluationResult: 'Good',
      );

      expect(result.status, TaskStatus.completed);
    });

    test('should throw when DAO completeTask returns null', () async {
      final task = createTestTask(
        config: const TaskConfiguration(),
        status: TaskStatus.active,
      );

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);
      when(mockTaskDao.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => null);

      expect(
        () => repository.completeTask(taskId: 'task-1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to complete task'),
        )),
      );
    });
  });

  // =========================================================================
  // skipTask
  // =========================================================================
  group('skipTask', () {
    test('should skip an active task successfully', () async {
      final task = createTestTask(status: TaskStatus.active);
      final skippedTask = task.copyWith(status: TaskStatus.skipped);

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);
      when(mockTaskDao.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => skippedTask);

      final result = await repository.skipTask(taskId: 'task-1', reason: 'No time');

      expect(result.status, TaskStatus.skipped);
    });

    test('should throw when task not found', () async {
      when(mockTaskDao.getTaskById('task-999')).thenAnswer((_) async => null);

      expect(
        () => repository.skipTask(taskId: 'task-999'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Task not found'),
        )),
      );
    });

    test('should throw when task is not active', () async {
      final task = createTestTask(status: TaskStatus.completed);

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);

      expect(
        () => repository.skipTask(taskId: 'task-1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Only active tasks can be skipped'),
        )),
      );
    });

    test('should throw when DAO skipTask returns null', () async {
      final task = createTestTask(status: TaskStatus.active);

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);
      when(mockTaskDao.skipTask(
        taskId: anyNamed('taskId'),
        reason: anyNamed('reason'),
      )).thenAnswer((_) async => null);

      expect(
        () => repository.skipTask(taskId: 'task-1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to skip task'),
        )),
      );
    });
  });

  // =========================================================================
  // updateTaskProgress
  // =========================================================================
  group('updateTaskProgress', () {
    test('should update counter task progress successfully', () async {
      final task = createTestTask(
        config: const TaskConfiguration(repeatCount: 10),
        status: TaskStatus.active,
      );
      final updatedTask = task.copyWith(currentCount: 5);

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);
      when(mockTaskDao.updateTaskProgress('task-1', 5))
          .thenAnswer((_) async => updatedTask);

      final result = await repository.updateTaskProgress('task-1', 5);

      expect(result.currentCount, 5);
      verifyNever(mockTaskDao.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      ));
    });

    test('should auto-complete when counter reaches target', () async {
      final task = createTestTask(
        config: const TaskConfiguration(repeatCount: 10),
        status: TaskStatus.active,
      );
      final updatedTask = task.copyWith(currentCount: 10);
      final completedTask = task.copyWith(
        status: TaskStatus.completed,
        currentCount: 10,
      );

      // First getTaskById for updateTaskProgress
      // Second getTaskById for completeTask (called internally)
      when(mockTaskDao.getTaskById('task-1'))
          .thenAnswer((_) async => task);
      when(mockTaskDao.updateTaskProgress('task-1', 10))
          .thenAnswer((_) async => updatedTask);
      when(mockTaskDao.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);

      final result = await repository.updateTaskProgress('task-1', 10);

      expect(result.status, TaskStatus.completed);
      verify(mockTaskDao.completeTask(
        taskId: 'task-1',
        actualDurationMinutes: null,
        evaluationResult: null,
        executionNote: 'Auto-completed after reaching target count',
      )).called(1);
    });

    test('should auto-complete when counter exceeds target', () async {
      final task = createTestTask(
        config: const TaskConfiguration(repeatCount: 5),
        status: TaskStatus.active,
      );
      final updatedTask = task.copyWith(currentCount: 7);
      final completedTask = task.copyWith(
        status: TaskStatus.completed,
        currentCount: 7,
      );

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);
      when(mockTaskDao.updateTaskProgress('task-1', 7))
          .thenAnswer((_) async => updatedTask);
      when(mockTaskDao.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);

      final result = await repository.updateTaskProgress('task-1', 7);

      expect(result.status, TaskStatus.completed);
    });

    test('should pass actualDurationMinutes and evaluationResult during auto-complete', () async {
      final task = createTestTask(
        config: const TaskConfiguration(
          repeatCount: 3,
          // Note: counter + eval combo
        ),
        status: TaskStatus.active,
      );
      final updatedTask = task.copyWith(currentCount: 3);
      final completedTask = task.copyWith(status: TaskStatus.completed);

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);
      when(mockTaskDao.updateTaskProgress('task-1', 3))
          .thenAnswer((_) async => updatedTask);
      when(mockTaskDao.completeTask(
        taskId: anyNamed('taskId'),
        actualDurationMinutes: anyNamed('actualDurationMinutes'),
        evaluationResult: anyNamed('evaluationResult'),
        executionNote: anyNamed('executionNote'),
      )).thenAnswer((_) async => completedTask);

      await repository.updateTaskProgress(
        'task-1',
        3,
        actualDurationMinutes: 15,
        evaluationResult: 'Great',
      );

      verify(mockTaskDao.completeTask(
        taskId: 'task-1',
        actualDurationMinutes: 15,
        evaluationResult: 'Great',
        executionNote: 'Auto-completed after reaching target count',
      )).called(1);
    });

    test('should throw when task not found', () async {
      when(mockTaskDao.getTaskById('task-999')).thenAnswer((_) async => null);

      expect(
        () => repository.updateTaskProgress('task-999', 1),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Task not found'),
        )),
      );
    });

    test('should throw when task is not a counter task', () async {
      final task = createTestTask(
        config: const TaskConfiguration(durationMinutes: 30),
        status: TaskStatus.active,
      );

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);

      expect(
        () => repository.updateTaskProgress('task-1', 1),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('This is not a counter task'),
        )),
      );
    });

    test('should throw when task is not active', () async {
      final task = createTestTask(
        config: const TaskConfiguration(repeatCount: 10),
        status: TaskStatus.completed,
      );

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);

      expect(
        () => repository.updateTaskProgress('task-1', 1),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Only active tasks can be updated'),
        )),
      );
    });

    test('should throw when DAO updateTaskProgress returns null', () async {
      final task = createTestTask(
        config: const TaskConfiguration(repeatCount: 10),
        status: TaskStatus.active,
      );

      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);
      when(mockTaskDao.updateTaskProgress('task-1', 5))
          .thenAnswer((_) async => null);

      expect(
        () => repository.updateTaskProgress('task-1', 5),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to update task progress'),
        )),
      );
    });
  });

  // =========================================================================
  // updateTaskStatus
  // =========================================================================
  group('updateTaskStatus', () {
    test('should update task status successfully', () async {
      final task = createTestTask(status: TaskStatus.active);
      final updatedTask = task.copyWith(status: TaskStatus.completed);

      when(mockTaskDao.updateTaskStatus(
        'task-1',
        TaskStatus.completed,
        clearExecutionData: false,
        clearSkipData: false,
        clearDeletedAt: false,
      )).thenAnswer((_) async => updatedTask);

      final result = await repository.updateTaskStatus(
        taskId: 'task-1',
        status: TaskStatus.completed,
      );

      expect(result.status, TaskStatus.completed);
    });

    test('should throw when DAO returns null', () async {
      when(mockTaskDao.updateTaskStatus(
        'task-1',
        TaskStatus.active,
        clearExecutionData: false,
        clearSkipData: false,
        clearDeletedAt: false,
      )).thenAnswer((_) async => null);

      expect(
        () => repository.updateTaskStatus(
          taskId: 'task-1',
          status: TaskStatus.active,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to update task status'),
        )),
      );
    });
  });

  // =========================================================================
  // batchCreateTasks
  // =========================================================================
  group('batchCreateTasks', () {
    test('should return empty list for empty input', () async {
      final result = await repository.batchCreateTasks([]);

      expect(result, isEmpty);
      verifyNever(mockTaskDao.batchCreateTasks(any));
    });

    test('should batch create tasks with valid configurations', () async {
      final now = DateTime.now();
      final tasks = [
        createTestTask(
          id: 'task-1',
          config: const TaskConfiguration(),
          windowStartTime: now,
          windowEndTime: now.add(const Duration(days: 1)),
        ),
        createTestTask(
          id: 'task-2',
          config: const TaskConfiguration(durationMinutes: 15),
          windowStartTime: now,
          windowEndTime: now.add(const Duration(days: 1)),
        ),
      ];

      when(mockTaskDao.batchCreateTasks(any)).thenAnswer((_) async => tasks);

      final result = await repository.batchCreateTasks(tasks);

      expect(result.length, 2);
      verify(mockTaskDao.batchCreateTasks(tasks)).called(1);
    });

    test('should throw when any task has invalid configuration', () async {
      final now = DateTime.now();
      final tasks = [
        createTestTask(
          id: 'task-1',
          name: 'Bad Task',
          config: const TaskConfiguration(
            durationMinutes: 30,
            evaluationOptions: ['Good', 'Bad'],
          ),
          windowStartTime: now,
          windowEndTime: now.add(const Duration(days: 1)),
        ),
      ];

      expect(
        () => repository.batchCreateTasks(tasks),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid task configuration for task: Bad Task'),
        )),
      );
    });

    test('should throw when any task has invalid window times', () async {
      final now = DateTime.now();
      final tasks = [
        createTestTask(
          id: 'task-1',
          name: 'Time Error Task',
          config: const TaskConfiguration(),
          windowStartTime: now.add(const Duration(days: 1)),
          windowEndTime: now,
        ),
      ];

      expect(
        () => repository.batchCreateTasks(tasks),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid window times for task: Time Error Task'),
        )),
      );
    });
  });

  // =========================================================================
  // searchTasks
  // =========================================================================
  group('searchTasks', () {
    test('should return all user tasks when query is empty', () async {
      final tasks = [createTestTask()];

      when(mockTaskDao.getUserTasks('user-1')).thenAnswer((_) async => tasks);

      final result = await repository.searchTasks('user-1', '');

      expect(result.length, 1);
      verify(mockTaskDao.getUserTasks('user-1')).called(1);
      verifyNever(mockTaskDao.searchTasks(any, any));
    });

    test('should search tasks when query is not empty', () async {
      final tasks = [createTestTask(name: 'Exercise')];

      when(mockTaskDao.searchTasks('user-1', 'Exercise'))
          .thenAnswer((_) async => tasks);

      final result = await repository.searchTasks('user-1', 'Exercise');

      expect(result.length, 1);
      verify(mockTaskDao.searchTasks('user-1', 'Exercise')).called(1);
    });
  });

  // =========================================================================
  // deleteTask / deletePlanTasks
  // =========================================================================
  group('deleteTask', () {
    test('should return true when task is deleted successfully', () async {
      when(mockTaskDao.deleteTask('task-1')).thenAnswer((_) async => 1);

      final result = await repository.deleteTask('task-1');

      expect(result, true);
    });

    test('should return false when task does not exist', () async {
      when(mockTaskDao.deleteTask('task-999')).thenAnswer((_) async => 0);

      final result = await repository.deleteTask('task-999');

      expect(result, false);
    });
  });

  group('deletePlanTasks', () {
    test('should delete all tasks for a plan', () async {
      final tasks = [
        createTestTask(id: 'task-1'),
        createTestTask(id: 'task-2'),
        createTestTask(id: 'task-3'),
      ];

      when(mockTaskDao.getPlanTasks('plan-1')).thenAnswer((_) async => tasks);
      when(mockTaskDao.deleteTask('task-1')).thenAnswer((_) async => 1);
      when(mockTaskDao.deleteTask('task-2')).thenAnswer((_) async => 1);
      when(mockTaskDao.deleteTask('task-3')).thenAnswer((_) async => 1);

      final result = await repository.deletePlanTasks('plan-1');

      expect(result, true);
      verify(mockTaskDao.deleteTask('task-1')).called(1);
      verify(mockTaskDao.deleteTask('task-2')).called(1);
      verify(mockTaskDao.deleteTask('task-3')).called(1);
    });

    test('should return true when plan has no tasks', () async {
      when(mockTaskDao.getPlanTasks('plan-1')).thenAnswer((_) async => []);

      final result = await repository.deletePlanTasks('plan-1');

      expect(result, true);
    });

    test('should return false when some tasks fail to delete', () async {
      final tasks = [
        createTestTask(id: 'task-1'),
        createTestTask(id: 'task-2'),
      ];

      when(mockTaskDao.getPlanTasks('plan-1')).thenAnswer((_) async => tasks);
      when(mockTaskDao.deleteTask('task-1')).thenAnswer((_) async => 1);
      when(mockTaskDao.deleteTask('task-2')).thenAnswer((_) async => 0);

      final result = await repository.deletePlanTasks('plan-1');

      expect(result, false);
    });
  });

  // =========================================================================
  // Delegate methods (simple pass-through to DAO)
  // =========================================================================
  group('delegate methods', () {
    test('getTaskById should delegate to DAO', () async {
      final task = createTestTask();
      when(mockTaskDao.getTaskById('task-1')).thenAnswer((_) async => task);

      final result = await repository.getTaskById('task-1');

      expect(result, task);
      verify(mockTaskDao.getTaskById('task-1')).called(1);
    });

    test('getUserTasks should delegate to DAO', () async {
      final tasks = [createTestTask()];
      when(mockTaskDao.getUserTasks('user-1')).thenAnswer((_) async => tasks);

      final result = await repository.getUserTasks('user-1');

      expect(result, tasks);
    });

    test('getPlanTasks should delegate to DAO', () async {
      final tasks = [createTestTask()];
      when(mockTaskDao.getPlanTasks('plan-1')).thenAnswer((_) async => tasks);

      final result = await repository.getPlanTasks('plan-1');

      expect(result, tasks);
    });

    test('getActiveTasks should delegate to DAO', () async {
      when(mockTaskDao.getActiveTasks('user-1')).thenAnswer((_) async => []);

      final result = await repository.getActiveTasks('user-1');

      expect(result, isEmpty);
    });

    test('getTaskStatistics should delegate to DAO', () async {
      final stats = {'totalTasks': 10, 'completedTasks': 5};
      when(mockTaskDao.getTaskStatistics('user-1')).thenAnswer((_) async => stats);

      final result = await repository.getTaskStatistics('user-1');

      expect(result, stats);
    });

    test('getTaskCompletionRate should delegate to DAO', () async {
      when(mockTaskDao.getTaskCompletionRate('user-1', days: 30))
          .thenAnswer((_) async => 0.85);

      final result = await repository.getTaskCompletionRate('user-1');

      expect(result, 0.85);
    });

    test('addTaskHistoryEntry should always return true', () async {
      final result = await repository.addTaskHistoryEntry(
        taskId: 'task-1',
        userId: 'user-1',
        action: 'test',
      );

      expect(result, true);
    });
  });
}
