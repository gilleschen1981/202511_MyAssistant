import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:myassistant/data/data_sources/local/database/app_database.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/core/utils/app_logger.dart';

/// Goal Data Access Object
class GoalDao {
  static const String _tableGoals = 'goals';
  static const String _tablePlans = 'plans';

  final AppDatabase _database = AppDatabase.instance;

  /// Insert goal
  Future<GoalModel> insertGoal(GoalModel goal) async {
    AppLogger.d('insertGoal called with goal: ${goal.toJson()}', tag: 'GoalDao');

    final db = await _database.database;
    final goalMap = goal.toJson();

    // Map field names to database columns
    goalMap['user_id'] = goalMap.remove('userId');
    goalMap['success_criteria'] = goalMap.remove('successCriteria');

    // Convert DateTime to timestamp
    goalMap['created_at'] = AppDatabase.dateTimeToTimestamp(goal.createdAt);
    goalMap['updated_at'] = AppDatabase.dateTimeToTimestamp(goal.updatedAt);
    if (goal.deadline != null) {
      goalMap['deadline'] = AppDatabase.dateTimeToTimestamp(goal.deadline!);
    }
    if (goal.deletedAt != null) {
      goalMap['deleted_at'] = AppDatabase.dateTimeToTimestamp(goal.deletedAt!);
    }

    // Convert enums
    goalMap['priority'] = goal.priority.toDbString();
    goalMap['status'] = goal.status.toDbString();

    // Convert tags list to JSON string
    goalMap['tags'] = jsonEncode(goal.tags);

    // Remove planIds and isDeleted (computed) as they're not stored in database
    goalMap.remove('planIds');
    goalMap.remove('isDeleted');  // This is computed from status
    goalMap.remove('createdAt');  // Remove camelCase versions that were replaced
    goalMap.remove('updatedAt');
    goalMap.remove('deletedAt');

    try {
      await db.insert(
        _tableGoals,
        goalMap,
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      AppLogger.i('Goal inserted successfully', tag: 'GoalDao');
    } catch (e) {
      AppLogger.e('Insert failed: $e', tag: 'GoalDao', error: e);
      rethrow;
    }

    return goal;
  }

  /// Get goal by ID
  Future<GoalModel?> getGoalById(String goalId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableGoals,
      where: 'id = ? AND status != ?',
      whereArgs: [goalId, 'deleted'],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    // Get plan IDs for this goal
    final planIds = await _getPlanIdsForGoal(goalId);

    return _mapToGoal(maps.first, planIds);
  }

  /// Get all goals for user
  Future<List<GoalModel>> getUserGoals(String userId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableGoals,
      where: 'user_id = ? AND status != \'deleted\'',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    final List<GoalModel> goals = [];
    for (final map in maps) {
      final planIds = await _getPlanIdsForGoal(map['id'] as String);
      goals.add(_mapToGoal(map, planIds));
    }

    return goals;
  }

  /// Get active goals for user
  Future<List<GoalModel>> getActiveGoals(String userId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableGoals,
      where: 'user_id = ? AND status = ? AND status != \'deleted\'',
      whereArgs: [userId, 'active'],
      orderBy: 'priority ASC, created_at DESC',
    );

    final List<GoalModel> goals = [];
    for (final map in maps) {
      final planIds = await _getPlanIdsForGoal(map['id'] as String);
      goals.add(_mapToGoal(map, planIds));
    }

    return goals;
  }

