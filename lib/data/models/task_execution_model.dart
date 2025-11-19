import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'task_execution_model.g.dart';

/// Model representing a task execution record
@JsonSerializable()
class TaskExecutionModel extends Equatable {
  final String id;
  final String taskId;
  final String userId;
  final String executionType; // simple, timer, counter, evaluation, timerWithCount, countWithEvaluation
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? durationMinutes;
  final int? counterValue;
  final String? evaluationScore;
  final String? notes;
  final Map<String, dynamic>? executionData;
  final DateTime createdAt;

  const TaskExecutionModel({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.executionType,
    required this.startedAt,
    this.completedAt,
    this.durationMinutes,
    this.counterValue,
    this.evaluationScore,
    this.notes,
    this.executionData,
    required this.createdAt,
  });

  /// Factory constructor for creating a TaskExecutionModel from JSON
  factory TaskExecutionModel.fromJson(Map<String, dynamic> json) =>
      _$TaskExecutionModelFromJson(json);

  /// Method to convert TaskExecutionModel to JSON
  Map<String, dynamic> toJson() => _$TaskExecutionModelToJson(this);

  /// Create a copy of TaskExecutionModel with updated fields
  TaskExecutionModel copyWith({
    String? id,
    String? taskId,
    String? userId,
    String? executionType,
    DateTime? startedAt,
    DateTime? completedAt,
    int? durationMinutes,
    int? counterValue,
    String? evaluationScore,
    String? notes,
    Map<String, dynamic>? executionData,
    DateTime? createdAt,
  }) {
    return TaskExecutionModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      executionType: executionType ?? this.executionType,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      counterValue: counterValue ?? this.counterValue,
      evaluationScore: evaluationScore ?? this.evaluationScore,
      notes: notes ?? this.notes,
      executionData: executionData ?? this.executionData,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Create a new TaskExecution from a task completion
  factory TaskExecutionModel.fromTaskCompletion({
    required String id,
    required String taskId,
    required String userId,
    required String executionType,
    required DateTime startedAt,
    DateTime? completedAt,
    int? durationMinutes,
    int? counterValue,
    String? evaluationScore,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return TaskExecutionModel(
      id: id,
      taskId: taskId,
      userId: userId,
      executionType: executionType,
      startedAt: startedAt,
      completedAt: completedAt ?? DateTime.now(),
      durationMinutes: durationMinutes,
      counterValue: counterValue,
      evaluationScore: evaluationScore,
      notes: notes,
      executionData: metadata,
      createdAt: DateTime.now(),
    );
  }

  /// Check if execution is completed
  bool get isCompleted => completedAt != null;

  /// Get actual duration if timer type
  Duration? get actualDuration {
    if (executionType.contains('timer') && completedAt != null) {
      return completedAt!.difference(startedAt);
    }
    return durationMinutes != null ? Duration(minutes: durationMinutes!) : null;
  }

  /// Get completion percentage for counter type
  double? getCompletionPercentage(int targetCount) {
    if (executionType.contains('counter') && counterValue != null && targetCount > 0) {
      return (counterValue! / targetCount).clamp(0.0, 1.0);
    }
    return null;
  }

  /// Parse evaluation score as numeric value
  double? get evaluationScoreNumeric {
    if (evaluationScore != null) {
      return double.tryParse(evaluationScore!);
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        taskId,
        userId,
        executionType,
        startedAt,
        completedAt,
        durationMinutes,
        counterValue,
        evaluationScore,
        notes,
        executionData,
        createdAt,
      ];
}

/// Enum for execution types
enum ExecutionType {
  simple('simple'),
  timer('timer'),
  counter('counter'),
  evaluation('evaluation'),
  timerWithCount('timerWithCount'),
  countWithEvaluation('countWithEvaluation');

  final String value;
  const ExecutionType(this.value);

  static ExecutionType fromString(String value) {
    return ExecutionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ExecutionType.simple,
    );
  }
}