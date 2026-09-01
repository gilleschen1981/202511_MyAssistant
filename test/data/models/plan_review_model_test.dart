import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/data/models/plan_review_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';

/// Helper to create a PlanModel for tests
PlanModel _createPlan() {
  final now = DateTime.now();
  return PlanModel(
    id: 'plan-123',
    userId: 'user-123',
    name: 'Test Plan',
    goalId: 'goal-123',
    startDate: now.subtract(const Duration(days: 30)),
    endDate: now.add(const Duration(days: 30)),
    repeatRule: const RepeatRule(type: RepeatType.daily),
    taskConfig: const TaskConfiguration(durationMinutes: 25),
    createdAt: now,
    updatedAt: now,
  );
}

/// Helper to create a TaskModel with sensible defaults
TaskModel _createTask({
  String id = 'task-1',
  TaskStatus status = TaskStatus.active,
  DateTime? createdAt,
  DateTime? completedAt,
  DateTime? skippedAt,
  int? actualDurationMinutes,
  String? executionNote,
  TaskConfiguration config = const TaskConfiguration(),
  DateTime? windowStartTime,
  DateTime? windowEndTime,
}) {
  final now = DateTime.now();
  return TaskModel(
    id: id,
    userId: 'user-123',
    planId: 'plan-123',
    name: 'Task $id',
    config: config,
    windowStartTime:
        windowStartTime ?? now.subtract(const Duration(hours: 1)),
    windowEndTime: windowEndTime ?? now.add(const Duration(hours: 1)),
    status: status,
    createdAt: createdAt ?? now,
    completedAt: completedAt,
    skippedAt: skippedAt,
    actualDurationMinutes: actualDurationMinutes,
    executionNote: executionNote,
  );
}

