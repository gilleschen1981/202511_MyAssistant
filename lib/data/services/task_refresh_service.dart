import 'dart:async';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/services/task_generation_service.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/core/utils/app_logger.dart';

/// Refresh result model
class RefreshResult {
  bool success = false;
  String? error;
  int generatedCount = 0;
  int expiredCount = 0;
  List<TaskModel> newTasks = [];
  DateTime? lastRefreshTime;

  RefreshResult();
}

/// Task refresh service - periodically checks and refreshes task status
class TaskRefreshService {
  final ITaskRepository _taskRepository;
  final IPlanRepository _planRepository;
  final TaskGenerationService _generationService;

  Timer? _periodicTimer;

  TaskRefreshService({
    required ITaskRepository taskRepository,
    required IPlanRepository planRepository,
    required TaskGenerationService generationService,
  })  : _taskRepository = taskRepository,
        _planRepository = planRepository,
        _generationService = generationService;

  /// Refresh all tasks for a user
  Future<RefreshResult> refreshAllTasks(String userId) async {
    AppLogger.i('refreshAllTasks called for user: $userId', tag: 'TaskRefreshService');
    final result = RefreshResult();

    try {
      // 1. Handle expired tasks
      AppLogger.d('Handling expired tasks...', tag: 'TaskRefreshService');
      result.expiredCount = await _handleExpiredTasks(userId);
      AppLogger.i('Handled ${result.expiredCount} expired tasks', tag: 'TaskRefreshService');

      // 2. Generate new tasks
      AppLogger.d('Generating pending tasks...', tag: 'TaskRefreshService');
      final newTasks = await _generationService.generateAllPendingTasks(userId);
      result.generatedCount = newTasks.length;
      result.newTasks = newTasks;
      AppLogger.i('Generated ${newTasks.length} new tasks', tag: 'TaskRefreshService');

      result.success = true;
      result.lastRefreshTime = DateTime.now();
      AppLogger.i('refreshAllTasks completed successfully ✓', tag: 'TaskRefreshService');
    } catch (e) {
      AppLogger.e('Error during refreshAllTasks', tag: 'TaskRefreshService', error: e);
      result.success = false;
      result.error = e.toString();
    }

    return result;
  }

  /// Handle expired tasks
  Future<int> _handleExpiredTasks(String userId) async {
    // 1. Get all active tasks that have expired
    final overdueTasks = await _taskRepository.getOverdueTasks(userId);
    int count = 0;

    // 2. Mark expired tasks as skipped
    for (final task in overdueTasks) {
      if (task.status == TaskStatus.active && task.isExpired) {
        await _taskRepository.skipTask(
          taskId: task.id,
          reason: 'Task expired automatically',
        );
        count++;
      }
    }

    return count;
  }

  /// Start periodic refresh (background service)
  void startPeriodicRefresh({
    required String userId,
    Duration interval = const Duration(hours: 1),
    Function(RefreshResult)? onRefresh,
  }) {
    stopPeriodicRefresh();

    _periodicTimer = Timer.periodic(interval, (timer) async {
      final result = await refreshAllTasks(userId);
      onRefresh?.call(result);
    });

    // Immediately refresh on start
    refreshAllTasks(userId).then((result) {
      onRefresh?.call(result);
    });
  }

  /// Stop periodic refresh
  void stopPeriodicRefresh() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Refresh tasks at specific times (e.g., midnight for daily tasks)
  Future<void> scheduleRefreshAt(List<DateTime> times, String userId) async {
    for (final time in times) {
      final now = DateTime.now();
      if (time.isAfter(now)) {
        final duration = time.difference(now);
        Timer(duration, () async {
          await refreshAllTasks(userId);
        });
      }
    }
  }

  /// Refresh tasks on app resume
  Future<RefreshResult> refreshOnResume(String userId) async {
    AppLogger.i('refreshOnResume called for user: $userId', tag: 'TaskRefreshService');
    // Quick refresh focusing on immediate tasks
    final result = RefreshResult();

    try {
      // Only handle tasks in current window
      AppLogger.d('Getting tasks in current window...', tag: 'TaskRefreshService');
      final currentWindowTasks = await _taskRepository.getTasksInCurrentWindow(userId);
      AppLogger.d('Found ${currentWindowTasks.length} tasks in current window', tag: 'TaskRefreshService');

      // Check for expired tasks
      int expiredCount = 0;
      for (final task in currentWindowTasks) {
        if (task.status == TaskStatus.active && task.isExpired) {
          AppLogger.d('Marking task as expired: ${task.name}', tag: 'TaskRefreshService');
          await _taskRepository.skipTask(
            taskId: task.id,
            reason: 'Task expired while app was in background',
          );
          expiredCount++;
        }
      }
      result.expiredCount = expiredCount;
      AppLogger.i('Marked $expiredCount tasks as expired', tag: 'TaskRefreshService');

      // Generate only immediate tasks
      AppLogger.d('Getting active plans...', tag: 'TaskRefreshService');
      final plans = await _planRepository.getActivePlans(userId);
      AppLogger.i('Found ${plans.length} active plans', tag: 'TaskRefreshService');
      final newTasks = <TaskModel>[];

      for (final plan in plans) {
        AppLogger.d('Checking plan: ${plan.name} (id: ${plan.id})', tag: 'TaskRefreshService');
        // Check if plan needs immediate task
        final activeTask = await _taskRepository.getActivePlanTask(plan.id);
        if (activeTask == null) {
          AppLogger.d('Plan has no active task, generating...', tag: 'TaskRefreshService');
          final task = await _generationService.generateNextTask(plan);
          if (task != null) {
            newTasks.add(task);
          }
        } else if (activeTask.isExpired) {
          AppLogger.d('Plan has expired task, generating new one...', tag: 'TaskRefreshService');
          final task = await _generationService.generateNextTask(plan);
          if (task != null) {
            newTasks.add(task);
          }
        } else {
          AppLogger.d('Plan already has active task: ${activeTask.name}', tag: 'TaskRefreshService');
        }
      }

      result.generatedCount = newTasks.length;
      result.newTasks = newTasks;
      result.success = true;
      result.lastRefreshTime = DateTime.now();
      AppLogger.i('Resume refresh completed: ${newTasks.length} new tasks, $expiredCount expired', tag: 'TaskRefreshService');
    } catch (e) {
      AppLogger.e('Error during resume refresh', tag: 'TaskRefreshService', error: e);
      result.success = false;
      result.error = e.toString();
    }

    return result;
  }

  /// Force refresh for specific plan
  Future<TaskModel?> refreshPlanTasks(String planId) async {
    final plan = await _planRepository.getPlanById(planId);
    if (plan == null || !plan.isActive) return null;

    // Check and generate task if needed
    final activeTask = await _taskRepository.getActivePlanTask(planId);
    if (activeTask == null || activeTask.isExpired) {
      return await _generationService.generateNextTask(plan);
    }

    return activeTask;
  }

  /// Clean up completed tasks older than specified days
  Future<int> cleanupOldTasks({
    required String userId,
    int daysOld = 30,
  }) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    final oldTasks = await _taskRepository.getTasksByDateRange(
      userId,
      DateTime(2000), // Very old date
      cutoffDate,
    );

    int cleanedCount = 0;
    for (final task in oldTasks) {
      if (task.status == TaskStatus.completed || task.status == TaskStatus.skipped) {
        // Note: Tasks cannot be deleted per business rules
        // This is just for counting, actual cleanup would be handled differently
        cleanedCount++;
      }
    }

    return cleanedCount;
  }

  /// Dispose resources
  void dispose() {
    stopPeriodicRefresh();
  }
}