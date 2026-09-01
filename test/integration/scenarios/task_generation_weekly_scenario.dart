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

  group('Scenario: weekly plan generates one task per week', () {
    test('first generation creates task with week window (Mon-Sun)', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        taskConfig: const TaskConfiguration(durationMinutes: 60),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => []);

      final task = createTask(
        planId: plan.id,
        config: plan.taskConfig,
        windowStartTime: startOfWeek(now),
        windowEndTime: endOfWeek(now),
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

    test('should NOT generate in same week after completion', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.weekly),
      );

      final thisWeekTask = createTask(
        planId: plan.id,
        status: TaskStatus.completed,
        windowStartTime: startOfWeek(now),
        windowEndTime: endOfWeek(now),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [thisWeekTask]);

      final result = await generationService.generateNextTask(plan);
      expect(result, isNull);
    });

    test('should generate for new week after previous week completed', () async {
      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7));
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.weekly),
      );

      final lastWeekTask = createTask(
        planId: plan.id,
        status: TaskStatus.completed,
        windowStartTime: startOfWeek(lastWeek),
        windowEndTime: endOfWeek(lastWeek),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [lastWeekTask]);

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

    test('should NOT generate when active task exists (not expired)', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.weekly),
      );

      final activeTask = createTask(
        planId: plan.id,
        status: TaskStatus.active,
        windowStartTime: startOfWeek(now),
        windowEndTime: endOfWeek(now),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [activeTask]);

      final result = await generationService.generateNextTask(plan);
      expect(result, isNull);
    });

    test('window end should be capped at plan endDate', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.weekly),
        endDate: now.add(const Duration(days: 2)),
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

    test('year boundary: last week of prev year → first week of new year',
        () async {
      final now = DateTime.now();
      final lastYear = now.year - 1;
      final dec31 = DateTime(lastYear, 12, 31);
      final mondayOfLastWeek =
          dec31.subtract(Duration(days: dec31.weekday - 1));
      final mondayStart = startOfDay(mondayOfLastWeek);
      final sundayEnd = endOfDay(
          mondayStart.add(const Duration(days: 6)));

      final plan = createPlan(
        repeatRule: const RepeatRule(type: RepeatType.weekly),
      );

      final lastWeekTask = createTask(
        planId: plan.id,
        status: TaskStatus.completed,
        windowStartTime: mondayStart,
        windowEndTime: sundayEnd,
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [lastWeekTask]);

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
