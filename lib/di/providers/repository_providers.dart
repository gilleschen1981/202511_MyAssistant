import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/domain/repositories/i_user_repository.dart';
import 'package:myassistant/domain/repositories/i_goal_repository.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/data/repositories/user_repository.dart';
import 'package:myassistant/data/repositories/goal_repository.dart';
import 'package:myassistant/data/repositories/plan_repository.dart';
import 'package:myassistant/data/repositories/task_repository.dart';
import 'package:myassistant/di/providers/dao_providers.dart';

/// User repository provider
final userRepositoryProvider = Provider<IUserRepository>((ref) {
  final userDao = ref.watch(userDaoProvider);
  return UserRepository(userDao: userDao);
});

/// Goal repository provider
final goalRepositoryProvider = Provider<IGoalRepository>((ref) {
  final goalDao = ref.watch(goalDaoProvider);
  return GoalRepository(goalDao: goalDao);
});

/// Plan repository provider
final planRepositoryProvider = Provider<IPlanRepository>((ref) {
  final planDao = ref.watch(planDaoProvider);
  final goalDao = ref.watch(goalDaoProvider);
  final goalRepository = ref.watch(goalRepositoryProvider);
  return PlanRepository(
    planDao: planDao,
    goalDao: goalDao,
    goalRepository: goalRepository,
  );
});

/// Task repository provider
final taskRepositoryProvider = Provider<ITaskRepository>((ref) {
  final taskDao = ref.watch(taskDaoProvider);
  final planDao = ref.watch(planDaoProvider);
  return TaskRepository(
    taskDao: taskDao,
    planDao: planDao,
  );
});