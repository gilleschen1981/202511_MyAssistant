import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:myassistant/data/data_sources/local/database/app_database.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';

/// Task Data Access Object
/// Note: Tasks cannot be deleted as per business rules
class TaskDao {
  static const String _tableTasks = 'tasks';
  static const String _tableTaskHistory = 'task_history';

  final AppDatabase _database = AppDatabase.instance;

  /// Insert task (system generated only)
  Future<TaskModel> insertTask(TaskModel task) async {
    final db = await _database.database;
    final taskMap = <String, dynamic>{
      'id': task.id,
      'user_id': task.userId,
      'plan_id': task.planId,
      'name': task.name,
      'description': task.description,
      'config': jsonEncode(task.config.toJson()),
      'window_start_time': AppDatabase.dateTimeToTimestamp(task.windowStartTime),
      'window_end_time': AppDatabase.dateTimeToTimestamp(task.windowEndTime),
      'status': task.status.toDbString(),
      'current_count': task.currentCount,
      'completed_at': task.completedAt != null
          ? AppDatabase.dateTimeToTimestamp(task.completedAt!)
          : null,
      'skipped_at': task.skippedAt != null
          ? AppDatabase.dateTimeToTimestamp(task.skippedAt!)
          : null,
      'actual_duration_minutes': task.actualDurationMinutes,
      'evaluation_result': task.evaluationResult,
      'execution_note': task.executionNote,
      'created_at': AppDatabase.dateTimeToTimestamp(task.createdAt),
    };

    await db.insert(
      _tableTasks,
      taskMap,
      conflictAlgorithm: ConflictAlgorithm.fail,
    );

    // Add history entry for creation
    await _addHistoryEntry(
      taskId: task.id,
      userId: task.userId,
      action: 'created',
      newStatus: task.status.toDbString(),
    );

    return task;
  }

  // Note: Repeat execution is no longer supported in v4.0
  // Each task is now an independent entity
  // To "repeat" a task, create a new independent task with the same configuration

  /// Get task by ID
  Future<TaskModel?> getTaskById(String taskId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableTasks,
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return _mapToTask(maps.first);
  }

  /// Get all tasks for user
  Future<List<TaskModel>> getUserTasks(String userId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableTasks,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'window_start_time DESC',
    );

