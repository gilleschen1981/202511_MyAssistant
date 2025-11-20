import 'package:myassistant/core/constants/string_constants.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';

/// Helper class to get localization keys for enums
class EnumHelper {
  /// Get localization key for Priority
  static String getPriorityKey(Priority priority) {
    switch (priority) {
      case Priority.high:
        return StringConstants.priorityHigh;
      case Priority.medium:
        return StringConstants.priorityMedium;
      case Priority.low:
        return StringConstants.priorityLow;
    }
  }

  /// Get localization key for GoalStatus
  static String getGoalStatusKey(GoalStatus status) {
    switch (status) {
      case GoalStatus.active:
        return StringConstants.goalStatusInProgress;
      case GoalStatus.paused:
        return StringConstants.goalStatusPaused;
      case GoalStatus.completed:
        return StringConstants.goalStatusCompleted;
      case GoalStatus.deleted:
        return StringConstants.goalStatusDeleted;
    }
  }

  /// Get localization key for TaskStatus
  static String getTaskStatusKey(TaskStatus status) {
    switch (status) {
      case TaskStatus.active:
        return StringConstants.taskStatusActive;
      case TaskStatus.completed:
        return StringConstants.taskStatusCompleted;
      case TaskStatus.skipped:
        return StringConstants.taskStatusSkipped;
      case TaskStatus.deleted:
        return StringConstants.taskStatusDeleted;
    }
  }

  /// Get localization key for UserStatus
  static String getUserStatusKey(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return StringConstants.userStatusActive;
      case UserStatus.deactivated:
        return StringConstants.userStatusDeactivated;
    }
  }

  /// Get localization key for TaskType
  static String getTaskTypeKey(TaskType type) {
    switch (type) {
      case TaskType.timer:
        return StringConstants.taskTypeTimer;
      case TaskType.counter:
        return StringConstants.taskTypeCounter;
      case TaskType.evaluation:
        return StringConstants.taskTypeEvaluation;
      case TaskType.timerWithCount:
        return StringConstants.taskTypeTimerWithCount;
      case TaskType.counterWithEval:
        return StringConstants.taskTypeCounterWithEval;
      case TaskType.simple:
        return StringConstants.taskTypeSimple;
    }
  }

  /// Get localization key for RepeatType
  static String getRepeatTypeKey(RepeatType type) {
    switch (type) {
      case RepeatType.oneTime:
        return StringConstants.repeatTypeOneTime;
      case RepeatType.daily:
        return StringConstants.repeatTypeDaily;
      case RepeatType.weekly:
        return StringConstants.repeatTypeWeekly;
      case RepeatType.monthly:
        return StringConstants.repeatTypeMonthly;
      case RepeatType.custom:
        return StringConstants.repeatTypeCustom;
    }
  }

  /// Get localization key for ThemeMode
  static String getThemeModeKey(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return StringConstants.themeModeLight;
      case ThemeMode.dark:
        return StringConstants.themeModeDark;
      case ThemeMode.system:
        return StringConstants.themeModeSystem;
    }
  }
}