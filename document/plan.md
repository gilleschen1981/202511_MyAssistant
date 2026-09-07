# 昨日补签功能 - Execution Plan

## 概述

实现"昨日补签"功能，允许用户对昨天被跳过的任务进行补签完成操作。补签模式下显示独立的任务列表，操作不影响当前任务窗口。

### 设计决策（已确认）

| 决策项 | 结论 |
|--------|------|
| 补签范围 | 按 `skipped_at` 时间戳在昨天范围内 |
| completed_at | 设为 `task.windowEndTime`（归入昨天统计） |
| Timer任务 | 直接完成，跳过计时 |
| Undo支持 | 不支持 |

---

## Phase 1: Data Layer

### Step 1.1: TaskDao - 添加查询方法

**文件**: `lib/data/data_sources/local/dao/task_dao.dart`

添加 `getYesterdaySkippedTasks(String userId)` 方法：
- 查询条件: `status = 'skipped' AND skipped_at BETWEEN yesterdayStart AND yesterdayEnd`
- 返回 `List<TaskModel>`，按 `window_start_time ASC` 排序

添加 `makeUpCompleteTask()` 方法：
- 更新字段: `status='completed'`, `completed_at=window_end_time`, `skipped_at=NULL`, `execution_note=?`
- 如果是counter任务，设置 `current_count = repeatCount`

### Step 1.2: ITaskRepository - 添加接口方法

**文件**: `lib/domain/repositories/i_task_repository.dart`

添加两个方法签名：
```dart
Future<List<TaskModel>> getYesterdaySkippedTasks(String userId);
Future<TaskModel> makeUpCompleteTask({
  required String taskId,
  String? evaluationResult,
  String? executionNote,
});
```

### Step 1.3: TaskRepository - 实现接口

**文件**: `lib/data/repositories/task_repository.dart`

实现上述两个方法，委托给 TaskDao。`makeUpCompleteTask` 需要：
1. 验证任务状态为 skipped
2. 验证评价任务有 evaluationResult
3. 调用 DAO 执行更新

### Step 1.4: TaskExecutionService - 添加补签方法

**文件**: `lib/data/services/task_execution_service.dart`

添加两个方法：

```dart
/// 补签完成任务（skipped → completed）
Future<TaskModel> makeUpCompleteTask({
  required TaskModel task,
  String? evaluationResult,
  String? executionNote,
}) async {
  // 1. 验证 task.status == skipped
  // 2. 验证 evaluation 任务有 evaluationResult
  // 3. 调用 _taskRepository.makeUpCompleteTask()
  // 4. 返回更新后的任务
}

/// 补签递增计数（Counter任务）
Future<TaskModel> makeUpIncrementCount(TaskModel task, {
  String? evaluationResult,
}) async {
  // 1. 验证是 counter 任务
  // 2. 验证 task.status == skipped
  // 3. 先将任务恢复为 active（临时，以便 updateTaskProgress 工作）
  //    或直接在 DAO 层处理 count 更新
  // 4. 递增 currentCount
  // 5. 如果达到 repeatCount，调用 makeUpCompleteTask
  // 6. 返回更新后的任务
}
```

注意: Counter任务的补签递增需要特殊处理。因为现有的 `incrementCount()` 要求 `status == active`，补签模式下任务是 skipped 状态。最简单的方案是在 DAO 层直接更新 `current_count`，不经过现有的 `incrementCount` 验证。当达到目标时调用 `makeUpCompleteTask`。

---

## Phase 2: State Management

### Step 2.1: TaskListState - 扩展状态

**文件**: `lib/presentation/providers/task_list_notifier.dart`

在 `TaskListState` 的 freezed class 中添加：
```dart
@Default(false) bool isMakeUpMode,
@Default([]) List<TaskModel> makeUpTasks,
```

运行 `flutter pub run build_runner build --delete-conflicting-outputs` 重新生成 freezed 文件。

### Step 2.2: TaskListNotifier - 添加补签方法

**文件**: `lib/presentation/providers/task_list_notifier.dart`

添加四个方法：

