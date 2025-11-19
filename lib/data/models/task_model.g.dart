// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskModel _$TaskModelFromJson(Map<String, dynamic> json) => TaskModel(
  id: json['id'] as String,
  userId: json['userId'] as String,
  planId: json['planId'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  config: TaskConfiguration.fromJson(json['config'] as Map<String, dynamic>),
  windowStartTime: DateTime.parse(json['windowStartTime'] as String),
  windowEndTime: DateTime.parse(json['windowEndTime'] as String),
  status: $enumDecode(_$TaskStatusEnumMap, json['status']),
  currentCount: (json['currentCount'] as num?)?.toInt() ?? 0,
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  skippedAt: json['skippedAt'] == null
      ? null
      : DateTime.parse(json['skippedAt'] as String),
  actualDurationMinutes: (json['actualDurationMinutes'] as num?)?.toInt(),
  evaluationResult: json['evaluationResult'] as String?,
  executionNote: json['executionNote'] as String?,
  repeatExecutionCount: (json['repeatExecutionCount'] as num?)?.toInt() ?? 0,
  originalTaskId: json['originalTaskId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$TaskModelToJson(TaskModel instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'planId': instance.planId,
  'name': instance.name,
  'description': instance.description,
  'config': instance.config,
  'windowStartTime': instance.windowStartTime.toIso8601String(),
  'windowEndTime': instance.windowEndTime.toIso8601String(),
  'status': _$TaskStatusEnumMap[instance.status]!,
  'currentCount': instance.currentCount,
  'completedAt': instance.completedAt?.toIso8601String(),
  'skippedAt': instance.skippedAt?.toIso8601String(),
  'actualDurationMinutes': instance.actualDurationMinutes,
  'evaluationResult': instance.evaluationResult,
  'executionNote': instance.executionNote,
  'repeatExecutionCount': instance.repeatExecutionCount,
  'originalTaskId': instance.originalTaskId,
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$TaskStatusEnumMap = {
  TaskStatus.active: 'active',
  TaskStatus.completed: 'completed',
  TaskStatus.skipped: 'skipped',
};
