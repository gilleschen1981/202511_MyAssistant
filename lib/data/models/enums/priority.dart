/// Priority enum for Goals
enum Priority {
  high(value: 1),
  medium(value: 2),
  low(value: 3);

  final int value;

  const Priority({required this.value});

  /// Get Priority from value
  static Priority fromValue(int value) {
    return Priority.values.firstWhere(
      (p) => p.value == value,
      orElse: () => Priority.medium,
    );
  }

  /// Get Priority from string
  static Priority fromString(String str) {
    return Priority.values.firstWhere(
      (p) => p.name == str.toLowerCase(),
      orElse: () => Priority.medium,
    );
  }

  /// Convert to string for database storage
  String toDbString() => name;
}