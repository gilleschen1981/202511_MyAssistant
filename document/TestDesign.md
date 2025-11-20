# 测试设计文档

本文档定义了Flutter任务管理App的完整测试策略、测试用例设计、自动化方案和质量保证标准。

## 平台测试策略

### 测试平台范围
- **目标平台**: Android 专属应用
  - 最低支持: Android 5.0 (API 21)
  - 推荐版本: Android 6.0+ (API 23+)
  - 测试环境: Android Emulator 和物理设备

### 测试环境配置
- **开发测试**: Android Emulator
  - 使用 Android Studio 的 AVD Manager 创建模拟器
  - 推荐配置: Pixel 4 API 30+ for standard testing
  - 多设备测试: 不同屏幕尺寸和Android版本

- **CI/CD测试**: Android Emulator (GitHub Actions)
  - 自动化测试运行在 Android 模拟器
  - API级别: 29 (Android 10)
  - 架构: x86_64 for faster emulation

- **不支持的平台**:
  - iOS: 项目不支持iOS平台
  - Web: 仅作为开发调试用途，不作为发布目标
  - Desktop: 不支持桌面平台

## 1. 测试策略概述

### 1.1 测试金字塔架构

采用经典的测试金字塔模型，确保测试的高效性和全面性：

```
        E2E测试 (5%)
       /         \
    集成测试 (15%)
   /              \
  Widget测试 (30%)
 /                 \
单元测试 (50%)
```

- **单元测试 (50%)**：测试独立的业务逻辑、服务、工具类
- **Widget测试 (30%)**：测试UI组件的渲染和交互
- **集成测试 (15%)**：测试功能模块的完整流程
- **E2E测试 (5%)**：测试关键用户场景的端到端流程

### 1.2 测试覆盖率目标

```
整体覆盖率目标：
├── 总体代码覆盖率: 80%+
├── 核心业务逻辑: 95%+
│   ├── TaskGenerationService: 100%
│   ├── TaskExecutionService: 95%
│   ├── TaskRefreshService: 95%
│   ├── 状态管理Providers: 90%
│   └── 数据库操作: 90%
├── UI组件: 70%+
├── 工具类: 85%+
└── 数据模型: 80%+
```

### 1.3 测试优先级

基于系统的核心功能和风险评估，测试优先级如下：

1. **P0 - 最高优先级**
   - 任务自动生成逻辑
   - 任务状态流转
   - 数据持久化

2. **P1 - 高优先级**
   - 计划管理CRUD
   - 目标进度计算
   - 任务执行（计时/计数/评价）

3. **P2 - 中优先级**
   - UI组件交互
   - 数据统计
   - 导航流程

4. **P3 - 低优先级**
   - 动画效果
   - 主题切换
   - 国际化

## 2. 单元测试设计 (50%)

### 2.1 任务生成服务测试

