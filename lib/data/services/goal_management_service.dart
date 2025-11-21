import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/domain/repositories/i_goal_repository.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/core/errors/exceptions.dart';
import 'package:myassistant/core/utils/app_logger.dart';

/// Goal statistics
class GoalStatistics {
  final int totalPlans;
  final int activePlans;
  final int completedPlans;
  final int totalTasks;
  final int completedTasks;
  final double overallProgress;
  final int daysRemaining;
  final double dailyProgress;

  GoalStatistics({
    required this.totalPlans,
    required this.activePlans,
    required this.completedPlans,
    required this.totalTasks,
    required this.completedTasks,
    required this.overallProgress,
    required this.daysRemaining,
    required this.dailyProgress,
  });
}

/// Goal achievement result
class GoalAchievementResult {
  final GoalModel goal;
  final bool isAchieved;
  final String achievementLevel;
  final Map<String, dynamic> details;

  GoalAchievementResult({
    required this.goal,
    required this.isAchieved,
    required this.achievementLevel,
    required this.details,
  });
}

/// Goal management service - handles goal lifecycle and progress tracking
class GoalManagementService {
  final IGoalRepository _goalRepository;
  final IPlanRepository _planRepository;
  final ITaskRepository _taskRepository;

  GoalManagementService({
    required IGoalRepository goalRepository,
    required IPlanRepository planRepository,
    required ITaskRepository taskRepository,
  })  : _goalRepository = goalRepository,
        _planRepository = planRepository,
        _taskRepository = taskRepository;

  /// Create a new goal
  Future<GoalModel> createGoal({
    required String userId,
    required String title,
    String? description,
    DateTime? deadline,
    Priority priority = Priority.medium,
    List<String>? tags,
    String? successCriteria,
  }) async {
    AppLogger.d('createGoal called: userId=$userId, title=$title', tag: 'GoalManagementService');

    // 1. Validate input
    AppLogger.d('Validating input...', tag: 'GoalManagementService');
    _validateGoalInput(title, description, deadline);
    AppLogger.d('Input validation passed', tag: 'GoalManagementService');

    // 2. Check for duplicate goals
    AppLogger.d('Checking for duplicate goals...', tag: 'GoalManagementService');
    final existingGoals = await _goalRepository.getUserGoals(userId);
    AppLogger.d('Found ${existingGoals.length} existing goals', tag: 'GoalManagementService');
    final isDuplicate = existingGoals.any(
      (g) => g.title.toLowerCase() == title.toLowerCase() && g.deletedAt == null,
    );

    if (isDuplicate) {
      AppLogger.w('Duplicate goal found with title: $title', tag: 'GoalManagementService');
      throw const ValidationException('A goal with this title already exists');
    }
    AppLogger.d('No duplicate found', tag: 'GoalManagementService');

    // 3. Create goal
    AppLogger.d('Creating goal...', tag: 'GoalManagementService');
    try {
      final result = await _goalRepository.createGoal(
        userId: userId,
        title: title,
        description: description,
        deadline: deadline,
        priority: priority,
        tags: tags,
        successCriteria: successCriteria,
      );
      AppLogger.i('Goal created successfully: ${result.id}', tag: 'GoalManagementService');
      return result;
    } catch (e) {
      AppLogger.e('Error creating goal: $e', tag: 'GoalManagementService', error: e);
      rethrow;
    }
  }

  /// Update goal
  Future<GoalModel> updateGoal({
    required String goalId,
    String? title,
    String? description,
    DateTime? deadline,
    Priority? priority,
    List<String>? tags,
    String? successCriteria,
  }) async {
    // 1. Get existing goal
    final goal = await _goalRepository.getGoalById(goalId);
    if (goal == null) {
      throw const NotFoundException('Goal not found');
    }

    // 2. Check if goal is completed
    if (goal.status == GoalStatus.completed) {
      throw const BusinessException('Cannot update completed goal');
    }

    // 3. Validate new values
    if (deadline != null && deadline.isBefore(DateTime.now())) {
      throw const ValidationException('Deadline cannot be in the past');
    }

    // 4. Create updated goal model
    final updatedGoal = goal.copyWith(
      title: title ?? goal.title,
      description: description ?? goal.description,
      deadline: deadline ?? goal.deadline,
      priority: priority ?? goal.priority,
      tags: tags ?? goal.tags,
      successCriteria: successCriteria ?? goal.successCriteria,
      updatedAt: DateTime.now(),
    );

    // 5. Update goal
    return await _goalRepository.updateGoal(updatedGoal);
  }

  /// Archive goal (soft delete)
  Future<bool> archiveGoal(String goalId) async {
    // 1. Get goal
    final goal = await _goalRepository.getGoalById(goalId);
    if (goal == null) {
      throw const NotFoundException('Goal not found');
    }

    // 2. Check if already deleted
    if (goal.isDeleted) {
      throw const BusinessException('Goal is already deleted');
    }

    // 3. Check for active plans
    final plans = await _planRepository.getGoalPlans(goalId);
    final hasActivePlans = plans.any((p) => p.isActive);

    if (hasActivePlans) {
      throw const BusinessException('Cannot archive goal with active plans');
    }

    // 4. Delete the goal (soft delete)
    return await _goalRepository.deleteGoal(goalId);
  }

