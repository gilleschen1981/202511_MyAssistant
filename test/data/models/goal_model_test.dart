import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/status.dart';

void main() {
  group('GoalModel', () {
    final now = DateTime.now();

    test('should create a GoalModel with required fields', () {
      final goal = GoalModel(
        id: 'goal-123',
        userId: 'user-123',
        title: 'Test Goal',
        tags: [],
        createdAt: now,
        updatedAt: now,
        priority: Priority.medium,
        status: GoalStatus.active,
        planIds: [],
      );

      expect(goal.id, 'goal-123');
      expect(goal.userId, 'user-123');
      expect(goal.title, 'Test Goal');
      expect(goal.priority, Priority.medium);
      expect(goal.status, GoalStatus.active);
      expect(goal.tags, isEmpty);
      expect(goal.planIds, isEmpty);
      expect(goal.description, null);
      expect(goal.deadline, null);
      expect(goal.successCriteria, null);
      expect(goal.deletedAt, null);
    });

    test('should create a GoalModel with all fields', () {
      final deadline = now.add(const Duration(days: 30));
      final goal = GoalModel(
        id: 'goal-123',
        userId: 'user-123',
        title: 'Complete Goal',
        description: 'A complete goal for testing',
        tags: ['health', 'fitness'],
        deadline: deadline,
        createdAt: now,
        updatedAt: now,
        priority: Priority.high,
        status: GoalStatus.active,
        successCriteria: 'Complete all tasks',
        planIds: ['plan-1', 'plan-2'],
        deletedAt: null,
      );

      expect(goal.description, 'A complete goal for testing');
      expect(goal.tags, ['health', 'fitness']);
      expect(goal.deadline, deadline);
      expect(goal.priority, Priority.high);
      expect(goal.successCriteria, 'Complete all tasks');
      expect(goal.planIds, ['plan-1', 'plan-2']);
    });

    test('planCount should return correct number of plans', () {
      final goalWithPlans = GoalModel(
        id: 'goal-123',
        userId: 'user-123',
        title: 'Goal with Plans',
        tags: [],
        createdAt: now,
        updatedAt: now,
        priority: Priority.medium,
        status: GoalStatus.active,
        planIds: ['plan-1', 'plan-2', 'plan-3'],
      );

      final goalWithoutPlans = GoalModel(
        id: 'goal-456',
        userId: 'user-123',
        title: 'Goal without Plans',
        tags: [],
        createdAt: now,
        updatedAt: now,
        priority: Priority.medium,
        status: GoalStatus.active,
        planIds: [],
      );

      expect(goalWithPlans.planCount, 3);
      expect(goalWithoutPlans.planCount, 0);
    });

    test('should correctly identify deleted status', () {
      final activeGoal = GoalModel(
        id: 'goal-1',
        userId: 'user-123',
        title: 'Active Goal',
        tags: [],
        createdAt: now,
        updatedAt: now,
        priority: Priority.medium,
        status: GoalStatus.active,
        planIds: [],
      );

      final deletedGoal = activeGoal.copyWith(
        status: GoalStatus.deleted,
        deletedAt: now,
      );

      expect(activeGoal.isDeleted, false);
      expect(deletedGoal.isDeleted, true);
    });

    test('should correctly identify active status', () {
      final activeGoal = GoalModel(
        id: 'goal-1',
        userId: 'user-123',
        title: 'Active Goal',
        tags: [],
        createdAt: now,
        updatedAt: now,
        priority: Priority.medium,
        status: GoalStatus.active,
        planIds: [],
      );

      final completedGoal = activeGoal.copyWith(status: GoalStatus.completed);
      final pausedGoal = activeGoal.copyWith(status: GoalStatus.paused);

      expect(activeGoal.isActive, true);
      expect(completedGoal.isActive, false);
      expect(pausedGoal.isActive, false);
    });

    test('daysRemaining should return null when no deadline', () {
      final goal = GoalModel(
        id: 'goal-123',
        userId: 'user-123',
        title: 'Goal without Deadline',
        tags: [],
        deadline: null,
        createdAt: now,
        updatedAt: now,
        priority: Priority.medium,
        status: GoalStatus.active,
        planIds: [],
      );

      expect(goal.daysRemaining, null);
    });

    test('daysRemaining should return 0 when deadline has passed', () {
      final pastDeadline = now.subtract(const Duration(days: 5));
      final goal = GoalModel(
        id: 'goal-123',
        userId: 'user-123',
        title: 'Overdue Goal',
        tags: [],
        deadline: pastDeadline,
        createdAt: now,
        updatedAt: now,
        priority: Priority.high,
        status: GoalStatus.active,
        planIds: [],
      );

      expect(goal.daysRemaining, 0);
    });

    test('daysRemaining should return correct days when deadline is in future', () {
      final futureDeadline = now.add(const Duration(days: 10));
      final goal = GoalModel(
        id: 'goal-123',
        userId: 'user-123',
        title: 'Future Goal',
        tags: [],
        deadline: futureDeadline,
        createdAt: now,
        updatedAt: now,
        priority: Priority.medium,
        status: GoalStatus.active,
        planIds: [],
      );

      // Should be approximately 10 days (might be 9 due to time precision)
      expect(goal.daysRemaining, greaterThanOrEqualTo(9));
      expect(goal.daysRemaining, lessThanOrEqualTo(10));
    });

    test('copyWith should create a new instance with updated fields', () {
      final original = GoalModel(
        id: 'goal-123',
        userId: 'user-123',
        title: 'Original Goal',
        tags: ['old-tag'],
        createdAt: now,
        updatedAt: now,
        priority: Priority.low,
        status: GoalStatus.active,
        planIds: [],
      );

      final updated = original.copyWith(
        title: 'Updated Goal',
        priority: Priority.high,
        tags: ['new-tag'],
        status: GoalStatus.completed,
      );

      expect(updated.id, original.id);
      expect(updated.userId, original.userId);
      expect(updated.title, 'Updated Goal');
      expect(updated.priority, Priority.high);
      expect(updated.tags, ['new-tag']);
      expect(updated.status, GoalStatus.completed);
      expect(identical(original, updated), false);
    });

    test('should serialize to JSON correctly', () {
      final deadline = DateTime(2024, 12, 31);
      final goal = GoalModel(
        id: 'goal-123',
        userId: 'user-123',
        title: 'Test Goal',
        description: 'A test goal',
        tags: ['fitness', 'health'],
        deadline: deadline,
        createdAt: now,
        updatedAt: now,
        priority: Priority.high,
        status: GoalStatus.active,
        successCriteria: 'Complete all tasks',
        planIds: ['plan-1', 'plan-2'],
      );

      final json = goal.toJson();

      expect(json['id'], 'goal-123');
      expect(json['userId'], 'user-123');
      expect(json['title'], 'Test Goal');
      expect(json['description'], 'A test goal');
      expect(json['tags'], ['fitness', 'health']);
      expect(json['priority'], 'high');
      expect(json['status'], 'active');
      expect(json['successCriteria'], 'Complete all tasks');
      expect(json['planIds'], ['plan-1', 'plan-2']);
    });

    test('should deserialize from JSON correctly', () {
      final deadline = DateTime(2024, 12, 31);
      final json = {
        'id': 'goal-123',
        'userId': 'user-123',
        'title': 'Test Goal',
        'description': 'A test goal',
        'tags': ['fitness', 'health'],
        'deadline': deadline.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'priority': 'high',
        'status': 'active',
        'successCriteria': 'Complete all tasks',
        'planIds': ['plan-1', 'plan-2'],
      };

      final goal = GoalModel.fromJson(json);

      expect(goal.id, 'goal-123');
      expect(goal.userId, 'user-123');
      expect(goal.title, 'Test Goal');
      expect(goal.description, 'A test goal');
      expect(goal.tags, ['fitness', 'health']);
      expect(goal.priority, Priority.high);
      expect(goal.status, GoalStatus.active);
      expect(goal.successCriteria, 'Complete all tasks');
      expect(goal.planIds, ['plan-1', 'plan-2']);
    });

    test('Equatable props should work correctly', () {
      final goal1 = GoalModel(
        id: 'goal-123',
        userId: 'user-123',
        title: 'Test Goal',
        tags: ['tag1'],
        createdAt: now,
        updatedAt: now,
        priority: Priority.medium,
        status: GoalStatus.active,
        planIds: [],
      );

      final goal2 = GoalModel(
        id: 'goal-123',
        userId: 'user-123',
        title: 'Test Goal',
        tags: ['tag1'],
        createdAt: now,
        updatedAt: now,
        priority: Priority.medium,
        status: GoalStatus.active,
        planIds: [],
      );

      final goal3 = GoalModel(
        id: 'goal-456',
        userId: 'user-123',
        title: 'Different Goal',
        tags: [],
        createdAt: now,
        updatedAt: now,
        priority: Priority.high,
        status: GoalStatus.active,
        planIds: [],
      );

      expect(goal1, equals(goal2));
      expect(goal1, isNot(equals(goal3)));
    });

    test('should handle soft delete correctly', () {
      final activeGoal = GoalModel(
        id: 'goal-123',
        userId: 'user-123',
        title: 'Test Goal',
        tags: [],
        createdAt: now,
        updatedAt: now,
        priority: Priority.medium,
        status: GoalStatus.active,
        planIds: [],
      );

      final deletedGoal = activeGoal.copyWith(
        status: GoalStatus.deleted,
        deletedAt: now,
      );

      expect(activeGoal.isDeleted, false);
      expect(activeGoal.deletedAt, null);
      expect(deletedGoal.isDeleted, true);
      expect(deletedGoal.deletedAt, isNotNull);
    });

    test('should handle different priority levels', () {
      final lowPriorityGoal = GoalModel(
        id: 'goal-1',
        userId: 'user-123',
        title: 'Low Priority',
        tags: [],
        createdAt: now,
        updatedAt: now,
        priority: Priority.low,
        status: GoalStatus.active,
        planIds: [],
      );

      final mediumPriorityGoal = lowPriorityGoal.copyWith(
        priority: Priority.medium,
      );

      final highPriorityGoal = lowPriorityGoal.copyWith(
        priority: Priority.high,
      );

      expect(lowPriorityGoal.priority, Priority.low);
      expect(mediumPriorityGoal.priority, Priority.medium);
      expect(highPriorityGoal.priority, Priority.high);
    });

    test('should handle different goal statuses', () {
      final activeGoal = GoalModel(
        id: 'goal-1',
        userId: 'user-123',
        title: 'Test Goal',
        tags: [],
        createdAt: now,
        updatedAt: now,
        priority: Priority.medium,
        status: GoalStatus.active,
        planIds: [],
      );

      final completedGoal = activeGoal.copyWith(status: GoalStatus.completed);
      final pausedGoal = activeGoal.copyWith(status: GoalStatus.paused);
      final deletedGoal = activeGoal.copyWith(status: GoalStatus.deleted);

      expect(activeGoal.status, GoalStatus.active);
      expect(completedGoal.status, GoalStatus.completed);
      expect(pausedGoal.status, GoalStatus.paused);
      expect(deletedGoal.status, GoalStatus.deleted);
    });

    test('should handle tags correctly', () {
      final goalWithoutTags = GoalModel(
        id: 'goal-1',
        userId: 'user-123',
        title: 'No Tags',
        tags: [],
        createdAt: now,
        updatedAt: now,
        priority: Priority.medium,
        status: GoalStatus.active,
        planIds: [],
      );

      final goalWithTags = goalWithoutTags.copyWith(
        tags: ['fitness', 'health', 'personal'],
      );

      expect(goalWithoutTags.tags, isEmpty);
      expect(goalWithTags.tags, ['fitness', 'health', 'personal']);
      expect(goalWithTags.tags.length, 3);
    });

    test('should handle multiple plans in planIds', () {
      final goal = GoalModel(
        id: 'goal-123',
        userId: 'user-123',
        title: 'Goal with Multiple Plans',
        tags: [],
        createdAt: now,
        updatedAt: now,
        priority: Priority.medium,
        status: GoalStatus.active,
        planIds: ['plan-1', 'plan-2', 'plan-3', 'plan-4', 'plan-5'],
      );

      expect(goal.planCount, 5);
      expect(goal.planIds.contains('plan-1'), true);
      expect(goal.planIds.contains('plan-5'), true);
      expect(goal.planIds.contains('plan-99'), false);
    });
  });
}
