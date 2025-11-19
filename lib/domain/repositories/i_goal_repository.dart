import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/status.dart';

/// Goal repository interface
abstract class IGoalRepository {
  /// Create a new goal
  Future<GoalModel> createGoal({
    required String userId,
    required String title,
    String? description,
    List<String>? tags,
    DateTime? deadline,
    Priority priority = Priority.medium,
    String? successCriteria,
  });

  /// Get goal by ID
  Future<GoalModel?> getGoalById(String goalId);

  /// Get all goals for user
  Future<List<GoalModel>> getUserGoals(String userId);

  /// Get active goals for user
  Future<List<GoalModel>> getActiveGoals(String userId);

  /// Get goals by status
  Future<List<GoalModel>> getGoalsByStatus(String userId, GoalStatus status);

  /// Get goals by priority
  Future<List<GoalModel>> getGoalsByPriority(String userId, Priority priority);

  /// Get goals by tags
  Future<List<GoalModel>> getGoalsByTags(String userId, List<String> tags);

  /// Get upcoming deadline goals
  Future<List<GoalModel>> getUpcomingDeadlineGoals(String userId, {int days = 7});

  /// Update goal
  Future<GoalModel> updateGoal(GoalModel goal);

  /// Update goal status
  Future<GoalModel> updateGoalStatus(String goalId, GoalStatus status);

  /// Delete goal (soft delete)
  Future<bool> deleteGoal(String goalId);

  /// Restore deleted goal
  Future<bool> restoreGoal(String goalId);

  /// Get goal progress (computed from plans)
  Future<double> getGoalProgress(String goalId);

  /// Get goal statistics
  Future<Map<String, dynamic>> getGoalStatistics(String goalId);

  /// Add plan to goal
  Future<bool> addPlanToGoal(String goalId, String planId);

  /// Remove plan from goal
  Future<bool> removePlanFromGoal(String goalId, String planId);

  /// Search goals
  Future<List<GoalModel>> searchGoals(String userId, String query);

  /// Get deleted goals (for recovery)
  Future<List<GoalModel>> getDeletedGoals(String userId);
}