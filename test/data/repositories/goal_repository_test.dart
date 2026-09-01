import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:myassistant/data/repositories/goal_repository.dart';
import 'package:myassistant/data/data_sources/local/dao/goal_dao.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'goal_repository_test.mocks.dart';

@GenerateMocks([GoalDao])
void main() {
  // Initialize sqflite ffi for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late GoalRepository repository;
  late MockGoalDao mockGoalDao;

  setUp(() {
    mockGoalDao = MockGoalDao();
    repository = GoalRepository(goalDao: mockGoalDao);
  });

  // Helper function to create a test goal
  GoalModel createTestGoal({
    String id = 'goal-123',
    String userId = 'user-123',
    String title = 'Test Goal',
    String? description,
    DateTime? deadline,
    Priority priority = Priority.medium,
    List<String>? tags,
    GoalStatus status = GoalStatus.active,
    List<String>? planIds,
    DateTime? deletedAt,
  }) {
    final now = DateTime.now();
    return GoalModel(
      id: id,
      userId: userId,
      title: title,
      description: description,
      tags: tags ?? const [],
      deadline: deadline,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
      priority: priority,
      status: status,
      successCriteria: null,
      planIds: planIds ?? const [],
      deletedAt: deletedAt,
    );
  }

  group('GoalRepository - createGoal', () {
    test('should create a goal with correct fields and return it', () async {
      // Arrange
      const userId = 'user-123';
      const title = 'New Goal';
      const description = 'A test goal';
      final deadline = DateTime.now().add(const Duration(days: 30));
      const priority = Priority.high;
      const tags = ['health', 'fitness'];

      when(mockGoalDao.insertGoal(any)).thenAnswer((invocation) async {
        final goal = invocation.positionalArguments[0] as GoalModel;
        return goal;
      });

      // Act
      final result = await repository.createGoal(
        userId: userId,
        title: title,
        description: description,
        deadline: deadline,
        priority: priority,
        tags: tags,
      );

      // Assert
      expect(result.userId, userId);
      expect(result.title, title);
      expect(result.description, description);
      expect(result.priority, priority);
      expect(result.tags, tags);
      expect(result.status, GoalStatus.active);
      expect(result.planIds, const []);
      expect(result.id, isNotEmpty);
      verify(mockGoalDao.insertGoal(any)).called(1);
    });

    test('should create a goal with default priority when not specified', () async {
      // Arrange
      when(mockGoalDao.insertGoal(any)).thenAnswer((invocation) async {
        return invocation.positionalArguments[0] as GoalModel;
      });

      // Act
      final result = await repository.createGoal(
        userId: 'user-123',
        title: 'Default Priority Goal',
      );

      // Assert
      expect(result.priority, Priority.medium);
      expect(result.tags, const []);
    });

    test('should generate a unique UUID for each goal', () async {
      // Arrange
      when(mockGoalDao.insertGoal(any)).thenAnswer((invocation) async {
        return invocation.positionalArguments[0] as GoalModel;
      });

      // Act
      final result1 = await repository.createGoal(
        userId: 'user-123',
        title: 'Goal 1',
      );
      final result2 = await repository.createGoal(
        userId: 'user-123',
        title: 'Goal 2',
      );

      // Assert
      expect(result1.id, isNot(result2.id));
    });

    test('should rethrow exception when DAO insert fails', () async {
      // Arrange
      when(mockGoalDao.insertGoal(any)).thenThrow(Exception('DB error'));

      // Act & Assert
      expect(
        () => repository.createGoal(
          userId: 'user-123',
          title: 'Failing Goal',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('GoalRepository - getGoalById', () {
    test('should return goal when found', () async {
      // Arrange
      final goal = createTestGoal();
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => goal);

      // Act
      final result = await repository.getGoalById('goal-123');

      // Assert
      expect(result, goal);
      verify(mockGoalDao.getGoalById('goal-123')).called(1);
    });

    test('should return null when goal not found', () async {
      // Arrange
      when(mockGoalDao.getGoalById('nonexistent'))
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.getGoalById('nonexistent');

      // Assert
      expect(result, isNull);
    });
  });

  group('GoalRepository - updateGoal', () {
    test('should update goal and set new updatedAt timestamp', () async {
      // Arrange
      final goal = createTestGoal();
      when(mockGoalDao.updateGoal(any)).thenAnswer((_) async => 1);

      // Act
      final result = await repository.updateGoal(goal);

      // Assert
      expect(result.title, goal.title);
      expect(result.updatedAt.isAfter(goal.updatedAt) ||
          result.updatedAt.isAtSameMomentAs(goal.updatedAt), isTrue);
      verify(mockGoalDao.updateGoal(any)).called(1);
    });

    test('should throw exception when DAO update returns 0', () async {
      // Arrange
      final goal = createTestGoal();
      when(mockGoalDao.updateGoal(any)).thenAnswer((_) async => 0);

      // Act & Assert
      expect(
        () => repository.updateGoal(goal),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to update goal'),
        )),
      );
    });
  });

  group('GoalRepository - updateGoalStatus', () {
    test('should update status for active goal', () async {
      // Arrange
      final goal = createTestGoal(status: GoalStatus.active);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => goal);
      when(mockGoalDao.updateGoalStatus('goal-123', GoalStatus.paused))
          .thenAnswer((_) async => 1);

      // Act
      final result = await repository.updateGoalStatus('goal-123', GoalStatus.paused);

      // Assert
      expect(result.status, GoalStatus.paused);
      verify(mockGoalDao.updateGoalStatus('goal-123', GoalStatus.paused)).called(1);
    });

    test('should allow setting completed status on active goal', () async {
      // Arrange
      final goal = createTestGoal(status: GoalStatus.active);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => goal);
      when(mockGoalDao.updateGoalStatus('goal-123', GoalStatus.completed))
          .thenAnswer((_) async => 1);

      // Act
      final result = await repository.updateGoalStatus('goal-123', GoalStatus.completed);

      // Assert
      expect(result.status, GoalStatus.completed);
    });

    test('should throw exception when goal not found', () async {
      // Arrange
      when(mockGoalDao.getGoalById('nonexistent'))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => repository.updateGoalStatus('nonexistent', GoalStatus.paused),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Goal not found'),
        )),
      );
    });

    test('should throw exception when trying to modify completed goal', () async {
      // Arrange
      final completedGoal = createTestGoal(status: GoalStatus.completed);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => completedGoal);

      // Act & Assert
      expect(
        () => repository.updateGoalStatus('goal-123', GoalStatus.active),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Cannot modify completed goal'),
        )),
      );
    });

    test('should allow re-setting completed status on completed goal', () async {
      // Arrange
      final completedGoal = createTestGoal(status: GoalStatus.completed);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => completedGoal);
      when(mockGoalDao.updateGoalStatus('goal-123', GoalStatus.completed))
          .thenAnswer((_) async => 1);

      // Act
      final result = await repository.updateGoalStatus('goal-123', GoalStatus.completed);

      // Assert
      expect(result.status, GoalStatus.completed);
    });

    test('should throw exception when trying to change completed to paused', () async {
      // Arrange
      final completedGoal = createTestGoal(status: GoalStatus.completed);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => completedGoal);

      // Act & Assert
      expect(
        () => repository.updateGoalStatus('goal-123', GoalStatus.paused),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Cannot modify completed goal'),
        )),
      );
    });

    test('should throw exception when DAO updateGoalStatus returns 0', () async {
      // Arrange
      final goal = createTestGoal(status: GoalStatus.active);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => goal);
      when(mockGoalDao.updateGoalStatus('goal-123', GoalStatus.paused))
          .thenAnswer((_) async => 0);

      // Act & Assert
      expect(
        () => repository.updateGoalStatus('goal-123', GoalStatus.paused),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to update goal status'),
        )),
      );
    });
  });

  group('GoalRepository - addPlanToGoal', () {
    test('should add plan to goal when not already present', () async {
      // Arrange
      final goal = createTestGoal(planIds: ['plan-1']);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => goal);
      when(mockGoalDao.updateGoal(any)).thenAnswer((_) async => 1);

      // Act
      final result = await repository.addPlanToGoal('goal-123', 'plan-2');

      // Assert
      expect(result, true);
      final captured = verify(mockGoalDao.updateGoal(captureAny)).captured.single as GoalModel;
      expect(captured.planIds, ['plan-1', 'plan-2']);
    });

    test('should return true without update when plan already in goal', () async {
      // Arrange
      final goal = createTestGoal(planIds: ['plan-1', 'plan-2']);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => goal);

      // Act
      final result = await repository.addPlanToGoal('goal-123', 'plan-2');

      // Assert
      expect(result, true);
      verifyNever(mockGoalDao.updateGoal(any));
    });

    test('should return false when goal not found', () async {
      // Arrange
      when(mockGoalDao.getGoalById('nonexistent'))
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.addPlanToGoal('nonexistent', 'plan-1');

      // Assert
      expect(result, false);
    });

    test('should return false when DAO update returns 0', () async {
      // Arrange
      final goal = createTestGoal(planIds: []);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => goal);
      when(mockGoalDao.updateGoal(any)).thenAnswer((_) async => 0);

      // Act
      final result = await repository.addPlanToGoal('goal-123', 'plan-1');

      // Assert
      expect(result, false);
    });

    test('should add plan to goal with empty planIds list', () async {
      // Arrange
      final goal = createTestGoal(planIds: []);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => goal);
      when(mockGoalDao.updateGoal(any)).thenAnswer((_) async => 1);

      // Act
      final result = await repository.addPlanToGoal('goal-123', 'plan-1');

      // Assert
      expect(result, true);
      final captured = verify(mockGoalDao.updateGoal(captureAny)).captured.single as GoalModel;
      expect(captured.planIds, ['plan-1']);
    });
  });

  group('GoalRepository - removePlanFromGoal', () {
    test('should remove plan from goal when present', () async {
      // Arrange
      final goal = createTestGoal(planIds: ['plan-1', 'plan-2', 'plan-3']);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => goal);
      when(mockGoalDao.updateGoal(any)).thenAnswer((_) async => 1);

      // Act
      final result = await repository.removePlanFromGoal('goal-123', 'plan-2');

      // Assert
      expect(result, true);
      final captured = verify(mockGoalDao.updateGoal(captureAny)).captured.single as GoalModel;
      expect(captured.planIds, ['plan-1', 'plan-3']);
    });

    test('should return true when plan is not in goal', () async {
      // Arrange
      final goal = createTestGoal(planIds: ['plan-1']);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => goal);

      // Act
      final result = await repository.removePlanFromGoal('goal-123', 'plan-99');

      // Assert
      expect(result, true);
      verifyNever(mockGoalDao.updateGoal(any));
    });

    test('should return false when goal not found', () async {
      // Arrange
      when(mockGoalDao.getGoalById('nonexistent'))
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.removePlanFromGoal('nonexistent', 'plan-1');

      // Assert
      expect(result, false);
    });

    test('should return false when DAO update returns 0', () async {
      // Arrange
      final goal = createTestGoal(planIds: ['plan-1']);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => goal);
      when(mockGoalDao.updateGoal(any)).thenAnswer((_) async => 0);

      // Act
      final result = await repository.removePlanFromGoal('goal-123', 'plan-1');

      // Assert
      expect(result, false);
    });

    test('should result in empty planIds when removing the only plan', () async {
      // Arrange
      final goal = createTestGoal(planIds: ['plan-1']);
      when(mockGoalDao.getGoalById('goal-123'))
          .thenAnswer((_) async => goal);
      when(mockGoalDao.updateGoal(any)).thenAnswer((_) async => 1);

      // Act
      final result = await repository.removePlanFromGoal('goal-123', 'plan-1');

      // Assert
      expect(result, true);
      final captured = verify(mockGoalDao.updateGoal(captureAny)).captured.single as GoalModel;
      expect(captured.planIds, isEmpty);
    });
  });

  group('GoalRepository - deleteGoal', () {
    test('should return true when soft delete succeeds', () async {
      // Arrange
      when(mockGoalDao.deleteGoal('goal-123')).thenAnswer((_) async => 1);

      // Act
      final result = await repository.deleteGoal('goal-123');

      // Assert
      expect(result, true);
      verify(mockGoalDao.deleteGoal('goal-123')).called(1);
    });

    test('should return false when soft delete affects no rows', () async {
      // Arrange
      when(mockGoalDao.deleteGoal('nonexistent')).thenAnswer((_) async => 0);

      // Act
      final result = await repository.deleteGoal('nonexistent');

      // Assert
      expect(result, false);
    });
  });

  group('GoalRepository - restoreGoal', () {
    test('should return true when restore succeeds', () async {
      // Arrange
      when(mockGoalDao.restoreGoal('goal-123')).thenAnswer((_) async => 1);

      // Act
      final result = await repository.restoreGoal('goal-123');

      // Assert
      expect(result, true);
      verify(mockGoalDao.restoreGoal('goal-123')).called(1);
    });

    test('should return false when restore affects no rows', () async {
      // Arrange
      when(mockGoalDao.restoreGoal('nonexistent')).thenAnswer((_) async => 0);

      // Act
      final result = await repository.restoreGoal('nonexistent');

      // Assert
      expect(result, false);
    });
  });

  group('GoalRepository - searchGoals', () {
    test('should return all user goals when query is empty', () async {
      // Arrange
      final goals = [createTestGoal(id: 'goal-1'), createTestGoal(id: 'goal-2')];
      when(mockGoalDao.getUserGoals('user-123'))
          .thenAnswer((_) async => goals);

      // Act
      final result = await repository.searchGoals('user-123', '');

      // Assert
      expect(result.length, 2);
      verify(mockGoalDao.getUserGoals('user-123')).called(1);
      verifyNever(mockGoalDao.searchGoals(any, any));
    });

    test('should delegate to DAO searchGoals when query is not empty', () async {
      // Arrange
      final goals = [createTestGoal(title: 'Health Goal')];
      when(mockGoalDao.searchGoals('user-123', 'Health'))
          .thenAnswer((_) async => goals);

      // Act
      final result = await repository.searchGoals('user-123', 'Health');

      // Assert
      expect(result.length, 1);
      expect(result.first.title, 'Health Goal');
      verify(mockGoalDao.searchGoals('user-123', 'Health')).called(1);
    });
  });

  group('GoalRepository - delegate methods', () {
    test('getGoalByUserAndTitle should delegate to DAO', () async {
      // Arrange
      final goal = createTestGoal();
      when(mockGoalDao.getGoalByUserAndTitle('user-123', 'Test Goal'))
          .thenAnswer((_) async => goal);

      // Act
      final result = await repository.getGoalByUserAndTitle('user-123', 'Test Goal');

      // Assert
      expect(result, goal);
      verify(mockGoalDao.getGoalByUserAndTitle('user-123', 'Test Goal')).called(1);
    });

    test('getUserGoals should delegate to DAO', () async {
      // Arrange
      final goals = [createTestGoal()];
      when(mockGoalDao.getUserGoals('user-123'))
          .thenAnswer((_) async => goals);

      // Act
      final result = await repository.getUserGoals('user-123');

      // Assert
      expect(result, goals);
    });

    test('getActiveGoals should delegate to DAO', () async {
      // Arrange
      final goals = [createTestGoal(status: GoalStatus.active)];
      when(mockGoalDao.getActiveGoals('user-123'))
          .thenAnswer((_) async => goals);

      // Act
      final result = await repository.getActiveGoals('user-123');

      // Assert
      expect(result, goals);
    });

    test('getGoalsByStatus should delegate to DAO', () async {
      // Arrange
      final goals = [createTestGoal(status: GoalStatus.paused)];
      when(mockGoalDao.getGoalsByStatus('user-123', GoalStatus.paused))
          .thenAnswer((_) async => goals);

      // Act
      final result = await repository.getGoalsByStatus('user-123', GoalStatus.paused);

      // Assert
      expect(result, goals);
    });

    test('getGoalsByPriority should delegate to DAO', () async {
      // Arrange
      final goals = [createTestGoal(priority: Priority.high)];
      when(mockGoalDao.getGoalsByPriority('user-123', Priority.high))
          .thenAnswer((_) async => goals);

      // Act
      final result = await repository.getGoalsByPriority('user-123', Priority.high);

      // Assert
      expect(result, goals);
    });

    test('getGoalsByTags should delegate to DAO', () async {
      // Arrange
      final goals = [createTestGoal(tags: ['health'])];
      when(mockGoalDao.getGoalsByTags('user-123', ['health']))
          .thenAnswer((_) async => goals);

      // Act
      final result = await repository.getGoalsByTags('user-123', ['health']);

      // Assert
      expect(result, goals);
    });

    test('getUpcomingDeadlineGoals should delegate to DAO with default days', () async {
      // Arrange
      final goals = [createTestGoal()];
      when(mockGoalDao.getUpcomingDeadlineGoals('user-123', days: 7))
          .thenAnswer((_) async => goals);

      // Act
      final result = await repository.getUpcomingDeadlineGoals('user-123');

      // Assert
      expect(result, goals);
    });

    test('getUpcomingDeadlineGoals should delegate to DAO with custom days', () async {
      // Arrange
      final goals = [createTestGoal()];
      when(mockGoalDao.getUpcomingDeadlineGoals('user-123', days: 14))
          .thenAnswer((_) async => goals);

      // Act
      final result = await repository.getUpcomingDeadlineGoals('user-123', days: 14);

      // Assert
      expect(result, goals);
    });

    test('getGoalProgress should delegate to DAO', () async {
      // Arrange
      when(mockGoalDao.getGoalProgress('goal-123'))
          .thenAnswer((_) async => 0.75);

      // Act
      final result = await repository.getGoalProgress('goal-123');

      // Assert
      expect(result, 0.75);
    });

    test('getGoalStatistics should delegate to DAO', () async {
      // Arrange
      final stats = {
        'planCount': 3,
        'overallProgress': 0.6,
        'totalCompletedTasks': 10,
        'totalTasks': 20,
      };
      when(mockGoalDao.getGoalStatistics('goal-123'))
          .thenAnswer((_) async => stats);

      // Act
      final result = await repository.getGoalStatistics('goal-123');

      // Assert
      expect(result, stats);
    });

    test('getDeletedGoals should delegate to DAO', () async {
      // Arrange
      final goals = [createTestGoal(status: GoalStatus.deleted, deletedAt: DateTime.now())];
      when(mockGoalDao.getDeletedGoals('user-123'))
          .thenAnswer((_) async => goals);

      // Act
      final result = await repository.getDeletedGoals('user-123');

      // Assert
      expect(result, goals);
    });
  });
}
