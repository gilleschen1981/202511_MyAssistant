# 状态管理设计

本文档定义了任务管理系统使用Riverpod进行状态管理的完整架构，包括Provider设计、状态流转、异步处理和最佳实践。

## 1. 状态管理架构概述

### 1.1 技术选型
- **框架**：Flutter Riverpod 2.4.0
- **架构模式**：MVVM + Repository Pattern
- **状态容器**：StateNotifier / AsyncNotifier
- **依赖注入**：Provider作为DI容器

### 1.2 架构分层

```
UI Layer (Widgets)
    ↓ watch/read
Provider Layer (State Management)
    ↓ 调用
Repository Layer (Data Access)
    ↓ 访问
Data Source (Local/Remote)
```

## 2. Provider组织结构图

### 2.1 Provider层级架构

```
┌──────────────────────────────────────────────────────────┐
│                      应用根Provider                        │
│                   ProviderScope/Container                 │
└──────────────────────────────────────────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼────────┐   ┌────────▼────────┐   ┌────────▼────────┐
│  基础设施层      │   │   业务服务层      │   │   状态管理层     │
│  Providers      │   │   Providers      │   │   Providers     │
├────────────────┤   ├─────────────────┤   ├─────────────────┤
│ • Database     │   │ • TaskGen       │   │ • TaskList      │
│ • Network      │   │ • TaskRefresh   │   │ • Timer         │
│ • Storage      │   │ • TaskExecution │   │ • Goals         │
│ • Notification │   │ • Sync Service  │   │ • Plans         │
└────────────────┘   └─────────────────┘   └─────────────────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼────────┐   ┌────────▼────────┐   ┌────────▼────────┐
│  Repository层   │   │    UI状态层      │   │   全局状态层     │
│  Providers      │   │   Providers      │   │   Providers     │
├────────────────┤   ├─────────────────┤   ├─────────────────┤
│ • TaskRepo     │   │ • Navigation    │   │ • Auth          │
│ • PlanRepo     │   │ • Forms         │   │ • Settings      │
│ • GoalRepo     │   │ • Dialogs       │   │ • Theme         │
│ • UserRepo     │   │ • Filters       │   │ • Locale        │
└────────────────┘   └─────────────────┘   └─────────────────┘
```

### 2.2 Provider依赖关系图

```
┌─────────────────────────────────────────────────────────────┐
│                    Provider依赖关系                          │
└─────────────────────────────────────────────────────────────┘

authProvider ─────────────┬──► currentUserProvider
                          │
                          ├──► taskListProvider
                          │     ├──► taskRepositoryProvider
                          │     ├──► taskRefreshServiceProvider
                          │     │     ├──► taskGenerationServiceProvider
                          │     │     │     ├──► taskRepositoryProvider
                          │     │     │     └──► planRepositoryProvider
                          │     │     └──► notificationServiceProvider
                          │     └──► taskExecutionServiceProvider
                          │           ├──► taskRepositoryProvider
                          │           ├──► planRepositoryProvider
                          │           └──► notificationServiceProvider
                          │
                          ├──► goalListProvider
                          │     ├──► goalRepositoryProvider
                          │     └──► goalManagementServiceProvider
                          │
                          ├──► planListProvider
                          │     ├──► planRepositoryProvider
                          │     └──► planManagementServiceProvider
                          │
                          └──► userSettingsProvider
                                └──► settingsRepositoryProvider

taskListProvider ─────────┬──► filteredTasksProvider
                          ├──► taskStatisticsProvider
                          └──► selectedTaskProvider

timerProvider ────────────┬──► taskExecutionServiceProvider
                          └──► pomodoroStatsProvider

themeProvider ◄────────────── userSettingsProvider
localeProvider ◄───────────── userSettingsProvider
```

### 2.3 Provider类型分布

```
Provider类型使用指南
├── Provider (30%) - 服务实例、仓库、工具类
│   ├── databaseProvider
│   ├── taskRepositoryProvider
│   ├── planRepositoryProvider
│   └── notificationServiceProvider
│
├── AsyncNotifierProvider (40%) - 异步状态管理
│   ├── taskListProvider
│   ├── goalListProvider
│   ├── planListProvider
│   └── userSettingsProvider
│
├── StateNotifierProvider (15%) - 复杂同步状态
│   ├── timerProvider
│   ├── authProvider
│   └── navigationProvider
│
├── FutureProvider (10%) - 一次性异步数据
│   ├── appInitializationProvider
│   ├── taskStatisticsProvider
│   └── goalProgressProvider
│
└── StateProvider (5%) - 简单状态值
    ├── selectedTaskProvider
    ├── bottomNavIndexProvider
    └── globalLoadingProvider
```

## 3. 状态更新流程设计

### 3.1 任务完成流程

```
用户操作                Provider层                    Repository层              数据层
   │                         │                            │                      │
   ├─[点击完成]──────────────►│                            │                      │
   │                         │                            │                      │
   │               taskListProvider.notifier               │                      │
   │                    .completeTask()                   │                      │
   │                         ├──────────────────────────►│                      │
   │                         │                            │                      │
   │                         │              taskExecutionService                 │
   │                         │                 .completeTask()                   │
   │                         │                            ├──────────────────────►│
   │                         │                            │                      │
   │                         │                            │         更新数据库     │
   │                         │                            │◄──────────────────────┤
   │                         │                            │                      │
   │                         │◄───────────────────────────┤                      │
   │                         │                            │                      │
   │                    更新本地状态                        │                      │
   │                    state.tasks                       │                      │
   │                         │                            │                      │
   │                         ├──────────────────────────►│                      │
   │                         │                            │                      │
   │                         │           更新Plan统计信息   │                      │
   │                         │                            ├──────────────────────►│
   │                         │                            │◄──────────────────────┤
   │                         │                            │                      │
   │                         │◄───────────────────────────┤                      │
   │                         │                            │                      │
   │                  触发依赖更新:                         │                      │
   │              • taskStatisticsProvider                │                      │
   │              • selectedTaskProvider                  │                      │
   │              • goalProgressProvider                  │                      │
   │                         │                            │                      │
   │◄────────────────────────┤                            │                      │
   │                         │                            │                      │
 UI更新                      │                            │                      │
```

