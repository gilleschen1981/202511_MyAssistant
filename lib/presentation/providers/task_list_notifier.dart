import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/services/task_execution_service.dart';
import 'package:myassistant/data/services/task_refresh_service.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/di/providers/repository_providers.dart';
import 'package:myassistant/di/providers/service_providers.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';

part 'task_list_notifier.freezed.dart';
part 'task_list_notifier.g.dart';

/// Task list state with freezed
@freezed
class TaskListState with _$TaskListState {
  const factory TaskListState({
    required List<TaskModel> allTasks,
    required List<TaskModel> todayTasks,
    required List<TaskModel> activeTasks,
    required List<TaskModel> completedTasks,
    required Map<String, TimerSession> activeSessions,
    String? error,
  }) = _TaskListState;

  factory TaskListState.initial() => const TaskListState(
        allTasks: [],
        todayTasks: [],
        activeTasks: [],
        completedTasks: [],
        activeSessions: {},
      );
}

/// Task list notifier using modern AsyncNotifier pattern
@riverpod
class TaskListNotifier extends _$TaskListNotifier {
  late ITaskRepository _taskRepository;
  late TaskExecutionService _executionService;
  late TaskRefreshService _refreshService;

  @override
  FutureOr<TaskListState> build() async {
    // Get dependencies
    _taskRepository = ref.watch(taskRepositoryProvider);
    _executionService = ref.watch(taskExecutionServiceProvider);
    _refreshService = ref.watch(taskRefreshServiceProvider);

    // Load initial data
    return await _loadTasks();
  }

  /// Load tasks from repository
  Future<TaskListState> _loadTasks() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return TaskListState.initial();
    }

    try {
      // Get today's tasks
      final todayTasks = await _taskRepository.getTodayTasks(user.id);

      // Filter by status
      final activeTasks = todayTasks
          .where((t) => t.status == TaskStatus.active)
          .toList();
      final completedTasks = todayTasks
          .where((t) => t.status == TaskStatus.completed)
          .toList();

      // Get active timer sessions
      final activeSessions = _executionService.getActiveSessions();

      return TaskListState(
        allTasks: todayTasks,
        todayTasks: todayTasks,
        activeTasks: activeTasks,
        completedTasks: completedTasks,
        activeSessions: activeSessions,
      );
    } catch (e) {
      // Return state with error
      return TaskListState.initial().copyWith(
        error: e.toString(),
      );
    }
  }

  /// Refresh tasks
  Future<void> refreshTasks() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Set loading state
    state = const AsyncValue.loading();

    try {
      // Refresh expired and generate new tasks
      await _refreshService.refreshAllTasks(user.id);

      // Reload tasks
      final newState = await _loadTasks();
      state = AsyncValue.data(newState);
    } catch (e, stack) {
      // Keep existing data but add error
      state = AsyncValue.error(e, stack);
    }
  }

  /// Complete task
  Future<void> completeTask({
    required TaskModel task,
    int? actualDurationMinutes,
    String? evaluationResult,
    String? executionNote,
  }) async {
    // Optimistically update UI
    state = AsyncValue.data(
      state.value!.copyWith(
        activeTasks: state.value!.activeTasks
            .where((t) => t.id != task.id)
            .toList(),
        completedTasks: [
          ...state.value!.completedTasks,
          task.copyWith(status: TaskStatus.completed),
        ],
      ),
    );

    try {
      final result = await _executionService.completeTask(
        task: task,
        actualDurationMinutes: actualDurationMinutes,
        evaluationResult: evaluationResult,
        executionNote: executionNote,
      );

      // Reload to get accurate state including any new tasks
      final newState = await _loadTasks();

      // Add next task if generated
      if (result.nextTask != null) {
        state = AsyncValue.data(
          newState.copyWith(
            allTasks: [...newState.allTasks, result.nextTask!],
            todayTasks: [...newState.todayTasks, result.nextTask!],
            activeTasks: [...newState.activeTasks, result.nextTask!],
          ),
        );
      } else {
        state = AsyncValue.data(newState);
      }
    } catch (e) {
      // Reload to revert optimistic update
      final newState = await _loadTasks();
      state = AsyncValue.data(
        newState.copyWith(error: e.toString()),
      );
    }
  }

  /// Skip task
  Future<void> skipTask({
    required TaskModel task,
    String? skipReason,
  }) async {
    // Optimistically update UI
    state = AsyncValue.data(
      state.value!.copyWith(
        activeTasks: state.value!.activeTasks
            .where((t) => t.id != task.id)
            .toList(),
      ),
    );

    try {
      await _executionService.skipTask(
        task: task,
        skipReason: skipReason,
      );

      // Reload tasks to reflect changes
      final newState = await _loadTasks();
      state = AsyncValue.data(newState);
    } catch (e) {
      // Reload to revert optimistic update
      final newState = await _loadTasks();
      state = AsyncValue.data(
        newState.copyWith(error: e.toString()),
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
          // The timer service will handle the updates
        },
        onComplete: () async {
          // Reload tasks when timer completes
          final newState = await _loadTasks();
          state = AsyncValue.data(newState);
        },
      );

      // Update active sessions
      state = AsyncValue.data(
        state.value!.copyWith(
          activeSessions: {
            ...state.value!.activeSessions,
            task.id: session,
          },
        ),
      );

      return session;
    } catch (e) {
      state = AsyncValue.data(
        state.value!.copyWith(error: e.toString()),
      );
      return null;
    }
  }

  /// Stop timer
  void stopTimer(String taskId) {
    _executionService.stopTimer(taskId);

    // Update active sessions
    final sessions = Map<String, TimerSession>.from(
      state.value?.activeSessions ?? {},
    );
    sessions.remove(taskId);

    state = AsyncValue.data(
      state.value!.copyWith(activeSessions: sessions),
    );
  }

  /// Increment counter
  Future<TaskModel> incrementCount(
    TaskModel task, {
    int? actualDurationMinutes,
    String? evaluationResult,
  }) async {
    try {
      final updatedTask = await _executionService.incrementCount(
        task,
        actualDurationMinutes: actualDurationMinutes,
        evaluationResult: evaluationResult,
      );

      // Check if task is now completed
      final isCompleted = updatedTask.status == TaskStatus.completed;

      // Update task in list
      state = AsyncValue.data(
        state.value!.copyWith(
          allTasks: state.value!.allTasks.map((t) {
            return t.id == updatedTask.id ? updatedTask : t;
          }).toList(),
          todayTasks: state.value!.todayTasks.map((t) {
            return t.id == updatedTask.id ? updatedTask : t;
          }).toList(),
          // If completed, remove from activeTasks
          activeTasks: isCompleted
              ? state.value!.activeTasks.where((t) => t.id != updatedTask.id).toList()
              : state.value!.activeTasks.map((t) {
                  return t.id == updatedTask.id ? updatedTask : t;
                }).toList(),
          // If completed, add to completedTasks
          completedTasks: isCompleted
              ? [...state.value!.completedTasks, updatedTask]
              : state.value!.completedTasks,
        ),
      );

      return updatedTask;
    } catch (e) {
      state = AsyncValue.data(
        state.value!.copyWith(error: e.toString()),
      );
      rethrow;
    }
  }

  /// Decrement counter
  Future<void> decrementCount(TaskModel task) async {
    try {
      final updatedTask = await _executionService.decrementCount(task);

      // Update task in list
      state = AsyncValue.data(
        state.value!.copyWith(
          allTasks: state.value!.allTasks.map((t) {
            return t.id == updatedTask.id ? updatedTask : t;
          }).toList(),
          todayTasks: state.value!.todayTasks.map((t) {
            return t.id == updatedTask.id ? updatedTask : t;
          }).toList(),
          activeTasks: state.value!.activeTasks.map((t) {
            return t.id == updatedTask.id ? updatedTask : t;
          }).toList(),
        ),
      );
    } catch (e) {
      state = AsyncValue.data(
        state.value!.copyWith(error: e.toString()),
      );
    }
  }

  /// Re-execute completed task within execution window
  ///
  /// Creates a new task instance with the same configuration.
  /// Only works if:
  /// - Task is completed
  /// - Current time is within task's execution window
  Future<TaskModel?> reExecuteTask(TaskModel task) async {
    try {
      final newTask = await _executionService.reExecuteTask(task);

      if (newTask != null) {
        // Add new task to lists
        state = AsyncValue.data(
          state.value!.copyWith(
            allTasks: [...state.value!.allTasks, newTask],
            todayTasks: [...state.value!.todayTasks, newTask],
            activeTasks: [...state.value!.activeTasks, newTask],
          ),
        );
      }

      return newTask;
    } catch (e) {
      state = AsyncValue.data(
        state.value!.copyWith(error: e.toString()),
      );
      return null;
    }
  }
}

