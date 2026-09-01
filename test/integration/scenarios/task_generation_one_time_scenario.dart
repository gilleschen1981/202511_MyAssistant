import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:myassistant/data/services/task_generation_service.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';

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

  group('Scenario: oneTime plan generates exactly one task', () {
    test('should generate a task spanning startDate to endDate', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.oneTime),
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 25)),
        taskConfig: const TaskConfiguration(durationMinutes: 30),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => []);

      final createdTask = createTask(
        planId: plan.id,
        config: plan.taskConfig,
        windowStartTime: startOfDay(now),
        windowEndTime: plan.endDate,
      );
      when(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      )).thenAnswer((_) async => createdTask);

      final result = await generationService.generateNextTask(plan);

      expect(result, isNotNull);
      expect(result!.config.durationMinutes, 30);
      verify(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      )).called(1);
    });

    test('should NOT generate second task after first is completed', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.oneTime),
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 25)),
      );

      final completedTask = createTask(
        planId: plan.id,
        status: TaskStatus.completed,
        windowStartTime: now.subtract(const Duration(days: 3)),
        windowEndTime: plan.endDate,
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [completedTask]);

      final result = await generationService.generateNextTask(plan);

      expect(result, isNull);
      verifyNever(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      ));
    });

    test('should NOT generate second task after first is skipped', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.oneTime),
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 25)),
      );

      final skippedTask = createTask(
        planId: plan.id,
        status: TaskStatus.skipped,
        windowStartTime: now.subtract(const Duration(days: 3)),
        windowEndTime: plan.endDate,
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [skippedTask]);

      final result = await generationService.generateNextTask(plan);

      expect(result, isNull);
    });

    test('should NOT generate if plan has expired', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.oneTime),
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.subtract(const Duration(days: 1)),
      );

      final result = await generationService.generateNextTask(plan);

      expect(result, isNull);
    });

    test('should work with all TaskConfiguration types', () async {
      final configs = [
        const TaskConfiguration(),
        const TaskConfiguration(durationMinutes: 25),
        const TaskConfiguration(repeatCount: 10),
        const TaskConfiguration(evaluationOptions: ['Good', 'Bad']),
        const TaskConfiguration(durationMinutes: 25, repeatCount: 10),
        const TaskConfiguration(
            repeatCount: 5, evaluationOptions: ['A', 'B', 'C']),
      ];

      for (final config in configs) {
        final now = DateTime.now();
        final planId = 'plan-${config.taskType.name}';
        final plan = createPlan(
          id: planId,
          repeatRule: const RepeatRule(type: RepeatType.oneTime),
          startDate: now.subtract(const Duration(days: 1)),
          endDate: now.add(const Duration(days: 30)),
          taskConfig: config,
        );

        when(mockTaskRepo.getPlanTasks(planId))
            .thenAnswer((_) async => []);

        final createdTask = createTask(
          planId: planId,
          config: config,
        );
        when(mockTaskRepo.createTask(
          userId: anyNamed('userId'),
          planId: anyNamed('planId'),
          name: anyNamed('name'),
          description: anyNamed('description'),
          config: anyNamed('config'),
          windowStartTime: anyNamed('windowStartTime'),
          windowEndTime: anyNamed('windowEndTime'),
        )).thenAnswer((_) async => createdTask);

        final result = await generationService.generateNextTask(plan);
        expect(result, isNotNull,
            reason: 'Should generate for config type: ${config.taskType}');
      }
    });
  });
}