```dart
/// 进入补签模式
Future<void> enterMakeUpMode() async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;
  final skippedTasks = await _taskRepository.getYesterdaySkippedTasks(user.id);
  state = AsyncValue.data(state.value!.copyWith(
    isMakeUpMode: true,
    makeUpTasks: skippedTasks,
  ));
}

/// 退出补签模式
void exitMakeUpMode() {
  state = AsyncValue.data(state.value!.copyWith(
    isMakeUpMode: false,
    makeUpTasks: [],
  ));
}

/// 补签完成任务
Future<void> makeUpCompleteTask({
  required TaskModel task,
  String? evaluationResult,
  String? executionNote,
}) async {
  final completedTask = await _executionService.makeUpCompleteTask(
    task: task,
    evaluationResult: evaluationResult,
    executionNote: executionNote,
  );
  // 从 makeUpTasks 中移除已完成的任务
  state = AsyncValue.data(state.value!.copyWith(
    makeUpTasks: state.value!.makeUpTasks
        .where((t) => t.id != task.id)
        .toList(),
  ));
  // 注意：不 reload allTasks/todayTasks，保持正常列表不变
}

/// 补签递增计数
Future<TaskModel> makeUpIncrementCount(TaskModel task, {
  String? evaluationResult,
}) async {
  final updatedTask = await _executionService.makeUpIncrementCount(
    task, evaluationResult: evaluationResult);
  // 更新 makeUpTasks 中的任务
  if (updatedTask.status == TaskStatus.completed) {
    // 已完成，从列表移除
    state = AsyncValue.data(state.value!.copyWith(
      makeUpTasks: state.value!.makeUpTasks
          .where((t) => t.id != task.id).toList(),
    ));
  } else {
    // 更新计数
    state = AsyncValue.data(state.value!.copyWith(
      makeUpTasks: state.value!.makeUpTasks
          .map((t) => t.id == updatedTask.id ? updatedTask : t).toList(),
    ));
  }
  return updatedTask;
}
```

### Step 2.3: 添加 computed providers

同文件，添加：
```dart
@riverpod
bool isMakeUpMode(Ref ref) { ... }

@riverpod
List<TaskModel> makeUpTasks(Ref ref) { ... }
```

---

## Phase 3: UI Layer

### Step 3.1: HomeScreen - 添加补签按钮和模式切换

**文件**: `lib/presentation/features/home/screens/home_screen.dart`

修改 AppBar：
1. 正常模式（`_currentIndex == 0 && !isMakeUpMode`）：在已有的筛选按钮旁边添加补签按钮（图标：`Icons.edit_calendar` 或 `Icons.history`）
2. 补签模式：
   - title 变为 `'昨日补签'`
   - 移除筛选按钮
   - 添加退出按钮（`Icons.close`）
3. 补签模式下禁用底部导航切换（或添加提示）

HomeScreen 需要变为 ConsumerStatefulWidget（已经是），watch `taskListNotifierProvider` 获取 `isMakeUpMode` 状态。

### Step 3.2: TasksScreen - 支持补签模式显示

**文件**: `lib/presentation/features/tasks/screens/tasks_screen.dart`

修改 `build()` 方法：
1. 检查 `isMakeUpMode`
2. 如果是补签模式：
   - 使用 `makeUpTasks` 而不是 `filteredTasks`
   - 不显示 FilterBar 和 Undo 按钮
   - 单组显示（"昨日跳过的任务"），默认展开
   - 所有任务以 Active 样式渲染（需要传递给 CompactTaskCard）
3. 补签模式下的 `_showQuickMenu` 调用补签版菜单

### Step 3.3: CompactTaskCard - 支持补签样式覆盖

**文件**: `lib/presentation/features/tasks/widgets/compact_task_card.dart`

添加可选参数 `bool forceActiveStyle = false`：
- 当 `forceActiveStyle == true` 时，无论任务实际状态，都以 Active 样式渲染（白色背景 + 蓝色左边框，无删除线）

### Step 3.4: TaskQuickMenu - 补签版菜单

**文件**: `lib/presentation/features/tasks/widgets/task_quick_menu.dart`

有两种方案：
- **方案A**: 在现有 `TaskQuickMenu.show()` 中添加 `bool isMakeUpMode` 参数，内部根据模式调整行为
- **方案B**: 创建新的 `MakeUpTaskQuickMenu` 类

**推荐方案A**，修改点：
1. Timer 任务：显示"完成"按钮而非"计时"按钮
2. 完成操作：调用 `makeUpCompleteTask` 而非 `completeTask`
3. Counter 操作：调用 `makeUpIncrementCount` 而非 `incrementCount`
4. 跳过按钮：补签模式下不显示（任务已经是 skipped 状态）
5. 再次执行按钮：补签模式下不显示

---

## Phase 4: Integration Tests

### Step 4.1: 补签功能集成测试

**文件**: `test/integration/scenarios/task_makeup_checkin_scenario.dart`

测试场景：

#### 4.1.1 补签基本流程
1. 创建一个 daily plan
2. 生成昨天的任务并 skip 它
3. 进入补签模式
4. 验证看到昨天 skip 的任务
5. 补签完成任务
6. 验证任务状态变为 completed
7. 验证 completed_at 等于 windowEndTime

#### 4.1.2 补签不影响当前任务窗口（关键测试）
1. 创建一个 daily plan
2. 生成昨天的任务并 skip
3. 生成今天的任务（active 状态）
4. 记录当前任务窗口内容快照
5. 进入补签模式
6. 补签完成昨天的任务
7. 退出补签模式
8. **验证当前任务窗口的内容与步骤4的快照完全一致**
9. 验证今天的 active 任务不受影响

