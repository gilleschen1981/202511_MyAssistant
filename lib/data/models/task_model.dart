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

  // Timestamp
  final DateTime createdAt;
  final DateTime? deletedAt; // For audit trail

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
    required this.createdAt,
    this.deletedAt,
  });

  // Computed properties
  bool get isDeleted => status == TaskStatus.deleted;
  bool get isExpired => DateTime.now().isAfter(windowEndTime);
  bool get canExecute => status == TaskStatus.active && !isExpired;
  bool get isCompleted => status == TaskStatus.completed;
  bool get isSkipped => status == TaskStatus.skipped;

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

  /// Factory constructor for creating from JSON
  factory TaskModel.fromJson(Map<String, dynamic> json) =>
      _$TaskModelFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$TaskModelToJson(this);

  /// Copy with method for immutable updates
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
    DateTime? createdAt,
    DateTime? deletedAt,
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
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
        createdAt,
        deletedAt,
      ];
}