import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:myassistant/data/data_sources/local/database/app_database.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/core/utils/app_logger.dart';

/// Plan Data Access Object
class PlanDao {
  static const String _tablePlans = 'plans';

  final AppDatabase _database = AppDatabase.instance;

  /// Insert plan
  Future<PlanModel> insertPlan(PlanModel plan) async {
    final db = await _database.database;
    final planMap = <String, dynamic>{
      'id': plan.id,
      'user_id': plan.userId,
      'goal_id': plan.goalId,
      'name': plan.name, // Immutable after creation
      'description': plan.description,
      'start_date': AppDatabase.dateTimeToTimestamp(plan.startDate),
      'end_date': AppDatabase.dateTimeToTimestamp(plan.endDate),
      'repeat_type': plan.repeatRule.type.toDbString(),
      'custom_days': plan.repeatRule.customDays,
      'task_config': jsonEncode(plan.taskConfig.toJson()),
      'status': plan.status.toDbString(),
      'created_at': AppDatabase.dateTimeToTimestamp(plan.createdAt),
      'updated_at': AppDatabase.dateTimeToTimestamp(plan.updatedAt),
      'deleted_at': plan.deletedAt != null
          ? AppDatabase.dateTimeToTimestamp(plan.deletedAt!)
          : null,
      'total_task_count': 0,
      'completed_task_count': 0,
      'skipped_task_count': 0,
      'completion_rate': 0.0,
    };

    await db.insert(
      _tablePlans,
      planMap,
      conflictAlgorithm: ConflictAlgorithm.fail,
    );

    return plan;
  }

  /// Get plan by ID
  Future<PlanModel?> getPlanById(String planId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tablePlans,
      where: 'id = ? AND status != ?',
      whereArgs: [planId, 'deleted'],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return _mapToPlan(maps.first);
  }

  /// Get all plans for user
  Future<List<PlanModel>> getUserPlans(String userId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tablePlans,
      where: 'user_id = ? AND status != ?',
      whereArgs: [userId, 'deleted'],
      orderBy: 'created_at DESC',
    );

