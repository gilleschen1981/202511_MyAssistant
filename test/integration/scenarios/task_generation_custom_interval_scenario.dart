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

  group('Scenario: custom interval plan generates every N days', () {
    test('custom(3): first generation creates 3-day window', () async {
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.custom, customDays: 3),
        taskConfig: const TaskConfiguration(durationMinutes: 45),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => []);

      final task = createTask(planId: plan.id, config: plan.taskConfig);
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
      expect(result, isNotNull);
    });

    test('custom(3): should NOT generate before 3 days elapsed', () async {
      final now = DateTime.now();
      final twoDaysAgo = now.subtract(const Duration(days: 2));
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.custom, customDays: 3),
      );

      final recentTask = createTask(
        planId: plan.id,
        status: TaskStatus.completed,
        windowStartTime: startOfDay(twoDaysAgo),
        windowEndTime: endOfDay(twoDaysAgo.add(const Duration(days: 2))),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [recentTask]);

      final result = await generationService.generateNextTask(plan);
      expect(result, isNull);
    });

    test('custom(3): should generate after 3+ days elapsed', () async {
      final now = DateTime.now();
      final fourDaysAgo = now.subtract(const Duration(days: 4));
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.custom, customDays: 3),
      );

      final oldTask = createTask(
        planId: plan.id,
        status: TaskStatus.completed,
        windowStartTime: startOfDay(fourDaysAgo),
        windowEndTime: endOfDay(fourDaysAgo.add(const Duration(days: 2))),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [oldTask]);

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

    test('custom(1): behaves like daily', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.custom, customDays: 1),
      );

      final yesterdayTask = createTask(
        planId: plan.id,
        status: TaskStatus.completed,
        windowStartTime: startOfDay(yesterday),
        windowEndTime: endOfDay(yesterday),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [yesterdayTask]);

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

    test('custom(7): window spans 7 days', () async {
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.custom, customDays: 7),
        taskConfig: const TaskConfiguration(
          repeatCount: 10,
          evaluationOptions: ['A', 'B', 'C'],
        ),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => []);

      when(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: captureAnyNamed('windowStartTime'),
        windowEndTime: captureAnyNamed('windowEndTime'),
      )).thenAnswer((_) async => createTask(planId: plan.id));

      await generationService.generateNextTask(plan);

      final captured = verify(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: captureAnyNamed('windowStartTime'),
        windowEndTime: captureAnyNamed('windowEndTime'),
      )).captured;

      // captured alternates: windowStartTime, windowEndTime
      final windowStart = captured[captured.length - 2] as DateTime;
      final windowEnd = captured[captured.length - 1] as DateTime;
      final daySpan = windowEnd.difference(windowStart).inDays;
      // 7-day custom: window is windowStart to windowStart+6 days end
      expect(daySpan, greaterThanOrEqualTo(6));
    });

    test('window end capped at plan endDate', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.custom, customDays: 30),
        endDate: now.add(const Duration(days: 5)),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => []);

      when(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: captureAnyNamed('windowEndTime'),
      )).thenAnswer((_) async => createTask(planId: plan.id));

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
      expect(
        windowEnd.isBefore(plan.endDate) ||
            windowEnd.isAtSameMomentAs(plan.endDate),
        isTrue,
      );
    });
  });
}
