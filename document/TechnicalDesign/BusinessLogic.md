# 业务逻辑设计

本文档详细定义了任务管理系统的核心业务逻辑，包括任务生成、刷新、执行、状态管理等核心功能的实现。

## 1. 核心服务概述

### 1.1 服务架构

```
TaskGenerationService ──→ 任务生成逻辑
TaskRefreshService ────→ 任务刷新和更新
TaskExecutionService ──→ 任务执行和完成
SyncService ──────────→ 数据同步（预留）
NotificationService ──→ 通知提醒
```

## 2. 任务生成服务（TaskGenerationService）

### 2.1 核心职责
负责根据计划规则自动生成任务，是系统的核心业务逻辑。

```dart
class TaskGenerationService {
  final TaskRepository _taskRepository;
  final PlanRepository _planRepository;

  TaskGenerationService({
    required TaskRepository taskRepository,
    required PlanRepository planRepository,
  }) : _taskRepository = taskRepository,
       _planRepository = planRepository;

  /// 为指定计划生成下一个任务
  Future<Task?> generateNextTask(Plan plan) async {
    // 1. 检查计划是否在有效期内
    if (!_isPlanActive(plan)) {
      return null;
    }

    // 2. 获取该计划的最后一个任务
    final lastTask = await _taskRepository.getLastTaskForPlan(plan.id);

    // 3. 检查是否应该生成新任务
    if (!_shouldGenerateTask(plan, lastTask)) {
      return null;
    }

    // 4. 计算执行窗口
    final window = _calculateExecutionWindow(plan, lastTask);

    // 5. 创建新任务
    final task = Task(
      id: IdGenerator.generateUuid(),
      userId: plan.userId,
      planId: plan.id,
      name: plan.name,
      description: plan.description,
      config: plan.taskConfig,
      windowStartTime: window.start,
      windowEndTime: window.end,
      status: TaskStatus.active,
      currentCount: 0,
      createdAt: DateTime.now(),
    );

    // 6. 保存任务到数据库
    await _taskRepository.createTask(task);

    return task;
  }

  /// 批量生成任务（应用启动时）
  Future<List<Task>> generateAllPendingTasks() async {
    final generatedTasks = <Task>[];

    // 1. 获取所有活跃计划
    final activePlans = await _planRepository.getActivePlans();

    // 2. 为每个计划生成任务
    for (final plan in activePlans) {
      final task = await generateNextTask(plan);
      if (task != null) {
        generatedTasks.add(task);
      }
    }

    return generatedTasks;
  }

  /// 检查计划是否在有效期内
  bool _isPlanActive(Plan plan) {
    final now = DateTime.now();
    return now.isAfter(plan.startDate) && now.isBefore(plan.endDate);
  }

  /// 判断是否应该生成新任务
  bool _shouldGenerateTask(Plan plan, Task? lastTask) {
    // 1. 如果没有历史任务，应该生成
    if (lastTask == null) {
      return true;
    }

    // 2. 如果最后的任务还在活跃状态，不生成
    if (lastTask.status == TaskStatus.active) {
      return false;
    }

    // 3. 根据重复规则判断
    final now = DateTime.now();

    switch (plan.repeatRule.type) {
      case RepeatType.oneTime:
        // 一次性任务：已有任务则不再生成
        return false;

      case RepeatType.daily:
        // 每日任务：检查今天是否已有任务
        return !_isSameDay(lastTask.windowStartTime, now);

      case RepeatType.weekly:
        // 每周任务：检查本周是否已有任务
        return !_isSameWeek(lastTask.windowStartTime, now);

      case RepeatType.monthly:
        // 每月任务：检查本月是否已有任务
        return !_isSameMonth(lastTask.windowStartTime, now);

      case RepeatType.custom:
        // 自定义间隔：检查间隔天数
        final daysSinceLastTask = now.difference(lastTask.windowStartTime).inDays;
        return daysSinceLastTask >= plan.repeatRule.customDays!;
    }
  }

  /// 计算任务执行窗口
  ExecutionWindow _calculateExecutionWindow(Plan plan, Task? lastTask) {
    final now = DateTime.now();
    DateTime windowStart;
    DateTime windowEnd;

    if (lastTask == null) {
      // 首次生成任务
      windowStart = _getStartOfDay(now);
    } else {
      // 根据重复规则计算开始时间
      switch (plan.repeatRule.type) {
        case RepeatType.oneTime:
          windowStart = plan.startDate;
          break;
        case RepeatType.daily:
          windowStart = _getStartOfDay(now);
          break;
        case RepeatType.weekly:
          windowStart = _getStartOfWeek(now);
          break;
        case RepeatType.monthly:
          windowStart = _getStartOfMonth(now);
          break;
        case RepeatType.custom:
          final daysSince = plan.repeatRule.customDays!;
          windowStart = lastTask.windowEndTime.add(Duration(days: 1));
          break;
      }
    }

    // 计算结束时间
    switch (plan.repeatRule.type) {
      case RepeatType.oneTime:
        windowEnd = plan.endDate;
        break;
      case RepeatType.daily:
        windowEnd = _getEndOfDay(windowStart);
        break;
      case RepeatType.weekly:
        windowEnd = _getEndOfWeek(windowStart);
        break;
      case RepeatType.monthly:
        windowEnd = _getEndOfMonth(windowStart);
        break;
      case RepeatType.custom:
        windowEnd = windowStart.add(Duration(days: plan.repeatRule.customDays! - 1));
        windowEnd = _getEndOfDay(windowEnd);
        break;
    }

    // 确保不超过计划结束日期
    if (windowEnd.isAfter(plan.endDate)) {
      windowEnd = plan.endDate;
    }

    return ExecutionWindow(start: windowStart, end: windowEnd);
  }

  // 辅助方法
  DateTime _getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  DateTime _getStartOfWeek(DateTime date) {
    // 周一为一周开始
    final weekday = date.weekday;
    return _getStartOfDay(date.subtract(Duration(days: weekday - 1)));
  }

  DateTime _getEndOfWeek(DateTime date) {
    // 周日为一周结束
    final weekday = date.weekday;
    return _getEndOfDay(date.add(Duration(days: 7 - weekday)));
  }

  DateTime _getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _getEndOfMonth(DateTime date) {
    final nextMonth = date.month == 12 ? 1 : date.month + 1;
    final nextYear = date.month == 12 ? date.year + 1 : date.year;
    return DateTime(nextYear, nextMonth, 1).subtract(Duration(seconds: 1));
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  bool _isSameWeek(DateTime date1, DateTime date2) {
    final week1 = _getWeekOfYear(date1);
    final week2 = _getWeekOfYear(date2);
    return date1.year == date2.year && week1 == week2;
  }

  bool _isSameMonth(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month;
  }

  int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirst = date.difference(firstDayOfYear).inDays;
    return (daysSinceFirst / 7).floor() + 1;
  }
}

/// 执行窗口
class ExecutionWindow {
  final DateTime start;
  final DateTime end;

  ExecutionWindow({required this.start, required this.end});
}
```

## 3. 任务刷新服务（TaskRefreshService）

### 3.1 核心职责
定期检查和刷新任务状态，生成新任务，清理过期任务。

