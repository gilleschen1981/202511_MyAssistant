import 'package:equatable/equatable.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';

/// Plan review statistics
class PlanReviewStatistics extends Equatable {
  final int totalTasks;
  final int completedTasks;
  final int skippedTasks;
  final int activeTasks;
  final double completionRate;
  final double? avgDurationMinutes;
  final DateTime? lastCompletedTaskAt;
  final DateTime? lastSkippedTaskAt;

  const PlanReviewStatistics({
    required this.totalTasks,
    required this.completedTasks,
    required this.skippedTasks,
    required this.activeTasks,
    required this.completionRate,
    this.avgDurationMinutes,
    this.lastCompletedTaskAt,
    this.lastSkippedTaskAt,
  });

  factory PlanReviewStatistics.empty() {
    return const PlanReviewStatistics(
      totalTasks: 0,
      completedTasks: 0,
      skippedTasks: 0,
      activeTasks: 0,
      completionRate: 0.0,
    );
  }

  @override
  List<Object?> get props => [
        totalTasks,
        completedTasks,
        skippedTasks,
        activeTasks,
        completionRate,
        avgDurationMinutes,
        lastCompletedTaskAt,
        lastSkippedTaskAt,
      ];
}

/// Plan review model - combines plan with its statistics and tasks
class PlanReviewModel extends Equatable {
  final PlanModel plan;
  final PlanReviewStatistics statistics;
  final List<TaskModel> tasks;

  const PlanReviewModel({
    required this.plan,
    required this.statistics,
    required this.tasks,
  });

  /// Get completed tasks
  List<TaskModel> get completedTasks =>
      tasks.where((t) => t.isCompleted).toList()
        ..sort((a, b) => (b.completedAt ?? b.createdAt)
            .compareTo(a.completedAt ?? a.createdAt));

  /// Get skipped tasks
  List<TaskModel> get skippedTasks =>
      tasks.where((t) => t.isSkipped).toList()
        ..sort((a, b) => (b.skippedAt ?? b.createdAt)
            .compareTo(a.skippedAt ?? a.createdAt));

  /// Get active tasks
  List<TaskModel> get activeTasks =>
      tasks.where((t) => t.status == TaskStatus.active).toList()
        ..sort((a, b) => a.windowEndTime.compareTo(b.windowEndTime));

  /// Get tasks grouped by date
  Map<DateTime, List<TaskModel>> get tasksByDate {
    final grouped = <DateTime, List<TaskModel>>{};

    for (final task in tasks) {
      final date = DateTime(
        task.createdAt.year,
        task.createdAt.month,
        task.createdAt.day,
      );
      grouped.putIfAbsent(date, () => []).add(task);
    }

    return grouped;
  }

  /// Get completion rate trend (last N days)
  Map<DateTime, double> getCompletionRateTrend({int days = 30}) {
    final trend = <DateTime, double>{};
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));

    // Group tasks by date
    final tasksByDay = <DateTime, List<TaskModel>>{};
    for (final task in tasks) {
      final taskDate = DateTime(
        task.createdAt.year,
        task.createdAt.month,
        task.createdAt.day,
      );

      if (taskDate.isAfter(startDate) && taskDate.isBefore(now.add(const Duration(days: 1)))) {
        tasksByDay.putIfAbsent(taskDate, () => []).add(task);
      }
    }

    // Calculate completion rate for each day
    for (final entry in tasksByDay.entries) {
      final dayTasks = entry.value;
      final completed = dayTasks.where((t) => t.isCompleted).length;
      final total = dayTasks.length;
      trend[entry.key] = total > 0 ? completed / total : 0.0;
    }

    return trend;
  }

  /// Get average duration by task type
  Map<String, double> getAvgDurationByType() {
    final durationByType = <String, List<double>>{};

    for (final task in completedTasks) {
      if (task.actualDurationMinutes != null) {
        final typeKey = task.config.taskType.toString();
        durationByType.putIfAbsent(typeKey, () => []).add(
          task.actualDurationMinutes!.toDouble(),
        );
      }
    }

    final avgByType = <String, double>{};
    for (final entry in durationByType.entries) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      avgByType[entry.key] = avg;
    }

    return avgByType;
  }

  /// Get task count by hour of day (to find best execution time)
  Map<int, int> getTaskCountByHour() {
    final countByHour = <int, int>{};

    for (final task in completedTasks) {
      final hour = task.completedAt?.hour ?? task.createdAt.hour;
      countByHour[hour] = (countByHour[hour] ?? 0) + 1;
    }

    return countByHour;
  }

  /// Get skip reasons with count
  Map<String, int> getSkipReasons() {
    final reasons = <String, int>{};

    for (final task in skippedTasks) {
      final reason = task.executionNote ?? '未提供原因';
      reasons[reason] = (reasons[reason] ?? 0) + 1;
    }

    return reasons;
  }

  @override
  List<Object?> get props => [plan, statistics, tasks];
}

/// Task execution trend data point
class TaskTrendDataPoint extends Equatable {
  final DateTime date;
  final int total;
  final int completed;
  final int skipped;
  final double completionRate;

  const TaskTrendDataPoint({
    required this.date,
    required this.total,
    required this.completed,
    required this.skipped,
    required this.completionRate,
  });

  @override
  List<Object> get props => [date, total, completed, skipped, completionRate];
}