### 3.2 异步状态处理流程

```
┌──────────────────────────────────────────────────────────┐
│                   异步状态生命周期                         │
└──────────────────────────────────────────────────────────┘

Initial State ──► Loading ──► Success ──► Data State
                    │            │
                    └──► Error ◄─┘
                           │
                        Retry ──┐
                           │    │
                           └────┘

代码实现:
state = const AsyncValue.loading();  // 开始加载

try {
  final data = await repository.fetchData();
  state = AsyncValue.data(data);      // 成功状态
} catch (e, stack) {
  state = AsyncValue.error(e, stack); // 错误状态
}
```

### 3.3 状态订阅与响应

```
┌──────────────────────────────────────────────────────────┐
│                    状态订阅机制                            │
└──────────────────────────────────────────────────────────┘

Widget层:
┌──────────────┐
│ConsumerWidget│
└──────┬───────┘
       │
   ref.watch() ──────► Provider
       │                   │
       │              状态变化
       │                   │
   自动rebuild ◄──────通知──┘

Provider层:
┌─────────────────────────┐
│ taskListProvider        │
├─────────────────────────┤
│ dependencies:           │
│ • currentUserProvider   │──► 自动重新计算
│ • taskRepositoryProvider│     当依赖变化
└─────────────────────────┘

监听机制:
ref.listen(provider, (previous, next) {
  // 响应状态变化
});
```

## 4. 缓存策略设计

### 4.1 缓存层级

```
┌──────────────────────────────────────────────────────────┐
│                     缓存层级架构                          │
└──────────────────────────────────────────────────────────┘

L1: Provider内存缓存
    ├── 生命周期：应用运行期间
    ├── 适用：高频访问数据
    └── 示例：当前任务列表、用户信息

L2: Repository缓存
    ├── 生命周期：可配置（5-30分钟）
    ├── 适用：中频访问数据
    └── 示例：目标列表、计划列表

L3: 本地数据库缓存
    ├── 生命周期：永久存储
    ├── 适用：所有用户数据
    └── 示例：SQLite数据库

L4: SharedPreferences缓存
    ├── 生命周期：永久存储
    ├── 适用：配置和设置
    └── 示例：用户偏好、登录凭证
```

### 4.2 缓存策略实现

```dart
// 缓存配置
class CacheConfig {
  static const Duration shortTerm = Duration(minutes: 5);
  static const Duration mediumTerm = Duration(minutes: 15);
  static const Duration longTerm = Duration(hours: 1);
}

// 带缓存的Provider
@riverpod
class CachedDataNotifier extends _$CachedDataNotifier {
  Timer? _cacheTimer;
  DateTime? _lastFetch;

  @override
  FutureOr<Data> build() async {
    // 设置缓存过期定时器
    ref.onDispose(() => _cacheTimer?.cancel());

    return _fetchData();
  }

  Future<Data> _fetchData() async {
    // 检查缓存有效性
    if (_isValidCache()) {
      return state.value!;
    }

    // 获取新数据
    final data = await repository.getData();
    _lastFetch = DateTime.now();

    // 设置缓存失效定时器
    _setupCacheInvalidation();

    return data;
  }

  bool _isValidCache() {
    if (_lastFetch == null || !state.hasValue) return false;

    final elapsed = DateTime.now().difference(_lastFetch!);
    return elapsed < CacheConfig.mediumTerm;
  }

  void _setupCacheInvalidation() {
    _cacheTimer?.cancel();
    _cacheTimer = Timer(CacheConfig.mediumTerm, () {
      ref.invalidateSelf();
    });
  }

  // 手动刷新
  Future<void> refresh() async {
    _lastFetch = null;
    ref.invalidateSelf();
  }
}
```

### 4.3 缓存失效策略

```
┌──────────────────────────────────────────────────────────┐
│                    缓存失效触发条件                        │
└──────────────────────────────────────────────────────────┘

1. 时间失效（TTL）
   └── 固定时间后自动失效

2. 事件失效
   ├── 用户操作（创建/更新/删除）
   ├── 后台同步完成
   └── 应用前后台切换

3. 依赖失效
   └── 依赖的Provider更新时

4. 手动失效
   ├── 下拉刷新
   └── 显式调用refresh()

失效传播机制：
taskCompleted ──► taskListCache失效
                  ├──► taskStatisticsCache失效
                  └──► goalProgressCache失效
```

### 4.4 智能预加载策略

```dart
// 预加载管理器
class PreloadManager {
  final WidgetRef ref;

  PreloadManager(this.ref);

  // 应用启动时预加载
  Future<void> preloadOnAppStart() async {
    await Future.wait([
      ref.read(userSettingsProvider.future),
      ref.read(taskListProvider.future),
      ref.read(goalListProvider.future),
    ]);
  }

  // 页面切换预加载
  void preloadForRoute(String route) {
    switch (route) {
      case '/tasks':
        ref.read(taskListProvider);
        ref.read(taskStatisticsProvider);
        break;
      case '/goals':
        ref.read(goalListProvider);
        ref.read(planListProvider);
        break;
      case '/review':
        // 延迟加载重量级数据
        Future.delayed(Duration(milliseconds: 500), () {
          ref.read(reviewDataProvider);
        });
        break;
    }
  }

  // 基于用户行为的预测性加载
  void predictiveLoad(UserAction action) {
    if (action == UserAction.scrollNearBottom) {
      // 预加载下一页数据
      ref.read(nextPageProvider);
    }
  }
}
```

## 5. Provider详细实现

### 5.1 Provider类型定义