```dart
class TaskRefreshService {
  final TaskRepository _taskRepository;
  final TaskGenerationService _generationService;
  final NotificationService _notificationService;

  TaskRefreshService({
    required TaskRepository taskRepository,
    required TaskGenerationService generationService,
    required NotificationService notificationService,
  }) : _taskRepository = taskRepository,
       _generationService = generationService,
       _notificationService = notificationService;

  /// 刷新所有任务
  Future<RefreshResult> refreshAllTasks() async {
    final result = RefreshResult();

    try {
      // 1. 处理过期任务
      result.expiredCount = await _handleExpiredTasks();

      // 2. 生成新任务
      final newTasks = await _generationService.generateAllPendingTasks();
      result.generatedCount = newTasks.length;
      result.newTasks = newTasks;

      // 3. 发送通知
      if (newTasks.isNotEmpty) {
        await _notificationService.notifyNewTasks(newTasks);
      }

      result.success = true;
    } catch (e) {
      result.success = false;
      result.error = e.toString();
    }

    return result;
  }

  /// 处理过期任务
  Future<int> _handleExpiredTasks() async {
    // 1. 获取所有活跃但已过期的任务
    final expiredTasks = await _taskRepository.getExpiredActiveTasks();

    // 2. 将过期任务标记为跳过
    for (final task in expiredTasks) {
      await _taskRepository.updateTask(
        task.copyWith(
          status: TaskStatus.skipped,
          skippedAt: DateTime.now(),
        ),
      );
    }

    return expiredTasks.length;
  }

  /// 定时刷新（后台服务）
  Stream<RefreshResult> startPeriodicRefresh({
    Duration interval = const Duration(hours: 1),
  }) async* {
    while (true) {
      await Future.delayed(interval);
      yield await refreshAllTasks();
    }
  }
}

/// 刷新结果
class RefreshResult {
  bool success = false;
  String? error;
  int generatedCount = 0;
  int expiredCount = 0;
  List<Task> newTasks = [];
}
```

## 4. 任务执行服务（TaskExecutionService）

### 4.1 核心职责
处理任务的执行、完成、跳过等状态变更。

```dart
class TaskExecutionService {
  final TaskRepository _taskRepository;
  final PlanRepository _planRepository;
  final NotificationService _notificationService;

  TaskExecutionService({
    required TaskRepository taskRepository,
    required PlanRepository planRepository,
    required NotificationService notificationService,
  }) : _taskRepository = taskRepository,
       _planRepository = planRepository,
       _notificationService = notificationService;

  /// 开始执行任务（计时任务）
  Future<TimerSession> startTimer(Task task) async {
    // 1. 验证任务状态
    if (task.status != TaskStatus.active) {
      throw BusinessException('只能执行活跃状态的任务');
    }

    // 2. 验证任务类型
    if (task.config.durationMinutes == null) {
      throw BusinessException('非计时任务');
    }

    // 3. 创建计时会话
    final session = TimerSession(
      taskId: task.id,
      startTime: DateTime.now(),
      targetDuration: Duration(minutes: task.config.durationMinutes!),
    );

    return session;
  }

  /// 完成任务
  Future<TaskCompletionResult> completeTask({
    required Task task,
    int? actualDurationMinutes,
    String? evaluationResult,
    String? executionNote,
  }) async {
    // 1. 验证任务状态
    if (task.status != TaskStatus.active) {
      throw BusinessException('任务已完成或已跳过');
    }

    // 2. 验证任务窗口期
    if (task.isExpired) {
      throw BusinessException('任务已过期');
    }

    // 3. 验证任务配置
    _validateTaskCompletion(task, evaluationResult);

    // 4. 更新任务状态
    final updatedTask = task.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime.now(),
      actualDurationMinutes: actualDurationMinutes,
      evaluationResult: evaluationResult,
      executionNote: executionNote,
    );

    await _taskRepository.updateTask(updatedTask);

    // 5. 记录任务完成(由trigger自动记录到task_history)

    // 6. 更新计划统计
    await _updatePlanStatistics(task.planId);

    // 6. 检查是否需要生成下一个任务（同一窗口期内再次执行）
    final plan = await _planRepository.getPlan(task.planId);
    final shouldGenerateNext = _shouldGenerateNextInSameWindow(plan!, task);

    Task? nextTask;
    if (shouldGenerateNext) {
      final generationService = TaskGenerationService(
        taskRepository: _taskRepository,
        planRepository: _planRepository,
      );
      nextTask = await generationService.generateNextTask(plan);
    }

    // 7. 发送完成通知
    await _notificationService.notifyTaskCompleted(updatedTask);

    return TaskCompletionResult(
      completedTask: updatedTask,
      nextTask: nextTask,
      statistics: await _getTaskStatistics(task.userId),
    );
  }

  /// 跳过任务
  Future<void> skipTask({
    required Task task,
    String? skipReason,
  }) async {
    // 1. 验证任务状态
    if (task.status != TaskStatus.active) {
      throw BusinessException('只能跳过活跃状态的任务');
    }

    // 2. 更新任务状态
    final updatedTask = task.copyWith(
      status: TaskStatus.skipped,
      skippedAt: DateTime.now(),
      executionNote: skipReason,
    );

    await _taskRepository.updateTask(updatedTask);

    // 3. 更新计划统计
    await _updatePlanStatistics(task.planId);

    // 4. 发送跳过通知
    await _notificationService.notifyTaskSkipped(updatedTask);
  }

  /// 增加计数（计数任务）
  Future<Task> incrementCount(Task task) async {
    // 1. 验证任务类型
    if (task.config.repeatCount == null) {
      throw BusinessException('非计数任务');
    }

    // 2. 增加计数
    final newCount = task.currentCount + 1;

    // 3. 检查是否达到目标
    if (newCount >= task.config.repeatCount!) {
      // 自动完成任务
      await completeTask(task: task);
      return task.copyWith(
        currentCount: newCount,
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
      );
    }

    // 4. 更新计数
    final updatedTask = task.copyWith(currentCount: newCount);
    await _taskRepository.updateTask(updatedTask);

    return updatedTask;
  }

  /// 验证任务完成数据
  void _validateTaskCompletion(Task task, String? evaluationResult) {
    // 评价任务必须有评价结果
    if (task.config.evaluationOptions != null &&
        task.config.evaluationOptions!.isNotEmpty &&
        evaluationResult == null) {
      throw BusinessException('评价任务需要提供评价结果');
    }

    // 验证评价结果的有效性
    if (evaluationResult != null &&
        task.config.evaluationOptions != null &&
        !task.config.evaluationOptions!.contains(evaluationResult)) {
      throw BusinessException('无效的评价选项');
    }
  }

  /// 判断是否在同一窗口期内生成下一个任务
  bool _shouldGenerateNextInSameWindow(Plan plan, Task completedTask) {
    // 只有每日任务支持同一天内多次执行
    if (plan.repeatRule.type != RepeatType.daily) {
      return false;
    }

    // 检查是否还在执行窗口内
    final now = DateTime.now();
    return now.isBefore(completedTask.windowEndTime);
  }

  /// 更新计划统计
  Future<void> _updatePlanStatistics(String planId) async {
    // 统计逻辑将在数据层实现
    // 这里触发统计更新
    await _planRepository.updateStatistics(planId);
  }

  /// 获取任务统计
  Future<TaskStatistics> _getTaskStatistics(String userId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final todayTasks = await _taskRepository.getTasksByDateRange(
      userId: userId,
      startDate: startOfDay,
      endDate: today,
    );

    return TaskStatistics(
      todayCompleted: todayTasks.where((t) => t.status == TaskStatus.completed).length,
      todayRemaining: todayTasks.where((t) => t.status == TaskStatus.active).length,
      todaySkipped: todayTasks.where((t) => t.status == TaskStatus.skipped).length,
    );
  }

  /// 再次执行任务（创建新的独立任务）
  /// v4.0 设计：没有"repeat execution"概念，每次都创建新任务
  Future<Task> reExecuteTask(String taskId) async {
    // 1. 获取原任务
    final originalTask = await _taskRepository.getTaskById(taskId);
    if (originalTask == null) {
      throw BusinessException('任务不存在');
    }

    // 2. 验证前置条件
    // 只有已完成的任务才能再次执行
    if (originalTask.status != TaskStatus.completed) {
      throw BusinessException('只有已完成的任务才能再次执行');
    }

    // 任务必须仍在时间窗口内
    if (!originalTask.isInCurrentWindow) {
      throw BusinessException('任务时间窗口已过期');
    }

    // 3. 创建新任务（复制配置）
    // 注意：这是一个全新的独立任务，有新的UUID
    final newTask = await _taskRepository.createRepeatExecution(taskId);

    if (newTask == null) {
      throw BusinessException('创建新任务失败');
    }

    // 4. 发送通知
    await _notificationService.notifyNewTask(newTask);

    return newTask;
  }
}

/// 计时会话
class TimerSession {
  final String taskId;
  final DateTime startTime;
  final Duration targetDuration;
  DateTime? pauseTime;
  Duration pausedDuration = Duration.zero;

  TimerSession({
    required this.taskId,
    required this.startTime,
    required this.targetDuration,
  });

  Duration get elapsedDuration {
    if (pauseTime != null) {
      return pauseTime!.difference(startTime) - pausedDuration;
    }
    return DateTime.now().difference(startTime) - pausedDuration;
  }

  Duration get remainingDuration {
    final remaining = targetDuration - elapsedDuration;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isCompleted => remainingDuration == Duration.zero;

  void pause() {
    if (pauseTime == null) {
      pauseTime = DateTime.now();
    }
  }

  void resume() {
    if (pauseTime != null) {
      pausedDuration += DateTime.now().difference(pauseTime!);
      pauseTime = null;
    }
  }
}

/// 任务完成结果
class TaskCompletionResult {
  final Task completedTask;
  final Task? nextTask;
  final TaskStatistics statistics;

  TaskCompletionResult({
    required this.completedTask,
    this.nextTask,
    required this.statistics,
  });
}

/// 任务统计
class TaskStatistics {
  final int todayCompleted;
  final int todayRemaining;
  final int todaySkipped;

  TaskStatistics({
    required this.todayCompleted,
    required this.todayRemaining,
    required this.todaySkipped,
  });
}
```

