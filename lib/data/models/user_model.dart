import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:myassistant/data/models/enums/status.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel extends Equatable {
  // Base fields
  final String id; // UUID
  final String username; // Unique
  final String email; // Unique
  final String passwordHash;

  // Personal info
  final String? displayName;
  final String? avatarUrl;

  // Status and timestamps
  final UserStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Statistics (usually computed from database, but can be cached)
  final int? totalGoals;
  final int? completedGoals;
  final int? activePlans;
  final int? completedTasks;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    this.displayName,
    this.avatarUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.totalGoals,
    this.completedGoals,
    this.activePlans,
    this.completedTasks,
  });

  /// Check if user is active
  bool get isActive => status == UserStatus.active;

  /// Computed properties for statistics
  /// These would typically be calculated from database queries
  /// but can be cached in the model for performance

  /// Goal completion rate
  double get goalCompletionRate {
    if (totalGoals == null || totalGoals == 0) return 0.0;
    if (completedGoals == null) return 0.0;
    return completedGoals! / totalGoals!;
  }

  /// Task completion rate (if we have the total)
  double? get taskCompletionRate {
    // This would need total tasks count to be meaningful
    // For now, return null as we don't store total tasks
    return null;
  }

  /// Check if user has any active goals
  bool get hasActiveGoals {
    if (totalGoals == null || completedGoals == null) return false;
    return (totalGoals! - completedGoals!) > 0;
  }

  /// Check if user has any active plans
  bool get hasActivePlans => activePlans != null && activePlans! > 0;

  /// Get account age in days
  int get accountAgeDays {
    return DateTime.now().difference(createdAt).inDays;
  }

  /// Check if account is new (less than 7 days old)
  bool get isNewUser => accountAgeDays < 7;

  /// Get formatted display name or fall back to username
  String get displayNameOrUsername => displayName ?? username;

  /// Get user's initials for avatar placeholder
  String get initials {
    final name = displayNameOrUsername;
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  /// Factory constructor for creating from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  /// Copy with method for immutable updates
  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? passwordHash,
    String? displayName,
    String? avatarUrl,
    UserStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalGoals,
    int? completedGoals,
    int? activePlans,
    int? completedTasks,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalGoals: totalGoals ?? this.totalGoals,
      completedGoals: completedGoals ?? this.completedGoals,
      activePlans: activePlans ?? this.activePlans,
      completedTasks: completedTasks ?? this.completedTasks,
    );
  }

  /// Create a copy without sensitive data (for client use)
  UserModel toSafeModel() {
    return UserModel(
      id: id,
      username: username,
      email: email,
      passwordHash: '', // Remove password hash for safety
      displayName: displayName,
      avatarUrl: avatarUrl,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      totalGoals: totalGoals,
      completedGoals: completedGoals,
      activePlans: activePlans,
      completedTasks: completedTasks,
    );
  }

  @override
  List<Object?> get props => [
        id,
        username,
        email,
        passwordHash,
        displayName,
        avatarUrl,
        status,
        createdAt,
        updatedAt,
        totalGoals,
        completedGoals,
        activePlans,
        completedTasks,
      ];
}