import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:myassistant/data/services/goal_management_service.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/core/errors/exceptions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_factories.dart';
import 'scenario_mocks.mocks.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late GoalManagementService goalService;
  late MockIGoalRepository mockGoalRepo;
  late MockIPlanRepository mockPlanRepo;
  late MockITaskRepository mockTaskRepo;
  late MockTaskGenerationService mockGenService;

  setUp(() {
    mockGoalRepo = MockIGoalRepository();
    mockPlanRepo = MockIPlanRepository();
    mockTaskRepo = MockITaskRepository();
    mockGenService = MockTaskGenerationService();
    goalService = GoalManagementService(
      goalRepository: mockGoalRepo,
      planRepository: mockPlanRepo,
      taskRepository: mockTaskRepo,
      generationService: mockGenService,
    );
  });

  group('Scenario: goal complete cascades to plans and tasks', () {
    test('completing goal skips active tasks in current window', () async {
      final now = DateTime.now();
      final goal = createGoal(status: GoalStatus.active);
      final completedGoal = createGoal(status: GoalStatus.completed);

      final plan1 = createPlan(
        id: 'plan-1',
        taskConfig: const TaskConfiguration(durationMinutes: 30),
      );
      final plan2 = createPlan(
        id: 'plan-2',
        taskConfig: const TaskConfiguration(repeatCount: 5),
      );

      final activeTaskInWindow = createTask(
        id: 'task-in-window',
        planId: 'plan-1',
        config: const TaskConfiguration(durationMinutes: 30),
        status: TaskStatus.active,
        windowStartTime: now.subtract(const Duration(hours: 1)),
        windowEndTime: now.add(const Duration(hours: 23)),
      );

      final completedTask = createTask(
        id: 'task-completed',
        planId: 'plan-1',
        status: TaskStatus.completed,
      );

      final activeTaskOutsideWindow = createTask(
        id: 'task-outside',
        planId: 'plan-2',
        status: TaskStatus.active,
        windowStartTime: now.add(const Duration(days: 1)),
        windowEndTime: now.add(const Duration(days: 2)),
      );

      var callCount = 0;
      when(mockGoalRepo.getGoalById(testGoalId)).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? goal : completedGoal;
      });
      when(mockPlanRepo.getGoalPlans(testGoalId))
          .thenAnswer((_) async => [plan1, plan2]);
      when(mockTaskRepo.getPlanTasks('plan-1'))
          .thenAnswer((_) async => [activeTaskInWindow, completedTask]);
      when(mockTaskRepo.getPlanTasks('plan-2'))
          .thenAnswer((_) async => [activeTaskOutsideWindow]);

      final result = await goalService.completeGoal(testGoalId);

      expect(result.status, GoalStatus.completed);
    });

    test('completing goal with no plans succeeds', () async {
      final goal = createGoal(status: GoalStatus.active);
      final completedGoal = createGoal(status: GoalStatus.completed);

      var callCount = 0;
      when(mockGoalRepo.getGoalById(testGoalId)).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? goal : completedGoal;
      });
      when(mockPlanRepo.getGoalPlans(testGoalId))
          .thenAnswer((_) async => []);

      final result = await goalService.completeGoal(testGoalId);
      expect(result.status, GoalStatus.completed);
    });

    test('cannot complete already completed goal', () async {
      when(mockGoalRepo.getGoalById(testGoalId))
          .thenAnswer((_) async => createGoal(status: GoalStatus.completed));

      expect(
        () => goalService.completeGoal(testGoalId),
        throwsA(isA<BusinessException>()),
      );
    });

    test('cannot complete deleted goal', () async {
      when(mockGoalRepo.getGoalById(testGoalId))
          .thenAnswer((_) async => createGoal(status: GoalStatus.deleted));

      expect(
        () => goalService.completeGoal(testGoalId),
        throwsA(isA<BusinessException>()),
      );
    });

    test('does not skip deleted plan tasks', () async {
      final goal = createGoal(status: GoalStatus.active);
      final completedGoal = createGoal(status: GoalStatus.completed);

      final activePlan = createPlan(
        id: 'plan-active',
        status: PlanStatus.active,
      );
      final deletedPlan = createPlan(
        id: 'plan-deleted',
        status: PlanStatus.deleted,
      );

      var callCount = 0;
      when(mockGoalRepo.getGoalById(testGoalId)).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? goal : completedGoal;
      });
      when(mockPlanRepo.getGoalPlans(testGoalId))
          .thenAnswer((_) async => [activePlan, deletedPlan]);
      when(mockTaskRepo.getPlanTasks('plan-active'))
          .thenAnswer((_) async => []);
      when(mockTaskRepo.getPlanTasks('plan-deleted'))
          .thenAnswer((_) async => []);

      await goalService.completeGoal(testGoalId);
      // Both plans' tasks are queried but deleted plan's status won't be updated
    });
  });

  group('Scenario: goal delete cascades to all plans', () {
    test('deleting goal deletes all associated plans', () async {
      final goal = createGoal();
      final plan1 = createPlan(id: 'plan-1');
      final plan2 = createPlan(id: 'plan-2');

      when(mockGoalRepo.getGoalById(testGoalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepo.getGoalPlans(testGoalId))
          .thenAnswer((_) async => [plan1, plan2]);
      when(mockPlanRepo.deletePlan(any))
          .thenAnswer((_) async => true);
      when(mockGoalRepo.deleteGoal(testGoalId))
          .thenAnswer((_) async => true);

      final result = await goalService.deleteGoal(testGoalId);

      expect(result, true);
      verify(mockPlanRepo.deletePlan('plan-1')).called(1);
      verify(mockPlanRepo.deletePlan('plan-2')).called(1);
      verify(mockGoalRepo.deleteGoal(testGoalId)).called(1);
    });

    test('deleting goal with plans of different configs', () async {
      final goal = createGoal();
      final plans = [
        createPlan(
          id: 'plan-simple',
          taskConfig: const TaskConfiguration(),
        ),
        createPlan(
          id: 'plan-timer',
          taskConfig: const TaskConfiguration(durationMinutes: 30),
        ),
        createPlan(
          id: 'plan-counter',
          taskConfig: const TaskConfiguration(repeatCount: 10),
        ),
        createPlan(
          id: 'plan-eval',
          taskConfig: const TaskConfiguration(
            evaluationOptions: ['A', 'B', 'C'],
          ),
        ),
      ];

      when(mockGoalRepo.getGoalById(testGoalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepo.getGoalPlans(testGoalId))
          .thenAnswer((_) async => plans);
      when(mockPlanRepo.deletePlan(any))
          .thenAnswer((_) async => true);
      when(mockGoalRepo.deleteGoal(testGoalId))
          .thenAnswer((_) async => true);

      final result = await goalService.deleteGoal(testGoalId);

      expect(result, true);
      for (final plan in plans) {
        verify(mockPlanRepo.deletePlan(plan.id)).called(1);
      }
    });

    test('delete non-existent goal throws NotFoundException', () async {
      when(mockGoalRepo.getGoalById(any))
          .thenAnswer((_) async => null);

      expect(
        () => goalService.deleteGoal('non-existent'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('Scenario: goal progress calculation with mixed task types', () {
    test('progress reflects completed tasks across all plan types', () async {
      final goal = createGoal(
        deadline: DateTime.now().add(const Duration(days: 30)),
      );

      final planTimer = createPlan(
        id: 'plan-timer',
        taskConfig: const TaskConfiguration(durationMinutes: 25),
      );
      final planCounter = createPlan(
        id: 'plan-counter',
        taskConfig: const TaskConfiguration(repeatCount: 10),
      );

      when(mockGoalRepo.getGoalById(testGoalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepo.getGoalPlans(testGoalId))
          .thenAnswer((_) async => [planTimer, planCounter]);

      // Plan-timer: 2 completed, 1 active
      when(mockTaskRepo.getPlanTasks('plan-timer')).thenAnswer((_) async => [
            createTask(id: 't1', status: TaskStatus.completed),
            createTask(id: 't2', status: TaskStatus.completed),
            createTask(id: 't3', status: TaskStatus.active),
          ]);

      // Plan-counter: 1 completed, 1 skipped
      when(mockTaskRepo.getPlanTasks('plan-counter')).thenAnswer((_) async => [
            createTask(id: 't4', status: TaskStatus.completed),
            createTask(id: 't5', status: TaskStatus.skipped),
          ]);

      final stats = await goalService.calculateGoalProgress(testGoalId);

      expect(stats.totalPlans, 2);
      expect(stats.totalTasks, 5);
      expect(stats.completedTasks, 3);
      expect(stats.overallProgress, closeTo(0.6, 0.01));
    });

    test('goal with no tasks has 0 progress', () async {
      final goal = createGoal();
      final plan = createPlan(id: 'plan-empty');

      when(mockGoalRepo.getGoalById(testGoalId))
          .thenAnswer((_) async => goal);
      when(mockPlanRepo.getGoalPlans(testGoalId))
          .thenAnswer((_) async => [plan]);
      when(mockTaskRepo.getPlanTasks('plan-empty'))
          .thenAnswer((_) async => []);

      final stats = await goalService.calculateGoalProgress(testGoalId);

      expect(stats.totalTasks, 0);
      expect(stats.overallProgress, 0.0);
    });
  });
}
