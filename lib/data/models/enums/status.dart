/// Goal Status
enum GoalStatus {
  active,
  paused,
  completed,
  deleted;

  /// Convert to string for database storage
  String toDbString() => name;

  /// Create from string
  static GoalStatus fromString(String str) {
    return GoalStatus.values.firstWhere(
      (s) => s.name == str.toLowerCase(),
      orElse: () => GoalStatus.active,
    );
  }
}

/// Task Status
enum TaskStatus {
  active,
  completed,
  skipped,
  deleted;

  /// Convert to string for database storage
  String toDbString() => name;

  /// Create from string
  static TaskStatus fromString(String str) {
    return TaskStatus.values.firstWhere(
      (s) => s.name == str.toLowerCase(),
      orElse: () => TaskStatus.active,
    );
  }
}

/// Plan Status
enum PlanStatus {
  active,
  paused,
  completed,
  deleted;

  /// Convert to string for database storage
  String toDbString() => name;

  /// Create from string
  static PlanStatus fromString(String str) {
    return PlanStatus.values.firstWhere(
      (s) => s.name == str.toLowerCase(),
      orElse: () => PlanStatus.active,
    );
  }
}

/// User Status
enum UserStatus {
  active,
  deactivated;

  /// Convert to string for database storage
  String toDbString() => name;

  /// Create from string
  static UserStatus fromString(String str) {
    return UserStatus.values.firstWhere(
      (s) => s.name == str.toLowerCase(),
      orElse: () => UserStatus.active,
    );
  }
}