    return maps.map(_mapToTask).toList();
  }

  /// Get tasks for plan
  Future<List<TaskModel>> getPlanTasks(String planId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableTasks,
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'window_start_time DESC',
    );

    return maps.map(_mapToTask).toList();
  }

  /// Get active tasks for user
  Future<List<TaskModel>> getActiveTasks(String userId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableTasks,
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'active'],
      orderBy: 'window_start_time ASC',
    );

    return maps.map(_mapToTask).toList();
  }

  /// Get tasks in current window
  Future<List<TaskModel>> getTasksInCurrentWindow(String userId) async {
    final db = await _database.database;
    final now = AppDatabase.getCurrentTimestamp();

    final List<Map<String, dynamic>> maps = await db.query(
      _tableTasks,
      where: 'user_id = ? AND window_start_time <= ? AND window_end_time >= ?',
      whereArgs: [userId, now, now],
      orderBy: 'window_start_time ASC',
    );

    return maps.map(_mapToTask).toList();
  }

  /// Get tasks by status
  Future<List<TaskModel>> getTasksByStatus(String userId, TaskStatus status) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableTasks,
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, status.toDbString()],
      orderBy: 'window_start_time DESC',
    );

    return maps.map(_mapToTask).toList();
  }

  /// Get tasks by date range
  Future<List<TaskModel>> getTasksByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _database.database;
    final startTimestamp = AppDatabase.dateTimeToTimestamp(startDate);
    final endTimestamp = AppDatabase.dateTimeToTimestamp(endDate);

    final List<Map<String, dynamic>> maps = await db.query(
      _tableTasks,
      where: '''user_id = ? AND
                ((window_start_time BETWEEN ? AND ?) OR
                 (window_end_time BETWEEN ? AND ?) OR
                 (window_start_time <= ? AND window_end_time >= ?))''',
      whereArgs: [
        userId,
        startTimestamp,
        endTimestamp,
        startTimestamp,
        endTimestamp,
        startTimestamp,
        endTimestamp,
      ],
      orderBy: 'window_start_time ASC',
    );

    return maps.map(_mapToTask).toList();
  }

  /// Get today's tasks
  Future<List<TaskModel>> getTodayTasks(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getTasksByDateRange(userId, startOfDay, endOfDay);
  }

  /// Get upcoming tasks
  Future<List<TaskModel>> getUpcomingTasks(String userId, {int days = 7}) async {
    final now = DateTime.now();
    final future = now.add(Duration(days: days));

    return getTasksByDateRange(userId, now, future);
  }

  /// Get overdue tasks
  Future<List<TaskModel>> getOverdueTasks(String userId) async {
    final db = await _database.database;
    final now = AppDatabase.getCurrentTimestamp();

    final List<Map<String, dynamic>> maps = await db.query(
      _tableTasks,
      where: 'user_id = ? AND status = ? AND window_end_time < ?',
      whereArgs: [userId, 'active', now],
      orderBy: 'window_end_time DESC',
    );

    return maps.map(_mapToTask).toList();
  }

  /// Complete task
  Future<TaskModel?> completeTask({
    required String taskId,
    int? actualDurationMinutes,
    String? evaluationResult,
    String? executionNote,
  }) async {
    final db = await _database.database;
    final task = await getTaskById(taskId);
    if (task == null) return null;

    final now = AppDatabase.getCurrentTimestamp();

    final updatedTask = task.copyWith(
      status: TaskStatus.completed,
      completedAt: AppDatabase.timestampToDateTime(now),
      actualDurationMinutes: actualDurationMinutes ?? task.actualDurationMinutes,
      evaluationResult: evaluationResult ?? task.evaluationResult,
      executionNote: executionNote ?? task.executionNote,
    );

    await db.update(
      _tableTasks,
      {
        'status': 'completed',
        'completed_at': now,
        'actual_duration_minutes': actualDurationMinutes,
        'evaluation_result': evaluationResult,
        'execution_note': executionNote,
        'current_count': task.config.repeatCount, // Set to max if counter task
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );

    // Triggers will update plan statistics automatically

    return updatedTask;
  }

  /// Skip task
  Future<TaskModel?> skipTask({
    required String taskId,
    String? reason,
  }) async {
    final db = await _database.database;
    final task = await getTaskById(taskId);
    if (task == null) return null;

    final now = AppDatabase.getCurrentTimestamp();

    final updatedTask = task.copyWith(
      status: TaskStatus.skipped,
      skippedAt: AppDatabase.timestampToDateTime(now),
      executionNote: reason,
    );

    await db.update(
      _tableTasks,
      {
        'status': 'skipped',
        'skipped_at': now,
        'execution_note': reason,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );

    // Triggers will update plan statistics automatically

    return updatedTask;
  }

  /// Soft delete task (sets status='deleted')
  Future<int> deleteTask(String taskId) async {
    final db = await _database.database;
    final timestamp = AppDatabase.getCurrentTimestamp();
    return await db.update(
      _tableTasks,
      {
        'status': 'deleted',
        'deleted_at': timestamp,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// Update task progress (for counter tasks)
  Future<TaskModel?> updateTaskProgress(String taskId, int currentCount) async {
    final db = await _database.database;
    final task = await getTaskById(taskId);
    if (task == null) return null;

    // Check if this is a counter task
    if (task.config.repeatCount == null) return task;

    // Clamp the count
    final maxCount = task.config.repeatCount!;
    final newCount = currentCount.clamp(0, maxCount);

    await db.update(
      _tableTasks,
      {'current_count': newCount},
      where: 'id = ?',
      whereArgs: [taskId],
    );

    return task.copyWith(currentCount: newCount);
  }

  /// Update task status (for undo operations)
  /// Can optionally clear execution data or skip data when reverting
  Future<TaskModel?> updateTaskStatus(
    String taskId,
    TaskStatus newStatus, {
    bool clearExecutionData = false,
    bool clearSkipData = false,
    bool clearDeletedAt = false,
  }) async {
    final db = await _database.database;
    final task = await getTaskById(taskId);
    if (task == null) return null;

    // Build update map
    final Map<String, dynamic> updates = {
      'status': newStatus.toDbString(),
    };

    // Clear execution data if requested (for reverting complete)
    if (clearExecutionData) {
      updates['actual_duration_minutes'] = null;
      updates['evaluation_result'] = null;
      updates['execution_note'] = null;
      updates['completed_at'] = null;
    }

    // Clear skip data if requested (for reverting skip)
    if (clearSkipData) {
      updates['execution_note'] = null;  // Skip reason is stored in execution_note
      updates['skipped_at'] = null;
    }

    // Clear deleted_at if requested (for restoring deleted tasks)
    if (clearDeletedAt) {
      updates['deleted_at'] = null;
      updates['execution_note'] = null;  // Clear pause reason
    }

    await db.update(
      _tableTasks,
      updates,
      where: 'id = ?',
      whereArgs: [taskId],
    );

    // Return updated task
    return task.copyWith(
      status: newStatus,
      actualDurationMinutes: clearExecutionData ? null : task.actualDurationMinutes,
      evaluationResult: clearExecutionData ? null : task.evaluationResult,
      executionNote: (clearExecutionData || clearSkipData || clearDeletedAt) ? null : task.executionNote,
      completedAt: clearExecutionData ? null : task.completedAt,
      skippedAt: clearSkipData ? null : task.skippedAt,
      deletedAt: clearDeletedAt ? null : task.deletedAt,
    );
  }

  /// Get task statistics
  Future<Map<String, dynamic>> getTaskStatistics(String userId) async {
    final db = await _database.database;

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as total_tasks,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_tasks,
        SUM(CASE WHEN status = 'skipped' THEN 1 ELSE 0 END) as skipped_tasks,
        SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active_tasks,
        AVG(CASE WHEN status = 'completed' AND actual_duration_minutes IS NOT NULL
                 THEN actual_duration_minutes ELSE NULL END) as avg_duration
      FROM $_tableTasks
      WHERE user_id = ?
    ''', [userId]);

    if (result.isEmpty) {
      return {
        'totalTasks': 0,
        'completedTasks': 0,
        'skippedTasks': 0,
        'activeTasks': 0,
        'avgDuration': 0.0,
      };
    }

    return {
      'totalTasks': result.first['total_tasks'] ?? 0,
      'completedTasks': result.first['completed_tasks'] ?? 0,
      'skippedTasks': result.first['skipped_tasks'] ?? 0,
      'activeTasks': result.first['active_tasks'] ?? 0,
      'avgDuration': result.first['avg_duration'] ?? 0.0,
    };
  }

  /// Get daily task statistics
  Future<Map<String, dynamic>> getDailyTaskStatistics(
    String userId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final tasks = await getTasksByDateRange(userId, startOfDay, endOfDay);

    int completed = 0;
    int skipped = 0;
    int active = 0;
    double totalDuration = 0;
    int durationCount = 0;

    for (final task in tasks) {
      switch (task.status) {
        case TaskStatus.completed:
          completed++;
          if (task.actualDurationMinutes != null) {
            totalDuration += task.actualDurationMinutes!;
            durationCount++;
          }
          break;
        case TaskStatus.skipped:
          skipped++;
          break;
        case TaskStatus.active:
          active++;
          break;
        case TaskStatus.deleted:
          // Skip deleted tasks in statistics
          break;
      }
    }

    return {
      'date': date.toIso8601String(),
      'totalTasks': tasks.length,
      'completedTasks': completed,
      'skippedTasks': skipped,
      'activeTasks': active,
      'avgDuration': durationCount > 0 ? totalDuration / durationCount : 0.0,
      'completionRate': tasks.isNotEmpty ? completed / tasks.length : 0.0,
    };
  }

  /// Get task completion rate
  Future<double> getTaskCompletionRate(String userId, {int days = 30}) async {
    final db = await _database.database;
    final now = AppDatabase.getCurrentTimestamp();
    final past = now - (days * 24 * 60 * 60);

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed
      FROM $_tableTasks
      WHERE user_id = ? AND window_start_time >= ?
    ''', [userId, past]);

    if (result.isEmpty) return 0.0;

    final total = result.first['total'] as int? ?? 0;
    final completed = result.first['completed'] as int? ?? 0;

    if (total == 0) return 0.0;
    return completed / total;
  }


  /// Get active task for plan (only one active task per plan)
  Future<TaskModel?> getActivePlanTask(String planId) async {
    final db = await _database.database;
    final now = AppDatabase.getCurrentTimestamp();

    final List<Map<String, dynamic>> maps = await db.query(
      _tableTasks,
      where: 'plan_id = ? AND status = ? AND window_end_time >= ?',
      whereArgs: [planId, 'active', now],
      orderBy: 'window_start_time DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return _mapToTask(maps.first);
  }

  /// Batch create tasks
  Future<List<TaskModel>> batchCreateTasks(List<TaskModel> tasks) async {
    final db = await _database.database;
    final batch = db.batch();

    for (final task in tasks) {
      final taskMap = <String, dynamic>{
        'id': task.id,
        'user_id': task.userId,
        'plan_id': task.planId,
        'name': task.name,
        'description': task.description,
        'config': jsonEncode(task.config.toJson()),
        'window_start_time': AppDatabase.dateTimeToTimestamp(task.windowStartTime),
        'window_end_time': AppDatabase.dateTimeToTimestamp(task.windowEndTime),
        'status': task.status.toDbString(),
        'current_count': task.currentCount,
        'created_at': AppDatabase.dateTimeToTimestamp(task.createdAt),
      };

      batch.insert(_tableTasks, taskMap);

      // Add history entry
      batch.insert(_tableTaskHistory, {
        'task_id': task.id,
        'user_id': task.userId,
        'action': 'created',
        'new_status': task.status.toDbString(),
        'created_at': AppDatabase.dateTimeToTimestamp(task.createdAt),
      });
    }

    await batch.commit(noResult: true);
    return tasks;
  }

  /// Search tasks
  Future<List<TaskModel>> searchTasks(String userId, String query) async {
    final db = await _database.database;
    final searchQuery = '%$query%';

    final List<Map<String, dynamic>> maps = await db.query(
      _tableTasks,
      where: 'user_id = ? AND (name LIKE ? OR description LIKE ?)',
      whereArgs: [userId, searchQuery, searchQuery],
      orderBy: 'window_start_time DESC',
    );

    return maps.map(_mapToTask).toList();
  }

  /// Get task history entries
  Future<List<Map<String, dynamic>>> getTaskHistory(String taskId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableTaskHistory,
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'created_at DESC',
    );

    return maps.map((map) {
      return {
        'id': map['id'],
        'taskId': map['task_id'],
        'userId': map['user_id'],
        'action': map['action'],
        'oldStatus': map['old_status'],
        'newStatus': map['new_status'],
        'metadata': map['metadata'] != null
            ? jsonDecode(map['metadata'] as String)
            : null,
        'createdAt': AppDatabase.timestampToDateTime(_toInt(map['created_at'])),
      };
    }).toList();
  }

  /// Add task history entry
  Future<void> _addHistoryEntry({
    required String taskId,
    required String userId,
    required String action,
    String? oldStatus,
    String? newStatus,
    Map<String, dynamic>? metadata,
  }) async {
    final db = await _database.database;
    await db.insert(
      _tableTaskHistory,
      {
        'task_id': taskId,
        'user_id': userId,
        'action': action,
        'old_status': oldStatus,
        'new_status': newStatus,
        'metadata': metadata != null ? jsonEncode(metadata) : null,
        'created_at': AppDatabase.getCurrentTimestamp(),
      },
    );
  }

  /// Convert map to TaskModel
  TaskModel _mapToTask(Map<String, dynamic> map) {
    // Parse task configuration
    final taskConfigJson = jsonDecode(map['config'] as String);
    final taskConfig = TaskConfiguration.fromJson(taskConfigJson);

    return TaskModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      planId: map['plan_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      config: taskConfig,
      windowStartTime: AppDatabase.timestampToDateTime(_toInt(map['window_start_time'])),
      windowEndTime: AppDatabase.timestampToDateTime(_toInt(map['window_end_time'])),
      status: TaskStatus.fromString(map['status'] as String),
      currentCount: map['current_count'] != null ? _toInt(map['current_count']) : 0,
      completedAt: map['completed_at'] != null
          ? AppDatabase.timestampToDateTime(_toInt(map['completed_at']))
          : null,
      skippedAt: map['skipped_at'] != null
          ? AppDatabase.timestampToDateTime(_toInt(map['skipped_at']))
          : null,
      actualDurationMinutes: map['actual_duration_minutes'] != null ? _toInt(map['actual_duration_minutes']) : null,
      evaluationResult: map['evaluation_result'] as String?,
      executionNote: map['execution_note'] as String?,
      createdAt: AppDatabase.timestampToDateTime(_toInt(map['created_at'])),
      deletedAt: map['deleted_at'] != null
          ? AppDatabase.timestampToDateTime(_toInt(map['deleted_at']))
          : null,
    );
  }

  /// Helper method to safely convert dynamic value to int
  /// Handles int, String (numeric), and ISO date strings from SQLite
  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    } else if (value is String) {
      // Check if it's an ISO date string (contains 'T' or looks like a date)
      if (value.contains('T') || value.contains('-')) {
        try {
          // Parse as ISO date and convert to Unix timestamp
          final dateTime = DateTime.parse(value);
          return dateTime.millisecondsSinceEpoch ~/ 1000;
        } catch (e) {
          // If parsing as date fails, try parsing as int
          return int.parse(value);
        }
      }
      // Regular numeric string
      return int.parse(value);
    } else {
      throw ArgumentError('Cannot convert $value to int');
    }
  }
}