```dart
// test/unit/services/task_generation_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:myassistant/services/task_generation_service.dart';

void main() {
  group('TaskGenerationService - 任务生成核心逻辑', () {
    late TaskGenerationService service;
    late MockTaskRepository mockTaskRepo;
    late MockPlanRepository mockPlanRepo;

    setUp(() {
      mockTaskRepo = MockTaskRepository();
      mockPlanRepo = MockPlanRepository();
      service = TaskGenerationService(
        taskRepository: mockTaskRepo,
        planRepository: mockPlanRepo,
      );
    });

    group('重复规则测试', () {
      test('每日任务 - 应该每天生成一个新任务', () async {
        // Given
        final plan = TestDataBuilder.createPlan(
          repeatType: RepeatType.daily,
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 12, 31),
        );

        when(mockTaskRepo.getLastTaskForPlan(plan.id))
          .thenAnswer((_) async => null);

        // When
        final task = await service.generateNextTask(plan);

        // Then
        expect(task, isNotNull);
        expect(task!.windowStartTime.day, equals(DateTime.now().day));
        expect(task.windowEndTime.day, equals(DateTime.now().day));
        verify(mockTaskRepo.createTask(any)).called(1);
      });

      test('每周任务 - 应该每周一生成新任务', () async {
        // Given
        final plan = TestDataBuilder.createPlan(
          repeatType: RepeatType.weekly,
          startDate: DateTime(2024, 1, 1),
        );

        final lastWeekTask = TestDataBuilder.createTask(
          planId: plan.id,
          windowStartTime: DateTime.now().subtract(Duration(days: 7)),
          status: TaskStatus.completed,
        );

        when(mockTaskRepo.getLastTaskForPlan(plan.id))
          .thenAnswer((_) async => lastWeekTask);

        // When
        final task = await service.generateNextTask(plan);

        // Then
        expect(task, isNotNull);
        expect(task!.windowStartTime.weekday, equals(DateTime.monday));
      });

      test('每月任务 - 应该在每月1号生成', () async {
        // 测试每月任务生成逻辑
      });

      test('自定义间隔 - N天重复', () async {
        // Given
        final plan = TestDataBuilder.createPlan(
          repeatType: RepeatType.custom,
          customDays: 3,
        );

        final lastTask = TestDataBuilder.createTask(
          planId: plan.id,
          windowStartTime: DateTime(2024, 1, 1),
          windowEndTime: DateTime(2024, 1, 3, 23, 59, 59),
          status: TaskStatus.completed,
        );

        when(mockTaskRepo.getLastTaskForPlan(plan.id))
          .thenAnswer((_) async => lastTask);

        // When
        final task = await service.generateNextTask(plan);

        // Then
        expect(task!.windowStartTime, equals(DateTime(2024, 1, 4)));
      });
    });

    group('边界条件测试', () {
      test('计划开始日期边界 - 不应在开始日期前生成任务', () async {
        // Given
        final futureplan = TestDataBuilder.createPlan(
          startDate: DateTime.now().add(Duration(days: 7)),
        );

        // When
        final task = await service.generateNextTask(futureplan);

        // Then
        expect(task, isNull);
      });

      test('计划结束日期边界 - 不应在结束日期后生成任务', () async {
        // Given
        final expiredPlan = TestDataBuilder.createPlan(
          endDate: DateTime.now().subtract(Duration(days: 1)),
        );

        // When
        final task = await service.generateNextTask(expiredPlan);

        // Then
        expect(task, isNull);
      });

      test('月末边界 - 正确处理不同天数的月份', () async {
        // 测试从1月31日到2月的过渡
        final plan = TestDataBuilder.createPlan(
          repeatType: RepeatType.monthly,
        );

        final januaryTask = TestDataBuilder.createTask(
          windowStartTime: DateTime(2024, 1, 31),
          status: TaskStatus.completed,
        );

        when(mockTaskRepo.getLastTaskForPlan(plan.id))
          .thenAnswer((_) async => januaryTask);

        // When - 2月只有29天（2024是闰年）
        final task = await service.generateNextTask(plan);

        // Then
        expect(task!.windowStartTime, equals(DateTime(2024, 2, 1)));
        expect(task.windowEndTime.day, equals(29));
      });

      test('闰年2月29日处理', () async {
        // 特殊处理闰年的2月29日
      });

      test('跨年任务生成', () async {
        // 测试12月31日到1月1日的过渡
      });
    });

    group('防重机制测试', () {
      test('不应为已有活跃任务的计划生成新任务', () async {
        // Given
        final plan = TestDataBuilder.createPlan();
        final activeTask = TestDataBuilder.createTask(
          planId: plan.id,
          status: TaskStatus.active,
        );

        when(mockTaskRepo.getLastTaskForPlan(plan.id))
          .thenAnswer((_) async => activeTask);

        // When
        final task = await service.generateNextTask(plan);

        // Then
        expect(task, isNull);
        verifyNever(mockTaskRepo.createTask(any));
      });

      test('并发请求不会生成重复任务', () async {
        // Given
        final plan = TestDataBuilder.createPlan();

        when(mockTaskRepo.getLastTaskForPlan(plan.id))
          .thenAnswer((_) async => null);

        // When - 模拟5个并发请求
        final futures = List.generate(5, (_) =>
          service.generateNextTask(plan)
        );

        final results = await Future.wait(futures);

        // Then - 只应该生成一个任务
        final nonNullResults = results.where((r) => r != null).toList();
        expect(nonNullResults.length, equals(1));
      });
    });
  });
}
```

### 2.2 任务执行服务测试

