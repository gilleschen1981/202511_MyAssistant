import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/core/constants/string_constants.dart';
import 'package:myassistant/core/utils/enum_helper.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';

void main() {
  group('EnumHelper.getPriorityKey', () {
    test('high maps to priorityHigh', () {
      expect(EnumHelper.getPriorityKey(Priority.high), StringConstants.priorityHigh);
    });

    test('medium maps to priorityMedium', () {
      expect(EnumHelper.getPriorityKey(Priority.medium), StringConstants.priorityMedium);
    });

    test('low maps to priorityLow', () {
      expect(EnumHelper.getPriorityKey(Priority.low), StringConstants.priorityLow);
    });
  });

  group('EnumHelper.getGoalStatusKey', () {
    test('active maps to goalStatusInProgress', () {
      expect(EnumHelper.getGoalStatusKey(GoalStatus.active), StringConstants.goalStatusInProgress);
    });

    test('paused maps to goalStatusPaused', () {
      expect(EnumHelper.getGoalStatusKey(GoalStatus.paused), StringConstants.goalStatusPaused);
    });

    test('completed maps to goalStatusCompleted', () {
      expect(EnumHelper.getGoalStatusKey(GoalStatus.completed), StringConstants.goalStatusCompleted);
    });

    test('deleted maps to goalStatusDeleted', () {
      expect(EnumHelper.getGoalStatusKey(GoalStatus.deleted), StringConstants.goalStatusDeleted);
    });
  });

  group('EnumHelper.getTaskStatusKey', () {
    test('active maps to taskStatusActive', () {
      expect(EnumHelper.getTaskStatusKey(TaskStatus.active), StringConstants.taskStatusActive);
    });

    test('completed maps to taskStatusCompleted', () {
      expect(EnumHelper.getTaskStatusKey(TaskStatus.completed), StringConstants.taskStatusCompleted);
    });

    test('skipped maps to taskStatusSkipped', () {
      expect(EnumHelper.getTaskStatusKey(TaskStatus.skipped), StringConstants.taskStatusSkipped);
    });

    test('deleted maps to taskStatusDeleted', () {
      expect(EnumHelper.getTaskStatusKey(TaskStatus.deleted), StringConstants.taskStatusDeleted);
    });
  });

  group('EnumHelper.getUserStatusKey', () {
    test('active maps to userStatusActive', () {
      expect(EnumHelper.getUserStatusKey(UserStatus.active), StringConstants.userStatusActive);
    });

    test('deactivated maps to userStatusDeactivated', () {
      expect(EnumHelper.getUserStatusKey(UserStatus.deactivated), StringConstants.userStatusDeactivated);
    });
  });

  group('EnumHelper.getTaskTypeKey', () {
    test('timer maps to taskTypeTimer', () {
      expect(EnumHelper.getTaskTypeKey(TaskType.timer), StringConstants.taskTypeTimer);
    });

    test('counter maps to taskTypeCounter', () {
      expect(EnumHelper.getTaskTypeKey(TaskType.counter), StringConstants.taskTypeCounter);
    });

    test('evaluation maps to taskTypeEvaluation', () {
      expect(EnumHelper.getTaskTypeKey(TaskType.evaluation), StringConstants.taskTypeEvaluation);
    });

    test('timerWithCount maps to taskTypeTimerWithCount', () {
      expect(EnumHelper.getTaskTypeKey(TaskType.timerWithCount), StringConstants.taskTypeTimerWithCount);
    });

    test('counterWithEval maps to taskTypeCounterWithEval', () {
      expect(EnumHelper.getTaskTypeKey(TaskType.counterWithEval), StringConstants.taskTypeCounterWithEval);
    });

    test('simple maps to taskTypeSimple', () {
      expect(EnumHelper.getTaskTypeKey(TaskType.simple), StringConstants.taskTypeSimple);
    });
  });

  group('EnumHelper.getRepeatTypeKey', () {
    test('oneTime maps to repeatTypeOneTime', () {
      expect(EnumHelper.getRepeatTypeKey(RepeatType.oneTime), StringConstants.repeatTypeOneTime);
    });

    test('daily maps to repeatTypeDaily', () {
      expect(EnumHelper.getRepeatTypeKey(RepeatType.daily), StringConstants.repeatTypeDaily);
    });

    test('weekly maps to repeatTypeWeekly', () {
      expect(EnumHelper.getRepeatTypeKey(RepeatType.weekly), StringConstants.repeatTypeWeekly);
    });

    test('monthly maps to repeatTypeMonthly', () {
      expect(EnumHelper.getRepeatTypeKey(RepeatType.monthly), StringConstants.repeatTypeMonthly);
    });

    test('daysOfWeek maps to hardcoded string', () {
      expect(EnumHelper.getRepeatTypeKey(RepeatType.daysOfWeek), 'repeatType.daysOfWeek');
    });

    test('custom maps to repeatTypeCustom', () {
      expect(EnumHelper.getRepeatTypeKey(RepeatType.custom), StringConstants.repeatTypeCustom);
    });
  });

  group('EnumHelper.getThemeModeKey', () {
    test('light maps to themeModeLight', () {
      expect(EnumHelper.getThemeModeKey(ThemeMode.light), StringConstants.themeModeLight);
    });

    test('dark maps to themeModeDark', () {
      expect(EnumHelper.getThemeModeKey(ThemeMode.dark), StringConstants.themeModeDark);
    });

    test('system maps to themeModeSystem', () {
      expect(EnumHelper.getThemeModeKey(ThemeMode.system), StringConstants.themeModeSystem);
    });
  });
}
