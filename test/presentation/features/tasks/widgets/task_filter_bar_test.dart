import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/enums/task_filter.dart';
import 'package:myassistant/presentation/providers/task_list_notifier.dart';
import 'package:myassistant/presentation/features/tasks/widgets/task_filter_bar.dart';

void main() {
  // Helper function to create a widget with provider overrides
  Widget createFilterBarWidget({
    required AsyncValue<TaskListState> taskListState,
  }) {
    return ProviderScope(
      overrides: [
        taskListNotifierProvider.overrideWith(() => TestTaskListNotifier(taskListState)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: TaskFilterBar(),
        ),
      ),
    );
  }

  group('TaskFilterBar - Filter Options Display', () {
    testWidgets('should display all filter options', (tester) async {
      // Arrange
      final taskListState = AsyncValue.data(
        TaskListState.initial(),
      );

      // Act
      await tester.pumpWidget(createFilterBarWidget(taskListState: taskListState));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('待执行'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      expect(find.text('已跳过'), findsOneWidget);
    });

    testWidgets('should display 4 filter chips', (tester) async {
      // Arrange
      final taskListState = AsyncValue.data(
        TaskListState.initial(),
      );

      // Act
      await tester.pumpWidget(createFilterBarWidget(taskListState: taskListState));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(FilterChip), findsNWidgets(4));
    });

    testWidgets('should highlight "all" filter by default', (tester) async {
      // Arrange
      final taskListState = AsyncValue.data(
        TaskListState.initial(), // currentFilter defaults to TaskFilter.all
      );

      // Act
      await tester.pumpWidget(createFilterBarWidget(taskListState: taskListState));
      await tester.pumpAndSettle();

      // Assert
      final allFilterChip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('全部'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(allFilterChip.selected, true);
    });

    testWidgets('should highlight "active" filter when selected', (tester) async {
      // Arrange
      final taskListState = AsyncValue.data(
        TaskListState.initial().copyWith(currentFilter: TaskFilter.active),
      );

      // Act
      await tester.pumpWidget(createFilterBarWidget(taskListState: taskListState));
      await tester.pumpAndSettle();

      // Assert
      final activeFilterChip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('待执行'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(activeFilterChip.selected, true);

      // All other filters should not be selected
      final allFilterChip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('全部'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(allFilterChip.selected, false);
    });

    testWidgets('should highlight "completed" filter when selected', (tester) async {
      // Arrange
      final taskListState = AsyncValue.data(
        TaskListState.initial().copyWith(currentFilter: TaskFilter.completed),
      );

      // Act
      await tester.pumpWidget(createFilterBarWidget(taskListState: taskListState));
      await tester.pumpAndSettle();

      // Assert
      final completedFilterChip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('已完成'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(completedFilterChip.selected, true);
    });

    testWidgets('should highlight "skipped" filter when selected', (tester) async {
      // Arrange
      final taskListState = AsyncValue.data(
        TaskListState.initial().copyWith(currentFilter: TaskFilter.skipped),
      );

      // Act
      await tester.pumpWidget(createFilterBarWidget(taskListState: taskListState));
      await tester.pumpAndSettle();

      // Assert
      final skippedFilterChip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('已跳过'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(skippedFilterChip.selected, true);
    });
  });

  group('TaskFilterBar - Loading and Error States', () {
    testWidgets('should show empty widget when loading', (tester) async {
      // Arrange
      const taskListState = AsyncValue<TaskListState>.loading();

      // Act
      await tester.pumpWidget(createFilterBarWidget(taskListState: taskListState));
      await tester.pump();

      // Assert
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('should show empty widget when error', (tester) async {
      // Arrange
      const error = 'Database error';
      const taskListState = AsyncValue<TaskListState>.error(
        error,
        StackTrace.empty,
      );

      // Act
      await tester.pumpWidget(createFilterBarWidget(taskListState: taskListState));
      await tester.pump();

      // Assert
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });
  });

  group('TaskFilterBar - Interactions', () {
    testWidgets('should call setFilter when tapping filter chip', (tester) async {
      // Arrange
      final notifier = TestTaskListNotifier(AsyncValue.data(TaskListState.initial()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListNotifierProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TaskFilterBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act - Tap on "待执行" filter
      await tester.tap(find.text('待执行'));
      await tester.pumpAndSettle();

      // Assert
      expect(notifier.setFilterCalled, true);
      expect(notifier.lastFilterSet, TaskFilter.active);
    });

    testWidgets('should update visual state when switching filters', (tester) async {
      // Arrange
      final notifier = TestTaskListNotifier(AsyncValue.data(TaskListState.initial()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListNotifierProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TaskFilterBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act - Switch from "全部" to "已完成"
      await tester.tap(find.text('已完成'));
      await tester.pumpAndSettle();

      // Assert
      expect(notifier.lastFilterSet, TaskFilter.completed);
    });
  });
}

/// Test implementation of TaskListNotifier for testing filter interactions
class TestTaskListNotifier extends TaskListNotifier {
  final AsyncValue<TaskListState> _state;
  bool setFilterCalled = false;
  TaskFilter? lastFilterSet;

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
  Future<void> setFilter(TaskFilter filter) async {
    setFilterCalled = true;
    lastFilterSet = filter;
    // Update state to reflect the new filter
    final currentState = await Future.value(_state.value!);
    state = AsyncValue.data(currentState.copyWith(currentFilter: filter));
  }

  @override
  Future<void> refreshTasks() async {
    // No-op for tests
  }
}
