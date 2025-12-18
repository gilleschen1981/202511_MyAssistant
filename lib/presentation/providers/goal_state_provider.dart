import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/services/goal_management_service.dart';
import 'package:myassistant/domain/repositories/i_goal_repository.dart';
import 'package:myassistant/di/providers/repository_providers.dart';
import 'package:myassistant/di/providers/service_providers.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';
import 'package:myassistant/core/utils/app_logger.dart';

/// Goal list state
class GoalListState {
  final List<GoalModel> goals;
  final List<GoalModel> activeGoals;
  final List<GoalModel> inactiveGoals; // Completed + Paused goals
  final bool isLoading;
  final String? error;

  const GoalListState({
    required this.goals,
    required this.activeGoals,
    required this.inactiveGoals,
    required this.isLoading,
    this.error,
  });

  factory GoalListState.initial() {
    return const GoalListState(
      goals: [],
      activeGoals: [],
      inactiveGoals: [],
      isLoading: false,
    );
  }

  GoalListState copyWith({
    List<GoalModel>? goals,
    List<GoalModel>? activeGoals,
    List<GoalModel>? inactiveGoals,
    bool? isLoading,
    String? error,
  }) {
    return GoalListState(
      goals: goals ?? this.goals,
      activeGoals: activeGoals ?? this.activeGoals,
      inactiveGoals: inactiveGoals ?? this.inactiveGoals,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Goal list state notifier
class GoalListNotifier extends StateNotifier<GoalListState> {
  final IGoalRepository _goalRepository;
  final GoalManagementService _goalService;
  final Ref _ref;

  GoalListNotifier({
    required IGoalRepository goalRepository,
    required GoalManagementService goalService,
    required Ref ref,
  })  : _goalRepository = goalRepository,
        _goalService = goalService,
        _ref = ref,
        super(GoalListState.initial());

  /// Load goals
  Future<void> loadGoals() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get all goals
      final goals = await _goalRepository.getUserGoals(user.id);

      // Filter active goals (not deleted)
      final activeGoalsList = goals
          .where((g) => g.deletedAt == null && g.isActive)
          .toList();

      // Filter inactive goals (completed + paused)
      final inactiveGoalsList = goals
          .where((g) => g.deletedAt == null &&
                       (g.status == GoalStatus.completed || g.status == GoalStatus.paused))
          .toList();

      state = state.copyWith(
        goals: goals,
        activeGoals: activeGoalsList,
        inactiveGoals: inactiveGoalsList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Create goal
  Future<GoalModel?> createGoal({
    required String title,
    String? description,
    DateTime? deadline,
    Priority priority = Priority.medium,
    List<String>? tags,
    String? successCriteria,
  }) async {
    AppLogger.d('createGoal called with title: $title', tag: 'GoalListNotifier');

    final user = _ref.read(currentUserProvider);
    if (user == null) {
      AppLogger.w('No user found, returning null', tag: 'GoalListNotifier');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      AppLogger.d('Calling _goalService.createGoal...', tag: 'GoalListNotifier');
      final goal = await _goalService.createGoal(
        userId: user.id,
        title: title,
        description: description,
        deadline: deadline,
        priority: priority,
        tags: tags,
        successCriteria: successCriteria,
      );
      AppLogger.i('Goal created successfully: ${goal.id}', tag: 'GoalListNotifier');

      // Reload goals
      AppLogger.d('Reloading goals...', tag: 'GoalListNotifier');
      await loadGoals();
      AppLogger.d('Goals reloaded', tag: 'GoalListNotifier');

      return goal;
    } catch (e) {
      AppLogger.e('Error creating goal: $e', tag: 'GoalListNotifier', error: e);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Update goal
  Future<GoalModel?> updateGoal({
    required String goalId,
    String? title,
    String? description,
    DateTime? deadline,
    Priority? priority,
    List<String>? tags,
    String? successCriteria,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final goal = await _goalService.updateGoal(
        goalId: goalId,
        title: title,
        description: description,
        deadline: deadline,
        priority: priority,
        tags: tags,
        successCriteria: successCriteria,
      );

      // Reload goals
      await loadGoals();

      return goal;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Archive goal
  Future<bool> archiveGoal(String goalId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _goalService.archiveGoal(goalId);

      // Reload goals
      await loadGoals();

      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Delete goal and all associated plans
  Future<bool> deleteGoal(String goalId) async {
    AppLogger.d('deleteGoal called with goalId: $goalId', tag: 'GoalStateProvider');
    state = state.copyWith(isLoading: true, error: null);

    try {
      AppLogger.d('Calling goal service deleteGoal...', tag: 'GoalStateProvider');
      final result = await _goalService.deleteGoal(goalId);
      AppLogger.d('Delete result: $result', tag: 'GoalStateProvider');

      // Reload goals
      AppLogger.d('Reloading goals...', tag: 'GoalStateProvider');
      await loadGoals();
      AppLogger.i('Goals reloaded successfully', tag: 'GoalStateProvider');

      return result;
    } catch (e, stackTrace) {
      AppLogger.e('Error deleting goal: $e', tag: 'GoalStateProvider', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Resume a paused goal and all associated plans
  Future<GoalModel?> resumeGoal(String goalId) async {
    AppLogger.i('Resuming goal: $goalId', tag: 'GoalListNotifier');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final resumedGoal = await _goalService.resumeGoal(goalId);
      AppLogger.i('Goal resumed successfully', tag: 'GoalListNotifier');

      // Reload goals
      await loadGoals();

      return resumedGoal;
    } catch (e) {
      AppLogger.e('Error resuming goal: $e', tag: 'GoalListNotifier', error: e);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Pause goal and all associated plans and tasks
  Future<GoalModel?> pauseGoal(String goalId) async {
    AppLogger.i('Pausing goal: $goalId', tag: 'GoalListNotifier');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final pausedGoal = await _goalService.pauseGoal(goalId);
      AppLogger.i('Goal paused successfully', tag: 'GoalListNotifier');

      // Reload goals
      await loadGoals();

      return pausedGoal;
    } catch (e) {
      AppLogger.e('Error pausing goal: $e', tag: 'GoalListNotifier', error: e);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Complete goal and all associated plans and tasks
  Future<GoalModel?> completeGoal(String goalId) async {
    AppLogger.i('Completing goal: $goalId', tag: 'GoalListNotifier');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final completedGoal = await _goalService.completeGoal(goalId);
      AppLogger.i('Goal completed successfully', tag: 'GoalListNotifier');

      // Reload goals
      await loadGoals();

      return completedGoal;
    } catch (e) {
      AppLogger.e('Error completing goal: $e', tag: 'GoalListNotifier', error: e);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Get goal progress
  Future<GoalStatistics?> getGoalProgress(String goalId) async {
    try {
      return await _goalService.calculateGoalProgress(goalId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Get goal recommendations
  Future<List<String>> getGoalRecommendations(String goalId) async {
    try {
      return await _goalService.getGoalRecommendations(goalId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }
}

/// Goal list provider
final goalListProvider = StateNotifierProvider<GoalListNotifier, GoalListState>((ref) {
  final goalRepository = ref.watch(goalRepositoryProvider);
  final goalService = ref.watch(goalManagementServiceProvider);

  return GoalListNotifier(
    goalRepository: goalRepository,
    goalService: goalService,
    ref: ref,
  );
});

/// Active goals provider
final activeGoalsProvider = Provider<List<GoalModel>>((ref) {
  final goalState = ref.watch(goalListProvider);
  return goalState.activeGoals;
});

/// Inactive goals provider (completed + paused)
final inactiveGoalsProvider = Provider<List<GoalModel>>((ref) {
  final goalState = ref.watch(goalListProvider);
  return goalState.inactiveGoals;
});

/// Selected goal provider
final selectedGoalProvider = StateProvider<GoalModel?>((ref) => null);

/// Goal progress provider
final goalProgressProvider = FutureProvider.family<GoalStatistics?, String>((ref, goalId) async {
  final goalService = ref.watch(goalManagementServiceProvider);
  try {
    return await goalService.calculateGoalProgress(goalId);
  } catch (e) {
    return null;
  }
});