```dart
// test/unit/services/task_execution_service_test.dart
void main() {
  group('TaskExecutionService - 任务执行逻辑', () {
    group('任务状态流转', () {
      test('active -> completed 正常完成流程', () async {
        // Given
        final task = TestDataBuilder.createTask(
          status: TaskStatus.active,
          config: TaskConfiguration(durationMinutes: 30),
        );

        // When
        final result = await service.completeTask(
          task: task,
          actualDurationMinutes: 35,
        );

        // Then
        expect(result.completedTask.status, equals(TaskStatus.completed));
        expect(result.completedTask.actualDurationMinutes, equals(35));
        expect(result.completedTask.completedAt, isNotNull);
      });

      test('active -> skipped 跳过任务', () async {
        // 测试跳过逻辑
      });

      test('已完成任务不能再次修改状态', () async {
        // Given
        final completedTask = TestDataBuilder.createTask(
          status: TaskStatus.completed,
        );

        // When & Then
        expect(
          () => service.completeTask(task: completedTask),
          throwsA(isA<BusinessException>()),
        );
      });

      test('过期任务自动标记为skipped', () async {
        // Given
        final expiredTask = TestDataBuilder.createTask(
          status: TaskStatus.active,
          windowEndTime: DateTime.now().subtract(Duration(hours: 1)),
        );

        // When
        await refreshService.handleExpiredTasks();

        // Then
        final updatedTask = await taskRepo.getTask(expiredTask.id);
        expect(updatedTask!.status, equals(TaskStatus.skipped));
      });
    });

    group('任务配置组合测试', () {
      test('计时+计数组合 - 正确处理番茄钟场景', () async {
        // Given
        final task = TestDataBuilder.createTask(
          config: TaskConfiguration(
            durationMinutes: 25,
            repeatCount: 4,
          ),
          currentCount: 2,
        );

        // When - 完成一个番茄钟
        final result = await service.incrementCount(task);

        // Then
        expect(result.currentCount, equals(3));
        expect(result.status, equals(TaskStatus.active));
      });

      test('计数+评价组合 - 完成时需要评价', () async {
        // Given
        final task = TestDataBuilder.createTask(
          config: TaskConfiguration(
            repeatCount: 5,
            evaluationOptions: ['优秀', '良好', '一般', '较差'],
          ),
          currentCount: 4,
        );

        // When & Then - 未提供评价应该抛出异常
        expect(
          () => service.completeTask(task: task),
          throwsA(isA<ValidationException>()),
        );

        // When - 提供评价
        final result = await service.completeTask(
          task: task,
          evaluationResult: '良好',
        );

        // Then
        expect(result.completedTask.evaluationResult, equals('良好'));
      });

      test('计时和评价互斥验证', () async {
        // Given - 尝试创建非法配置
        expect(
          () => TaskConfiguration(
            durationMinutes: 30,
            evaluationOptions: ['好', '中', '差'],
          ),
          throwsA(isA<BusinessRuleException>()),
        );
      });
    });
  });
}
```

### 2.3 状态管理测试

```dart
// test/unit/providers/task_list_provider_test.dart
void main() {
  group('TaskListProvider - 任务列表状态管理', () {
    test('加载任务列表', () async {
      // Given
      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(MockTaskRepository()),
        ],
      );

      when(mockTaskRepository.getActiveTasksByUserId(any))
        .thenAnswer((_) async => testTasks);

      // When
      final state = await container.read(taskListProvider.future);

      // Then
      expect(state.tasks.length, equals(testTasks.length));
      expect(state.isLoading, isFalse);
    });

    test('过滤任务 - 今日任务', () async {
      // 测试过滤逻辑
    });

    test('任务排序 - 按时间/优先级/名称', () async {
      // 测试排序逻辑
    });
  });
}
```

## 3. Widget测试设计 (30%)

### 3.1 任务卡片组件测试

