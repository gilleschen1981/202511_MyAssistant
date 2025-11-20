import 'dart:async';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/services/notification_service.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/core/errors/exceptions.dart';

/// Timer session for timer tasks
class TimerSession {
  final String taskId;
  final DateTime startTime;
  final Duration targetDuration;
  DateTime? pauseTime;
  Duration pausedDuration = Duration.zero;
  Timer? _timer;
  final Function(Duration)? onTick;
  final Function()? onComplete;

  TimerSession({
    required this.taskId,
    required this.startTime,
    required this.targetDuration,
    this.onTick,
    this.onComplete,
  });

  Duration get elapsedDuration {
    if (pauseTime != null) {
      return pauseTime!.difference(startTime) - pausedDuration;
    }
    return DateTime.now().difference(startTime) - pausedDuration;
  }

  Duration get remainingDuration {
    final remaining = targetDuration - elapsedDuration;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isCompleted => remainingDuration == Duration.zero;
  bool get isPaused => pauseTime != null;
  bool get isRunning => _timer != null && !isPaused;

  void start() {
    if (isRunning) return;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused) {
        onTick?.call(remainingDuration);

        if (isCompleted) {
          timer.cancel();
          _timer = null;
          onComplete?.call();
        }
      }
    });
  }

  void pause() {
    if (!isRunning || isPaused) return;
    pauseTime = DateTime.now();
  }

  void resume() {
    if (!isPaused) return;
    pausedDuration += DateTime.now().difference(pauseTime!);
    pauseTime = null;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
  }
}

/// Task completion result
class TaskCompletionResult {
  final TaskModel completedTask;
  final TaskModel? nextTask;
  final TaskStatistics statistics;

  TaskCompletionResult({
    required this.completedTask,
    this.nextTask,
    required this.statistics,
  });
}

/// Task statistics
class TaskStatistics {
  final int todayCompleted;
  final int todayRemaining;
  final int todaySkipped;
  final double completionRate;

  TaskStatistics({
    required this.todayCompleted,
    required this.todayRemaining,
    required this.todaySkipped,
    required this.completionRate,
  });
}

/// Task execution service - handles task execution, completion, and skipping.
///
/// This service manages the execution lifecycle of tasks including:
/// - Timer sessions for time-based tasks
/// - Counter management for count-based tasks
/// - Task completion with various execution modes
/// - Unlimited task re-execution within time windows
/// - Task skipping with reasons
///
/// Key features:
/// - Supports all task types (simple, timer, counter, evaluation, combined)
/// - Manages active timer sessions with pause/resume functionality
/// - Automatic task completion when targets are reached
/// - Statistics tracking for completion rates
///
/// Example usage:
/// ```dart
/// // Complete a simple task
/// final result = await executionService.completeTask(
///   task: myTask,
///   executionNote: 'Completed successfully',
/// );
///
/// // Start a timer task
/// final session = await executionService.startTimer(
///   task: timerTask,
///   onTick: (remaining) => print('Time left: $remaining'),
///   onComplete: () => print('Timer finished!'),
/// );
/// ```
class TaskExecutionService {
  final ITaskRepository _taskRepository;
  final IPlanRepository _planRepository;
  final NotificationService _notificationService;

  /// Active timer sessions indexed by task ID
  final Map<String, TimerSession> _activeSessions = {};

  TaskExecutionService({
    required ITaskRepository taskRepository,
    required IPlanRepository planRepository,
    required NotificationService notificationService,
  })  : _taskRepository = taskRepository,
        _planRepository = planRepository,
        _notificationService = notificationService;

