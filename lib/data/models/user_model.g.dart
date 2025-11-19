// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: json['id'] as String,
  username: json['username'] as String,
  email: json['email'] as String,
  passwordHash: json['passwordHash'] as String,
  displayName: json['displayName'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  status: $enumDecode(_$UserStatusEnumMap, json['status']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  totalGoals: (json['totalGoals'] as num?)?.toInt(),
  completedGoals: (json['completedGoals'] as num?)?.toInt(),
  activePlans: (json['activePlans'] as num?)?.toInt(),
  completedTasks: (json['completedTasks'] as num?)?.toInt(),
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'email': instance.email,
  'passwordHash': instance.passwordHash,
  'displayName': instance.displayName,
  'avatarUrl': instance.avatarUrl,
  'status': _$UserStatusEnumMap[instance.status]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'totalGoals': instance.totalGoals,
  'completedGoals': instance.completedGoals,
  'activePlans': instance.activePlans,
  'completedTasks': instance.completedTasks,
};

const _$UserStatusEnumMap = {
  UserStatus.active: 'active',
  UserStatus.deactivated: 'deactivated',
};