  /// Get goals by status
  Future<List<GoalModel>> getGoalsByStatus(String userId, GoalStatus status) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableGoals,
      where: 'user_id = ? AND status = ? AND status != \'deleted\'',
      whereArgs: [userId, status.toDbString()],
      orderBy: 'created_at DESC',
    );

    final List<GoalModel> goals = [];
    for (final map in maps) {
      final planIds = await _getPlanIdsForGoal(map['id'] as String);
      goals.add(_mapToGoal(map, planIds));
    }

    return goals;
  }

  /// Get goals by priority
  Future<List<GoalModel>> getGoalsByPriority(String userId, Priority priority) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableGoals,
      where: 'user_id = ? AND priority = ? AND status != \'deleted\'',
      whereArgs: [userId, priority.toDbString()],
      orderBy: 'created_at DESC',
    );

    final List<GoalModel> goals = [];
    for (final map in maps) {
      final planIds = await _getPlanIdsForGoal(map['id'] as String);
      goals.add(_mapToGoal(map, planIds));
    }

    return goals;
  }

  /// Get goals by tags
  Future<List<GoalModel>> getGoalsByTags(String userId, List<String> tags) async {
    final db = await _database.database;

    // Build WHERE clause for tags
    final tagConditions = tags.map((tag) => "tags LIKE '%\"$tag\"%'").join(' OR ');

    final List<Map<String, dynamic>> maps = await db.query(
      _tableGoals,
      where: 'user_id = ? AND ($tagConditions) AND status != \'deleted\'',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    final List<GoalModel> goals = [];
    for (final map in maps) {
      final planIds = await _getPlanIdsForGoal(map['id'] as String);
      goals.add(_mapToGoal(map, planIds));
    }

    return goals;
  }

  /// Get upcoming deadline goals
  Future<List<GoalModel>> getUpcomingDeadlineGoals(String userId, {int days = 7}) async {
    final db = await _database.database;
    final now = AppDatabase.getCurrentTimestamp();
    final future = now + (days * 24 * 60 * 60);

    final List<Map<String, dynamic>> maps = await db.query(
      _tableGoals,
      where: 'user_id = ? AND deadline IS NOT NULL AND deadline BETWEEN ? AND ? AND status != \'deleted\'',
      whereArgs: [userId, now, future],
      orderBy: 'deadline ASC',
    );

    final List<GoalModel> goals = [];
    for (final map in maps) {
      final planIds = await _getPlanIdsForGoal(map['id'] as String);
      goals.add(_mapToGoal(map, planIds));
    }

    return goals;
  }

  /// Update goal
  Future<int> updateGoal(GoalModel goal) async {
    final db = await _database.database;
    final goalMap = goal.toJson();

    // Map field names to database columns
    goalMap['user_id'] = goalMap.remove('userId');
    goalMap['success_criteria'] = goalMap.remove('successCriteria');

    // Set updated timestamp
    goalMap['updated_at'] = AppDatabase.getCurrentTimestamp();

    // Convert DateTime to timestamp
    if (goal.deadline != null) {
      goalMap['deadline'] = AppDatabase.dateTimeToTimestamp(goal.deadline!);
    }
    if (goal.deletedAt != null) {
      goalMap['deleted_at'] = AppDatabase.dateTimeToTimestamp(goal.deletedAt!);
    }
    goalMap['created_at'] = AppDatabase.dateTimeToTimestamp(goal.createdAt);

    // Convert enums
    goalMap['priority'] = goal.priority.toDbString();
    goalMap['status'] = goal.status.toDbString();

    // Convert tags list to JSON string
    goalMap['tags'] = jsonEncode(goal.tags);

    // Remove planIds and isDeleted (computed) as they're not stored in database
    goalMap.remove('planIds');
    goalMap.remove('isDeleted');  // This is computed from status
    goalMap.remove('createdAt');  // Remove camelCase versions that were replaced
    goalMap.remove('updatedAt');
    goalMap.remove('deletedAt');

    return await db.update(
      _tableGoals,
      goalMap,
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  /// Update goal status
  Future<int> updateGoalStatus(String goalId, GoalStatus status) async {
    final db = await _database.database;
    return await db.update(
      _tableGoals,
      {
        'status': status.toDbString(),
        'updated_at': AppDatabase.getCurrentTimestamp(),
      },
      where: 'id = ?',
      whereArgs: [goalId],
    );
  }

  /// Soft delete goal
  Future<int> deleteGoal(String goalId) async {
    AppLogger.d('deleteGoal called with goalId: $goalId', tag: 'GoalDao');
    final db = await _database.database;

    final timestamp = AppDatabase.getCurrentTimestamp();
    final statusString = GoalStatus.deleted.toDbString();

    try {
      final result = await db.update(
        _tableGoals,
        {
          'status': statusString,
          'deleted_at': timestamp,
          'updated_at': timestamp,
        },
        where: 'id = ?',
        whereArgs: [goalId],
      );
      AppLogger.i('Soft delete result: $result rows affected', tag: 'GoalDao');
      return result;
    } catch (e) {
      AppLogger.e('Error deleting goal: $e', tag: 'GoalDao', error: e);
      rethrow;
    }
  }

  /// Restore deleted goal
  Future<int> restoreGoal(String goalId) async {
    final db = await _database.database;
    return await db.update(
      _tableGoals,
      {
        'status': GoalStatus.active.toDbString(),
        'deleted_at': null,
        'updated_at': AppDatabase.getCurrentTimestamp(),
      },
      where: 'id = ?',
      whereArgs: [goalId],
    );
  }

  /// Get goal progress
  Future<double> getGoalProgress(String goalId) async {
    final db = await _database.database;
    final result = await db.rawQuery('''
      SELECT AVG(completion_rate) as progress
      FROM $_tablePlans
      WHERE goal_id = ? AND status != 'deleted'
    ''', [goalId]);

    if (result.isEmpty) return 0.0;

    final progress = result.first['progress'] as double?;
    return progress ?? 0.0;
  }

  /// Get goal statistics
  Future<Map<String, dynamic>> getGoalStatistics(String goalId) async {
    final db = await _database.database;

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as plan_count,
        AVG(completion_rate) as overall_progress,
        SUM(completed_task_count) as total_completed_tasks,
        SUM(total_task_count) as total_tasks,
        SUM(skipped_task_count) as total_skipped_tasks
      FROM $_tablePlans
      WHERE goal_id = ? AND status != 'deleted'
    ''', [goalId]);

    if (result.isEmpty) {
      return {
        'planCount': 0,
        'overallProgress': 0.0,
        'totalCompletedTasks': 0,
        'totalTasks': 0,
        'totalSkippedTasks': 0,
      };
    }

    return {
      'planCount': result.first['plan_count'] ?? 0,
      'overallProgress': result.first['overall_progress'] ?? 0.0,
      'totalCompletedTasks': result.first['total_completed_tasks'] ?? 0,
      'totalTasks': result.first['total_tasks'] ?? 0,
      'totalSkippedTasks': result.first['total_skipped_tasks'] ?? 0,
    };
  }

  /// Search goals
  Future<List<GoalModel>> searchGoals(String userId, String query) async {
    final db = await _database.database;
    final searchQuery = '%$query%';

    final List<Map<String, dynamic>> maps = await db.query(
      _tableGoals,
      where: 'user_id = ? AND (title LIKE ? OR description LIKE ?) AND status != \'deleted\'',
      whereArgs: [userId, searchQuery, searchQuery],
      orderBy: 'created_at DESC',
    );

    final List<GoalModel> goals = [];
    for (final map in maps) {
      final planIds = await _getPlanIdsForGoal(map['id'] as String);
      goals.add(_mapToGoal(map, planIds));
    }

    return goals;
  }

  /// Get deleted goals
  Future<List<GoalModel>> getDeletedGoals(String userId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableGoals,
      where: 'user_id = ? AND deleted_at IS NOT NULL',
      whereArgs: [userId],
      orderBy: 'deleted_at DESC',
    );

    final List<GoalModel> goals = [];
    for (final map in maps) {
      final planIds = await _getPlanIdsForGoal(map['id'] as String);
      goals.add(_mapToGoal(map, planIds));
    }

    return goals;
  }

  /// Get plan IDs for a goal
  Future<List<String>> _getPlanIdsForGoal(String goalId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tablePlans,
      columns: ['id'],
      where: 'goal_id = ? AND status != \'deleted\'',
      whereArgs: [goalId],
    );

    return maps.map((map) => map['id'] as String).toList();
  }

  /// Convert map to GoalModel
  GoalModel _mapToGoal(Map<String, dynamic> map, List<String> planIds) {
    return GoalModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      tags: map['tags'] != null
          ? (jsonDecode(map['tags'] as String) as List).cast<String>()
          : [],
      deadline: map['deadline'] != null
          ? AppDatabase.timestampToDateTime(_toInt(map['deadline']))
          : null,
      priority: Priority.fromString(map['priority'] as String),
      status: GoalStatus.fromString(map['status'] as String),
      successCriteria: map['success_criteria'] as String?,
      createdAt: AppDatabase.timestampToDateTime(_toInt(map['created_at'])),
      updatedAt: AppDatabase.timestampToDateTime(_toInt(map['updated_at'])),
      deletedAt: map['deleted_at'] != null
          ? AppDatabase.timestampToDateTime(_toInt(map['deleted_at']))
          : null,
      planIds: planIds,
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