## 5. 任务快捷菜单逻辑（TaskQuickMenu）

### 5.1 核心职责

任务快捷菜单（TaskQuickMenu）是任务卡片上的操作入口，提供快速执行任务相关操作的能力。核心职责包括：

1. **条件显示**：根据任务状态和类型动态显示合适的菜单按钮
2. **操作路由**：将用户操作路由到正确的业务逻辑处理
3. **状态验证**：执行前验证任务状态和执行条件
4. **用户反馈**：提供即时的视觉反馈和错误提示

**设计原则**：
- 最小化用户决策负担（不显示无效操作）
- 状态驱动的UI显示（基于任务实际状态）
- 类型驱动的行为分派（不同类型有不同处理）
- 防御性编程（所有操作前都验证前置条件）

**实现位置**：`lib/presentation/features/tasks/widgets/task_quick_menu.dart`

### 5.2 菜单显示规则矩阵

#### 5.2.1 核心显示规则表

| 任务状态 | 任务类型 | 主按钮 | 跳过按钮 | 主按钮行为 | 备注 |
|---------|---------|-------|---------|-----------|------|
| **completed** | 任何类型 | ✅ 再次执行 | ❌ 不显示 | 创建新任务实例（重置状态） | 所有已完成任务统一处理 |
| **active** | simple | ✅ 完成 | ✅ 跳过 | 直接标记为completed | 最简单的任务类型，一键完成 |
| **active** | timer | ✅ 计时 | ✅ 跳过 | 打开计时对话框 | 显示倒计时/正计时界面 |
| **active** | counter | ✅ 完成 | ✅ 跳过 | 递增计数，达到目标自动完成 | 按钮显示当前进度 (x/y) |
| **active** | evaluation | ✅ 完成 | ✅ 跳过 | 打开评估选项菜单 | 必须选择一个评估结果 |
| **active** | timerWithCount | ✅ 计时 | ✅ 跳过 | 打开计时对话框（含计数） | 计时结束后自动递增计数 |
| **active** | counterWithEval | ✅ 完成 | ✅ 跳过 | 递增计数，最后一次显示评估 | 动态行为：递增 or 评估 |
| **skipped** | 任何类型 | ❌ 不显示 | ❌ 不显示 | - | 已跳过任务不可操作 |
| **deleted** | 任何类型 | ❌ 不显示 | ❌ 不显示 | - | 软删除任务不显示在列表 |

#### 5.2.2 特殊条件处理表

| 条件 | 任务状态 | 菜单显示 | 按钮状态 | 点击行为 | 说明 |
|------|---------|---------|---------|---------|------|
| **过期任务** | active | ❌ 不显示整个菜单 | - | - | `isExpired = true`的任务应被自动跳过 |
| **过期任务** | completed | ✅ 显示 | ✅ 启用"再次执行" | 创建新任务 | 已完成任务可以重新执行 |
| **窗口未开始** | active | ✅ 显示 | ⚠️ 禁用所有按钮 | 提示"任务未开始" | `now < windowStartTime` |
| **窗口已过** | active | ❌ 不显示 | - | - | 等同于过期任务 |
| **计数已满** | active + counter | ✅ 显示"完成" | ✅ 启用 | 显示评估菜单（如有）或直接完成 | `currentCount >= repeatCount` |

#### 5.2.3 任务类型判断逻辑

```dart
// TaskConfiguration.taskType getter 的判断优先级
TaskType get taskType {
  // 1. Timer 和 Evaluation 互斥校验
  if (durationMinutes != null && evaluationOptions != null) {
    throw StateError('Timer and evaluation cannot coexist');
  }

  // 2. 组合类型判断（优先级从高到低）
  if (durationMinutes != null && repeatCount != null) {
    return TaskType.timerWithCount;  // Timer + Counter
  }

  if (durationMinutes != null) {
    return TaskType.timer;  // 仅 Timer
  }

  if (repeatCount != null && evaluationOptions != null) {
    return TaskType.counterWithEval;  // Counter + Evaluation
  }

  if (repeatCount != null) {
    return TaskType.counter;  // 仅 Counter
  }

  if (evaluationOptions != null) {
    return TaskType.evaluation;  // 仅 Evaluation
  }

  return TaskType.simple;  // 无配置 = Simple
}
```

### 5.3 按钮行为详细说明

#### 5.3.1 主按钮点击处理流程