```dart
// Provider类型说明
/*
1. Provider: 用于提供不变的值或服务实例
2. StateProvider: 用于简单的状态（单个值）
3. StateNotifierProvider: 用于复杂状态管理
4. FutureProvider: 用于异步数据获取
5. StreamProvider: 用于流式数据
6. AsyncNotifierProvider: 用于异步状态管理（推荐）
*/
```

### 5.2 全局Provider定义

```dart
// lib/providers/providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============= 服务层Provider =============

/// 数据库实例
final databaseProvider = Provider<Database>((ref) {
  return DatabaseHelper.instance.database;
});

/// 任务生成服务
final taskGenerationServiceProvider = Provider<TaskGenerationService>((ref) {
  final taskRepo = ref.watch(taskRepositoryProvider);
  final planRepo = ref.watch(planRepositoryProvider);

  return TaskGenerationService(
    taskRepository: taskRepo,
    planRepository: planRepo,
  );
});

/// 任务刷新服务
final taskRefreshServiceProvider = Provider<TaskRefreshService>((ref) {
  final taskRepo = ref.watch(taskRepositoryProvider);
  final generationService = ref.watch(taskGenerationServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  return TaskRefreshService(
    taskRepository: taskRepo,
    generationService: generationService,
    notificationService: notificationService,
  );
});

/// 任务执行服务
final taskExecutionServiceProvider = Provider<TaskExecutionService>((ref) {
  final taskRepo = ref.watch(taskRepositoryProvider);
  final planRepo = ref.watch(planRepositoryProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  return TaskExecutionService(
    taskRepository: taskRepo,
    planRepository: planRepo,
    notificationService: notificationService,
  );
});

// ============= Repository层Provider =============

/// 任务仓库
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TaskRepository(db);
});

/// 计划仓库
final planRepositoryProvider = Provider<PlanRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PlanRepository(db);
});

/// 目标仓库
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return GoalRepository(db);
});

/// 用户仓库
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UserRepository(db);
});

// ============= 通知服务Provider =============

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
```

## 6. 任务管理状态

### 6.1 任务列表状态管理

```dart
// lib/presentation/providers/task_list_notifier.dart

/// 任务列表状态
@freezed
class TaskListState with _$TaskListState {
  const factory TaskListState({
    required List<TaskModel> allTasks,
    required List<TaskModel> todayTasks,
    required List<TaskModel> activeTasks,
    required List<TaskModel> completedTasks,
    required List<TaskModel> filteredTasks,
    required Map<String, TimerSession> activeSessions,
    @Default(TaskFilter.all) TaskFilter currentFilter,
    String? error,
  }) = _TaskListState;

  factory TaskListState.initial() => const TaskListState(
        allTasks: [],
        todayTasks: [],
        activeTasks: [],
        completedTasks: [],
        filteredTasks: [],
        activeSessions: {},
      );
}
```

