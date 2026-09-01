import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:myassistant/data/services/task_generation_service.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/data/models/plan_model.dart';

import 'helpers/test_factories.dart';
import 'scenario_mocks.mocks.dart';

void main() {
  late TaskGenerationService generationService;
  late MockITaskRepository mockTaskRepo;
  late MockIPlanRepository mockPlanRepo;

  setUp(() {
    mockTaskRepo = MockITaskRepository();
    mockPlanRepo = MockIPlanRepository();
    generationService = TaskGenerationService(
      taskRepository: mockTaskRepo,
      planRepository: mockPlanRepo,
    );
  });

  group('Scenario: daily plan generates one task per day', () {
    test('first generation creates task with today window', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.daily),
        taskConfig: const TaskConfiguration(durationMinutes: 15),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => []);

      final expectedTask = createTask(
        planId: plan.id,
        config: plan.taskConfig,
        windowStartTime: startOfDay(now),
        windowEndTime: endOfDay(now),
      );
      when(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      )).thenAnswer((_) async => expectedTask);

      final result = await generationService.generateNextTask(plan);

      expect(result, isNotNull);
      verify(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: captureAnyNamed('windowStartTime'),
        windowEndTime: captureAnyNamed('windowEndTime'),
      )).called(1);
    });

    test('should NOT generate when today already has active task', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.daily),
      );

      final todayTask = createTask(
        planId: plan.id,
        status: TaskStatus.active,
        windowStartTime: startOfDay(now),
        windowEndTime: endOfDay(now),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [todayTask]);

      final result = await generationService.generateNextTask(plan);
      expect(result, isNull);
    });

    test('should NOT generate when today already has completed task', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.daily),
      );

      final todayCompleted = createTask(
        planId: plan.id,
        status: TaskStatus.completed,
        windowStartTime: startOfDay(now),
        windowEndTime: endOfDay(now),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [todayCompleted]);

      final result = await generationService.generateNextTask(plan);
      expect(result, isNull);
    });

    test('should generate when last task was yesterday (completed)', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.daily),
        taskConfig: const TaskConfiguration(repeatCount: 5),
      );

      final yesterdayTask = createTask(
        planId: plan.id,
        status: TaskStatus.completed,
        windowStartTime: startOfDay(yesterday),
        windowEndTime: endOfDay(yesterday),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [yesterdayTask]);

      final newTask = createTask(
        planId: plan.id,
        config: plan.taskConfig,
        windowStartTime: startOfDay(now),
        windowEndTime: endOfDay(now),
      );
      when(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      )).thenAnswer((_) async => newTask);

      final result = await generationService.generateNextTask(plan);
      expect(result, isNotNull);
      expect(result!.config.repeatCount, 5);
    });

    test('should generate when last task was yesterday (skipped)', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.daily),
      );

      final yesterdaySkipped = createTask(
        planId: plan.id,
        status: TaskStatus.skipped,
        windowStartTime: startOfDay(yesterday),
        windowEndTime: endOfDay(yesterday),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [yesterdaySkipped]);

      final newTask = createTask(planId: plan.id);
      when(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      )).thenAnswer((_) async => newTask);

      final result = await generationService.generateNextTask(plan);
      expect(result, isNotNull);
    });

    test('should stop generating after plan endDate', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.daily),
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.subtract(const Duration(days: 1)),
      );

      final result = await generationService.generateNextTask(plan);
      expect(result, isNull);
    });

    test('window end should be capped at plan endDate', () async {
      final now = DateTime.now();
      final planEndDate = DateTime(now.year, now.month, now.day, 18, 0, 0);
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.daily),
        startDate: now.subtract(const Duration(days: 5)),
        endDate: planEndDate.isAfter(now)
            ? planEndDate
            : now.add(const Duration(hours: 1)),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => []);

      final capturedTask = createTask(planId: plan.id);
      when(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: captureAnyNamed('windowEndTime'),
      )).thenAnswer((_) async => capturedTask);

      await generationService.generateNextTask(plan);

      final captured = verify(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: captureAnyNamed('windowEndTime'),
      )).captured;

      final windowEnd = captured.last as DateTime;
      expect(windowEnd.isBefore(plan.endDate) || windowEnd == plan.endDate,
          isTrue);
    });

    test('daily plan with each TaskConfiguration type', () async {
      final configs = {
        'simple': const TaskConfiguration(),
        'timer': const TaskConfiguration(durationMinutes: 25),
        'counter': const TaskConfiguration(repeatCount: 10),
        'evaluation':
            const TaskConfiguration(evaluationOptions: ['A', 'B', 'C']),
        'timerWithCount':
            const TaskConfiguration(durationMinutes: 25, repeatCount: 10),
        'counterWithEval': const TaskConfiguration(
            repeatCount: 5, evaluationOptions: ['Good', 'OK', 'Bad']),
      };

      for (final entry in configs.entries) {
        final planId = 'plan-daily-${entry.key}';
        final plan = createPlan(
          id: planId,
          repeatRule: const RepeatRule(type: RepeatType.daily),
          taskConfig: entry.value,
        );

        when(mockTaskRepo.getPlanTasks(planId))
            .thenAnswer((_) async => []);

        final task = createTask(planId: planId, config: entry.value);
        when(mockTaskRepo.createTask(
          userId: anyNamed('userId'),
          planId: anyNamed('planId'),
          name: anyNamed('name'),
          description: anyNamed('description'),
          config: anyNamed('config'),
          windowStartTime: anyNamed('windowStartTime'),
          windowEndTime: anyNamed('windowEndTime'),
        )).thenAnswer((_) async => task);

        final result = await generationService.generateNextTask(plan);
        expect(result, isNotNull,
            reason: 'Daily ${entry.key} should generate task');
      }
    });
  });
}
