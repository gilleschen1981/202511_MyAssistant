import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/presentation/providers/plan_state_provider.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';
import 'package:myassistant/presentation/providers/task_list_notifier.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/user_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/data/services/plan_management_service.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/data/services/task_execution_service.dart';
import 'package:myassistant/data/services/task_refresh_service.dart';
import 'package:myassistant/di/providers/repository_providers.dart';
import 'package:myassistant/di/providers/service_providers.dart';

import 'plan_state_provider_test.mocks.dart';

@GenerateMocks([
  IPlanRepository,
  PlanManagementService,
  ITaskRepository,
  TaskExecutionService,
  TaskRefreshService,
])
void main() {
  late MockIPlanRepository mockPlanRepository;
  late MockPlanManagementService mockPlanService;
  late MockITaskRepository mockTaskRepository;
  late MockTaskExecutionService mockExecutionService;
  late MockTaskRefreshService mockRefreshService;
  late ProviderContainer container;

  setUp(() {
    mockPlanRepository = MockIPlanRepository();
    mockPlanService = MockPlanManagementService();
    mockTaskRepository = MockITaskRepository();
    mockExecutionService = MockTaskExecutionService();
    mockRefreshService = MockTaskRefreshService();

    // Default mocks for taskListNotifierProvider dependencies
    when(mockExecutionService.getActiveSessions()).thenReturn({});
    when(mockTaskRepository.getFutureTasks(any))
        .thenAnswer((_) async => []);
    when(mockTaskRepository.getTodayTasks(any))
        .thenAnswer((_) async => []);
    when(mockRefreshService.refreshAllTasks(any))
        .thenAnswer((_) async => RefreshResult());
  });

  tearDown(() {
    container.dispose();
  });

  /// Helper to create a test user
  UserModel createTestUser({String id = 'test-user-123'}) {
    final now = DateTime.now();
    return UserModel(
      id: id,
      username: 'testuser',
      email: 'test@example.com',
      passwordHash: 'test-hash',
      status: UserStatus.active,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Helper to create a test plan
  PlanModel createTestPlan({
    String id = 'plan-123',
    String userId = 'test-user-123',
    String goalId = 'goal-123',
    String name = 'Test Plan',
    PlanStatus status = PlanStatus.active,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    return PlanModel(
      id: id,
      userId: userId,
      goalId: goalId,
      name: name,
      startDate: startDate ?? now.subtract(const Duration(days: 7)),
      endDate: endDate ?? now.add(const Duration(days: 23)),
      repeatRule: const RepeatRule(type: RepeatType.daily),
      taskConfig: const TaskConfiguration(durationMinutes: 30),
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Helper to create container with mocks
  ProviderContainer createContainer({UserModel? user}) {
    final testUser = user ?? createTestUser();

    return ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => testUser),
        planRepositoryProvider.overrideWith((ref) => mockPlanRepository),
        planManagementServiceProvider.overrideWith((ref) => mockPlanService),
        taskRepositoryProvider.overrideWith((ref) => mockTaskRepository),
        taskExecutionServiceProvider
            .overrideWith((ref) => mockExecutionService),
        taskRefreshServiceProvider.overrideWith((ref) => mockRefreshService),
      ],
    );
  }

  /// Helper to create container with null user
  ProviderContainer createContainerWithNullUser() {
    return ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => null),
        planRepositoryProvider.overrideWith((ref) => mockPlanRepository),
        planManagementServiceProvider.overrideWith((ref) => mockPlanService),
        taskRepositoryProvider.overrideWith((ref) => mockTaskRepository),
        taskExecutionServiceProvider
            .overrideWith((ref) => mockExecutionService),
        taskRefreshServiceProvider.overrideWith((ref) => mockRefreshService),
      ],
    );
  }

  group('PlanListNotifier - loadPlans', () {
    test('should load and categorize plans correctly', () async {
      // Arrange
      final now = DateTime.now();
      final activePlan = createTestPlan(
        id: 'active-plan',
        name: 'Active Plan',
        status: PlanStatus.active,
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 25)),
      );
      final completedPlan = createTestPlan(
        id: 'completed-plan',
        name: 'Completed Plan',
        status: PlanStatus.active,
        startDate: now.subtract(const Duration(days: 60)),
        endDate: now.subtract(const Duration(days: 1)),
      );

      when(mockPlanRepository.getUserPlans('test-user-123'))
          .thenAnswer((_) async => [activePlan, completedPlan]);

      container = createContainer();

      // Act
      await container
          .read(planListProvider.notifier)
          .loadPlans();

      // Assert
      final state = container.read(planListProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.plans.length, equals(2));
      // activePlan.isActive checks status == active && now is between start and end
      expect(state.activePlans.length, equals(1));
      expect(state.activePlans.first.id, equals('active-plan'));
      // completedPlan.hasEnded checks now.isAfter(endDate)
      expect(state.completedPlans.length, equals(1));
      expect(state.completedPlans.first.id, equals('completed-plan'));
    });

    test('should set loading state while loading', () async {
      // Arrange
      when(mockPlanRepository.getUserPlans('test-user-123'))
          .thenAnswer((_) async => []);

      container = createContainer();

      // Act - check initial state
      final initialState = container.read(planListProvider);
      expect(initialState.isLoading, isFalse);

      // Load plans
      await container.read(planListProvider.notifier).loadPlans();

      // Assert - after loading
      final finalState = container.read(planListProvider);
      expect(finalState.isLoading, isFalse);
      expect(finalState.error, isNull);
    });

    test('should handle error during loadPlans', () async {
      // Arrange
      when(mockPlanRepository.getUserPlans('test-user-123'))
          .thenThrow(Exception('Database error'));

      container = createContainer();

      // Act
      await container.read(planListProvider.notifier).loadPlans();

      // Assert
      final state = container.read(planListProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, contains('Database error'));
    });

    test('should return early when user is null', () async {
      // Arrange
      container = createContainerWithNullUser();

      // Act
      await container.read(planListProvider.notifier).loadPlans();

      // Assert
      final state = container.read(planListProvider);
      expect(state.plans, isEmpty);
      expect(state.isLoading, isFalse);
      verifyNever(mockPlanRepository.getUserPlans(any));
    });

    test('should handle empty plan list', () async {
      // Arrange
      when(mockPlanRepository.getUserPlans('test-user-123'))
          .thenAnswer((_) async => []);

      container = createContainer();

      // Act
      await container.read(planListProvider.notifier).loadPlans();

      // Assert
      final state = container.read(planListProvider);
      expect(state.plans, isEmpty);
      expect(state.activePlans, isEmpty);
      expect(state.completedPlans, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });
  });

  group('PlanListNotifier - loadGoalPlans', () {
    test('should load plans for a specific goal', () async {
      // Arrange
      final plan = createTestPlan(
        id: 'goal-plan-1',
        goalId: 'goal-456',
        name: 'Goal Plan',
      );

      when(mockPlanRepository.getGoalPlans('goal-456'))
          .thenAnswer((_) async => [plan]);

      container = createContainer();

      // Act
      await container
          .read(planListProvider.notifier)
          .loadGoalPlans('goal-456');

      // Assert
      final state = container.read(planListProvider);
      expect(state.plans.length, equals(1));
      expect(state.plans.first.goalId, equals('goal-456'));
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('should handle error during loadGoalPlans', () async {
      // Arrange
      when(mockPlanRepository.getGoalPlans('goal-456'))
          .thenThrow(Exception('Goal not found'));

      container = createContainer();

      // Act
      await container
          .read(planListProvider.notifier)
          .loadGoalPlans('goal-456');

      // Assert
      final state = container.read(planListProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, contains('Goal not found'));
    });
  });

  group('PlanListNotifier - createPlan', () {
    test('should create plan and reload plans and tasks', () async {
      // Arrange
      final now = DateTime.now();
      final newPlan = createTestPlan(
        id: 'new-plan',
        name: 'New Plan',
      );

      when(mockPlanService.createPlan(
        userId: anyNamed('userId'),
        goalId: anyNamed('goalId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        startDate: anyNamed('startDate'),
        endDate: anyNamed('endDate'),
        repeatRule: anyNamed('repeatRule'),
        taskConfig: anyNamed('taskConfig'),
      )).thenAnswer((_) async => newPlan);

      when(mockPlanRepository.getUserPlans('test-user-123'))
          .thenAnswer((_) async => [newPlan]);

      container = createContainer();
      // Wait for taskListNotifierProvider to initialize
      await container.read(taskListNotifierProvider.future);

      // Act
      final result = await container.read(planListProvider.notifier).createPlan(
        goalId: 'goal-123',
        name: 'New Plan',
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        repeatRule: const RepeatRule(type: RepeatType.daily),
        taskConfig: const TaskConfiguration(durationMinutes: 30),
      );

      // Assert
      expect(result, isNotNull);
      expect(result!.id, equals('new-plan'));
      verify(mockPlanService.createPlan(
        userId: 'test-user-123',
        goalId: 'goal-123',
        name: 'New Plan',
        description: null,
        startDate: anyNamed('startDate'),
        endDate: anyNamed('endDate'),
        repeatRule: anyNamed('repeatRule'),
        taskConfig: anyNamed('taskConfig'),
      )).called(1);
      // loadPlans was called, which calls getUserPlans
      verify(mockPlanRepository.getUserPlans('test-user-123')).called(1);
    });

    test('should return null when user is null', () async {
      // Arrange
      final now = DateTime.now();
      container = createContainerWithNullUser();

      // Act
      final result = await container.read(planListProvider.notifier).createPlan(
        goalId: 'goal-123',
        name: 'New Plan',
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        repeatRule: const RepeatRule(type: RepeatType.daily),
        taskConfig: const TaskConfiguration(durationMinutes: 30),
      );

      // Assert
      expect(result, isNull);
      verifyNever(mockPlanService.createPlan(
        userId: anyNamed('userId'),
        goalId: anyNamed('goalId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        startDate: anyNamed('startDate'),
        endDate: anyNamed('endDate'),
        repeatRule: anyNamed('repeatRule'),
        taskConfig: anyNamed('taskConfig'),
      ));
    });

    test('should handle error during createPlan', () async {
      // Arrange
      final now = DateTime.now();

      when(mockPlanService.createPlan(
        userId: anyNamed('userId'),
        goalId: anyNamed('goalId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        startDate: anyNamed('startDate'),
        endDate: anyNamed('endDate'),
        repeatRule: anyNamed('repeatRule'),
        taskConfig: anyNamed('taskConfig'),
      )).thenThrow(Exception('Duplicate plan name'));

      container = createContainer();

      // Act
      final result = await container.read(planListProvider.notifier).createPlan(
        goalId: 'goal-123',
        name: 'Duplicate',
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        repeatRule: const RepeatRule(type: RepeatType.daily),
        taskConfig: const TaskConfiguration(durationMinutes: 30),
      );

      // Assert
      expect(result, isNull);
      final state = container.read(planListProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, contains('Duplicate plan name'));
    });
  });

  group('PlanListNotifier - updatePlan', () {
    test('should update plan and reload plans', () async {
      // Arrange
      final updatedPlan = createTestPlan(
        id: 'plan-123',
        name: 'Updated Plan',
      );

      when(mockPlanService.updatePlan(
        planId: anyNamed('planId'),
        description: anyNamed('description'),
        endDate: anyNamed('endDate'),
        taskConfig: anyNamed('taskConfig'),
        repeatRule: anyNamed('repeatRule'),
      )).thenAnswer((_) async => updatedPlan);

      when(mockPlanRepository.getUserPlans('test-user-123'))
          .thenAnswer((_) async => [updatedPlan]);

      container = createContainer();

      // Act
      final result =
          await container.read(planListProvider.notifier).updatePlan(
        planId: 'plan-123',
        description: 'Updated description',
      );

      // Assert
      expect(result, isNotNull);
      expect(result!.id, equals('plan-123'));
      verify(mockPlanService.updatePlan(
        planId: 'plan-123',
        description: 'Updated description',
        endDate: null,
        taskConfig: null,
        repeatRule: null,
      )).called(1);
      verify(mockPlanRepository.getUserPlans('test-user-123')).called(1);
    });

    test('should handle error during updatePlan', () async {
      // Arrange
      when(mockPlanService.updatePlan(
        planId: anyNamed('planId'),
        description: anyNamed('description'),
        endDate: anyNamed('endDate'),
        taskConfig: anyNamed('taskConfig'),
        repeatRule: anyNamed('repeatRule'),
      )).thenThrow(Exception('Plan not found'));

      container = createContainer();

      // Act
      final result =
          await container.read(planListProvider.notifier).updatePlan(
        planId: 'nonexistent-plan',
        description: 'test',
      );

      // Assert
      expect(result, isNull);
      final state = container.read(planListProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, contains('Plan not found'));
    });
  });

  group('PlanListNotifier - deletePlan', () {
    test('should delete plan and reload plans', () async {
      // Arrange
      when(mockPlanService.deletePlan('plan-123'))
          .thenAnswer((_) async => true);

      when(mockPlanRepository.getUserPlans('test-user-123'))
          .thenAnswer((_) async => []);

      container = createContainer();

      // Act
      final result = await container
          .read(planListProvider.notifier)
          .deletePlan('plan-123');

      // Assert
      expect(result, isTrue);
      verify(mockPlanService.deletePlan('plan-123')).called(1);
      verify(mockPlanRepository.getUserPlans('test-user-123')).called(1);

      final state = container.read(planListProvider);
      expect(state.plans, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('should handle error during deletePlan', () async {
      // Arrange
      when(mockPlanService.deletePlan('plan-123'))
          .thenThrow(Exception('Cannot delete'));

      container = createContainer();

      // Act
      final result = await container
          .read(planListProvider.notifier)
          .deletePlan('plan-123');

      // Assert
      expect(result, isFalse);
      final state = container.read(planListProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, contains('Cannot delete'));
    });
  });

  group('PlanListNotifier - extendPlan', () {
    test('should extend plan and reload plans', () async {
      // Arrange
      final now = DateTime.now();
      final extendedPlan = createTestPlan(
        id: 'plan-123',
        name: 'Extended Plan',
        endDate: now.add(const Duration(days: 37)),
      );

      when(mockPlanService.extendPlan(
        planId: anyNamed('planId'),
        additionalDays: anyNamed('additionalDays'),
      )).thenAnswer((_) async => extendedPlan);

      when(mockPlanRepository.getUserPlans('test-user-123'))
          .thenAnswer((_) async => [extendedPlan]);

      container = createContainer();

      // Act
      final result =
          await container.read(planListProvider.notifier).extendPlan(
        planId: 'plan-123',
        additionalDays: 14,
      );

      // Assert
      expect(result, isNotNull);
      expect(result!.id, equals('plan-123'));
      verify(mockPlanService.extendPlan(
        planId: 'plan-123',
        additionalDays: 14,
      )).called(1);
      verify(mockPlanRepository.getUserPlans('test-user-123')).called(1);
    });

    test('should handle error during extendPlan', () async {
      // Arrange
      when(mockPlanService.extendPlan(
        planId: anyNamed('planId'),
        additionalDays: anyNamed('additionalDays'),
      )).thenThrow(Exception('Cannot extend deleted plan'));

      container = createContainer();

      // Act
      final result =
          await container.read(planListProvider.notifier).extendPlan(
        planId: 'plan-123',
        additionalDays: 7,
      );

      // Assert
      expect(result, isNull);
      final state = container.read(planListProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, contains('Cannot extend deleted plan'));
    });
  });

  group('PlanListNotifier - getPlanStatistics', () {
    test('should return plan statistics', () async {
      // Arrange
      final stats = PlanStatistics(
        totalTasks: 10,
        completedTasks: 7,
        activeTasks: 2,
        skippedTasks: 1,
        completionRate: 0.7,
        daysRemaining: 15,
        totalDays: 30,
        progressPercentage: 0.5,
      );

      when(mockPlanService.calculatePlanStatistics('plan-123'))
          .thenAnswer((_) async => stats);

      container = createContainer();

      // Act
      final result = await container
          .read(planListProvider.notifier)
          .getPlanStatistics('plan-123');

      // Assert
      expect(result, isNotNull);
      expect(result!.totalTasks, equals(10));
      expect(result.completedTasks, equals(7));
      expect(result.completionRate, equals(0.7));
    });

    test('should handle error and set error state', () async {
      // Arrange
      when(mockPlanService.calculatePlanStatistics('plan-123'))
          .thenThrow(Exception('Not found'));

      container = createContainer();

      // Act
      final result = await container
          .read(planListProvider.notifier)
          .getPlanStatistics('plan-123');

      // Assert
      expect(result, isNull);
      final state = container.read(planListProvider);
      expect(state.error, isNotNull);
      expect(state.error, contains('Not found'));
    });
  });

  group('PlanListNotifier - getPlanRecommendations', () {
    test('should return recommendations', () async {
      // Arrange
      final recommendations = [
        'Low task completion rate. Consider adjusting task difficulty.',
        'No active tasks. Check task generation settings.',
      ];

      when(mockPlanService.getPlanRecommendations('plan-123'))
          .thenAnswer((_) async => recommendations);

      container = createContainer();

      // Act
      final result = await container
          .read(planListProvider.notifier)
          .getPlanRecommendations('plan-123');

      // Assert
      expect(result, isNotEmpty);
      expect(result.length, equals(2));
      expect(result.first, contains('completion rate'));
    });

    test('should return empty list on error', () async {
      // Arrange
      when(mockPlanService.getPlanRecommendations('plan-123'))
          .thenThrow(Exception('Error'));

      container = createContainer();

      // Act
      final result = await container
          .read(planListProvider.notifier)
          .getPlanRecommendations('plan-123');

      // Assert
      expect(result, isEmpty);
      final state = container.read(planListProvider);
      expect(state.error, isNotNull);
    });
  });

  group('PlanListState', () {
    test('initial state should have empty lists and not loading', () {
      final state = PlanListState.initial();

      expect(state.plans, isEmpty);
      expect(state.activePlans, isEmpty);
      expect(state.completedPlans, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith should update specified fields', () {
      final initial = PlanListState.initial();
      final plan = createTestPlan();

      final updated = initial.copyWith(
        plans: [plan],
        isLoading: true,
        error: 'some error',
      );

      expect(updated.plans.length, equals(1));
      expect(updated.isLoading, isTrue);
      expect(updated.error, equals('some error'));
      expect(updated.activePlans, isEmpty); // unchanged
    });

    test('copyWith with error null clears error', () {
      final withError = PlanListState.initial().copyWith(error: 'an error');
      expect(withError.error, equals('an error'));

      // copyWith with no error parameter keeps the behavior:
      // error parameter defaults to null in the copyWith which means error is cleared
      final cleared = withError.copyWith(isLoading: false);
      expect(cleared.error, isNull);
    });
  });
}