```dart
// lib/data/models/enums/task_filter.dart

/// 任务过滤器
/// Task filter options for filtering task list
enum TaskFilter {
  /// All tasks regardless of status
  all('全部'),

  /// Only active tasks (pending execution)
  active('待执行'),

  /// Only completed tasks
  completed('已完成'),

  /// Only skipped tasks
  skipped('已跳过');

  const TaskFilter(this.label);

  /// Display label for the filter
  final String label;
}

/// 任务列表Provider
@riverpod
class TaskListNotifier extends _$TaskListNotifier {
  late ITaskRepository _taskRepository;
  late TaskExecutionService _executionService;
  late TaskRefreshService _refreshService;

  @override
  FutureOr<TaskListState> build() async {
    // Get dependencies
    _taskRepository = ref.watch(taskRepositoryProvider);
    _executionService = ref.watch(taskExecutionServiceProvider);
    _refreshService = ref.watch(taskRefreshServiceProvider);

    // Load initial data
    return await _loadTasks();
  }

  /// 加载任务列表
  Future<TaskListState> _loadTasks() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return TaskListState.initial();
    }

    try {
      // Get today's tasks
      final todayTasks = await _taskRepository.getTodayTasks(user.id);

      // Filter by status
      final activeTasks = todayTasks
          .where((t) => t.status == TaskStatus.active)
          .toList();
      final completedTasks = todayTasks
          .where((t) => t.status == TaskStatus.completed)
          .toList();

      // Get active timer sessions
      final activeSessions = _executionService.getActiveSessions();

      return TaskListState(
        allTasks: todayTasks,
        todayTasks: todayTasks,
        activeTasks: activeTasks,
        completedTasks: completedTasks,
        filteredTasks: todayTasks, // Initially show all tasks
        activeSessions: activeSessions,
      );
    } catch (e) {
      // Return state with error
      return TaskListState.initial().copyWith(
        error: e.toString(),
      );
    }
  }

  /// 刷新任务
  Future<void> refreshTasks() async {
    if (state.valueOrNull?.isRefreshing ?? false) return;

    state = AsyncValue.data(
      state.value!.copyWith(isRefreshing: true),
    );

    try {
      // 刷新任务（生成新任务，处理过期任务）
      final result = await _refreshService.refreshAllTasks();

      // 重新加载任务列表
      await _loadTasks();

      // 显示刷新结果
      if (result.generatedCount > 0) {
        _showNotification('生成了 ${result.generatedCount} 个新任务');
      }
    } catch (e) {
      state = AsyncValue.data(
        state.value!.copyWith(
          isRefreshing: false,
          error: e.toString(),
        ),
      );
    }
  }

  /// 完成任务
  Future<void> completeTask(Task task, {
    int? actualDuration,
    String? evaluation,
    String? note,
  }) async {
    try {
      final result = await _executionService.completeTask(
        task: task,
        actualDurationMinutes: actualDuration,
        evaluationResult: evaluation,
        executionNote: note,
      );

      // 更新任务列表
      state = AsyncValue.data(
        state.value!.copyWith(
          tasks: state.value!.tasks.map((t) {
            if (t.id == task.id) {
              return result.completedTask;
            }
            return t;
          }).toList(),
        ),
      );

      // 如果生成了新任务，添加到列表
      if (result.nextTask != null) {
        state = AsyncValue.data(
          state.value!.copyWith(
            tasks: [...state.value!.tasks, result.nextTask!],
          ),
        );
      }

      // 应用当前过滤器
      _applyCurrentFilter();

      // 显示成功消息
      _showNotification('任务已完成');
    } catch (e) {
      _showError('完成任务失败: $e');
    }
  }

  /// 跳过任务
  Future<void> skipTask(Task task, {String? reason}) async {
    try {
      await _executionService.skipTask(
        task: task,
        skipReason: reason,
      );

      // 更新任务状态
      state = AsyncValue.data(
        state.value!.copyWith(
          tasks: state.value!.tasks.map((t) {
            if (t.id == task.id) {
              return t.copyWith(
                status: TaskStatus.skipped,
                skippedAt: DateTime.now(),
                executionNote: reason,
              );
            }
            return t;
          }).toList(),
        ),
      );

      _applyCurrentFilter();
      _showNotification('任务已跳过');
    } catch (e) {
      _showError('跳过任务失败: $e');
    }
  }

  /// 设置过滤器
  /// Set filter and update filtered tasks
  void setFilter(TaskFilter filter) {
    if (state.valueOrNull == null) return;

    final currentState = state.value!;
    final filteredTasks = _applyFilter(currentState.todayTasks, filter);

    state = AsyncValue.data(
      currentState.copyWith(
        currentFilter: filter,
        filteredTasks: filteredTasks,
      ),
    );
  }

  /// 应用过滤器
  /// Apply filter to task list
  List<TaskModel> _applyFilter(List<TaskModel> tasks, TaskFilter filter) {
    switch (filter) {
      case TaskFilter.all:
        return tasks;
      case TaskFilter.active:
        return tasks.where((t) => t.status == TaskStatus.active).toList();
      case TaskFilter.completed:
        return tasks.where((t) => t.status == TaskStatus.completed).toList();
      case TaskFilter.skipped:
        return tasks.where((t) => t.status == TaskStatus.skipped).toList();
    }
  }

  /// 重新应用当前过滤器
  /// Reapply current filter after task list changes
  void _reapplyFilter() {
    if (state.valueOrNull == null) return;

    final currentState = state.value!;
    final filteredTasks = _applyFilter(
      currentState.todayTasks,
      currentState.currentFilter,
    );

    state = AsyncValue.data(
      currentState.copyWith(filteredTasks: filteredTasks),
    );
  }

  /// 设置定时刷新
  void _setupPeriodicRefresh() {
    // 每30分钟自动刷新
    ref.onDispose(() {});  // 清理定时器

    Timer.periodic(Duration(minutes: 30), (timer) {
      if (state.valueOrNull != null) {
        refreshTasks();
      }
    });
  }

  void _showNotification(String message) {
    // 通过通知服务显示消息
    ref.read(notificationServiceProvider).showMessage(message);
  }

  void _showError(String error) {
    // 显示错误消息
    ref.read(notificationServiceProvider).showError(error);
  }
}

/// 任务列表Provider
final taskListProvider = AsyncNotifierProvider<TaskListNotifier, TaskListState>(
  () => TaskListNotifier(),
);

/// 选中的任务Provider
final selectedTaskProvider = StateProvider<Task?>((ref) => null);

/// 任务统计Provider
final taskStatisticsProvider = FutureProvider<TaskStatistics>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id ?? 'default_user';
  final taskRepo = ref.watch(taskRepositoryProvider);

  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);

  final todayTasks = await taskRepo.getTasksByDateRange(
    userId: userId,
    startDate: startOfDay,
    endDate: today,
  );

  return TaskStatistics(
    todayCompleted: todayTasks.where((t) => t.status == TaskStatus.completed).length,
    todayRemaining: todayTasks.where((t) => t.status == TaskStatus.active).length,
    todaySkipped: todayTasks.where((t) => t.status == TaskStatus.skipped).length,
  );
});
```

### 6.2 计时器状态管理

