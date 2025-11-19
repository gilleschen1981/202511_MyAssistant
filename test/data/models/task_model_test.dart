import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';

void main() {
  group('TaskModel', () {
    test('should create a TaskModel with required fields', () {
      final windowStart = DateTime(2024, 1, 1, 9, 0);
      final windowEnd = DateTime(2024, 1, 1, 17, 0);
      const config = TaskConfiguration(
        durationMinutes: 25,
      );

      final task = TaskModel(
        id: 'task-123',
        userId: 'user-123',
        planId: 'plan-123',
        name: 'Test Task',
        config: config,
        windowStartTime: windowStart,
        windowEndTime: windowEnd,
        status: TaskStatus.active,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(task.id, 'task-123');
      expect(task.userId, 'user-123');
      expect(task.planId, 'plan-123');
      expect(task.name, 'Test Task');
      expect(task.config.taskType, TaskType.timer);
      expect(task.status, TaskStatus.active);
      expect(task.currentCount, 0);
      expect(task.repeatExecutionCount, 0);
      expect(task.description, null);
      expect(task.originalTaskId, null);
    });

    test('should correctly identify task type from configuration', () {
      // Timer task
      const timerConfig = TaskConfiguration(durationMinutes: 25);
      expect(timerConfig.taskType, TaskType.timer);

      // Counter task
      const counterConfig = TaskConfiguration(repeatCount: 10);
      expect(counterConfig.taskType, TaskType.counter);

      // Evaluation task
      const evalConfig = TaskConfiguration(
        evaluationOptions: ['Good', 'Bad'],
      );
      expect(evalConfig.taskType, TaskType.evaluation);

      // Combined timer + counter
      const timerCounterConfig = TaskConfiguration(
        durationMinutes: 25,
        repeatCount: 5,
      );
      expect(timerCounterConfig.taskType, TaskType.timerWithCount);

      // Combined counter + evaluation
      const counterEvalConfig = TaskConfiguration(
        repeatCount: 10,
        evaluationOptions: ['Excellent', 'Good', 'Fair'],
      );
      expect(counterEvalConfig.taskType, TaskType.counterWithEval);

      // Simple task (no config)
      const simpleConfig = TaskConfiguration();
      expect(simpleConfig.taskType, TaskType.simple);
    });

    test('should calculate progress correctly for counter tasks', () {
      const config = TaskConfiguration(repeatCount: 10);
      final task = TaskModel(
        id: 'task-123',
        userId: 'user-123',
        planId: 'plan-123',
        name: 'Counter Task',
        config: config,
        windowStartTime: DateTime.now(),
        windowEndTime: DateTime.now().add(const Duration(hours: 1)),
        status: TaskStatus.active,
        currentCount: 5,
        createdAt: DateTime.now(),
      );

      expect(task.progress, 0.5); // 5/10 = 0.5
    });

    test('should check if task is expired correctly', () {
      final pastWindowEnd = DateTime.now().subtract(const Duration(hours: 1));
      final futureWindowEnd = DateTime.now().add(const Duration(hours: 1));

      final expiredTask = TaskModel(
        id: 'task-123',
        userId: 'user-123',
        planId: 'plan-123',
        name: 'Expired Task',
        config: const TaskConfiguration(),
        windowStartTime: DateTime.now().subtract(const Duration(hours: 2)),
        windowEndTime: pastWindowEnd,
        status: TaskStatus.active,
        createdAt: DateTime.now(),
      );

      final activeTask = TaskModel(
        id: 'task-456',
        userId: 'user-123',
        planId: 'plan-123',
        name: 'Active Task',
        config: const TaskConfiguration(),
        windowStartTime: DateTime.now().subtract(const Duration(minutes: 30)),
        windowEndTime: futureWindowEnd,
        status: TaskStatus.active,
        createdAt: DateTime.now(),
      );

      expect(expiredTask.isExpired, true);
      expect(activeTask.isExpired, false);
    });

    test('should check if task can be executed', () {
      final now = DateTime.now();
      final activeTask = TaskModel(
        id: 'task-123',
        userId: 'user-123',
        planId: 'plan-123',
        name: 'Active Task',
        config: const TaskConfiguration(),
        windowStartTime: now.subtract(const Duration(minutes: 30)),
        windowEndTime: now.add(const Duration(minutes: 30)),
        status: TaskStatus.active,
        createdAt: now,
      );

      final completedTask = activeTask.copyWith(
        status: TaskStatus.completed,
        completedAt: now,
      );

      final expiredTask = TaskModel(
        id: 'task-456',
        userId: 'user-123',
        planId: 'plan-123',
        name: 'Expired Task',
        config: const TaskConfiguration(),
        windowStartTime: now.subtract(const Duration(hours: 2)),
        windowEndTime: now.subtract(const Duration(hours: 1)),
        status: TaskStatus.active,
        createdAt: now,
      );

      expect(activeTask.canExecute, true);
      expect(completedTask.canExecute, false);
      expect(expiredTask.canExecute, false);
    });

    test('should check if task can be repeated', () {
      final now = DateTime.now();
      final completedTaskInWindow = TaskModel(
        id: 'task-123',
        userId: 'user-123',
        planId: 'plan-123',
        name: 'Completed Task',
        config: const TaskConfiguration(),
        windowStartTime: now.subtract(const Duration(minutes: 30)),
        windowEndTime: now.add(const Duration(minutes: 30)),
        status: TaskStatus.completed,
        completedAt: now,
        createdAt: now,
      );

      final completedTaskOutOfWindow = TaskModel(
        id: 'task-456',
        userId: 'user-123',
        planId: 'plan-123',
        name: 'Old Completed Task',
        config: const TaskConfiguration(),
        windowStartTime: now.subtract(const Duration(hours: 2)),
        windowEndTime: now.subtract(const Duration(hours: 1)),
        status: TaskStatus.completed,
        completedAt: now.subtract(const Duration(hours: 1, minutes: 30)),
        createdAt: now.subtract(const Duration(hours: 2)),
      );

      expect(completedTaskInWindow.canRepeat, true);
      expect(completedTaskOutOfWindow.canRepeat, false);
    });

    test('should identify repeat execution correctly', () {
      final originalTask = TaskModel(
        id: 'task-123',
        userId: 'user-123',
        planId: 'plan-123',
        name: 'Original Task',
        config: const TaskConfiguration(),
        windowStartTime: DateTime.now(),
        windowEndTime: DateTime.now().add(const Duration(hours: 1)),
        status: TaskStatus.active,
        createdAt: DateTime.now(),
      );

      final repeatTask = TaskModel(
        id: 'task-456',
        userId: 'user-123',
        planId: 'plan-123',
        name: 'Original Task',
        config: const TaskConfiguration(),
        windowStartTime: DateTime.now(),
        windowEndTime: DateTime.now().add(const Duration(hours: 1)),
        status: TaskStatus.active,
        originalTaskId: 'task-123',
        repeatExecutionCount: 1,
        createdAt: DateTime.now(),
      );

      expect(originalTask.isRepeatExecution, false);
      expect(repeatTask.isRepeatExecution, true);
    });

    test('should serialize to JSON correctly', () {
      final task = TaskModel(
        id: 'task-123',
        userId: 'user-123',
        planId: 'plan-123',
        name: 'Test Task',
        description: 'A test task',
        config: const TaskConfiguration(
          durationMinutes: 25,
          repeatCount: 5,
        ),
        windowStartTime: DateTime(2024, 1, 1, 9, 0),
        windowEndTime: DateTime(2024, 1, 1, 17, 0),
        status: TaskStatus.active,
        currentCount: 2,
        createdAt: DateTime(2024, 1, 1),
      );

      final json = task.toJson();

      expect(json['id'], 'task-123');
      expect(json['userId'], 'user-123');
      expect(json['planId'], 'plan-123');
      expect(json['name'], 'Test Task');
      expect(json['description'], 'A test task');
      expect(json['status'], 'active');
      expect(json['currentCount'], 2);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'task-123',
        'userId': 'user-123',
        'planId': 'plan-123',
        'name': 'Test Task',
        'description': 'A test task',
        'config': {
          'durationMinutes': 25,
          'repeatCount': 5,
        },
        'windowStartTime': DateTime(2024, 1, 1, 9, 0).toIso8601String(),
        'windowEndTime': DateTime(2024, 1, 1, 17, 0).toIso8601String(),
        'status': 'active',
        'currentCount': 2,
        'createdAt': DateTime(2024, 1, 1).toIso8601String(),
      };

      final task = TaskModel.fromJson(json);

      expect(task.id, 'task-123');
      expect(task.userId, 'user-123');
      expect(task.planId, 'plan-123');
      expect(task.name, 'Test Task');
      expect(task.description, 'A test task');
      expect(task.status, TaskStatus.active);
      expect(task.currentCount, 2);
      expect(task.config.durationMinutes, 25);
      expect(task.config.repeatCount, 5);
    });

    test('copyWith should create a new instance with updated fields', () {
      final original = TaskModel(
        id: 'task-123',
        userId: 'user-123',
        planId: 'plan-123',
        name: 'Original Task',
        config: const TaskConfiguration(),
        windowStartTime: DateTime.now(),
        windowEndTime: DateTime.now().add(const Duration(hours: 1)),
        status: TaskStatus.active,
        createdAt: DateTime.now(),
      );

      final updated = original.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
        currentCount: 5,
      );

      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.status, TaskStatus.completed);
      expect(updated.currentCount, 5);
      expect(updated.completedAt, isNotNull);
      expect(identical(original, updated), false);
    });
  });
}