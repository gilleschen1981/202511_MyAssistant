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

  group('Scenario: monthly plan generates one task per month', () {
    test('first generation creates task with month window', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.monthly),
        taskConfig: const TaskConfiguration(
          evaluationOptions: ['Excellent', 'Good', 'Fair', 'Poor'],
        ),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => []);

      final task = createTask(
        planId: plan.id,
        config: plan.taskConfig,
        windowStartTime: startOfMonth(now),
        windowEndTime: endOfMonth(now),
      );
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

    test('should NOT generate when same month already has task', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.monthly),
      );

      final thisMonthTask = createTask(
        planId: plan.id,
        status: TaskStatus.completed,
        windowStartTime: startOfMonth(now),
        windowEndTime: endOfMonth(now),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [thisMonthTask]);

      final result = await generationService.generateNextTask(plan);
      expect(result, isNull);
    });

    test('should generate for new month after previous month task', () async {
      final now = DateTime.now();
      final prevMonth = DateTime(
        now.month == 1 ? now.year - 1 : now.year,
        now.month == 1 ? 12 : now.month - 1,
        1,
      );
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.monthly),
      );

      final lastMonthTask = createTask(
        planId: plan.id,
        status: TaskStatus.completed,
        windowStartTime: startOfMonth(prevMonth),
        windowEndTime: endOfMonth(prevMonth),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [lastMonthTask]);

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

    test('window end should be capped at plan endDate', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.monthly),
        endDate: now.add(const Duration(days: 10)),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => []);

      final task = createTask(planId: plan.id);
      when(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: captureAnyNamed('windowEndTime'),
      )).thenAnswer((_) async => task);

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

    test('year boundary: Dec → Jan generates new task', () async {
      final now = DateTime.now();
      final lastDec = DateTime(now.year - 1, 12, 15);
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.monthly),
      );

      final decTask = createTask(
        planId: plan.id,
        status: TaskStatus.completed,
        windowStartTime: DateTime(lastDec.year, 12, 1),
        windowEndTime: DateTime(lastDec.year, 12, 31, 23, 59, 59, 999),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [decTask]);

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
  });
}
