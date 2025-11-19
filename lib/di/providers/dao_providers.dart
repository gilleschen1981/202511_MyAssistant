import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/data_sources/local/dao/user_dao.dart';
import 'package:myassistant/data/data_sources/local/dao/goal_dao.dart';
import 'package:myassistant/data/data_sources/local/dao/plan_dao.dart';
import 'package:myassistant/data/data_sources/local/dao/task_dao.dart';

/// User DAO provider
final userDaoProvider = Provider<UserDao>((ref) {
  return UserDao();
});

/// Goal DAO provider
final goalDaoProvider = Provider<GoalDao>((ref) {
  return GoalDao();
});

/// Plan DAO provider
final planDaoProvider = Provider<PlanDao>((ref) {
  return PlanDao();
});

/// Task DAO provider
final taskDaoProvider = Provider<TaskDao>((ref) {
  return TaskDao();
});