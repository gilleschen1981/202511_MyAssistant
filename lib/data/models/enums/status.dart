/// Goal Status
enum GoalStatus {
  inProgress,
  paused,
  completed;

  /// Convert to string for database storage
  String toDbString() => name;

  /// Create from string
  static GoalStatus fromString(String str) {
    return GoalStatus.values.firstWhere(
      (s) => s.name == str.toLowerCase(),
      orElse: () => GoalStatus.inProgress,
    );
  }
}

/// Task Status
enum TaskStatus {
  active,
  completed,
  skipped;

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