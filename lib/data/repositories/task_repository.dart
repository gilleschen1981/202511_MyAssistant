import 'package:uuid/uuid.dart';
import 'package:myassistant/data/data_sources/local/dao/task_dao.dart';
import 'package:myassistant/data/data_sources/local/dao/plan_dao.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/core/utils/app_logger.dart';

/// Task repository implementation
/// Note: Tasks cannot be deleted as per business rules
class TaskRepository implements ITaskRepository {
  final TaskDao _taskDao;
  final PlanDao _planDao;
  final _uuid = const Uuid();

  TaskRepository({
    TaskDao? taskDao,
    PlanDao? planDao,
  })  : _taskDao = taskDao ?? TaskDao(),
        _planDao = planDao ?? PlanDao();

  @override
  Future<TaskModel> createTask({
    required String userId,
    required String planId,
    required String name,
    String? description,
    required TaskConfiguration config,
    required DateTime windowStartTime,
    required DateTime windowEndTime,
  }) async {
    // Validate plan exists
    final plan = await _planDao.getPlanById(planId);
    if (plan == null) {
      throw Exception('Plan not found');
    }

    // Validate window times
    if (windowEndTime.isBefore(windowStartTime)) {
      throw Exception('Window end time must be after start time');
    }

    // Validate task configuration
    if (!config.isValid) {
      throw Exception('Invalid task configuration');
    }

    // Check if there's already an active task for this plan
    // Only one active task is allowed per plan, regardless of window
    final activeTask = await _taskDao.getActivePlanTask(planId);
    if (activeTask != null) {
      throw Exception('该计划已有活跃任务，请先完成或跳过当前任务');
    }

    final now = DateTime.now();
    final task = TaskModel(
      id: _uuid.v4(),
      userId: userId,
      planId: planId,
      name: name,
      description: description,
      config: config,
      windowStartTime: windowStartTime,
      windowEndTime: windowEndTime,
      status: TaskStatus.active,
      createdAt: now,
    );

    return await _taskDao.insertTask(task);
  }

  @override
  Future<TaskModel?> getTaskById(String taskId) async {
    return await _taskDao.getTaskById(taskId);
  }

  @override
  Future<List<TaskModel>> getUserTasks(String userId) async {
    return await _taskDao.getUserTasks(userId);
  }

  @override
  Future<List<TaskModel>> getPlanTasks(String planId) async {
    return await _taskDao.getPlanTasks(planId);
  }

  @override
  Future<List<TaskModel>> getActiveTasks(String userId) async {
    return await _taskDao.getActiveTasks(userId);
  }

  @override
  Future<List<TaskModel>> getTasksInCurrentWindow(String userId) async {
    return await _taskDao.getTasksInCurrentWindow(userId);
  }

  @override
  Future<List<TaskModel>> getTasksByStatus(String userId, TaskStatus status) async {
    return await _taskDao.getTasksByStatus(userId, status);
  }