```dart
// lib/presentation/features/tasks/providers/timer_provider.dart

/// 计时器状态
@freezed
class TimerState with _$TimerState {
  const factory TimerState({
    Task? currentTask,
    @Default(TimerStatus.idle) TimerStatus status,
    @Default(Duration.zero) Duration elapsed,
    @Default(Duration.zero) Duration remaining,
    DateTime? startTime,
    DateTime? pauseTime,
    @Default(Duration.zero) Duration pausedDuration,
    @Default(0) int completedPomodoros,
  }) = _TimerState;
}

enum TimerStatus {
  idle,     // 空闲
  running,  // 运行中
  paused,   // 暂停
  completed,// 完成
}

/// 计时器Provider
@riverpod
class TimerNotifier extends _$TimerNotifier {
  Timer? _timer;
  late TaskExecutionService _executionService;

  @override
  TimerState build() {
    // 初始化服务
    _executionService = ref.watch(taskExecutionServiceProvider);

    // 清理计时器
    ref.onDispose(() {
      _timer?.cancel();
    });

    return const TimerState();
  }

  /// 开始计时
  Future<void> startTimer(Task task) async {
    if (task.config.durationMinutes == null) {
      throw Exception('非计时任务');
    }

    // 停止当前计时器
    _timer?.cancel();

    // 创建计时会话
    final session = await _executionService.startTimer(task);

    state = TimerState(
      currentTask: task,
      status: TimerStatus.running,
      startTime: session.startTime,
      remaining: session.targetDuration,
    );

    // 启动计时器
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      _updateTimer();
    });
  }

  /// 暂停计时
  void pauseTimer() {
    if (state.status != TimerStatus.running) return;

    _timer?.cancel();

    state = state.copyWith(
      status: TimerStatus.paused,
      pauseTime: DateTime.now(),
    );
  }

  /// 恢复计时
  void resumeTimer() {
    if (state.status != TimerStatus.paused) return;

    final pauseDuration = DateTime.now().difference(state.pauseTime!);

    state = state.copyWith(
      status: TimerStatus.running,
      pauseTime: null,
      pausedDuration: state.pausedDuration + pauseDuration,
    );

    // 重启计时器
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      _updateTimer();
    });
  }

  /// 停止计时
  void stopTimer() {
    _timer?.cancel();

    state = const TimerState();
  }

  /// 完成计时
  Future<void> completeTimer() async {
    if (state.currentTask == null) return;

    _timer?.cancel();

    final actualMinutes = state.elapsed.inMinutes;

    // 完成任务
    await ref.read(taskListProvider.notifier).completeTask(
      state.currentTask!,
      actualDuration: actualMinutes,
    );

    // 检查是否完成番茄钟
    if (state.currentTask!.config.durationMinutes == 25) {
      state = state.copyWith(
        completedPomodoros: state.completedPomodoros + 1,
      );
    }

    // 重置状态
    state = state.copyWith(
      status: TimerStatus.completed,
    );

    // 3秒后重置
    Future.delayed(Duration(seconds: 3), () {
      state = const TimerState();
    });
  }

  /// 更新计时器
  void _updateTimer() {
    if (state.status != TimerStatus.running || state.startTime == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(state.startTime!) - state.pausedDuration;

    final targetDuration = Duration(
      minutes: state.currentTask?.config.durationMinutes ?? 0,
    );

    final remaining = targetDuration - elapsed;

    if (remaining <= Duration.zero) {
      // 计时完成
      completeTimer();
    } else {
      state = state.copyWith(
        elapsed: elapsed,
        remaining: remaining,
      );
    }
  }

  /// 格式化时间
  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// 计时器Provider
final timerProvider = NotifierProvider<TimerNotifier, TimerState>(
  () => TimerNotifier(),
);

/// 番茄钟统计Provider
final pomodoroStatsProvider = StateProvider<PomodoroStats>((ref) {
  return PomodoroStats(
    dailyTarget: 8,
    weeklyTarget: 40,
  );
});

@freezed
class PomodoroStats with _$PomodoroStats {
  const factory PomodoroStats({
    @Default(0) int todayCompleted,
    @Default(8) int dailyTarget,
    @Default(0) int weekCompleted,
    @Default(40) int weeklyTarget,
  }) = _PomodoroStats;
}
```

## 7. 目标与计划状态管理

### 7.1 目标状态管理

```dart
// lib/presentation/features/goals/providers/goal_provider.dart

/// 目标列表Provider
final goalListProvider = AsyncNotifierProvider<GoalListNotifier, List<Goal>>(
  () => GoalListNotifier(),
);

@riverpod
class GoalListNotifier extends _$GoalListNotifier {
  late GoalRepository _goalRepository;
  late GoalManagementService _managementService;

  @override
  FutureOr<List<Goal>> build() async {
    _goalRepository = ref.watch(goalRepositoryProvider);
    _managementService = GoalManagementService(
      goalRepository: _goalRepository,
      planRepository: ref.watch(planRepositoryProvider),
    );

    return _loadGoals();
  }

  Future<List<Goal>> _loadGoals() async {
    final userId = ref.read(currentUserProvider)?.id ?? 'default_user';
    return await _goalRepository.getGoalsByUserId(userId);
  }

  /// 创建目标
  Future<void> createGoal({
    required String title,
    String? description,
    List<String>? tags,
    DateTime? deadline,
    Priority priority = Priority.medium,
    String? successCriteria,
  }) async {
    state = const AsyncValue.loading();

    try {
      final userId = ref.read(currentUserProvider)?.id ?? 'default_user';

      final goal = await _managementService.createGoal(
        userId: userId,
        title: title,
        description: description,
        tags: tags,
        deadline: deadline,
        priority: priority,
        successCriteria: successCriteria,
      );

      // 更新列表
      final goals = await _loadGoals();
      state = AsyncValue.data(goals);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// 更新目标
  Future<void> updateGoal(String goalId, {
    String? title,
    String? description,
    List<String>? tags,
    DateTime? deadline,
    Priority? priority,
    GoalStatus? status,
  }) async {
    try {
      await _managementService.updateGoal(
        goalId: goalId,
        title: title,
        description: description,
        tags: tags,
        deadline: deadline,
        priority: priority,
        status: status,
      );

      // 更新列表
      final goals = await _loadGoals();
      state = AsyncValue.data(goals);
    } catch (e) {
      // 显示错误但保持当前状态
      ref.read(notificationServiceProvider).showError(e.toString());
    }
  }

  /// 删除目标
  Future<void> deleteGoal(String goalId) async {
    try {
      await _managementService.deleteGoal(goalId);

      // 更新列表
      final goals = await _loadGoals();
      state = AsyncValue.data(goals);
    } catch (e) {
      ref.read(notificationServiceProvider).showError(e.toString());
    }
  }
}

/// 选中的目标Provider
final selectedGoalProvider = StateProvider<Goal?>((ref) => null);

/// 目标进度Provider
final goalProgressProvider = FutureProvider.family<double, String>((ref, goalId) async {
  final managementService = GoalManagementService(
    goalRepository: ref.watch(goalRepositoryProvider),
    planRepository: ref.watch(planRepositoryProvider),
  );

  return await managementService.calculateGoalProgress(goalId);
});

/// 目标详情Provider
final goalDetailProvider = FutureProvider.family<GoalDetail?, String>((ref, goalId) async {
  final goalRepo = ref.watch(goalRepositoryProvider);
  final planRepo = ref.watch(planRepositoryProvider);

  final goal = await goalRepo.getGoal(goalId);
  if (goal == null) return null;

  final plans = await planRepo.getPlansByGoalId(goalId);

  return GoalDetail(
    goal: goal,
    plans: plans,
    progress: await ref.watch(goalProgressProvider(goalId).future),
  );
});

@freezed
class GoalDetail with _$GoalDetail {
  const factory GoalDetail({
    required Goal goal,
    required List<Plan> plans,
    required double progress,
  }) = _GoalDetail;
}
```