#### 4.1.3 Timer 任务补签
1. 创建带 Timer 配置的 plan
2. 生成昨天的任务并 skip
3. 进入补签模式
4. 验证 Timer 任务可直接完成（无需计时）
5. 验证 completed_at 为 windowEndTime

#### 4.1.4 Counter 任务补签
1. 创建带 Counter 配置的 plan（repeatCount=3）
2. 生成昨天的任务并 skip
3. 进入补签模式
4. 递增计数 3 次
5. 验证任务自动完成
6. 验证 completed_at 为 windowEndTime

#### 4.1.5 Evaluation 任务补签
1. 创建带 Evaluation 配置的 plan
2. 生成昨天的任务并 skip
3. 进入补签模式
4. 选择评价选项后完成
5. 验证 evaluationResult 已保存
6. 验证 completed_at 为 windowEndTime

#### 4.1.6 无昨日跳过任务
1. 进入补签模式
2. 验证 makeUpTasks 为空

#### 4.1.7 仅查询昨日（不包括前天或今天的 skip）
1. 创建 tasks，skip_at 分别在前天、昨天、今天
2. 进入补签模式
3. 验证只显示 skipped_at 在昨天范围的任务

---

## Phase 5: Unit Tests

### Step 5.1: DAO 单元测试

**文件**: `test/data/data_sources/local/dao/task_dao_test.dart`（如果存在则修改，否则新建）

测试 `getYesterdaySkippedTasks` 和 `makeUpCompleteTask`。

### Step 5.2: TaskExecutionService 单元测试

**文件**: `test/data/services/task_execution_service_test.dart`

添加补签相关测试用例：
- 补签完成 simple 任务
- 补签完成 timer 任务（直接完成）
- 补签递增 counter 任务
- 补签完成 evaluation 任务
- 补签非 skipped 任务应抛异常
- 补签 evaluation 任务缺少 evaluationResult 应抛异常

### Step 5.3: TaskListNotifier 单元测试

**文件**: `test/presentation/providers/task_list_notifier_test.dart`

添加补签模式相关测试：
- enterMakeUpMode 正确加载昨日跳过的任务
- exitMakeUpMode 清空补签状态
- makeUpCompleteTask 从 makeUpTasks 移除已完成任务
- makeUpCompleteTask 不影响 allTasks/todayTasks
- makeUpIncrementCount 更新 makeUpTasks 中的计数

---

## Phase 6: Code Generation & Verification

### Step 6.1: 运行 build_runner
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```
重新生成 `task_list_notifier.freezed.dart` 和 `task_list_notifier.g.dart`。

### Step 6.2: 运行全部测试
```bash
flutter test
```
确保所有现有测试通过 + 新增测试通过。

### Step 6.3: 运行静态分析
```bash
flutter analyze
```

---

## 执行顺序

```
Phase 1 (Data Layer)
  └── Step 1.1 → 1.2 → 1.3 → 1.4  （顺序依赖）

Phase 2 (State Management)
  └── Step 2.1 → build_runner → 2.2 → 2.3

Phase 3 (UI Layer)            ← 依赖 Phase 2
  └── Step 3.1, 3.2, 3.3, 3.4（可并行）

Phase 4 (Integration Tests)   ← 依赖 Phase 1-3
  └── Step 4.1

Phase 5 (Unit Tests)          ← 可与 Phase 3 并行
  └── Step 5.1, 5.2, 5.3（可并行）

Phase 6 (Verification)        ← 最后执行
  └── Step 6.1 → 6.2 → 6.3
```

## 影响范围

### 修改的文件
| 文件 | 修改类型 |
|------|----------|
| `lib/data/data_sources/local/dao/task_dao.dart` | 添加 2 个方法 |
| `lib/domain/repositories/i_task_repository.dart` | 添加 2 个接口方法 |
| `lib/data/repositories/task_repository.dart` | 实现 2 个方法 |
| `lib/data/services/task_execution_service.dart` | 添加 2 个方法 |
| `lib/presentation/providers/task_list_notifier.dart` | 扩展 state + 添加 4 个方法 + 2 个 provider |
| `lib/presentation/features/home/screens/home_screen.dart` | AppBar 补签按钮 + 模式切换 |
| `lib/presentation/features/tasks/screens/tasks_screen.dart` | 补签模式显示逻辑 |
| `lib/presentation/features/tasks/widgets/compact_task_card.dart` | 添加 forceActiveStyle 参数 |
| `lib/presentation/features/tasks/widgets/task_quick_menu.dart` | 添加 isMakeUpMode 参数 |

### 新增的文件
| 文件 | 说明 |
|------|------|
| `test/integration/scenarios/task_makeup_checkin_scenario.dart` | 补签集成测试 |

### 不变的文件
- 数据库 schema（不需要 migration，利用现有 skipped_at 字段）
- 路由配置（补签模式不是新页面，是同一页面的状态切换）
- 任务生成逻辑（补签不触发任务生成）
