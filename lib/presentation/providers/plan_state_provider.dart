import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/services/plan_management_service.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/di/providers/repository_providers.dart';
import 'package:myassistant/di/providers/service_providers.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';
import 'package:myassistant/presentation/providers/task_state_provider.dart';

/// Plan list state
class PlanListState {
  final List<PlanModel> plans;
  final List<PlanModel> activePlans;
  final List<PlanModel> completedPlans;
  final bool isLoading;
  final String? error;

  const PlanListState({
    required this.plans,
    required this.activePlans,
    required this.completedPlans,
    required this.isLoading,
    this.error,
  });

  factory PlanListState.initial() {
    return const PlanListState(
      plans: [],
      activePlans: [],
      completedPlans: [],
      isLoading: false,
    );
  }

  PlanListState copyWith({
    List<PlanModel>? plans,
    List<PlanModel>? activePlans,
    List<PlanModel>? completedPlans,
    bool? isLoading,
    String? error,
  }) {
    return PlanListState(
      plans: plans ?? this.plans,
      activePlans: activePlans ?? this.activePlans,
      completedPlans: completedPlans ?? this.completedPlans,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Plan list state notifier
class PlanListNotifier extends StateNotifier<PlanListState> {
  final IPlanRepository _planRepository;
  final PlanManagementService _planService;
  final Ref _ref;

  PlanListNotifier({
    required IPlanRepository planRepository,
    required PlanManagementService planService,
    required Ref ref,
  })  : _planRepository = planRepository,
        _planService = planService,
        _ref = ref,
        super(PlanListState.initial());

  /// Load plans
  Future<void> loadPlans() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get all plans
      final plans = await _planRepository.getUserPlans(user.id);

      // Filter active plans
      final activePlansList = plans.where((p) => p.isActive).toList();

      // Filter completed plans (ended)
      final completedPlansList = plans.where((p) => p.hasEnded).toList();

      state = state.copyWith(
        plans: plans,
        activePlans: activePlansList,
        completedPlans: completedPlansList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load plans for a specific goal
  Future<void> loadGoalPlans(String goalId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final plans = await _planRepository.getGoalPlans(goalId);

      // Filter active plans
      final activePlansList = plans.where((p) => p.isActive).toList();

      // Filter completed plans (ended)
      final completedPlansList = plans.where((p) => p.hasEnded).toList();

      state = state.copyWith(
        plans: plans,
        activePlans: activePlansList,
        completedPlans: completedPlansList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Create plan
  Future<PlanModel?> createPlan({
    required String goalId,
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    required RepeatRule repeatRule,
    required TaskConfiguration taskConfig,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return null;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final plan = await _planService.createPlan(
        userId: user.id,
        goalId: goalId,
        name: name,
        description: description,
        startDate: startDate,
        endDate: endDate,
        repeatRule: repeatRule,
        taskConfig: taskConfig,
      );

      // Reload plans
      await loadPlans();

      // Reload tasks since new task was generated
      _ref.read(taskListProvider.notifier).loadTasks();

      return plan;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Update plan
  Future<PlanModel?> updatePlan({
    required String planId,
    String? description,
    DateTime? endDate,
    TaskConfiguration? taskConfig,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final plan = await _planService.updatePlan(
        planId: planId,
        description: description,
        endDate: endDate,
        taskConfig: taskConfig,
      );

      // Reload plans
      await loadPlans();

      return plan;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Delete plan
  Future<bool> deletePlan(String planId) async {
    print('[PlanStateProvider] deletePlan called with planId: $planId');
    state = state.copyWith(isLoading: true, error: null);

    try {
      print('[PlanStateProvider] Calling _planService.deletePlan...');
      final result = await _planService.deletePlan(planId);
      print('[PlanStateProvider] _planService.deletePlan result: $result');

      // Reload plans
      print('[PlanStateProvider] Reloading plans...');
      await loadPlans();
      print('[PlanStateProvider] Plans reloaded successfully');

      return result;
    } catch (e, stackTrace) {
      print('[PlanStateProvider] Error deleting plan: $e');
      print('[PlanStateProvider] Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Extend plan
  Future<PlanModel?> extendPlan({
    required String planId,
    required int additionalDays,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final plan = await _planService.extendPlan(
        planId: planId,
        additionalDays: additionalDays,
      );

      // Reload plans
      await loadPlans();

      return plan;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Get plan statistics
  Future<PlanStatistics?> getPlanStatistics(String planId) async {
    try {
      return await _planService.calculatePlanStatistics(planId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Get plan recommendations
  Future<List<String>> getPlanRecommendations(String planId) async {
    try {
      return await _planService.getPlanRecommendations(planId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }
}

/// Plan list provider
final planListProvider = StateNotifierProvider<PlanListNotifier, PlanListState>((ref) {
  final planRepository = ref.watch(planRepositoryProvider);
  final planService = ref.watch(planManagementServiceProvider);

  return PlanListNotifier(
    planRepository: planRepository,
    planService: planService,
    ref: ref,
  );
});

/// Goal plans provider - plans for a specific goal
final goalPlansProvider = FutureProvider.family<List<PlanModel>, String>((ref, goalId) async {
  final planRepository = ref.watch(planRepositoryProvider);
  return await planRepository.getGoalPlans(goalId);
});

/// Active plans provider
final activePlansProvider = Provider<List<PlanModel>>((ref) {
  final planState = ref.watch(planListProvider);
  return planState.activePlans;
});

/// Selected plan provider
final selectedPlanProvider = StateProvider<PlanModel?>((ref) => null);

/// Plan statistics provider
final planStatisticsProvider = FutureProvider.family<PlanStatistics?, String>((ref, planId) async {
  final planService = ref.watch(planManagementServiceProvider);
  try {
    return await planService.calculatePlanStatistics(planId);
  } catch (e) {
    return null;
  }
});