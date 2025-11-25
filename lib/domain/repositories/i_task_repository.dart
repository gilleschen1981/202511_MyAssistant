import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';

/// Task repository interface
/// Note: Tasks are never physically deleted, only soft deleted when plan is deleted
abstract class ITaskRepository {
  /// Create a new task (system generated only)
  Future<TaskModel> createTask({
    required String userId,
    required String planId,
    required String name,
    String? description,
    required TaskConfiguration config,
    required DateTime windowStartTime,
    required DateTime windowEndTime,
  });

  /// Get task by ID
  Future<TaskModel?> getTaskById(String taskId);

  /// Get all tasks for user
  Future<List<TaskModel>> getUserTasks(String userId);

  /// Get tasks for plan
  Future<List<TaskModel>> getPlanTasks(String planId);

  /// Get active tasks for user
  Future<List<TaskModel>> getActiveTasks(String userId);

  /// Get tasks in current window
  Future<List<TaskModel>> getTasksInCurrentWindow(String userId);

  /// Get tasks by status
  Future<List<TaskModel>> getTasksByStatus(String userId, TaskStatus status);

  /// Get tasks by date range
  Future<List<TaskModel>> getTasksByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  );

  /// Get today's tasks
  Future<List<TaskModel>> getTodayTasks(String userId);

  /// Get upcoming tasks
  Future<List<TaskModel>> getUpcomingTasks(String userId, {int days = 7});

  /// Get overdue tasks
  Future<List<TaskModel>> getOverdueTasks(String userId);

  /// Complete task
  Future<TaskModel> completeTask({
    required String taskId,
    int? actualDurationMinutes,
    String? evaluationResult,
    String? executionNote,
  });

  /// Skip task
  Future<TaskModel> skipTask({
    required String taskId,
    String? reason,
  });

  /// Update task progress (for counter tasks)
  Future<TaskModel> updateTaskProgress(
    String taskId,
    int currentCount, {
    int? actualDurationMinutes,
    String? evaluationResult,
  });

  /// Get task statistics
  Future<Map<String, dynamic>> getTaskStatistics(String userId);

  /// Get daily task statistics
  Future<Map<String, dynamic>> getDailyTaskStatistics(
    String userId,
    DateTime date,
  );

  /// Get task completion rate
  Future<double> getTaskCompletionRate(String userId, {int days = 30});

  /// Get active task for plan (only one active task per plan)
  Future<TaskModel?> getActivePlanTask(String planId);

  /// Batch create tasks for multiple plans
  Future<List<TaskModel>> batchCreateTasks(List<TaskModel> tasks);

  /// Search tasks
  Future<List<TaskModel>> searchTasks(String userId, String query);

  /// Get task history entries
  Future<List<Map<String, dynamic>>> getTaskHistory(String taskId);

  /// Add task history entry
  Future<bool> addTaskHistoryEntry({
    required String taskId,
    required String userId,
    required String action,
    String? oldStatus,
    String? newStatus,
    Map<String, dynamic>? metadata,
  });

  /// Soft delete task (only when plan is deleted)
  /// This marks the task as deleted but preserves it in the database
  Future<bool> deleteTask(String taskId);

  /// Soft delete all tasks for a plan (only when plan is deleted)
  Future<bool> deletePlanTasks(String planId);
}