/// Computed providers for specific task lists
@riverpod
List<TaskModel> todayTasks(Ref ref) {
  final taskListAsync = ref.watch(taskListNotifierProvider);
  return taskListAsync.when(
    data: (state) => state.todayTasks,
    loading: () => [],
    error: (_, __) => [],
  );
}

@riverpod
List<TaskModel> activeTasks(Ref ref) {
  final taskListAsync = ref.watch(taskListNotifierProvider);
  return taskListAsync.when(
    data: (state) => state.activeTasks,
    loading: () => [],
    error: (_, __) => [],
  );
}

@riverpod
List<TaskModel> completedTasks(Ref ref) {
  final taskListAsync = ref.watch(taskListNotifierProvider);
  return taskListAsync.when(
    data: (state) => state.completedTasks,
    loading: () => [],
    error: (_, __) => [],
  );
}

@riverpod
Map<String, TimerSession> activeSessions(Ref ref) {
  final taskListAsync = ref.watch(taskListNotifierProvider);
  return taskListAsync.when(
    data: (state) => state.activeSessions,
    loading: () => {},
    error: (_, __) => {},
  );
}

/// Selected task provider
@riverpod
class SelectedTask extends _$SelectedTask {
  @override
  TaskModel? build() => null;

  void selectTask(TaskModel? task) {
    state = task;
  }
}

/// Task statistics provider
@riverpod
Future<TaskStatistics> taskStatistics(Ref ref) async {
  final taskListAsync = ref.watch(taskListNotifierProvider);

  return taskListAsync.when(
    data: (state) {
      final total = state.allTasks.length;
      final completed = state.completedTasks.length;
      final active = state.activeTasks.length;
      final skipped = state.allTasks
          .where((t) => t.status == TaskStatus.skipped)
          .length;

      return TaskStatistics(
        total: total,
        completed: completed,
        active: active,
        skipped: skipped,
        completionRate: total > 0 ? completed / total : 0.0,
      );
    },
    loading: () => TaskStatistics.empty(),
    error: (_, __) => TaskStatistics.empty(),
  );
}

/// Task statistics model
@freezed
class TaskStatistics with _$TaskStatistics {
  const factory TaskStatistics({
    required int total,
    required int completed,
    required int active,
    required int skipped,
    required double completionRate,
  }) = _TaskStatistics;

  factory TaskStatistics.empty() => const TaskStatistics(
        total: 0,
        completed: 0,
        active: 0,
        skipped: 0,
        completionRate: 0.0,
      );
}