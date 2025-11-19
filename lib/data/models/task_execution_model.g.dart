// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_execution_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskExecutionModel _$TaskExecutionModelFromJson(Map<String, dynamic> json) =>
    TaskExecutionModel(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      userId: json['userId'] as String,
      executionType: json['executionType'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      counterValue: (json['counterValue'] as num?)?.toInt(),
      evaluationScore: json['evaluationScore'] as String?,
      notes: json['notes'] as String?,
      executionData: json['executionData'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$TaskExecutionModelToJson(TaskExecutionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'taskId': instance.taskId,
      'userId': instance.userId,
      'executionType': instance.executionType,
      'startedAt': instance.startedAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'durationMinutes': instance.durationMinutes,
      'counterValue': instance.counterValue,
      'evaluationScore': instance.evaluationScore,
      'notes': instance.notes,
      'executionData': instance.executionData,
      'createdAt': instance.createdAt.toIso8601String(),
    };