```dart
Future<void> handleMainButtonTap(TaskModel task, WidgetRef ref) async {
  // 1. 已完成任务 → 再次执行
  if (task.isCompleted) {
    await _handleReExecute(task, ref);
    return;
  }

  // 2. Active状态任务 → 根据类型分派
  if (task.status == TaskStatus.active) {
    final taskType = task.config.taskType;

    switch (taskType) {
      case TaskType.timer:
      case TaskType.timerWithCount:
        // 打开计时对话框
        await _showTimerDialog(context, task, ref);
        break;

      case TaskType.counter:
        // 递增计数（可能自动完成）
        await _handleCounterIncrement(task, ref);
        break;

      case TaskType.counterWithEval:
        // 检查是否最后一次计数
        await _handleCounterWithEval(task, ref);
        break;

      case TaskType.evaluation:
        // 显示评估菜单
        await _showEvaluationMenu(context, task, ref);
        break;

      case TaskType.simple:
        // 直接完成
        await _completeSimpleTask(task, ref);
        break;
    }
  }
}
```

#### 5.3.2 Counter类型详细处理

```dart
Future<void> _handleCounterIncrement(TaskModel task, WidgetRef ref) async {
  final config = task.config;
  final newCount = task.currentCount + 1;
  final willComplete = newCount >= config.repeatCount!;

  if (willComplete) {
    // 达到目标 → 自动完成任务
    await ref.read(taskExecutionServiceProvider).completeTask(
      task: task,
      actualDurationMinutes: null,
      evaluationResult: null,
      executionNote: '完成 ${config.repeatCount} 次计数',
    );
  } else {
    // 仅递增计数
    await ref.read(taskExecutionServiceProvider).incrementCount(task);
  }
}

Future<void> _handleCounterWithEval(TaskModel task, WidgetRef ref) async {
  final config = task.config;
  final newCount = task.currentCount + 1;
  final isLastCount = newCount >= config.repeatCount!;

  if (isLastCount && config.evaluationOptions != null) {
    // 最后一次 + 有评估 → 显示评估菜单
    _showEvaluationMenuForCounter(context, task, ref);
  } else {
    // 其他情况 → 仅递增计数
    await ref.read(taskExecutionServiceProvider).incrementCount(task);
  }
}
```

#### 5.3.3 跳过按钮处理

```dart
Future<void> handleSkipButtonTap(TaskModel task, WidgetRef ref) async {
  // 1. 验证状态
  if (task.status != TaskStatus.active) {
    showErrorToast('只能跳过活跃状态的任务');
    return;
  }

  // 2. 执行跳过
  await ref.read(taskExecutionServiceProvider).skipTask(
    task: task,
    skipReason: null,  // 可选：显示对话框让用户输入原因
  );

  // 3. 刷新列表
  ref.read(taskListNotifierProvider.notifier).refresh();
}
```

#### 5.3.4 再次执行处理

```dart
Future<void> _handleReExecute(TaskModel task, WidgetRef ref) async {
  // 1. 验证前置条件
  if (task.status != TaskStatus.completed) {
    showErrorToast('只有已完成的任务才能再次执行');
    return;
  }

  if (!task.isInCurrentWindow) {
    showErrorToast('任务时间窗口已过期');
    return;
  }

  // 2. 创建新任务
  final newTask = await ref.read(taskExecutionServiceProvider)
      .reExecuteTask(task.id);

  if (newTask != null) {
    showSuccessToast('已创建新任务');
    ref.read(taskListNotifierProvider.notifier).refresh();
  }
}
```

### 5.4 特殊条件处理

#### 5.4.1 过期任务处理

**检测逻辑**：
```dart
bool get isExpired {
  final now = DateTime.now();
  return now.isAfter(windowEndTime);
}
```

**处理策略**：
1. **Active状态过期任务**：
   - UI层：不显示快捷菜单
   - Service层：由TaskRefreshService自动标记为skipped
   - 时机：应用启动、定时刷新、手动刷新

2. **Completed状态过期任务**：
   - 仍显示快捷菜单
   - "再次执行"按钮可用
   - 点击时需验证执行窗口（不能超过计划endDate）

#### 5.4.2 执行窗口检查

**窗口状态判断**：
```dart
enum WindowStatus {
  notStarted,   // now < windowStartTime
  inProgress,   // windowStartTime <= now <= windowEndTime
  expired;      // now > windowEndTime
}

WindowStatus get windowStatus {
  final now = DateTime.now();
  if (now.isBefore(windowStartTime)) {
    return WindowStatus.notStarted;
  }
  if (now.isAfter(windowEndTime)) {
    return WindowStatus.expired;
  }
  return WindowStatus.inProgress;
}
```

**UI处理**：
- `notStarted`：显示菜单，但按钮禁用，提示"任务未开始"
- `inProgress`：正常显示，按钮启用
- `expired`：不显示菜单（等同于过期任务）

#### 5.4.3 最后一次计数的特殊逻辑

**判断条件**：
```dart
bool isLastCount(TaskModel task) {
  if (task.config.repeatCount == null) return false;
  return task.currentCount + 1 >= task.config.repeatCount!;
}

bool hasEvaluation(TaskModel task) {
  return task.config.evaluationOptions != null &&
         task.config.evaluationOptions!.isNotEmpty;
}
```

**处理流程**：
```
Counter任务点击"完成"：
├─ if (currentCount + 1 < repeatCount)
│   └─ 递增计数，保持active状态
│
└─ else if (currentCount + 1 >= repeatCount)
    ├─ if (hasEvaluation)
    │   └─ 显示评估菜单 → 选择后完成任务
    │
    └─ else
        └─ 直接完成任务（无评估）
```

### 5.5 代码实现参考

#### 5.5.1 关键文件位置

**UI层**：
- `/lib/presentation/features/tasks/widgets/task_quick_menu.dart` - 快捷菜单组件
- `/lib/presentation/features/tasks/widgets/compact_task_card.dart` - 任务卡片（包含菜单）

**Provider层**：
- `/lib/presentation/providers/task_list_notifier.dart` - 任务列表状态管理
- `/lib/presentation/providers/task_state_provider.dart` - 单个任务状态

**Service层**：
- `/lib/data/services/task_execution_service.dart` - 任务执行服务
- `/lib/data/repositories/task_repository.dart` - 任务数据仓库

**Model层**：
- `/lib/data/models/task_model.dart` - 任务模型（含computed properties）
- `/lib/data/models/enums/status.dart` - TaskStatus枚举
- `/lib/data/models/enums/task_type.dart` - TaskType枚举

#### 5.5.2 核心代码片段

**菜单显示条件判断**（task_quick_menu.dart:88-189）：
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // 1. 计算显示条件
  final canReExecute = task.isCompleted;
  final hasTimer = task.config.durationMinutes != null;
  final hasCounter = task.config.repeatCount != null;

  // 2. 构建菜单按钮
  return Row(
    children: [
      // 主按钮
      if (canReExecute)
        _MenuButton(icon: Icons.refresh, label: '再次执行', onTap: _handleReExecute)
      else if (hasTimer)
        _MenuButton(icon: Icons.timer, label: '计时', onTap: _showTimerDialog)
      else
        _MenuButton(icon: Icons.check, label: '完成', onTap: _handleComplete),

      // 分隔线
      Container(width: 1, height: 56, color: Colors.grey),

      // 跳过按钮
      _MenuButton(icon: Icons.skip_next, label: '跳过', onTap: _handleSkip),
    ],
  );
}
```

**Counter任务处理**（task_quick_menu.dart:192-231）：
```dart
Future<void> _handleCounterTask(
  BuildContext context,
  TaskModel task,
  WidgetRef ref,
) async {
  final willComplete = task.currentCount + 1 >= task.config.repeatCount!;

  if (willComplete &&
      task.config.evaluationOptions != null &&
      task.config.evaluationOptions!.isNotEmpty) {
    // 最后一次 + 有评估 → 显示评估菜单
    _showEvaluationMenuForCounter(context, task, ref);
  } else {
    // 递增计数（可能自动完成）
    await ref.read(taskListNotifierProvider.notifier).incrementCount(task);
  }
}
```

**TaskModel计算属性**（task_model.dart）：
```dart
class TaskModel {
  // 状态检查
  bool get isCompleted => status == TaskStatus.completed;
  bool get isSkipped => status == TaskStatus.skipped;
  bool get isDeleted => status == TaskStatus.deleted;

