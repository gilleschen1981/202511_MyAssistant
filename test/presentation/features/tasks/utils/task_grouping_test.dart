import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/presentation/features/tasks/utils/task_grouping.dart';

/// Helper to create a [TaskModel] with the given execution window.
///
/// All other fields are filled with sensible defaults so tests can focus on
/// the grouping logic.
TaskModel _makeTask({
  required DateTime windowStart,
  required DateTime windowEnd,
  String id = 'task-1',
  TaskStatus status = TaskStatus.active,
}) {
  return TaskModel(
    id: id,
    userId: 'user-1',
    planId: 'plan-1',
    name: 'Test Task $id',
    config: const TaskConfiguration(),
    windowStartTime: windowStart,
    windowEndTime: windowEnd,
    status: status,
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  // ---------------------------------------------------------------
  // Reference points derived the same way TaskGrouping does it, so
  // our assertions stay consistent regardless of when tests run.
  // ---------------------------------------------------------------
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final endOfWeek = today.add(Duration(days: 7 - now.weekday));
  final endOfMonth = DateTime(now.year, now.month + 1, 0);

  // -------------------------------------------------------------------
  // groupByDeadline
  // -------------------------------------------------------------------
  group('TaskGrouping.groupByDeadline', () {
    // ---------- "today" group ----------

    group('today group', () {
      test('daily task whose window is exactly today is in "today"', () {
        final task = _makeTask(
          windowStart: today,
          windowEnd: today,
        );
        final groups = TaskGrouping.groupByDeadline([task]);
        expect(groups['today'], contains(task));
      });

      test('weekly task whose window spans this week is in "today"', () {
        // Window starts on Monday, ends on Sunday of the current week.
        final monday = today.subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        final task = _makeTask(
          windowStart: monday,
          windowEnd: sunday,
        );
        final groups = TaskGrouping.groupByDeadline([task]);
        expect(groups['today'], contains(task));
      });

      test('monthly task whose window spans the entire month is in "today"', () {
        final firstOfMonth = DateTime(now.year, now.month, 1);
        final lastOfMonth = DateTime(now.year, now.month + 1, 0);
        final task = _makeTask(
          windowStart: firstOfMonth,
          windowEnd: lastOfMonth,
        );
        final groups = TaskGrouping.groupByDeadline([task]);
        expect(groups['today'], contains(task));
      });

      test('multi-day task started yesterday and ending tomorrow is in "today"', () {
        final task = _makeTask(
          windowStart: today.subtract(const Duration(days: 1)),
          windowEnd: today.add(const Duration(days: 1)),
        );
        final groups = TaskGrouping.groupByDeadline([task]);
        expect(groups['today'], contains(task));
      });

      test('task whose window started in the past and ends today is in "today"', () {
        final task = _makeTask(
          windowStart: today.subtract(const Duration(days: 5)),
          windowEnd: today,
        );
        final groups = TaskGrouping.groupByDeadline([task]);
        expect(groups['today'], contains(task));
      });

      test('completed task in current window is still in "today"', () {
        final task = _makeTask(
          windowStart: today,
          windowEnd: today,
          status: TaskStatus.completed,
        );
        final groups = TaskGrouping.groupByDeadline([task]);
        expect(groups['today'], contains(task));
      });
    });

    // ---------- "tomorrow" group ----------

    group('tomorrow group', () {
      test('task with window starting and ending tomorrow is in "tomorrow"', () {
        final task = _makeTask(
          windowStart: tomorrow,
          windowEnd: tomorrow,
        );
        final groups = TaskGrouping.groupByDeadline([task]);
        expect(groups['tomorrow'], contains(task));
      });
    });

    // ---------- "thisWeek" group ----------

    group('thisWeek group', () {
      test('task later this week (after tomorrow, before end of week) is in "thisWeek"', () {
        // Only meaningful when there are days between tomorrow and end of week.
        // If today is Friday (weekday 5), endOfWeek is Sunday (today+2),
        // tomorrow is Saturday (today+1), and dayAfterTomorrow is Sunday (today+2).
        // thisWeek condition: deadline.isAfter(tomorrow) && deadline.isBefore(endOfWeek + 1day)
        // So Sunday == endOfWeek, and Sunday.isBefore(endOfWeek+1day) == true.
        // But windowStart must be after today for it not to go to "today".
        final dayAfterTomorrow = tomorrow.add(const Duration(days: 1));
        // Only test if dayAfterTomorrow is still within endOfWeek
        if (!dayAfterTomorrow.isAfter(endOfWeek)) {
          final task = _makeTask(
            windowStart: dayAfterTomorrow,
            windowEnd: dayAfterTomorrow,
          );
          final groups = TaskGrouping.groupByDeadline([task]);
          expect(groups['thisWeek'], contains(task));
        }
      });

      test('task ending on the last day of this week is in "thisWeek"', () {
        // endOfWeek itself should qualify for thisWeek
        // (as long as windowStart is after today so it does not fall into "today")
        if (endOfWeek.isAfter(tomorrow)) {
          final task = _makeTask(
            windowStart: endOfWeek,
            windowEnd: endOfWeek,
          );
          final groups = TaskGrouping.groupByDeadline([task]);
          expect(groups['thisWeek'], contains(task));
        }
      });
    });

    // ---------- "thisMonth" group ----------

    group('thisMonth group', () {
      test('task in a later week of this month is in "thisMonth"', () {
        // Pick a date that is after endOfWeek but still within the month
        final candidateDate = endOfWeek.add(const Duration(days: 1));
        if (candidateDate.month == now.month &&
            candidateDate.isAfter(tomorrow)) {
          final task = _makeTask(
            windowStart: candidateDate,
            windowEnd: candidateDate,
          );
          final groups = TaskGrouping.groupByDeadline([task]);
          expect(groups['thisMonth'], contains(task));
        }
      });

      test('task ending on the last day of this month is in "thisMonth"', () {
        // Only applies if endOfMonth is after endOfWeek
        if (endOfMonth.isAfter(endOfWeek)) {
          final task = _makeTask(
            windowStart: endOfMonth,
            windowEnd: endOfMonth,
          );
          final groups = TaskGrouping.groupByDeadline([task]);
          expect(groups['thisMonth'], contains(task));
        }
      });
    });

    // ---------- "later" group ----------

    group('later group', () {
      test('task next month is in "later"', () {
        final nextMonth = DateTime(now.year, now.month + 2, 1);
        final task = _makeTask(
          windowStart: nextMonth,
          windowEnd: nextMonth,
        );
        final groups = TaskGrouping.groupByDeadline([task]);
        expect(groups['later'], contains(task));
      });

      test('task next year is in "later"', () {
        final nextYear = DateTime(now.year + 1, 1, 15);
        final task = _makeTask(
          windowStart: nextYear,
          windowEnd: nextYear,
        );
        final groups = TaskGrouping.groupByDeadline([task]);
        expect(groups['later'], contains(task));
      });
    });

    // ---------- edge cases ----------

    group('edge cases', () {
      test('empty task list returns empty groups', () {
        final groups = TaskGrouping.groupByDeadline([]);
        expect(groups['today'], isEmpty);
        expect(groups['tomorrow'], isEmpty);
        expect(groups['thisWeek'], isEmpty);
        expect(groups['thisMonth'], isEmpty);
        expect(groups['later'], isEmpty);
      });

      test('all tasks land in the same group', () {
        final tasks = List.generate(
          5,
          (i) => _makeTask(
            id: 'task-$i',
            windowStart: today,
            windowEnd: today,
          ),
        );
        final groups = TaskGrouping.groupByDeadline(tasks);
        expect(groups['today']!.length, 5);
        expect(groups['tomorrow'], isEmpty);
        expect(groups['thisWeek'], isEmpty);
        expect(groups['thisMonth'], isEmpty);
        expect(groups['later'], isEmpty);
      });

      test('task whose window already passed (both start and end before today) goes to "later" bucket', () {
        // windowStart and windowEnd both in the past -- neither spans today,
        // nor matches tomorrow/thisWeek/thisMonth, so it falls through to
        // "later".
        final pastTask = _makeTask(
          windowStart: today.subtract(const Duration(days: 10)),
          windowEnd: today.subtract(const Duration(days: 5)),
        );
        final groups = TaskGrouping.groupByDeadline([pastTask]);
        // Past tasks: windowStart > today is false (good), but
        // deadline < today so it fails the "today" check.
        // deadline != tomorrow, not after tomorrow, so falls through to later.
        expect(groups['later'], contains(pastTask));
      });

      test('tasks are distributed across multiple groups', () {
        final todayTask = _makeTask(
          id: 'today-task',
          windowStart: today,
          windowEnd: today,
        );
        final tomorrowTask = _makeTask(
          id: 'tomorrow-task',
          windowStart: tomorrow,
          windowEnd: tomorrow,
        );
        final laterTask = _makeTask(
          id: 'later-task',
          windowStart: DateTime(now.year, now.month + 2, 1),
          windowEnd: DateTime(now.year, now.month + 2, 1),
        );

        final groups = TaskGrouping.groupByDeadline([
          todayTask,
          tomorrowTask,
          laterTask,
        ]);

        expect(groups['today'], contains(todayTask));
        expect(groups['tomorrow'], contains(tomorrowTask));
        expect(groups['later'], contains(laterTask));
      });

      test('skipped task in today window still grouped as "today"', () {
        final task = _makeTask(
          windowStart: today,
          windowEnd: today,
          status: TaskStatus.skipped,
        );
        final groups = TaskGrouping.groupByDeadline([task]);
        expect(groups['today'], contains(task));
      });

      test('groupByDeadline returns all five keys', () {
        final groups = TaskGrouping.groupByDeadline([]);
        expect(groups.keys, containsAll(['today', 'tomorrow', 'thisWeek', 'thisMonth', 'later']));
        expect(groups.keys.length, 5);
      });
    });

    // ---------- Sunday edge case ----------

    group('Sunday edge case', () {
      test('endOfWeek calculation when weekday is 7 (Sunday) equals today', () {
        // When now.weekday == 7, endOfWeek = today + (7-7) = today.
        // Verify the formula produces a sane result.
        if (now.weekday == 7) {
          // If running on Sunday, endOfWeek == today.
          expect(endOfWeek, equals(today));
          // A task for today should still land in "today".
          final task = _makeTask(windowStart: today, windowEnd: today);
          final groups = TaskGrouping.groupByDeadline([task]);
          expect(groups['today'], contains(task));
        }
        // If not Sunday, just verify the formula: endOfWeek should be the
        // coming Sunday.
        if (now.weekday < 7) {
          expect(endOfWeek.weekday, DateTime.sunday);
        }
      });
    });
  });

  // -------------------------------------------------------------------
  // getGroupDisplayName
  // -------------------------------------------------------------------
  group('TaskGrouping.getGroupDisplayName', () {
    test('today includes date and count', () {
      final result = TaskGrouping.getGroupDisplayName('today', 3);
      expect(result, contains('${now.month}'));
      expect(result, contains('${now.day}'));
      expect(result, contains('(3)'));
    });

    test('tomorrow label', () {
      expect(TaskGrouping.getGroupDisplayName('tomorrow', 2), equals('明日 (2)'));
    });

    test('thisWeek label', () {
      expect(TaskGrouping.getGroupDisplayName('thisWeek', 5), equals('本周 (5)'));
    });

    test('thisMonth label', () {
      expect(TaskGrouping.getGroupDisplayName('thisMonth', 1), equals('本月 (1)'));
    });

    test('later label', () {
      expect(TaskGrouping.getGroupDisplayName('later', 0), equals('更晚 (0)'));
    });

    test('unknown key returns fallback label', () {
      expect(TaskGrouping.getGroupDisplayName('unknown', 7), equals('未知 (7)'));
    });
  });

  // -------------------------------------------------------------------
  // getGroupIcon
  // -------------------------------------------------------------------
  group('TaskGrouping.getGroupIcon', () {
    test('returns correct icon for each group key', () {
      expect(TaskGrouping.getGroupIcon('today'), equals('📅'));
      expect(TaskGrouping.getGroupIcon('tomorrow'), equals('📆'));
      expect(TaskGrouping.getGroupIcon('thisWeek'), equals('📊'));
      expect(TaskGrouping.getGroupIcon('thisMonth'), equals('📋'));
      expect(TaskGrouping.getGroupIcon('later'), equals('⏰'));
    });

    test('returns fallback icon for unknown key', () {
      expect(TaskGrouping.getGroupIcon('foo'), equals('📁'));
    });
  });

  // -------------------------------------------------------------------
  // orderedGroupKeys
  // -------------------------------------------------------------------
  group('TaskGrouping.orderedGroupKeys', () {
    test('returns keys in correct order', () {
      expect(
        TaskGrouping.orderedGroupKeys,
        equals(['today', 'tomorrow', 'thisWeek', 'thisMonth', 'later']),
      );
    });

    test('length is 5', () {
      expect(TaskGrouping.orderedGroupKeys.length, 5);
    });
  });
}
