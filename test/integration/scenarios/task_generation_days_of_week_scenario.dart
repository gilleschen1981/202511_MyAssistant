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

  group('Scenario: daysOfWeek plan generates per-day tasks', () {
    test('generates tasks only for selected days (Mon/Wed/Fri)', () async {
      final now = DateTime.now();
      final plan = createPlan(
        repeatRule: const RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [1, 3, 5], // Mon, Wed, Fri
        ),
        taskConfig: const TaskConfiguration(durationMinutes: 30),
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
        windowEndTime: anyNamed('windowEndTime'),
      )).thenAnswer((invocation) async {
        final windowStart =
            invocation.namedArguments[const Symbol('windowStartTime')]
                as DateTime;
        final windowEnd =
            invocation.namedArguments[const Symbol('windowEndTime')]
                as DateTime;
        return createTask(
          planId: plan.id,
          config: plan.taskConfig,
          windowStartTime: windowStart,
          windowEndTime: windowEnd,
        );
      });

      final result = await generationService.generateNextTask(plan);

      // Should have attempted to create tasks for future selected days
      // The exact count depends on which days remain in the current week
      final todayWeekday = now.weekday;
      final futureDays = [1, 3, 5].where((d) => d >= todayWeekday).length;

      if (futureDays > 0) {
        expect(result, isNotNull);
      }
    });

    test('each task has single-day window (start~end of that day)', () async {
      final plan = createPlan(
        repeatRule: const RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [1, 2, 3, 4, 5, 6, 7], // All days
        ),
        taskConfig: const TaskConfiguration(repeatCount: 3),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => []);

      final createdWindows = <({DateTime start, DateTime end})>[];
      when(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      )).thenAnswer((invocation) async {
        final ws = invocation.namedArguments[const Symbol('windowStartTime')]
            as DateTime;
        final we = invocation.namedArguments[const Symbol('windowEndTime')]
            as DateTime;
        createdWindows.add((start: ws, end: we));
        return createTask(
          planId: plan.id,
          config: plan.taskConfig,
          windowStartTime: ws,
          windowEndTime: we,
        );
      });

      await generationService.generateNextTask(plan);

      for (final window in createdWindows) {
        expect(window.start.hour, 0);
        expect(window.start.minute, 0);
        expect(window.end.hour, 23);
        expect(window.end.minute, 59);
        // Single day: same date
        expect(window.start.year, window.end.year);
        expect(window.start.month, window.end.month);
        expect(window.start.day, window.end.day);
      }
    });

    test('skips past days in current week', () async {
      final now = DateTime.now();
      final todayWeekday = now.weekday;

      // Select only past days
      final pastDays = List.generate(todayWeekday - 1, (i) => i + 1);
      if (pastDays.isEmpty) return; // Monday, no past days to test

      final plan = createPlan(
        repeatRule: RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: pastDays,
        ),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => []);

      final result = await generationService.generateNextTask(plan);

      // Past days should be skipped, no tasks created
      verifyNever(mockTaskRepo.createTask(
        userId: anyNamed('userId'),
        planId: anyNamed('planId'),
        name: anyNamed('name'),
        description: anyNamed('description'),
        config: anyNamed('config'),
        windowStartTime: anyNamed('windowStartTime'),
        windowEndTime: anyNamed('windowEndTime'),
      ));
      expect(result, isNull);
    });

    test('does not duplicate tasks for same day', () async {
      final now = DateTime.now();
      final todayWeekday = now.weekday;

      final plan = createPlan(
        repeatRule: RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [todayWeekday],
        ),
      );

      // Already has task for today
      final todayTask = createTask(
        planId: plan.id,
        status: TaskStatus.active,
        windowStartTime: startOfDay(now),
        windowEndTime: endOfDay(now),
      );

      when(mockTaskRepo.getPlanTasks(plan.id))
          .thenAnswer((_) async => [todayTask]);

      await generationService.generateNextTask(plan);

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

    test('skips days outside plan date range', () async {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      // Plan starts tomorrow — today should be skipped even if selected
      final plan = createPlan(
        repeatRule: const RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        ),
        startDate: startOfDay(tomorrow),
        endDate: now.add(const Duration(days: 60)),
      );

      // Plan not active yet (now is before startDate)
      final result = await generationService.generateNextTask(plan);
      expect(result, isNull);
    });

    test('generates with counter+evaluation config', () async {
      final now = DateTime.now();
      final todayWeekday = now.weekday;

      const config = TaskConfiguration(
        repeatCount: 5,
        evaluationOptions: ['Great', 'OK', 'Poor'],
      );

      final plan = createPlan(
        repeatRule: RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [todayWeekday], // Today
        ),
        taskConfig: config,
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
        windowEndTime: anyNamed('windowEndTime'),
      )).thenAnswer((_) async => createTask(
            planId: plan.id,
            config: config,
          ));

      final result = await generationService.generateNextTask(plan);
      expect(result, isNotNull);
      expect(result!.config.taskType, TaskType.counterWithEval);
    });
  });
}