  // 时间检查
  bool get isExpired {
    final now = DateTime.now();
    return now.isAfter(windowEndTime);
  }

  bool get isInCurrentWindow {
    final now = DateTime.now();
    return now.isAfter(windowStartTime) && now.isBefore(windowEndTime);
  }

  // 执行能力检查
  bool get canExecute => status == TaskStatus.active && !isExpired;

  // 计数任务进度
  double get progress {
    if (config.repeatCount == null) return 0.0;
    return (currentCount / config.repeatCount!).clamp(0.0, 1.0);
  }
}
```

### 5.6 业务规则汇总

#### 5.6.1 菜单显示规则
1. 只有`active`和`completed`状态的任务显示快捷菜单
2. `skipped`和`deleted`状态的任务不显示菜单
3. 过期的`active`任务不显示菜单（应被自动跳过）
4. 过期的`completed`任务仍显示菜单（支持重新执行）

#### 5.6.2 主按钮显示规则
1. `completed`状态：统一显示"再次执行"按钮
2. `active`状态：
   - 有`durationMinutes`配置 → 显示"计时"按钮
   - 其他情况 → 显示"完成"按钮

#### 5.6.3 跳过按钮显示规则
1. 仅`active`状态显示跳过按钮
2. `completed`状态不显示跳过（已完成无需跳过）
3. 过期任务不显示跳过（由系统自动处理）

#### 5.6.4 完成按钮行为规则
1. **Simple任务**：直接调用`completeTask()`
2. **Timer任务**：打开计时对话框，完成后调用`completeTask(actualDurationMinutes)`
3. **Counter任务**：
   - 未达到目标：调用`incrementCount()`
   - 达到目标且无评估：自动调用`completeTask()`
   - 达到目标且有评估：显示评估菜单后调用`completeTask(evaluationResult)`
4. **Evaluation任务**：显示评估菜单，选择后调用`completeTask(evaluationResult)`
5. **TimerWithCount任务**：打开计时对话框，完成后自动递增计数
6. **CounterWithEval任务**：结合Counter和Evaluation逻辑

#### 5.6.5 状态转换约束
1. 只有`active`状态的任务可以完成或跳过
2. 只有`completed`状态的任务可以再次执行
3. 再次执行创建的是全新的任务（新UUID），不是修改原任务
4. 任务状态转换单向：`active` → `completed` 或 `skipped`

#### 5.6.6 时间窗口约束
1. 执行窗口外的任务不可操作（除了已完成任务的重新执行）
2. 过期任务由系统自动标记为`skipped`
3. 重新执行的任务保持原执行窗口（`windowStartTime`和`windowEndTime`）
4. 窗口验证在UI层和Service层都需要进行

## 6. 目标与计划管理逻辑

### 6.1 目标管理

```dart
class GoalManagementService {
  final GoalRepository _goalRepository;
  final PlanRepository _planRepository;

  GoalManagementService({
    required GoalRepository goalRepository,
    required PlanRepository planRepository,
  }) : _goalRepository = goalRepository,
       _planRepository = planRepository;

  /// 创建目标
  Future<Goal> createGoal({
    required String userId,
    required String title,
    String? description,
    List<String>? tags,
    DateTime? deadline,
    Priority priority = Priority.medium,
    String? successCriteria,
  }) async {
    // 1. 验证输入
    if (title.trim().isEmpty) {
      throw ValidationException('目标标题不能为空');
    }

    if (deadline != null && deadline.isBefore(DateTime.now())) {
      throw ValidationException('截止日期不能早于当前时间');
    }

    // 2. 创建目标实体
    final goal = Goal(
      id: IdGenerator.generateUuid(),
      userId: userId,
      title: title.trim(),
      description: description?.trim(),
      tags: tags ?? [],
      deadline: deadline,
      priority: priority,
      status: GoalStatus.active,
      successCriteria: successCriteria?.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      planIds: [],
    );

    // 3. 保存到数据库
    await _goalRepository.createGoal(goal);

    return goal;
  }

  /// 更新目标
  Future<Goal> updateGoal({
    required String goalId,
    String? title,
    String? description,
    List<String>? tags,
    DateTime? deadline,
    Priority? priority,
    GoalStatus? status,
    String? successCriteria,
  }) async {
    // 1. 获取现有目标
    final existingGoal = await _goalRepository.getGoal(goalId);
    if (existingGoal == null) {
      throw NotFoundException('目标不存在');
    }

    // 2. 验证状态
    if (existingGoal.status == GoalStatus.completed) {
      throw BusinessException('已完成的目标不能修改');
    }

    // 3. 验证截止日期
    if (deadline != null && deadline.isBefore(DateTime.now())) {
      throw ValidationException('截止日期不能早于当前时间');
    }

    // 4. 更新目标
    final updatedGoal = existingGoal.copyWith(
      title: title ?? existingGoal.title,
      description: description ?? existingGoal.description,
      tags: tags ?? existingGoal.tags,
      deadline: deadline ?? existingGoal.deadline,
      priority: priority ?? existingGoal.priority,
      status: status ?? existingGoal.status,
      successCriteria: successCriteria ?? existingGoal.successCriteria,
      updatedAt: DateTime.now(),
    );

    await _goalRepository.updateGoal(updatedGoal);

    return updatedGoal;
  }

  /// 删除目标（软删除：设置status='deleted'）
  Future<void> deleteGoal(String goalId) async {
    // 1. 获取相关计划
    final plans = await _planRepository.getPlansByGoalId(goalId);

    // 2. 软删除所有相关计划（级联软删除：设置status='deleted'）
    for (final plan in plans) {
      await _planRepository.deletePlan(plan.id);
    }

    // 3. 软删除目标（设置status='deleted'和deleted_at）
    await _goalRepository.deleteGoal(goalId);
  }

  /// 计算目标进度
  Future<double> calculateGoalProgress(String goalId) async {
    // 1. 获取目标的所有计划
    final plans = await _planRepository.getPlansByGoalId(goalId);

    if (plans.isEmpty) {
      return 0.0;
    }

    // 2. 计算每个计划的完成率
    double totalProgress = 0;
    for (final plan in plans) {
      totalProgress += await _calculatePlanProgress(plan);
    }

    // 3. 返回平均完成率
    return totalProgress / plans.length;
  }

  Future<double> _calculatePlanProgress(Plan plan) async {
    // 这里调用计划的统计方法
    return plan.completionRate;
  }
}
```

### 6.2 计划管理

```dart
class PlanManagementService {
  final PlanRepository _planRepository;
  final TaskRepository _taskRepository;
  final TaskGenerationService _generationService;

