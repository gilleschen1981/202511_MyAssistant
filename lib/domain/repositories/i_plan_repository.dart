import 'package:myassistant/data/models/plan_model.dart';

/// Plan repository interface
abstract class IPlanRepository {
  /// Create a new plan
  /// Note: Plan name is immutable after creation
  Future<PlanModel> createPlan({
    required String userId,
    required String goalId,
    required String name, // Immutable after creation
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    required RepeatRule repeatRule,
    required TaskConfiguration taskConfig,
  });

  /// Get plan by ID
  Future<PlanModel?> getPlanById(String planId);

  /// Get all plans for user
  Future<List<PlanModel>> getUserPlans(String userId);

  /// Get plans for goal
  Future<List<PlanModel>> getGoalPlans(String goalId);

  /// Get active plans
  Future<List<PlanModel>> getActivePlans(String userId);

  /// Get plans by date range
  Future<List<PlanModel>> getPlansByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  );

  /// Update plan (name cannot be updated)
  Future<PlanModel> updatePlan(PlanModel plan);

  /// Delete plan (soft delete)
  Future<bool> deletePlan(String planId);

  /// Restore deleted plan
  Future<bool> restorePlan(String planId);

  /// Check if plan name exists for user (for creation validation)
  Future<bool> isPlanNameExists(String userId, String name);

  /// Get plan statistics
  Future<Map<String, dynamic>> getPlanStatistics(String planId);

  /// Update plan statistics (called after task completion)
  Future<bool> updatePlanStatistics({
    required String planId,
    int? totalTaskCount,
    int? completedTaskCount,
    int? skippedTaskCount,
  });

  /// Calculate completion rate
  Future<double> calculateCompletionRate(String planId);

  /// Get plans that need task generation
  Future<List<PlanModel>> getPlansNeedingTaskGeneration(String userId);

  /// Search plans
  Future<List<PlanModel>> searchPlans(String userId, String query);

  /// Get deleted plans (for recovery)
  Future<List<PlanModel>> getDeletedPlans(String userId);

  /// Get plans ending soon
  Future<List<PlanModel>> getPlansEndingSoon(String userId, {int days = 7});
}