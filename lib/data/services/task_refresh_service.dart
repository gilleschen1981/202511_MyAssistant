import 'dart:async';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/services/task_generation_service.dart';
import 'package:myassistant/data/services/notification_service.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';

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
  final NotificationService _notificationService;

  Timer? _periodicTimer;

  TaskRefreshService({
    required ITaskRepository taskRepository,
    required IPlanRepository planRepository,
    required TaskGenerationService generationService,
    required NotificationService notificationService,
  })  : _taskRepository = taskRepository,
        _planRepository = planRepository,
        _generationService = generationService,
        _notificationService = notificationService;

  /// Refresh all tasks for a user
  Future<RefreshResult> refreshAllTasks(String userId) async {
    final result = RefreshResult();

    try {
      // 1. Handle expired tasks
      result.expiredCount = await _handleExpiredTasks(userId);

      // 2. Generate new tasks
      final newTasks = await _generationService.generateAllPendingTasks(userId);
      result.generatedCount = newTasks.length;
      result.newTasks = newTasks;

      // 3. Send notifications for new tasks
      if (newTasks.isNotEmpty) {
        await _notificationService.notifyNewTasks(newTasks);
      }

      result.success = true;
      result.lastRefreshTime = DateTime.now();
    } catch (e) {
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
    // Quick refresh focusing on immediate tasks
    final result = RefreshResult();

    try {
      // Only handle tasks in current window
      final currentWindowTasks = await _taskRepository.getTasksInCurrentWindow(userId);

      // Check for expired tasks
      int expiredCount = 0;
      for (final task in currentWindowTasks) {
        if (task.status == TaskStatus.active && task.isExpired) {
          await _taskRepository.skipTask(
            taskId: task.id,
            reason: 'Task expired while app was in background',
          );
          expiredCount++;
        }
      }
      result.expiredCount = expiredCount;

      // Generate only immediate tasks
      final plans = await _planRepository.getActivePlans(userId);
      final newTasks = <TaskModel>[];

      for (final plan in plans) {
        // Check if plan needs immediate task
        final activeTask = await _taskRepository.getActivePlanTask(plan.id);
        if (activeTask == null || activeTask.isExpired) {
          final task = await _generationService.generateNextTask(plan);
          if (task != null) {
            newTasks.add(task);
          }
        }
      }

      result.generatedCount = newTasks.length;
      result.newTasks = newTasks;
      result.success = true;
      result.lastRefreshTime = DateTime.now();

      // Send notifications
      if (newTasks.isNotEmpty) {
        await _notificationService.notifyNewTasks(newTasks);
      }
    } catch (e) {
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