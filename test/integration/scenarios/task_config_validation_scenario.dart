import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/task_type.dart';

void main() {
  group('Scenario: TaskConfiguration validation and type derivation', () {
    group('valid configurations produce correct TaskType', () {
      test('empty config → simple', () {
        const config = TaskConfiguration();
        expect(config.taskType, TaskType.simple);
        expect(config.isValid, true);
      });

      test('durationMinutes only → timer', () {
        const config = TaskConfiguration(durationMinutes: 25);
        expect(config.taskType, TaskType.timer);
        expect(config.isValid, true);
      });

      test('repeatCount only → counter', () {
        const config = TaskConfiguration(repeatCount: 10);
        expect(config.taskType, TaskType.counter);
        expect(config.isValid, true);
      });

      test('evaluationOptions only → evaluation', () {
        const config =
            TaskConfiguration(evaluationOptions: ['Good', 'Bad']);
        expect(config.taskType, TaskType.evaluation);
        expect(config.isValid, true);
      });

      test('durationMinutes + repeatCount → timerWithCount', () {
        const config =
            TaskConfiguration(durationMinutes: 25, repeatCount: 5);
        expect(config.taskType, TaskType.timerWithCount);
        expect(config.isValid, true);
      });

      test('repeatCount + evaluationOptions → counterWithEval', () {
        const config = TaskConfiguration(
          repeatCount: 5,
          evaluationOptions: ['A', 'B', 'C'],
        );
        expect(config.taskType, TaskType.counterWithEval);
        expect(config.isValid, true);
      });
    });

    group('invalid configurations', () {
      test('timer + evaluation throws StateError', () {
        const config = TaskConfiguration(
          durationMinutes: 25,
          evaluationOptions: ['Good', 'Bad'],
        );
        expect(() => config.taskType, throwsStateError);
        expect(config.isValid, false);
      });

      test('timer + counter + evaluation throws StateError', () {
        const config = TaskConfiguration(
          durationMinutes: 25,
          repeatCount: 5,
          evaluationOptions: ['Good', 'Bad'],
        );
        expect(() => config.taskType, throwsStateError);
        expect(config.isValid, false);
      });

      test('durationMinutes <= 0 is invalid', () {
        const config = TaskConfiguration(durationMinutes: 0);
        expect(config.isValid, false);

        const config2 = TaskConfiguration(durationMinutes: -1);
        expect(config2.isValid, false);
      });

      test('repeatCount <= 0 is invalid', () {
        const config = TaskConfiguration(repeatCount: 0);
        expect(config.isValid, false);

        const config2 = TaskConfiguration(repeatCount: -5);
        expect(config2.isValid, false);
      });

      test('evaluationOptions with 1 option is invalid', () {
        const config = TaskConfiguration(evaluationOptions: ['OnlyOne']);
        expect(config.isValid, false);
      });

      test('evaluationOptions with 0 options is invalid', () {
        const config = TaskConfiguration(evaluationOptions: []);
        // Empty list: taskType returns simple (not evaluation)
        expect(config.taskType, TaskType.simple);
        // isValid check: empty list passes because length check only applies
        // when evaluationOptions != null && length < 2
        // Actually [] has length 0 which is < 2, so it's invalid
        expect(config.isValid, false);
      });
    });

    group('boundary values', () {
      test('durationMinutes = 1 (minimum valid)', () {
        const config = TaskConfiguration(durationMinutes: 1);
        expect(config.isValid, true);
        expect(config.taskType, TaskType.timer);
      });

      test('durationMinutes = 240 (max allowed by service)', () {
        const config = TaskConfiguration(durationMinutes: 240);
        expect(config.isValid, true);
        expect(config.taskType, TaskType.timer);
      });

      test('repeatCount = 1 (minimum valid)', () {
        const config = TaskConfiguration(repeatCount: 1);
        expect(config.isValid, true);
        expect(config.taskType, TaskType.counter);
      });

      test('evaluationOptions with exactly 2 (minimum valid)', () {
        const config =
            TaskConfiguration(evaluationOptions: ['Yes', 'No']);
        expect(config.isValid, true);
        expect(config.taskType, TaskType.evaluation);
      });

      test('large repeatCount', () {
        const config = TaskConfiguration(repeatCount: 1000);
        expect(config.isValid, true);
      });

      test('many evaluationOptions', () {
        final options =
            List.generate(20, (i) => 'Option ${i + 1}');
        final config = TaskConfiguration(evaluationOptions: options);
        expect(config.isValid, true);
        expect(config.evaluationOptions!.length, 20);
      });
    });

    group('RepeatRule validation', () {
      test('oneTime is always valid', () {
        const rule = RepeatRule(type: RepeatType.oneTime);
        expect(rule.isValid, true);
        expect(rule.intervalDays, 0);
      });

      test('daily is always valid', () {
        const rule = RepeatRule(type: RepeatType.daily);
        expect(rule.isValid, true);
        expect(rule.intervalDays, 1);
      });

      test('weekly is always valid', () {
        const rule = RepeatRule(type: RepeatType.weekly);
        expect(rule.isValid, true);
        expect(rule.intervalDays, 7);
      });

      test('monthly is always valid', () {
        const rule = RepeatRule(type: RepeatType.monthly);
        expect(rule.isValid, true);
        expect(rule.intervalDays, 30);
      });

      test('custom requires positive customDays', () {
        const valid = RepeatRule(type: RepeatType.custom, customDays: 3);
        expect(valid.isValid, true);
        expect(valid.intervalDays, 3);

        const invalid1 = RepeatRule(type: RepeatType.custom);
        expect(invalid1.isValid, false);

        const invalid2 = RepeatRule(type: RepeatType.custom, customDays: 0);
        expect(invalid2.isValid, false);

        const invalid3 = RepeatRule(type: RepeatType.custom, customDays: -1);
        expect(invalid3.isValid, false);
      });

      test('daysOfWeek requires non-empty selectedDays in 1-7 range', () {
        const valid = RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [1, 3, 5],
        );
        expect(valid.isValid, true);

        const invalid1 = RepeatRule(type: RepeatType.daysOfWeek);
        expect(invalid1.isValid, false);

        const invalid2 = RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [],
        );
        expect(invalid2.isValid, false);

        const invalid3 = RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [0, 8],
        );
        expect(invalid3.isValid, false);
      });

      test('daysOfWeek all 7 days', () {
        const rule = RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        );
        expect(rule.isValid, true);
      });

      test('daysOfWeek single day (weekends only)', () {
        const rule = RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [6, 7],
        );
        expect(rule.isValid, true);
      });
    });

    group('RepeatRule × TaskConfiguration cross-product', () {
      test('all valid RepeatRule types with simple config', () {
        final rules = [
          const RepeatRule(type: RepeatType.oneTime),
          const RepeatRule(type: RepeatType.daily),
          const RepeatRule(type: RepeatType.weekly),
          const RepeatRule(type: RepeatType.monthly),
          const RepeatRule(
            type: RepeatType.daysOfWeek,
            selectedDaysOfWeek: [1, 5],
          ),
          const RepeatRule(type: RepeatType.custom, customDays: 3),
        ];

        for (final rule in rules) {
          expect(rule.isValid, true, reason: '${rule.type} should be valid');
        }
      });

      test('all valid TaskConfig types with daily repeat', () {
        final configs = [
          const TaskConfiguration(),
          const TaskConfiguration(durationMinutes: 25),
          const TaskConfiguration(repeatCount: 10),
          const TaskConfiguration(evaluationOptions: ['A', 'B']),
          const TaskConfiguration(durationMinutes: 25, repeatCount: 5),
          const TaskConfiguration(
            repeatCount: 5,
            evaluationOptions: ['A', 'B'],
          ),
        ];

        for (final config in configs) {
          expect(config.isValid, true,
              reason: '${config.taskType} should be valid');
        }
      });
    });
  });
}
