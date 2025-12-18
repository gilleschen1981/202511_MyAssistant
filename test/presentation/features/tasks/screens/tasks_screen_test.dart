import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/data/models/enums/task_filter.dart';
import 'package:myassistant/presentation/providers/task_list_notifier.dart';
import 'package:myassistant/presentation/features/tasks/screens/tasks_screen.dart';
import 'package:myassistant/presentation/features/tasks/widgets/compact_task_card.dart';
import 'package:myassistant/presentation/features/tasks/widgets/task_filter_bar.dart';

void main() {
  // Helper function to create a test task
  TaskModel createTestTask({
    String id = 'task-123',
    String name = 'Test Task',
    TaskStatus status = TaskStatus.active,
    DateTime? windowStartTime,
    DateTime? windowEndTime,
  }) {
    final now = DateTime.now();
    return TaskModel(
      id: id,
      userId: 'user-123',
      planId: 'plan-123',
      name: name,
      config: const TaskConfiguration(),
      windowStartTime: windowStartTime ?? now.subtract(const Duration(hours: 1)),
      windowEndTime: windowEndTime ?? now.add(const Duration(days: 1)),
      status: status,
      createdAt: now,
    );
  }

  // Helper function to create a widget with provider overrides
  Widget createTasksScreen({
    required AsyncValue<TaskListState> taskListState,
  }) {
    return ProviderScope(
      overrides: [
        // Override the provider with a fixed AsyncValue
        taskListNotifierProvider.overrideWith(() => TestTaskListNotifier(taskListState)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: TasksScreen(),
        ),
      ),
    );
  }

  group('TasksScreen - Widget Rendering', () {
    testWidgets('should display loading indicator when loading', (tester) async {
      // Arrange
      const taskListState = AsyncValue<TaskListState>.loading();

      // Act
      await tester.pumpWidget(createTasksScreen(taskListState: taskListState));
      await tester.pump();

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display error message when has error', (tester) async {
      // Arrange
      const error = 'Database connection failed';
      final taskListState = AsyncValue<TaskListState>.error(
        error,
        StackTrace.empty,
      );

      // Act
      await tester.pumpWidget(createTasksScreen(taskListState: taskListState));
      await tester.pump();

      // Assert
      expect(find.textContaining('Error:'), findsOneWidget);
      expect(find.textContaining(error), findsOneWidget);
    });

    testWidgets('should display empty state when no tasks', (tester) async {
      // Arrange
      final taskListState = AsyncValue.data(
        TaskListState.initial(),
      );

      // Act
      await tester.pumpWidget(createTasksScreen(taskListState: taskListState));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('暂无任务'), findsOneWidget);
      expect(find.text('创建计划后将自动生成任务'), findsOneWidget);
      expect(find.byIcon(Icons.task_alt), findsOneWidget);
    });

    testWidgets('should display filter bar in empty state', (tester) async {
      // Arrange
      final taskListState = AsyncValue.data(
        TaskListState.initial(),
      );

      // Act
      await tester.pumpWidget(createTasksScreen(taskListState: taskListState));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(TaskFilterBar), findsOneWidget);
    });

    testWidgets('should display tasks when task list is not empty', (tester) async {
      // Arrange
      final now = DateTime.now();
      final tasks = [
        createTestTask(
          id: 'task-1',
          name: 'Task 1',
          windowEndTime: now.add(const Duration(hours: 2)),
        ),
        createTestTask(
          id: 'task-2',
          name: 'Task 2',
          windowEndTime: now.add(const Duration(hours: 5)),
        ),
      ];

      final taskListState = AsyncValue.data(
        TaskListState(
          allTasks: tasks,
          todayTasks: tasks,
          activeTasks: tasks,
          completedTasks: const [],
          filteredTasks: tasks,
          activeSessions: const {},
        ),
      );

      // Act
      await tester.pumpWidget(createTasksScreen(taskListState: taskListState));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CompactTaskCard), findsNWidgets(2));
    });

    testWidgets('should display undo button', (tester) async {
      // Arrange
      final tasks = [createTestTask()];
      final taskListState = AsyncValue.data(
        TaskListState(
          allTasks: tasks,
          todayTasks: tasks,
          activeTasks: tasks,
          completedTasks: const [],
          filteredTasks: tasks,
          activeSessions: const {},
        ),
      );

      // Act
      await tester.pumpWidget(createTasksScreen(taskListState: taskListState));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.undo), findsOneWidget);
    });
  });

  group('TasksScreen - Task Grouping', () {
    testWidgets('should group tasks by deadline', (tester) async {
      // Arrange
      final now = DateTime.now();
      final tasks = [
        createTestTask(
          id: 'task-today',
          name: 'Today Task',
          windowEndTime: now.add(const Duration(hours: 2)),
        ),
        createTestTask(
          id: 'task-tomorrow',
          name: 'Tomorrow Task',
          windowEndTime: now.add(const Duration(days: 1)),
        ),
      ];

      final taskListState = AsyncValue.data(
        TaskListState(
          allTasks: tasks,
          todayTasks: tasks,
          activeTasks: tasks,
          completedTasks: const [],
          filteredTasks: tasks,
          activeSessions: const {},
        ),
      );

      // Act
      await tester.pumpWidget(createTasksScreen(taskListState: taskListState));
      await tester.pumpAndSettle();

      // Assert
      // Should show group headers
      expect(find.byIcon(Icons.arrow_drop_down), findsWidgets);
    });

    testWidgets('should toggle group expansion on tap', (tester) async {
      // Arrange
      final now = DateTime.now();
      final tasks = [
        createTestTask(
          id: 'task-1',
          windowEndTime: now.add(const Duration(hours: 2)),
        ),
      ];

      final taskListState = AsyncValue.data(
        TaskListState(
          allTasks: tasks,
          todayTasks: tasks,
          activeTasks: tasks,
          completedTasks: const [],
          filteredTasks: tasks,
          activeSessions: const {},
        ),
      );

      // Act
      await tester.pumpWidget(createTasksScreen(taskListState: taskListState));
      await tester.pumpAndSettle();

      // Find and tap the group header (today group should be expanded by default)
      final dropDownIcon = find.byIcon(Icons.arrow_drop_down).first;
      expect(dropDownIcon, findsOneWidget);

      // Tap to collapse
      await tester.tap(dropDownIcon);
      await tester.pumpAndSettle();

      // Assert - should change to arrow_right
      expect(find.byIcon(Icons.arrow_right), findsWidgets);
    });
  });

  group('TasksScreen - Interactions', () {
    testWidgets('should show RefreshIndicator for pull to refresh', (tester) async {
      // Arrange
      final tasks = [createTestTask()];
      final taskListState = AsyncValue.data(
        TaskListState(
          allTasks: tasks,
          todayTasks: tasks,
          activeTasks: tasks,
          completedTasks: const [],
          filteredTasks: tasks,
          activeSessions: const {},
        ),
      );

      // Act
      await tester.pumpWidget(createTasksScreen(taskListState: taskListState));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });
}

/// Test implementation of TaskListNotifier that returns a fixed state
class TestTaskListNotifier extends TaskListNotifier {
  final AsyncValue<TaskListState> _state;

  TestTaskListNotifier(this._state);

  @override
  Future<TaskListState> build() {
    return _state.when(
      data: (data) => Future.value(data),
      loading: () {
        // Return a never-completing future to simulate loading
        return Completer<TaskListState>().future;
      },
      error: (error, stack) => Future.error(error, stack),
    );
  }

  @override
  Future<void> refreshTasks() async {
    // No-op for tests
  }
}