### 7.2 计划状态管理

```dart
// lib/presentation/features/plans/providers/plan_provider.dart

/// 计划列表Provider
final planListProvider = AsyncNotifierProvider<PlanListNotifier, List<Plan>>(
  () => PlanListNotifier(),
);

@riverpod
class PlanListNotifier extends _$PlanListNotifier {
  late PlanRepository _planRepository;
  late PlanManagementService _managementService;

  @override
  FutureOr<List<Plan>> build() async {
    _planRepository = ref.watch(planRepositoryProvider);

    final taskRepo = ref.watch(taskRepositoryProvider);
    final generationService = ref.watch(taskGenerationServiceProvider);

    _managementService = PlanManagementService(
      planRepository: _planRepository,
      taskRepository: taskRepo,
      generationService: generationService,
    );

    return _loadPlans();
  }

  Future<List<Plan>> _loadPlans() async {
    final userId = ref.read(currentUserProvider)?.id ?? 'default_user';
    return await _planRepository.getPlansByUserId(userId);
  }

  /// 创建计划
  Future<void> createPlan({
    required String goalId,
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    required RepeatRule repeatRule,
    required TaskConfiguration taskConfig,
  }) async {
    state = const AsyncValue.loading();

    try {
      final userId = ref.read(currentUserProvider)?.id ?? 'default_user';

      final plan = await _managementService.createPlan(
        userId: userId,
        goalId: goalId,
        name: name,
        description: description,
        startDate: startDate,
        endDate: endDate,
        repeatRule: repeatRule,
        taskConfig: taskConfig,
      );

      // 更新列表
      final plans = await _loadPlans();
      state = AsyncValue.data(plans);

      // 刷新任务列表（因为会生成新任务）
      ref.invalidate(taskListProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// 暂停计划
  Future<void> pausePlan(String planId) async {
    try {
      await _managementService.pausePlan(planId);

      // 更新计划状态
      if (state.hasValue) {
        final plans = state.value!.map((plan) {
          if (plan.id == planId) {
            // 这里简化处理，实际应该有暂停状态
            return plan;
          }
          return plan;
        }).toList();

        state = AsyncValue.data(plans);
      }

      // 刷新任务列表
      ref.invalidate(taskListProvider);
    } catch (e) {
      ref.read(notificationServiceProvider).showError(e.toString());
    }
  }

  /// 恢复计划
  Future<void> resumePlan(String planId) async {
    try {
      await _managementService.resumePlan(planId);

      // 刷新任务列表
      ref.invalidate(taskListProvider);
    } catch (e) {
      ref.read(notificationServiceProvider).showError(e.toString());
    }
  }

  /// 删除计划
  Future<void> deletePlan(String planId) async {
    try {
      await _managementService.deletePlan(planId);

      // 更新列表
      final plans = await _loadPlans();
      state = AsyncValue.data(plans);

      // 刷新任务列表
      ref.invalidate(taskListProvider);
    } catch (e) {
      ref.read(notificationServiceProvider).showError(e.toString());
    }
  }
}

/// 目标的计划列表Provider
final plansByGoalProvider = FutureProvider.family<List<Plan>, String>((ref, goalId) async {
  final planRepo = ref.watch(planRepositoryProvider);
  return await planRepo.getPlansByGoalId(goalId);
});

/// 计划详情Provider
final planDetailProvider = FutureProvider.family<PlanDetail?, String>((ref, planId) async {
  final planRepo = ref.watch(planRepositoryProvider);
  final taskRepo = ref.watch(taskRepositoryProvider);

  final plan = await planRepo.getPlan(planId);
  if (plan == null) return null;

  final tasks = await taskRepo.getTasksByPlanId(planId);

  final stats = PlanStatistics(
    totalTasks: tasks.length,
    completedTasks: tasks.where((t) => t.status == TaskStatus.completed).length,
    skippedTasks: tasks.where((t) => t.status == TaskStatus.skipped).length,
    activeTasks: tasks.where((t) => t.status == TaskStatus.active).length,
  );

  return PlanDetail(
    plan: plan,
    tasks: tasks,
    statistics: stats,
  );
});

@freezed
class PlanDetail with _$PlanDetail {
  const factory PlanDetail({
    required Plan plan,
    required List<Task> tasks,
    required PlanStatistics statistics,
  }) = _PlanDetail;
}

@freezed
class PlanStatistics with _$PlanStatistics {
  const factory PlanStatistics({
    required int totalTasks,
    required int completedTasks,
    required int skippedTasks,
    required int activeTasks,
  }) = _PlanStatistics;
}
```

## 8. 用户与设置状态管理

### 8.1 用户认证状态

```dart
// lib/presentation/features/auth/providers/auth_provider.dart

/// 认证状态
@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(User user) = _Authenticated;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.error(String message) = _Error;
}

/// 认证Provider
@riverpod
class AuthNotifier extends _$AuthNotifier {
  late UserRepository _userRepository;

  @override
  AuthState build() {
    _userRepository = ref.watch(userRepositoryProvider);

    // 检查本地存储的认证状态
    _checkAuthStatus();

    return const AuthState.initial();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('current_user_id');

    if (userId != null) {
      final user = await _userRepository.getUserById(userId);
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  /// 登录
  Future<void> login(String username, String password) async {
    state = const AuthState.loading();

    try {
      final user = await _userRepository.authenticate(username, password);

      if (user != null) {
        // 保存用户ID
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_id', user.id);

        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.error('用户名或密码错误');
      }
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  /// 注册
  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();

    try {
      final user = await _userRepository.createUser(
        username: username,
        email: email,
        password: password,
      );

      // 自动登录
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', user.id);

      state = AuthState.authenticated(user);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  /// 登出
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');

    state = const AuthState.unauthenticated();
  }
}

/// 认证Provider
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  () => AuthNotifier(),
);

/// 当前用户Provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authProvider);

  return authState.maybeWhen(
    authenticated: (user) => user,
    orElse: () => null,
  );
});
```