```dart
// test/widget/features/tasks/task_card_test.dart
void main() {
  group('TaskCard Widget', () {
    testWidgets('显示正确的任务信息', (tester) async {
      // Given
      final task = TestDataBuilder.createTask(
        name: '晨跑',
        config: TaskConfiguration(durationMinutes: 30),
      );

      // When
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(task: task),
          ),
        ),
      );

      // Then
      expect(find.text('晨跑'), findsOneWidget);
      expect(find.text('30分钟'), findsOneWidget);
    });

    testWidgets('任务配置组合显示 - 计时+计数', (tester) async {
      // Given
      final task = TestDataBuilder.createTask(
        name: '番茄钟',
        config: TaskConfiguration(
          durationMinutes: 25,
          repeatCount: 4,
        ),
        currentCount: 2,
      );

      // When
      await tester.pumpWidget(
        TestWrapper(child: TaskCard(task: task)),
      );

      // Then
      expect(find.text('25分×(2/4)'), findsOneWidget);
    });

    testWidgets('任务配置组合显示 - 计数+评价', (tester) async {
      // Given
      final task = TestDataBuilder.createTask(
        name: '冥想练习',
        config: TaskConfiguration(
          repeatCount: 4,
          evaluationOptions: ['优秀', '良好', '一般'],
        ),
        currentCount: 2,
      );

      // When
      await tester.pumpWidget(
        TestWrapper(child: TaskCard(task: task)),
      );

      // Then
      expect(find.text('(2/4)·⭐评价'), findsOneWidget);
    });

    testWidgets('点击任务卡片显示快捷菜单', (tester) async {
      // Given
      final task = TestDataBuilder.createTask();

      // When
      await tester.pumpWidget(
        TestWrapper(child: TaskCard(task: task)),
      );
      await tester.tap(find.byType(TaskCard));
      await tester.pumpAndSettle();

      // Then
      expect(find.text('计时'), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
      expect(find.text('跳过'), findsOneWidget);
    });

    testWidgets('不同状态的视觉样式', (tester) async {
      // 测试active/completed/skipped的不同显示
    });
  });
}
```

### 3.2 计时页面测试

```dart
// test/widget/features/tasks/timer_page_test.dart
void main() {
  group('TimerPage Widget', () {
    testWidgets('计时器倒计时功能', (tester) async {
      // Given
      final task = TestDataBuilder.createTask(
        name: '专注时间',
        config: TaskConfiguration(durationMinutes: 25),
      );

      // When
      await tester.pumpWidget(
        TestWrapper(child: TimerPage(task: task)),
      );

      // Then - 初始显示
      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('专注时间'), findsOneWidget);

      // When - 开始计时
      await tester.tap(find.text('开始'));
      await tester.pump(Duration(seconds: 1));

      // Then - 1秒后
      expect(find.text('24:59'), findsOneWidget);
    });

    testWidgets('暂停/继续功能', (tester) async {
      // 测试暂停和继续计时
    });

    testWidgets('计时完成自动标记任务完成', (tester) async {
      // 测试倒计时结束后的处理
    });
  });
}
```

### 3.3 表单输入测试

```dart
// test/widget/features/plans/plan_form_test.dart
void main() {
  group('PlanForm Widget', () {
    testWidgets('创建计划表单验证', (tester) async {
      // When
      await tester.pumpWidget(
        TestWrapper(child: PlanFormScreen()),
      );

      // 不填写必填字段，直接提交
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Then
      expect(find.text('计划名称不能为空'), findsOneWidget);
      expect(find.text('请选择开始日期'), findsOneWidget);
    });

    testWidgets('任务配置组合选择', (tester) async {
      // 测试不同配置组合的UI交互
    });

    testWidgets('日期选择器边界验证', (tester) async {
      // 测试结束日期不能早于开始日期
    });
  });
}
```

## 4. 集成测试设计 (15%)

### 4.1 完整功能流程测试

```dart
// integration_test/task_lifecycle_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('任务完整生命周期', () {
    testWidgets('从创建目标到完成任务的完整流程', (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      // Step 1: 创建目标
      await tester.tap(find.byIcon(Icons.add));
      await tester.enterText(find.byKey(Key('goal_title')), 'Flutter学习');
      await tester.tap(find.text('高优先级'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('Flutter学习'), findsOneWidget);

      // Step 2: 创建计划
      await tester.tap(find.text('Flutter学习'));
      await tester.tap(find.text('添加计划'));
      await tester.enterText(find.byKey(Key('plan_name')), '每日编码练习');

      // 选择每日重复
      await tester.tap(find.text('重复设置'));
      await tester.tap(find.text('每日'));

      // 设置计时任务
      await tester.tap(find.text('任务配置'));
      await tester.enterText(find.byKey(Key('duration')), '60');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Step 3: 验证任务自动生成
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      expect(find.text('每日编码练习'), findsOneWidget);
      expect(find.text('60分钟'), findsOneWidget);

      // Step 4: 执行任务
      await tester.tap(find.text('每日编码练习'));
      await tester.tap(find.text('计时'));
      await tester.pumpAndSettle();

      // 验证进入计时页面
      expect(find.text('60:00'), findsOneWidget);

      // Step 5: 完成任务
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 验证任务状态更新
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });
}
```

### 4.2 多模块协同测试

