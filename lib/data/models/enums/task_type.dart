/// Task Type enum based on configuration
enum TaskType {
  timer,           // Timer task
  counter,         // Counter task
  evaluation,      // Evaluation task
  timerWithCount,  // Timer + Counter task
  counterWithEval, // Counter + Evaluation task
  simple;          // Simple task (no config)

  /// Convert to string for database storage
  String toDbString() => name;

  /// Create from string
  static TaskType fromString(String str) {
    return TaskType.values.firstWhere(
      (t) => t.name == str.toLowerCase(),
      orElse: () => TaskType.simple,
    );
  }
}

/// Repeat Type for Plans
enum RepeatType {
  oneTime,
  daily,
  weekly,
  monthly,
  custom;

  /// Convert to string for database storage
  String toDbString() => name;

  /// Create from string
  static RepeatType fromString(String str) {
    return RepeatType.values.firstWhere(
      (r) => r.name == str.toLowerCase(),
      orElse: () => RepeatType.oneTime,
    );
  }
}

/// Theme Mode for user settings
enum ThemeMode {
  light,
  dark,
  system;

  /// Convert to string for database storage
  String toDbString() => name;

  /// Create from string
  static ThemeMode fromString(String str) {
    return ThemeMode.values.firstWhere(
      (t) => t.name == str.toLowerCase(),
      orElse: () => ThemeMode.system,
    );
  }
}