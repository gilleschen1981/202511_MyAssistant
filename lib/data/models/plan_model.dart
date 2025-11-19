import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:myassistant/data/models/enums/task_type.dart';

part 'plan_model.g.dart';

/// Repeat Rule for Plans
@JsonSerializable()
class RepeatRule extends Equatable {
  final RepeatType type;
  final int? customDays; // Only used when type is custom

  const RepeatRule({
    required this.type,
    this.customDays,
  });

  /// Validate the rule
  bool get isValid {
    if (type == RepeatType.custom) {
      return customDays != null && customDays! > 0;
    }
    return true;
  }

  /// Get the interval in days
  int get intervalDays {
    switch (type) {
      case RepeatType.oneTime:
        return 0;
      case RepeatType.daily:
        return 1;
      case RepeatType.weekly:
        return 7;
      case RepeatType.monthly:
        return 30; // Approximate
      case RepeatType.custom:
        return customDays ?? 0;
    }
  }

  factory RepeatRule.fromJson(Map<String, dynamic> json) =>
      _$RepeatRuleFromJson(json);

  Map<String, dynamic> toJson() => _$RepeatRuleToJson(this);

  @override
  List<Object?> get props => [type, customDays];
}

/// Task Configuration
@JsonSerializable()
class TaskConfiguration extends Equatable {
  // Optional configuration items
  final int? durationMinutes; // Timer task duration
  final int? repeatCount; // Counter task repeat count
  final List<String>? evaluationOptions; // Evaluation options

  const TaskConfiguration({
    this.durationMinutes,
    this.repeatCount,
    this.evaluationOptions,
  });

  /// Get the task type based on configuration
  /// Business rule: Timer and evaluation are mutually exclusive
  TaskType get taskType {
    // Timer and evaluation cannot coexist
    if (durationMinutes != null && evaluationOptions != null) {
      throw StateError('Timer and evaluation cannot coexist');
    }

    // Determine task type
    if (durationMinutes != null && repeatCount != null) {
      return TaskType.timerWithCount;
    }
    if (durationMinutes != null) {
      return TaskType.timer;
    }
    if (repeatCount != null &&
        evaluationOptions != null &&
        evaluationOptions!.isNotEmpty) {
      return TaskType.counterWithEval;
    }
    if (repeatCount != null) {
      return TaskType.counter;
    }
    if (evaluationOptions != null && evaluationOptions!.isNotEmpty) {
      return TaskType.evaluation;
    }
    return TaskType.simple;
  }

  /// Validate configuration
  bool get isValid {
    // Timer and evaluation cannot coexist
    if (durationMinutes != null && evaluationOptions != null) {
      return false;
    }
    // Timer duration must be positive
    if (durationMinutes != null && durationMinutes! <= 0) {
      return false;
    }
    // Repeat count must be positive
    if (repeatCount != null && repeatCount! <= 0) {
      return false;
    }
    // Evaluation options must have at least 2 options
    if (evaluationOptions != null && evaluationOptions!.length < 2) {
      return false;
    }
    return true;
  }

  factory TaskConfiguration.fromJson(Map<String, dynamic> json) =>
      _$TaskConfigurationFromJson(json);

  Map<String, dynamic> toJson() => _$TaskConfigurationToJson(this);

  @override
  List<Object?> get props => [durationMinutes, repeatCount, evaluationOptions];
}

/// Plan Model
@JsonSerializable()
class PlanModel extends Equatable {
  // Base fields - UUID as primary key
  final String id; // UUID
  final String userId;
  final String name; // Unique within user scope, IMMUTABLE after creation
  final String? description;

  // Associated relationship
  final String goalId; // Must belong to a goal

  // Time settings
  final DateTime startDate;
  final DateTime endDate;
  final RepeatRule repeatRule;

  // Task configuration
  final TaskConfiguration taskConfig;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  // Soft delete support
  final DateTime? deletedAt;

  const PlanModel({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.goalId,
    required this.startDate,
    required this.endDate,
    required this.repeatRule,
    required this.taskConfig,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Check if plan is currently active
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) &&
        now.isBefore(endDate) &&
        deletedAt == null;
  }

  /// Check if plan has ended
  bool get hasEnded {
    return DateTime.now().isAfter(endDate);
  }

  /// Check if plan is deleted
  bool get isDeleted => deletedAt != null;

  /// Get duration in days
  int get durationDays {
    return endDate.difference(startDate).inDays;
  }

  /// Factory constructor for creating from JSON
  factory PlanModel.fromJson(Map<String, dynamic> json) =>
      _$PlanModelFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$PlanModelToJson(this);

  /// Copy with method for immutable updates
  /// Note: name field is NOT included as it's immutable after creation
  PlanModel copyWith({
    String? id,
    String? userId,
    String? description,
    String? goalId,
    DateTime? startDate,
    DateTime? endDate,
    RepeatRule? repeatRule,
    TaskConfiguration? taskConfig,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return PlanModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name, // Name is immutable, always use original
      description: description ?? this.description,
      goalId: goalId ?? this.goalId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      repeatRule: repeatRule ?? this.repeatRule,
      taskConfig: taskConfig ?? this.taskConfig,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        description,
        goalId,
        startDate,
        endDate,
        repeatRule,
        taskConfig,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}