import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/presentation/providers/task_list_notifier.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/user_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_filter.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/data/services/task_execution_service.dart';
import 'package:myassistant/data/services/task_refresh_service.dart';
import 'package:myassistant/di/providers/repository_providers.dart';
import 'package:myassistant/di/providers/service_providers.dart';

import 'task_list_notifier_test.mocks.dart';

@GenerateMocks([ITaskRepository, TaskExecutionService, TaskRefreshService])
void main() {
  late MockITaskRepository mockTaskRepository;
  late MockTaskExecutionService mockExecutionService;
  late MockTaskRefreshService mockRefreshService;
  late ProviderContainer container;

  setUp(() {
    mockTaskRepository = MockITaskRepository();
    mockExecutionService = MockTaskExecutionService();
    mockRefreshService = MockTaskRefreshService();

    // Setup default mocks
    when(mockExecutionService.getActiveSessions()).thenReturn({});
  });

  tearDown(() {
    container.dispose();
  });

  /// Helper to create a test user
  UserModel createTestUser({String id = 'test-user-123'}) {
    final now = DateTime.now();
    return UserModel(
      id: id,
      username: 'testuser',
      email: 'test@example.com',
      passwordHash: 'test-hash',
      status: UserStatus.active,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Helper to create a test task
  TaskModel createTestTask({
    String id = 'task-123',
    String userId = 'test-user-123',
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

  /// Helper to create container with mocks
  ProviderContainer createContainer() {
    final testUser = createTestUser();

    return ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => testUser),
        taskRepositoryProvider.overrideWith((ref) => mockTaskRepository),
        taskExecutionServiceProvider.overrideWith((ref) => mockExecutionService),
        taskRefreshServiceProvider.overrideWith((ref) => mockRefreshService),
      ],
    );
  }

  group('TaskListNotifier - Window Task Loading', () {
    test('should load tasks in current execution window to allTasks', () async {
      // Arrange
      final now = DateTime.now();
      final windowStart = now.subtract(const Duration(hours: 1));
      final windowEnd = now.add(const Duration(hours: 1));

      final taskInWindow = createTestTask(
        id: 'task-1',
        windowStartTime: windowStart,
        windowEndTime: windowEnd,
        status: TaskStatus.active,
      );

      when(mockTaskRepository.getFutureTasks('test-user-123'))
          .thenAnswer((_) async => [taskInWindow]);
      when(mockTaskRepository.getTodayTasks('test-user-123'))
          .thenAnswer((_) async => [taskInWindow]);

      container = createContainer();

      // Act
      await container.read(taskListNotifierProvider.future);

      // Assert
      final state = container.read(taskListNotifierProvider).value!;
      expect(state.allTasks.length, equals(1));
      expect(state.allTasks.first.id, equals('task-1'));
      expect(state.activeTasks.length, equals(1));
    });

    test('should NOT include expired tasks in allTasks', () async {
      // Arrange
      final now = DateTime.now();
      final expiredWindowStart = now.subtract(const Duration(days: 2));
      final expiredWindowEnd = now.subtract(const Duration(days: 1));

      final expiredTask = createTestTask(
        id: 'expired-task',
        windowStartTime: expiredWindowStart,
        windowEndTime: expiredWindowEnd,
        status: TaskStatus.active,
      );

      // getTasksInCurrentWindow should not return expired tasks
      when(mockTaskRepository.getFutureTasks('test-user-123'))
          .thenAnswer((_) async => []);
      when(mockTaskRepository.getTodayTasks('test-user-123'))
          .thenAnswer((_) async => [expiredTask]);

      container = createContainer();

      // Act
      await container.read(taskListNotifierProvider.future);

      // Assert
      final state = container.read(taskListNotifierProvider).value!;
      expect(state.allTasks.length, equals(0));
      expect(state.todayTasks.length, equals(1)); // Still in todayTasks for UI
    });

    test('should NOT include future tasks (window not started) in allTasks', () async {
      // Arrange
      final now = DateTime.now();
      final futureWindowStart = now.add(const Duration(hours: 2));
      final futureWindowEnd = now.add(const Duration(hours: 3));

      final futureTask = createTestTask(
        id: 'future-task',
        windowStartTime: futureWindowStart,
        windowEndTime: futureWindowEnd,
        status: TaskStatus.active,
      );

      // getTasksInCurrentWindow should not return future tasks
      when(mockTaskRepository.getFutureTasks('test-user-123'))
          .thenAnswer((_) async => []);
      when(mockTaskRepository.getTodayTasks('test-user-123'))
          .thenAnswer((_) async => [futureTask]);

      container = createContainer();

      // Act
      await container.read(taskListNotifierProvider.future);

      // Assert
      final state = container.read(taskListNotifierProvider).value!;
      expect(state.allTasks.length, equals(0));
      expect(state.todayTasks.length, equals(1)); // May be in todayTasks if window starts today
    });

    test('should include multi-day tasks that span current time', () async {
      // Arrange
      final now = DateTime.now();
      final windowStart = now.subtract(const Duration(days: 1));
      final windowEnd = now.add(const Duration(days: 1));

      final multiDayTask = createTestTask(
        id: 'multi-day-task',
        windowStartTime: windowStart,
        windowEndTime: windowEnd,
        status: TaskStatus.active,
      );

      when(mockTaskRepository.getFutureTasks('test-user-123'))
          .thenAnswer((_) async => [multiDayTask]);
      when(mockTaskRepository.getTodayTasks('test-user-123'))
          .thenAnswer((_) async => [multiDayTask]);

      container = createContainer();

      // Act
      await container.read(taskListNotifierProvider.future);

      // Assert
      final state = container.read(taskListNotifierProvider).value!;
      expect(state.allTasks.length, equals(1));
      expect(state.allTasks.first.id, equals('multi-day-task'));
    });

    test('should separate allTasks and todayTasks correctly', () async {
      // Arrange
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Task in current window (started yesterday, ends tomorrow)
      final windowTask = createTestTask(
        id: 'window-task',
        windowStartTime: today.subtract(const Duration(days: 1)),
        windowEndTime: today.add(const Duration(days: 1)),
        status: TaskStatus.active,
      );

      // Task starting today but window not started yet
      final todayFutureTask = createTestTask(
        id: 'today-future-task',
        windowStartTime: today.add(const Duration(hours: 20)),
        windowEndTime: today.add(const Duration(hours: 23)),
        status: TaskStatus.active,
      );

      when(mockTaskRepository.getFutureTasks('test-user-123'))
          .thenAnswer((_) async => [windowTask]); // Only current window
      when(mockTaskRepository.getTodayTasks('test-user-123'))
          .thenAnswer((_) async => [windowTask, todayFutureTask]); // Both today

      container = createContainer();

      // Act
      await container.read(taskListNotifierProvider.future);

      // Assert
      final state = container.read(taskListNotifierProvider).value!;
      expect(state.allTasks.length, equals(1));
      expect(state.allTasks.first.id, equals('window-task'));
      expect(state.todayTasks.length, equals(2));
    });
  });

  group('TaskListNotifier - Status Filtering', () {
    test('should filter activeTasks from allTasks (windowTasks)', () async {
      // Arrange
      final now = DateTime.now();
      final windowStart = now.subtract(const Duration(hours: 1));
      final windowEnd = now.add(const Duration(hours: 1));

      final activeTask = createTestTask(
        id: 'active-task',
        windowStartTime: windowStart,
        windowEndTime: windowEnd,
        status: TaskStatus.active,
      );

      final completedTask = createTestTask(
        id: 'completed-task',
        windowStartTime: windowStart,
        windowEndTime: windowEnd,
        status: TaskStatus.completed,
      );

      when(mockTaskRepository.getFutureTasks('test-user-123'))
          .thenAnswer((_) async => [activeTask, completedTask]);
      when(mockTaskRepository.getTodayTasks('test-user-123'))
          .thenAnswer((_) async => [activeTask, completedTask]);

      container = createContainer();

      // Act
      await container.read(taskListNotifierProvider.future);

      // Assert
      final state = container.read(taskListNotifierProvider).value!;
      expect(state.allTasks.length, equals(2));
      expect(state.activeTasks.length, equals(1));
      expect(state.activeTasks.first.id, equals('active-task'));
      expect(state.completedTasks.length, equals(1));
      expect(state.completedTasks.first.id, equals('completed-task'));
    });
  });

  group('TaskListNotifier - Task Filtering', () {
    test('setFilter should filter based on allTasks not todayTasks', () async {
      // Arrange
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final windowActiveTask = createTestTask(
        id: 'window-active',
        windowStartTime: now.subtract(const Duration(hours: 1)),
        windowEndTime: now.add(const Duration(hours: 1)),
        status: TaskStatus.active,
      );

      final windowCompletedTask = createTestTask(
        id: 'window-completed',
        windowStartTime: now.subtract(const Duration(hours: 1)),
        windowEndTime: now.add(const Duration(hours: 1)),
        status: TaskStatus.completed,
      );

      // Extra task in todayTasks but not in window
      final todayOnlyTask = createTestTask(
        id: 'today-only',
        windowStartTime: today.add(const Duration(hours: 20)),
        windowEndTime: today.add(const Duration(hours: 23)),
        status: TaskStatus.active,
      );

      when(mockTaskRepository.getFutureTasks('test-user-123'))
          .thenAnswer((_) async => [windowActiveTask, windowCompletedTask]);
      when(mockTaskRepository.getTodayTasks('test-user-123'))
          .thenAnswer((_) async => [windowActiveTask, windowCompletedTask, todayOnlyTask]);

      container = createContainer();
      await container.read(taskListNotifierProvider.future);

      // Act - Set filter to active only
      container.read(taskListNotifierProvider.notifier).setFilter(TaskFilter.active);

      // Assert
      final state = container.read(taskListNotifierProvider).value!;
      expect(state.filteredTasks.length, equals(1)); // Only from allTasks
      expect(state.filteredTasks.first.id, equals('window-active'));
    });

    test('setFilter to completed should only filter from allTasks', () async {
      // Arrange
      final now = DateTime.now();
      final windowStart = now.subtract(const Duration(hours: 1));
      final windowEnd = now.add(const Duration(hours: 1));

      final activeTask = createTestTask(
        id: 'active-task',
        windowStartTime: windowStart,
        windowEndTime: windowEnd,
        status: TaskStatus.active,
      );

      final completedTask = createTestTask(
        id: 'completed-task',
        windowStartTime: windowStart,
        windowEndTime: windowEnd,
        status: TaskStatus.completed,
      );

      when(mockTaskRepository.getFutureTasks('test-user-123'))
          .thenAnswer((_) async => [activeTask, completedTask]);
      when(mockTaskRepository.getTodayTasks('test-user-123'))
          .thenAnswer((_) async => [activeTask, completedTask]);

      container = createContainer();
      await container.read(taskListNotifierProvider.future);

      // Act
      container.read(taskListNotifierProvider.notifier).setFilter(TaskFilter.completed);

      // Assert
      final state = container.read(taskListNotifierProvider).value!;
      expect(state.filteredTasks.length, equals(1));
      expect(state.filteredTasks.first.id, equals('completed-task'));
    });
  });

  group('TaskListNotifier - Real-world Scenarios', () {
    test('Weekly task scenario: completed task should not be in allTasks after window expires', () async {
      // Arrange
      // Last week's task window (already expired)
      // We don't need to create the task object since getTasksInCurrentWindow
      // won't return it anyway (window expired)

      // Current window is empty (next week's task not generated yet)
      when(mockTaskRepository.getFutureTasks('test-user-123'))
          .thenAnswer((_) async => []);
      when(mockTaskRepository.getTodayTasks('test-user-123'))
          .thenAnswer((_) async => []);

      container = createContainer();

      // Act
      await container.read(taskListNotifierProvider.future);

      // Assert
      final state = container.read(taskListNotifierProvider).value!;
      expect(state.allTasks.length, equals(0)); // Last week task not in current window
    });

    test('Monthly task scenario: task should be in allTasks throughout the month', () async {
      // Arrange
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1)
          .subtract(const Duration(milliseconds: 1));

      final monthlyTask = createTestTask(
        id: 'monthly-task',
        windowStartTime: monthStart,
        windowEndTime: monthEnd,
        status: TaskStatus.active,
      );

      when(mockTaskRepository.getFutureTasks('test-user-123'))
          .thenAnswer((_) async => [monthlyTask]);
      when(mockTaskRepository.getTodayTasks('test-user-123'))
          .thenAnswer((_) async => [monthlyTask]);

      container = createContainer();

      // Act
      await container.read(taskListNotifierProvider.future);

      // Assert
      final state = container.read(taskListNotifierProvider).value!;
      expect(state.allTasks.length, equals(1));
      expect(state.allTasks.first.id, equals('monthly-task'));
    });

    test('Multiple plans scenario: allTasks count should equal number of active plans (ideal case)', () async {
      // Arrange
      final now = DateTime.now();
      final windowStart = now.subtract(const Duration(hours: 1));
      final windowEnd = now.add(const Duration(hours: 1));

      // Simulate 3 active plans, each with 1 current window task
      final task1 = createTestTask(
        id: 'task-1',
        planId: 'plan-1',
        windowStartTime: windowStart,
        windowEndTime: windowEnd,
        status: TaskStatus.active,
      );

      final task2 = createTestTask(
        id: 'task-2',
        planId: 'plan-2',
        windowStartTime: windowStart,
        windowEndTime: windowEnd,
        status: TaskStatus.completed,
      );

      final task3 = createTestTask(
        id: 'task-3',
        planId: 'plan-3',
        windowStartTime: windowStart,
        windowEndTime: windowEnd,
        status: TaskStatus.active,
      );

      when(mockTaskRepository.getFutureTasks('test-user-123'))
          .thenAnswer((_) async => [task1, task2, task3]);
      when(mockTaskRepository.getTodayTasks('test-user-123'))
          .thenAnswer((_) async => [task1, task2, task3]);

      container = createContainer();

      // Act
      await container.read(taskListNotifierProvider.future);

      // Assert
      final state = container.read(taskListNotifierProvider).value!;
      expect(state.allTasks.length, equals(3)); // One task per plan
      expect(state.activeTasks.length, equals(2));
      expect(state.completedTasks.length, equals(1));
    });
  });

  group('TaskListNotifier - Edge Cases', () {
    test('should handle empty task lists', () async {
      // Arrange
      when(mockTaskRepository.getFutureTasks('test-user-123'))
          .thenAnswer((_) async => []);
      when(mockTaskRepository.getTodayTasks('test-user-123'))
          .thenAnswer((_) async => []);

      container = createContainer();

      // Act
      await container.read(taskListNotifierProvider.future);

      // Assert
      final state = container.read(taskListNotifierProvider).value!;
      expect(state.allTasks.length, equals(0));
      expect(state.todayTasks.length, equals(0));
      expect(state.activeTasks.length, equals(0));
      expect(state.completedTasks.length, equals(0));
    });

    test('should handle tasks at exact window boundary', () async {
      // Arrange
      final now = DateTime.now();

      // Task where windowEndTime equals current time
      final taskEndingNow = createTestTask(
        id: 'ending-now',
        windowStartTime: now.subtract(const Duration(hours: 1)),
        windowEndTime: now,
        status: TaskStatus.active,
      );

      when(mockTaskRepository.getFutureTasks('test-user-123'))
          .thenAnswer((_) async => [taskEndingNow]); // DAO should include it (<=)
      when(mockTaskRepository.getTodayTasks('test-user-123'))
          .thenAnswer((_) async => [taskEndingNow]);

      container = createContainer();

      // Act
      await container.read(taskListNotifierProvider.future);

      // Assert
      final state = container.read(taskListNotifierProvider).value!;
      expect(state.allTasks.length, equals(1));
    });
  });
}
