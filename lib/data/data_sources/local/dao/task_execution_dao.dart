import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:myassistant/data/data_sources/local/database/app_database.dart';
import 'package:myassistant/data/models/task_execution_model.dart';
import 'package:uuid/uuid.dart';

/// Task Execution Data Access Object
/// Handles storing and retrieving task execution history
class TaskExecutionDao {
  static const String _tableTaskExecutions = 'task_executions';

  final AppDatabase _database = AppDatabase.instance;
  final _uuid = const Uuid();

  /// Insert a new task execution record
  Future<TaskExecutionModel> insertExecution(TaskExecutionModel execution) async {
    final db = await _database.database;
    final executionMap = <String, dynamic>{
      'id': execution.id,
      'task_id': execution.taskId,
      'user_id': execution.userId,
      'execution_type': execution.executionType,
      'started_at': AppDatabase.dateTimeToTimestamp(execution.startedAt),
      'completed_at': execution.completedAt != null
          ? AppDatabase.dateTimeToTimestamp(execution.completedAt!)
          : null,
      'duration_minutes': execution.durationMinutes,
      'counter_value': execution.counterValue,
      'evaluation_score': execution.evaluationScore,
      'notes': execution.notes,
      'execution_data': execution.executionData != null
          ? jsonEncode(execution.executionData)
          : null,
      'created_at': AppDatabase.dateTimeToTimestamp(execution.createdAt),
    };

    await db.insert(
      _tableTaskExecutions,
      executionMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return execution;
  }

  /// Create execution record from task completion
  Future<TaskExecutionModel> createFromTaskCompletion({
    required String taskId,
    required String userId,
    required String executionType,
    required DateTime startedAt,
    DateTime? completedAt,
    int? durationMinutes,
    int? counterValue,
    String? evaluationScore,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    final execution = TaskExecutionModel.fromTaskCompletion(
      id: _uuid.v4(),
      taskId: taskId,
      userId: userId,
      executionType: executionType,
      startedAt: startedAt,
      completedAt: completedAt,
      durationMinutes: durationMinutes,
      counterValue: counterValue,
      evaluationScore: evaluationScore,
      notes: notes,
      metadata: metadata,
    );

    return await insertExecution(execution);
  }

  /// Update an existing execution (e.g., to mark as completed)
  Future<void> updateExecution(TaskExecutionModel execution) async {
    final db = await _database.database;
    final executionMap = <String, dynamic>{
      'id': execution.id,
      'task_id': execution.taskId,
      'user_id': execution.userId,
      'execution_type': execution.executionType,
      'started_at': AppDatabase.dateTimeToTimestamp(execution.startedAt),
      'completed_at': execution.completedAt != null
          ? AppDatabase.dateTimeToTimestamp(execution.completedAt!)
          : null,
      'duration_minutes': execution.durationMinutes,
      'counter_value': execution.counterValue,
      'evaluation_score': execution.evaluationScore,
      'notes': execution.notes,
      'execution_data': execution.executionData != null
          ? jsonEncode(execution.executionData)
          : null,
      'created_at': AppDatabase.dateTimeToTimestamp(execution.createdAt),
    };

    await db.update(
      _tableTaskExecutions,
      executionMap,
      where: 'id = ?',
      whereArgs: [execution.id],
    );
  }

  /// Get execution by ID
  Future<TaskExecutionModel?> getExecutionById(String executionId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableTaskExecutions,
      where: 'id = ?',
      whereArgs: [executionId],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return _mapToExecution(maps.first);
  }

  /// Get all executions for a task
  Future<List<TaskExecutionModel>> getTaskExecutions(String taskId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableTaskExecutions,
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'started_at DESC',
    );

    return maps.map((map) => _mapToExecution(map)).toList();
  }

  /// Get all executions for a user
  Future<List<TaskExecutionModel>> getUserExecutions(String userId, {
    DateTime? startDate,
    DateTime? endDate,
    String? executionType,
    int? limit,
  }) async {
    final db = await _database.database;

    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (startDate != null) {
      whereClause += ' AND started_at >= ?';
      whereArgs.add(AppDatabase.dateTimeToTimestamp(startDate));
    }

    if (endDate != null) {
      whereClause += ' AND started_at <= ?';
      whereArgs.add(AppDatabase.dateTimeToTimestamp(endDate));
    }

    if (executionType != null) {
      whereClause += ' AND execution_type = ?';
      whereArgs.add(executionType);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      _tableTaskExecutions,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'started_at DESC',
      limit: limit,
    );

    return maps.map((map) => _mapToExecution(map)).toList();
  }

  /// Get execution statistics for a user
  Future<Map<String, dynamic>> getUserExecutionStats(String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _database.database;

    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (startDate != null) {
      whereClause += ' AND started_at >= ?';
      whereArgs.add(AppDatabase.dateTimeToTimestamp(startDate));
    }

    if (endDate != null) {
      whereClause += ' AND started_at <= ?';
      whereArgs.add(AppDatabase.dateTimeToTimestamp(endDate));
    }

    // Get total executions
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM $_tableTaskExecutions WHERE $whereClause',
      whereArgs,
    );

    // Get completed executions
    final completedResult = await db.rawQuery(
      'SELECT COUNT(*) as completed FROM $_tableTaskExecutions WHERE $whereClause AND completed_at IS NOT NULL',
      whereArgs,
    );

    // Get average duration for timer tasks
    final durationResult = await db.rawQuery(
      'SELECT AVG(duration_minutes) as avg_duration FROM $_tableTaskExecutions '
      'WHERE $whereClause AND duration_minutes IS NOT NULL',
      whereArgs,
    );

    // Get average counter value
    final counterResult = await db.rawQuery(
      'SELECT AVG(counter_value) as avg_counter FROM $_tableTaskExecutions '
      'WHERE $whereClause AND counter_value IS NOT NULL',
      whereArgs,
    );

    // Get average evaluation score
    final evaluationResult = await db.rawQuery(
      'SELECT AVG(CAST(evaluation_score AS REAL)) as avg_evaluation FROM $_tableTaskExecutions '
      'WHERE $whereClause AND evaluation_score IS NOT NULL',
      whereArgs,
    );

    return {
      'total_executions': totalResult.first['total'] ?? 0,
      'completed_executions': completedResult.first['completed'] ?? 0,
      'avg_duration_minutes': durationResult.first['avg_duration'],
      'avg_counter_value': counterResult.first['avg_counter'],
      'avg_evaluation_score': evaluationResult.first['avg_evaluation'],
    };
  }

