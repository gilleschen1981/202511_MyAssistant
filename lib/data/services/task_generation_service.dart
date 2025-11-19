import 'package:uuid/uuid.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';

/// Execution window for tasks
class ExecutionWindow {
  final DateTime start;
  final DateTime end;

  const ExecutionWindow({required this.start, required this.end});
}

/// Task generation service - responsible for automatically generating tasks based on plan rules
class TaskGenerationService {
  final ITaskRepository _taskRepository;
  final IPlanRepository _planRepository;
  final _uuid = const Uuid();

  TaskGenerationService({
    required ITaskRepository taskRepository,
    required IPlanRepository planRepository,
  })  : _taskRepository = taskRepository,
        _planRepository = planRepository;

  /// Generate next task for a specific plan
  Future<TaskModel?> generateNextTask(PlanModel plan) async {
    // 1. Check if plan is active
    if (!_isPlanActive(plan)) {
      return null;
    }

    // 2. Get the last task for this plan
    final lastTask = await _getLastTaskForPlan(plan.id);

    // 3. Check if should generate new task
    if (!_shouldGenerateTask(plan, lastTask)) {
      return null;
    }

    // 4. Calculate execution window
    final window = _calculateExecutionWindow(plan, lastTask);

    // 5. Create new task
    final task = TaskModel(
      id: _uuid.v4(),
      userId: plan.userId,
      planId: plan.id,
      name: plan.name,
      description: plan.description,
      config: plan.taskConfig,
      windowStartTime: window.start,
      windowEndTime: window.end,
      status: TaskStatus.active,
      createdAt: DateTime.now(),
    );

    // 6. Save task to database
    return await _taskRepository.createTask(
      userId: task.userId,
      planId: task.planId,
      name: task.name,
      description: task.description,
      config: task.config,
      windowStartTime: task.windowStartTime,
      windowEndTime: task.windowEndTime,
    );
  }

  /// Batch generate tasks (on app startup)
  Future<List<TaskModel>> generateAllPendingTasks(String userId) async {
    final generatedTasks = <TaskModel>[];

    // 1. Get all plans that need task generation
    final plans = await _planRepository.getPlansNeedingTaskGeneration(userId);

    // 2. Generate task for each plan
    for (final plan in plans) {
      final task = await generateNextTask(plan);
      if (task != null) {
        generatedTasks.add(task);
      }
    }

    return generatedTasks;
  }

  /// Generate tasks for specific date range
  Future<List<TaskModel>> generateTasksForDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final generatedTasks = <TaskModel>[];

    // Get active plans in date range
    final plans = await _planRepository.getPlansByDateRange(userId, startDate, endDate);

    for (final plan in plans) {
      if (!plan.isActive) continue;

      final task = await generateNextTask(plan);
      if (task != null) {
        generatedTasks.add(task);
      }
    }

    return generatedTasks;
  }

  /// Get last task for a plan
  Future<TaskModel?> _getLastTaskForPlan(String planId) async {
    final tasks = await _taskRepository.getPlanTasks(planId);
    if (tasks.isEmpty) return null;

    // Sort by window start time descending to get the most recent
    tasks.sort((a, b) => b.windowStartTime.compareTo(a.windowStartTime));
    return tasks.first;
  }

  /// Check if plan is in valid period
  bool _isPlanActive(PlanModel plan) {
    final now = DateTime.now();
    return now.isAfter(plan.startDate) &&
           now.isBefore(plan.endDate) &&
           plan.deletedAt == null;
  }

  /// Determine if should generate new task
  bool _shouldGenerateTask(PlanModel plan, TaskModel? lastTask) {
    // 1. If no history task, should generate
    if (lastTask == null) {
      return true;
    }

    // 2. If last task is still active and not expired, don't generate
    if (lastTask.status == TaskStatus.active && !lastTask.isExpired) {
      return false;
    }

    // 3. Check based on repeat rule
    final now = DateTime.now();

    switch (plan.repeatRule.type) {
      case RepeatType.oneTime:
        // One-time task: don't generate if already has task
        return false;

      case RepeatType.daily:
        // Daily task: check if today already has task
        return !_isSameDay(lastTask.windowStartTime, now);

      case RepeatType.weekly:
        // Weekly task: check if this week already has task
        return !_isSameWeek(lastTask.windowStartTime, now);

      case RepeatType.monthly:
        // Monthly task: check if this month already has task
        return !_isSameMonth(lastTask.windowStartTime, now);

      case RepeatType.custom:
        // Custom interval: check days passed
        final daysSinceLastTask = now.difference(lastTask.windowStartTime).inDays;
        return daysSinceLastTask >= (plan.repeatRule.customDays ?? 1);
    }
  }

  /// Calculate task execution window
  ExecutionWindow _calculateExecutionWindow(PlanModel plan, TaskModel? lastTask) {
    final now = DateTime.now();
    DateTime windowStart;
    DateTime windowEnd;

    if (lastTask == null) {
      // First task generation
      windowStart = _getStartOfDay(now);
    } else {
      // Calculate based on repeat rule
      switch (plan.repeatRule.type) {
        case RepeatType.oneTime:
          windowStart = plan.startDate;
          break;
        case RepeatType.daily:
          windowStart = _getStartOfDay(now);
          break;
        case RepeatType.weekly:
          windowStart = _getStartOfWeek(now);
          break;
        case RepeatType.monthly:
          windowStart = _getStartOfMonth(now);
          break;
        case RepeatType.custom:
          windowStart = lastTask.windowEndTime.add(const Duration(days: 1));
          break;
      }
    }

    // Calculate end time
    switch (plan.repeatRule.type) {
      case RepeatType.oneTime:
        windowEnd = plan.endDate;
        break;
      case RepeatType.daily:
        windowEnd = _getEndOfDay(windowStart);
        break;
      case RepeatType.weekly:
        windowEnd = _getEndOfWeek(windowStart);
        break;
      case RepeatType.monthly:
        windowEnd = _getEndOfMonth(windowStart);
        break;
      case RepeatType.custom:
        final days = (plan.repeatRule.customDays ?? 1) - 1;
        windowEnd = windowStart.add(Duration(days: days));
        windowEnd = _getEndOfDay(windowEnd);
        break;
    }

    // Ensure not exceeding plan end date
    if (windowEnd.isAfter(plan.endDate)) {
      windowEnd = plan.endDate;
    }

    return ExecutionWindow(start: windowStart, end: windowEnd);
  }

  // Helper methods
  DateTime _getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  DateTime _getStartOfWeek(DateTime date) {
    // Monday as start of week
    final weekday = date.weekday;
    return _getStartOfDay(date.subtract(Duration(days: weekday - 1)));
  }

  DateTime _getEndOfWeek(DateTime date) {
    // Sunday as end of week
    final weekday = date.weekday;
    return _getEndOfDay(date.add(Duration(days: 7 - weekday)));
  }

  DateTime _getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _getEndOfMonth(DateTime date) {
    final nextMonth = date.month == 12 ? 1 : date.month + 1;
    final nextYear = date.month == 12 ? date.year + 1 : date.year;
    final lastDay = DateTime(nextYear, nextMonth, 1).subtract(const Duration(days: 1));
    return _getEndOfDay(lastDay);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  bool _isSameWeek(DateTime date1, DateTime date2) {
    final week1 = _getWeekOfYear(date1);
    final week2 = _getWeekOfYear(date2);
    return date1.year == date2.year && week1 == week2;
  }

  bool _isSameMonth(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month;
  }

  int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirst = date.difference(firstDayOfYear).inDays;
    return (daysSinceFirst / 7).floor() + 1;
  }
}