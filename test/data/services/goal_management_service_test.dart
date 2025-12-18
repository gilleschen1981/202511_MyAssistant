import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:myassistant/data/services/goal_management_service.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/domain/repositories/i_goal_repository.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/core/errors/exceptions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'goal_management_service_test.mocks.dart';

@GenerateMocks([IGoalRepository, IPlanRepository, ITaskRepository])
void main() {
  // Initialize sqflite ffi for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  late GoalManagementService service;
  late MockIGoalRepository mockGoalRepository;
  late MockIPlanRepository mockPlanRepository;
  late MockITaskRepository mockTaskRepository;

  setUp(() {
    mockGoalRepository = MockIGoalRepository();
    mockPlanRepository = MockIPlanRepository();
    mockTaskRepository = MockITaskRepository();
    service = GoalManagementService(
      goalRepository: mockGoalRepository,
      planRepository: mockPlanRepository,
      taskRepository: mockTaskRepository,
    );
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
      planIds: const [],
      deletedAt: deletedAt,
    );
  }

  // Helper function to create a test plan
  PlanModel createTestPlan({
    String id = 'plan-123',
    String userId = 'user-123',
    String goalId = 'goal-123',
    String name = 'Test Plan',
    PlanStatus status = PlanStatus.active,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    return PlanModel(
      id: id,
      userId: userId,
      name: name,
      goalId: goalId,
      startDate: startDate ?? now.subtract(const Duration(days: 7)),
      endDate: endDate ?? now.add(const Duration(days: 23)),
      repeatRule: const RepeatRule(type: RepeatType.weekly),
      taskConfig: const TaskConfiguration(durationMinutes: 30),
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Helper function to create a test task
  TaskModel createTestTask({
    String id = 'task-123',
    String planId = 'plan-123',
    TaskStatus status = TaskStatus.active,
  }) {
    final now = DateTime.now();
    return TaskModel(
      id: id,
      userId: 'user-123',
      planId: planId,
      name: 'Test Task',
      config: const TaskConfiguration(),
      windowStartTime: now,
      windowEndTime: now.add(const Duration(days: 7)),
      status: status,
      createdAt: now,
    );
  }

  group('GoalManagementService - createGoal', () {
    test('should successfully create a goal with valid input', () async {
      // Arrange
      const userId = 'user-123';
      const title = 'New Goal';
      final deadline = DateTime.now().add(const Duration(days: 30));

      when(mockGoalRepository.getUserGoals(userId))
          .thenAnswer((_) async => []);
      when(mockGoalRepository.createGoal(
        userId: anyNamed('userId'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        deadline: anyNamed('deadline'),
        priority: anyNamed('priority'),
        tags: anyNamed('tags'),
        successCriteria: anyNamed('successCriteria'),
      )).thenAnswer((_) async => createTestGoal(title: title, deadline: deadline));

      // Act
      final result = await service.createGoal(
        userId: userId,
        title: title,
        description: 'Test description',
        deadline: deadline,
        priority: Priority.high,
        tags: const ['health', 'fitness'],
      );

      // Assert
      expect(result.title, title);
      verify(mockGoalRepository.getUserGoals(userId)).called(1);
      verify(mockGoalRepository.createGoal(
        userId: anyNamed('userId'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        deadline: anyNamed('deadline'),
        priority: anyNamed('priority'),
        tags: anyNamed('tags'),
        successCriteria: anyNamed('successCriteria'),
      )).called(1);
    });

    test('should throw ValidationException for empty title', () async {
      // Act & Assert
      expect(
        () => service.createGoal(
          userId: 'user-123',
          title: '',
          description: 'Test',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for title too long', () async {
      // Arrange
      final longTitle = 'a' * 101; // 101 characters

      // Act & Assert
      expect(
        () => service.createGoal(
          userId: 'user-123',
          title: longTitle,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for description too long', () async {
      // Arrange
      final longDescription = 'a' * 501; // 501 characters

      // Act & Assert
      expect(
        () => service.createGoal(
          userId: 'user-123',
          title: 'Valid Title',
          description: longDescription,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for deadline in the past', () async {
      // Arrange
      final pastDeadline = DateTime.now().subtract(const Duration(days: 1));

      // Act & Assert
      expect(
        () => service.createGoal(
          userId: 'user-123',
          title: 'Valid Title',
          deadline: pastDeadline,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for deadline too far in future', () async {
      // Arrange
      final farFutureDeadline = DateTime.now().add(const Duration(days: 365 * 6));

      // Act & Assert
      expect(
        () => service.createGoal(
          userId: 'user-123',
          title: 'Valid Title',
          deadline: farFutureDeadline,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException when duplicate title exists', () async {
      // Arrange
      const userId = 'user-123';
      const title = 'Duplicate Goal';
      final existingGoal = createTestGoal(title: title);

      when(mockGoalRepository.getUserGoals(userId))
          .thenAnswer((_) async => [existingGoal]);

      // Act & Assert
      expect(
        () => service.createGoal(
          userId: userId,
          title: title,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should allow creating goal with same title as deleted goal', () async {
      // Arrange
      const userId = 'user-123';
      const title = 'Reused Goal Title';
      final deletedGoal = createTestGoal(
        title: title,
        deletedAt: DateTime.now(),
      );

      when(mockGoalRepository.getUserGoals(userId))
          .thenAnswer((_) async => [deletedGoal]);
      when(mockGoalRepository.createGoal(
        userId: anyNamed('userId'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        deadline: anyNamed('deadline'),
        priority: anyNamed('priority'),
        tags: anyNamed('tags'),
        successCriteria: anyNamed('successCriteria'),
      )).thenAnswer((_) async => createTestGoal(title: title));

      // Act
      final result = await service.createGoal(
        userId: userId,
        title: title,
      );

      // Assert
      expect(result.title, title);
    });

    test('should create goal with tags', () async {
      // Arrange
      const userId = 'user-123';
      const title = 'Tagged Goal';
      const tags = ['health', 'fitness', 'personal'];

      when(mockGoalRepository.getUserGoals(userId))
          .thenAnswer((_) async => []);
      when(mockGoalRepository.createGoal(
        userId: anyNamed('userId'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        deadline: anyNamed('deadline'),
        priority: anyNamed('priority'),
        tags: anyNamed('tags'),
        successCriteria: anyNamed('successCriteria'),
      )).thenAnswer((_) async => createTestGoal(title: title, tags: tags));

      // Act
      final result = await service.createGoal(
        userId: userId,
        title: title,
        tags: tags,
      );

      // Assert
      expect(result.tags, tags);
    });
  });

  group('GoalManagementService - updateGoal', () {
    test('should successfully update goal fields', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId);
      final newDeadline = DateTime.now().add(const Duration(days: 60));

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => []);
      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal.copyWith(
                title: 'Updated Title',
                priority: Priority.high,
                deadline: newDeadline,
              ));

      // Act
      final result = await service.updateGoal(
        goalId: goalId,
        title: 'Updated Title',
        priority: Priority.high,
        deadline: newDeadline,
      );

      // Assert
      expect(result.title, 'Updated Title');
      expect(result.priority, Priority.high);
    });

    test('should throw NotFoundException for non-existent goal', () async {
      // Arrange
      when(mockGoalRepository.getGoalById(any))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => service.updateGoal(
          goalId: 'non-existent',
          title: 'New Title',
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('should throw BusinessException when updating completed goal', () async {
      // Arrange
      const goalId = 'goal-123';
      final completedGoal = createTestGoal(
        id: goalId,
        status: GoalStatus.completed,
      );

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => completedGoal);

      // Act & Assert
      expect(
        () => service.updateGoal(
          goalId: goalId,
          title: 'New Title',
        ),
        throwsA(isA<BusinessException>()),
      );
    });

    test('should throw ValidationException for deadline in past', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId);
      final pastDeadline = DateTime.now().subtract(const Duration(days: 1));

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);

      // Act & Assert
      expect(
        () => service.updateGoal(
          goalId: goalId,
          deadline: pastDeadline,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException when deadline is before plan start date', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId);
      final plan = createTestPlan(
        goalId: goalId,
        startDate: DateTime.now().add(const Duration(days: 10)),
      );
      final earlierDeadline = DateTime.now().add(const Duration(days: 5));

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => [plan]);

      // Act & Assert
      expect(
        () => service.updateGoal(
          goalId: goalId,
          deadline: earlierDeadline,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('GoalManagementService - archiveGoal', () {
    test('should successfully archive goal without active plans', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId);
      final completedPlan = createTestPlan(
        goalId: goalId,
        status: PlanStatus.completed,
      );

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => [completedPlan]);
      when(mockGoalRepository.deleteGoal(goalId))
          .thenAnswer((_) async => true);

      // Act
      final result = await service.archiveGoal(goalId);

      // Assert
      expect(result, true);
      verify(mockGoalRepository.deleteGoal(goalId)).called(1);
    });

    test('should throw NotFoundException for non-existent goal', () async {
      // Arrange
      when(mockGoalRepository.getGoalById(any))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => service.archiveGoal('non-existent'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('should throw BusinessException when goal is already deleted', () async {
      // Arrange
      const goalId = 'goal-123';
      final deletedGoal = createTestGoal(
        id: goalId,
        status: GoalStatus.deleted,
        deletedAt: DateTime.now(),
      );

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => deletedGoal);

      // Act & Assert
      expect(
        () => service.archiveGoal(goalId),
        throwsA(isA<BusinessException>()),
      );
    });

    test('should throw BusinessException when goal has active plans', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId);
      final activePlan = createTestPlan(
        goalId: goalId,
        status: PlanStatus.active,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 29)),
      );

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => [activePlan]);

      // Act & Assert
      expect(
        () => service.archiveGoal(goalId),
        throwsA(isA<BusinessException>()),
      );
    });
  });

  group('GoalManagementService - deleteGoal', () {
    test('should successfully delete goal and all associated plans', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId);
      final plan1 = createTestPlan(id: 'plan-1', goalId: goalId);
      final plan2 = createTestPlan(id: 'plan-2', goalId: goalId);

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => [plan1, plan2]);
      when(mockPlanRepository.deletePlan(any))
          .thenAnswer((_) async => true);
      when(mockGoalRepository.deleteGoal(goalId))
          .thenAnswer((_) async => true);

      // Act
      final result = await service.deleteGoal(goalId);

      // Assert
      expect(result, true);
      verify(mockPlanRepository.deletePlan('plan-1')).called(1);
      verify(mockPlanRepository.deletePlan('plan-2')).called(1);
      verify(mockGoalRepository.deleteGoal(goalId)).called(1);
    });

    test('should throw NotFoundException for non-existent goal', () async {
      // Arrange
      when(mockGoalRepository.getGoalById(any))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => service.deleteGoal('non-existent'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('GoalManagementService - calculateGoalProgress', () {
    test('should calculate progress correctly with completed tasks', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(
        id: goalId,
        deadline: DateTime.now().add(const Duration(days: 30)),
      );
      final plan = createTestPlan(goalId: goalId);
      final completedTask = createTestTask(status: TaskStatus.completed);
      final activeTask = createTestTask(id: 'task-2', status: TaskStatus.active);

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => [plan]);
      when(mockTaskRepository.getPlanTasks(plan.id))
          .thenAnswer((_) async => [completedTask, activeTask]);

      // Act
      final stats = await service.calculateGoalProgress(goalId);

      // Assert
      expect(stats.totalPlans, 1);
      expect(stats.totalTasks, 2);
      expect(stats.completedTasks, 1);
      expect(stats.overallProgress, 0.5);
    });

    test('should handle goal with no plans', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId);

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => []);

      // Act
      final stats = await service.calculateGoalProgress(goalId);

      // Assert
      expect(stats.totalPlans, 0);
      expect(stats.totalTasks, 0);
      expect(stats.overallProgress, 0.0);
    });

    test('should throw NotFoundException for non-existent goal', () async {
      // Arrange
      when(mockGoalRepository.getGoalById(any))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => service.calculateGoalProgress('non-existent'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('GoalManagementService - checkGoalAchievement', () {
    test('should mark goal as fully achieved when progress is 100%', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId);
      final plan = createTestPlan(goalId: goalId);
      final completedTask = createTestTask(status: TaskStatus.completed);

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => [plan]);
      when(mockTaskRepository.getPlanTasks(plan.id))
          .thenAnswer((_) async => [completedTask]);
      when(mockGoalRepository.updateGoal(any))
          .thenAnswer((_) async => goal.copyWith(status: GoalStatus.completed));

      // Act
      final result = await service.checkGoalAchievement(goalId);

      // Assert
      expect(result.isAchieved, true);
      expect(result.achievementLevel, 'Fully Achieved');
      verify(mockGoalRepository.updateGoal(any)).called(1);
    });

    test('should return "Mostly Achieved" for 80-99% progress', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId);
      final plan = createTestPlan(goalId: goalId);
      final tasks = [
        createTestTask(id: 'task-1', status: TaskStatus.completed),
        createTestTask(id: 'task-2', status: TaskStatus.completed),
        createTestTask(id: 'task-3', status: TaskStatus.completed),
        createTestTask(id: 'task-4', status: TaskStatus.completed),
        createTestTask(id: 'task-5', status: TaskStatus.active),
      ];

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => [plan]);
      when(mockTaskRepository.getPlanTasks(plan.id))
          .thenAnswer((_) async => tasks);

      // Act
      final result = await service.checkGoalAchievement(goalId);

      // Assert
      expect(result.isAchieved, false);
      expect(result.achievementLevel, 'Mostly Achieved');
    });

    test('should return "Partially Achieved" for 50-79% progress', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId);
      final plan = createTestPlan(goalId: goalId);
      final tasks = [
        createTestTask(id: 'task-1', status: TaskStatus.completed),
        createTestTask(id: 'task-2', status: TaskStatus.active),
      ];

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => [plan]);
      when(mockTaskRepository.getPlanTasks(plan.id))
          .thenAnswer((_) async => tasks);

      // Act
      final result = await service.checkGoalAchievement(goalId);

      // Assert
      expect(result.isAchieved, false);
      expect(result.achievementLevel, 'Partially Achieved');
    });
  });

  group('GoalManagementService - getGoalsApproachingDeadline', () {
    test('should return goals within threshold days', () async {
      // Arrange
      const userId = 'user-123';
      final goal1 = createTestGoal(
        id: 'goal-1',
        title: 'Urgent Goal',
        deadline: DateTime.now().add(const Duration(days: 3)),
      );
      final goal2 = createTestGoal(
        id: 'goal-2',
        title: 'Far Goal',
        deadline: DateTime.now().add(const Duration(days: 15)),
      );

      when(mockGoalRepository.getUserGoals(userId))
          .thenAnswer((_) async => [goal1, goal2]);

      // Act
      final result = await service.getGoalsApproachingDeadline(
        userId: userId,
        daysThreshold: 7,
      );

      // Assert
      expect(result.length, 1);
      expect(result.first.id, 'goal-1');
    });

    test('should exclude completed goals', () async {
      // Arrange
      const userId = 'user-123';
      final goal = createTestGoal(
        deadline: DateTime.now().add(const Duration(days: 3)),
        status: GoalStatus.completed,
      );

      when(mockGoalRepository.getUserGoals(userId))
          .thenAnswer((_) async => [goal]);

      // Act
      final result = await service.getGoalsApproachingDeadline(
        userId: userId,
        daysThreshold: 7,
      );

      // Assert
      expect(result.length, 0);
    });

    test('should exclude deleted goals', () async {
      // Arrange
      const userId = 'user-123';
      final goal = createTestGoal(
        deadline: DateTime.now().add(const Duration(days: 3)),
        deletedAt: DateTime.now(),
      );

      when(mockGoalRepository.getUserGoals(userId))
          .thenAnswer((_) async => [goal]);

      // Act
      final result = await service.getGoalsApproachingDeadline(
        userId: userId,
        daysThreshold: 7,
      );

      // Assert
      expect(result.length, 0);
    });
  });

  group('GoalManagementService - getGoalsByTags', () {
    test('should group goals by tags correctly', () async {
      // Arrange
      const userId = 'user-123';
      final goal1 = createTestGoal(
        id: 'goal-1',
        tags: const ['health', 'fitness'],
      );
      final goal2 = createTestGoal(
        id: 'goal-2',
        tags: const ['health', 'personal'],
      );

      when(mockGoalRepository.getUserGoals(userId))
          .thenAnswer((_) async => [goal1, goal2]);

      // Act
      final result = await service.getGoalsByTags(userId);

      // Assert
      expect(result['health']!.length, 2);
      expect(result['fitness']!.length, 1);
      expect(result['personal']!.length, 1);
    });

    test('should exclude deleted goals', () async {
      // Arrange
      const userId = 'user-123';
      final goal = createTestGoal(
        tags: const ['health'],
        deletedAt: DateTime.now(),
      );

      when(mockGoalRepository.getUserGoals(userId))
          .thenAnswer((_) async => [goal]);

      // Act
      final result = await service.getGoalsByTags(userId);

      // Assert
      expect(result.isEmpty, true);
    });
  });

  group('GoalManagementService - completeGoal', () {
    test('should successfully complete goal with active tasks in current window', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId, status: GoalStatus.active);
      final completedGoal = createTestGoal(id: goalId, status: GoalStatus.completed);
      final plan1 = createTestPlan(id: 'plan-1', goalId: goalId, status: PlanStatus.active);
      final plan2 = createTestPlan(id: 'plan-2', goalId: goalId, status: PlanStatus.active);

      final now = DateTime.now();
      final activeTaskInWindow = TaskModel(
        id: 'task-1',
        userId: 'user-123',
        planId: 'plan-1',
        name: 'Active Task',
        config: const TaskConfiguration(),
        windowStartTime: now.subtract(const Duration(hours: 1)),
        windowEndTime: now.add(const Duration(hours: 23)),
        status: TaskStatus.active,
        createdAt: now,
      );

      final completedTask = createTestTask(
        id: 'task-2',
        planId: 'plan-1',
        status: TaskStatus.completed,
      );

      // Setup sequential responses using a call counter
      var getGoalCallCount = 0;
      when(mockGoalRepository.getGoalById(goalId)).thenAnswer((_) async {
        getGoalCallCount++;
        return getGoalCallCount == 1 ? goal : completedGoal;
      });
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => [plan1, plan2]);
      when(mockTaskRepository.getPlanTasks('plan-1'))
          .thenAnswer((_) async => [activeTaskInWindow, completedTask]);
      when(mockTaskRepository.getPlanTasks('plan-2'))
          .thenAnswer((_) async => []);

      // Act
      final result = await service.completeGoal(goalId);

      // Assert
      expect(result.status, GoalStatus.completed);
      verify(mockGoalRepository.getGoalById(goalId)).called(2);
      verify(mockPlanRepository.getGoalPlans(goalId)).called(1);
      verify(mockTaskRepository.getPlanTasks('plan-1')).called(1);
      verify(mockTaskRepository.getPlanTasks('plan-2')).called(1);
    });

    test('should throw NotFoundException if goal does not exist', () async {
      // Arrange
      const goalId = 'non-existent';
      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => service.completeGoal(goalId),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('should throw BusinessException if goal is already completed', () async {
      // Arrange
      const goalId = 'goal-123';
      final completedGoal = createTestGoal(
        id: goalId,
        status: GoalStatus.completed,
      );

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => completedGoal);

      // Act & Assert
      expect(
        () => service.completeGoal(goalId),
        throwsA(isA<BusinessException>()),
      );
    });

    test('should throw BusinessException if goal is deleted', () async {
      // Arrange
      const goalId = 'goal-123';
      final deletedGoal = createTestGoal(
        id: goalId,
        status: GoalStatus.deleted,
      );

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => deletedGoal);

      // Act & Assert
      expect(
        () => service.completeGoal(goalId),
        throwsA(isA<BusinessException>()),
      );
    });

    test('should complete goal with no plans', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId, status: GoalStatus.active);
      final completedGoal = createTestGoal(id: goalId, status: GoalStatus.completed);

      // Setup sequential responses using a call counter
      var getGoalCallCount = 0;
      when(mockGoalRepository.getGoalById(goalId)).thenAnswer((_) async {
        getGoalCallCount++;
        return getGoalCallCount == 1 ? goal : completedGoal;
      });
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => []);

      // Act
      final result = await service.completeGoal(goalId);

      // Assert
      expect(result.status, GoalStatus.completed);
      verify(mockPlanRepository.getGoalPlans(goalId)).called(1);
    });

    test('should skip only active tasks in current execution window', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId, status: GoalStatus.active);
      final completedGoal = createTestGoal(id: goalId, status: GoalStatus.completed);
      final plan = createTestPlan(goalId: goalId, status: PlanStatus.active);

      final now = DateTime.now();

      // Active task in current window - should be skipped
      final activeTaskInWindow = TaskModel(
        id: 'task-1',
        userId: 'user-123',
        planId: plan.id,
        name: 'Active Task In Window',
        config: const TaskConfiguration(),
        windowStartTime: now.subtract(const Duration(hours: 1)),
        windowEndTime: now.add(const Duration(hours: 23)),
        status: TaskStatus.active,
        createdAt: now,
      );

      // Active task outside current window - should NOT be skipped
      final activeTaskOutsideWindow = TaskModel(
        id: 'task-2',
        userId: 'user-123',
        planId: plan.id,
        name: 'Active Task Outside Window',
        config: const TaskConfiguration(),
        windowStartTime: now.add(const Duration(days: 1)),
        windowEndTime: now.add(const Duration(days: 2)),
        status: TaskStatus.active,
        createdAt: now,
      );

      // Completed task - should NOT be skipped
      final completedTask = createTestTask(
        id: 'task-3',
        planId: plan.id,
        status: TaskStatus.completed,
      );

      // Setup sequential responses using a call counter
      var getGoalCallCount = 0;
      when(mockGoalRepository.getGoalById(goalId)).thenAnswer((_) async {
        getGoalCallCount++;
        return getGoalCallCount == 1 ? goal : completedGoal;
      });
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => [plan]);
      when(mockTaskRepository.getPlanTasks(plan.id))
          .thenAnswer((_) async => [activeTaskInWindow, activeTaskOutsideWindow, completedTask]);

      // Act
      final result = await service.completeGoal(goalId);

      // Assert
      expect(result.status, GoalStatus.completed);
      // Verify only one task (activeTaskInWindow) was considered for skipping
      verify(mockTaskRepository.getPlanTasks(plan.id)).called(1);
    });

    test('should not update deleted plans when completing goal', () async {
      // Arrange
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId, status: GoalStatus.active);
      final completedGoal = createTestGoal(id: goalId, status: GoalStatus.completed);
      final activePlan = createTestPlan(
        id: 'plan-1',
        goalId: goalId,
        status: PlanStatus.active,
      );
      final deletedPlan = createTestPlan(
        id: 'plan-2',
        goalId: goalId,
        status: PlanStatus.deleted,
      );

      // Setup sequential responses using a call counter
      var getGoalCallCount = 0;
      when(mockGoalRepository.getGoalById(goalId)).thenAnswer((_) async {
        getGoalCallCount++;
        return getGoalCallCount == 1 ? goal : completedGoal;
      });
      when(mockPlanRepository.getGoalPlans(goalId))
          .thenAnswer((_) async => [activePlan, deletedPlan]);
      when(mockTaskRepository.getPlanTasks('plan-1'))
          .thenAnswer((_) async => []);
      when(mockTaskRepository.getPlanTasks('plan-2'))
          .thenAnswer((_) async => []);

      // Act
      final result = await service.completeGoal(goalId);

      // Assert
      expect(result.status, GoalStatus.completed);
      // Both plans should be queried for tasks
      verify(mockTaskRepository.getPlanTasks('plan-1')).called(1);
      verify(mockTaskRepository.getPlanTasks('plan-2')).called(1);
    });
  });
}
