import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/services/task_execution_service.dart';
import 'package:myassistant/data/services/task_refresh_service.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/di/providers/repository_providers.dart';
import 'package:myassistant/di/providers/service_providers.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';

/// Task list state
class TaskListState {
  final List<TaskModel> allTasks;
  final List<TaskModel> todayTasks;
  final List<TaskModel> activeTasks;
  final List<TaskModel> completedTasks;
  final bool isLoading;
  final String? error;
  final Map<String, TimerSession> activeSessions;

  const TaskListState({
    required this.allTasks,
    required this.todayTasks,
    required this.activeTasks,
    required this.completedTasks,
    required this.isLoading,
    this.error,
    required this.activeSessions,
  });

  factory TaskListState.initial() {
    return const TaskListState(
      allTasks: [],
      todayTasks: [],
      activeTasks: [],
      completedTasks: [],
      isLoading: false,
      activeSessions: {},
    );
  }

  TaskListState copyWith({
    List<TaskModel>? allTasks,
    List<TaskModel>? todayTasks,
    List<TaskModel>? activeTasks,
    List<TaskModel>? completedTasks,
    bool? isLoading,
    String? error,
    Map<String, TimerSession>? activeSessions,
  }) {
    return TaskListState(
      allTasks: allTasks ?? this.allTasks,
      todayTasks: todayTasks ?? this.todayTasks,
      activeTasks: activeTasks ?? this.activeTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeSessions: activeSessions ?? this.activeSessions,
    );
  }
}

/// Task list state notifier
class TaskListNotifier extends StateNotifier<TaskListState> {
  final ITaskRepository _taskRepository;
  final TaskExecutionService _executionService;
  final TaskRefreshService _refreshService;
  final Ref _ref;

  TaskListNotifier({
    required ITaskRepository taskRepository,
    required TaskExecutionService executionService,
    required TaskRefreshService refreshService,
    required Ref ref,
  })  : _taskRepository = taskRepository,
        _executionService = executionService,
        _refreshService = refreshService,
        _ref = ref,
        super(TaskListState.initial());

  /// Load tasks
  Future<void> loadTasks() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get today's tasks
      final todayTasks = await _taskRepository.getTodayTasks(user.id);

      // Filter by status
      final activeTasks = todayTasks.where((t) => t.status == TaskStatus.active).toList();
      final completedTasks = todayTasks.where((t) => t.status == TaskStatus.completed).toList();

      // Get active timer sessions
      final activeSessions = _executionService.getActiveSessions();

      state = state.copyWith(
        allTasks: todayTasks,
        todayTasks: todayTasks,
        activeTasks: activeTasks,
        completedTasks: completedTasks,
        isLoading: false,
        activeSessions: activeSessions,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh tasks
  Future<void> refreshTasks() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    try {
      // Refresh expired and generate new tasks
      await _refreshService.refreshAllTasks(user.id);

      // Reload tasks
      await loadTasks();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Complete task
  Future<void> completeTask({
    required TaskModel task,
    int? actualDurationMinutes,
    String? evaluationResult,
    String? executionNote,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _executionService.completeTask(
        task: task,
        actualDurationMinutes: actualDurationMinutes,
        evaluationResult: evaluationResult,
        executionNote: executionNote,
      );

      // Add next task if generated
      if (result.nextTask != null) {
        final updatedTasks = [...state.allTasks, result.nextTask!];
        state = state.copyWith(allTasks: updatedTasks);
      }

      // Reload tasks to reflect changes
      await loadTasks();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Skip task
  Future<void> skipTask({
    required TaskModel task,
    String? skipReason,
  }) async {
    print('[TaskListNotifier] skipTask called for task: ${task.id}, reason: $skipReason');
    state = state.copyWith(isLoading: true, error: null);

    try {
      print('[TaskListNotifier] Calling executionService.skipTask');
      await _executionService.skipTask(
        task: task,
        skipReason: skipReason,
      );

      print('[TaskListNotifier] Skip successful, reloading tasks');
      // Reload tasks to reflect changes
      await loadTasks();
      print('[TaskListNotifier] Tasks reloaded successfully');
    } catch (e) {
      print('[TaskListNotifier] Error skipping task: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Start timer
  Future<TimerSession?> startTimer(TaskModel task) async {
    try {
      final session = await _executionService.startTimer(
        task: task,
        onTick: (remaining) {
          // Update UI with remaining time
          // This could trigger a state update if needed
        },
        onComplete: () {
          // Reload tasks when timer completes
          loadTasks();
        },
      );

      // Update active sessions
      final sessions = Map<String, TimerSession>.from(state.activeSessions);
      sessions[task.id] = session;
      state = state.copyWith(activeSessions: sessions);

      return session;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Stop timer
  void stopTimer(String taskId) {
    _executionService.stopTimer(taskId);

    // Update active sessions
    final sessions = Map<String, TimerSession>.from(state.activeSessions);
    sessions.remove(taskId);
    state = state.copyWith(activeSessions: sessions);
  }

  /// Increment counter
  Future<void> incrementCount(
    TaskModel task, {
    String? evaluationResult,
  }) async {
    try {
      await _executionService.incrementCount(
        task,
        evaluationResult: evaluationResult,
      );

      // Reload tasks to reflect changes (including completion if reached target)
      await loadTasks();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Decrement counter
  Future<void> decrementCount(TaskModel task) async {
    try {
      final updatedTask = await _executionService.decrementCount(task);

      // Update task in list
      final updatedTasks = state.allTasks.map((t) {
        return t.id == updatedTask.id ? updatedTask : t;
      }).toList();

      state = state.copyWith(allTasks: updatedTasks);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Task list provider
final taskListProvider = StateNotifierProvider<TaskListNotifier, TaskListState>((ref) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final executionService = ref.watch(taskExecutionServiceProvider);
  final refreshService = ref.watch(taskRefreshServiceProvider);

  return TaskListNotifier(
    taskRepository: taskRepository,
    executionService: executionService,
    refreshService: refreshService,
    ref: ref,
  );
});

/// Today's tasks provider
final todayTasksProvider = Provider<List<TaskModel>>((ref) {
  final taskState = ref.watch(taskListProvider);
  return taskState.todayTasks;
});

/// Active tasks provider
final activeTasksProvider = Provider<List<TaskModel>>((ref) {
  final taskState = ref.watch(taskListProvider);
  return taskState.activeTasks;
});

/// Completed tasks provider
final completedTasksProvider = Provider<List<TaskModel>>((ref) {
  final taskState = ref.watch(taskListProvider);
  return taskState.completedTasks;
});

/// Active timer sessions provider
final activeSessionsProvider = Provider<Map<String, TimerSession>>((ref) {
  final taskState = ref.watch(taskListProvider);
  return taskState.activeSessions;
});