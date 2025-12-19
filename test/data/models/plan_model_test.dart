import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';

void main() {
  group('RepeatRule', () {
    test('should create a daily repeat rule', () {
      const rule = RepeatRule(type: RepeatType.daily);

      expect(rule.type, RepeatType.daily);
      expect(rule.customDays, null);
      expect(rule.isValid, true);
      expect(rule.intervalDays, 1);
    });

    test('should create a weekly repeat rule', () {
      const rule = RepeatRule(type: RepeatType.weekly);

      expect(rule.type, RepeatType.weekly);
      expect(rule.intervalDays, 7);
      expect(rule.isValid, true);
    });

    test('should create a monthly repeat rule', () {
      const rule = RepeatRule(type: RepeatType.monthly);

      expect(rule.type, RepeatType.monthly);
      expect(rule.intervalDays, 30);
      expect(rule.isValid, true);
    });

    test('should create a one-time repeat rule', () {
      const rule = RepeatRule(type: RepeatType.oneTime);

      expect(rule.type, RepeatType.oneTime);
      expect(rule.intervalDays, 0);
      expect(rule.isValid, true);
    });

    test('should create a custom repeat rule with valid customDays', () {
      const rule = RepeatRule(type: RepeatType.custom, customDays: 14);

      expect(rule.type, RepeatType.custom);
      expect(rule.customDays, 14);
      expect(rule.isValid, true);
      expect(rule.intervalDays, 14);
    });

    test('should be invalid when custom type without customDays', () {
      const rule = RepeatRule(type: RepeatType.custom);

      expect(rule.isValid, false);
      expect(rule.intervalDays, 0);
    });

    test('should be invalid when custom type with zero or negative days', () {
      const invalidRule1 = RepeatRule(type: RepeatType.custom, customDays: 0);
      const invalidRule2 = RepeatRule(type: RepeatType.custom, customDays: -5);

      expect(invalidRule1.isValid, false);
      expect(invalidRule2.isValid, false);
    });

    test('should serialize to JSON correctly', () {
      const rule = RepeatRule(type: RepeatType.custom, customDays: 10);

      final json = rule.toJson();

      expect(json['type'], 'custom');
      expect(json['customDays'], 10);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'type': 'weekly',
        'customDays': null,
      };

      final rule = RepeatRule.fromJson(json);

      expect(rule.type, RepeatType.weekly);
      expect(rule.customDays, null);
    });

    test('should create daysOfWeek rule with valid selected days', () {
      const rule = RepeatRule(
        type: RepeatType.daysOfWeek,
        selectedDaysOfWeek: [1, 3, 5], // Monday, Wednesday, Friday
      );

      expect(rule.type, RepeatType.daysOfWeek);
      expect(rule.selectedDaysOfWeek, [1, 3, 5]);
      expect(rule.isValid, true);
      expect(rule.intervalDays, 7);
    });

    test('daysOfWeek rule should be invalid without selected days', () {
      const rule1 = RepeatRule(type: RepeatType.daysOfWeek);
      const rule2 = RepeatRule(type: RepeatType.daysOfWeek, selectedDaysOfWeek: []);

      expect(rule1.isValid, false);
      expect(rule2.isValid, false);
    });

    test('daysOfWeek rule should be invalid with out-of-range days', () {
      const rule1 = RepeatRule(
        type: RepeatType.daysOfWeek,
        selectedDaysOfWeek: [0, 1, 2], // 0 is invalid (must be 1-7)
      );
      const rule2 = RepeatRule(
        type: RepeatType.daysOfWeek,
        selectedDaysOfWeek: [1, 8], // 8 is invalid (must be 1-7)
      );

      expect(rule1.isValid, false);
      expect(rule2.isValid, false);
    });

    test('daysOfWeek rule should serialize to JSON correctly', () {
      const rule = RepeatRule(
        type: RepeatType.daysOfWeek,
        selectedDaysOfWeek: [6, 7], // Saturday, Sunday
      );

      final json = rule.toJson();

      expect(json['type'], 'daysOfWeek'); // Critical: camelCase preserved
      expect(json['selectedDaysOfWeek'], [6, 7]);
      expect(json['customDays'], null);
    });

    test('daysOfWeek rule should deserialize from JSON correctly', () {
      final json = {
        'type': 'daysOfWeek', // Critical: test camelCase
        'selectedDaysOfWeek': [1, 2, 6, 7],
        'customDays': null,
      };

      final rule = RepeatRule.fromJson(json);

      expect(rule.type, RepeatType.daysOfWeek);
      expect(rule.selectedDaysOfWeek, [1, 2, 6, 7]);
      expect(rule.isValid, true);
    });

    test('daysOfWeek rule should survive round-trip serialization', () {
      const original = RepeatRule(
        type: RepeatType.daysOfWeek,
        selectedDaysOfWeek: [1, 3, 5, 7],
      );

      final json = original.toJson();
      final restored = RepeatRule.fromJson(json);

      expect(restored, equals(original));
      expect(restored.type, RepeatType.daysOfWeek);
      expect(restored.selectedDaysOfWeek, [1, 3, 5, 7]);
    });

    test('daysOfWeek type enum should deserialize case-insensitively from database string', () {
      // This tests the database deserialization path (RepeatType.fromString)
      // JSON deserialization uses json_annotation which has strict case matching
      final testCases = [
        'daysOfWeek', // camelCase - exact match
        'DAYSOFWEEK', // UPPERCASE
        'daysofweek', // lowercase
        'DaysOfWeek', // PascalCase
      ];

      for (final dbString in testCases) {
        final type = RepeatType.fromString(dbString);
        expect(
          type,
          RepeatType.daysOfWeek,
          reason: 'Failed to deserialize from database string: $dbString',
        );
      }
    });

    test('Equatable props should work correctly', () {
      const rule1 = RepeatRule(type: RepeatType.daily);
      const rule2 = RepeatRule(type: RepeatType.daily);
      const rule3 = RepeatRule(type: RepeatType.weekly);

      expect(rule1, equals(rule2));
      expect(rule1, isNot(equals(rule3)));
    });
  });

  group('TaskConfiguration', () {
    test('should validate timer and evaluation mutual exclusion', () {
      const invalidConfig = TaskConfiguration(
        durationMinutes: 30,
        evaluationOptions: ['Good', 'Bad'],
      );

      expect(invalidConfig.isValid, false);
      expect(
        () => invalidConfig.taskType,
        throwsA(isA<StateError>()),
      );
    });

    test('should validate timer duration must be positive', () {
      const invalidConfig1 = TaskConfiguration(durationMinutes: 0);
      const invalidConfig2 = TaskConfiguration(durationMinutes: -10);

      expect(invalidConfig1.isValid, false);
      expect(invalidConfig2.isValid, false);
    });

    test('should validate repeat count must be positive', () {
      const invalidConfig1 = TaskConfiguration(repeatCount: 0);
      const invalidConfig2 = TaskConfiguration(repeatCount: -5);

      expect(invalidConfig1.isValid, false);
      expect(invalidConfig2.isValid, false);
    });

    test('should validate evaluation options need at least 2 options', () {
      const invalidConfig1 = TaskConfiguration(evaluationOptions: []);
      const invalidConfig2 = TaskConfiguration(evaluationOptions: ['Only One']);

      expect(invalidConfig1.isValid, false);
      expect(invalidConfig2.isValid, false);
    });

    test('should serialize and deserialize correctly', () {
      const config = TaskConfiguration(
        durationMinutes: 25,
        repeatCount: 5,
      );

      final json = config.toJson();
      final restored = TaskConfiguration.fromJson(json);

      expect(restored, equals(config));
      expect(restored.durationMinutes, 25);
      expect(restored.repeatCount, 5);
    });
  });

  group('PlanModel', () {
    final now = DateTime.now();
    final startDate = DateTime(2024, 1, 1);
    final endDate = DateTime(2024, 12, 31);

    test('should create a PlanModel with required fields', () {
      final plan = PlanModel(
        id: 'plan-123',
        userId: 'user-123',
        name: 'Test Plan',
        goalId: 'goal-123',
        startDate: startDate,
        endDate: endDate,
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(durationMinutes: 30),
        createdAt: now,
        updatedAt: now,
      );

      expect(plan.id, 'plan-123');
      expect(plan.userId, 'user-123');
      expect(plan.name, 'Test Plan');
      expect(plan.goalId, 'goal-123');
      expect(plan.status, PlanStatus.active);
      expect(plan.description, null);
      expect(plan.deletedAt, null);
    });

    test('should create a PlanModel with all fields', () {
      final plan = PlanModel(
        id: 'plan-123',
        userId: 'user-123',
        name: 'Complete Plan',
        description: 'A complete plan for testing',
        goalId: 'goal-123',
        startDate: startDate,
        endDate: endDate,
        repeatRule: const RepeatRule(type: RepeatType.daily),
        taskConfig: const TaskConfiguration(repeatCount: 10),
        status: PlanStatus.completed,
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
      );

      expect(plan.description, 'A complete plan for testing');
      expect(plan.status, PlanStatus.completed);
      expect(plan.deletedAt, isNotNull);
    });

    test('should correctly identify deleted status', () {
      final activePlan = PlanModel(
        id: 'plan-1',
        userId: 'user-123',
        name: 'Active Plan',
        goalId: 'goal-123',
        startDate: startDate,
        endDate: endDate,
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(),
        status: PlanStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      final deletedPlan = activePlan.copyWith(
        status: PlanStatus.deleted,
        deletedAt: now,
      );

      expect(activePlan.isDeleted, false);
      expect(deletedPlan.isDeleted, true);
    });

    test('should correctly identify active status', () {
      final activeStartDate = now.subtract(const Duration(days: 1));
      final activeEndDate = now.add(const Duration(days: 1));

      final activePlan = PlanModel(
        id: 'plan-1',
        userId: 'user-123',
        name: 'Active Plan',
        goalId: 'goal-123',
        startDate: activeStartDate,
        endDate: activeEndDate,
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(),
        status: PlanStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      final pausedPlan = activePlan.copyWith(status: PlanStatus.paused);

      final notStartedPlan = PlanModel(
        id: 'plan-2',
        userId: 'user-123',
        name: 'Future Plan',
        goalId: 'goal-123',
        startDate: now.add(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 30)),
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(),
        status: PlanStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      expect(activePlan.isActive, true);
      expect(pausedPlan.isActive, false);
      expect(notStartedPlan.isActive, false);
    });

    test('should correctly identify ended status', () {
      final endedPlan = PlanModel(
        id: 'plan-1',
        userId: 'user-123',
        name: 'Ended Plan',
        goalId: 'goal-123',
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.subtract(const Duration(days: 1)),
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(),
        status: PlanStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      final ongoingPlan = PlanModel(
        id: 'plan-2',
        userId: 'user-123',
        name: 'Ongoing Plan',
        goalId: 'goal-123',
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 30)),
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(),
        status: PlanStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      expect(endedPlan.hasEnded, true);
      expect(ongoingPlan.hasEnded, false);
    });

    test('should calculate duration in days correctly', () {
      final plan = PlanModel(
        id: 'plan-123',
        userId: 'user-123',
        name: 'Test Plan',
        goalId: 'goal-123',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 31),
        repeatRule: const RepeatRule(type: RepeatType.daily),
        taskConfig: const TaskConfiguration(),
        createdAt: now,
        updatedAt: now,
      );

      expect(plan.durationDays, 30);
    });

    test('copyWith should NOT allow changing name (immutable)', () {
      final original = PlanModel(
        id: 'plan-123',
        userId: 'user-123',
        name: 'Original Name',
        goalId: 'goal-123',
        startDate: startDate,
        endDate: endDate,
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(),
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        description: 'Updated description',
        status: PlanStatus.paused,
      );

      expect(updated.name, 'Original Name'); // Name should remain unchanged
      expect(updated.description, 'Updated description');
      expect(updated.status, PlanStatus.paused);
      expect(identical(original, updated), false);
    });

    test('should serialize to JSON correctly', () {
      final plan = PlanModel(
        id: 'plan-123',
        userId: 'user-123',
        name: 'Test Plan',
        description: 'A test plan',
        goalId: 'goal-123',
        startDate: startDate,
        endDate: endDate,
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(durationMinutes: 30),
        status: PlanStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      final json = plan.toJson();

      expect(json['id'], 'plan-123');
      expect(json['userId'], 'user-123');
      expect(json['name'], 'Test Plan');
      expect(json['description'], 'A test plan');
      expect(json['goalId'], 'goal-123');
      expect(json['status'], 'active');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'plan-123',
        'userId': 'user-123',
        'name': 'Test Plan',
        'description': 'A test plan',
        'goalId': 'goal-123',
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'repeatRule': {
          'type': 'weekly',
        },
        'taskConfig': {
          'durationMinutes': 30,
        },
        'status': 'active',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final plan = PlanModel.fromJson(json);

      expect(plan.id, 'plan-123');
      expect(plan.userId, 'user-123');
      expect(plan.name, 'Test Plan');
      expect(plan.description, 'A test plan');
      expect(plan.goalId, 'goal-123');
      expect(plan.status, PlanStatus.active);
      expect(plan.repeatRule.type, RepeatType.weekly);
      expect(plan.taskConfig.durationMinutes, 30);
    });

    test('should serialize and deserialize daysOfWeek plan correctly', () {
      final plan = PlanModel(
        id: 'plan-daysofweek',
        userId: 'user-123',
        name: 'Weekend Plan',
        description: 'Tasks for weekend',
        goalId: 'goal-123',
        startDate: startDate,
        endDate: endDate,
        repeatRule: const RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [6, 7], // Saturday, Sunday
        ),
        taskConfig: const TaskConfiguration(durationMinutes: 45),
        status: PlanStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      // Serialize to JSON and encode to string (simulates real serialization)
      final jsonMap = plan.toJson();
      final jsonString = jsonEncode(jsonMap);

      // Decode back to Map (simulates real deserialization)
      final decodedJson = jsonDecode(jsonString) as Map<String, dynamic>;

      // Verify nested RepeatRule JSON structure
      final repeatRuleJson = decodedJson['repeatRule'] as Map<String, dynamic>;
      expect(repeatRuleJson['type'], 'daysOfWeek'); // Critical: camelCase preserved
      expect(repeatRuleJson['selectedDaysOfWeek'], [6, 7]);

      // Deserialize from JSON
      final restored = PlanModel.fromJson(decodedJson);

      // Verify complete restoration
      expect(restored.id, plan.id);
      expect(restored.name, plan.name);
      expect(restored.repeatRule.type, RepeatType.daysOfWeek); // Critical check
      expect(restored.repeatRule.selectedDaysOfWeek, [6, 7]);
      expect(restored.taskConfig.durationMinutes, 45);
      expect(restored, equals(plan));
    });

    test('daysOfWeek plan should survive database-style round-trip', () {
      // This simulates the PlanDao flow:
      // 1. Create plan with daysOfWeek rule
      final originalPlan = PlanModel(
        id: 'plan-db-test',
        userId: 'user-123',
        name: 'Weekday Plan',
        goalId: 'goal-123',
        startDate: startDate,
        endDate: endDate,
        repeatRule: const RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [1, 2, 3, 4, 5], // Weekdays
        ),
        taskConfig: const TaskConfiguration(repeatCount: 10),
        createdAt: now,
        updatedAt: now,
      );

      // 2. Simulate database storage (PlanDao.insertPlan)
      // In database, RepeatRule.type is stored as a string via toDbString()
      final dbRepeatType = originalPlan.repeatRule.type.toDbString();
      expect(dbRepeatType, 'daysOfWeek'); // This is what gets stored in DB

      // 3. Simulate database retrieval (PlanDao._fromMap)
      // RepeatRule.type is reconstructed via RepeatType.fromString()
      final restoredType = RepeatType.fromString(dbRepeatType);
      expect(restoredType, RepeatType.daysOfWeek); // Critical: must match original

      // 4. Verify this works even with different casings (database tolerance)
      expect(RepeatType.fromString('daysofweek'), RepeatType.daysOfWeek);
      expect(RepeatType.fromString('DAYSOFWEEK'), RepeatType.daysOfWeek);
      expect(RepeatType.fromString('DaysOfWeek'), RepeatType.daysOfWeek);
    });

    test('Equatable props should work correctly', () {
      final plan1 = PlanModel(
        id: 'plan-123',
        userId: 'user-123',
        name: 'Test Plan',
        goalId: 'goal-123',
        startDate: startDate,
        endDate: endDate,
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(durationMinutes: 30),
        createdAt: now,
        updatedAt: now,
      );

      final plan2 = PlanModel(
        id: 'plan-123',
        userId: 'user-123',
        name: 'Test Plan',
        goalId: 'goal-123',
        startDate: startDate,
        endDate: endDate,
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(durationMinutes: 30),
        createdAt: now,
        updatedAt: now,
      );

      final plan3 = PlanModel(
        id: 'plan-456',
        userId: 'user-123',
        name: 'Different Plan',
        goalId: 'goal-123',
        startDate: startDate,
        endDate: endDate,
        repeatRule: const RepeatRule(type: RepeatType.daily),
        taskConfig: const TaskConfiguration(),
        createdAt: now,
        updatedAt: now,
      );

      expect(plan1, equals(plan2));
      expect(plan1, isNot(equals(plan3)));
    });

    test('should handle soft delete correctly', () {
      final activePlan = PlanModel(
        id: 'plan-123',
        userId: 'user-123',
        name: 'Test Plan',
        goalId: 'goal-123',
        startDate: startDate,
        endDate: endDate,
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(),
        status: PlanStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      final deletedPlan = activePlan.copyWith(
        status: PlanStatus.deleted,
        deletedAt: now,
      );

      expect(activePlan.isDeleted, false);
      expect(activePlan.deletedAt, null);
      expect(deletedPlan.isDeleted, true);
      expect(deletedPlan.deletedAt, isNotNull);
    });
  });
}