  /// Starts a timer session for a timer-based task.
  ///
  /// Creates and manages a countdown timer for tasks with duration configuration.
  /// The timer automatically completes the task when finished.
  ///
  /// Parameters:
  /// - [task]: The task to start timer for (must be active and have durationMinutes)
  /// - [onTick]: Optional callback called every second with remaining duration
  /// - [onComplete]: Optional callback called when timer completes
  ///
  /// Returns the [TimerSession] for managing pause/resume operations.
  ///
  /// Throws:
  /// - [BusinessException] if task is not active or not a timer task
  Future<TimerSession> startTimer({
    required TaskModel task,
    Function(Duration)? onTick,
    Function()? onComplete,
  }) async {
    // 1. Validate task status
    if (task.status != TaskStatus.active) {
      throw const BusinessException('Only active tasks can be started');
    }

    // 2. Validate task type
    if (task.config.durationMinutes == null) {
      throw const BusinessException('This is not a timer task');
    }

    // 3. Check if session already exists
    if (_activeSessions.containsKey(task.id)) {
      return _activeSessions[task.id]!;
    }

    // 4. Create timer session
    final session = TimerSession(
      taskId: task.id,
      startTime: DateTime.now(),
      targetDuration: Duration(minutes: task.config.durationMinutes!),
      onTick: onTick,
      onComplete: () {
        onComplete?.call();
        // Auto-complete task when timer finishes
        completeTask(
          task: task,
          actualDurationMinutes: task.config.durationMinutes,
        );
      },
    );

    // 5. Start the timer
    session.start();
    _activeSessions[task.id] = session;

    return session;
  }

  /// Get active timer session
  TimerSession? getTimerSession(String taskId) {
    return _activeSessions[taskId];
  }

  /// Stop timer
  void stopTimer(String taskId) {
    final session = _activeSessions[taskId];
    if (session != null) {
      session.stop();
      _activeSessions.remove(taskId);
    }
  }

  /// Completes a task with appropriate execution data.
  ///
  /// Marks a task as completed and handles post-completion logic including:
  /// - Validation of completion requirements
  /// - Stopping active timer sessions
  /// - Creating repeat executions if allowed
  /// - Updating statistics
  /// - Sending notifications
  ///
  /// Parameters:
  /// - [task]: The task to complete (must be active and not expired)
  /// - [actualDurationMinutes]: Actual duration spent on timer tasks
  /// - [evaluationResult]: Selected option for evaluation tasks
  /// - [executionNote]: Optional note about the execution
  ///
  /// Returns [TaskCompletionResult] containing:
  /// - completedTask: The updated task model
  /// - nextTask: Optional repeat execution if created
  /// - statistics: Updated task statistics
  ///
  /// Throws:
  /// - [BusinessException] if task is already completed/skipped or expired
  /// - [ValidationException] if evaluation result is missing or invalid
  ///
  /// Note: Tasks support unlimited re-execution within their time window
  Future<TaskCompletionResult> completeTask({
    required TaskModel task,
    int? actualDurationMinutes,
    String? evaluationResult,
    String? executionNote,
  }) async {
    // 1. Validate task status
    if (task.status != TaskStatus.active) {
      throw const BusinessException('Task is already completed or skipped');
    }

    // 2. Validate task window
    if (task.isExpired) {
      throw const BusinessException('Task has expired');
    }

    // 3. Validate task completion data
    _validateTaskCompletion(task, evaluationResult);

    // 4. Complete the task
    final completedTask = await _taskRepository.completeTask(
      taskId: task.id,
      actualDurationMinutes: actualDurationMinutes,
      evaluationResult: evaluationResult,
      executionNote: executionNote,
    );

    // 5. Stop timer if active
    stopTimer(task.id);

    // 6. Note: Repeat execution is no longer supported in v4.0
    // Each task is now an independent entity
    // To repeat a task, create a new independent task with the same configuration
    TaskModel? nextTask;

    // 7. Get statistics
    final statistics = await _getTaskStatistics(task.userId);

    // 8. Send completion notification
    await _notificationService.notifyTaskCompleted(completedTask);

    return TaskCompletionResult(
      completedTask: completedTask,
      nextTask: nextTask,
      statistics: statistics,
    );
  }