### 8.2 用户设置状态

```dart
// lib/presentation/features/profile/providers/settings_provider.dart

/// 设置Provider
final userSettingsProvider = AsyncNotifierProvider<UserSettingsNotifier, UserSettings>(
  () => UserSettingsNotifier(),
);

@riverpod
class UserSettingsNotifier extends _$UserSettingsNotifier {
  late SettingsRepository _repository;

  @override
  FutureOr<UserSettings> build() async {
    _repository = ref.watch(settingsRepositoryProvider);

    final userId = ref.watch(currentUserProvider)?.id;
    if (userId == null) {
      return UserSettings.defaultSettings();
    }

    return await _repository.getUserSettings(userId);
  }

  /// 更新主题
  Future<void> updateTheme(ThemeMode mode) async {
    if (state.hasValue) {
      final updated = state.value!.copyWith(themeMode: mode);
      state = AsyncValue.data(updated);

      await _repository.updateSettings(updated);
    }
  }

  /// 更新语言
  Future<void> updateLocale(String locale) async {
    if (state.hasValue) {
      final updated = state.value!.copyWith(locale: locale);
      state = AsyncValue.data(updated);

      await _repository.updateSettings(updated);
    }
  }

  /// 更新通知设置
  Future<void> updateNotificationSettings({
    bool? enableNotifications,
    bool? enableSound,
    bool? enableVibration,
  }) async {
    if (state.hasValue) {
      final updated = state.value!.copyWith(
        enableNotifications: enableNotifications ?? state.value!.enableNotifications,
        enableSound: enableSound ?? state.value!.enableSound,
        enableVibration: enableVibration ?? state.value!.enableVibration,
      );

      state = AsyncValue.data(updated);
      await _repository.updateSettings(updated);
    }
  }
}

/// 主题Provider
final themeProvider = Provider<ThemeData>((ref) {
  final settings = ref.watch(userSettingsProvider).valueOrNull;
  final themeMode = settings?.themeMode ?? ThemeMode.system;

  switch (themeMode) {
    case ThemeMode.light:
      return AppTheme.lightTheme;
    case ThemeMode.dark:
      return AppTheme.darkTheme;
    case ThemeMode.system:
      // 根据系统设置判断
      final brightness = WidgetsBinding.instance.window.platformBrightness;
      return brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme;
  }
});

/// 语言Provider
final localeProvider = Provider<Locale>((ref) {
  final settings = ref.watch(userSettingsProvider).valueOrNull;
  final localeString = settings?.locale ?? 'zh_CN';

  final parts = localeString.split('_');
  return Locale(parts[0], parts.length > 1 ? parts[1] : null);
});
```

## 9. 全局状态管理

### 9.1 应用状态

```dart
// lib/providers/app_provider.dart

/// 应用生命周期Provider
final appLifecycleProvider = StateProvider<AppLifecycleState>((ref) {
  return AppLifecycleState.resumed;
});

/// 网络状态Provider
final connectivityProvider = StreamProvider<ConnectivityResult>((ref) async* {
  yield* Connectivity().onConnectivityChanged;
});

/// 应用初始化Provider
final appInitializationProvider = FutureProvider<bool>((ref) async {
  try {
    // 初始化数据库
    await DatabaseHelper.instance.init();

    // 初始化通知服务
    await ref.read(notificationServiceProvider).initialize();

    // 检查认证状态
    await ref.read(authProvider.notifier)._checkAuthStatus();

    // 生成待处理任务
    final refreshService = ref.read(taskRefreshServiceProvider);
    await refreshService.refreshAllTasks();

    return true;
  } catch (e) {
    return false;
  }
});

/// 全局加载状态Provider
final globalLoadingProvider = StateProvider<bool>((ref) => false);

/// 全局错误Provider
final globalErrorProvider = StateProvider<String?>((ref) => null);
```

### 9.2 导航状态

```dart
// lib/providers/navigation_provider.dart

/// 底部导航索引Provider
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

/// 当前路由Provider
final currentRouteProvider = StateProvider<String>((ref) => '/');

/// 路由历史Provider
final routeHistoryProvider = StateNotifierProvider<RouteHistoryNotifier, List<String>>(
  (ref) => RouteHistoryNotifier(),
);

class RouteHistoryNotifier extends StateNotifier<List<String>> {
  RouteHistoryNotifier() : super(['/']);

  void push(String route) {
    state = [...state, route];
  }

  void pop() {
    if (state.length > 1) {
      state = state.sublist(0, state.length - 1);
    }
  }

  void clear() {
    state = ['/'];
  }
}
```

## 10. Provider使用示例

### 10.1 在Widget中使用

