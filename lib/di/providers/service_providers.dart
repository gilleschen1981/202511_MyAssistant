import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/services/authentication_service.dart';
import 'package:myassistant/data/services/goal_management_service.dart';
import 'package:myassistant/data/services/plan_management_service.dart';
import 'package:myassistant/data/services/task_generation_service.dart';
import 'package:myassistant/data/services/task_execution_service.dart';
import 'package:myassistant/data/services/task_refresh_service.dart';
import 'package:myassistant/di/providers/repository_providers.dart';

/// Authentication service provider
final authenticationServiceProvider = Provider<AuthenticationService>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return AuthenticationService(userRepository: userRepository);
});

/// Task generation service provider
/// Note: Defined before other services to avoid initialization issues
final taskGenerationServiceProvider = Provider<TaskGenerationService>((ref) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final planRepository = ref.watch(planRepositoryProvider);
  return TaskGenerationService(
    taskRepository: taskRepository,
    planRepository: planRepository,
  );
});

/// Goal management service provider
final goalManagementServiceProvider = Provider<GoalManagementService>((ref) {
  final goalRepository = ref.watch(goalRepositoryProvider);
  final planRepository = ref.watch(planRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);
  final taskGenerationService = ref.watch(taskGenerationServiceProvider);
  return GoalManagementService(
    goalRepository: goalRepository,
    planRepository: planRepository,
    taskRepository: taskRepository,
    generationService: taskGenerationService,
  );
});

/// Plan management service provider
final planManagementServiceProvider = Provider<PlanManagementService>((ref) {
  final planRepository = ref.watch(planRepositoryProvider);
  final goalRepository = ref.watch(goalRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);
  final taskGenerationService = ref.watch(taskGenerationServiceProvider);
  return PlanManagementService(
    planRepository: planRepository,
    goalRepository: goalRepository,
    taskRepository: taskRepository,
    generationService: taskGenerationService,
  );
});

/// Task execution service provider
final taskExecutionServiceProvider = Provider<TaskExecutionService>((ref) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  return TaskExecutionService(
    taskRepository: taskRepository,
  );
});

/// Task refresh service provider
final taskRefreshServiceProvider = Provider<TaskRefreshService>((ref) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final planRepository = ref.watch(planRepositoryProvider);
  final taskGenerationService = ref.watch(taskGenerationServiceProvider);
  return TaskRefreshService(
    taskRepository: taskRepository,
    planRepository: planRepository,
    generationService: taskGenerationService,
  );
});