  @override
  Future<List<TaskModel>> getTasksByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _taskDao.getTasksByDateRange(userId, startDate, endDate);
  }

  @override
  Future<List<TaskModel>> getTodayTasks(String userId) async {
    return await _taskDao.getTodayTasks(userId);
  }

  @override
  Future<List<TaskModel>> getUpcomingTasks(String userId, {int days = 7}) async {
    return await _taskDao.getUpcomingTasks(userId, days: days);
  }

  @override
  Future<List<TaskModel>> getOverdueTasks(String userId) async {
    return await _taskDao.getOverdueTasks(userId);
  }

  @override
  Future<TaskModel> completeTask({
    required String taskId,
    int? actualDurationMinutes,
    String? evaluationResult,
    String? executionNote,
  }) async {
    final task = await _taskDao.getTaskById(taskId);
    if (task == null) {
      throw Exception('Task not found');
    }

    // Validate task can be completed
    if (task.status != TaskStatus.active) {
      throw Exception('Only active tasks can be completed');
    }

    // Validate timer task duration
    if (task.config.durationMinutes != null && actualDurationMinutes == null) {
      throw Exception('Timer task requires actual duration');
    }

    // Validate evaluation task result
    if (task.config.evaluationOptions != null && evaluationResult == null) {
      throw Exception('Evaluation task requires evaluation result');
    }

    final result = await _taskDao.completeTask(
      taskId: taskId,
      actualDurationMinutes: actualDurationMinutes,
      evaluationResult: evaluationResult,
      executionNote: executionNote,
    );

    if (result == null) {
      throw Exception('Failed to complete task');
    }

    return result;
  }

  @override
  Future<TaskModel> skipTask({
    required String taskId,
    String? reason,
  }) async {
    final task = await _taskDao.getTaskById(taskId);
    if (task == null) {
      throw Exception('Task not found');
    }

    // Validate task can be skipped
    if (task.status != TaskStatus.active) {
      throw Exception('Only active tasks can be skipped');
    }

    final result = await _taskDao.skipTask(
      taskId: taskId,
      reason: reason,
    );

    if (result == null) {
      throw Exception('Failed to skip task');
    }

    return result;
  }

  @override
  Future<TaskModel> updateTaskProgress(
    String taskId,
    int currentCount, {
    int? actualDurationMinutes,
    String? evaluationResult,
  }) async {
    final task = await _taskDao.getTaskById(taskId);
    if (task == null) {
      throw Exception('Task not found');
    }

    // Validate this is a counter task
    if (task.config.repeatCount == null) {
      throw Exception('This is not a counter task');
    }

    // Validate task is active
    if (task.status != TaskStatus.active) {
      throw Exception('Only active tasks can be updated');
    }

    final result = await _taskDao.updateTaskProgress(taskId, currentCount);
    if (result == null) {
      throw Exception('Failed to update task progress');
    }

    // Auto-complete if reached target
    if (currentCount >= task.config.repeatCount!) {
      return await completeTask(
        taskId: taskId,
        actualDurationMinutes: actualDurationMinutes,
        evaluationResult: evaluationResult,
        executionNote: 'Auto-completed after reaching target count',
      );
    }

    return result;
  }

  @override
  Future<TaskModel> updateTaskStatus({
    required String taskId,
    required TaskStatus status,
    bool clearExecutionData = false,
    bool clearSkipData = false,
    bool clearDeletedAt = false,
  }) async {
    final result = await _taskDao.updateTaskStatus(
      taskId,
      status,
      clearExecutionData: clearExecutionData,
      clearSkipData: clearSkipData,
      clearDeletedAt: clearDeletedAt,
    );

    if (result == null) {
      throw Exception('Failed to update task status');
    }

    return result;
  }

  @override
  Future<Map<String, dynamic>> getTaskStatistics(String userId) async {
    return await _taskDao.getTaskStatistics(userId);
  }

  @override
  Future<Map<String, dynamic>> getDailyTaskStatistics(
    String userId,
    DateTime date,
  ) async {
    return await _taskDao.getDailyTaskStatistics(userId, date);
  }

  @override
  Future<double> getTaskCompletionRate(String userId, {int days = 30}) async {
    return await _taskDao.getTaskCompletionRate(userId, days: days);
  }

  @override
  Future<TaskModel?> getActivePlanTask(String planId) async {
    return await _taskDao.getActivePlanTask(planId);
  }

  @override
  Future<List<TaskModel>> batchCreateTasks(List<TaskModel> tasks) async {
    if (tasks.isEmpty) return [];

    // Validate all tasks
    for (final task in tasks) {
      if (!task.config.isValid) {
        throw Exception('Invalid task configuration for task: ${task.name}');
      }

      if (task.windowEndTime.isBefore(task.windowStartTime)) {
        throw Exception('Invalid window times for task: ${task.name}');
      }
    }

    return await _taskDao.batchCreateTasks(tasks);
  }

  @override
  Future<List<TaskModel>> searchTasks(String userId, String query) async {
    if (query.isEmpty) {
      return await getUserTasks(userId);
    }
    return await _taskDao.searchTasks(userId, query);
  }

  @override
  Future<List<Map<String, dynamic>>> getTaskHistory(String taskId) async {
    return await _taskDao.getTaskHistory(taskId);
  }

  @override
  Future<bool> addTaskHistoryEntry({
    required String taskId,
    required String userId,
    required String action,
    String? oldStatus,
    String? newStatus,
    Map<String, dynamic>? metadata,
  }) async {
    // This is handled internally by TaskDao
    // Exposed here for special cases or manual tracking
    return true;
  }

  @override
  Future<bool> deleteTask(String taskId) async {
    AppLogger.d('deleteTask called with taskId: $taskId', tag: 'TaskRepository');
    final result = await _taskDao.deleteTask(taskId);
    AppLogger.d('Task delete result (rows affected): $result', tag: 'TaskRepository');
    return result > 0;
  }

  @override
  Future<bool> deletePlanTasks(String planId) async {
    AppLogger.d('deletePlanTasks called with planId: $planId', tag: 'TaskRepository');
    final tasks = await _taskDao.getPlanTasks(planId);
    AppLogger.d('Found ${tasks.length} tasks to delete for plan', tag: 'TaskRepository');

    int deletedCount = 0;
    for (final task in tasks) {
      final result = await _taskDao.deleteTask(task.id);
      if (result > 0) deletedCount++;
    }

    AppLogger.i('Successfully deleted $deletedCount tasks', tag: 'TaskRepository');
    return deletedCount == tasks.length;
  }
}