```dart
// 任务列表页面
class TaskListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskListAsync = ref.watch(taskListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('任务列表'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              ref.read(taskListProvider.notifier).refreshTasks();
            },
          ),
        ],
      ),
      body: taskListAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorWidget(error: error.toString()),
        data: (taskListState) {
          if (taskListState.filteredTasks.isEmpty) {
            return EmptyStateWidget(message: '暂无任务');
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(taskListProvider.notifier).refreshTasks();
            },
            child: ListView.builder(
              itemCount: taskListState.filteredTasks.length,
              itemBuilder: (context, index) {
                final task = taskListState.filteredTasks[index];
                return TaskCard(
                  task: task,
                  onComplete: () {
                    ref.read(taskListProvider.notifier).completeTask(task);
                  },
                  onSkip: () {
                    ref.read(taskListProvider.notifier).skipTask(task);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// 计时器页面
class TimerScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final notifier = ref.read(timerProvider.notifier);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 显示任务名称
            if (timerState.currentTask != null)
              Text(
                timerState.currentTask!.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),

            SizedBox(height: 32),

            // 显示倒计时
            Text(
              notifier.formatDuration(timerState.remaining),
              style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 48),

            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (timerState.status == TimerStatus.idle)
                  ElevatedButton.icon(
                    onPressed: () {
                      final selectedTask = ref.read(selectedTaskProvider);
                      if (selectedTask != null) {
                        notifier.startTimer(selectedTask);
                      }
                    },
                    icon: Icon(Icons.play_arrow),
                    label: Text('开始'),
                  ),

                if (timerState.status == TimerStatus.running)
                  ElevatedButton.icon(
                    onPressed: notifier.pauseTimer,
                    icon: Icon(Icons.pause),
                    label: Text('暂停'),
                  ),

                if (timerState.status == TimerStatus.paused)
                  ElevatedButton.icon(
                    onPressed: notifier.resumeTimer,
                    icon: Icon(Icons.play_arrow),
                    label: Text('继续'),
                  ),

                SizedBox(width: 16),

                if (timerState.status != TimerStatus.idle)
                  TextButton.icon(
                    onPressed: notifier.stopTimer,
                    icon: Icon(Icons.stop),
                    label: Text('停止'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### 10.2 Provider依赖关系

```dart
// 使用ref.watch建立依赖
final filteredTasksProvider = Provider<List<Task>>((ref) {
  final taskList = ref.watch(taskListProvider).valueOrNull;
  final filter = ref.watch(taskFilterProvider);

  if (taskList == null) return [];

  return taskList.tasks.where((task) {
    switch (filter) {
      case TaskFilter.active:
        return task.status == TaskStatus.active;
      case TaskFilter.completed:
        return task.status == TaskStatus.completed;
      default:
        return true;
    }
  }).toList();
});

// 使用ref.listen监听变化
class TaskListScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  @override
  void initState() {
    super.initState();

    // 监听任务完成
    ref.listen<AsyncValue<TaskListState>>(
      taskListProvider,
      (previous, next) {
        next.whenData((state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!)),
            );
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Widget构建...
  }
}
```

## 11. 最佳实践

### 11.1 Provider组织原则

1. **按功能模块组织**：每个功能模块有自己的provider文件
2. **避免过度嵌套**：使用组合而非继承
3. **合理使用缓存**：对于不常变化的数据使用缓存
4. **及时清理资源**：使用ref.onDispose清理定时器等资源

### 11.2 性能优化

```dart
// 使用select优化重建
final taskCountProvider = Provider<int>((ref) {
  return ref.watch(taskListProvider.select((state) {
    return state.valueOrNull?.tasks.length ?? 0;
  }));
});

// 使用family避免重复计算
final taskByIdProvider = Provider.family<Task?, String>((ref, id) {
  final tasks = ref.watch(taskListProvider).valueOrNull?.tasks ?? [];
  return tasks.firstWhereOrNull((t) => t.id == id);
});

// 使用autoDispose自动清理
final temporaryDataProvider = StateProvider.autoDispose<String>((ref) {
  return '';
});
```

### 11.3 错误处理

```dart
// 统一错误处理
extension AsyncValueX<T> on AsyncValue<T> {
  void showErrorIfAny(BuildContext context) {
    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// 全局错误边界
class ErrorBoundary extends ConsumerWidget {
  final Widget child;

  const ErrorBoundary({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorWidget.builder = (details) {
      // 记录错误
      ref.read(globalErrorProvider.notifier).state = details.toString();

      return Scaffold(
        body: Center(
          child: Text('发生错误: ${details.exception}'),
        ),
      );
    };

    return child;
  }
}
```

## 12. 测试策略

### 12.1 Provider测试

```dart
void main() {
  test('TaskListNotifier should load tasks on build', () async {
    final container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(MockTaskRepository()),
      ],
    );

    final notifier = container.read(taskListProvider.notifier);

    await expectLater(
      container.read(taskListProvider.future),
      completion(isA<TaskListState>()),
    );
  });

  test('Timer should update remaining time', () {
    final container = ProviderContainer();

    final notifier = container.read(timerProvider.notifier);

    final task = Task(
      id: 'test',
      config: TaskConfiguration(durationMinutes: 25),
      // ... 其他字段
    );

    notifier.startTimer(task);

    expect(
      container.read(timerProvider).status,
      equals(TimerStatus.running),
    );
  });
}
```

### 12.2 Widget测试

```dart
testWidgets('TaskListScreen displays tasks', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskListProvider.overrideWith(() => MockTaskListNotifier()),
      ],
      child: MaterialApp(
        home: TaskListScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();

  expect(find.text('任务1'), findsOneWidget);
  expect(find.text('任务2'), findsOneWidget);
});
```

## 总结

本状态管理设计文档提供了完整的Riverpod状态管理架构，包括：

1. **状态管理架构概述**：技术选型和分层设计
2. **Provider组织结构图**：清晰的层级架构、依赖关系图和类型分布指南
3. **状态更新流程设计**：详细的任务完成流程、异步状态处理和订阅机制
4. **缓存策略设计**：多层级缓存架构、智能预加载和缓存失效策略
5. **Provider详细实现**：全局Provider定义和服务层设计
6. **任务状态管理**：完整的任务列表和计时器状态
7. **目标计划管理**：目标和计划的CRUD操作
8. **用户认证与设置**：登录、注册、登出流程和用户设置管理
9. **全局状态管理**：应用级别的状态管理和导航状态
10. **Provider使用示例**：实际的Widget集成代码和依赖关系示例
11. **最佳实践**：组织原则、性能优化和错误处理
12. **测试策略**：Provider测试和Widget测试

### 架构亮点

- **可视化设计**：通过结构图和流程图清晰展示Provider组织和状态流转
- **性能优化**：完善的缓存策略和预加载机制
- **错误处理**：统一的错误边界和异常处理
- **可测试性**：清晰的依赖注入和测试策略
- **可维护性**：模块化设计和明确的职责划分

这个状态管理架构确保了应用状态的一致性、可预测性和可测试性，为Flutter应用提供了坚实的状态管理基础。