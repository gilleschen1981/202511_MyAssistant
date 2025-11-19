import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/plan_model.dart';

part 'task_model.g.dart';

@JsonSerializable()
class TaskModel extends Equatable {
  // Base fields
  final String id; // UUID
  final String userId;
  final String planId; // Source plan ID

  // Task info (inherited from plan)
  final String name;
  final String? description;
  final TaskConfiguration config;

  // Execution window
  final DateTime windowStartTime;
  final DateTime windowEndTime;

  // Status and execution data
  final TaskStatus status;
  final int currentCount; // Current completion count for counter tasks

  // Completion info
  final DateTime? completedAt;
  final DateTime? skippedAt;
  final int? actualDurationMinutes; // Actual execution duration for timer tasks
  final String? evaluationResult; // Evaluation result for evaluation tasks
  final String? executionNote;

  // For repeat executions within the same window
  final int repeatExecutionCount; // Number of times this task has been re-executed
  final String? originalTaskId; // If this is a repeat, reference to original task

  // Timestamp
  final DateTime createdAt;

  const TaskModel({
    required this.id,
    required this.userId,
    required this.planId,
    required this.name,
    this.description,
    required this.config,
    required this.windowStartTime,
    required this.windowEndTime,
    required this.status,
    this.currentCount = 0,
    this.completedAt,
    this.skippedAt,
    this.actualDurationMinutes,
    this.evaluationResult,
    this.executionNote,
    this.repeatExecutionCount = 0,
    this.originalTaskId,
    required this.createdAt,
  });

  // Computed properties
  bool get isExpired => DateTime.now().isAfter(windowEndTime);
  bool get canExecute => status == TaskStatus.active && !isExpired;
  bool get isCompleted => status == TaskStatus.completed;
  bool get isSkipped => status == TaskStatus.skipped;
  bool get isRepeatExecution => originalTaskId != null;

  /// Progress calculation for counter tasks
  double get progress {
    if (config.repeatCount == null) return 0;
    if (config.repeatCount! <= 0) return 0;
    return (currentCount / config.repeatCount!).clamp(0.0, 1.0);
  }

  /// Check if task is in current window
  bool get isInCurrentWindow {
    final now = DateTime.now();
    return now.isAfter(windowStartTime) && now.isBefore(windowEndTime);
  }

  /// Check if task can be repeated (unlimited repeats allowed)
  bool get canRepeat {
    return isCompleted && isInCurrentWindow;
  }

  /// Factory constructor for creating from JSON
  factory TaskModel.fromJson(Map<String, dynamic> json) =>
      _$TaskModelFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$TaskModelToJson(this);

  /// Copy with method for immutable updates
  /// Note: Tasks cannot be deleted, so no deletedAt field
  TaskModel copyWith({
    String? id,
    String? userId,
    String? planId,
    String? name,
    String? description,
    TaskConfiguration? config,
    DateTime? windowStartTime,
    DateTime? windowEndTime,
    TaskStatus? status,
    int? currentCount,
    DateTime? completedAt,
    DateTime? skippedAt,
    int? actualDurationMinutes,
    String? evaluationResult,
    String? executionNote,
    int? repeatExecutionCount,
    String? originalTaskId,
    DateTime? createdAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      name: name ?? this.name,
      description: description ?? this.description,
      config: config ?? this.config,
      windowStartTime: windowStartTime ?? this.windowStartTime,
      windowEndTime: windowEndTime ?? this.windowEndTime,
      status: status ?? this.status,
      currentCount: currentCount ?? this.currentCount,
      completedAt: completedAt ?? this.completedAt,
      skippedAt: skippedAt ?? this.skippedAt,
      actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
      evaluationResult: evaluationResult ?? this.evaluationResult,
      executionNote: executionNote ?? this.executionNote,
      repeatExecutionCount: repeatExecutionCount ?? this.repeatExecutionCount,
      originalTaskId: originalTaskId ?? this.originalTaskId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Create a repeat execution of this task
  TaskModel createRepeatExecution(String newId) {
    return TaskModel(
      id: newId,
      userId: userId,
      planId: planId,
      name: name,
      description: description,
      config: config,
      windowStartTime: windowStartTime,
      windowEndTime: windowEndTime,
      status: TaskStatus.active, // New execution starts as active
      currentCount: 0, // Reset counter
      completedAt: null, // Reset completion
      skippedAt: null,
      actualDurationMinutes: null,
      evaluationResult: null,
      executionNote: null,
      repeatExecutionCount: repeatExecutionCount + 1,
      originalTaskId: originalTaskId ?? id, // Reference original task
      createdAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        planId,
        name,
        description,
        config,
        windowStartTime,
        windowEndTime,
        status,
        currentCount,
        completedAt,
        skippedAt,
        actualDurationMinutes,
        evaluationResult,
        executionNote,
        repeatExecutionCount,
        originalTaskId,
        createdAt,
      ];
}