  /// Delete goal and all associated plans
  /// Note: Tasks will be cascaded deleted when plans are deleted
  Future<bool> deleteGoal(String goalId) async {
    AppLogger.d('deleteGoal called with goalId: $goalId', tag: 'GoalManagementService');

    // 1. Get goal
    AppLogger.d('Fetching goal...', tag: 'GoalManagementService');
    final goal = await _goalRepository.getGoalById(goalId);
    if (goal == null) {
      AppLogger.w('Goal not found: $goalId', tag: 'GoalManagementService');
      throw const NotFoundException('Goal not found');
    }
    AppLogger.d('Goal found: ${goal.id}, status: ${goal.status}', tag: 'GoalManagementService');

    // 2. Get all plans for this goal
    AppLogger.d('Fetching plans for goal...', tag: 'GoalManagementService');
    final plans = await _planRepository.getGoalPlans(goalId);
    AppLogger.d('Found ${plans.length} plans', tag: 'GoalManagementService');

    // 3. Delete all plans (tasks will be cascade deleted)
    AppLogger.d('Deleting ${plans.length} plans...', tag: 'GoalManagementService');
    for (final plan in plans) {
      AppLogger.d('Deleting plan: ${plan.id}', tag: 'GoalManagementService');
      await _planRepository.deletePlan(plan.id);
    }
    AppLogger.d('All plans deleted', tag: 'GoalManagementService');

    // 4. Delete the goal
    AppLogger.d('Deleting goal...', tag: 'GoalManagementService');
    final result = await _goalRepository.deleteGoal(goalId);
    AppLogger.i('Goal deletion result: $result', tag: 'GoalManagementService');
    return result;
  }

  /// Calculate goal progress
  Future<GoalStatistics> calculateGoalProgress(String goalId) async {
    // 1. Get goal
    final goal = await _goalRepository.getGoalById(goalId);
    if (goal == null) {
      throw const NotFoundException('Goal not found');
    }

    // 2. Get all plans for this goal
    final plans = await _planRepository.getGoalPlans(goalId);

    // 3. Calculate plan statistics
    int activePlans = 0;
    int completedPlans = 0;
    int totalTasks = 0;
    int completedTasks = 0;

    for (final plan in plans) {
      if (plan.isActive) {
        activePlans++;
      }
      // A plan is considered completed if it has ended
      if (plan.hasEnded) {
        completedPlans++;
      }

      // Get tasks for this plan
      final tasks = await _taskRepository.getPlanTasks(plan.id);
      totalTasks += tasks.length;
      completedTasks += tasks.where((t) => t.status == TaskStatus.completed).length;
    }

    // 4. Calculate overall progress
    double overallProgress = 0.0;
    if (totalTasks > 0) {
      overallProgress = completedTasks / totalTasks;
    }

    // 5. Calculate days remaining
    final daysRemaining = goal.deadline != null
        ? goal.deadline!.difference(DateTime.now()).inDays
        : -1; // -1 indicates no deadline

    // 6. Calculate daily progress
    final daysPassed = DateTime.now().difference(goal.createdAt).inDays;
    final dailyProgress = daysPassed > 0 ? overallProgress / daysPassed : 0.0;

    return GoalStatistics(
      totalPlans: plans.length,
      activePlans: activePlans,
      completedPlans: completedPlans,
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      overallProgress: overallProgress,
      daysRemaining: daysRemaining,
      dailyProgress: dailyProgress,
    );
  }

  /// Check goal achievement
  Future<GoalAchievementResult> checkGoalAchievement(String goalId) async {
    // 1. Get goal and statistics
    final goal = await _goalRepository.getGoalById(goalId);
    if (goal == null) {
      throw const NotFoundException('Goal not found');
    }

    final stats = await calculateGoalProgress(goalId);

    // 2. Determine achievement status
    bool isAchieved = false;
    String achievementLevel = 'Not Achieved';
    Map<String, dynamic> details = {};

    if (stats.overallProgress >= 1.0) {
      isAchieved = true;
      achievementLevel = 'Fully Achieved';
      details['completionDate'] = DateTime.now().toIso8601String();
    } else if (stats.overallProgress >= 0.8) {
      achievementLevel = 'Mostly Achieved';
      details['progress'] = '${(stats.overallProgress * 100).toStringAsFixed(1)}%';
    } else if (stats.overallProgress >= 0.5) {
      achievementLevel = 'Partially Achieved';
      details['progress'] = '${(stats.overallProgress * 100).toStringAsFixed(1)}%';
    } else if (stats.overallProgress >= 0.2) {
      achievementLevel = 'Limited Progress';
      details['progress'] = '${(stats.overallProgress * 100).toStringAsFixed(1)}%';
    } else {
      achievementLevel = 'Minimal Progress';
      details['progress'] = '${(stats.overallProgress * 100).toStringAsFixed(1)}%';
    }

    details['totalPlans'] = stats.totalPlans;
    details['completedPlans'] = stats.completedPlans;
    details['totalTasks'] = stats.totalTasks;
    details['completedTasks'] = stats.completedTasks;
    details['daysRemaining'] = stats.daysRemaining;

    // 3. Update goal status if achieved
    if (isAchieved && goal.status != GoalStatus.completed) {
      final completedGoal = goal.copyWith(
        status: GoalStatus.completed,
        updatedAt: DateTime.now(),
      );
      await _goalRepository.updateGoal(completedGoal);
    }

    return GoalAchievementResult(
      goal: goal,
      isAchieved: isAchieved,
      achievementLevel: achievementLevel,
      details: details,
    );
  }

