import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_review_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';

/// Service for plan review and statistics
class PlanReviewService {
  final IPlanRepository _planRepository;
  final ITaskRepository _taskRepository;

  PlanReviewService({
    required IPlanRepository planRepository,
    required ITaskRepository taskRepository,
  })  : _planRepository = planRepository,
        _taskRepository = taskRepository;

  /// Get all plans with their statistics for review
  Future<List<PlanReviewModel>> getUserPlanReviews(String userId) async {
    final plans = await _planRepository.getUserPlans(userId);
    final reviews = <PlanReviewModel>[];

    for (final plan in plans) {
      final review = await getPlanReview(plan.id);
      if (review != null) {
        reviews.add(review);
      }
    }

    return reviews;
  }

  /// Get plan review for a specific plan
  Future<PlanReviewModel?> getPlanReview(String planId) async {
    final plan = await _planRepository.getPlanById(planId);
    if (plan == null) return null;

    // Get all tasks for this plan
    final tasks = await _taskRepository.getPlanTasks(planId);

    // Calculate statistics
    final statistics = _calculateStatistics(tasks);

    return PlanReviewModel(
      plan: plan,
      statistics: statistics,
      tasks: tasks,
    );
  }

  /// Get plan reviews by date range
  Future<List<PlanReviewModel>> getPlanReviewsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final plans = await _planRepository.getPlansByDateRange(
      userId,
      startDate,
      endDate,
    );

    final reviews = <PlanReviewModel>[];
    for (final plan in plans) {
      final review = await getPlanReview(plan.id);
      if (review != null) {
        reviews.add(review);
      }
    }

    return reviews;
  }

  /// Get plan reviews filtered by goal
  Future<List<PlanReviewModel>> getGoalPlanReviews(String goalId) async {
    final plans = await _planRepository.getGoalPlans(goalId);
    final reviews = <PlanReviewModel>[];

    for (final plan in plans) {
      final review = await getPlanReview(plan.id);
      if (review != null) {
        reviews.add(review);
      }
    }

    return reviews;
  }

  /// Calculate statistics from tasks
  PlanReviewStatistics _calculateStatistics(List<TaskModel> tasks) {
    int total = 0;
    int completed = 0;
    int skipped = 0;
    int active = 0;
    double totalDuration = 0;
    int durationCount = 0;
    DateTime? lastCompletedAt;
    DateTime? lastSkippedAt;

    for (final task in tasks) {
      // Skip deleted tasks
      if (task.isDeleted) continue;

      total++;

      switch (task.status) {
        case TaskStatus.completed:
          completed++;
          if (task.completedAt != null) {
            if (lastCompletedAt == null || task.completedAt!.isAfter(lastCompletedAt)) {
              lastCompletedAt = task.completedAt;
            }
          }
          if (task.actualDurationMinutes != null) {
            totalDuration += task.actualDurationMinutes!;
            durationCount++;
          }
          break;
        case TaskStatus.skipped:
          skipped++;
          if (task.skippedAt != null) {
            if (lastSkippedAt == null || task.skippedAt!.isAfter(lastSkippedAt)) {
              lastSkippedAt = task.skippedAt;
            }
          }
          break;
        case TaskStatus.active:
          active++;
          break;
        case TaskStatus.deleted:
          // Already filtered above
          break;
      }
    }

    final completionRate = total > 0 ? completed / total : 0.0;
    final avgDuration = durationCount > 0 ? totalDuration / durationCount : null;

    return PlanReviewStatistics(
      totalTasks: total,
      completedTasks: completed,
      skippedTasks: skipped,
      activeTasks: active,
      completionRate: completionRate,
      avgDurationMinutes: avgDuration,
      lastCompletedTaskAt: lastCompletedAt,
      lastSkippedTaskAt: lastSkippedAt,
    );
  }

  /// Get summary statistics for all user plans
  Future<Map<String, dynamic>> getUserSummaryStatistics(String userId) async {
    final reviews = await getUserPlanReviews(userId);

    int totalPlans = reviews.length;
    int activePlans = reviews.where((r) => r.plan.isActive).length;
    int completedPlans = reviews.where((r) => r.plan.hasEnded).length;

    int totalTasks = 0;
    int completedTasks = 0;
    int skippedTasks = 0;
    double totalCompletionRate = 0;

    for (final review in reviews) {
      totalTasks += review.statistics.totalTasks;
      completedTasks += review.statistics.completedTasks;
      skippedTasks += review.statistics.skippedTasks;
      totalCompletionRate += review.statistics.completionRate;
    }

    final avgCompletionRate = totalPlans > 0 ? totalCompletionRate / totalPlans : 0.0;

    return {
      'totalPlans': totalPlans,
      'activePlans': activePlans,
      'completedPlans': completedPlans,
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'skippedTasks': skippedTasks,
      'averageCompletionRate': avgCompletionRate,
    };
  }

  /// Get plans sorted by completion rate (ascending or descending)
  Future<List<PlanReviewModel>> getPlansSortedByCompletionRate(
    String userId, {
    bool ascending = false,
  }) async {
    final reviews = await getUserPlanReviews(userId);

    reviews.sort((a, b) {
      final comparison = a.statistics.completionRate.compareTo(
        b.statistics.completionRate,
      );
      return ascending ? comparison : -comparison;
    });

    return reviews;
  }

  /// Get plans that need attention (low completion rate or many skipped tasks)
  Future<List<PlanReviewModel>> getPlansNeedingAttention(
    String userId, {
    double completionRateThreshold = 0.5,
    double skippedRateThreshold = 0.3,
  }) async {
    final reviews = await getUserPlanReviews(userId);

    return reviews.where((review) {
      final stats = review.statistics;
      if (stats.totalTasks == 0) return false;

      final skippedRate = stats.skippedTasks / stats.totalTasks;

      return stats.completionRate < completionRateThreshold ||
          skippedRate > skippedRateThreshold;
    }).toList();
  }
}
