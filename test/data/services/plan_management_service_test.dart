import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:myassistant/data/services/plan_management_service.dart';
import 'package:myassistant/data/services/task_generation_service.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/domain/repositories/i_goal_repository.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/core/errors/exceptions.dart';

import 'plan_management_service_test.mocks.dart';

@GenerateMocks([IPlanRepository, IGoalRepository, ITaskRepository, TaskGenerationService])
void main() {
  late PlanManagementService service;
  late MockIPlanRepository mockPlanRepository;
  late MockIGoalRepository mockGoalRepository;
  late MockITaskRepository mockTaskRepository;
  late MockTaskGenerationService mockGenerationService;

  setUp(() {
    mockPlanRepository = MockIPlanRepository();
    mockGoalRepository = MockIGoalRepository();
    mockTaskRepository = MockITaskRepository();
    mockGenerationService = MockTaskGenerationService();
    service = PlanManagementService(
      planRepository: mockPlanRepository,
      goalRepository: mockGoalRepository,
      taskRepository: mockTaskRepository,
      generationService: mockGenerationService,
    );
  });

  // Helper function to create a test goal
  GoalModel createTestGoal({
    String id = 'goal-123',
    String userId = 'user-123',
    String title = 'Test Goal',
  }) {
    final now = DateTime.now();
    return GoalModel(
      id: id,
      userId: userId,
      title: title,
      tags: const [],
      createdAt: now,
      updatedAt: now,
      priority: Priority.medium,
      status: GoalStatus.active,
      planIds: const [],
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
    DateTime? deletedAt,
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
      deletedAt: deletedAt,
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

  group('PlanManagementService - createPlan', () {
    test('should successfully create a plan with valid input', () async {
      // Arrange
      const userId = 'user-123';
      const goalId = 'goal-123';
      const name = 'New Plan';
      final goal = createTestGoal(id: goalId, userId: userId);
      final plan = createTestPlan(name: name, goalId: goalId);
      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(days: 30));

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getActivePlans(userId))
          .thenAnswer((_) async => []);
      when(mockPlanRepository.createPlan(
        userId: anyNamed('userId'),
        goalId: anyNamed('goalId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        startDate: anyNamed('startDate'),
        endDate: anyNamed('endDate'),
        repeatRule: anyNamed('repeatRule'),
        taskConfig: anyNamed('taskConfig'),
      )).thenAnswer((_) async => plan);
      when(mockGoalRepository.addPlanToGoal(goalId, plan.id))
          .thenAnswer((_) async => true);
      when(mockGenerationService.generateNextTask(any))
          .thenAnswer((_) async => createTestTask());

      // Act
      final result = await service.createPlan(
        userId: userId,
        goalId: goalId,
        name: name,
        startDate: startDate,
        endDate: endDate,
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(durationMinutes: 30),
      );

      // Assert
      expect(result.name, name);
      verify(mockGoalRepository.getGoalById(goalId)).called(1);
      verify(mockPlanRepository.createPlan(
        userId: anyNamed('userId'),
        goalId: anyNamed('goalId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        startDate: anyNamed('startDate'),
        endDate: anyNamed('endDate'),
        repeatRule: anyNamed('repeatRule'),
        taskConfig: anyNamed('taskConfig'),
      )).called(1);
      verify(mockGoalRepository.addPlanToGoal(goalId, plan.id)).called(1);
    });

    test('should throw NotFoundException when goal does not exist', () async {
      // Arrange
      when(mockGoalRepository.getGoalById(any))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => service.createPlan(
          userId: 'user-123',
          goalId: 'non-existent',
          name: 'Test Plan',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          repeatRule: const RepeatRule(type: RepeatType.daily),
          taskConfig: const TaskConfiguration(),
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('should throw PermissionException when user does not own goal', () async {
      // Arrange
      const userId = 'user-123';
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId, userId: 'other-user');

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);

      // Act & Assert
      expect(
        () => service.createPlan(
          userId: userId,
          goalId: goalId,
          name: 'Test Plan',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          repeatRule: const RepeatRule(type: RepeatType.daily),
          taskConfig: const TaskConfiguration(),
        ),
        throwsA(isA<PermissionException>()),
      );
    });

    test('should throw ValidationException for duplicate plan name', () async {
      // Arrange
      const userId = 'user-123';
      const goalId = 'goal-123';
      const name = 'Duplicate Plan';
      final goal = createTestGoal(id: goalId, userId: userId);
      final existingPlan = createTestPlan(name: name);

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getActivePlans(userId))
          .thenAnswer((_) async => [existingPlan]);

      // Act & Assert
      expect(
        () => service.createPlan(
          userId: userId,
          goalId: goalId,
          name: name,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          repeatRule: const RepeatRule(type: RepeatType.daily),
          taskConfig: const TaskConfiguration(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for empty plan name', () async {
      // Arrange
      const userId = 'user-123';
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId, userId: userId);

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getActivePlans(userId))
          .thenAnswer((_) async => []);

      // Act & Assert
      expect(
        () => service.createPlan(
          userId: userId,
          goalId: goalId,
          name: '',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          repeatRule: const RepeatRule(type: RepeatType.daily),
          taskConfig: const TaskConfiguration(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for plan name too long', () async {
      // Arrange
      const userId = 'user-123';
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId, userId: userId);
      final longName = 'a' * 101;

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getActivePlans(userId))
          .thenAnswer((_) async => []);

      // Act & Assert
      expect(
        () => service.createPlan(
          userId: userId,
          goalId: goalId,
          name: longName,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          repeatRule: const RepeatRule(type: RepeatType.daily),
          taskConfig: const TaskConfiguration(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException when endDate is before startDate', () async {
      // Arrange
      const userId = 'user-123';
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId, userId: userId);
      final startDate = DateTime.now();
      final endDate = startDate.subtract(const Duration(days: 1));

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getActivePlans(userId))
          .thenAnswer((_) async => []);

      // Act & Assert
      expect(
        () => service.createPlan(
          userId: userId,
          goalId: goalId,
          name: 'Test Plan',
          startDate: startDate,
          endDate: endDate,
          repeatRule: const RepeatRule(type: RepeatType.daily),
          taskConfig: const TaskConfiguration(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for invalid repeat rule', () async {
      // Arrange
      const userId = 'user-123';
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId, userId: userId);

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getActivePlans(userId))
          .thenAnswer((_) async => []);

      // Act & Assert
      expect(
        () => service.createPlan(
          userId: userId,
          goalId: goalId,
          name: 'Test Plan',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          repeatRule: const RepeatRule(type: RepeatType.custom), // Invalid: no customDays
          taskConfig: const TaskConfiguration(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for invalid task configuration', () async {
      // Arrange
      const userId = 'user-123';
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId, userId: userId);

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getActivePlans(userId))
          .thenAnswer((_) async => []);

      // Act & Assert
      expect(
        () => service.createPlan(
          userId: userId,
          goalId: goalId,
          name: 'Test Plan',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          repeatRule: const RepeatRule(type: RepeatType.daily),
          taskConfig: const TaskConfiguration(
            durationMinutes: -10, // Invalid: negative duration
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for timer duration too long', () async {
      // Arrange
      const userId = 'user-123';
      const goalId = 'goal-123';
      final goal = createTestGoal(id: goalId, userId: userId);

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getActivePlans(userId))
          .thenAnswer((_) async => []);

      // Act & Assert
      expect(
        () => service.createPlan(
          userId: userId,
          goalId: goalId,
          name: 'Test Plan',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          repeatRule: const RepeatRule(type: RepeatType.daily),
          taskConfig: const TaskConfiguration(
            durationMinutes: 250, // Invalid: > 240 minutes (4 hours)
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should generate first task for active plan', () async {
      // Arrange
      const userId = 'user-123';
      const goalId = 'goal-123';
      const name = 'Active Plan';
      final goal = createTestGoal(id: goalId, userId: userId);
      final now = DateTime.now();
      final activePlan = createTestPlan(
        name: name,
        goalId: goalId,
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 29)),
        status: PlanStatus.active,
      );

      when(mockGoalRepository.getGoalById(goalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getActivePlans(userId))
          .thenAnswer((_) async => []);
      when(mockPlanRepository.createPlan(
        userId: anyNamed('userId'),
        goalId: anyNamed('goalId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        startDate: anyNamed('startDate'),
        endDate: anyNamed('endDate'),
        repeatRule: anyNamed('repeatRule'),
        taskConfig: anyNamed('taskConfig'),
      )).thenAnswer((_) async => activePlan);
      when(mockGoalRepository.addPlanToGoal(goalId, activePlan.id))
          .thenAnswer((_) async => true);
      when(mockGenerationService.generateNextTask(any))
          .thenAnswer((_) async => createTestTask());

      // Act
      await service.createPlan(
        userId: userId,
        goalId: goalId,
        name: name,
        startDate: activePlan.startDate,
        endDate: activePlan.endDate,
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(durationMinutes: 30),
      );

      // Assert
      verify(mockGenerationService.generateNextTask(any)).called(1);
    });
  });

  group('PlanManagementService - updatePlan', () {
    test('should successfully update plan description', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);
      final updatedPlan = plan.copyWith(description: 'Updated description');

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);
      when(mockPlanRepository.updatePlan(any))
          .thenAnswer((_) async => updatedPlan);

      // Act
      final result = await service.updatePlan(
        planId: planId,
        description: 'Updated description',
      );

      // Assert
      expect(result.description, 'Updated description');
      verify(mockPlanRepository.updatePlan(any)).called(1);
    });

    test('should throw NotFoundException for non-existent plan', () async {
      // Arrange
      when(mockPlanRepository.getPlanById(any))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => service.updatePlan(
          planId: 'non-existent',
          description: 'Test',
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('should throw BusinessException when updating deleted plan', () async {
      // Arrange
      const planId = 'plan-123';
      final deletedPlan = createTestPlan(
        id: planId,
        status: PlanStatus.deleted,
        deletedAt: DateTime.now(),
      );

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => deletedPlan);

      // Act & Assert
      expect(
        () => service.updatePlan(
          planId: planId,
          description: 'Test',
        ),
        throwsA(isA<BusinessException>()),
      );
    });

    test('should throw ValidationException when endDate is before startDate', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(
        id: planId,
        startDate: DateTime.now(),
      );
      final earlierDate = plan.startDate.subtract(const Duration(days: 1));

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);

      // Act & Assert
      expect(
        () => service.updatePlan(
          planId: planId,
          endDate: earlierDate,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException when endDate is in the past', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);
      final pastDate = DateTime.now().subtract(const Duration(days: 1));

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);

      // Act & Assert
      expect(
        () => service.updatePlan(
          planId: planId,
          endDate: pastDate,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for invalid task configuration', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);

      // Act & Assert
      expect(
        () => service.updatePlan(
          planId: planId,
          taskConfig: const TaskConfiguration(
            durationMinutes: -5, // Invalid
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should successfully update repeatRule from weekly to daily', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);
      final updatedPlan = plan.copyWith(
        repeatRule: const RepeatRule(type: RepeatType.daily),
      );

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);
      when(mockPlanRepository.updatePlan(any))
          .thenAnswer((_) async => updatedPlan);

      // Act
      final result = await service.updatePlan(
        planId: planId,
        repeatRule: const RepeatRule(type: RepeatType.daily),
      );

      // Assert
      expect(result.repeatRule.type, RepeatType.daily);
      verify(mockPlanRepository.updatePlan(any)).called(1);
    });

    test('should successfully update repeatRule to custom with customDays', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);
      const newRepeatRule = RepeatRule(type: RepeatType.custom, customDays: 10);
      final updatedPlan = plan.copyWith(repeatRule: newRepeatRule);

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);
      when(mockPlanRepository.updatePlan(any))
          .thenAnswer((_) async => updatedPlan);

      // Act
      final result = await service.updatePlan(
        planId: planId,
        repeatRule: newRepeatRule,
      );

      // Assert
      expect(result.repeatRule.type, RepeatType.custom);
      expect(result.repeatRule.customDays, 10);
      verify(mockPlanRepository.updatePlan(any)).called(1);
    });

    test('should successfully update repeatRule to daysOfWeek with selectedDaysOfWeek', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);
      const newRepeatRule = RepeatRule(
        type: RepeatType.daysOfWeek,
        selectedDaysOfWeek: [1, 3, 5], // Monday, Wednesday, Friday
      );
      final updatedPlan = plan.copyWith(repeatRule: newRepeatRule);

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);
      when(mockPlanRepository.updatePlan(any))
          .thenAnswer((_) async => updatedPlan);

      // Act
      final result = await service.updatePlan(
        planId: planId,
        repeatRule: newRepeatRule,
      );

      // Assert
      expect(result.repeatRule.type, RepeatType.daysOfWeek);
      expect(result.repeatRule.selectedDaysOfWeek, [1, 3, 5]);
      verify(mockPlanRepository.updatePlan(any)).called(1);
    });

    test('should throw ValidationException for invalid repeatRule (custom without customDays)', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);

      // Act & Assert
      expect(
        () => service.updatePlan(
          planId: planId,
          repeatRule: const RepeatRule(type: RepeatType.custom), // Invalid: no customDays
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for invalid daysOfWeek (empty selectedDaysOfWeek)', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);

      // Act & Assert
      expect(
        () => service.updatePlan(
          planId: planId,
          repeatRule: const RepeatRule(type: RepeatType.daysOfWeek), // Invalid: empty days
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw ValidationException for invalid daysOfWeek (out-of-range days)', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);

      // Act & Assert
      expect(
        () => service.updatePlan(
          planId: planId,
          repeatRule: const RepeatRule(
            type: RepeatType.daysOfWeek,
            selectedDaysOfWeek: [0, 8], // Invalid: must be 1-7
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should update repeatRule combined with other fields', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);
      const newRepeatRule = RepeatRule(type: RepeatType.daily);
      final newEndDate = plan.endDate.add(const Duration(days: 10));
      final updatedPlan = plan.copyWith(
        description: 'Updated description',
        endDate: newEndDate,
        repeatRule: newRepeatRule,
      );

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);
      when(mockPlanRepository.updatePlan(any))
          .thenAnswer((_) async => updatedPlan);

      // Act
      final result = await service.updatePlan(
        planId: planId,
        description: 'Updated description',
        endDate: newEndDate,
        repeatRule: newRepeatRule,
      );

      // Assert
      expect(result.description, 'Updated description');
      expect(result.endDate, newEndDate);
      expect(result.repeatRule.type, RepeatType.daily);
      verify(mockPlanRepository.updatePlan(any)).called(1);
    });
  });

  group('PlanManagementService - deletePlan', () {
    test('should successfully delete plan and associated tasks', () async {
      // Arrange
      const planId = 'plan-123';
      const goalId = 'goal-123';
      final plan = createTestPlan(id: planId, goalId: goalId);

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);
      when(mockTaskRepository.deletePlanTasks(planId))
          .thenAnswer((_) async => true);
      when(mockPlanRepository.deletePlan(planId))
          .thenAnswer((_) async => true);
      when(mockGoalRepository.removePlanFromGoal(goalId, planId))
          .thenAnswer((_) async => true);

      // Act
      final result = await service.deletePlan(planId);

      // Assert
      expect(result, true);
      verify(mockTaskRepository.deletePlanTasks(planId)).called(1);
      verify(mockPlanRepository.deletePlan(planId)).called(1);
      verify(mockGoalRepository.removePlanFromGoal(goalId, planId)).called(1);
    });

    test('should throw NotFoundException for non-existent plan', () async {
      // Arrange
      when(mockPlanRepository.getPlanById(any))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => service.deletePlan('non-existent'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('should throw BusinessException when plan is already deleted', () async {
      // Arrange
      const planId = 'plan-123';
      final deletedPlan = createTestPlan(
        id: planId,
        status: PlanStatus.deleted,
        deletedAt: DateTime.now(),
      );

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => deletedPlan);

      // Act & Assert
      expect(
        () => service.deletePlan(planId),
        throwsA(isA<BusinessException>()),
      );
    });
  });

  group('PlanManagementService - calculatePlanStatistics', () {
    test('should calculate statistics correctly', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(
        id: planId,
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 20)),
      );
      final tasks = [
        createTestTask(id: 'task-1', status: TaskStatus.completed),
        createTestTask(id: 'task-2', status: TaskStatus.completed),
        createTestTask(id: 'task-3', status: TaskStatus.active),
        createTestTask(id: 'task-4', status: TaskStatus.skipped),
      ];

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);
      when(mockTaskRepository.getPlanTasks(planId))
          .thenAnswer((_) async => tasks);

      // Act
      final stats = await service.calculatePlanStatistics(planId);

      // Assert
      expect(stats.totalTasks, 4);
      expect(stats.completedTasks, 2);
      expect(stats.activeTasks, 1);
      expect(stats.skippedTasks, 1);
      expect(stats.completionRate, 0.5);
      expect(stats.daysRemaining, greaterThanOrEqualTo(19));
    });

    test('should handle plan with no tasks', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(id: planId);

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);
      when(mockTaskRepository.getPlanTasks(planId))
          .thenAnswer((_) async => []);

      // Act
      final stats = await service.calculatePlanStatistics(planId);

      // Assert
      expect(stats.totalTasks, 0);
      expect(stats.completionRate, 0.0);
    });

    test('should throw NotFoundException for non-existent plan', () async {
      // Arrange
      when(mockPlanRepository.getPlanById(any))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => service.calculatePlanStatistics('non-existent'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('PlanManagementService - extendPlan', () {
    test('should successfully extend plan end date', () async {
      // Arrange
      const planId = 'plan-123';
      final plan = createTestPlan(
        id: planId,
        endDate: DateTime.now().add(const Duration(days: 30)),
      );
      final extendedPlan = plan.copyWith(
        endDate: plan.endDate.add(const Duration(days: 7)),
      );

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => plan);
      when(mockPlanRepository.updatePlan(any))
          .thenAnswer((_) async => extendedPlan);

      // Act
      final result = await service.extendPlan(
        planId: planId,
        additionalDays: 7,
      );

      // Assert
      expect(result.endDate.isAfter(plan.endDate), true);
    });

    test('should throw ValidationException for non-positive additional days', () async {
      // Act & Assert
      expect(
        () => service.extendPlan(
          planId: 'plan-123',
          additionalDays: 0,
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => service.extendPlan(
          planId: 'plan-123',
          additionalDays: -5,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should throw BusinessException when extending deleted plan', () async {
      // Arrange
      const planId = 'plan-123';
      final deletedPlan = createTestPlan(
        id: planId,
        status: PlanStatus.deleted,
        deletedAt: DateTime.now(),
      );

      when(mockPlanRepository.getPlanById(planId))
          .thenAnswer((_) async => deletedPlan);

      // Act & Assert
      expect(
        () => service.extendPlan(
          planId: planId,
          additionalDays: 7,
        ),
        throwsA(isA<BusinessException>()),
      );
    });
  });

  group('PlanManagementService - clonePlan', () {
    test('should successfully clone a plan', () async {
      // Arrange
      const originalPlanId = 'plan-123';
      const newGoalId = 'goal-456';
      final originalPlan = createTestPlan(id: originalPlanId);
      final goal = createTestGoal(id: newGoalId, userId: originalPlan.userId);
      final clonedPlan = createTestPlan(
        id: 'plan-456',
        name: '${originalPlan.name} (Copy)',
        goalId: newGoalId,
      );

      when(mockPlanRepository.getPlanById(originalPlanId))
          .thenAnswer((_) async => originalPlan);
      when(mockGoalRepository.getGoalById(newGoalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepository.getActivePlans(originalPlan.userId))
          .thenAnswer((_) async => []);
      when(mockPlanRepository.createPlan(
        userId: anyNamed('userId'),
        goalId: anyNamed('goalId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        startDate: anyNamed('startDate'),
        endDate: anyNamed('endDate'),
        repeatRule: anyNamed('repeatRule'),
        taskConfig: anyNamed('taskConfig'),
      )).thenAnswer((_) async => clonedPlan);
      when(mockGoalRepository.addPlanToGoal(newGoalId, clonedPlan.id))
          .thenAnswer((_) async => true);
      when(mockGenerationService.generateNextTask(any))
          .thenAnswer((_) async => createTestTask());

      // Act
      final result = await service.clonePlan(
        originalPlanId: originalPlanId,
        newGoalId: newGoalId,
      );

      // Assert
      expect(result.name, contains('(Copy)'));
      expect(result.goalId, newGoalId);
    });

    test('should throw NotFoundException when original plan not found', () async {
      // Arrange
      when(mockPlanRepository.getPlanById(any))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => service.clonePlan(
          originalPlanId: 'non-existent',
          newGoalId: 'goal-123',
        ),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('PlanManagementService - getPlansByTaskType', () {
    test('should filter plans by task type correctly', () async {
      // Arrange
      const userId = 'user-123';
      final timerPlan = createTestPlan(
        id: 'plan-1',
        name: 'Timer Plan',
      );
      final counterPlan = createTestPlan(
        id: 'plan-2',
        name: 'Counter Plan',
      ).copyWith(
        taskConfig: const TaskConfiguration(repeatCount: 10),
      );

      when(mockPlanRepository.getActivePlans(userId))
          .thenAnswer((_) async => [timerPlan, counterPlan]);

      // Act
      final timerPlans = await service.getPlansByTaskType(
        userId: userId,
        taskType: TaskType.timer,
      );
      final counterPlans = await service.getPlansByTaskType(
        userId: userId,
        taskType: TaskType.counter,
      );

      // Assert
      expect(timerPlans.length, 1);
      expect(timerPlans.first.id, 'plan-1');
      expect(counterPlans.length, 1);
      expect(counterPlans.first.id, 'plan-2');
    });
  });
}