```dart
// integration_test/multi_module_test.dart
void main() {
  group('多模块协同测试', () {
    testWidgets('目标-计划-任务级联关系', (tester) async {
      // 创建完整的目标体系
      final goalId = await createGoalWithUI(tester, '健康生活');

      // 创建多个计划
      await createPlanWithUI(tester, goalId, '晨跑', RepeatType.daily);
      await createPlanWithUI(tester, goalId, '瑜伽', RepeatType.weekly);
      await createPlanWithUI(tester, goalId, '体检', RepeatType.monthly);

      // 验证任务生成
      await tester.pump(Duration(seconds: 1));

      expect(find.text('晨跑'), findsOneWidget);  // 每日任务
      expect(find.text('瑜伽'), findsOneWidget);  // 每周任务
      expect(find.text('体检'), findsOneWidget);  // 每月任务

      // 删除目标，验证级联删除
      await deleteGoalWithUI(tester, goalId);

      expect(find.text('晨跑'), findsNothing);
      expect(find.text('瑜伽'), findsNothing);
      expect(find.text('体检'), findsNothing);
    });
  });
}
```

## 5. E2E测试设计 (5%)

### 5.1 关键用户场景

```dart
// e2e_test/critical_user_journeys_test.dart
void main() {
  group('关键用户旅程', () {
    test('新用户首次使用流程', () async {
      // 1. 首次打开应用
      // 2. 创建第一个目标
      // 3. 设置第一个计划
      // 4. 完成第一个任务
      // 5. 查看统计数据
    });

    test('日常使用流程', () async {
      // 1. 打开应用查看今日任务
      // 2. 执行番茄钟任务
      // 3. 完成评价任务
      // 4. 查看进度
    });

    test('数据恢复流程', () async {
      // 1. 创建数据
      // 2. 卸载应用
      // 3. 重新安装
      // 4. 验证数据恢复
    });
  });
}
```

## 6. 特殊场景测试

### 6.1 性能测试

```dart
// test/performance/performance_test.dart
void main() {
  group('性能测试', () {
    testWidgets('大数据量列表滚动性能', (tester) async {
      // Given - 创建1000个任务
      final tasks = List.generate(1000, (i) =>
        TestDataBuilder.createTask(name: 'Task $i')
      );

      // When
      await tester.pumpWidget(
        TestWrapper(child: TaskListScreen(tasks: tasks)),
      );

      // 执行快速滚动
      await tester.timedDrag(
        find.byType(ListView),
        Offset(0, -5000),
        Duration(seconds: 2),
      );

      // Then - 验证帧率
      final FrameTiming timing = await tester.pumpAndSettle();
      expect(timing.rasterDuration.inMilliseconds, lessThan(16)); // 60fps
    });

    test('应用启动时间', () async {
      final stopwatch = Stopwatch()..start();

      await app.main();
      await tester.pumpAndSettle();

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });

    test('内存使用监控', () async {
      // 初始内存
      final initialMemory = getMemoryUsage();

      // 执行大量操作
      for (int i = 0; i < 100; i++) {
        await createAndDeleteTask();
      }

      // 最终内存
      final finalMemory = getMemoryUsage();

      // 验证没有内存泄漏
      expect(finalMemory - initialMemory, lessThan(10 * 1024 * 1024)); // 10MB
    });
  });
}
```

### 6.2 并发和竞态条件测试

```dart
// test/concurrency/concurrency_test.dart
void main() {
  group('并发控制测试', () {
    test('同一计划并发生成任务不会重复', () async {
      final plan = TestDataBuilder.createPlan();

      // 模拟5个并发请求
      final futures = List.generate(5, (_) =>
        taskGenerationService.generateNextTask(plan)
      );

      final results = await Future.wait(futures);

      // 验证只生成了一个任务
      final nonNullResults = results.where((r) => r != null).toList();
      expect(nonNullResults.length, equals(1));
    });

    test('并发更新任务状态', () async {
      final task = TestDataBuilder.createTask();

      // 同时尝试完成和跳过
      final future1 = executionService.completeTask(task);
      final future2 = executionService.skipTask(task);

      // 只有一个操作应该成功
      int successCount = 0;
      int errorCount = 0;

      try {
        await future1;
        successCount++;
      } catch (e) {
        errorCount++;
      }

      try {
        await future2;
        successCount++;
      } catch (e) {
        errorCount++;
      }

      expect(successCount, equals(1));
      expect(errorCount, equals(1));
    });
  });
}
```