  PlanManagementService({
    required PlanRepository planRepository,
    required TaskRepository taskRepository,
    required TaskGenerationService generationService,
  }) : _planRepository = planRepository,
       _taskRepository = taskRepository,
       _generationService = generationService;

  /// 创建计划
  Future<Plan> createPlan({
    required String userId,
    required String goalId,
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    required RepeatRule repeatRule,
    required TaskConfiguration taskConfig,
  }) async {
    // 1. 验证输入
    _validatePlanInput(
      name: name,
      startDate: startDate,
      endDate: endDate,
      repeatRule: repeatRule,
      taskConfig: taskConfig,
    );

    // 2. 检查计划名称唯一性（用户范围内）
    final existingPlan = await _planRepository.getPlanByUserAndName(userId, name);
    if (existingPlan != null) {
      throw BusinessException('该名称的计划已存在');
    }

    // 3. 创建计划实体
    final plan = Plan(
      id: IdGenerator.generateUuid(), // 使用UUID作为ID
      userId: userId,
      name: name,
      description: description?.trim(),
      goalId: goalId,
      startDate: startDate,
      endDate: endDate,
      repeatRule: repeatRule,
      taskConfig: taskConfig,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 4. 保存到数据库
    await _planRepository.createPlan(plan);

    // 5. 立即生成第一个任务
    await _generationService.generateNextTask(plan);

    return plan;
  }

  /// 更新计划
  /// 注意：计划名称（name）创建后不可修改
  Future<Plan> updatePlan({
    required String planId,
    String? description,
    DateTime? endDate,
    RepeatRule? repeatRule,
    TaskConfiguration? taskConfig,
    PlanStatus? status,
  }) async {
    // 1. 获取现有计划
    final existingPlan = await _planRepository.getPlan(planId);
    if (existingPlan == null) {
      throw NotFoundException('计划不存在');
    }

    // 2. 验证结束日期
    if (endDate != null && endDate.isBefore(existingPlan.startDate)) {
      throw ValidationException('结束日期不能早于开始日期');
    }

    // 3. 验证任务配置
    if (taskConfig != null && !taskConfig.isValid) {
      throw ValidationException('任务配置不合法');
    }

    // 4. 更新计划（name字段不可修改）
    final updatedPlan = existingPlan.copyWith(
      description: description ?? existingPlan.description,
      endDate: endDate ?? existingPlan.endDate,
      repeatRule: repeatRule ?? existingPlan.repeatRule,
      taskConfig: taskConfig ?? existingPlan.taskConfig,
      status: status ?? existingPlan.status,
      updatedAt: DateTime.now(),
    );

    await _planRepository.updatePlan(updatedPlan);

    return updatedPlan;
  }

  /// 删除计划（软删除：设置status='deleted'）
  Future<void> deletePlan(String planId) async {
    // 1. 软删除相关的所有任务（设置status='deleted'）
    await _taskRepository.deleteTasksByPlanId(planId);

    // 2. 软删除计划（设置status='deleted'和deleted_at）
    await _planRepository.deletePlan(planId);
  }

  /// 暂停计划
  Future<void> pausePlan(String planId) async {
    // 1. 获取计划的活跃任务
    final activeTasks = await _taskRepository.getActiveTasksByPlanId(planId);

    // 2. 将所有活跃任务标记为跳过
    for (final task in activeTasks) {
      await _taskRepository.updateTask(
        task.copyWith(
          status: TaskStatus.skipped,
          skippedAt: DateTime.now(),
          executionNote: '计划暂停',
        ),
      );
    }
  }

  /// 恢复计划
  Future<void> resumePlan(String planId) async {
    // 获取计划并生成新任务
    final plan = await _planRepository.getPlan(planId);
    if (plan != null && plan.isActive) {
      await _generationService.generateNextTask(plan);
    }
  }

  /// 验证计划输入
  void _validatePlanInput({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required RepeatRule repeatRule,
    required TaskConfiguration taskConfig,
  }) {
    // 名称验证
    if (name.trim().isEmpty) {
      throw ValidationException('计划名称不能为空');
    }

    // 日期验证
    if (endDate.isBefore(startDate)) {
      throw ValidationException('结束日期不能早于开始日期');
    }

    // 重复规则验证
    if (!repeatRule.isValid) {
      throw ValidationException('无效的重复规则');
    }

    // 任务配置验证
    if (!taskConfig.isValid) {
      throw ValidationException('无效的任务配置');
    }
  }
}
```

### 6.3 完成目标 (Complete Goal)

#### 功能描述
用户可以在目标详情页面点击"完成"按钮来完成一个目标。完成目标会自动处理所有关联的计划和任务，确保数据一致性。

#### 业务规则
1. **前置条件**：
   - 只有状态为 `active` 或 `paused` 的目标可以被完成
   - 已删除的目标不能被完成
   - 已完成的目标不能重复完成

2. **完成操作**（原子性事务）：
   - 将该目标下所有计划中的活跃任务（在当前执行窗口内）标记为 `skipped`
   - 将该目标下的所有计划状态更新为 `completed`
   - 将目标状态更新为 `completed`

3. **事务保证**：
   - 使用数据库事务确保所有操作要么全部成功，要么全部回滚
   - 任何步骤失败都会导致整个操作回滚，保持数据一致性

4. **任务跳过逻辑**：
   - 只跳过满足以下条件的任务：
     - `task.status == TaskStatus.active`
     - `task.isInCurrentWindow == true`（当前时间在任务的执行窗口内）
   - 跳过原因：`executionNote = '目标已完成'`

#### 实现代码

```dart
/// 完成目标
///
/// 将目标及其所有关联的计划和活跃任务标记为完成状态。
/// 使用数据库事务确保操作的原子性。
///
/// 参数：
/// - [goalId]: 要完成的目标ID
///
/// 返回：
/// - 更新后的目标对象
///
/// 异常：
/// - [NotFoundException]: 目标不存在
/// - [BusinessException]: 目标已完成或已删除
Future<GoalModel> completeGoal(String goalId) async {
  AppLogger.i('Completing goal: $goalId', tag: 'GoalManagementService');

  // 1. 获取并验证目标
  final goal = await _goalRepository.getGoalById(goalId);
  if (goal == null) {
    throw const NotFoundException('目标不存在');
  }

  if (goal.status == GoalStatus.completed) {
    throw const BusinessException('目标已完成，无法重复完成');
  }

  if (goal.status == GoalStatus.deleted) {
    throw const BusinessException('已删除的目标无法完成');
  }

  // 2. 获取目标的所有计划
  final plans = await _planRepository.getGoalPlans(goalId);
  AppLogger.d('Found ${plans.length} plans for goal', tag: 'GoalManagementService');

  // 3. 使用数据库事务确保原子性
  final db = await AppDatabase.instance.database;

  try {
    await db.transaction((txn) async {
      // 3.1 跳过所有计划中当前执行窗口内的活跃任务
      for (final plan in plans) {
        final tasks = await _taskRepository.getPlanTasks(plan.id);

        // 筛选活跃且在当前执行窗口内的任务
        final tasksToSkip = tasks.where((task) =>
          task.status == TaskStatus.active && task.isInCurrentWindow
        ).toList();

        AppLogger.d('Skipping ${tasksToSkip.length} tasks for plan ${plan.name}', tag: 'GoalManagementService');

        // 跳过这些任务
        for (final task in tasksToSkip) {
          await txn.update(
            'tasks',
            {
              'status': TaskStatus.skipped.toDbString(),
              'skipped_at': AppDatabase.getCurrentTimestamp(),
              'execution_note': '目标已完成',
            },
            where: 'id = ?',
            whereArgs: [task.id],
          );
        }
      }

      // 3.2 更新所有计划为已完成状态
      for (final plan in plans) {
        if (plan.status != PlanStatus.deleted) {
          await txn.update(
            'plans',
            {
              'status': PlanStatus.completed.toDbString(),
              'updated_at': AppDatabase.getCurrentTimestamp(),
            },
            where: 'id = ?',
            whereArgs: [plan.id],
          );
        }
      }

      // 3.3 更新目标为已完成状态
      await txn.update(
        'goals',
        {
          'status': GoalStatus.completed.toDbString(),
          'updated_at': AppDatabase.getCurrentTimestamp(),
        },
        where: 'id = ?',
        whereArgs: [goalId],
      );
    });

    AppLogger.i('Goal completed successfully', tag: 'GoalManagementService');
  } catch (e) {
    AppLogger.e('Failed to complete goal', tag: 'GoalManagementService', error: e);
    throw BusinessException('完成目标失败: ${e.toString()}');
  }

  // 4. 重新获取并返回更新后的目标
  final updatedGoal = await _goalRepository.getGoalById(goalId);
  if (updatedGoal == null) {
    throw const NotFoundException('目标更新后未找到');
  }

  return updatedGoal;
}
```

#### 使用示例

```dart
// 在目标详情页点击完成按钮
try {
  final completedGoal = await goalManagementService.completeGoal(goalId);
  print('目标"${completedGoal.title}"已完成');
  // 导航回目标列表
  Navigator.pop(context);
} catch (e) {
  // 显示错误消息
  showErrorDialog('完成目标失败: ${e.toString()}');
}
```

#### 注意事项

1. **数据一致性**：使用事务确保所有操作的原子性，避免出现部分更新的情况
2. **性能考虑**：对于拥有大量计划和任务的目标，完成操作可能需要较长时间，建议在UI显示加载指示器
3. **不可逆操作**：目标完成后，相关的计划将不再生成新任务
4. **任务跳过**：只跳过当前执行窗口内的活跃任务，已完成或已跳过的任务保持不变

### 6.4 暂停目标 (Pause Goal)

#### 功能描述
用户可以在目标列表页面点击"暂停"按钮来暂停一个目标。暂停目标会自动处理所有关联的计划和活跃任务，允许用户后续恢复目标的执行。

#### 业务规则
1. **前置条件**：
   - 只有状态为 `active` 的目标可以被暂停
   - 已删除、已完成或已暂停的目标不能被暂停

2. **暂停操作**（原子性事务）：
   - 将该目标下所有计划中的活跃任务（在当前执行窗口内）标记为 `deleted`（软删除）
   - 将该目标下的所有计划状态更新为 `paused`
   - 将目标状态更新为 `paused`

3. **事务保证**：
   - 使用数据库事务确保所有操作要么全部成功，要么全部回滚
   - 任何步骤失败都会导致整个操作回滚，保持数据一致性

4. **任务软删除逻辑**：
   - 只删除满足以下条件的任务：
     - `task.status == TaskStatus.active`
     - `task.isInCurrentWindow == true`（当前时间在任务的执行窗口内）
   - 删除方式：软删除（设置 `status = 'deleted'` 和 `deleted_at` 时间戳）
   - 删除原因：`executionNote = '目标已暂停'`

5. **与完成目标的区别**：
   - 完成目标时，任务被标记为 `skipped`（跳过）
   - 暂停目标时，任务被标记为 `deleted`（软删除）
   - 暂停的目标可以恢复，而完成的目标不可恢复

#### 实现代码

```dart
/// 暂停目标
///
/// 将目标及其所有关联的计划和活跃任务标记为暂停/删除状态。
/// 使用数据库事务确保操作的原子性。
///
/// 参数：
/// - [goalId]: 要暂停的目标ID
///
/// 返回：
/// - 更新后的目标对象
///
/// 异常：
/// - [NotFoundException]: 目标不存在
/// - [BusinessException]: 目标已暂停、已完成或已删除
Future<GoalModel> pauseGoal(String goalId) async {
  AppLogger.i('Pausing goal: $goalId', tag: 'GoalManagementService');

  // 1. 获取并验证目标
  final goal = await _goalRepository.getGoalById(goalId);
  if (goal == null) {
    throw const NotFoundException('目标不存在');
  }

  if (goal.status == GoalStatus.paused) {
    throw const BusinessException('目标已暂停，无法重复暂停');
  }

  if (goal.status == GoalStatus.completed) {
    throw const BusinessException('已完成的目标无法暂停');
  }

  if (goal.status == GoalStatus.deleted) {
    throw const BusinessException('已删除的目标无法暂停');
  }

  // 2. 获取目标的所有计划
  final plans = await _planRepository.getGoalPlans(goalId);
  AppLogger.d('Found ${plans.length} plans for goal', tag: 'GoalManagementService');

  // 3. 使用数据库事务确保原子性
  final db = await AppDatabase.instance.database;

  try {
    await db.transaction((txn) async {
      // 3.1 软删除所有计划中当前执行窗口内的活跃任务
      for (final plan in plans) {
        final tasks = await _taskRepository.getPlanTasks(plan.id);

        // 筛选活跃且在当前执行窗口内的任务
        final tasksToDelete = tasks.where((task) =>
          task.status == TaskStatus.active && task.isInCurrentWindow
        ).toList();

        AppLogger.d('Deleting ${tasksToDelete.length} tasks for plan ${plan.name}', tag: 'GoalManagementService');

        // 软删除这些任务
        for (final task in tasksToDelete) {
          await txn.update(
            'tasks',
            {
              'status': TaskStatus.deleted.toDbString(),
              'deleted_at': AppDatabase.getCurrentTimestamp(),
              'execution_note': '目标已暂停',
            },
            where: 'id = ?',
            whereArgs: [task.id],
          );
        }
      }

      // 3.2 更新所有计划为暂停状态
      for (final plan in plans) {
        if (plan.status != PlanStatus.deleted) {
          await txn.update(
            'plans',
            {
              'status': PlanStatus.paused.toDbString(),
              'updated_at': AppDatabase.getCurrentTimestamp(),
            },
            where: 'id = ?',
            whereArgs: [plan.id],
          );
        }
      }

      // 3.3 更新目标为暂停状态
      await txn.update(
        'goals',
        {
          'status': GoalStatus.paused.toDbString(),
          'updated_at': AppDatabase.getCurrentTimestamp(),
        },
        where: 'id = ?',
        whereArgs: [goalId],
      );
    });

    AppLogger.i('Goal paused successfully', tag: 'GoalManagementService');
  } catch (e) {
    AppLogger.e('Failed to pause goal', tag: 'GoalManagementService', error: e);
    throw BusinessException('暂停目标失败: ${e.toString()}');
  }

  // 4. 重新获取并返回更新后的目标
  final updatedGoal = await _goalRepository.getGoalById(goalId);
  if (updatedGoal == null) {
    throw const NotFoundException('目标更新后未找到');
  }

  return updatedGoal;
}
```

#### 使用示例

```dart
// 在目标列表页点击暂停按钮
try {
  final pausedGoal = await goalManagementService.pauseGoal(goalId);
  print('目标"${pausedGoal.title}"已暂停');
  // 刷新目标列表
  ref.read(goalListProvider.notifier).loadGoals();
} catch (e) {
  // 显示错误消息
  showErrorDialog('暂停目标失败: ${e.toString()}');
}
```

#### 注意事项

1. **数据一致性**：使用事务确保所有操作的原子性，避免出现部分更新的情况
2. **软删除**：任务被软删除而非物理删除，保留历史记录用于审计
3. **可恢复性**：暂停的目标可以恢复，恢复时会重新生成任务
4. **任务删除**：只删除当前执行窗口内的活跃任务，已完成或已跳过的任务保持不变
5. **计划状态**：所有非删除状态的计划都会被更新为暂停状态

## 7. 异常处理

### 7.1 业务异常定义

```dart
/// 基础异常类
abstract class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, [this.code]);

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// 业务逻辑异常
class BusinessException extends AppException {
  BusinessException(String message, [String? code]) : super(message, code);
}

