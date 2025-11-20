// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RepeatRule _$RepeatRuleFromJson(Map<String, dynamic> json) => RepeatRule(
  type: $enumDecode(_$RepeatTypeEnumMap, json['type']),
  customDays: (json['customDays'] as num?)?.toInt(),
);

Map<String, dynamic> _$RepeatRuleToJson(RepeatRule instance) =>
    <String, dynamic>{
      'type': _$RepeatTypeEnumMap[instance.type]!,
      'customDays': instance.customDays,
    };

const _$RepeatTypeEnumMap = {
  RepeatType.oneTime: 'oneTime',
  RepeatType.daily: 'daily',
  RepeatType.weekly: 'weekly',
  RepeatType.monthly: 'monthly',
  RepeatType.custom: 'custom',
};

TaskConfiguration _$TaskConfigurationFromJson(Map<String, dynamic> json) =>
    TaskConfiguration(
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      repeatCount: (json['repeatCount'] as num?)?.toInt(),
      evaluationOptions: (json['evaluationOptions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$TaskConfigurationToJson(TaskConfiguration instance) =>
    <String, dynamic>{
      'durationMinutes': instance.durationMinutes,
      'repeatCount': instance.repeatCount,
      'evaluationOptions': instance.evaluationOptions,
    };

PlanModel _$PlanModelFromJson(Map<String, dynamic> json) => PlanModel(
  id: json['id'] as String,
  userId: json['userId'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  goalId: json['goalId'] as String,
  startDate: DateTime.parse(json['startDate'] as String),
  endDate: DateTime.parse(json['endDate'] as String),
  repeatRule: RepeatRule.fromJson(json['repeatRule'] as Map<String, dynamic>),
  taskConfig: TaskConfiguration.fromJson(
    json['taskConfig'] as Map<String, dynamic>,
  ),
  status:
      $enumDecodeNullable(_$PlanStatusEnumMap, json['status']) ??
      PlanStatus.active,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  deletedAt: json['deletedAt'] == null
      ? null
      : DateTime.parse(json['deletedAt'] as String),
);

Map<String, dynamic> _$PlanModelToJson(PlanModel instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'name': instance.name,
  'description': instance.description,
  'goalId': instance.goalId,
  'startDate': instance.startDate.toIso8601String(),
  'endDate': instance.endDate.toIso8601String(),
  'repeatRule': instance.repeatRule,
  'taskConfig': instance.taskConfig,
  'status': _$PlanStatusEnumMap[instance.status]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'deletedAt': instance.deletedAt?.toIso8601String(),
};

const _$PlanStatusEnumMap = {
  PlanStatus.active: 'active',
  PlanStatus.paused: 'paused',
  PlanStatus.completed: 'completed',
  PlanStatus.deleted: 'deleted',
};