    return maps.map(_mapToPlan).toList();
  }

  /// Get plans for goal
  Future<List<PlanModel>> getGoalPlans(String goalId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tablePlans,
      where: 'goal_id = ? AND status != ?',
      whereArgs: [goalId, 'deleted'],
      orderBy: 'created_at DESC',
    );

    return maps.map(_mapToPlan).toList();
  }

  /// Get active plans
  Future<List<PlanModel>> getActivePlans(String userId) async {
    final db = await _database.database;
    final now = AppDatabase.getCurrentTimestamp();

    final List<Map<String, dynamic>> maps = await db.query(
      _tablePlans,
      where: 'user_id = ? AND start_date <= ? AND end_date >= ? AND status != ?',
      whereArgs: [userId, now, now, 'deleted'],
      orderBy: 'created_at DESC',
    );

    return maps.map(_mapToPlan).toList();
  }

  /// Get plans by date range
  Future<List<PlanModel>> getPlansByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _database.database;
    final startTimestamp = AppDatabase.dateTimeToTimestamp(startDate);
    final endTimestamp = AppDatabase.dateTimeToTimestamp(endDate);

    final List<Map<String, dynamic>> maps = await db.query(
      _tablePlans,
      where: '''user_id = ? AND status != ? AND
                ((start_date BETWEEN ? AND ?) OR
                 (end_date BETWEEN ? AND ?) OR
                 (start_date <= ? AND end_date >= ?))''',
      whereArgs: [
        userId,
        'deleted',
        startTimestamp,
        endTimestamp,
        startTimestamp,
        endTimestamp,
        startTimestamp,
        endTimestamp,
      ],
      orderBy: 'start_date ASC',
    );

    return maps.map(_mapToPlan).toList();
  }

  /// Update plan (name cannot be updated)
  Future<int> updatePlan(PlanModel plan) async {
    final db = await _database.database;
    final planMap = <String, dynamic>{
      // 'name' is NOT updated - it's immutable
      'description': plan.description,
      'start_date': AppDatabase.dateTimeToTimestamp(plan.startDate),
      'end_date': AppDatabase.dateTimeToTimestamp(plan.endDate),
      'repeat_type': plan.repeatRule.type.toDbString(),
      'custom_days': plan.repeatRule.customDays,
      'task_config': jsonEncode(plan.taskConfig.toJson()),
      'status': plan.status.toDbString(),
      'updated_at': AppDatabase.getCurrentTimestamp(),
    };

    if (plan.deletedAt != null) {
      planMap['deleted_at'] = AppDatabase.dateTimeToTimestamp(plan.deletedAt!);
    }

    return await db.update(
      _tablePlans,
      planMap,
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  /// Soft delete plan (sets status='deleted')
  Future<int> deletePlan(String planId) async {
    AppLogger.d('deletePlan called with planId: $planId', tag: 'PlanDao');
    final db = await _database.database;
    final timestamp = AppDatabase.getCurrentTimestamp();
    final result = await db.update(
      _tablePlans,
      {
        'status': 'deleted',
        'deleted_at': timestamp,
        'updated_at': timestamp,
      },
      where: 'id = ?',
      whereArgs: [planId],
    );
    AppLogger.i('Soft delete result (rows affected): $result', tag: 'PlanDao');
    return result;
  }

  /// Restore deleted plan (sets status='active')
  Future<int> restorePlan(String planId) async {
    final db = await _database.database;
    return await db.update(
      _tablePlans,
      {
        'status': 'active',
        'deleted_at': null,
        'updated_at': AppDatabase.getCurrentTimestamp(),
      },
      where: 'id = ?',
      whereArgs: [planId],
    );
  }

  /// Check if plan name exists for user
  Future<bool> isPlanNameExists(String userId, String name) async {
    final db = await _database.database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $_tablePlans WHERE user_id = ? AND name = ? AND status != ?',
      [userId, name, 'deleted'],
    ));
    return count != null && count > 0;
  }

  /// Get plan statistics
  Future<Map<String, dynamic>> getPlanStatistics(String planId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tablePlans,
      columns: [
        'total_task_count',
        'completed_task_count',
        'skipped_task_count',
        'completion_rate',
      ],
      where: 'id = ?',
      whereArgs: [planId],
      limit: 1,
    );

    if (maps.isEmpty) {
      return {
        'totalTaskCount': 0,
        'completedTaskCount': 0,
        'skippedTaskCount': 0,
        'completionRate': 0.0,
      };
    }

    return {
      'totalTaskCount': maps.first['total_task_count'] ?? 0,
      'completedTaskCount': maps.first['completed_task_count'] ?? 0,
      'skippedTaskCount': maps.first['skipped_task_count'] ?? 0,
      'completionRate': maps.first['completion_rate'] ?? 0.0,
    };
  }

  /// Update plan statistics
  Future<int> updatePlanStatistics({
    required String planId,
    int? totalTaskCount,
    int? completedTaskCount,
    int? skippedTaskCount,
  }) async {
    final db = await _database.database;

    // Get current values
    final current = await getPlanStatistics(planId);

    final total = totalTaskCount ?? current['totalTaskCount'] as int;
    final completed = completedTaskCount ?? current['completedTaskCount'] as int;
    final skipped = skippedTaskCount ?? current['skippedTaskCount'] as int;

    final completionRate = total > 0 ? completed / total : 0.0;

    return await db.update(
      _tablePlans,
      {
        'total_task_count': total,
        'completed_task_count': completed,
        'skipped_task_count': skipped,
        'completion_rate': completionRate,
        'updated_at': AppDatabase.getCurrentTimestamp(),
      },
      where: 'id = ?',
      whereArgs: [planId],
    );
  }

  /// Calculate completion rate
  Future<double> calculateCompletionRate(String planId) async {
    final stats = await getPlanStatistics(planId);
    final total = stats['totalTaskCount'] as int;
    final completed = stats['completedTaskCount'] as int;

    if (total == 0) return 0.0;
    return completed / total;
  }

  /// Get plans that need task generation
  Future<List<PlanModel>> getPlansNeedingTaskGeneration(String userId) async {
    AppLogger.i('getPlansNeedingTaskGeneration called for user: $userId', tag: 'PlanDao');
    final db = await _database.database;
    final now = AppDatabase.getCurrentTimestamp();

    // Get active plans
    AppLogger.d('Getting active plans...', tag: 'PlanDao');
    final activePlans = await getActivePlans(userId);
    AppLogger.i('Found ${activePlans.length} active plans', tag: 'PlanDao');

    final plansNeedingGeneration = <PlanModel>[];

    for (final plan in activePlans) {
      AppLogger.d('Checking plan: ${plan.name} (id: ${plan.id})', tag: 'PlanDao');

      // Check if there's an active task for this plan
      final activeTaskCount = Sqflite.firstIntValue(await db.rawQuery(
        '''SELECT COUNT(*) FROM tasks
           WHERE plan_id = ? AND status = 'active'
           AND window_end_time >= ?''',
        [plan.id, now],
      ));

      AppLogger.d('Active task count for plan ${plan.name}: $activeTaskCount', tag: 'PlanDao');

      if (activeTaskCount == null || activeTaskCount == 0) {
        AppLogger.d('✓ Plan ${plan.name} needs task generation', tag: 'PlanDao');
        plansNeedingGeneration.add(plan);
      } else {
        AppLogger.d('✗ Plan ${plan.name} already has active task', tag: 'PlanDao');
      }
    }

    AppLogger.i('${plansNeedingGeneration.length} plans need task generation', tag: 'PlanDao');
    return plansNeedingGeneration;
  }

  /// Search plans
  Future<List<PlanModel>> searchPlans(String userId, String query) async {
    final db = await _database.database;
    final searchQuery = '%$query%';

    final List<Map<String, dynamic>> maps = await db.query(
      _tablePlans,
      where: 'user_id = ? AND (name LIKE ? OR description LIKE ?) AND status != ?',
      whereArgs: [userId, searchQuery, searchQuery, 'deleted'],
      orderBy: 'created_at DESC',
    );

    return maps.map(_mapToPlan).toList();
  }

  /// Get deleted plans
  Future<List<PlanModel>> getDeletedPlans(String userId) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tablePlans,
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'deleted'],
      orderBy: 'deleted_at DESC',
    );

    return maps.map(_mapToPlan).toList();
  }

  /// Get plans ending soon
  Future<List<PlanModel>> getPlansEndingSoon(String userId, {int days = 7}) async {
    final db = await _database.database;
    final now = AppDatabase.getCurrentTimestamp();
    final future = now + (days * 24 * 60 * 60);

    final List<Map<String, dynamic>> maps = await db.query(
      _tablePlans,
      where: 'user_id = ? AND end_date BETWEEN ? AND ? AND status != ?',
      whereArgs: [userId, now, future, 'deleted'],
      orderBy: 'end_date ASC',
    );

    return maps.map(_mapToPlan).toList();
  }

  /// Convert map to PlanModel
  PlanModel _mapToPlan(Map<String, dynamic> map) {
    // Parse task configuration
    final taskConfigJson = jsonDecode(map['task_config'] as String);
    final taskConfig = TaskConfiguration.fromJson(taskConfigJson);

    // Parse repeat rule
    final repeatRule = RepeatRule(
      type: RepeatType.fromString(map['repeat_type'] as String),
      customDays: map['custom_days'] != null ? _toInt(map['custom_days']) : null,
    );

    return PlanModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      goalId: map['goal_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      startDate: AppDatabase.timestampToDateTime(_toInt(map['start_date'])),
      endDate: AppDatabase.timestampToDateTime(_toInt(map['end_date'])),
      repeatRule: repeatRule,
      taskConfig: taskConfig,
      status: PlanStatus.fromString(map['status'] as String),
      createdAt: AppDatabase.timestampToDateTime(_toInt(map['created_at'])),
      updatedAt: AppDatabase.timestampToDateTime(_toInt(map['updated_at'])),
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