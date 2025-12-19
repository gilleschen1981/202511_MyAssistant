import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/data/models/enums/status.dart';

void main() {
  group('RepeatType enum serialization', () {
    test('toDbString should return correct enum name for all types', () {
      expect(RepeatType.oneTime.toDbString(), 'oneTime');
      expect(RepeatType.daily.toDbString(), 'daily');
      expect(RepeatType.weekly.toDbString(), 'weekly');
      expect(RepeatType.monthly.toDbString(), 'monthly');
      expect(RepeatType.daysOfWeek.toDbString(), 'daysOfWeek'); // Critical: camelCase
      expect(RepeatType.custom.toDbString(), 'custom');
    });

    test('fromString should deserialize all types correctly (exact case)', () {
      expect(RepeatType.fromString('oneTime'), RepeatType.oneTime);
      expect(RepeatType.fromString('daily'), RepeatType.daily);
      expect(RepeatType.fromString('weekly'), RepeatType.weekly);
      expect(RepeatType.fromString('monthly'), RepeatType.monthly);
      expect(RepeatType.fromString('daysOfWeek'), RepeatType.daysOfWeek); // Critical test
      expect(RepeatType.fromString('custom'), RepeatType.custom);
    });

    test('fromString should deserialize case-insensitively', () {
      expect(RepeatType.fromString('ONETIME'), RepeatType.oneTime);
      expect(RepeatType.fromString('Daily'), RepeatType.daily);
      expect(RepeatType.fromString('WEEKLY'), RepeatType.weekly);
      expect(RepeatType.fromString('Monthly'), RepeatType.monthly);
      expect(RepeatType.fromString('DAYSOFWEEK'), RepeatType.daysOfWeek); // Critical: all caps
      expect(RepeatType.fromString('daysofweek'), RepeatType.daysOfWeek); // Critical: all lowercase
      expect(RepeatType.fromString('DaysOfWeek'), RepeatType.daysOfWeek); // Critical: PascalCase
      expect(RepeatType.fromString('CUSTOM'), RepeatType.custom);
    });

    test('fromString should return default for unknown values', () {
      expect(RepeatType.fromString('unknown'), RepeatType.oneTime);
      expect(RepeatType.fromString('invalid'), RepeatType.oneTime);
      expect(RepeatType.fromString(''), RepeatType.oneTime);
      expect(RepeatType.fromString('null'), RepeatType.oneTime);
    });

    test('round-trip serialization should preserve type (toDbString -> fromString)', () {
      for (final type in RepeatType.values) {
        final serialized = type.toDbString();
        final deserialized = RepeatType.fromString(serialized);
        expect(
          deserialized,
          type,
          reason: 'Round-trip failed for $type: $serialized -> $deserialized',
        );
      }
    });

    test('daysOfWeek type should survive database round-trip simulation', () {
      // This simulates what happens in the database:
      // 1. Enum is stored via toDbString()
      const original = RepeatType.daysOfWeek;
      final storedInDb = original.toDbString(); // "daysOfWeek"

      // 2. Enum is read via fromString()
      final restoredFromDb = RepeatType.fromString(storedInDb);

      expect(restoredFromDb, RepeatType.daysOfWeek);
      expect(storedInDb, 'daysOfWeek');
    });
  });

  group('TaskType enum serialization', () {
    test('toDbString should return correct enum name for all types', () {
      expect(TaskType.timer.toDbString(), 'timer');
      expect(TaskType.counter.toDbString(), 'counter');
      expect(TaskType.evaluation.toDbString(), 'evaluation');
      expect(TaskType.timerWithCount.toDbString(), 'timerWithCount'); // Critical: camelCase
      expect(TaskType.counterWithEval.toDbString(), 'counterWithEval'); // Critical: camelCase
      expect(TaskType.simple.toDbString(), 'simple');
    });

    test('fromString should deserialize all types correctly (exact case)', () {
      expect(TaskType.fromString('timer'), TaskType.timer);
      expect(TaskType.fromString('counter'), TaskType.counter);
      expect(TaskType.fromString('evaluation'), TaskType.evaluation);
      expect(TaskType.fromString('timerWithCount'), TaskType.timerWithCount); // Critical
      expect(TaskType.fromString('counterWithEval'), TaskType.counterWithEval); // Critical
      expect(TaskType.fromString('simple'), TaskType.simple);
    });

    test('fromString should deserialize case-insensitively', () {
      expect(TaskType.fromString('TIMER'), TaskType.timer);
      expect(TaskType.fromString('Counter'), TaskType.counter);
      expect(TaskType.fromString('TIMERWITHCOUNT'), TaskType.timerWithCount); // Critical
      expect(TaskType.fromString('timerwithcount'), TaskType.timerWithCount); // Critical
      expect(TaskType.fromString('TimerWithCount'), TaskType.timerWithCount); // Critical
      expect(TaskType.fromString('COUNTERWITHEVAL'), TaskType.counterWithEval); // Critical
      expect(TaskType.fromString('counterwitheval'), TaskType.counterWithEval); // Critical
    });

    test('fromString should return default for unknown values', () {
      expect(TaskType.fromString('unknown'), TaskType.simple);
      expect(TaskType.fromString('invalid'), TaskType.simple);
      expect(TaskType.fromString(''), TaskType.simple);
    });

    test('round-trip serialization should preserve type', () {
      for (final type in TaskType.values) {
        final serialized = type.toDbString();
        final deserialized = TaskType.fromString(serialized);
        expect(
          deserialized,
          type,
          reason: 'Round-trip failed for $type: $serialized -> $deserialized',
        );
      }
    });
  });

  group('ThemeMode enum serialization', () {
    test('toDbString should return correct enum name for all types', () {
      expect(ThemeMode.light.toDbString(), 'light');
      expect(ThemeMode.dark.toDbString(), 'dark');
      expect(ThemeMode.system.toDbString(), 'system');
    });

    test('fromString should deserialize all types correctly', () {
      expect(ThemeMode.fromString('light'), ThemeMode.light);
      expect(ThemeMode.fromString('dark'), ThemeMode.dark);
      expect(ThemeMode.fromString('system'), ThemeMode.system);
    });

    test('fromString should deserialize case-insensitively', () {
      expect(ThemeMode.fromString('LIGHT'), ThemeMode.light);
      expect(ThemeMode.fromString('Dark'), ThemeMode.dark);
      expect(ThemeMode.fromString('SYSTEM'), ThemeMode.system);
    });

    test('fromString should return default for unknown values', () {
      expect(ThemeMode.fromString('unknown'), ThemeMode.system);
      expect(ThemeMode.fromString(''), ThemeMode.system);
    });

    test('round-trip serialization should preserve type', () {
      for (final mode in ThemeMode.values) {
        final serialized = mode.toDbString();
        final deserialized = ThemeMode.fromString(serialized);
        expect(
          deserialized,
          mode,
          reason: 'Round-trip failed for $mode: $serialized -> $deserialized',
        );
      }
    });
  });

  group('PlanStatus enum serialization', () {
    test('toDbString should return correct enum name for all statuses', () {
      expect(PlanStatus.active.toDbString(), 'active');
      expect(PlanStatus.paused.toDbString(), 'paused');
      expect(PlanStatus.completed.toDbString(), 'completed');
      expect(PlanStatus.deleted.toDbString(), 'deleted');
    });

    test('fromString should deserialize all statuses correctly', () {
      expect(PlanStatus.fromString('active'), PlanStatus.active);
      expect(PlanStatus.fromString('paused'), PlanStatus.paused);
      expect(PlanStatus.fromString('completed'), PlanStatus.completed);
      expect(PlanStatus.fromString('deleted'), PlanStatus.deleted);
    });

    test('fromString should deserialize case-insensitively', () {
      expect(PlanStatus.fromString('ACTIVE'), PlanStatus.active);
      expect(PlanStatus.fromString('Paused'), PlanStatus.paused);
      expect(PlanStatus.fromString('COMPLETED'), PlanStatus.completed);
    });

    test('round-trip serialization should preserve status', () {
      for (final status in PlanStatus.values) {
        final serialized = status.toDbString();
        final deserialized = PlanStatus.fromString(serialized);
        expect(
          deserialized,
          status,
          reason: 'Round-trip failed for $status: $serialized -> $deserialized',
        );
      }
    });
  });
}