void main() {
  group('PlanReviewStatistics', () {
    test('should create with required fields', () {
      const stats = PlanReviewStatistics(
        totalTasks: 10,
        completedTasks: 7,
        skippedTasks: 2,
        activeTasks: 1,
        completionRate: 0.7,
        avgDurationMinutes: 25.0,
      );

      expect(stats.totalTasks, 10);
      expect(stats.completedTasks, 7);
      expect(stats.skippedTasks, 2);
      expect(stats.activeTasks, 1);
      expect(stats.completionRate, 0.7);
      expect(stats.avgDurationMinutes, 25.0);
      expect(stats.lastCompletedTaskAt, isNull);
      expect(stats.lastSkippedTaskAt, isNull);
    });

    test('empty factory should create zeroed statistics', () {
      final stats = PlanReviewStatistics.empty();

      expect(stats.totalTasks, 0);
      expect(stats.completedTasks, 0);
      expect(stats.skippedTasks, 0);
      expect(stats.activeTasks, 0);
      expect(stats.completionRate, 0.0);
      expect(stats.avgDurationMinutes, isNull);
      expect(stats.lastCompletedTaskAt, isNull);
      expect(stats.lastSkippedTaskAt, isNull);
    });

    test('should include optional timestamp fields', () {
      final completedTime = DateTime(2024, 6, 15, 10, 30);
      final skippedTime = DateTime(2024, 6, 14, 8, 0);

      final stats = PlanReviewStatistics(
        totalTasks: 5,
        completedTasks: 3,
        skippedTasks: 1,
        activeTasks: 1,
        completionRate: 0.6,
        lastCompletedTaskAt: completedTime,
        lastSkippedTaskAt: skippedTime,
      );

      expect(stats.lastCompletedTaskAt, completedTime);
      expect(stats.lastSkippedTaskAt, skippedTime);
    });

    test('Equatable props should work correctly', () {
      const stats1 = PlanReviewStatistics(
        totalTasks: 10,
        completedTasks: 7,
        skippedTasks: 2,
        activeTasks: 1,
        completionRate: 0.7,
      );

      const stats2 = PlanReviewStatistics(
        totalTasks: 10,
        completedTasks: 7,
        skippedTasks: 2,
        activeTasks: 1,
        completionRate: 0.7,
      );

      const stats3 = PlanReviewStatistics(
        totalTasks: 5,
        completedTasks: 3,
        skippedTasks: 1,
        activeTasks: 1,
        completionRate: 0.6,
      );

      expect(stats1, equals(stats2));
      expect(stats1, isNot(equals(stats3)));
    });
  });

  group('TaskTrendDataPoint', () {
    test('should create with required fields', () {
      final date = DateTime(2024, 6, 15);

      final dataPoint = TaskTrendDataPoint(
        date: date,
        total: 10,
        completed: 7,
        skipped: 2,
        completionRate: 0.7,
      );

      expect(dataPoint.date, date);
      expect(dataPoint.total, 10);
      expect(dataPoint.completed, 7);
      expect(dataPoint.skipped, 2);
      expect(dataPoint.completionRate, 0.7);
    });

    test('Equatable props should work correctly', () {
      final date = DateTime(2024, 6, 15);

      final point1 = TaskTrendDataPoint(
        date: date,
        total: 10,
        completed: 7,
        skipped: 2,
        completionRate: 0.7,
      );

      final point2 = TaskTrendDataPoint(
        date: date,
        total: 10,
        completed: 7,
        skipped: 2,
        completionRate: 0.7,
      );

      final point3 = TaskTrendDataPoint(
        date: date,
        total: 5,
        completed: 3,
        skipped: 1,
        completionRate: 0.6,
      );

      expect(point1, equals(point2));
      expect(point1, isNot(equals(point3)));
    });
  });

  group('PlanReviewModel', () {
    test('should create with required fields', () {
      final plan = _createPlan();
      final stats = PlanReviewStatistics.empty();

      final review = PlanReviewModel(
        plan: plan,
        statistics: stats,
        tasks: const [],
      );

      expect(review.plan, plan);
      expect(review.statistics, stats);
      expect(review.tasks, isEmpty);
    });

    group('completedTasks', () {
      test('should return empty list when no tasks', () {
        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: const [],
        );

        expect(review.completedTasks, isEmpty);
      });

      test('should filter only completed tasks', () {
        final completedTime1 = DateTime(2024, 6, 15, 10, 0);
        final completedTime2 = DateTime(2024, 6, 16, 14, 0);

        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            completedAt: completedTime1,
            createdAt: DateTime(2024, 6, 15),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.active,
            createdAt: DateTime(2024, 6, 16),
          ),
          _createTask(
            id: 'task-3',
            status: TaskStatus.completed,
            completedAt: completedTime2,
            createdAt: DateTime(2024, 6, 16),
          ),
          _createTask(
            id: 'task-4',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 17),
            createdAt: DateTime(2024, 6, 17),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final completed = review.completedTasks;
        expect(completed.length, 2);
        expect(completed.every((t) => t.isCompleted), true);
      });

      test('should sort by completedAt descending', () {
        final earlier = DateTime(2024, 6, 15, 10, 0);
        final later = DateTime(2024, 6, 16, 14, 0);

        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            completedAt: earlier,
            createdAt: DateTime(2024, 6, 15),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.completed,
            completedAt: later,
            createdAt: DateTime(2024, 6, 16),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final completed = review.completedTasks;
        expect(completed.first.id, 'task-2'); // later should come first
        expect(completed.last.id, 'task-1');
      });

      test('should use createdAt as fallback when completedAt is null', () {
        final earlierCreated = DateTime(2024, 6, 10);
        final laterCreated = DateTime(2024, 6, 20);

        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            createdAt: earlierCreated,
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.completed,
            createdAt: laterCreated,
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final completed = review.completedTasks;
        // laterCreated should come first (descending order)
        expect(completed.first.id, 'task-2');
        expect(completed.last.id, 'task-1');
      });

      test('should return empty list when all tasks are active', () {
        final tasks = [
          _createTask(id: 'task-1', status: TaskStatus.active),
          _createTask(id: 'task-2', status: TaskStatus.active),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        expect(review.completedTasks, isEmpty);
      });
    });

    group('skippedTasks', () {
      test('should return empty list when no tasks', () {
        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: const [],
        );

        expect(review.skippedTasks, isEmpty);
      });

      test('should filter only skipped tasks', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 15),
            createdAt: DateTime(2024, 6, 15),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 16),
            createdAt: DateTime(2024, 6, 16),
          ),
          _createTask(
            id: 'task-3',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 17),
            createdAt: DateTime(2024, 6, 17),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final skipped = review.skippedTasks;
        expect(skipped.length, 2);
        expect(skipped.every((t) => t.isSkipped), true);
      });

      test('should sort by skippedAt descending', () {
        final earlier = DateTime(2024, 6, 15, 10, 0);
        final later = DateTime(2024, 6, 16, 14, 0);

        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.skipped,
            skippedAt: earlier,
            createdAt: DateTime(2024, 6, 15),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.skipped,
            skippedAt: later,
            createdAt: DateTime(2024, 6, 16),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final skipped = review.skippedTasks;
        expect(skipped.first.id, 'task-2'); // later should come first
        expect(skipped.last.id, 'task-1');
      });

      test('should return all tasks when all are skipped', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 15),
            createdAt: DateTime(2024, 6, 15),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 16),
            createdAt: DateTime(2024, 6, 16),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        expect(review.skippedTasks.length, 2);
      });
    });

    group('activeTasks', () {
      test('should return empty list when no tasks', () {
        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: const [],
        );

        expect(review.activeTasks, isEmpty);
      });

      test('should filter only active tasks', () {
        final now = DateTime.now();
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.active,
            windowEndTime: now.add(const Duration(hours: 2)),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.completed,
            completedAt: now,
          ),
          _createTask(
            id: 'task-3',
            status: TaskStatus.active,
            windowEndTime: now.add(const Duration(hours: 1)),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final active = review.activeTasks;
        expect(active.length, 2);
        expect(active.every((t) => t.status == TaskStatus.active), true);
      });

      test('should sort by windowEndTime ascending', () {
        final now = DateTime.now();
        final earlier = now.add(const Duration(hours: 1));
        final later = now.add(const Duration(hours: 3));

        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.active,
            windowEndTime: later,
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.active,
            windowEndTime: earlier,
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final active = review.activeTasks;
        expect(active.first.id, 'task-2'); // earlier end time first
        expect(active.last.id, 'task-1');
      });
    });

    group('tasksByDate', () {
      test('should return empty map when no tasks', () {
        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: const [],
        );

        expect(review.tasksByDate, isEmpty);
      });

      test('should group tasks by their creation date', () {
        final day1 = DateTime(2024, 6, 15, 10, 30);
        final day1Later = DateTime(2024, 6, 15, 14, 0);
        final day2 = DateTime(2024, 6, 16, 9, 0);

        final tasks = [
          _createTask(id: 'task-1', createdAt: day1),
          _createTask(id: 'task-2', createdAt: day1Later),
          _createTask(id: 'task-3', createdAt: day2),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final grouped = review.tasksByDate;
        expect(grouped.length, 2);

        final dateKey1 = DateTime(2024, 6, 15);
        final dateKey2 = DateTime(2024, 6, 16);

        expect(grouped[dateKey1]?.length, 2);
        expect(grouped[dateKey2]?.length, 1);
      });

      test('should strip time component from date keys', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            createdAt: DateTime(2024, 6, 15, 23, 59, 59),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final grouped = review.tasksByDate;
        final key = grouped.keys.first;
        expect(key.hour, 0);
        expect(key.minute, 0);
        expect(key.second, 0);
      });

      test('should handle single task per day', () {
        final tasks = [
          _createTask(id: 'task-1', createdAt: DateTime(2024, 6, 15)),
          _createTask(id: 'task-2', createdAt: DateTime(2024, 6, 16)),
          _createTask(id: 'task-3', createdAt: DateTime(2024, 6, 17)),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final grouped = review.tasksByDate;
        expect(grouped.length, 3);
        for (final entry in grouped.entries) {
          expect(entry.value.length, 1);
        }
      });
    });

    group('getCompletionRateTrend', () {
      test('should return empty map when no tasks', () {
        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: const [],
        );

        expect(review.getCompletionRateTrend(), isEmpty);
      });

      test('should calculate completion rate per day', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            createdAt: todayDate.add(const Duration(hours: 9)),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.active,
            createdAt: todayDate.add(const Duration(hours: 10)),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final trend = review.getCompletionRateTrend();
        expect(trend[todayDate], 0.5); // 1 completed out of 2
      });

      test('should return 1.0 when all tasks completed on a day', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            createdAt: todayDate.add(const Duration(hours: 9)),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.completed,
            createdAt: todayDate.add(const Duration(hours: 14)),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final trend = review.getCompletionRateTrend();
        expect(trend[todayDate], 1.0);
      });

      test('should return 0.0 when no tasks completed on a day', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.active,
            createdAt: todayDate.add(const Duration(hours: 9)),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.skipped,
            createdAt: todayDate.add(const Duration(hours: 10)),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final trend = review.getCompletionRateTrend();
        expect(trend[todayDate], 0.0);
      });

      test('should exclude tasks outside the date range', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final oldDate = todayDate.subtract(const Duration(days: 60));

        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            createdAt: todayDate.add(const Duration(hours: 9)),
          ),
          _createTask(
            id: 'task-old',
            status: TaskStatus.completed,
            createdAt: oldDate,
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final trend = review.getCompletionRateTrend(days: 30);
        // Old task should not appear (older than 30 days)
        expect(trend.containsKey(oldDate), false);
        expect(trend[todayDate], 1.0);
      });

      test('should support custom day range', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final fiveDaysAgo = todayDate.subtract(const Duration(days: 5));
        final tenDaysAgo = todayDate.subtract(const Duration(days: 10));

        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            createdAt: fiveDaysAgo.add(const Duration(hours: 9)),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.completed,
            createdAt: tenDaysAgo.add(const Duration(hours: 9)),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        // With 7-day range, 10-days-ago task should be excluded
        final trend = review.getCompletionRateTrend(days: 7);
        expect(trend.containsKey(fiveDaysAgo), true);
        expect(trend.containsKey(tenDaysAgo), false);
      });
    });

    group('getAvgDurationByType', () {
      test('should return empty map when no completed tasks', () {
        final tasks = [
          _createTask(id: 'task-1', status: TaskStatus.active),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        expect(review.getAvgDurationByType(), isEmpty);
      });

      test('should return empty map when completed tasks have no duration', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 15),
            createdAt: DateTime(2024, 6, 15),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        expect(review.getAvgDurationByType(), isEmpty);
      });

      test('should calculate average duration by task type', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 15),
            createdAt: DateTime(2024, 6, 15),
            actualDurationMinutes: 20,
            config: const TaskConfiguration(durationMinutes: 25),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 16),
            createdAt: DateTime(2024, 6, 16),
            actualDurationMinutes: 30,
            config: const TaskConfiguration(durationMinutes: 25),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final avgByType = review.getAvgDurationByType();
        final timerKey = TaskType.timer.toString();
        expect(avgByType.containsKey(timerKey), true);
        expect(avgByType[timerKey], 25.0); // (20 + 30) / 2
      });

      test('should group by different task types', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 15),
            createdAt: DateTime(2024, 6, 15),
            actualDurationMinutes: 20,
            config: const TaskConfiguration(durationMinutes: 25),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 16),
            createdAt: DateTime(2024, 6, 16),
            actualDurationMinutes: 5,
            config: const TaskConfiguration(repeatCount: 10),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final avgByType = review.getAvgDurationByType();
        expect(avgByType.length, 2);
        expect(avgByType[TaskType.timer.toString()], 20.0);
        expect(avgByType[TaskType.counter.toString()], 5.0);
      });

      test('should ignore skipped tasks', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 15),
            createdAt: DateTime(2024, 6, 15),
            actualDurationMinutes: 20,
            config: const TaskConfiguration(durationMinutes: 25),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 16),
            createdAt: DateTime(2024, 6, 16),
            actualDurationMinutes: 100,
            config: const TaskConfiguration(durationMinutes: 25),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final avgByType = review.getAvgDurationByType();
        // Only the completed task should be counted
        expect(avgByType[TaskType.timer.toString()], 20.0);
      });
    });

    group('getTaskCountByHour', () {
      test('should return empty map when no completed tasks', () {
        final tasks = [
          _createTask(id: 'task-1', status: TaskStatus.active),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        expect(review.getTaskCountByHour(), isEmpty);
      });

      test('should count completed tasks by hour of completedAt', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 15, 9, 0),
            createdAt: DateTime(2024, 6, 15, 8, 0),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 16, 9, 30),
            createdAt: DateTime(2024, 6, 16, 8, 0),
          ),
          _createTask(
            id: 'task-3',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 17, 14, 0),
            createdAt: DateTime(2024, 6, 17, 13, 0),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final countByHour = review.getTaskCountByHour();
        expect(countByHour[9], 2); // Two tasks completed at hour 9
        expect(countByHour[14], 1); // One task completed at hour 14
      });

      test('should use createdAt hour when completedAt is null', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            createdAt: DateTime(2024, 6, 15, 10, 0),
            // completedAt is null
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final countByHour = review.getTaskCountByHour();
        expect(countByHour[10], 1);
      });
    });

    group('getSkipReasons', () {
      test('should return empty map when no skipped tasks', () {
        final tasks = [
          _createTask(id: 'task-1', status: TaskStatus.active),
          _createTask(
            id: 'task-2',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 15),
            createdAt: DateTime(2024, 6, 15),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        expect(review.getSkipReasons(), isEmpty);
      });

      test('should count skip reasons correctly', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 15),
            createdAt: DateTime(2024, 6, 15),
            executionNote: 'Too busy',
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 16),
            createdAt: DateTime(2024, 6, 16),
            executionNote: 'Too busy',
          ),
          _createTask(
            id: 'task-3',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 17),
            createdAt: DateTime(2024, 6, 17),
            executionNote: 'Not feeling well',
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final reasons = review.getSkipReasons();
        expect(reasons['Too busy'], 2);
        expect(reasons['Not feeling well'], 1);
      });

      test('should use default reason when executionNote is null', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 15),
            createdAt: DateTime(2024, 6, 15),
            // executionNote is null
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 16),
            createdAt: DateTime(2024, 6, 16),
            executionNote: 'Specific reason',
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final reasons = review.getSkipReasons();
        expect(reasons['未提供原因'], 1);
        expect(reasons['Specific reason'], 1);
      });

      test('should handle all tasks with no execution note', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 15),
            createdAt: DateTime(2024, 6, 15),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 16),
            createdAt: DateTime(2024, 6, 16),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        final reasons = review.getSkipReasons();
        expect(reasons.length, 1);
        expect(reasons['未提供原因'], 2);
      });
    });

    group('mixed status scenarios', () {
      test('should handle all completed tasks', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 15),
            createdAt: DateTime(2024, 6, 15),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 16),
            createdAt: DateTime(2024, 6, 16),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        expect(review.completedTasks.length, 2);
        expect(review.skippedTasks, isEmpty);
        expect(review.activeTasks, isEmpty);
        expect(review.getSkipReasons(), isEmpty);
      });

      test('should handle all skipped tasks', () {
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 15),
            createdAt: DateTime(2024, 6, 15),
            executionNote: 'Reason A',
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 16),
            createdAt: DateTime(2024, 6, 16),
            executionNote: 'Reason B',
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        expect(review.completedTasks, isEmpty);
        expect(review.skippedTasks.length, 2);
        expect(review.activeTasks, isEmpty);
        expect(review.getTaskCountByHour(), isEmpty);
      });

      test('should handle mixed statuses correctly', () {
        final now = DateTime.now();
        final tasks = [
          _createTask(
            id: 'task-1',
            status: TaskStatus.completed,
            completedAt: DateTime(2024, 6, 15, 10, 0),
            createdAt: DateTime(2024, 6, 15),
            actualDurationMinutes: 25,
            config: const TaskConfiguration(durationMinutes: 25),
          ),
          _createTask(
            id: 'task-2',
            status: TaskStatus.skipped,
            skippedAt: DateTime(2024, 6, 16),
            createdAt: DateTime(2024, 6, 16),
            executionNote: 'No time',
          ),
          _createTask(
            id: 'task-3',
            status: TaskStatus.active,
            createdAt: now,
            windowEndTime: now.add(const Duration(hours: 2)),
          ),
        ];

        final review = PlanReviewModel(
          plan: _createPlan(),
          statistics: PlanReviewStatistics.empty(),
          tasks: tasks,
        );

        expect(review.completedTasks.length, 1);
        expect(review.skippedTasks.length, 1);
        expect(review.activeTasks.length, 1);
        expect(review.getSkipReasons()['No time'], 1);
        expect(review.getTaskCountByHour()[10], 1);
      });
    });

    group('Equatable', () {
      test('should be equal when plan, statistics, and tasks are the same', () {
        final plan = _createPlan();
        final stats = PlanReviewStatistics.empty();

        final review1 = PlanReviewModel(
          plan: plan,
          statistics: stats,
          tasks: const [],
        );

        final review2 = PlanReviewModel(
          plan: plan,
          statistics: stats,
          tasks: const [],
        );

        expect(review1, equals(review2));
      });

      test('should not be equal when tasks differ', () {
        final plan = _createPlan();
        final stats = PlanReviewStatistics.empty();

        final review1 = PlanReviewModel(
          plan: plan,
          statistics: stats,
          tasks: const [],
        );

        final review2 = PlanReviewModel(
          plan: plan,
          statistics: stats,
          tasks: [_createTask(id: 'task-1')],
        );

        expect(review1, isNot(equals(review2)));
      });
    });
  });
}