  /// Get goal recommendations
  Future<List<String>> getGoalRecommendations(String goalId) async {
    final recommendations = <String>[];

    // 1. Get goal and statistics
    final goal = await _goalRepository.getGoalById(goalId);
    if (goal == null) {
      throw const NotFoundException('Goal not found');
    }

    final stats = await calculateGoalProgress(goalId);

    // 2. Check progress rate
    if (stats.dailyProgress < 0.01 && stats.daysRemaining > 7) {
      recommendations.add('Your progress is slow. Consider creating more specific plans.');
    }

    // 3. Check active plans
    if (stats.activePlans == 0 && stats.daysRemaining > 0) {
      recommendations.add('No active plans. Create new plans to achieve your goal.');
    }

    // 4. Check task completion rate
    if (stats.totalTasks > 0) {
      final taskCompletionRate = stats.completedTasks / stats.totalTasks;
      if (taskCompletionRate < 0.5) {
        recommendations.add('Low task completion rate. Focus on completing existing tasks.');
      }
    }

    // 5. Check deadline
    if (stats.daysRemaining > 0 && stats.daysRemaining <= 7 && stats.overallProgress < 0.8) {
      recommendations.add('Deadline approaching! Prioritize critical plans.');
    } else if (stats.daysRemaining == 0 && goal.status != GoalStatus.completed) {
      recommendations.add('Goal deadline has passed. Consider extending the deadline.');
    }

    // 6. Check plan distribution
    if (stats.totalPlans > 10) {
      recommendations.add('Many plans created. Consider consolidating similar plans.');
    } else if (stats.totalPlans == 0) {
      recommendations.add('No plans created yet. Start by creating your first plan.');
    }

    return recommendations;
  }

  /// Get goals by tags
  Future<Map<String, List<GoalModel>>> getGoalsByTags(String userId) async {
    final goals = await _goalRepository.getUserGoals(userId);
    final goalsByTag = <String, List<GoalModel>>{};

    for (final goal in goals) {
      if (goal.deletedAt == null) {
        for (final tag in goal.tags) {
          goalsByTag.putIfAbsent(tag, () => []).add(goal);
        }
      }
    }

    return goalsByTag;
  }

  /// Get goals approaching deadline
  Future<List<GoalModel>> getGoalsApproachingDeadline({
    required String userId,
    int daysThreshold = 7,
  }) async {
    final goals = await _goalRepository.getUserGoals(userId);
    final approachingGoals = <GoalModel>[];
    final thresholdDate = DateTime.now().add(Duration(days: daysThreshold));

    for (final goal in goals) {
      if (goal.deletedAt == null &&
          goal.status != GoalStatus.completed &&
          goal.deadline != null &&
          goal.deadline!.isBefore(thresholdDate)) {
        approachingGoals.add(goal);
      }
    }

    // Sort by deadline (nearest first)
    approachingGoals.sort((a, b) {
      if (a.deadline == null) return 1;
      if (b.deadline == null) return -1;
      return a.deadline!.compareTo(b.deadline!);
    });

    return approachingGoals;
  }

  /// Validate goal input
  void _validateGoalInput(String title, String? description, DateTime? deadline) {
    // Title validation
    if (title.trim().isEmpty) {
      throw const ValidationException('Goal title cannot be empty');
    }
    if (title.length > 100) {
      throw const ValidationException('Goal title is too long (max 100 characters)');
    }

    // Description validation (optional)
    if (description != null && description.length > 500) {
      throw const ValidationException('Goal description is too long (max 500 characters)');
    }

    // Deadline validation (optional)
    if (deadline != null) {
      if (deadline.isBefore(DateTime.now())) {
        throw const ValidationException('Deadline cannot be in the past');
      }
      if (deadline.isAfter(DateTime.now().add(const Duration(days: 365 * 5)))) {
        throw const ValidationException('Deadline is too far in the future (max 5 years)');
      }
    }
  }
}