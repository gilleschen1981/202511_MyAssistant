import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';

const testUserId = 'user-test';
const testGoalId = 'goal-test';
const testPlanId = 'plan-test';

GoalModel createGoal({
  String id = testGoalId,
  String userId = testUserId,
  String title = 'Test Goal',
  String? description,
  DateTime? deadline,
  Priority priority = Priority.medium,
  GoalStatus status = GoalStatus.active,
  List<String> tags = const [],
  DateTime? deletedAt,
}) {
  final now = DateTime.now();
  return GoalModel(
    id: id,
    userId: userId,
    title: title,
    description: description,
    tags: tags,
    deadline: deadline,
    createdAt: now.subtract(const Duration(days: 30)),
    updatedAt: now,
    priority: priority,
    status: status,
    successCriteria: null,
    planIds: const [],
    deletedAt: deletedAt,
  );
}

PlanModel createPlan({
  String id = testPlanId,
  String userId = testUserId,
  String goalId = testGoalId,
  String name = 'Test Plan',
  String? description,
  DateTime? startDate,
  DateTime? endDate,
  RepeatRule? repeatRule,
  TaskConfiguration? taskConfig,
  PlanStatus status = PlanStatus.active,
  DateTime? deletedAt,
}) {
  final now = DateTime.now();
  return PlanModel(
    id: id,
    userId: userId,
    name: name,
    description: description,
    goalId: goalId,
    startDate: startDate ?? now.subtract(const Duration(days: 30)),
    endDate: endDate ?? now.add(const Duration(days: 30)),
    repeatRule: repeatRule ?? const RepeatRule(type: RepeatType.daily),
    taskConfig: taskConfig ?? const TaskConfiguration(),
    status: status,
    createdAt: now.subtract(const Duration(days: 30)),
    updatedAt: now,
    deletedAt: deletedAt,
  );
}

TaskModel createTask({
  String? id,
  String userId = testUserId,
  String planId = testPlanId,
  String name = 'Test Task',
  String? description,
  TaskConfiguration? config,
  DateTime? windowStartTime,
  DateTime? windowEndTime,
  TaskStatus status = TaskStatus.active,
  int currentCount = 0,
  DateTime? completedAt,
  DateTime? skippedAt,
  int? actualDurationMinutes,
  String? evaluationResult,
  String? executionNote,
  DateTime? deletedAt,
}) {
  final now = DateTime.now();
  return TaskModel(
    id: id ?? 'task-${now.microsecondsSinceEpoch}',
    userId: userId,
    planId: planId,
    name: name,
    description: description,
    config: config ?? const TaskConfiguration(),
    windowStartTime: windowStartTime ?? now.subtract(const Duration(hours: 1)),
    windowEndTime: windowEndTime ?? now.add(const Duration(hours: 23)),
    status: status,
    currentCount: currentCount,
    completedAt: completedAt,
    skippedAt: skippedAt,
    actualDurationMinutes: actualDurationMinutes,
    evaluationResult: evaluationResult,
    executionNote: executionNote,
    createdAt: now,
    deletedAt: deletedAt,
  );
}

DateTime startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

DateTime startOfWeek(DateTime date) {
  final weekday = date.weekday;
  return startOfDay(date.subtract(Duration(days: weekday - 1)));
}

DateTime endOfWeek(DateTime date) {
  final weekday = date.weekday;
  return endOfDay(date.add(Duration(days: 7 - weekday)));
}

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month, 1);

DateTime endOfMonth(DateTime date) {
  final nextMonth = date.month == 12 ? 1 : date.month + 1;
  final nextYear = date.month == 12 ? date.year + 1 : date.year;
  final lastDay =
      DateTime(nextYear, nextMonth, 1).subtract(const Duration(days: 1));
  return endOfDay(lastDay);
}
