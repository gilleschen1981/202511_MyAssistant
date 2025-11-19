import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/domain/repositories/i_goal_repository.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/data/services/task_generation_service.dart';
import 'package:myassistant/core/errors/exceptions.dart';

/// Plan statistics
class PlanStatistics {
  final int totalTasks;
  final int completedTasks;
  final int activeTasks;
  final int skippedTasks;
  final double completionRate;
  final int daysRemaining;
  final int totalDays;
  final double progressPercentage;

  PlanStatistics({
    required this.totalTasks,
    required this.completedTasks,
    required this.activeTasks,
    required this.skippedTasks,
    required this.completionRate,
    required this.daysRemaining,
    required this.totalDays,
    required this.progressPercentage,
  });
}

/// Plan validation result
class PlanValidationResult {
  final bool isValid;
  final List<String> errors;

  PlanValidationResult({
    required this.isValid,
    required this.errors,
  });
}

/// Plan management service - handles plan lifecycle and operations
class PlanManagementService {
  final IPlanRepository _planRepository;
  final IGoalRepository _goalRepository;
  final ITaskRepository _taskRepository;
  final TaskGenerationService _generationService;

  PlanManagementService({
    required IPlanRepository planRepository,
    required IGoalRepository goalRepository,
    required ITaskRepository taskRepository,
    required TaskGenerationService generationService,
  })  : _planRepository = planRepository,
        _goalRepository = goalRepository,
        _taskRepository = taskRepository,
        _generationService = generationService;

  /// Create a new plan
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
    // 1. Validate goal exists
    final goal = await _goalRepository.getGoalById(goalId);
    if (goal == null) {
      throw const NotFoundException('Goal not found');
    }

    // 2. Check goal ownership
    if (goal.userId != userId) {
      throw const PermissionException('You do not have permission to add plans to this goal');
    }

    // 3. Validate plan
    final validation = await _validatePlanCreation(
      userId: userId,
      name: name,
      startDate: startDate,
      endDate: endDate,
      repeatRule: repeatRule,
      taskConfig: taskConfig,
    );

    if (!validation.isValid) {
      throw ValidationException(validation.errors.join('; '));
    }

    // 4. Create the plan
    final plan = await _planRepository.createPlan(
      userId: userId,
      goalId: goalId,
      name: name,
      description: description,
      startDate: startDate,
      endDate: endDate,
      repeatRule: repeatRule,
      taskConfig: taskConfig,
    );

    // 5. Add plan to goal
    await _goalRepository.addPlanToGoal(goalId, plan.id);

    // 6. Generate first task if applicable
    if (plan.isActive) {
      await _generationService.generateNextTask(plan);
    }