/// 验证异常
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException(String message, {this.fieldErrors, String? code})
      : super(message, code);
}

/// 资源未找到异常
class NotFoundException extends AppException {
  NotFoundException(String message, [String? code]) : super(message, code);
}

/// 权限异常
class PermissionException extends AppException {
  PermissionException(String message, [String? code]) : super(message, code);
}

/// 并发冲突异常
class ConcurrencyException extends AppException {
  ConcurrencyException(String message, [String? code]) : super(message, code);
}
```

### 7.2 全局异常处理

```dart
class GlobalExceptionHandler {
  static void handleException(Object error, StackTrace stackTrace) {
    if (error is AppException) {
      _handleAppException(error);
    } else if (error is FormatException) {
      _handleFormatException(error);
    } else {
      _handleUnknownError(error, stackTrace);
    }
  }

  static void _handleAppException(AppException exception) {
    // 记录日志
    logger.warning('Business exception: ${exception.message}');

    // 显示用户友好的错误消息
    showErrorToast(exception.message);
  }

  static void _handleFormatException(FormatException exception) {
    logger.error('Format exception: ${exception.message}');
    showErrorToast('数据格式错误');
  }

  static void _handleUnknownError(Object error, StackTrace stackTrace) {
    logger.error('Unknown error', error, stackTrace);
    showErrorToast('系统错误，请稍后重试');
  }
}
```

## 8. 业务规则汇总

### 8.1 任务生成规则
1. 任务只能由系统自动生成，不能手动创建
2. 每个计划同一时间只能有一个活跃任务
3. 任务生成时机：
   - 应用启动时
   - 完成/跳过任务后
   - 手动刷新时
4. 任务窗口期根据重复规则计算

### 8.2 任务执行规则
1. 任务创建后不可编辑
2. 任务状态流转单向：Active → Completed/Skipped
3. 过期任务自动标记为跳过
4. 计时任务和评价任务互斥
5. 评价任务必须提供评价结果

### 8.3 计划管理规则
1. 计划名称作为ID，创建后不可修改
2. 计划必须关联到某个目标
3. 删除计划时级联软删除相关任务（设置status='deleted'）
4. 计划暂停时，活跃任务标记为跳过

### 8.4 目标管理规则
1. 已完成的目标不能修改
2. 删除目标时级联软删除相关计划和任务（设置status='deleted'）
3. 目标进度为所有计划进度的平均值

## 9. 性能优化策略

### 9.1 缓存策略
```dart
class CacheManager {
  // 内存缓存
  static final _memoryCache = <String, CacheEntry>{};

