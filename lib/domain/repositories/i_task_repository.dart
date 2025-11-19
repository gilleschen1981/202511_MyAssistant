import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';

/// Task repository interface
/// Note: Tasks cannot be deleted as per business rules
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

  /// Create a repeat execution of an existing task
  /// Used when user wants to re-execute a completed task
  Future<TaskModel> createRepeatExecution(String originalTaskId);

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
  Future<TaskModel> updateTaskProgress(String taskId, int currentCount);

  /// Get task execution history
  Future<List<TaskModel>> getTaskExecutionHistory(String originalTaskId);

  /// Get task statistics
  Future<Map<String, dynamic>> getTaskStatistics(String userId);

  /// Get daily task statistics
  Future<Map<String, dynamic>> getDailyTaskStatistics(
    String userId,
    DateTime date,
  );

  /// Get task completion rate
  Future<double> getTaskCompletionRate(String userId, {int days = 30});

  /// Check if task can be repeated
  Future<bool> canRepeatTask(String taskId);

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
}