import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/data/models/enums/priority.dart';

void main() {
  group('Priority enum values', () {
    test('high has value 1', () {
      expect(Priority.high.value, 1);
    });

    test('medium has value 2', () {
      expect(Priority.medium.value, 2);
    });

    test('low has value 3', () {
      expect(Priority.low.value, 3);
    });
  });

  group('Priority.fromValue', () {
    test('returns high for value 1', () {
      expect(Priority.fromValue(1), Priority.high);
    });

    test('returns medium for value 2', () {
      expect(Priority.fromValue(2), Priority.medium);
    });

    test('returns low for value 3', () {
      expect(Priority.fromValue(3), Priority.low);
    });

    test('returns medium (default) for unknown value 0', () {
      expect(Priority.fromValue(0), Priority.medium);
    });

    test('returns medium (default) for unknown value 99', () {
      expect(Priority.fromValue(99), Priority.medium);
    });

    test('returns medium (default) for negative value', () {
      expect(Priority.fromValue(-1), Priority.medium);
    });
  });

  group('Priority.fromString', () {
    test('returns correct priority for exact name match', () {
      expect(Priority.fromString('high'), Priority.high);
      expect(Priority.fromString('medium'), Priority.medium);
      expect(Priority.fromString('low'), Priority.low);
    });

    test('is case-insensitive', () {
      expect(Priority.fromString('HIGH'), Priority.high);
      expect(Priority.fromString('High'), Priority.high);
      expect(Priority.fromString('MEDIUM'), Priority.medium);
      expect(Priority.fromString('Medium'), Priority.medium);
      expect(Priority.fromString('LOW'), Priority.low);
      expect(Priority.fromString('Low'), Priority.low);
    });

    test('returns medium (default) for unknown string', () {
      expect(Priority.fromString('unknown'), Priority.medium);
      expect(Priority.fromString('invalid'), Priority.medium);
      expect(Priority.fromString(''), Priority.medium);
    });
  });

  group('Priority.toDbString', () {
    test('returns enum name for each priority', () {
      expect(Priority.high.toDbString(), 'high');
      expect(Priority.medium.toDbString(), 'medium');
      expect(Priority.low.toDbString(), 'low');
    });
  });

  group('Priority round-trip serialization', () {
    test('toDbString -> fromString preserves value for all priorities', () {
      for (final priority in Priority.values) {
        final serialized = priority.toDbString();
        final deserialized = Priority.fromString(serialized);
        expect(
          deserialized,
          priority,
          reason: 'Round-trip failed for $priority: $serialized -> $deserialized',
        );
      }
    });
  });
}
