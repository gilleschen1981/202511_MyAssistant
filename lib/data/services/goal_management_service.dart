import 'dart:convert';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/domain/repositories/i_goal_repository.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/core/errors/exceptions.dart';
import 'package:myassistant/core/utils/app_logger.dart';
import 'package:myassistant/data/data_sources/local/database/app_database.dart';
import 'package:myassistant/data/services/task_generation_service.dart';

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
  final TaskGenerationService _generationService;

  GoalManagementService({
    required IGoalRepository goalRepository,
    required IPlanRepository planRepository,
    required ITaskRepository taskRepository,
    required TaskGenerationService generationService,
  })  : _goalRepository = goalRepository,
        _planRepository = planRepository,
        _taskRepository = taskRepository,
        _generationService = generationService;

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

    // 4. Check if deadline changed (need to cascade update plans)
    final deadlineChanged = deadline != goal.deadline;

    // 5. If deadline changed and not null, validate against all plans
    if (deadlineChanged && deadline != null) {
      final plans = await _planRepository.getGoalPlans(goalId);
      for (final plan in plans) {
        if (plan.status != PlanStatus.deleted && deadline.isBefore(plan.startDate)) {
          throw ValidationException(
            '目标截止日期不能早于计划"${plan.name}"的开始日期 (${plan.startDate.toString().substring(0, 10)})',
          );
        }
      }
    }

    // 6. Use database transaction to update both goal and plans
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      // 6.1 Update goal
      final goalMap = <String, dynamic>{
        'title': title ?? goal.title,
        'description': description ?? goal.description,
        'priority': (priority ?? goal.priority).toDbString(),
        'success_criteria': successCriteria ?? goal.successCriteria,
        'updated_at': AppDatabase.getCurrentTimestamp(),
      };

      // Handle tags (must use JSON encoding for array)
      if (tags != null) {
        goalMap['tags'] = jsonEncode(tags);
      }

      // Handle deadline (fix bug: explicitly set null when cleared)
      if (deadline != null) {
        goalMap['deadline'] = AppDatabase.dateTimeToTimestamp(deadline);
      } else if (deadlineChanged) {
        goalMap['deadline'] = null;
      }

      await txn.update(
        'goals',
        goalMap,
        where: 'id = ?',
        whereArgs: [goalId],
      );

      // 6.2 If deadline changed, cascade update all plans
      if (deadlineChanged) {
        // Calculate new endDate for plans
        // If deadline is null, set plans' endDate to 100 years in future
        final newEndDate = deadline ?? DateTime.now().add(const Duration(days: 36500));

        await txn.update(
          'plans',
          {
            'end_date': AppDatabase.dateTimeToTimestamp(newEndDate),
            'updated_at': AppDatabase.getCurrentTimestamp(),
          },
          where: 'goal_id = ? AND status != ?',
          whereArgs: [goalId, PlanStatus.deleted.toDbString()],
        );

        AppLogger.i(
          'Cascade updated plans for goal $goalId with new endDate: $newEndDate',
          tag: 'GoalManagementService',
        );
      }
    });

    // 7. Re-query and return updated goal
    final updatedGoal = await _goalRepository.getGoalById(goalId);
    if (updatedGoal == null) {
      throw const NotFoundException('Goal not found after update');
    }

    return updatedGoal;
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

  /// Resume a paused goal
  ///
  /// Marks a paused goal and all its associated plans as active.
  /// Uses database transaction to ensure atomicity.
  ///
  /// Parameters:
  /// - [goalId]: The ID of the goal to resume
  ///
  /// Returns:
  /// - The updated goal object
  ///
  /// Throws:
  /// - [NotFoundException]: Goal not found
  /// - [BusinessException]: Goal is not paused
  Future<GoalModel> resumeGoal(String goalId) async {
    AppLogger.i('Resuming goal: $goalId', tag: 'GoalManagementService');

    // 1. Get and validate goal
    final goal = await _goalRepository.getGoalById(goalId);
    if (goal == null) {
      throw const NotFoundException('目标不存在');
    }

    AppLogger.d('Goal status BEFORE: ${goal.status}', tag: 'GoalManagementService');

    if (goal.status != GoalStatus.paused) {
      throw const BusinessException('只能恢复暂停的目标');
    }

    // 2. Get all plans for this goal
    final plans = await _planRepository.getGoalPlans(goalId);
    AppLogger.d('Found ${plans.length} plans for goal', tag: 'GoalManagementService');

    // 3. Use database transaction to ensure atomicity
    final db = await AppDatabase.instance.database;
    AppLogger.d('Starting database transaction...', tag: 'GoalManagementService');

    try {
      await db.transaction((txn) async {
        AppLogger.d('Inside transaction', tag: 'GoalManagementService');

        // 3.1 Update all plans to active status
        int totalPlansUpdated = 0;
        for (final plan in plans) {
          if (plan.status == PlanStatus.paused) {
            final rowsAffected = await txn.update(
              'plans',
              {
                'status': PlanStatus.active.toDbString(),
                'updated_at': AppDatabase.getCurrentTimestamp(),
              },
              where: 'id = ?',
              whereArgs: [plan.id],
            );
            totalPlansUpdated += rowsAffected;
            AppLogger.d('Updated plan ${plan.id} (${plan.name}), rows affected: $rowsAffected', tag: 'GoalManagementService');
          }
        }
        AppLogger.d('Total plans updated: $totalPlansUpdated', tag: 'GoalManagementService');

        // 3.2 Update goal to active status
        final activeStatus = GoalStatus.active.toDbString();
        AppLogger.d('Updating goal to status: $activeStatus', tag: 'GoalManagementService');

        final goalRowsAffected = await txn.update(
          'goals',
          {
            'status': activeStatus,
            'updated_at': AppDatabase.getCurrentTimestamp(),
          },
          where: 'id = ?',
          whereArgs: [goalId],
        );
        AppLogger.d('Goal update rows affected: $goalRowsAffected', tag: 'GoalManagementService');

        if (goalRowsAffected == 0) {
          AppLogger.w('WARNING: Goal update affected 0 rows!', tag: 'GoalManagementService');
        }
      });

      AppLogger.i('Transaction completed successfully', tag: 'GoalManagementService');
    } catch (e) {
      AppLogger.e('Failed to resume goal', tag: 'GoalManagementService', error: e);
      throw BusinessException('恢复目标失败: ${e.toString()}');
    }

    // 4. Restore or create tasks for all active plans in current execution window
    AppLogger.d('Restoring/creating tasks for resumed plans...', tag: 'GoalManagementService');
    final updatedPlans = await _planRepository.getGoalPlans(goalId);
    int tasksRestored = 0;
    int tasksCreated = 0;

    for (final plan in updatedPlans) {
      if (plan.status == PlanStatus.active && !plan.isDeleted) {
        AppLogger.d('Processing plan: ${plan.name} (${plan.id})', tag: 'GoalManagementService');

        // 4.1 Calculate current execution window
        final window = _calculateCurrentExecutionWindow(plan);
        AppLogger.d('Current execution window: ${window.start} - ${window.end}', tag: 'GoalManagementService');

        // 4.2 Get all tasks for this plan
        final tasks = await _taskRepository.getPlanTasks(plan.id);
        AppLogger.d('Found ${tasks.length} total tasks for plan', tag: 'GoalManagementService');

        // 4.3 Find tasks in current execution window
        final tasksInWindow = tasks.where((task) =>
          task.windowStartTime.isBefore(window.end) &&
          task.windowEndTime.isAfter(window.start)
        ).toList();
        AppLogger.d('Found ${tasksInWindow.length} tasks in current window', tag: 'GoalManagementService');

        // 4.4 Check for deleted tasks in current window
        final deletedTasksInWindow = tasksInWindow.where((task) =>
          task.status == TaskStatus.deleted
        ).toList();

        if (deletedTasksInWindow.isNotEmpty) {
          // 4.5 Restore deleted tasks to active status
          AppLogger.i('Restoring ${deletedTasksInWindow.length} deleted task(s) for plan ${plan.name}', tag: 'GoalManagementService');
          for (final task in deletedTasksInWindow) {
            await _taskRepository.updateTaskStatus(
              taskId: task.id,
              status: TaskStatus.active,
              clearDeletedAt: true,
            );
            tasksRestored++;
            AppLogger.i('✓ Task restored: ${task.name} (${task.id})', tag: 'GoalManagementService');
          }
        } else {
          // 4.6 No deleted task in current window, generate new one
          AppLogger.d('No deleted task in window, generating new task for plan ${plan.name}', tag: 'GoalManagementService');
          final task = await _generationService.generateNextTask(plan);
          if (task != null) {
            tasksCreated++;
            AppLogger.i('✓ Task created: ${task.name} for plan ${plan.name}', tag: 'GoalManagementService');
          } else {
            AppLogger.d('✗ No task created for plan ${plan.name} (may already have active task)', tag: 'GoalManagementService');
          }
        }
      }
    }
    AppLogger.i('Restored $tasksRestored tasks, created $tasksCreated new tasks for ${updatedPlans.length} plans', tag: 'GoalManagementService');

    // 5. Re-query and return updated goal
    AppLogger.d('Re-querying goal from database...', tag: 'GoalManagementService');
    final updatedGoal = await _goalRepository.getGoalById(goalId);
    if (updatedGoal == null) {
      throw const NotFoundException('Goal not found after update');
    }

    AppLogger.d('Goal status AFTER: ${updatedGoal.status}', tag: 'GoalManagementService');
    AppLogger.i('Goal resumed successfully', tag: 'GoalManagementService');

    return updatedGoal;
  }

  /// Pause a goal
  ///
  /// Marks a goal and all its associated plans and active tasks as paused/deleted.
  /// Uses database transaction to ensure atomicity.
  ///
  /// Parameters:
  /// - [goalId]: The ID of the goal to pause
  ///
  /// Returns:
  /// - The updated goal object
  ///
  /// Throws:
  /// - [NotFoundException]: Goal not found
  /// - [BusinessException]: Goal is already paused, completed, or deleted
  Future<GoalModel> pauseGoal(String goalId) async {
    AppLogger.i('Pausing goal: $goalId', tag: 'GoalManagementService');

    // 1. Get and validate goal
    final goal = await _goalRepository.getGoalById(goalId);
    if (goal == null) {
      throw const NotFoundException('目标不存在');
    }

    AppLogger.d('Goal status BEFORE: ${goal.status}', tag: 'GoalManagementService');

    if (goal.status == GoalStatus.paused) {
      throw const BusinessException('目标已暂停，无法重复暂停');
    }

    if (goal.status == GoalStatus.completed) {
      throw const BusinessException('已完成的目标无法暂停');
    }

    if (goal.status == GoalStatus.deleted) {
      throw const BusinessException('已删除的目标无法暂停');
    }

    // 2. Get all plans for this goal
    final plans = await _planRepository.getGoalPlans(goalId);
    AppLogger.d('Found ${plans.length} plans for goal', tag: 'GoalManagementService');

    // 3. Get all tasks for all plans (before transaction)
    final Map<String, List<TaskModel>> planTasksMap = {};
    for (final plan in plans) {
      final tasks = await _taskRepository.getPlanTasks(plan.id);
      planTasksMap[plan.id] = tasks;
    }

    // 4. Use database transaction to ensure atomicity
    final db = await AppDatabase.instance.database;
    AppLogger.d('Starting database transaction...', tag: 'GoalManagementService');

    try {
      await db.transaction((txn) async {
        AppLogger.d('Inside transaction', tag: 'GoalManagementService');

        // 4.1 Soft delete all active tasks in current execution window for all plans
        int totalTasksDeleted = 0;
        for (final plan in plans) {
          final tasks = planTasksMap[plan.id] ?? [];

          // Filter active tasks in current execution window
          final tasksToDelete = tasks.where((task) =>
            task.status == TaskStatus.active && task.isInCurrentWindow
          ).toList();

          AppLogger.d('Deleting ${tasksToDelete.length} tasks for plan ${plan.name}', tag: 'GoalManagementService');

          // Soft delete these tasks
          for (final task in tasksToDelete) {
            final rowsAffected = await txn.update(
              'tasks',
              {
                'status': TaskStatus.deleted.toDbString(),
                'deleted_at': AppDatabase.getCurrentTimestamp(),
                'execution_note': '目标已暂停',
              },
              where: 'id = ?',
              whereArgs: [task.id],
            );
            totalTasksDeleted += rowsAffected;
            AppLogger.d('Deleted task ${task.id}, rows affected: $rowsAffected', tag: 'GoalManagementService');
          }
        }
        AppLogger.d('Total tasks deleted: $totalTasksDeleted', tag: 'GoalManagementService');

        // 4.2 Update all plans to paused status
        int totalPlansUpdated = 0;
        for (final plan in plans) {
          if (plan.status != PlanStatus.deleted) {
            final rowsAffected = await txn.update(
              'plans',
              {
                'status': PlanStatus.paused.toDbString(),
                'updated_at': AppDatabase.getCurrentTimestamp(),
              },
              where: 'id = ?',
              whereArgs: [plan.id],
            );
            totalPlansUpdated += rowsAffected;
            AppLogger.d('Updated plan ${plan.id} (${plan.name}), rows affected: $rowsAffected', tag: 'GoalManagementService');
          }
        }
        AppLogger.d('Total plans updated: $totalPlansUpdated', tag: 'GoalManagementService');

        // 4.3 Update goal to paused status
        final pausedStatus = GoalStatus.paused.toDbString();
        AppLogger.d('Updating goal to status: $pausedStatus', tag: 'GoalManagementService');

        final goalRowsAffected = await txn.update(
          'goals',
          {
            'status': pausedStatus,
            'updated_at': AppDatabase.getCurrentTimestamp(),
          },
          where: 'id = ?',
          whereArgs: [goalId],
        );
        AppLogger.d('Goal update rows affected: $goalRowsAffected', tag: 'GoalManagementService');

        if (goalRowsAffected == 0) {
          AppLogger.w('WARNING: Goal update affected 0 rows!', tag: 'GoalManagementService');
        }
      });

      AppLogger.i('Transaction completed successfully', tag: 'GoalManagementService');
    } catch (e) {
      AppLogger.e('Failed to pause goal', tag: 'GoalManagementService', error: e);
      throw BusinessException('暂停目标失败: ${e.toString()}');
    }

    // 5. Re-query and return updated goal
    AppLogger.d('Re-querying goal from database...', tag: 'GoalManagementService');
    final updatedGoal = await _goalRepository.getGoalById(goalId);
    if (updatedGoal == null) {
      throw const NotFoundException('Goal not found after update');
    }

    AppLogger.d('Goal status AFTER: ${updatedGoal.status}', tag: 'GoalManagementService');
    AppLogger.i('Goal paused successfully', tag: 'GoalManagementService');

    return updatedGoal;
  }

  /// Complete a goal
  ///
  /// Marks a goal and all its associated plans and active tasks as completed.
  /// Uses database transaction to ensure atomicity.
  ///
  /// Parameters:
  /// - [goalId]: The ID of the goal to complete
  ///
  /// Returns:
  /// - The updated goal object
  ///
  /// Throws:
  /// - [NotFoundException]: Goal not found
  /// - [BusinessException]: Goal is already completed or deleted
  Future<GoalModel> completeGoal(String goalId) async {
    AppLogger.i('Completing goal: $goalId', tag: 'GoalManagementService');

    // 1. Get and validate goal
    final goal = await _goalRepository.getGoalById(goalId);
    if (goal == null) {
      throw const NotFoundException('Goal not found');
    }

    AppLogger.d('Goal status BEFORE: ${goal.status}', tag: 'GoalManagementService');

    if (goal.status == GoalStatus.completed) {
      throw const BusinessException('Goal is already completed');
    }

    if (goal.status == GoalStatus.deleted) {
      throw const BusinessException('Deleted goal cannot be completed');
    }

    // 2. Get all plans for this goal
    final plans = await _planRepository.getGoalPlans(goalId);
    AppLogger.d('Found ${plans.length} plans for goal', tag: 'GoalManagementService');

    // 3. Get all tasks for all plans (before transaction)
    final Map<String, List<TaskModel>> planTasksMap = {};
    for (final plan in plans) {
      final tasks = await _taskRepository.getPlanTasks(plan.id);
      planTasksMap[plan.id] = tasks;
    }

    // 4. Use database transaction to ensure atomicity
    final db = await AppDatabase.instance.database;
    AppLogger.d('Starting database transaction...', tag: 'GoalManagementService');

    try {
      await db.transaction((txn) async {
        AppLogger.d('Inside transaction', tag: 'GoalManagementService');

        // 4.1 Skip all active tasks in current execution window for all plans
        int totalTasksSkipped = 0;
        for (final plan in plans) {
          final tasks = planTasksMap[plan.id] ?? [];

          // Filter active tasks in current execution window
          final tasksToSkip = tasks.where((task) =>
            task.status == TaskStatus.active && task.isInCurrentWindow
          ).toList();

          AppLogger.d('Skipping ${tasksToSkip.length} tasks for plan ${plan.name}', tag: 'GoalManagementService');

          // Skip these tasks
          for (final task in tasksToSkip) {
            final rowsAffected = await txn.update(
              'tasks',
              {
                'status': TaskStatus.skipped.toDbString(),
                'skipped_at': AppDatabase.getCurrentTimestamp(),
                'execution_note': '目标已完成',
              },
              where: 'id = ?',
              whereArgs: [task.id],
            );
            totalTasksSkipped += rowsAffected;
            AppLogger.d('Skipped task ${task.id}, rows affected: $rowsAffected', tag: 'GoalManagementService');
          }
        }
        AppLogger.d('Total tasks skipped: $totalTasksSkipped', tag: 'GoalManagementService');

        // 4.2 Update all plans to completed status
        int totalPlansUpdated = 0;
        for (final plan in plans) {
          if (plan.status != PlanStatus.deleted) {
            final rowsAffected = await txn.update(
              'plans',
              {
                'status': PlanStatus.completed.toDbString(),
                'updated_at': AppDatabase.getCurrentTimestamp(),
              },
              where: 'id = ?',
              whereArgs: [plan.id],
            );
            totalPlansUpdated += rowsAffected;
            AppLogger.d('Updated plan ${plan.id} (${plan.name}), rows affected: $rowsAffected', tag: 'GoalManagementService');
          }
        }
        AppLogger.d('Total plans updated: $totalPlansUpdated', tag: 'GoalManagementService');

        // 4.3 Update goal to completed status
        final completedStatus = GoalStatus.completed.toDbString();
        AppLogger.d('Updating goal to status: $completedStatus', tag: 'GoalManagementService');

        final goalRowsAffected = await txn.update(
          'goals',
          {
            'status': completedStatus,
            'updated_at': AppDatabase.getCurrentTimestamp(),
          },
          where: 'id = ?',
          whereArgs: [goalId],
        );
        AppLogger.d('Goal update rows affected: $goalRowsAffected', tag: 'GoalManagementService');

        if (goalRowsAffected == 0) {
          AppLogger.w('WARNING: Goal update affected 0 rows!', tag: 'GoalManagementService');
        }
      });

      AppLogger.i('Transaction completed successfully', tag: 'GoalManagementService');
    } catch (e) {
      AppLogger.e('Failed to complete goal', tag: 'GoalManagementService', error: e);
      throw BusinessException('完成目标失败: ${e.toString()}');
    }

    // 5. Re-query and return updated goal
    AppLogger.d('Re-querying goal from database...', tag: 'GoalManagementService');
    final updatedGoal = await _goalRepository.getGoalById(goalId);
    if (updatedGoal == null) {
      throw const NotFoundException('Goal not found after update');
    }

    AppLogger.d('Goal status AFTER: ${updatedGoal.status}', tag: 'GoalManagementService');
    AppLogger.i('Goal completed successfully', tag: 'GoalManagementService');

    return updatedGoal;
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

  /// Calculate current execution window for a plan
  ({DateTime start, DateTime end}) _calculateCurrentExecutionWindow(PlanModel plan) {
    final now = DateTime.now();
    DateTime windowStart;
    DateTime windowEnd;

    switch (plan.repeatRule.type) {
      case RepeatType.oneTime:
        windowStart = plan.startDate;
        windowEnd = plan.endDate;
        break;
      case RepeatType.daily:
        windowStart = _getStartOfDay(now);
        windowEnd = _getEndOfDay(now);
        break;
      case RepeatType.weekly:
        windowStart = _getStartOfWeek(now);
        windowEnd = _getEndOfWeek(now);
        break;
      case RepeatType.monthly:
        windowStart = _getStartOfMonth(now);
        windowEnd = _getEndOfMonth(now);
        break;
      case RepeatType.daysOfWeek:
        // For daysOfWeek, window is weekly (same as weekly type)
        windowStart = _getStartOfWeek(now);
        windowEnd = _getEndOfWeek(now);
        break;
      case RepeatType.custom:
        // For custom, use current day as start
        windowStart = _getStartOfDay(now);
        final days = (plan.repeatRule.customDays ?? 1) - 1;
        windowEnd = windowStart.add(Duration(days: days));
        windowEnd = _getEndOfDay(windowEnd);
        break;
    }

    // Ensure not exceeding plan end date
    if (windowEnd.isAfter(plan.endDate)) {
      windowEnd = plan.endDate;
    }

    return (start: windowStart, end: windowEnd);
  }

  // Helper methods for date calculations
  DateTime _getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  DateTime _getStartOfWeek(DateTime date) {
    // Monday as start of week
    final weekday = date.weekday;
    return _getStartOfDay(date.subtract(Duration(days: weekday - 1)));
  }

  DateTime _getEndOfWeek(DateTime date) {
    // Sunday as end of week
    final weekday = date.weekday;
    return _getEndOfDay(date.add(Duration(days: 7 - weekday)));
  }

  DateTime _getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _getEndOfMonth(DateTime date) {
    final nextMonth = date.month == 12 ? 1 : date.month + 1;
    final nextYear = date.month == 12 ? date.year + 1 : date.year;
    final lastDay = DateTime(nextYear, nextMonth, 1).subtract(const Duration(days: 1));
    return _getEndOfDay(lastDay);
  }
}