import 'package:uuid/uuid.dart';
import 'package:myassistant/data/data_sources/local/dao/goal_dao.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/domain/repositories/i_goal_repository.dart';
import 'package:myassistant/core/utils/app_logger.dart';

/// Goal repository implementation
class GoalRepository implements IGoalRepository {
  final GoalDao _goalDao;
  final _uuid = const Uuid();

  GoalRepository({GoalDao? goalDao}) : _goalDao = goalDao ?? GoalDao();

  @override
  Future<GoalModel> createGoal({
    required String userId,
    required String title,
    String? description,
    List<String>? tags,
    DateTime? deadline,
    Priority priority = Priority.medium,
    String? successCriteria,
  }) async {
    AppLogger.d('createGoal called with: userId=$userId, title=$title', tag: 'GoalRepository');

    final now = DateTime.now();
    final goal = GoalModel(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      description: description,
      tags: tags ?? [],
      deadline: deadline,
      priority: priority,
      status: GoalStatus.active,
      successCriteria: successCriteria,
      createdAt: now,
      updatedAt: now,
      planIds: const [],
    );
    AppLogger.d('Created GoalModel with id: ${goal.id}', tag: 'GoalRepository');

    try {
      final result = await _goalDao.insertGoal(goal);
      AppLogger.i('Goal inserted successfully', tag: 'GoalRepository');
      return result;
    } catch (e) {
      AppLogger.e('Error inserting goal: $e', tag: 'GoalRepository', error: e);
      rethrow;
    }
  }

  @override
  Future<GoalModel?> getGoalById(String goalId) async {
    return await _goalDao.getGoalById(goalId);
  }

  @override
  Future<List<GoalModel>> getUserGoals(String userId) async {
    return await _goalDao.getUserGoals(userId);
  }

  @override
  Future<List<GoalModel>> getActiveGoals(String userId) async {
    return await _goalDao.getActiveGoals(userId);
  }

  @override
  Future<List<GoalModel>> getGoalsByStatus(String userId, GoalStatus status) async {
    return await _goalDao.getGoalsByStatus(userId, status);
  }

  @override
  Future<List<GoalModel>> getGoalsByPriority(String userId, Priority priority) async {
    return await _goalDao.getGoalsByPriority(userId, priority);
  }

  @override
  Future<List<GoalModel>> getGoalsByTags(String userId, List<String> tags) async {
    return await _goalDao.getGoalsByTags(userId, tags);
  }

  @override
  Future<List<GoalModel>> getUpcomingDeadlineGoals(String userId, {int days = 7}) async {
    return await _goalDao.getUpcomingDeadlineGoals(userId, days: days);
  }

  @override
  Future<GoalModel> updateGoal(GoalModel goal) async {
    final updatedGoal = goal.copyWith(
      updatedAt: DateTime.now(),
    );

    final result = await _goalDao.updateGoal(updatedGoal);
    if (result == 0) {
      throw Exception('Failed to update goal');
    }

    return updatedGoal;
  }

  @override
  Future<GoalModel> updateGoalStatus(String goalId, GoalStatus status) async {
    final goal = await _goalDao.getGoalById(goalId);
    if (goal == null) {
      throw Exception('Goal not found');
    }

    // Business rule: Completed goals cannot be modified
    if (goal.status == GoalStatus.completed && status != GoalStatus.completed) {
      throw Exception('Cannot modify completed goal');
    }

    final result = await _goalDao.updateGoalStatus(goalId, status);
    if (result == 0) {
      throw Exception('Failed to update goal status');
    }

    return goal.copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<bool> deleteGoal(String goalId) async {
    // Note: This is a soft delete
    final result = await _goalDao.deleteGoal(goalId);
    return result > 0;
  }

  @override
  Future<bool> restoreGoal(String goalId) async {
    final result = await _goalDao.restoreGoal(goalId);
    return result > 0;
  }

  @override
  Future<double> getGoalProgress(String goalId) async {
    return await _goalDao.getGoalProgress(goalId);
  }

  @override
  Future<Map<String, dynamic>> getGoalStatistics(String goalId) async {
    return await _goalDao.getGoalStatistics(goalId);
  }

  @override
  Future<bool> addPlanToGoal(String goalId, String planId) async {
    final goal = await _goalDao.getGoalById(goalId);
    if (goal == null) return false;

    if (!goal.planIds.contains(planId)) {
      final updatedGoal = goal.copyWith(
        planIds: [...goal.planIds, planId],
        updatedAt: DateTime.now(),
      );

      final result = await _goalDao.updateGoal(updatedGoal);
      return result > 0;
    }

    return true;
  }

  @override
  Future<bool> removePlanFromGoal(String goalId, String planId) async {
    AppLogger.d('removePlanFromGoal called - goalId: $goalId, planId: $planId', tag: 'GoalRepository');
    final goal = await _goalDao.getGoalById(goalId);
    if (goal == null) {
      AppLogger.w('Goal not found', tag: 'GoalRepository');
      return false;
    }
    AppLogger.d('Goal found: ${goal.title}, planIds count: ${goal.planIds.length}', tag: 'GoalRepository');

    if (goal.planIds.contains(planId)) {
      AppLogger.d('Plan found in goal, removing...', tag: 'GoalRepository');
      final updatedPlanIds = goal.planIds.where((id) => id != planId).toList();
      AppLogger.d('Updated planIds count: ${updatedPlanIds.length}', tag: 'GoalRepository');
      final updatedGoal = goal.copyWith(
        planIds: updatedPlanIds,
        updatedAt: DateTime.now(),
      );

      AppLogger.d('Updating goal in DAO...', tag: 'GoalRepository');
      final result = await _goalDao.updateGoal(updatedGoal);
      AppLogger.d('DAO update result: $result', tag: 'GoalRepository');
      return result > 0;
    }

    AppLogger.d('Plan not found in goal, returning true', tag: 'GoalRepository');
    return true;
  }

  @override
  Future<List<GoalModel>> searchGoals(String userId, String query) async {
    if (query.isEmpty) {
      return await getUserGoals(userId);
    }
    return await _goalDao.searchGoals(userId, query);
  }

  @override
  Future<List<GoalModel>> getDeletedGoals(String userId) async {
    return await _goalDao.getDeletedGoals(userId);
  }
}