  // 缓存任务列表
  static Future<List<Task>> getCachedTasks(String userId) async {
    final key = 'tasks_$userId';
    final cached = _memoryCache[key];

    if (cached != null && !cached.isExpired) {
      return cached.data as List<Task>;
    }

    // 从数据库加载
    final tasks = await TaskRepository().getTasksByUserId(userId);

    // 更新缓存
    _memoryCache[key] = CacheEntry(
      data: tasks,
      expireTime: DateTime.now().add(Duration(minutes: 5)),
    );

    return tasks;
  }

  // 清除缓存
  static void clearCache(String? key) {
    if (key != null) {
      _memoryCache.remove(key);
    } else {
      _memoryCache.clear();
    }
  }
}

class CacheEntry {
  final dynamic data;
  final DateTime expireTime;

  CacheEntry({required this.data, required this.expireTime});

  bool get isExpired => DateTime.now().isAfter(expireTime);
}
```

### 9.2 批量操作优化
```dart
// 批量生成任务
Future<void> batchGenerateTasks(List<Plan> plans) async {
  final tasks = <Task>[];

  for (final plan in plans) {
    final task = await _generateTaskForPlan(plan);
    if (task != null) {
      tasks.add(task);
    }
  }

  // 批量插入数据库
  await _taskRepository.batchInsert(tasks);
}

// 批量更新状态
Future<void> batchUpdateTaskStatus(
  List<String> taskIds,
  TaskStatus newStatus,
) async {
  await _taskRepository.batchUpdateStatus(taskIds, newStatus);
}
```

## 10. 测试策略

### 10.1 单元测试示例

```dart
void main() {
  group('TaskGenerationService', () {
    late TaskGenerationService service;
    late MockTaskRepository taskRepository;
    late MockPlanRepository planRepository;

    setUp(() {
      taskRepository = MockTaskRepository();
      planRepository = MockPlanRepository();
      service = TaskGenerationService(
        taskRepository: taskRepository,
        planRepository: planRepository,
      );
    });

    test('should generate daily task when no previous task exists', () async {
      // Arrange
      final plan = Plan(
        id: 'test_plan',
        userId: 'user1',
        name: 'Daily Exercise',
        goalId: 'goal1',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
        repeatRule: RepeatRule(type: RepeatType.daily),
        taskConfig: TaskConfiguration(durationMinutes: 30),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(taskRepository.getLastTaskForPlan('test_plan'))
          .thenAnswer((_) async => null);

      // Act
      final task = await service.generateNextTask(plan);

      // Assert
      expect(task, isNotNull);
      expect(task!.planId, equals('test_plan'));
      expect(task.status, equals(TaskStatus.active));
      verify(taskRepository.createTask(any)).called(1);
    });

    test('should not generate task when active task exists', () async {
      // Arrange
      final plan = _createTestPlan();
      final activeTask = _createActiveTask(plan.id);

      when(taskRepository.getLastTaskForPlan(plan.id))
          .thenAnswer((_) async => activeTask);

      // Act
      final task = await service.generateNextTask(plan);

      // Assert
      expect(task, isNull);
      verifyNever(taskRepository.createTask(any));
    });
  });
}
```

## 总结

本文档定义了任务管理系统的核心业务逻辑，包括：

1. **任务生成服务**：自动生成任务的核心逻辑
2. **任务刷新服务**：定期检查和更新任务状态
3. **任务执行服务**：处理任务的完成和跳过
4. **目标与计划管理**：CRUD操作和业务规则
5. **异常处理**：统一的异常体系
6. **性能优化**：缓存和批量操作
7. **测试策略**：单元测试示例

这些业务逻辑服务将作为应用的核心引擎，确保系统按照既定规则正确运行。