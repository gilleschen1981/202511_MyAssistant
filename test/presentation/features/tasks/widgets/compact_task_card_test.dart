import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/presentation/features/tasks/widgets/compact_task_card.dart';

void main() {
  // Helper function to create a test task
  TaskModel createTestTask({
    String id = 'task-123',
    String name = 'Test Task',
    TaskStatus status = TaskStatus.active,
    TaskConfiguration? config,
    int currentCount = 0,
  }) {
    final now = DateTime.now();
    return TaskModel(
      id: id,
      userId: 'user-123',
      planId: 'plan-123',
      name: name,
      config: config ?? const TaskConfiguration(),
      status: status,
      currentCount: currentCount,
      windowStartTime: now.subtract(const Duration(hours: 1)),
      windowEndTime: now.add(const Duration(days: 1)),
      createdAt: now,
    );
  }

  // Helper function to create a widget with the card
  Widget createCardWidget(TaskModel task, {VoidCallback? onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: CompactTaskCard(
          task: task,
          onTap: onTap,
        ),
      ),
    );
  }

  group('CompactTaskCard - Task Type Rendering', () {
    testWidgets('should render simple task without task info', (tester) async {
      // Arrange
      final task = createTestTask(name: 'Simple Task');

      // Act
      await tester.pumpWidget(createCardWidget(task));

      // Assert
      expect(find.text('Simple Task'), findsOneWidget);
      // Simple task should have empty info text
      expect(find.text(''), findsWidgets);
    });

    testWidgets('should render timer task with duration', (tester) async {
      // Arrange
      final task = createTestTask(
        name: 'Timer Task',
        config: const TaskConfiguration(durationMinutes: 25),
      );

      // Act
      await tester.pumpWidget(createCardWidget(task));

      // Assert
      expect(find.text('Timer Task'), findsOneWidget);
      expect(find.text('25分钟'), findsOneWidget);
    });

    testWidgets('should render counter task with progress', (tester) async {
      // Arrange
      final task = createTestTask(
        name: 'Counter Task',
        config: const TaskConfiguration(repeatCount: 10),
        currentCount: 5,
      );

      // Act
      await tester.pumpWidget(createCardWidget(task));

      // Assert
      expect(find.text('Counter Task'), findsOneWidget);
      expect(find.text('(5/10)'), findsOneWidget);
    });

    testWidgets('should render evaluation task', (tester) async {
      // Arrange
      final task = createTestTask(
        name: 'Evaluation Task',
        config: const TaskConfiguration(
          evaluationOptions: ['Good', 'Bad'],
        ),
      );

      // Act
      await tester.pumpWidget(createCardWidget(task));

      // Assert
      expect(find.text('Evaluation Task'), findsOneWidget);
      expect(find.text('⭐ 评价'), findsOneWidget);
    });

    testWidgets('should render timer+counter task', (tester) async {
      // Arrange
      final task = createTestTask(
        name: 'Timer+Counter Task',
        config: const TaskConfiguration(
          durationMinutes: 30,
          repeatCount: 5,
        ),
        currentCount: 2,
      );

      // Act
      await tester.pumpWidget(createCardWidget(task));

      // Assert
      expect(find.text('Timer+Counter Task'), findsOneWidget);
      expect(find.text('30分×(2/5)'), findsOneWidget);
    });

    testWidgets('should render counter+evaluation task', (tester) async {
      // Arrange
      final task = createTestTask(
        name: 'Counter+Evaluation Task',
        config: const TaskConfiguration(
          repeatCount: 3,
          evaluationOptions: ['Excellent', 'Good', 'Poor'],
        ),
        currentCount: 1,
      );

      // Act
      await tester.pumpWidget(createCardWidget(task));

      // Assert
      expect(find.text('Counter+Evaluation Task'), findsOneWidget);
      expect(find.text('(1/3)·⭐评价'), findsOneWidget);
    });
  });

  group('CompactTaskCard - Task Status Display', () {
    testWidgets('should display active task with white background and blue border', (tester) async {
      // Arrange
      final task = createTestTask(
        name: 'Active Task',
        status: TaskStatus.active,
      );

      // Act
      await tester.pumpWidget(createCardWidget(task));

      // Assert
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CompactTaskCard),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(decoration.border, isNotNull);
      expect((decoration.border as Border).left.color, const Color(0xFF2196F3));
    });

    testWidgets('should display completed task with green background', (tester) async {
      // Arrange
      final task = createTestTask(
        name: 'Completed Task',
        status: TaskStatus.completed,
      );

      // Act
      await tester.pumpWidget(createCardWidget(task));

      // Assert
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CompactTaskCard),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFE8F5E9));
      expect(decoration.border, isNull);
    });

    testWidgets('should display skipped task with gray background and strikethrough', (tester) async {
      // Arrange
      final task = createTestTask(
        name: 'Skipped Task',
        status: TaskStatus.skipped,
      );

      // Act
      await tester.pumpWidget(createCardWidget(task));

      // Assert
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CompactTaskCard),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFF5F5F5));
      expect(decoration.border, isNull);

      // Check for strikethrough text
      final textWidget = tester.widget<Text>(find.text('Skipped Task'));
      expect(textWidget.style?.decoration, TextDecoration.lineThrough);
    });
  });

  group('CompactTaskCard - Interactions', () {
    testWidgets('should trigger onTap callback when tapped', (tester) async {
      // Arrange
      bool tapped = false;
      final task = createTestTask(name: 'Tappable Task');

      // Act
      await tester.pumpWidget(createCardWidget(task, onTap: () {
        tapped = true;
      }));
      await tester.tap(find.byType(CompactTaskCard));

      // Assert
      expect(tapped, true);
    });

    testWidgets('should trigger onTapWithPosition callback with position', (tester) async {
      // Arrange
      Offset? tapPosition;
      final task = createTestTask(name: 'Position Task');

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactTaskCard(
              task: task,
              onTapWithPosition: (position) {
                tapPosition = position;
              },
            ),
          ),
        ),
      );

      // Tap at the center of the widget
      await tester.tap(find.byType(CompactTaskCard));
      await tester.pump();

      // Assert
      expect(tapPosition, isNotNull);
      // Position should be the global position where the tap occurred
      expect(tapPosition!.dx, greaterThan(0));
      expect(tapPosition!.dy, greaterThan(0));
    });

    testWidgets('should not crash when no callbacks provided', (tester) async {
      // Arrange
      final task = createTestTask(name: 'No Callback Task');

      // Act & Assert - should not throw
      await tester.pumpWidget(createCardWidget(task));
      await tester.tap(find.byType(CompactTaskCard));
      await tester.pump();
    });
  });

  group('CompactTaskCard - Text Overflow', () {
    testWidgets('should truncate long task name with ellipsis', (tester) async {
      // Arrange
      final task = createTestTask(
        name: 'This is a very long task name that should be truncated with ellipsis',
      );

      // Act
      await tester.pumpWidget(createCardWidget(task));

      // Assert
      final textWidget = tester.widget<Text>(
        find.text('This is a very long task name that should be truncated with ellipsis'),
      );
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });
  });
}
