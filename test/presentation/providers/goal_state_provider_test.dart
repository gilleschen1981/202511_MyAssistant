import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/presentation/providers/goal_state_provider.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/user_model.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/domain/repositories/i_goal_repository.dart';
import 'package:myassistant/data/services/goal_management_service.dart';
import 'package:myassistant/di/providers/repository_providers.dart';
import 'package:myassistant/di/providers/service_providers.dart';

import 'goal_state_provider_test.mocks.dart';

@GenerateMocks([IGoalRepository, GoalManagementService])
void main() {
  late MockIGoalRepository mockGoalRepository;
  late MockGoalManagementService mockGoalService;
  late ProviderContainer container;

  setUp(() {
    mockGoalRepository = MockIGoalRepository();
    mockGoalService = MockGoalManagementService();
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

  /// Helper to create a test goal
  GoalModel createTestGoal({
    String id = 'goal-123',
    String userId = 'test-user-123',
    String title = 'Test Goal',
    GoalStatus status = GoalStatus.active,
    DateTime? deletedAt,
  }) {
    final now = DateTime.now();
    return GoalModel(
      id: id,
      userId: userId,
      title: title,
      tags: const [],
      createdAt: now,
      updatedAt: now,
      priority: Priority.medium,
      status: status,
      planIds: const [],
      deletedAt: deletedAt,
    );
  }

  /// Helper to create container with mocks
  ProviderContainer createContainer() {
    final testUser = createTestUser();

    return ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => testUser),
        goalRepositoryProvider.overrideWith((ref) => mockGoalRepository),
        goalManagementServiceProvider.overrideWith((ref) => mockGoalService),
      ],
    );
  }

  group('GoalListState', () {
    test('initial state should have empty lists and not loading', () {
      container = createContainer();
      final state = GoalListState.initial();

      expect(state.goals, isEmpty);
      expect(state.activeGoals, isEmpty);
      expect(state.inactiveGoals, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith should create a new state with updated values', () {
      container = createContainer();
      final initial = GoalListState.initial();
      final goal = createTestGoal();

      final updated = initial.copyWith(
        goals: [goal],
        activeGoals: [goal],
        isLoading: true,
      );

      expect(updated.goals.length, equals(1));
      expect(updated.activeGoals.length, equals(1));
      expect(updated.isLoading, isTrue);
      expect(updated.inactiveGoals, isEmpty);
    });

    test('copyWith error should be cleared when not passed', () {
      container = createContainer();
      final stateWithError = GoalListState.initial().copyWith(
        error: 'Some error',
      );
      expect(stateWithError.error, equals('Some error'));

      final cleared = stateWithError.copyWith(isLoading: true);
      expect(cleared.error, isNull);
    });
  });

  group('GoalListNotifier - loadGoals', () {
    test('should load and categorize goals correctly', () async {
      final activeGoal = createTestGoal(
        id: 'goal-1',
        title: 'Active Goal',
        status: GoalStatus.active,
      );
      final completedGoal = createTestGoal(
        id: 'goal-2',
        title: 'Completed Goal',
        status: GoalStatus.completed,
      );
      final pausedGoal = createTestGoal(
        id: 'goal-3',
        title: 'Paused Goal',
        status: GoalStatus.paused,
      );
      final deletedGoal = createTestGoal(
        id: 'goal-4',
        title: 'Deleted Goal',
        status: GoalStatus.deleted,
        deletedAt: DateTime.now(),
      );

      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => [activeGoal, completedGoal, pausedGoal, deletedGoal]);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      await notifier.loadGoals();

      final state = container.read(goalListProvider);
      expect(state.goals.length, equals(4));
      expect(state.activeGoals.length, equals(1));
      expect(state.activeGoals.first.id, equals('goal-1'));
      // Inactive = completed + paused
      expect(state.inactiveGoals.length, equals(2));
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('should handle empty goal list', () async {
      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => []);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      await notifier.loadGoals();

      final state = container.read(goalListProvider);
      expect(state.goals, isEmpty);
      expect(state.activeGoals, isEmpty);
      expect(state.inactiveGoals, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('should set error state on load failure', () async {
      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenThrow(Exception('Database error'));

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      await notifier.loadGoals();

      final state = container.read(goalListProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, contains('Database error'));
    });

    test('should not load goals when user is null', () async {
      container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          goalRepositoryProvider.overrideWith((ref) => mockGoalRepository),
          goalManagementServiceProvider.overrideWith((ref) => mockGoalService),
        ],
      );

      final notifier = container.read(goalListProvider.notifier);
      await notifier.loadGoals();

      final state = container.read(goalListProvider);
      expect(state.goals, isEmpty);
      expect(state.isLoading, isFalse);
      verifyNever(mockGoalRepository.getUserGoals(any));
    });

    test('should exclude soft-deleted goals from active and inactive lists', () async {
      final deletedActiveGoal = createTestGoal(
        id: 'goal-deleted',
        title: 'Deleted Active Goal',
        status: GoalStatus.active,
        deletedAt: DateTime.now(),
      );
      final normalActiveGoal = createTestGoal(
        id: 'goal-normal',
        title: 'Normal Goal',
        status: GoalStatus.active,
      );

      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => [deletedActiveGoal, normalActiveGoal]);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      await notifier.loadGoals();

      final state = container.read(goalListProvider);
      expect(state.activeGoals.length, equals(1));
      expect(state.activeGoals.first.id, equals('goal-normal'));
    });
  });

  group('GoalListNotifier - createGoal', () {
    test('should create goal and reload goals on success', () async {
      final newGoal = createTestGoal(id: 'new-goal-1', title: 'New Goal');

      when(mockGoalService.createGoal(
        userId: anyNamed('userId'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        deadline: anyNamed('deadline'),
        priority: anyNamed('priority'),
        tags: anyNamed('tags'),
        successCriteria: anyNamed('successCriteria'),
      )).thenAnswer((_) async => newGoal);

      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => [newGoal]);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.createGoal(title: 'New Goal');

      expect(result, isNotNull);
      expect(result!.id, equals('new-goal-1'));

      verify(mockGoalService.createGoal(
        userId: 'test-user-123',
        title: 'New Goal',
        description: null,
        deadline: null,
        priority: Priority.medium,
        tags: null,
        successCriteria: null,
      )).called(1);
    });

    test('should return null when user is not authenticated', () async {
      container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          goalRepositoryProvider.overrideWith((ref) => mockGoalRepository),
          goalManagementServiceProvider.overrideWith((ref) => mockGoalService),
        ],
      );

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.createGoal(title: 'New Goal');

      expect(result, isNull);
      verifyNever(mockGoalService.createGoal(
        userId: anyNamed('userId'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        deadline: anyNamed('deadline'),
        priority: anyNamed('priority'),
        tags: anyNamed('tags'),
        successCriteria: anyNamed('successCriteria'),
      ));
    });

    test('should set error state on create failure', () async {
      when(mockGoalService.createGoal(
        userId: anyNamed('userId'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        deadline: anyNamed('deadline'),
        priority: anyNamed('priority'),
        tags: anyNamed('tags'),
        successCriteria: anyNamed('successCriteria'),
      )).thenThrow(Exception('Duplicate goal'));

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.createGoal(title: 'Duplicate');

      expect(result, isNull);
      final state = container.read(goalListProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, contains('Duplicate goal'));
    });
  });

  group('GoalListNotifier - updateGoal', () {
    test('should update goal and reload on success', () async {
      final updatedGoal = createTestGoal(
        id: 'goal-123',
        title: 'Updated Title',
      );

      when(mockGoalService.updateGoal(
        goalId: anyNamed('goalId'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        deadline: anyNamed('deadline'),
        priority: anyNamed('priority'),
        tags: anyNamed('tags'),
        successCriteria: anyNamed('successCriteria'),
      )).thenAnswer((_) async => updatedGoal);

      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => [updatedGoal]);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.updateGoal(
        goalId: 'goal-123',
        title: 'Updated Title',
      );

      expect(result, isNotNull);
      expect(result!.title, equals('Updated Title'));
    });

    test('should return null and set error on update failure', () async {
      when(mockGoalService.updateGoal(
        goalId: anyNamed('goalId'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        deadline: anyNamed('deadline'),
        priority: anyNamed('priority'),
        tags: anyNamed('tags'),
        successCriteria: anyNamed('successCriteria'),
      )).thenThrow(Exception('Goal not found'));

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.updateGoal(
        goalId: 'nonexistent',
        title: 'New Title',
      );

      expect(result, isNull);
      final state = container.read(goalListProvider);
      expect(state.error, contains('Goal not found'));
    });
  });

  group('GoalListNotifier - archiveGoal', () {
    test('should archive goal and reload on success', () async {
      when(mockGoalService.archiveGoal('goal-123'))
          .thenAnswer((_) async => true);
      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => []);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.archiveGoal('goal-123');

      expect(result, isTrue);
      verify(mockGoalService.archiveGoal('goal-123')).called(1);
    });

    test('should return false and set error on archive failure', () async {
      when(mockGoalService.archiveGoal('goal-123'))
          .thenThrow(Exception('Cannot archive'));

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.archiveGoal('goal-123');

      expect(result, isFalse);
      final state = container.read(goalListProvider);
      expect(state.error, contains('Cannot archive'));
    });
  });

  group('GoalListNotifier - deleteGoal', () {
    test('should delete goal and reload on success', () async {
      when(mockGoalService.deleteGoal('goal-123'))
          .thenAnswer((_) async => true);
      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => []);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.deleteGoal('goal-123');

      expect(result, isTrue);
      verify(mockGoalService.deleteGoal('goal-123')).called(1);
    });

    test('should return false and set error on delete failure', () async {
      when(mockGoalService.deleteGoal('goal-123'))
          .thenThrow(Exception('Delete failed'));

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.deleteGoal('goal-123');

      expect(result, isFalse);
      final state = container.read(goalListProvider);
      expect(state.error, contains('Delete failed'));
    });
  });

  group('GoalListNotifier - resumeGoal', () {
    test('should resume goal and reload on success', () async {
      final resumedGoal = createTestGoal(
        id: 'goal-123',
        status: GoalStatus.active,
      );

      when(mockGoalService.resumeGoal('goal-123'))
          .thenAnswer((_) async => resumedGoal);
      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => [resumedGoal]);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.resumeGoal('goal-123');

      expect(result, isNotNull);
      expect(result!.status, equals(GoalStatus.active));
    });

    test('should return null and set error on resume failure', () async {
      when(mockGoalService.resumeGoal('goal-123'))
          .thenThrow(Exception('Goal is not paused'));

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.resumeGoal('goal-123');

      expect(result, isNull);
      final state = container.read(goalListProvider);
      expect(state.error, contains('Goal is not paused'));
    });
  });

  group('GoalListNotifier - pauseGoal', () {
    test('should pause goal and reload on success', () async {
      final pausedGoal = createTestGoal(
        id: 'goal-123',
        status: GoalStatus.paused,
      );

      when(mockGoalService.pauseGoal('goal-123'))
          .thenAnswer((_) async => pausedGoal);
      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => [pausedGoal]);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.pauseGoal('goal-123');

      expect(result, isNotNull);
      expect(result!.status, equals(GoalStatus.paused));
    });

    test('should return null and set error on pause failure', () async {
      when(mockGoalService.pauseGoal('goal-123'))
          .thenThrow(Exception('Cannot pause'));

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.pauseGoal('goal-123');

      expect(result, isNull);
      final state = container.read(goalListProvider);
      expect(state.error, contains('Cannot pause'));
    });
  });

  group('GoalListNotifier - completeGoal', () {
    test('should complete goal and reload on success', () async {
      final completedGoal = createTestGoal(
        id: 'goal-123',
        status: GoalStatus.completed,
      );

      when(mockGoalService.completeGoal('goal-123'))
          .thenAnswer((_) async => completedGoal);
      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => [completedGoal]);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.completeGoal('goal-123');

      expect(result, isNotNull);
      expect(result!.status, equals(GoalStatus.completed));
    });

    test('should return null and set error on complete failure', () async {
      when(mockGoalService.completeGoal('goal-123'))
          .thenThrow(Exception('Already completed'));

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.completeGoal('goal-123');

      expect(result, isNull);
      final state = container.read(goalListProvider);
      expect(state.error, contains('Already completed'));
    });
  });

  group('GoalListNotifier - getGoalProgress', () {
    test('should return goal statistics on success', () async {
      final stats = GoalStatistics(
        totalPlans: 3,
        activePlans: 2,
        completedPlans: 1,
        totalTasks: 10,
        completedTasks: 5,
        overallProgress: 0.5,
        daysRemaining: 30,
        dailyProgress: 0.01,
      );

      when(mockGoalService.calculateGoalProgress('goal-123'))
          .thenAnswer((_) async => stats);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.getGoalProgress('goal-123');

      expect(result, isNotNull);
      expect(result!.totalPlans, equals(3));
      expect(result.overallProgress, equals(0.5));
    });

    test('should return null and set error on progress failure', () async {
      when(mockGoalService.calculateGoalProgress('goal-123'))
          .thenThrow(Exception('Goal not found'));

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.getGoalProgress('goal-123');

      expect(result, isNull);
      final state = container.read(goalListProvider);
      expect(state.error, contains('Goal not found'));
    });
  });

  group('GoalListNotifier - getGoalRecommendations', () {
    test('should return recommendations on success', () async {
      when(mockGoalService.getGoalRecommendations('goal-123'))
          .thenAnswer((_) async => ['Create more plans', 'Focus on tasks']);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.getGoalRecommendations('goal-123');

      expect(result, hasLength(2));
      expect(result.first, equals('Create more plans'));
    });

    test('should return empty list and set error on failure', () async {
      when(mockGoalService.getGoalRecommendations('goal-123'))
          .thenThrow(Exception('Goal not found'));

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      final result = await notifier.getGoalRecommendations('goal-123');

      expect(result, isEmpty);
      final state = container.read(goalListProvider);
      expect(state.error, contains('Goal not found'));
    });
  });

  group('GoalListNotifier - Loading State', () {
    test('loadGoals should set loading before fetch', () async {
      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => []);

      container = createContainer();

      final states = <GoalListState>[];
      container.listen(goalListProvider, (previous, next) {
        states.add(next);
      });

      final notifier = container.read(goalListProvider.notifier);
      await notifier.loadGoals();

      // First state change should be loading
      expect(states.first.isLoading, isTrue);
    });

    test('createGoal should set loading before create', () async {
      final newGoal = createTestGoal(id: 'new-goal');

      when(mockGoalService.createGoal(
        userId: anyNamed('userId'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        deadline: anyNamed('deadline'),
        priority: anyNamed('priority'),
        tags: anyNamed('tags'),
        successCriteria: anyNamed('successCriteria'),
      )).thenAnswer((_) async => newGoal);

      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => [newGoal]);

      container = createContainer();

      final states = <GoalListState>[];
      container.listen(goalListProvider, (previous, next) {
        states.add(next);
      });

      final notifier = container.read(goalListProvider.notifier);
      await notifier.createGoal(title: 'New Goal');

      expect(states.first.isLoading, isTrue);
    });
  });

  group('Derived Providers', () {
    test('activeGoalsProvider should return active goals', () async {
      final activeGoal = createTestGoal(
        id: 'goal-1',
        status: GoalStatus.active,
      );
      final completedGoal = createTestGoal(
        id: 'goal-2',
        status: GoalStatus.completed,
      );

      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => [activeGoal, completedGoal]);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      await notifier.loadGoals();

      final active = container.read(activeGoalsProvider);
      expect(active.length, equals(1));
      expect(active.first.id, equals('goal-1'));
    });

    test('inactiveGoalsProvider should return completed and paused goals', () async {
      final activeGoal = createTestGoal(
        id: 'goal-1',
        status: GoalStatus.active,
      );
      final completedGoal = createTestGoal(
        id: 'goal-2',
        status: GoalStatus.completed,
      );
      final pausedGoal = createTestGoal(
        id: 'goal-3',
        status: GoalStatus.paused,
      );

      when(mockGoalRepository.getUserGoals('test-user-123'))
          .thenAnswer((_) async => [activeGoal, completedGoal, pausedGoal]);

      container = createContainer();

      final notifier = container.read(goalListProvider.notifier);
      await notifier.loadGoals();

      final inactive = container.read(inactiveGoalsProvider);
      expect(inactive.length, equals(2));
    });

    test('selectedGoalProvider should default to null', () {
      container = createContainer();

      final selected = container.read(selectedGoalProvider);
      expect(selected, isNull);
    });

    test('selectedGoalProvider should allow setting a goal', () {
      container = createContainer();

      final goal = createTestGoal();
      container.read(selectedGoalProvider.notifier).state = goal;

      final selected = container.read(selectedGoalProvider);
      expect(selected, isNotNull);
      expect(selected!.id, equals('goal-123'));
    });
  });
}
