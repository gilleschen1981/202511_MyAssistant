import 'package:myassistant/data/models/task_model.dart';

/// Task grouping utility based on deadline (windowEndTime)
/// Groups tasks by: Today, Tomorrow, This Week, This Month, Later
class TaskGrouping {
  /// Group tasks by deadline
  static Map<String, List<TaskModel>> groupByDeadline(List<TaskModel> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final endOfWeek = today.add(Duration(days: 7 - now.weekday));
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final groups = <String, List<TaskModel>>{
      'today': [],
      'tomorrow': [],
      'thisWeek': [],
      'thisMonth': [],
      'later': [],
    };

    for (final task in tasks) {
      final deadline = DateTime(
        task.windowEndTime.year,
        task.windowEndTime.month,
        task.windowEndTime.day,
      );

      if (deadline.isBefore(tomorrow) && deadline.isAtSameMomentAs(today) || deadline.isAfter(today) && deadline.isBefore(tomorrow)) {
        // Today: deadline is today
        groups['today']!.add(task);
      } else if (deadline.isAtSameMomentAs(tomorrow)) {
        // Tomorrow: deadline is tomorrow
        groups['tomorrow']!.add(task);
      } else if (deadline.isAfter(tomorrow) && deadline.isBefore(endOfWeek.add(const Duration(days: 1)))) {
        // This week: deadline is within this week (excluding today and tomorrow)
        groups['thisWeek']!.add(task);
      } else if (deadline.isAfter(endOfWeek) && deadline.isBefore(endOfMonth.add(const Duration(days: 1)))) {
        // This month: deadline is within this month (excluding this week)
        groups['thisMonth']!.add(task);
      } else {
        // Later: deadline is after this month
        groups['later']!.add(task);
      }
    }

    return groups;
  }

  /// Get display name for group
  static String getGroupDisplayName(String groupKey, int count) {
    switch (groupKey) {
      case 'today':
        final now = DateTime.now();
        final dateStr = '${now.month}月${now.day}日';
        return '今日 ($count) $dateStr';
      case 'tomorrow':
        return '明日 ($count)';
      case 'thisWeek':
        return '本周 ($count)';
      case 'thisMonth':
        return '本月 ($count)';
      case 'later':
        return '更晚 ($count)';
      default:
        return '未知 ($count)';
    }
  }

  /// Get icon for group
  static String getGroupIcon(String groupKey) {
    switch (groupKey) {
      case 'today':
        return '📅';
      case 'tomorrow':
        return '📆';
      case 'thisWeek':
        return '📊';
      case 'thisMonth':
        return '📋';
      case 'later':
        return '⏰';
      default:
        return '📁';
    }
  }

  /// Get group keys in order
  static List<String> get orderedGroupKeys => [
        'today',
        'tomorrow',
        'thisWeek',
        'thisMonth',
        'later',
      ];
}