  /// Delete all executions for a task (for cleanup purposes)
  Future<int> deleteTaskExecutions(String taskId) async {
    final db = await _database.database;
    return await db.delete(
      _tableTaskExecutions,
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }

  /// Delete executions older than a certain date (for data retention)
  Future<int> deleteOldExecutions(DateTime beforeDate) async {
    final db = await _database.database;
    return await db.delete(
      _tableTaskExecutions,
      where: 'created_at < ?',
      whereArgs: [AppDatabase.dateTimeToTimestamp(beforeDate)],
    );
  }

  /// Convert database map to TaskExecutionModel
  TaskExecutionModel _mapToExecution(Map<String, dynamic> map) {
    return TaskExecutionModel(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      userId: map['user_id'] as String,
      executionType: map['execution_type'] as String,
      startedAt: AppDatabase.timestampToDateTime(map['started_at'] as int),
      completedAt: map['completed_at'] != null
          ? AppDatabase.timestampToDateTime(map['completed_at'] as int)
          : null,
      durationMinutes: map['duration_minutes'] as int?,
      counterValue: map['counter_value'] as int?,
      evaluationScore: map['evaluation_score'] as String?,
      notes: map['notes'] as String?,
      executionData: map['execution_data'] != null
          ? jsonDecode(map['execution_data'] as String) as Map<String, dynamic>
          : null,
      createdAt: AppDatabase.timestampToDateTime(map['created_at'] as int),
    );
  }
}