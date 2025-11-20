// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoalModel _$GoalModelFromJson(Map<String, dynamic> json) => GoalModel(
  id: json['id'] as String,
  userId: json['userId'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
  deadline: json['deadline'] == null
      ? null
      : DateTime.parse(json['deadline'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  priority: $enumDecode(_$PriorityEnumMap, json['priority']),
  status: $enumDecode(_$GoalStatusEnumMap, json['status']),
  successCriteria: json['successCriteria'] as String?,
  planIds: (json['planIds'] as List<dynamic>).map((e) => e as String).toList(),
  deletedAt: json['deletedAt'] == null
      ? null
      : DateTime.parse(json['deletedAt'] as String),
);

Map<String, dynamic> _$GoalModelToJson(GoalModel instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'title': instance.title,
  'description': instance.description,
  'tags': instance.tags,
  'deadline': instance.deadline?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'priority': _$PriorityEnumMap[instance.priority]!,
  'status': _$GoalStatusEnumMap[instance.status]!,
  'successCriteria': instance.successCriteria,
  'planIds': instance.planIds,
  'deletedAt': instance.deletedAt?.toIso8601String(),
};

const _$PriorityEnumMap = {
  Priority.high: 'high',
  Priority.medium: 'medium',
  Priority.low: 'low',
};

const _$GoalStatusEnumMap = {
  GoalStatus.active: 'active',
  GoalStatus.paused: 'paused',
  GoalStatus.completed: 'completed',
  GoalStatus.deleted: 'deleted',
};