### 6.3 数据完整性测试

```dart
// test/database/database_integrity_test.dart
void main() {
  group('数据库完整性', () {
    late Database db;

    setUp(() async {
      db = await DatabaseHelper.instance.database;
    });

    test('级联删除 - 删除目标时相关数据被清理', () async {
      // 创建目标-计划-任务链
      final goalId = 'test_goal';
      await db.insert('goals', {'id': goalId, 'title': 'Test Goal'});
      await db.insert('plans', {'id': 'plan1', 'goal_id': goalId});
      await db.insert('tasks', {'id': 'task1', 'plan_id': 'plan1'});

      // 删除目标
      await db.delete('goals', where: 'id = ?', whereArgs: [goalId]);

      // 验证级联删除
      final plans = await db.query('plans', where: 'goal_id = ?', whereArgs: [goalId]);
      final tasks = await db.query('tasks', where: 'plan_id = ?', whereArgs: ['plan1']);

      expect(plans, isEmpty);
      expect(tasks, isEmpty);
    });

    test('唯一约束 - 用户+计划名称', () async {
      // 插入第一个计划
      await db.insert('plans', {
        'id': 'plan1',
        'user_id': 'user1',
        'name': 'Daily Exercise',
      });

      // 尝试插入重复名称
      expect(
        () => db.insert('plans', {
          'id': 'plan2',
          'user_id': 'user1',
          'name': 'Daily Exercise',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('软删除机制', () async {
      // 创建并软删除
      final planId = 'test_plan';
      await db.insert('plans', {'id': planId, 'name': 'Test'});
      await db.update(
        'plans',
        {'deleted_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [planId],
      );

      // 验证软删除的数据不出现在常规查询中
      final activePlans = await db.query(
        'plans',
        where: 'deleted_at IS NULL',
      );

      expect(
        activePlans.any((p) => p['id'] == planId),
        isFalse,
      );
    });
  });
}
```

## 7. 测试数据管理

### 7.1 测试数据构建器

```dart
// test/fixtures/test_data_builder.dart
class TestDataBuilder {
  static int _counter = 0;

  static String generateId() => 'test_${_counter++}';

  // 基础构建方法
  static Goal createGoal({
    String? id,
    String? title,
    String? userId,
    Priority priority = Priority.medium,
    DateTime? deadline,
    GoalStatus status = GoalStatus.active,
  }) {
    return Goal(
      id: id ?? generateId(),
      userId: userId ?? 'test_user',
      title: title ?? 'Test Goal ${_counter}',
      priority: priority,
      deadline: deadline,
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Plan createPlan({
    String? id,
    String? name,
    String? goalId,
    RepeatType repeatType = RepeatType.daily,
    DateTime? startDate,
    DateTime? endDate,
    int? customDays,
    TaskConfiguration? taskConfig,
  }) {
    return Plan(
      id: id ?? generateId(),
      userId: 'test_user',
      name: name ?? 'Test Plan ${_counter}',
      goalId: goalId ?? 'test_goal',
      startDate: startDate ?? DateTime.now(),
      endDate: endDate ?? DateTime.now().add(Duration(days: 30)),
      repeatRule: RepeatRule(
        type: repeatType,
        customDays: customDays,
      ),
      taskConfig: taskConfig ?? TaskConfiguration(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Task createTask({
    String? id,
    String? name,
    String? planId,
    TaskStatus status = TaskStatus.active,
    DateTime? windowStartTime,
    DateTime? windowEndTime,
    TaskConfiguration? config,
    int currentCount = 0,
  }) {
    final now = DateTime.now();
    return Task(
      id: id ?? generateId(),
      userId: 'test_user',
      planId: planId ?? 'test_plan',
      name: name ?? 'Test Task ${_counter}',
      status: status,
      windowStartTime: windowStartTime ?? now,
      windowEndTime: windowEndTime ?? now.add(Duration(hours: 23, minutes: 59)),
      config: config ?? TaskConfiguration(),
      currentCount: currentCount,
      createdAt: now,
    );
  }

  // 场景化数据构建
  static Future<TestScenario> setupDailyRoutineScenario() async {
    // 创建一个完整的日常任务场景
    final healthGoal = createGoal(
      title: '健康生活',
      priority: Priority.high,
    );

    final exercisePlan = createPlan(
      name: '晨跑',
      goalId: healthGoal.id,
      repeatType: RepeatType.daily,
      taskConfig: TaskConfiguration(durationMinutes: 30),
    );

    final meditationPlan = createPlan(
      name: '冥想',
      goalId: healthGoal.id,
      repeatType: RepeatType.daily,
      taskConfig: TaskConfiguration(
        repeatCount: 2,
        evaluationOptions: ['很好', '一般', '较差'],
      ),
    );

    final morningRunTask = createTask(
      name: '晨跑',
      planId: exercisePlan.id,
      config: exercisePlan.taskConfig,
    );

    final meditationTask = createTask(
      name: '冥想',
      planId: meditationPlan.id,
      config: meditationPlan.taskConfig,
    );

    return TestScenario(
      goals: [healthGoal],
      plans: [exercisePlan, meditationPlan],
      tasks: [morningRunTask, meditationTask],
    );
  }

  static Future<TestScenario> setupComplexProjectScenario() async {
    // 创建复杂项目管理场景
    // ...
  }
}

class TestScenario {
  final List<Goal> goals;
  final List<Plan> plans;
  final List<Task> tasks;

  TestScenario({
    required this.goals,
    required this.plans,
    required this.tasks,
  });

  Future<void> insertIntoDatabase(Database db) async {
    for (final goal in goals) {
      await db.insert('goals', goal.toMap());
    }
    for (final plan in plans) {
      await db.insert('plans', plan.toMap());
    }
    for (final task in tasks) {
      await db.insert('tasks', task.toMap());
    }
  }
}
```