  /// Skip task
  Future<TaskModel> skipTask({
    required TaskModel task,
    String? skipReason,
  }) async {
    // 1. Validate task status
    if (task.status != TaskStatus.active) {
      throw const BusinessException('Only active tasks can be skipped');
    }

    // 2. Skip the task
    final skippedTask = await _taskRepository.skipTask(
      taskId: task.id,
      reason: skipReason,
    );

    // 3. Stop timer if active
    stopTimer(task.id);

    // 4. Send skip notification
    await _notificationService.notifyTaskSkipped(skippedTask);

    return skippedTask;
  }

  /// Increment counter (for counter tasks)
  Future<TaskModel> incrementCount(TaskModel task) async {
    // 1. Validate task type
    if (task.config.repeatCount == null) {
      throw const BusinessException('This is not a counter task');
    }

    // 2. Validate task status
    if (task.status != TaskStatus.active) {
      throw const BusinessException('Only active tasks can be updated');
    }

    // 3. Increment count
    final newCount = task.currentCount + 1;

    // 4. Update progress
    final updatedTask = await _taskRepository.updateTaskProgress(task.id, newCount);

    // 5. Check if reached target
    if (newCount >= task.config.repeatCount!) {
      // Auto-complete task
      return (await completeTask(
        task: updatedTask,
        executionNote: 'Completed after reaching target count',
      )).completedTask;
    }

    return updatedTask;
  }

  /// Decrement counter (for counter tasks)
  Future<TaskModel> decrementCount(TaskModel task) async {
    // 1. Validate task type
    if (task.config.repeatCount == null) {
      throw const BusinessException('This is not a counter task');
    }

    // 2. Validate task status
    if (task.status != TaskStatus.active) {
      throw const BusinessException('Only active tasks can be updated');
    }

    // 3. Decrement count
    final newCount = (task.currentCount - 1).clamp(0, task.config.repeatCount!);

    // 4. Update progress
    return await _taskRepository.updateTaskProgress(task.id, newCount);
  }

  /// Re-execute completed task (create a new similar task)
  // Note: reExecuteTask is no longer supported in v4.0
  // Repeat execution has been removed
  // To repeat a task, create a new independent task with the same configuration

  /// Validate task completion data
  void _validateTaskCompletion(TaskModel task, String? evaluationResult) {
    // Evaluation task must have evaluation result
    if (task.config.evaluationOptions != null &&
        task.config.evaluationOptions!.isNotEmpty &&
        evaluationResult == null) {
      throw const ValidationException('Evaluation task requires an evaluation result');
    }

    // Validate evaluation result validity
    if (evaluationResult != null &&
        task.config.evaluationOptions != null &&
        !task.config.evaluationOptions!.contains(evaluationResult)) {
      throw const ValidationException('Invalid evaluation option');
    }
  }

  /// Get task statistics
  Future<TaskStatistics> _getTaskStatistics(String userId) async {
    final todayTasks = await _taskRepository.getTodayTasks(userId);

    final completed = todayTasks.where((t) => t.status == TaskStatus.completed).length;
    final active = todayTasks.where((t) => t.status == TaskStatus.active).length;
    final skipped = todayTasks.where((t) => t.status == TaskStatus.skipped).length;

    final total = todayTasks.length;
    final completionRate = total > 0 ? completed / total : 0.0;

    return TaskStatistics(
      todayCompleted: completed,
      todayRemaining: active,
      todaySkipped: skipped,
      completionRate: completionRate,
    );
  }

  /// Get all active timer sessions
  Map<String, TimerSession> getActiveSessions() {
    return Map.unmodifiable(_activeSessions);
  }

  /// Pause all timers
  void pauseAllTimers() {
    for (final session in _activeSessions.values) {
      session.pause();
    }
  }

  /// Resume all timers
  void resumeAllTimers() {
    for (final session in _activeSessions.values) {
      session.resume();
    }
  }

  /// Dispose all resources
  void dispose() {
    for (final session in _activeSessions.values) {
      session.dispose();
    }
    _activeSessions.clear();
  }
}