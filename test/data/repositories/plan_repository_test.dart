import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:myassistant/data/repositories/plan_repository.dart';
import 'package:myassistant/data/data_sources/local/dao/plan_dao.dart';
import 'package:myassistant/data/data_sources/local/dao/goal_dao.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/domain/repositories/i_goal_repository.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';

import 'plan_repository_test.mocks.dart';

@GenerateMocks([PlanDao, GoalDao, IGoalRepository, ITaskRepository])
void main() {
  late PlanRepository repository;
  late MockPlanDao mockPlanDao;
  late MockGoalDao mockGoalDao;
  late MockIGoalRepository mockGoalRepository;
  late MockITaskRepository mockTaskRepository;

  setUp(() {
    mockPlanDao = MockPlanDao();
    mockGoalDao = MockGoalDao();
    mockGoalRepository = MockIGoalRepository();
    mockTaskRepository = MockITaskRepository();
    repository = PlanRepository(
      planDao: mockPlanDao,
      goalDao: mockGoalDao,
      goalRepository: mockGoalRepository,
      taskRepository: mockTaskRepository,
    );
  });

  // Helper: create a test GoalModel
  GoalModel createTestGoal({
    String id = 'goal-1',
    String userId = 'user-1',
    String title = 'Test Goal',
  }) {
    final now = DateTime.now();
    return GoalModel(
      id: id,
      userId: userId,
      title: title,
      tags: const [],
      priority: Priority.medium,
      status: GoalStatus.active,
      createdAt: now,
      updatedAt: now,
      planIds: const [],
    );
  }

  // Helper: create a test PlanModel
  PlanModel createTestPlan({
    String id = 'plan-1',
    String userId = 'user-1',
    String goalId = 'goal-1',
    String name = 'Test Plan',
    RepeatType repeatType = RepeatType.weekly,
    TaskConfiguration taskConfig = const TaskConfiguration(durationMinutes: 30),
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    return PlanModel(
      id: id,
      userId: userId,
      name: name,
      goalId: goalId,
      startDate: startDate ?? now.subtract(const Duration(days: 30)),
      endDate: endDate ?? now.add(const Duration(days: 30)),
      repeatRule: RepeatRule(type: repeatType),
      taskConfig: taskConfig,
      status: PlanStatus.active,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
    );
  }

  // =========================================================================
  // createPlan
  // =========================================================================
  group('createPlan', () {
    test('should create plan successfully with valid inputs', () async {
      final goal = createTestGoal();
      final now = DateTime.now();
      final startDate = now;
      final endDate = now.add(const Duration(days: 60));
      const repeatRule = RepeatRule(type: RepeatType.weekly);
      const taskConfig = TaskConfiguration(durationMinutes: 30);

      when(mockGoalDao.getGoalById('goal-1')).thenAnswer((_) async => goal);
      when(mockPlanDao.isPlanNameExists('user-1', 'New Plan'))
          .thenAnswer((_) async => false);
      when(mockPlanDao.insertPlan(any)).thenAnswer((inv) async {
        final plan = inv.positionalArguments[0] as PlanModel;
        return plan;
      });
      when(mockGoalRepository.addPlanToGoal(any, any))
          .thenAnswer((_) async => true);

      final result = await repository.createPlan(
        userId: 'user-1',
        goalId: 'goal-1',
        name: 'New Plan',
        startDate: startDate,
        endDate: endDate,
        repeatRule: repeatRule,
        taskConfig: taskConfig,
      );

      expect(result.userId, 'user-1');
      expect(result.goalId, 'goal-1');
      expect(result.name, 'New Plan');
      verify(mockPlanDao.insertPlan(any)).called(1);
      verify(mockGoalRepository.addPlanToGoal('goal-1', any)).called(1);
    });

    test('should throw when goal does not exist', () async {
      final now = DateTime.now();

      when(mockGoalDao.getGoalById('goal-999')).thenAnswer((_) async => null);

      expect(
        () => repository.createPlan(
          userId: 'user-1',
          goalId: 'goal-999',
          name: 'Plan',
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          repeatRule: const RepeatRule(type: RepeatType.weekly),
          taskConfig: const TaskConfiguration(),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Goal not found'),
        )),
      );
    });

    test('should throw when plan name already exists for user', () async {
      final goal = createTestGoal();
      final now = DateTime.now();

      when(mockGoalDao.getGoalById('goal-1')).thenAnswer((_) async => goal);
      when(mockPlanDao.isPlanNameExists('user-1', 'Existing Plan'))
          .thenAnswer((_) async => true);

      expect(
        () => repository.createPlan(
          userId: 'user-1',
          goalId: 'goal-1',
          name: 'Existing Plan',
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          repeatRule: const RepeatRule(type: RepeatType.weekly),
          taskConfig: const TaskConfiguration(),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Plan name already exists'),
        )),
      );
    });

    test('should throw when end date is before start date', () async {
      final goal = createTestGoal();
      final now = DateTime.now();

      when(mockGoalDao.getGoalById('goal-1')).thenAnswer((_) async => goal);
      when(mockPlanDao.isPlanNameExists('user-1', 'Plan'))
          .thenAnswer((_) async => false);

      expect(
        () => repository.createPlan(
          userId: 'user-1',
          goalId: 'goal-1',
          name: 'Plan',
          startDate: now.add(const Duration(days: 30)),
          endDate: now,
          repeatRule: const RepeatRule(type: RepeatType.weekly),
          taskConfig: const TaskConfiguration(),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('End date must be after start date'),
        )),
      );
    });

    test('should throw when repeat rule is invalid', () async {
      final goal = createTestGoal();
      final now = DateTime.now();

      when(mockGoalDao.getGoalById('goal-1')).thenAnswer((_) async => goal);
      when(mockPlanDao.isPlanNameExists('user-1', 'Plan'))
          .thenAnswer((_) async => false);

      // custom repeat type without customDays is invalid
      expect(
        () => repository.createPlan(
          userId: 'user-1',
          goalId: 'goal-1',
          name: 'Plan',
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          repeatRule: const RepeatRule(type: RepeatType.custom),
          taskConfig: const TaskConfiguration(),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid repeat rule'),
        )),
      );
    });

    test('should throw when task configuration is invalid', () async {
      final goal = createTestGoal();
      final now = DateTime.now();

      when(mockGoalDao.getGoalById('goal-1')).thenAnswer((_) async => goal);
      when(mockPlanDao.isPlanNameExists('user-1', 'Plan'))
          .thenAnswer((_) async => false);

      // durationMinutes and evaluationOptions cannot coexist
      expect(
        () => repository.createPlan(
          userId: 'user-1',
          goalId: 'goal-1',
          name: 'Plan',
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          repeatRule: const RepeatRule(type: RepeatType.weekly),
          taskConfig: const TaskConfiguration(
            durationMinutes: 30,
            evaluationOptions: ['Good', 'Bad'],
          ),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid task configuration'),
        )),
      );
    });
  });

  // =========================================================================
  // updatePlan
  // =========================================================================
  group('updatePlan', () {
    test('should update plan successfully without changing name', () async {
      final existingPlan = createTestPlan(name: 'My Plan');
      final updatedPlan = existingPlan.copyWith(
        description: 'Updated description',
      );

      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => existingPlan);
      when(mockPlanDao.updatePlan(any)).thenAnswer((_) async => 1);

      final result = await repository.updatePlan(updatedPlan);

      expect(result.description, 'Updated description');
      expect(result.name, 'My Plan');
      verify(mockPlanDao.updatePlan(any)).called(1);
    });

    test('should throw when plan not found', () async {
      final plan = createTestPlan(id: 'plan-999');

      when(mockPlanDao.getPlanById('plan-999')).thenAnswer((_) async => null);

      expect(
        () => repository.updatePlan(plan),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Plan not found'),
        )),
      );
    });

    test('should throw when name is changed (immutability check)', () async {
      final existingPlan = createTestPlan(name: 'Original Name');
      // Create a plan with a different name by constructing a new PlanModel
      final modifiedPlan = PlanModel(
        id: existingPlan.id,
        userId: existingPlan.userId,
        name: 'Changed Name',
        goalId: existingPlan.goalId,
        startDate: existingPlan.startDate,
        endDate: existingPlan.endDate,
        repeatRule: existingPlan.repeatRule,
        taskConfig: existingPlan.taskConfig,
        status: existingPlan.status,
        createdAt: existingPlan.createdAt,
        updatedAt: existingPlan.updatedAt,
      );

      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => existingPlan);

      expect(
        () => repository.updatePlan(modifiedPlan),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Plan name cannot be changed after creation'),
        )),
      );
    });

    test('should throw when end date is before start date on update', () async {
      final existingPlan = createTestPlan();
      final now = DateTime.now();
      final invalidPlan = PlanModel(
        id: existingPlan.id,
        userId: existingPlan.userId,
        name: existingPlan.name,
        goalId: existingPlan.goalId,
        startDate: now.add(const Duration(days: 30)),
        endDate: now,
        repeatRule: existingPlan.repeatRule,
        taskConfig: existingPlan.taskConfig,
        status: existingPlan.status,
        createdAt: existingPlan.createdAt,
        updatedAt: existingPlan.updatedAt,
      );

      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => existingPlan);

      expect(
        () => repository.updatePlan(invalidPlan),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('End date must be after start date'),
        )),
      );
    });

    test('should throw when repeat rule is invalid on update', () async {
      final existingPlan = createTestPlan();
      final invalidPlan = PlanModel(
        id: existingPlan.id,
        userId: existingPlan.userId,
        name: existingPlan.name,
        goalId: existingPlan.goalId,
        startDate: existingPlan.startDate,
        endDate: existingPlan.endDate,
        repeatRule: const RepeatRule(type: RepeatType.custom), // no customDays
        taskConfig: existingPlan.taskConfig,
        status: existingPlan.status,
        createdAt: existingPlan.createdAt,
        updatedAt: existingPlan.updatedAt,
      );

      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => existingPlan);

      expect(
        () => repository.updatePlan(invalidPlan),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid repeat rule'),
        )),
      );
    });

    test('should throw when task config is invalid on update', () async {
      final existingPlan = createTestPlan();
      final invalidPlan = PlanModel(
        id: existingPlan.id,
        userId: existingPlan.userId,
        name: existingPlan.name,
        goalId: existingPlan.goalId,
        startDate: existingPlan.startDate,
        endDate: existingPlan.endDate,
        repeatRule: existingPlan.repeatRule,
        taskConfig: const TaskConfiguration(
          durationMinutes: 30,
          evaluationOptions: ['A', 'B'],
        ),
        status: existingPlan.status,
        createdAt: existingPlan.createdAt,
        updatedAt: existingPlan.updatedAt,
      );

      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => existingPlan);

      expect(
        () => repository.updatePlan(invalidPlan),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid task configuration'),
        )),
      );
    });

    test('should throw when DAO updatePlan returns 0', () async {
      final existingPlan = createTestPlan();

      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => existingPlan);
      when(mockPlanDao.updatePlan(any)).thenAnswer((_) async => 0);

      expect(
        () => repository.updatePlan(existingPlan),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to update plan'),
        )),
      );
    });
  });

  // =========================================================================
  // deletePlan (cascade)
  // =========================================================================
  group('deletePlan', () {
    test('should cascade delete: tasks, remove from goal, soft delete plan', () async {
      final plan = createTestPlan();

      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => plan);
      when(mockTaskRepository.deletePlanTasks('plan-1'))
          .thenAnswer((_) async => true);
      when(mockGoalRepository.removePlanFromGoal('goal-1', 'plan-1'))
          .thenAnswer((_) async => true);
      when(mockPlanDao.deletePlan('plan-1')).thenAnswer((_) async => 1);

      final result = await repository.deletePlan('plan-1');

      expect(result, true);
      // Verify cascade order
      verifyInOrder([
        mockPlanDao.getPlanById('plan-1'),
        mockTaskRepository.deletePlanTasks('plan-1'),
        mockGoalRepository.removePlanFromGoal('goal-1', 'plan-1'),
        mockPlanDao.deletePlan('plan-1'),
      ]);
    });

    test('should return false when plan not found', () async {
      when(mockPlanDao.getPlanById('plan-999')).thenAnswer((_) async => null);

      final result = await repository.deletePlan('plan-999');

      expect(result, false);
      verifyNever(mockTaskRepository.deletePlanTasks(any));
      verifyNever(mockGoalRepository.removePlanFromGoal(any, any));
    });

    test('should return false when DAO deletePlan returns 0', () async {
      final plan = createTestPlan();

      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => plan);
      when(mockTaskRepository.deletePlanTasks('plan-1'))
          .thenAnswer((_) async => true);
      when(mockGoalRepository.removePlanFromGoal('goal-1', 'plan-1'))
          .thenAnswer((_) async => true);
      when(mockPlanDao.deletePlan('plan-1')).thenAnswer((_) async => 0);

      final result = await repository.deletePlan('plan-1');

      expect(result, false);
    });
  });

  // =========================================================================
  // restorePlan
  // =========================================================================
  group('restorePlan', () {
    test('should restore plan and re-add to goal', () async {
      final plan = createTestPlan();

      when(mockPlanDao.restorePlan('plan-1')).thenAnswer((_) async => 1);
      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => plan);
      when(mockGoalRepository.addPlanToGoal('goal-1', 'plan-1'))
          .thenAnswer((_) async => true);

      final result = await repository.restorePlan('plan-1');

      expect(result, true);
      verify(mockGoalRepository.addPlanToGoal('goal-1', 'plan-1')).called(1);
    });

    test('should return false when restore fails', () async {
      when(mockPlanDao.restorePlan('plan-1')).thenAnswer((_) async => 0);

      final result = await repository.restorePlan('plan-1');

      expect(result, false);
      verifyNever(mockGoalRepository.addPlanToGoal(any, any));
    });

    test('should still return true when plan not found after restore', () async {
      // Edge case: restorePlan succeeds but getPlanById returns null
      when(mockPlanDao.restorePlan('plan-1')).thenAnswer((_) async => 1);
      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => null);

      final result = await repository.restorePlan('plan-1');

      expect(result, true);
      verifyNever(mockGoalRepository.addPlanToGoal(any, any));
    });
  });

  // =========================================================================
  // searchPlans
  // =========================================================================
  group('searchPlans', () {
    test('should return all user plans when query is empty', () async {
      final plans = [createTestPlan()];

      when(mockPlanDao.getUserPlans('user-1')).thenAnswer((_) async => plans);

      final result = await repository.searchPlans('user-1', '');

      expect(result.length, 1);
      verify(mockPlanDao.getUserPlans('user-1')).called(1);
      verifyNever(mockPlanDao.searchPlans(any, any));
    });

    test('should search plans when query is not empty', () async {
      final plans = [createTestPlan(name: 'Exercise Plan')];

      when(mockPlanDao.searchPlans('user-1', 'Exercise'))
          .thenAnswer((_) async => plans);

      final result = await repository.searchPlans('user-1', 'Exercise');

      expect(result.length, 1);
      verify(mockPlanDao.searchPlans('user-1', 'Exercise')).called(1);
    });
  });

  // =========================================================================
  // updatePlanStatistics
  // =========================================================================
  group('updatePlanStatistics', () {
    test('should return true when update succeeds', () async {
      when(mockPlanDao.updatePlanStatistics(
        planId: 'plan-1',
        totalTaskCount: 10,
        completedTaskCount: 5,
        skippedTaskCount: 2,
      )).thenAnswer((_) async => 1);

      final result = await repository.updatePlanStatistics(
        planId: 'plan-1',
        totalTaskCount: 10,
        completedTaskCount: 5,
        skippedTaskCount: 2,
      );

      expect(result, true);
    });

    test('should return false when update returns 0', () async {
      when(mockPlanDao.updatePlanStatistics(
        planId: 'plan-999',
        totalTaskCount: null,
        completedTaskCount: null,
        skippedTaskCount: null,
      )).thenAnswer((_) async => 0);

      final result = await repository.updatePlanStatistics(planId: 'plan-999');

      expect(result, false);
    });
  });

  // =========================================================================
  // Delegate methods (simple pass-through to DAO)
  // =========================================================================
  group('delegate methods', () {
    test('getPlanById should delegate to DAO', () async {
      final plan = createTestPlan();
      when(mockPlanDao.getPlanById('plan-1')).thenAnswer((_) async => plan);

      final result = await repository.getPlanById('plan-1');

      expect(result, plan);
    });

    test('getUserPlans should delegate to DAO', () async {
      final plans = [createTestPlan()];
      when(mockPlanDao.getUserPlans('user-1')).thenAnswer((_) async => plans);

      final result = await repository.getUserPlans('user-1');

      expect(result, plans);
    });

    test('getGoalPlans should delegate to DAO', () async {
      final plans = [createTestPlan()];
      when(mockPlanDao.getGoalPlans('goal-1')).thenAnswer((_) async => plans);

      final result = await repository.getGoalPlans('goal-1');

      expect(result, plans);
    });

    test('getActivePlans should delegate to DAO', () async {
      when(mockPlanDao.getActivePlans('user-1')).thenAnswer((_) async => []);

      final result = await repository.getActivePlans('user-1');

      expect(result, isEmpty);
    });

    test('isPlanNameExists should delegate to DAO', () async {
      when(mockPlanDao.isPlanNameExists('user-1', 'test'))
          .thenAnswer((_) async => true);

      final result = await repository.isPlanNameExists('user-1', 'test');

      expect(result, true);
    });

    test('calculateCompletionRate should delegate to DAO', () async {
      when(mockPlanDao.calculateCompletionRate('plan-1'))
          .thenAnswer((_) async => 0.75);

      final result = await repository.calculateCompletionRate('plan-1');

      expect(result, 0.75);
    });

    test('getDeletedPlans should delegate to DAO', () async {
      when(mockPlanDao.getDeletedPlans('user-1')).thenAnswer((_) async => []);

      final result = await repository.getDeletedPlans('user-1');

      expect(result, isEmpty);
    });

    test('getPlansEndingSoon should delegate to DAO', () async {
      when(mockPlanDao.getPlansEndingSoon('user-1', days: 7))
          .thenAnswer((_) async => []);

      final result = await repository.getPlansEndingSoon('user-1');

      expect(result, isEmpty);
    });

    test('getPlanStatistics should delegate to DAO', () async {
      final stats = {'totalTaskCount': 10};
      when(mockPlanDao.getPlanStatistics('plan-1'))
          .thenAnswer((_) async => stats);

      final result = await repository.getPlanStatistics('plan-1');

      expect(result, stats);
    });

    test('getPlansNeedingTaskGeneration should delegate to DAO', () async {
      when(mockPlanDao.getPlansNeedingTaskGeneration('user-1'))
          .thenAnswer((_) async => []);

      final result = await repository.getPlansNeedingTaskGeneration('user-1');

      expect(result, isEmpty);
    });
  });
}