### 7.2 Mock对象管理

```dart
// test/mocks/mock_repositories.dart
import 'package:mockito/annotations.dart';

@GenerateMocks([
  TaskRepository,
  PlanRepository,
  GoalRepository,
  UserRepository,
])
void main() {}

// 使用示例
class MockTaskRepository extends Mock implements TaskRepository {
  // 预设常用行为
  void setupDefaultBehaviors() {
    when(getActiveTasksByUserId(any))
      .thenAnswer((_) async => []);

    when(createTask(any))
      .thenAnswer((invocation) async => invocation.positionalArguments[0]);

    when(updateTask(any))
      .thenAnswer((invocation) async => invocation.positionalArguments[0]);
  }
}
```

## 8. 测试自动化与CI/CD

### 8.1 GitHub Actions配置

```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Run unit tests with coverage
        run: flutter test --coverage test/unit

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: coverage/lcov.info
          flags: unit

      - name: Check coverage threshold
        run: |
          coverage=$(lcov --summary coverage/lcov.info | grep "lines" | sed 's/.*: \([0-9.]*\)%.*/\1/')
          if (( $(echo "$coverage < 80" | bc -l) )); then
            echo "Coverage is below 80%: $coverage%"
            exit 1
          fi

  widget-tests:
    name: Widget Tests
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'

      - name: Install dependencies
        run: flutter pub get

      - name: Run widget tests
        run: flutter test test/widget

  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest  # Android emulator on Linux

    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'

      - name: Install dependencies
        run: flutter pub get

      # Android测试环境设置
      - name: Setup Android Emulator
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 29
          target: default
          arch: x86_64
          script: flutter test integration_test/ -d android

      - name: Run integration tests on Android
        run: flutter test integration_test/ -d android

  performance-tests:
    name: Performance Tests
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2

      - name: Run performance tests
        run: flutter test test/performance

      - name: Upload performance results
        uses: actions/upload-artifact@v3
        with:
          name: performance-results
          path: test_results/performance/
```

### 8.2 本地测试脚本

```bash
#!/bin/bash
# scripts/run_tests.sh

echo "🧪 Running Test Suite..."

# 清理之前的测试结果
rm -rf coverage/
rm -rf test_results/

# 运行单元测试
echo "📦 Running unit tests..."
flutter test test/unit --coverage

# 运行Widget测试
echo "🎨 Running widget tests..."
flutter test test/widget

# 运行集成测试（需要设备）
if [ "$1" == "--integration" ]; then
  echo "🔗 Running integration tests..."
  flutter test integration_test
fi

# 生成覆盖率报告
echo "📊 Generating coverage report..."
genhtml coverage/lcov.info -o coverage/html

# 检查覆盖率
coverage=$(lcov --summary coverage/lcov.info | grep "lines" | sed 's/.*: \([0-9.]*\)%.*/\1/')
echo "Coverage: $coverage%"

if (( $(echo "$coverage < 80" | bc -l) )); then
  echo "❌ Coverage is below 80%"
  exit 1
else
  echo "✅ Coverage meets threshold"
fi

# 打开覆盖率报告
if [ "$2" == "--open" ]; then
  open coverage/html/index.html
fi
```

