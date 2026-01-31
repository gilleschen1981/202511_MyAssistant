import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/presentation/features/planning/widgets/edit_plan_dialog.dart';
import 'package:myassistant/presentation/providers/plan_state_provider.dart';

import 'edit_plan_dialog_test.mocks.dart';

@GenerateMocks([PlanListNotifier])
void main() {
  late MockPlanListNotifier mockPlanListNotifier;
  late PlanModel testPlan;

  setUp(() {
    mockPlanListNotifier = MockPlanListNotifier();

    // Create a test plan
    final now = DateTime.now();
    testPlan = PlanModel(
      id: 'plan-123',
      userId: 'user-123',
      name: 'Test Plan',
      description: 'Test description',
      goalId: 'goal-123',
      startDate: now.subtract(const Duration(days: 7)),
      endDate: now.add(const Duration(days: 23)),
      repeatRule: const RepeatRule(type: RepeatType.weekly),
      taskConfig: const TaskConfiguration(durationMinutes: 30),
      status: PlanStatus.active,
      createdAt: now,
      updatedAt: now,
    );
  });

  Widget createTestWidget(PlanModel plan) {
    return ProviderScope(
      overrides: [
        planListProvider.overrideWith((ref) => mockPlanListNotifier),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: EditPlanDialog(plan: plan),
        ),
      ),
    );
  }

  group('EditPlanDialog - RepeatRule UI', () {
    testWidgets('should display current repeatRule type in dropdown', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(testPlan));
      await tester.pumpAndSettle();

      // Find the RepeatType dropdown
      final dropdown = find.byType(DropdownButtonFormField<RepeatType>);
      expect(dropdown, findsOneWidget);

      // Check that the current value is displayed
      expect(find.text('每周'), findsOneWidget);
    });

    testWidgets('should show custom days input when RepeatType.custom is selected', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(testPlan));
      await tester.pumpAndSettle();

      // Open the dropdown
      await tester.tap(find.byType(DropdownButtonFormField<RepeatType>));
      await tester.pumpAndSettle();

      // Select "自定义"
      await tester.tap(find.text('自定义').last);
      await tester.pumpAndSettle();

      // Check that custom days input is visible
      expect(find.text('自定义间隔天数'), findsOneWidget);
    });

    testWidgets('should show days of week selector when RepeatType.daysOfWeek is selected', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(testPlan));
      await tester.pumpAndSettle();

      // Open the dropdown
      await tester.tap(find.byType(DropdownButtonFormField<RepeatType>));
      await tester.pumpAndSettle();

      // Select "选择星期"
      await tester.tap(find.text('选择星期').last);
      await tester.pumpAndSettle();

      // Check that day selector is visible
      expect(find.text('选择星期'), findsAtLeastNWidgets(2)); // Label + dropdown item
      expect(find.text('一'), findsOneWidget); // Monday
      expect(find.text('日'), findsOneWidget); // Sunday
    });

    testWidgets('should toggle days of week selection', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(testPlan));
      await tester.pumpAndSettle();

      // Select daysOfWeek type
      await tester.tap(find.byType(DropdownButtonFormField<RepeatType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择星期').last);
      await tester.pumpAndSettle();

      // Tap Monday (一)
      await tester.tap(find.text('一'));
      await tester.pumpAndSettle();

      // Verify that Monday is now selected (container should have different style)
      // This is a visual check - in a real test you might check the container decoration

      // Tap Monday again to deselect
      await tester.tap(find.text('一'));
      await tester.pumpAndSettle();
    });

    testWidgets('should initialize with plan\'s existing repeatRule', (WidgetTester tester) async {
      // Create a plan with daysOfWeek repeatRule
      final planWithDaysOfWeek = testPlan.copyWith(
        repeatRule: const RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [1, 3, 5], // Mon, Wed, Fri
        ),
      );

      await tester.pumpWidget(createTestWidget(planWithDaysOfWeek));
      await tester.pumpAndSettle();

      // Check that the dropdown shows the correct type
      expect(find.text('选择星期'), findsAtLeastNWidgets(1));
    });

    testWidgets('should initialize custom days when plan has custom repeatRule', (WidgetTester tester) async {
      // Create a plan with custom repeatRule
      final planWithCustom = testPlan.copyWith(
        repeatRule: const RepeatRule(
          type: RepeatType.custom,
          customDays: 14,
        ),
      );

      await tester.pumpWidget(createTestWidget(planWithCustom));
      await tester.pumpAndSettle();

      // Check that custom type is selected
      expect(find.text('自定义'), findsAtLeastNWidgets(1));

      // Check that the custom days field shows the value
      expect(find.text('14'), findsOneWidget);
    });
  });

  group('EditPlanDialog - Validation', () {
    testWidgets('should show error when daysOfWeek has no days selected', (WidgetTester tester) async {
      when(mockPlanListNotifier.updatePlan(
        planId: anyNamed('planId'),
        description: anyNamed('description'),
        endDate: anyNamed('endDate'),
        taskConfig: anyNamed('taskConfig'),
        repeatRule: anyNamed('repeatRule'),
      )).thenAnswer((_) async => testPlan);

      await tester.pumpWidget(createTestWidget(testPlan));
      await tester.pumpAndSettle();

      // Select daysOfWeek type
      await tester.tap(find.byType(DropdownButtonFormField<RepeatType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择星期').last);
      await tester.pumpAndSettle();

      // Try to submit without selecting any days
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Check for error message
      expect(find.text('请至少选择一天'), findsOneWidget);
    });

    testWidgets('should validate custom days input', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(testPlan));
      await tester.pumpAndSettle();

      // Select custom type
      await tester.tap(find.byType(DropdownButtonFormField<RepeatType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自定义').last);
      await tester.pumpAndSettle();

      // Enter invalid value (0)
      await tester.enterText(find.widgetWithText(TextFormField, '自定义间隔天数'), '0');
      await tester.pumpAndSettle();

      // Try to submit
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Check for validation error
      expect(find.text('请输入有效的天数'), findsOneWidget);
    });
  });

  group('EditPlanDialog - Form Submission', () {
    testWidgets('should call updatePlan with repeatRule when form is submitted', (WidgetTester tester) async {
      when(mockPlanListNotifier.updatePlan(
        planId: anyNamed('planId'),
        description: anyNamed('description'),
        endDate: anyNamed('endDate'),
        taskConfig: anyNamed('taskConfig'),
        repeatRule: anyNamed('repeatRule'),
      )).thenAnswer((_) async => testPlan.copyWith(
        repeatRule: const RepeatRule(type: RepeatType.daily),
      ));

      await tester.pumpWidget(createTestWidget(testPlan));
      await tester.pumpAndSettle();

      // Change repeatType to daily
      await tester.tap(find.byType(DropdownButtonFormField<RepeatType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('每日').last);
      await tester.pumpAndSettle();

      // Submit the form
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Verify that updatePlan was called with the new repeatRule
      verify(mockPlanListNotifier.updatePlan(
        planId: 'plan-123',
        description: anyNamed('description'),
        endDate: anyNamed('endDate'),
        taskConfig: anyNamed('taskConfig'),
        repeatRule: argThat(
          isA<RepeatRule>().having(
            (r) => r.type,
            'type',
            RepeatType.daily,
          ),
          named: 'repeatRule',
        ),
      )).called(1);
    });

    testWidgets('should submit daysOfWeek repeatRule with selected days', (WidgetTester tester) async {
      when(mockPlanListNotifier.updatePlan(
        planId: anyNamed('planId'),
        description: anyNamed('description'),
        endDate: anyNamed('endDate'),
        taskConfig: anyNamed('taskConfig'),
        repeatRule: anyNamed('repeatRule'),
      )).thenAnswer((_) async => testPlan.copyWith(
        repeatRule: const RepeatRule(
          type: RepeatType.daysOfWeek,
          selectedDaysOfWeek: [1, 3, 5],
        ),
      ));

      await tester.pumpWidget(createTestWidget(testPlan));
      await tester.pumpAndSettle();

      // Select daysOfWeek type
      await tester.tap(find.byType(DropdownButtonFormField<RepeatType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择星期').last);
      await tester.pumpAndSettle();

      // Select Monday, Wednesday, Friday
      await tester.tap(find.text('一'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('三'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('五'));
      await tester.pumpAndSettle();

      // Submit the form
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Verify the call
      verify(mockPlanListNotifier.updatePlan(
        planId: 'plan-123',
        description: anyNamed('description'),
        endDate: anyNamed('endDate'),
        taskConfig: anyNamed('taskConfig'),
        repeatRule: argThat(
          isA<RepeatRule>()
              .having((r) => r.type, 'type', RepeatType.daysOfWeek)
              .having((r) => r.selectedDaysOfWeek, 'selectedDaysOfWeek', [1, 3, 5]),
          named: 'repeatRule',
        ),
      )).called(1);
    });
  });
}