    return plan;
  }

  /// Update plan (limited fields can be updated)
  Future<PlanModel> updatePlan({
    required String planId,
    String? description,
    DateTime? endDate,
    TaskConfiguration? taskConfig,
  }) async {
    // 1. Get existing plan
    final plan = await _planRepository.getPlanById(planId);
    if (plan == null) {
      throw const NotFoundException('Plan not found');
    }

    // 2. Check if plan is deleted
    if (plan.isDeleted) {
      throw const BusinessException('Cannot update deleted plan');
    }

    // 3. Validate updates
    if (endDate != null) {
      if (endDate.isBefore(plan.startDate)) {
        throw const ValidationException('End date cannot be before start date');
      }
      if (endDate.isBefore(DateTime.now())) {
        throw const ValidationException('End date cannot be in the past');
      }
    }

    if (taskConfig != null && !taskConfig.isValid) {
      throw const ValidationException('Invalid task configuration');
    }

    // 4. Create updated plan (name is immutable)
    final updatedPlan = plan.copyWith(
      description: description ?? plan.description,
      endDate: endDate ?? plan.endDate,
      taskConfig: taskConfig ?? plan.taskConfig,
      updatedAt: DateTime.now(),
    );

    // 5. Update plan
    return await _planRepository.updatePlan(updatedPlan);
  }

  /// Delete plan (soft delete)
  Future<bool> deletePlan(String planId) async {
    // 1. Get plan
    final plan = await _planRepository.getPlanById(planId);
    if (plan == null) {
      throw const NotFoundException('Plan not found');
    }

    // 2. Check if already deleted
    if (plan.isDeleted) {
      throw const BusinessException('Plan is already deleted');
    }

    // 3. Check for active tasks
    final tasks = await _taskRepository.getPlanTasks(planId);
    final hasActiveTasks = tasks.any((t) => t.status == TaskStatus.active);

    if (hasActiveTasks) {
      throw const BusinessException('Cannot delete plan with active tasks');
    }

    // 4. Delete the plan
    final result = await _planRepository.deletePlan(planId);

    // 5. Remove from goal
    await _goalRepository.removePlanFromGoal(plan.goalId, planId);

    return result;
  }

  /// Calculate plan statistics
  Future<PlanStatistics> calculatePlanStatistics(String planId) async {
    // 1. Get plan
    final plan = await _planRepository.getPlanById(planId);
    if (plan == null) {
      throw const NotFoundException('Plan not found');
    }

    // 2. Get all tasks for this plan
    final tasks = await _taskRepository.getPlanTasks(planId);

    // 3. Calculate task statistics
    final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).length;
    final activeTasks = tasks.where((t) => t.status == TaskStatus.active).length;
    final skippedTasks = tasks.where((t) => t.status == TaskStatus.skipped).length;

    // 4. Calculate completion rate
    final completionRate = tasks.isNotEmpty ? completedTasks / tasks.length : 0.0;

    // 5. Calculate days
    final now = DateTime.now();
    final daysRemaining = plan.endDate.difference(now).inDays.clamp(0, double.infinity).toInt();
    final totalDays = plan.endDate.difference(plan.startDate).inDays;
    final daysPassed = now.difference(plan.startDate).inDays.clamp(0, totalDays);

    // 6. Calculate progress percentage
    final progressPercentage = totalDays > 0 ? daysPassed / totalDays : 0.0;

    return PlanStatistics(
      totalTasks: tasks.length,
      completedTasks: completedTasks,
      activeTasks: activeTasks,
      skippedTasks: skippedTasks,
      completionRate: completionRate,
      daysRemaining: daysRemaining,
      totalDays: totalDays,
      progressPercentage: progressPercentage,
    );
  }

  /// Get plan recommendations
  Future<List<String>> getPlanRecommendations(String planId) async {
    final recommendations = <String>[];

    // 1. Get plan and statistics
    final plan = await _planRepository.getPlanById(planId);
    if (plan == null) {
      throw const NotFoundException('Plan not found');
    }

    final stats = await calculatePlanStatistics(planId);

    // 2. Check completion rate
    if (stats.completionRate < 0.5 && stats.totalTasks > 5) {
      recommendations.add('Low task completion rate. Consider adjusting task difficulty.');
    }

    // 3. Check if plan is ending soon
    if (stats.daysRemaining <= 3 && stats.completionRate < 0.8) {
      recommendations.add('Plan ending soon with incomplete tasks. Focus on critical tasks.');
    }

    // 4. Check task generation
    if (plan.isActive && stats.activeTasks == 0) {
      recommendations.add('No active tasks. Check task generation settings.');
    }

    // 5. Check skip rate
    if (stats.totalTasks > 0) {
      final skipRate = stats.skippedTasks / stats.totalTasks;
      if (skipRate > 0.3) {
        recommendations.add('High task skip rate. Tasks may be too difficult or frequent.');
      }
    }

    // 6. Check task configuration
    if (plan.taskConfig.taskType == TaskType.timer) {
      if (plan.taskConfig.durationMinutes! > 60) {
        recommendations.add('Timer tasks are long. Consider breaking into smaller sessions.');
      }
    }

    return recommendations;
  }

  /// Extend plan end date
  Future<PlanModel> extendPlan({
    required String planId,
    required int additionalDays,
  }) async {
    if (additionalDays <= 0) {
      throw const ValidationException('Additional days must be positive');
    }

    final plan = await _planRepository.getPlanById(planId);
    if (plan == null) {
      throw const NotFoundException('Plan not found');
    }

    if (plan.isDeleted) {
      throw const BusinessException('Cannot extend deleted plan');
    }

    final newEndDate = plan.endDate.add(Duration(days: additionalDays));

    return await updatePlan(
      planId: planId,
      endDate: newEndDate,
    );
  }

  /// Clone an existing plan
  Future<PlanModel> clonePlan({
    required String originalPlanId,
    required String newGoalId,
    DateTime? newStartDate,
    DateTime? newEndDate,
  }) async {
    // 1. Get original plan
    final originalPlan = await _planRepository.getPlanById(originalPlanId);
    if (originalPlan == null) {
      throw const NotFoundException('Original plan not found');
    }

    // 2. Calculate new dates
    final startDate = newStartDate ?? DateTime.now();
    final duration = originalPlan.durationDays;
    final endDate = newEndDate ?? startDate.add(Duration(days: duration));

    // 3. Create new plan with same configuration
    return await createPlan(
      userId: originalPlan.userId,
      goalId: newGoalId,
      name: '${originalPlan.name} (Copy)',
      description: originalPlan.description,
      startDate: startDate,
      endDate: endDate,
      repeatRule: originalPlan.repeatRule,
      taskConfig: originalPlan.taskConfig,
    );
  }

  /// Get plans by task type
  Future<List<PlanModel>> getPlansByTaskType({
    required String userId,
    required TaskType taskType,
  }) async {
    final plans = await _planRepository.getActivePlans(userId);
    return plans.where((p) => p.taskConfig.taskType == taskType).toList();
  }

  /// Validate plan creation
  Future<PlanValidationResult> _validatePlanCreation({
    required String userId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required RepeatRule repeatRule,
    required TaskConfiguration taskConfig,
  }) async {
    final errors = <String>[];

    // 1. Name validation
    if (name.trim().isEmpty) {
      errors.add('Plan name cannot be empty');
    }
    if (name.length > 100) {
      errors.add('Plan name is too long (max 100 characters)');
    }

    // 2. Check for duplicate name (names are unique within user scope)
    final existingPlans = await _planRepository.getActivePlans(userId);
    final isDuplicate = existingPlans.any((p) => p.name == name && !p.isDeleted);
    if (isDuplicate) {
      errors.add('A plan with this name already exists');
    }

    // 3. Date validation
    if (endDate.isBefore(startDate)) {
      errors.add('End date cannot be before start date');
    }
    if (startDate.isAfter(endDate)) {
      errors.add('Start date cannot be after end date');
    }

    // 4. Repeat rule validation
    if (!repeatRule.isValid) {
      errors.add('Invalid repeat rule configuration');
    }

    // 5. Task configuration validation
    if (!taskConfig.isValid) {
      errors.add('Invalid task configuration');
    }

    // 6. Check for overlapping timer tasks
    if (taskConfig.taskType == TaskType.timer || taskConfig.taskType == TaskType.timerWithCount) {
      final duration = taskConfig.durationMinutes!;
      if (duration < 1) {
        errors.add('Timer duration must be at least 1 minute');
      }
      if (duration > 240) {
        errors.add('Timer duration cannot exceed 4 hours');
      }
    }

    return PlanValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}