## 9. 测试执行计划

### 9.1 日常开发测试

```
开发阶段测试执行：
1. 编写代码前：先写单元测试（TDD）
2. 提交代码前：运行相关单元测试和Widget测试
3. PR创建后：自动运行完整测试套件
4. 合并到main前：必须通过所有测试
```

### 9.2 发布前测试清单

```markdown
## 发布前测试检查清单

### ✅ 功能测试
- [ ] 所有重复类型的任务生成（一次性/每日/每周/每月/自定义）
- [ ] 任务状态流转（active -> completed/skipped）
- [ ] 任务配置组合（计时/计数/评价及其组合）
- [ ] 计划CRUD操作
- [ ] 目标管理和进度计算
- [ ] 数据持久化和恢复

### ✅ 边界和异常测试
- [ ] 日期边界（月末、年末、闰年）
- [ ] 时区切换处理
- [ ] 大数据量处理（1000+ 任务）
- [ ] 空数据状态
- [ ] 网络异常处理
- [ ] 数据库损坏恢复
- [ ] 并发操作安全性

### ✅ 性能测试
- [ ] 应用启动时间 < 3秒
- [ ] 列表滚动帧率 > 55fps
- [ ] 内存使用 < 150MB
- [ ] 数据库查询 < 100ms

### ✅ 兼容性测试
- [ ] Android 5.0+ 兼容（API 21+）
- [ ] Android 6.0+ 优化测试（API 23+）
- [ ] Android不同屏幕尺寸适配（手机/平板）
- [ ] 横竖屏切换
- [ ] 不同Android版本测试（Android 5.0 - Android 14）
- [ ] 不同厂商ROM测试（如有条件）

### ✅ 用户体验测试
- [ ] 新用户引导流程
- [ ] 错误提示友好性
- [ ] 操作响应及时性
- [ ] 无障碍功能
```

### 9.3 回归测试策略

```
回归测试执行时机：
1. 主要功能修改后：运行相关模块的完整测试
2. Bug修复后：添加针对性测试用例
3. 版本发布前：运行完整测试套件
4. 依赖升级后：重点测试受影响功能
```

## 10. 测试度量和报告

### 10.1 关键测试指标

```
测试KPI：
- 代码覆盖率: > 80%
- 测试执行时间: < 10分钟
- 测试稳定性: 失败率 < 1%
- Bug逃逸率: < 5%
- 测试用例数量: > 500
```

### 10.2 测试报告模板

```markdown
# 测试报告 - v1.0.0

## 测试概况
- 测试周期: 2024.01.01 - 2024.01.15
- 测试版本: v1.0.0-rc1
- 测试环境: Android Emulator (API 29-34) / Android 物理设备测试

## 测试结果
| 类型 | 总数 | 通过 | 失败 | 跳过 | 通过率 |
|------|------|------|------|------|--------|
| 单元测试 | 256 | 254 | 2 | 0 | 99.2% |
| Widget测试 | 89 | 89 | 0 | 0 | 100% |
| 集成测试 | 34 | 33 | 1 | 0 | 97.1% |
| E2E测试 | 12 | 12 | 0 | 0 | 100% |

## 代码覆盖率
- 整体: 85.3%
- 核心业务: 96.2%
- UI组件: 72.8%

## 发现的问题
1. BUG-001: 月末任务生成异常
2. BUG-002: 并发操作数据不一致

## 性能测试结果
- 启动时间: 2.3s ✅
- 滚动帧率: 58fps ✅
- 内存峰值: 128MB ✅

## 建议
- 增加月末边界测试用例
- 优化并发控制机制
```

## 总结

本测试设计文档为Flutter任务管理App提供了全面的测试策略和实施方案：

1. **完整的测试金字塔**：50%单元测试 + 30%Widget测试 + 15%集成测试 + 5%E2E测试
2. **重点测试领域**：任务生成逻辑、状态流转、配置组合、数据完整性
3. **自动化支持**：CI/CD集成、自动化脚本、测试报告
4. **质量保证**：80%代码覆盖率、性能基准、回归测试策略

通过执行本测试计划，可以确保应用的功能正确性、性能稳定性和用户体验质量。