import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/status.dart';

part 'goal_model.g.dart';

@JsonSerializable()
class GoalModel extends Equatable {
  // Base fields
  final String id;
  final String userId;
  final String title;
  final String? description;

  // Categories and tags
  final List<String> tags;

  // Time related
  final DateTime? deadline;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Priority and status
  final Priority priority;
  final GoalStatus status;

  // Success criteria
  final String? successCriteria;

  // Associated relationships
  final List<String> planIds;

  // Soft delete support (via status field - GoalStatus.deleted)
  // Note: deletedAt timestamp still tracked separately for audit
  final DateTime? deletedAt;

  const GoalModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.tags,
    this.deadline,
    required this.createdAt,
    required this.updatedAt,
    required this.priority,
    required this.status,
    this.successCriteria,
    required this.planIds,
    this.deletedAt,
  });

  // Computed properties
  int get planCount => planIds.length;
  bool get isDeleted => status == GoalStatus.deleted;

  int? get daysRemaining {
    if (deadline == null) return null;
    final now = DateTime.now();
    if (now.isAfter(deadline!)) return 0;
    return deadline!.difference(now).inDays;
  }

  bool get isActive => status == GoalStatus.active;

  // Factory constructor for creating from JSON
  factory GoalModel.fromJson(Map<String, dynamic> json) =>
      _$GoalModelFromJson(json);

  // Method to convert to JSON
  Map<String, dynamic> toJson() => _$GoalModelToJson(this);

  // Copy with method for immutable updates
  GoalModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    List<String>? tags,
    DateTime? deadline,
    DateTime? createdAt,
    DateTime? updatedAt,
    Priority? priority,
    GoalStatus? status,
    String? successCriteria,
    List<String>? planIds,
    DateTime? deletedAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      successCriteria: successCriteria ?? this.successCriteria,
      planIds: planIds ?? this.planIds,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        description,
        tags,
        deadline,
        createdAt,
        updatedAt,
        priority,
        status,
        successCriteria,
        planIds,
        deletedAt,
      ];
}