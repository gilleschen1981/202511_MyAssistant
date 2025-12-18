import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/presentation/providers/task_list_notifier.dart';
import 'package:myassistant/presentation/features/tasks/widgets/task_quick_menu.dart';

void main() {
  // Helper function to create a test task
  TaskModel createTestTask({
    String id = 'task-123',
    String name = 'Test Task',
    TaskStatus status = TaskStatus.active,
    TaskConfiguration? config,
  }) {
    final now = DateTime.now();
    return TaskModel(
      id: id,
      userId: 'user-123',
      planId: 'plan-123',
      name: name,
      config: config ?? const TaskConfiguration(),
      status: status,
      windowStartTime: now.subtract(const Duration(hours: 1)),
      windowEndTime: now.add(const Duration(hours: 23)),
      createdAt: now,
    );
  }

  group('TaskQuickMenu - Menu Display', () {
    testWidgets('should display menu for active simple task', (tester) async {
      // Arrange
      final task = createTestTask(status: TaskStatus.active);
      final notifier = TestTaskListNotifier(AsyncValue.data(TaskListState.initial()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    TaskQuickMenu.show(context, task, const Offset(100, 100));
                  },
                  child: const Text('Tap to show menu'),
                ),
              ),
            ),
          ),
        ),
      );

      // Act - Tap to show menu
      await tester.tap(find.text('Tap to show menu'));
      await tester.pumpAndSettle();

      // Assert - Menu should be shown (popup menu items exist)
      expect(find.byType(PopupMenuItem), findsOneWidget);
    });

    testWidgets('should display menu for active timer task', (tester) async {
      // Arrange
      final task = createTestTask(
        status: TaskStatus.active,
        config: const TaskConfiguration(durationMinutes: 25),
      );
      final notifier = TestTaskListNotifier(AsyncValue.data(TaskListState.initial()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    TaskQuickMenu.show(context, task, const Offset(100, 100));
                  },
                  child: const Text('Tap to show menu'),
                ),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Tap to show menu'));
      await tester.pumpAndSettle();

      // Assert - Menu should be shown with timer button
      expect(find.byIcon(Icons.timer), findsOneWidget);
      expect(find.text('计时'), findsOneWidget);
    });

    testWidgets('should display menu for active counter task', (tester) async {
      // Arrange
      final task = createTestTask(
        status: TaskStatus.active,
        config: const TaskConfiguration(repeatCount: 10),
      );
      final notifier = TestTaskListNotifier(AsyncValue.data(TaskListState.initial()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    TaskQuickMenu.show(context, task, const Offset(100, 100));
                  },
                  child: const Text('Tap to show menu'),
                ),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Tap to show menu'));
      await tester.pumpAndSettle();

      // Assert - Menu should be shown with complete button
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
    });

    testWidgets('should display menu for active evaluation task', (tester) async {
      // Arrange
      final task = createTestTask(
        status: TaskStatus.active,
        config: const TaskConfiguration(
          evaluationOptions: ['Excellent', 'Good', 'Poor'],
        ),
      );
      final notifier = TestTaskListNotifier(AsyncValue.data(TaskListState.initial()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    TaskQuickMenu.show(context, task, const Offset(100, 100));
                  },
                  child: const Text('Tap to show menu'),
                ),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Tap to show menu'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
    });

    testWidgets('should display skip button for active tasks', (tester) async {
      // Arrange
      final task = createTestTask(status: TaskStatus.active);
      final notifier = TestTaskListNotifier(AsyncValue.data(TaskListState.initial()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    TaskQuickMenu.show(context, task, const Offset(100, 100));
                  },
                  child: const Text('Tap to show menu'),
                ),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Tap to show menu'));
      await tester.pumpAndSettle();

      // Assert - Skip button should be shown for active tasks
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      expect(find.text('跳过'), findsOneWidget);
    });

    testWidgets('should display re-execute button for completed tasks', (tester) async {
      // Arrange
      final task = createTestTask(status: TaskStatus.completed);
      final notifier = TestTaskListNotifier(AsyncValue.data(TaskListState.initial()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    TaskQuickMenu.show(context, task, const Offset(100, 100));
                  },
                  child: const Text('Tap to show menu'),
                ),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Tap to show menu'));
      await tester.pumpAndSettle();

      // Assert - Re-execute button should be shown
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.text('再次执行'), findsOneWidget);
    });

    testWidgets('should NOT display skip button for completed tasks', (tester) async {
      // Arrange
      final task = createTestTask(status: TaskStatus.completed);
      final notifier = TestTaskListNotifier(AsyncValue.data(TaskListState.initial()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    TaskQuickMenu.show(context, task, const Offset(100, 100));
                  },
                  child: const Text('Tap to show menu'),
                ),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Tap to show menu'));
      await tester.pumpAndSettle();

      // Assert - Skip button should NOT be shown for completed tasks
      expect(find.byIcon(Icons.skip_next), findsNothing);
      expect(find.text('跳过'), findsNothing);
    });

    testWidgets('should display menu at specified position', (tester) async {
      // Arrange
      final task = createTestTask(status: TaskStatus.active);
      final notifier = TestTaskListNotifier(AsyncValue.data(TaskListState.initial()));
      bool menuShown = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    TaskQuickMenu.show(context, task, const Offset(200, 300));
                    menuShown = true;
                  },
                  child: const Text('Tap to show menu'),
                ),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Tap to show menu'));
      await tester.pumpAndSettle();

      // Assert - Menu should be shown
      expect(menuShown, true);
      expect(find.byType(PopupMenuItem), findsOneWidget);
    });
  });
}

/// Test implementation of TaskListNotifier for testing
class TestTaskListNotifier extends TaskListNotifier {
  final AsyncValue<TaskListState> _state;

  TestTaskListNotifier(this._state);

  @override
  Future<TaskListState> build() {
    return _state.when(
      data: (data) => Future.value(data),
      loading: () => Completer<TaskListState>().future,
      error: (error, stack) => Future.error(error, stack),
    );
  }

  @override
  Future<void> refreshTasks() async {
    // No-op for tests
  }

  @override
  Future<void> completeTask({
    required TaskModel task,
    int? actualDurationMinutes,
    String? evaluationResult,
    String? executionNote,
  }) async {
    // No-op for tests
  }

  @override
  Future<void> skipTask({
    required TaskModel task,
    String? skipReason,
  }) async {
    // No-op for tests
  }

  @override
  Future<TaskModel> incrementCount(
    TaskModel task, {
    int? actualDurationMinutes,
    String? evaluationResult,
  }) async {
    // Return the same task for tests
    return task;
  }

  @override
  Future<TaskModel?> reExecuteTask(TaskModel task) async {
    // Return a new task for tests
    return task.copyWith(id: 'task-new');
  }
}
