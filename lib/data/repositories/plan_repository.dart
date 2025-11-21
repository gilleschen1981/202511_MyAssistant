import 'package:uuid/uuid.dart';
import 'package:myassistant/data/data_sources/local/dao/plan_dao.dart';
import 'package:myassistant/data/data_sources/local/dao/goal_dao.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/domain/repositories/i_goal_repository.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/core/utils/app_logger.dart';

/// Plan repository implementation
class PlanRepository implements IPlanRepository {
  final PlanDao _planDao;
  final GoalDao _goalDao;
  final IGoalRepository _goalRepository;
  final ITaskRepository _taskRepository;
  final _uuid = const Uuid();

  PlanRepository({
    PlanDao? planDao,
    GoalDao? goalDao,
    required IGoalRepository goalRepository,
    required ITaskRepository taskRepository,
  })  : _planDao = planDao ?? PlanDao(),
        _goalDao = goalDao ?? GoalDao(),
        _goalRepository = goalRepository,
        _taskRepository = taskRepository;

  @override
  Future<PlanModel> createPlan({
    required String userId,
    required String goalId,
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    required RepeatRule repeatRule,
    required TaskConfiguration taskConfig,
  }) async {
    // Validate goal exists
    final goal = await _goalDao.getGoalById(goalId);
    if (goal == null) {
      throw Exception('Goal not found');
    }

    // Validate plan name uniqueness for user
    if (await _planDao.isPlanNameExists(userId, name)) {
      throw Exception('Plan name already exists for this user');
    }

    // Validate date range
    if (endDate.isBefore(startDate)) {
      throw Exception('End date must be after start date');
    }

    // Validate repeat rule
    if (!repeatRule.isValid) {
      throw Exception('Invalid repeat rule');
    }

    // Validate task configuration
    if (!taskConfig.isValid) {
      throw Exception('Invalid task configuration');
    }

    final now = DateTime.now();
    final plan = PlanModel(
      id: _uuid.v4(),
      userId: userId,
      name: name, // Immutable after creation
      description: description,
      goalId: goalId,
      startDate: startDate,
      endDate: endDate,
      repeatRule: repeatRule,
      taskConfig: taskConfig,
      createdAt: now,
      updatedAt: now,
    );

    final createdPlan = await _planDao.insertPlan(plan);

    // Add plan ID to goal
    await _goalRepository.addPlanToGoal(goalId, createdPlan.id);

    return createdPlan;
  }

  @override
  Future<PlanModel?> getPlanById(String planId) async {
    return await _planDao.getPlanById(planId);
  }

  @override
  Future<List<PlanModel>> getUserPlans(String userId) async {
    return await _planDao.getUserPlans(userId);
  }

  @override
  Future<List<PlanModel>> getGoalPlans(String goalId) async {
    return await _planDao.getGoalPlans(goalId);
  }

  @override
  Future<List<PlanModel>> getActivePlans(String userId) async {
    return await _planDao.getActivePlans(userId);
  }

  @override
  Future<List<PlanModel>> getPlansByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _planDao.getPlansByDateRange(userId, startDate, endDate);
  }

  @override
  Future<PlanModel> updatePlan(PlanModel plan) async {
    // Note: Plan name is immutable and cannot be updated
    final existingPlan = await _planDao.getPlanById(plan.id);
    if (existingPlan == null) {
      throw Exception('Plan not found');
    }

    // Ensure name is not changed
    if (existingPlan.name != plan.name) {
      throw Exception('Plan name cannot be changed after creation');
    }

    // Validate date range
    if (plan.endDate.isBefore(plan.startDate)) {
      throw Exception('End date must be after start date');
    }

    // Validate repeat rule
    if (!plan.repeatRule.isValid) {
      throw Exception('Invalid repeat rule');
    }

    // Validate task configuration
    if (!plan.taskConfig.isValid) {
      throw Exception('Invalid task configuration');
    }

    final updatedPlan = plan.copyWith(
      updatedAt: DateTime.now(),
    );

    final result = await _planDao.updatePlan(updatedPlan);
    if (result == 0) {
      throw Exception('Failed to update plan');
    }

    return updatedPlan;
  }

  @override
  Future<bool> deletePlan(String planId) async {
    AppLogger.d('deletePlan called with planId: $planId', tag: 'PlanRepository');
    // Note: This is a soft delete
    AppLogger.d('Fetching plan from DAO...', tag: 'PlanRepository');
    final plan = await _planDao.getPlanById(planId);
    if (plan == null) {
      AppLogger.w('Plan not found in DAO', tag: 'PlanRepository');
      return false;
    }
    AppLogger.d('Plan found: ${plan.name}, goalId: ${plan.goalId}', tag: 'PlanRepository');

    // 1. Delete all tasks for this plan (cascade delete)
    AppLogger.d('Deleting all tasks for plan...', tag: 'PlanRepository');
    await _taskRepository.deletePlanTasks(planId);
    AppLogger.d('Tasks deleted', tag: 'PlanRepository');

    // 2. Remove plan from goal
    AppLogger.d('Removing plan from goal...', tag: 'PlanRepository');
    await _goalRepository.removePlanFromGoal(plan.goalId, planId);
    AppLogger.d('Plan removed from goal', tag: 'PlanRepository');

    // 3. Delete the plan
    AppLogger.d('Calling DAO.deletePlan...', tag: 'PlanRepository');
    final result = await _planDao.deletePlan(planId);
    AppLogger.d('DAO delete result: $result', tag: 'PlanRepository');
    return result > 0;
  }

  @override
  Future<bool> restorePlan(String planId) async {
    final result = await _planDao.restorePlan(planId);
    if (result > 0) {
      // Re-add plan to goal
      final plan = await _planDao.getPlanById(planId);
      if (plan != null) {
        await _goalRepository.addPlanToGoal(plan.goalId, planId);
      }
      return true;
    }
    return false;
  }

  @override
  Future<bool> isPlanNameExists(String userId, String name) async {
    return await _planDao.isPlanNameExists(userId, name);
  }

  @override
  Future<Map<String, dynamic>> getPlanStatistics(String planId) async {
    return await _planDao.getPlanStatistics(planId);
  }

  @override
  Future<bool> updatePlanStatistics({
    required String planId,
    int? totalTaskCount,
    int? completedTaskCount,
    int? skippedTaskCount,
  }) async {
    final result = await _planDao.updatePlanStatistics(
      planId: planId,
      totalTaskCount: totalTaskCount,
      completedTaskCount: completedTaskCount,
      skippedTaskCount: skippedTaskCount,
    );
    return result > 0;
  }

  @override
  Future<double> calculateCompletionRate(String planId) async {
    return await _planDao.calculateCompletionRate(planId);
  }

  @override
  Future<List<PlanModel>> getPlansNeedingTaskGeneration(String userId) async {
    return await _planDao.getPlansNeedingTaskGeneration(userId);
  }

  @override
  Future<List<PlanModel>> searchPlans(String userId, String query) async {
    if (query.isEmpty) {
      return await getUserPlans(userId);
    }
    return await _planDao.searchPlans(userId, query);
  }

  @override
  Future<List<PlanModel>> getDeletedPlans(String userId) async {
    return await _planDao.getDeletedPlans(userId);
  }

  @override
  Future<List<PlanModel>> getPlansEndingSoon(String userId, {int days = 7}) async {
    return await _planDao.getPlansEndingSoon(userId, days: days);
  }
}