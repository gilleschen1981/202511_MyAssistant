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

    // 5. 更新计划统计
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

## 5. 目标与计划管理逻辑

### 5.1 目标管理

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
      status: GoalStatus.inProgress,
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

  /// 删除目标
  Future<void> deleteGoal(String goalId) async {
    // 1. 获取相关计划
    final plans = await _planRepository.getPlansByGoalId(goalId);

    // 2. 删除所有相关计划（级联删除）
    for (final plan in plans) {
      await _planRepository.deletePlan(plan.id);
    }

    // 3. 删除目标
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

### 5.2 计划管理

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
  Future<Plan> updatePlan({
    required String planId,
    String? name,
    String? description,
    DateTime? endDate,
  }) async {
    // 1. 获取现有计划
    final existingPlan = await _planRepository.getPlan(planId);
    if (existingPlan == null) {
      throw NotFoundException('计划不存在');
    }

    // 2. 如果要修改名称，检查唯一性
    if (name != null && name != existingPlan.name) {
      final duplicatePlan = await _planRepository.getPlanByUserAndName(
        existingPlan.userId,
        name,
      );
      if (duplicatePlan != null && duplicatePlan.id != planId) {
        throw BusinessException('该名称的计划已存在');
      }
    }

    // 3. 验证结束日期
    if (endDate != null && endDate.isBefore(existingPlan.startDate)) {
      throw ValidationException('结束日期不能早于开始日期');
    }

    // 4. 更新计划
    final updatedPlan = existingPlan.copyWith(
      name: name ?? existingPlan.name,
      description: description ?? existingPlan.description,
      endDate: endDate ?? existingPlan.endDate,
      updatedAt: DateTime.now(),
    );

    await _planRepository.updatePlan(updatedPlan);

    return updatedPlan;
  }

  /// 删除计划
  Future<void> deletePlan(String planId) async {
    // 1. 删除相关的所有任务
    await _taskRepository.deleteTasksByPlanId(planId);

    // 2. 删除计划
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

## 6. 异常处理

### 6.1 业务异常定义

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

### 6.2 全局异常处理

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

## 7. 业务规则汇总

### 7.1 任务生成规则
1. 任务只能由系统自动生成，不能手动创建
2. 每个计划同一时间只能有一个活跃任务
3. 任务生成时机：
   - 应用启动时
   - 完成/跳过任务后
   - 手动刷新时
4. 任务窗口期根据重复规则计算

### 7.2 任务执行规则
1. 任务创建后不可编辑
2. 任务状态流转单向：Active → Completed/Skipped
3. 过期任务自动标记为跳过
4. 计时任务和评价任务互斥
5. 评价任务必须提供评价结果

### 7.3 计划管理规则
1. 计划名称作为ID，创建后不可修改
2. 计划必须关联到某个目标
3. 删除计划时级联删除相关任务
4. 计划暂停时，活跃任务标记为跳过

### 7.4 目标管理规则
1. 已完成的目标不能修改
2. 删除目标时级联删除相关计划和任务
3. 目标进度为所有计划进度的平均值

## 8. 性能优化策略

### 8.1 缓存策略
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

### 8.2 批量操作优化
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

## 9. 测试策略

### 9.1 单元测试示例

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