import 'package:uuid/uuid.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/core/utils/app_logger.dart';

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
  /// For daysOfWeek type, this may generate multiple tasks (one for each selected day)
  /// Returns the first generated task for compatibility
  Future<TaskModel?> generateNextTask(PlanModel plan) async {
    AppLogger.d('generateNextTask called for plan: ${plan.name}', tag: 'TaskGenerationService');

    // Special handling for daysOfWeek type - generate multiple tasks
    if (plan.repeatRule.type == RepeatType.daysOfWeek) {
      final tasks = await _generateDaysOfWeekTasks(plan);
      return tasks.isNotEmpty ? tasks.first : null;
    }

    // Standard single-task generation for other repeat types
    // 1. Check if plan is active
    if (!_isPlanActive(plan)) {
      AppLogger.d('Plan is not active, skipping', tag: 'TaskGenerationService');
      return null;
    }
    AppLogger.d('Plan is active ✓', tag: 'TaskGenerationService');

    // 2. Get the last task for this plan
    AppLogger.d('Getting last task for plan...', tag: 'TaskGenerationService');
    final lastTask = await _getLastTaskForPlan(plan.id);
    if (lastTask != null) {
      AppLogger.d('Last task: ${lastTask.name}, status: ${lastTask.status}, window: ${lastTask.windowStartTime} - ${lastTask.windowEndTime}', tag: 'TaskGenerationService');
    } else {
      AppLogger.d('No previous task found (first generation)', tag: 'TaskGenerationService');
    }

    // 3. Check if should generate new task
    if (!_shouldGenerateTask(plan, lastTask)) {
      AppLogger.d('Should not generate task (conditions not met)', tag: 'TaskGenerationService');
      return null;
    }
    AppLogger.d('Should generate task ✓', tag: 'TaskGenerationService');

    // 4. Calculate execution window
    final window = _calculateExecutionWindow(plan, lastTask);
    AppLogger.d('Execution window: ${window.start} - ${window.end}', tag: 'TaskGenerationService');

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
    AppLogger.i('Creating task in database: ${task.name}', tag: 'TaskGenerationService');
    try {
      final createdTask = await _taskRepository.createTask(
        userId: task.userId,
        planId: task.planId,
        name: task.name,
        description: task.description,
        config: task.config,
        windowStartTime: task.windowStartTime,
        windowEndTime: task.windowEndTime,
      );
      AppLogger.i('Task created successfully ✓', tag: 'TaskGenerationService');
      return createdTask;
    } catch (e) {
      AppLogger.e('Failed to create task', tag: 'TaskGenerationService', error: e);
      return null;
    }
  }

  /// Generate tasks for daysOfWeek repeat type
  /// Creates one task for each selected day in the current week
  Future<List<TaskModel>> _generateDaysOfWeekTasks(PlanModel plan) async {
    AppLogger.d('_generateDaysOfWeekTasks called for plan: ${plan.name}', tag: 'TaskGenerationService');

    // 1. Check if plan is active
    if (!_isPlanActive(plan)) {
      AppLogger.d('Plan is not active, skipping', tag: 'TaskGenerationService');
      return [];
    }

    // 2. Get the last task to check if we need to generate
    final lastTask = await _getLastTaskForPlan(plan.id);

    // 3. Check if should generate
    if (!_shouldGenerateTask(plan, lastTask)) {
      AppLogger.d('Should not generate tasks (conditions not met)', tag: 'TaskGenerationService');
      return [];
    }

    // 4. Calculate task windows for each selected day
    final weekStart = _getStartOfWeek(DateTime.now());
    final taskWindows = _calculateTaskWindowsForWeek(plan, weekStart);
    AppLogger.i('Calculated ${taskWindows.length} task windows for selected days', tag: 'TaskGenerationService');
    for (var i = 0; i < taskWindows.length; i++) {
      AppLogger.d('  Window $i: ${taskWindows[i].start} - ${taskWindows[i].end}', tag: 'TaskGenerationService');
    }

    final generatedTasks = <TaskModel>[];

    // 5. For each window, check if task already exists, if not create it
    for (var i = 0; i < taskWindows.length; i++) {
      final window = taskWindows[i];
      AppLogger.d('Processing window $i: ${window.start}', tag: 'TaskGenerationService');

      // Check if task already exists for this day
      final existingTasks = await _taskRepository.getPlanTasks(plan.id);
      AppLogger.d('Found ${existingTasks.length} existing tasks for plan', tag: 'TaskGenerationService');

      final hasTaskForDay = existingTasks.any((t) =>
          _isSameDay(t.windowStartTime, window.start) &&
          t.status == TaskStatus.active);

      if (hasTaskForDay) {
        AppLogger.d('Task already exists for ${window.start}, skipping', tag: 'TaskGenerationService');
        continue;
      }

      // Create task for this day
      AppLogger.i('Creating task for ${window.start}', tag: 'TaskGenerationService');
      try {
        final createdTask = await _taskRepository.createTask(
          userId: plan.userId,
          planId: plan.id,
          name: plan.name,
          description: plan.description,
          config: plan.taskConfig,
          windowStartTime: window.start,
          windowEndTime: window.end,
        );
        generatedTasks.add(createdTask);
        AppLogger.i('Task created successfully for ${window.start} ✓', tag: 'TaskGenerationService');
      } catch (e, stackTrace) {
        AppLogger.e('Failed to create task for ${window.start}', tag: 'TaskGenerationService', error: e, stackTrace: stackTrace);
      }
    }

    AppLogger.i('Generated ${generatedTasks.length} tasks for daysOfWeek plan', tag: 'TaskGenerationService');
    return generatedTasks;
  }

  /// Batch generate tasks (on app startup)
  Future<List<TaskModel>> generateAllPendingTasks(String userId) async {
    AppLogger.i('generateAllPendingTasks called for user: $userId', tag: 'TaskGenerationService');
    final generatedTasks = <TaskModel>[];

    // 1. Get all plans that need task generation
    AppLogger.d('Getting plans needing task generation...', tag: 'TaskGenerationService');
    final plans = await _planRepository.getPlansNeedingTaskGeneration(userId);
    AppLogger.i('Found ${plans.length} plans needing task generation', tag: 'TaskGenerationService');

    // 2. Generate task for each plan
    for (final plan in plans) {
      AppLogger.d('Processing plan: ${plan.name} (id: ${plan.id})', tag: 'TaskGenerationService');
      final task = await generateNextTask(plan);
      if (task != null) {
        AppLogger.i('✓ Generated task: ${task.name}', tag: 'TaskGenerationService');
        generatedTasks.add(task);
      } else {
        AppLogger.d('✗ No task generated for plan: ${plan.name}', tag: 'TaskGenerationService');
      }
    }

    AppLogger.i('Generated ${generatedTasks.length} tasks in total', tag: 'TaskGenerationService');
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
    AppLogger.d('Checking if should generate task for plan: ${plan.name}', tag: 'TaskGenerationService');

    // 1. If no history task, should generate
    if (lastTask == null) {
      AppLogger.d('No previous task, should generate ✓', tag: 'TaskGenerationService');
      return true;
    }

    // 2. If last task is still active and not expired, don't generate
    if (lastTask.status == TaskStatus.active && !lastTask.isExpired) {
      AppLogger.d('Last task is still active and not expired, should NOT generate ✗', tag: 'TaskGenerationService');
      return false;
    }

    // 3. Check based on repeat rule
    final now = DateTime.now();
    AppLogger.d('Repeat type: ${plan.repeatRule.type}', tag: 'TaskGenerationService');

    switch (plan.repeatRule.type) {
      case RepeatType.oneTime:
        // One-time task: don't generate if already has task
        AppLogger.d('One-time task already has task, should NOT generate ✗', tag: 'TaskGenerationService');
        return false;

      case RepeatType.daily:
        // Daily task: check if today already has task
        final isSameDay = _isSameDay(lastTask.windowStartTime, now);
        AppLogger.d('Daily task - same day check: $isSameDay, should generate: ${!isSameDay}', tag: 'TaskGenerationService');
        return !isSameDay;

      case RepeatType.weekly:
        // Weekly task: check if this week already has task
        final lastWeekStart = _getStartOfWeek(lastTask.windowStartTime);
        final currentWeekStart = _getStartOfWeek(now);
        final isSameWeek = _isSameWeek(lastTask.windowStartTime, now);
        AppLogger.d(
          'Weekly task - last week start: $lastWeekStart, '
          'current week start: $currentWeekStart, '
          'same week: $isSameWeek, should generate: ${!isSameWeek}',
          tag: 'TaskGenerationService'
        );
        return !isSameWeek;

      case RepeatType.monthly:
        // Monthly task: check if this month already has task
        final isSameMonth = _isSameMonth(lastTask.windowStartTime, now);
        AppLogger.d('Monthly task - same month check: $isSameMonth, should generate: ${!isSameMonth}', tag: 'TaskGenerationService');
        return !isSameMonth;

      case RepeatType.daysOfWeek:
        // DaysOfWeek task: check if current week is missing any tasks for selected days
        // Different from weekly - we need to check if ALL selected days have tasks
        final isSameWeek = _isSameWeek(lastTask.windowStartTime, now);
        if (!isSameWeek) {
          // New week started, should generate tasks for this week
          AppLogger.d('DaysOfWeek task - new week started, should generate ✓', tag: 'TaskGenerationService');
          return true;
        }
        // Same week - need to check if we have all tasks for selected days
        // This will be handled in generateNextTask by checking individual days
        AppLogger.d('DaysOfWeek task - same week, checking in generateNextTask', tag: 'TaskGenerationService');
        return true;

      case RepeatType.custom:
        // Custom interval: check days passed
        final daysSinceLastTask = now.difference(lastTask.windowStartTime).inDays;
        final customDays = plan.repeatRule.customDays ?? 1;
        final shouldGenerate = daysSinceLastTask >= customDays;
        AppLogger.d('Custom task - days since last: $daysSinceLastTask, required: $customDays, should generate: $shouldGenerate', tag: 'TaskGenerationService');
        return shouldGenerate;
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
        case RepeatType.daysOfWeek:
          // Start of current week
          windowStart = _getStartOfWeek(now);
          break;
        case RepeatType.custom:
          windowStart = _getStartOfDay(lastTask.windowEndTime.add(const Duration(days: 1)));
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
      case RepeatType.daysOfWeek:
        // For daysOfWeek, execution window is the whole week
        // Individual task windows are calculated separately in _calculateTaskWindowsForWeek
        windowEnd = _getEndOfWeek(windowStart);
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

  /// Calculate task windows for each selected day of the week
  /// Used for daysOfWeek repeat type
  List<ExecutionWindow> _calculateTaskWindowsForWeek(
    PlanModel plan,
    DateTime weekStart,
  ) {
    final windows = <ExecutionWindow>[];
    final selectedDays = plan.repeatRule.selectedDaysOfWeek!;
    final now = DateTime.now();

    for (final dayOfWeek in selectedDays) {
      // Calculate date for this day in the week
      // dayOfWeek: 1=Monday, 7=Sunday
      final taskDate = weekStart.add(Duration(days: dayOfWeek - 1));

      // Skip if date is before plan start or after plan end
      if (taskDate.isBefore(_getStartOfDay(plan.startDate)) ||
          taskDate.isAfter(_getEndOfDay(plan.endDate))) {
        continue;
      }

      // For first week: skip days that have already passed
      if (taskDate.isBefore(_getStartOfDay(now))) {
        continue;
      }

      windows.add(ExecutionWindow(
        start: _getStartOfDay(taskDate),
        end: _getEndOfDay(taskDate),
      ));
    }

    return windows;
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
    final week1Start = _getStartOfWeek(date1);
    final week2Start = _getStartOfWeek(date2);
    return week1Start.year == week2Start.year &&
           week1Start.month == week2Start.month &&
           week1Start.day == week2Start.day;
  }

  bool _isSameMonth(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month;
  }
}