import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:myassistant/data/services/task_generation_service.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';

import 'task_generation_service_test.mocks.dart';

@GenerateMocks([ITaskRepository, IPlanRepository])
void main() {
  late TaskGenerationService service;
  late MockITaskRepository mockTaskRepository;
  late MockIPlanRepository mockPlanRepository;

  setUp(() {
    mockTaskRepository = MockITaskRepository();
    mockPlanRepository = MockIPlanRepository();
    service = TaskGenerationService(
      taskRepository: mockTaskRepository,
      planRepository: mockPlanRepository,
    );
  });

  // Helper function to create a test plan
  PlanModel createTestPlan({
    String id = 'plan-123',
    String userId = 'user-123',
    String goalId = 'goal-123',
    String name = 'Test Weekly Plan',
    RepeatType repeatType = RepeatType.weekly,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    return PlanModel(
      id: id,
      userId: userId,
      name: name,
      goalId: goalId,
      startDate: startDate ?? now.subtract(const Duration(days: 365)),
      endDate: endDate ?? now.add(const Duration(days: 365)),
      repeatRule: RepeatRule(type: repeatType),
      taskConfig: const TaskConfiguration(durationMinutes: 30),
      status: PlanStatus.active,
      createdAt: now.subtract(const Duration(days: 365)),
      updatedAt: now,
    );
  }

  // Helper function to create a test task
  TaskModel createTestTask({
    String id = 'task-123',
    String userId = 'user-123',
    String planId = 'plan-123',
    String name = 'Test Task',
    required DateTime windowStartTime,
    required DateTime windowEndTime,
    TaskStatus status = TaskStatus.active,
  }) {
    return TaskModel(
      id: id,
      userId: userId,
      planId: planId,
      name: name,
      config: const TaskConfiguration(durationMinutes: 30),
      windowStartTime: windowStartTime,
      windowEndTime: windowEndTime,
      status: status,
      createdAt: DateTime.now(),
    );
  }

  group('TaskGenerationService - Weekly Tasks', () {
    group('Same week detection', () {
      test('should NOT generate new task when completing on Monday and refreshing on same Monday', () async {
        // Arrange: Use current week's Monday
        final now = DateTime.now();
        final weekday = now.weekday; // 1 = Monday, 7 = Sunday
        final mondayThisWeek = now.subtract(Duration(days: weekday - 1));
        final mondayStart = DateTime(mondayThisWeek.year, mondayThisWeek.month, mondayThisWeek.day);
        final sundayEnd = mondayStart.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));

        final plan = createTestPlan(repeatType: RepeatType.weekly);

        // Last task was created on Monday of this week, window: Monday 00:00 - Sunday 23:59
        final lastTask = createTestTask(
          planId: plan.id,
          windowStartTime: mondayStart,
          windowEndTime: sundayEnd,
          status: TaskStatus.completed,
        );

        when(mockTaskRepository.getPlanTasks(plan.id))
            .thenAnswer((_) async => [lastTask]);

        // Act: Try to generate task on the same week
        final result = await service.generateNextTask(plan);

        // Assert: Should NOT generate new task (same week)
        expect(result, isNull);
        verifyNever(mockTaskRepository.createTask(
          userId: anyNamed('userId'),
          planId: anyNamed('planId'),
          name: anyNamed('name'),
          description: anyNamed('description'),
          config: anyNamed('config'),
          windowStartTime: anyNamed('windowStartTime'),
          windowEndTime: anyNamed('windowEndTime'),
        ));
      });

      test('should NOT generate new task when task is from current week', () async {
        // Arrange: Use current week
        final now = DateTime.now();
        final weekday = now.weekday;
        final mondayThisWeek = now.subtract(Duration(days: weekday - 1));
        final mondayStart = DateTime(mondayThisWeek.year, mondayThisWeek.month, mondayThisWeek.day);
        final sundayEnd = mondayStart.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));

        final plan = createTestPlan(repeatType: RepeatType.weekly);

        final lastTask = createTestTask(
          planId: plan.id,
          windowStartTime: mondayStart,
          windowEndTime: sundayEnd,
          status: TaskStatus.completed,
        );

        when(mockTaskRepository.getPlanTasks(plan.id))
            .thenAnswer((_) async => [lastTask]);

        // Act
        final result = await service.generateNextTask(plan);

        // Assert: Should NOT generate new task (still in same week)
        expect(result, isNull);
      });

      test('should generate new task when last task was from previous week', () async {
        // Arrange: Last week (7-13 days ago)
        final now = DateTime.now();
        final lastWeekMonday = now.subtract(Duration(days: now.weekday - 1 + 7));
        final lastWeekMondayStart = DateTime(lastWeekMonday.year, lastWeekMonday.month, lastWeekMonday.day);
        final lastWeekSundayEnd = lastWeekMondayStart.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));

        final plan = createTestPlan(repeatType: RepeatType.weekly);

        final lastTask = createTestTask(
          planId: plan.id,
          windowStartTime: lastWeekMondayStart,
          windowEndTime: lastWeekSundayEnd,
          status: TaskStatus.completed,
        );

        when(mockTaskRepository.getPlanTasks(plan.id))
            .thenAnswer((_) async => [lastTask]);
        when(mockTaskRepository.createTask(
          userId: anyNamed('userId'),
          planId: anyNamed('planId'),
          name: anyNamed('name'),
          description: anyNamed('description'),
          config: anyNamed('config'),
          windowStartTime: anyNamed('windowStartTime'),
          windowEndTime: anyNamed('windowEndTime'),
        )).thenAnswer((_) async => createTestTask(
          windowStartTime: now,
          windowEndTime: now.add(const Duration(days: 7)),
        ));

        // Act
        final result = await service.generateNextTask(plan);

        // Assert: Should generate new task for new week
        expect(result, isNotNull);
        verify(mockTaskRepository.createTask(
          userId: anyNamed('userId'),
          planId: anyNamed('planId'),
          name: anyNamed('name'),
          description: anyNamed('description'),
          config: anyNamed('config'),
          windowStartTime: anyNamed('windowStartTime'),
          windowEndTime: anyNamed('windowEndTime'),
        )).called(1);
      });
    });

    group('Week boundary edge cases', () {
      test('should correctly identify different weeks across year boundary', () async {
        // Arrange: Use last week of previous year
        final now = DateTime.now();
        final lastYear = now.year - 1;
        final lastWeekOfPrevYear = DateTime(lastYear, 12, 31);
        final mondayOfLastWeek = lastWeekOfPrevYear.subtract(Duration(days: lastWeekOfPrevYear.weekday - 1));
        final mondayStart = DateTime(mondayOfLastWeek.year, mondayOfLastWeek.month, mondayOfLastWeek.day);
        final sundayEnd = mondayStart.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));

        final plan = createTestPlan(repeatType: RepeatType.weekly);

        final lastTask = createTestTask(
          planId: plan.id,
          windowStartTime: mondayStart,
          windowEndTime: sundayEnd,
          status: TaskStatus.completed,
        );

        when(mockTaskRepository.getPlanTasks(plan.id))
            .thenAnswer((_) async => [lastTask]);
        when(mockTaskRepository.createTask(
          userId: anyNamed('userId'),
          planId: anyNamed('planId'),
          name: anyNamed('name'),
          description: anyNamed('description'),
          config: anyNamed('config'),
          windowStartTime: anyNamed('windowStartTime'),
          windowEndTime: anyNamed('windowEndTime'),
        )).thenAnswer((_) async => createTestTask(
          windowStartTime: now,
          windowEndTime: now.add(const Duration(days: 7)),
        ));

        // Act
        final result = await service.generateNextTask(plan);

        // Assert: Should recognize different weeks across year boundary
        expect(result, isNotNull);
      });
    });

    group('First task generation', () {
      test('should generate first task when no previous tasks exist', () async {
        // Arrange
        final plan = createTestPlan(repeatType: RepeatType.weekly);

        when(mockTaskRepository.getPlanTasks(plan.id))
            .thenAnswer((_) async => []);
        when(mockTaskRepository.createTask(
          userId: anyNamed('userId'),
          planId: anyNamed('planId'),
          name: anyNamed('name'),
          description: anyNamed('description'),
          config: anyNamed('config'),
          windowStartTime: anyNamed('windowStartTime'),
          windowEndTime: anyNamed('windowEndTime'),
        )).thenAnswer((_) async => createTestTask(
          windowStartTime: DateTime.now(),
          windowEndTime: DateTime.now().add(const Duration(days: 7)),
        ));

        // Act
        final result = await service.generateNextTask(plan);

        // Assert
        expect(result, isNotNull);
        verify(mockTaskRepository.createTask(
          userId: anyNamed('userId'),
          planId: anyNamed('planId'),
          name: anyNamed('name'),
          description: anyNamed('description'),
          config: anyNamed('config'),
          windowStartTime: anyNamed('windowStartTime'),
          windowEndTime: anyNamed('windowEndTime'),
        )).called(1);
      });
    });

    group('Active task handling', () {
      test('should NOT generate new task when active task still exists', () async {
        // Arrange
        final now = DateTime.now();
        final plan = createTestPlan(repeatType: RepeatType.weekly);

        // Active task still exists
        final activeTask = createTestTask(
          planId: plan.id,
          windowStartTime: now,
          windowEndTime: now.add(const Duration(days: 7)),
          status: TaskStatus.active,
        );

        when(mockTaskRepository.getPlanTasks(plan.id))
            .thenAnswer((_) async => [activeTask]);

        // Act
        final result = await service.generateNextTask(plan);

        // Assert: Should NOT generate new task
        expect(result, isNull);
        verifyNever(mockTaskRepository.createTask(
          userId: anyNamed('userId'),
          planId: anyNamed('planId'),
          name: anyNamed('name'),
          description: anyNamed('description'),
          config: anyNamed('config'),
          windowStartTime: anyNamed('windowStartTime'),
          windowEndTime: anyNamed('windowEndTime'),
        ));
      });
    });
  });

  group('TaskGenerationService - Other Repeat Types', () {
    test('daily task should NOT generate on same day', () async {
      // Arrange
      final plan = createTestPlan(
        repeatType: RepeatType.daily,
      );

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

      final lastTask = createTestTask(
        planId: plan.id,
        windowStartTime: startOfDay,
        windowEndTime: endOfDay,
        status: TaskStatus.completed,
      );

      when(mockTaskRepository.getPlanTasks(plan.id))
          .thenAnswer((_) async => [lastTask]);

      // Act
      final result = await service.generateNextTask(plan);

      // Assert
      expect(result, isNull);
    });

    test('monthly task should NOT generate in same month', () async {
      // Arrange
      final plan = createTestPlan(
        repeatType: RepeatType.monthly,
      );

      final today = DateTime.now();
      final startOfMonth = DateTime(today.year, today.month, 1);
      final endOfMonth = DateTime(today.year, today.month + 1, 1)
          .subtract(const Duration(days: 1));

      final lastTask = createTestTask(
        planId: plan.id,
        windowStartTime: startOfMonth,
        windowEndTime: endOfMonth,
        status: TaskStatus.completed,
      );

      when(mockTaskRepository.getPlanTasks(plan.id))
          .thenAnswer((_) async => [lastTask]);

      // Act
      final result = await service.generateNextTask(plan);

      // Assert
      expect(result, isNull);
    });
  });
}
