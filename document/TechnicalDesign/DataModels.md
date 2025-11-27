# 数据模型定义

本文档定义了任务管理系统中所有核心实体的数据结构、关系和业务规则。

## 1. 核心实体

### 1.1 Goal（目标）实体

目标是系统中的顶层概念，代表用户想要达成的长期目标。

```dart
class Goal {
  // 基础字段
  String id;                    // 唯一标识符（UUID）
  String userId;                // 所属用户ID
  String title;                 // 目标标题（必填）
  String? description;          // 目标描述（选填）

  // 分类和标签
  List<String> tags;            // 标签列表（个人/工作/学习/健康等）

  // 时间相关
  DateTime? deadline;           // 截止日期（选填）
  DateTime createdAt;           // 创建时间
  DateTime updatedAt;           // 更新时间

  // 优先级和状态
  Priority priority;            // 优先级（高/中/低）
  GoalStatus status;            // 状态（进行中/暂停/已完成）

  // 成功标准
  String? successCriteria;      // 成功标准/KPI（选填）

  // 关联关系
  List<String> planIds;         // 关联的计划ID列表

  // 软删除支持（通过 status 字段）
  // 注意：Goal 使用 status='deleted' 进行软删除，而不是单独的 is_deleted 字段
  // 因为 GoalStatus 枚举已包含 deleted 状态
  DateTime? deletedAt;          // 删除时间（用于审计跟踪）

  // 计算属性
  int get planCount => planIds.length;
  bool get isDeleted => status == GoalStatus.deleted;  // 从 status 计算得出
  double get overallProgress;   // 所有计划的平均完成率
  int get daysRemaining;        // 剩余天数
}

enum Priority {
  high,    // 高优先级
  medium,  // 中优先级
  low      // 低优先级
}

enum GoalStatus {
  active,      // 活跃
  paused,      // 暂停
  completed,   // 已完成
  deleted      // 已删除（软删除状态）
}
```

### 1.2 Plan（计划）实体

计划是目标的具体执行方案，包含时间规则和任务配置。

**重要说明**: 计划使用 `status='deleted'` 进行软删除，与 Goal 和 Task 保持一致。

```dart
class Plan {
  // 基础字段
  String id;                    // 唯一标识符（UUID）
  String userId;                // 所属用户ID
  String name;                  // 计划名称（必填，用户范围内唯一，创建后不可修改）
  String? description;          // 计划描述（选填）

  // 关联关系
  String goalId;                // 所属目标ID（必填，计划必须属于某个目标）

  // 时间设置
  DateTime startDate;           // 开始日期（必填）
  DateTime endDate;             // 结束日期（必填）
  RepeatRule repeatRule;        // 重复规则

  // 任务配置
  TaskConfiguration taskConfig; // 任务配置（计时/计数/评价等）

  // 状态
  PlanStatus status;            // 状态（active/paused/completed/deleted）

  // 时间戳
  DateTime createdAt;           // 创建时间
  DateTime updatedAt;           // 更新时间
  DateTime? deletedAt;          // 删除时间（用于审计跟踪）

  // 计算属性
  double get completionRate;    // 完成率
  int get totalTaskCount;       // 总任务数
  int get completedTaskCount;   // 已完成任务数
  int get skippedTaskCount;     // 已跳过任务数
  bool get isDeleted => status == PlanStatus.deleted;  // 从 status 计算得出
  bool get isActive => status != PlanStatus.deleted && status == PlanStatus.active;  // 是否处于活动期
}

enum PlanStatus {
  active,      // 活跃
  paused,      // 暂停
  completed,   // 已完成
  deleted      // 已删除（软删除状态）
}
```

### 1.3 RepeatRule（重复规则）

定义计划的重复模式。

```dart
class RepeatRule {
  RepeatType type;              // 重复类型
  int? customDays;              // 自定义天数（仅当type为custom时使用）

  RepeatRule({
    required this.type,
    this.customDays,
  });

  // 验证规则
  bool get isValid {
    if (type == RepeatType.custom) {
      return customDays != null && customDays! > 0;
    }
    return true;
  }
}

enum RepeatType {
  oneTime,  // 一次性
  daily,    // 每日
  weekly,   // 每周
  monthly,  // 每月
  custom    // 自定义（每N天）
}
```

### 1.4 TaskConfiguration（任务配置）

定义任务的执行方式和参数。

```dart
class TaskConfiguration {
  // 可选配置项（根据任务类型选择）
  int? durationMinutes;         // 计时任务：持续时间（分钟）
  int? repeatCount;             // 计量任务：重复次数
  List<String>? evaluationOptions; // 评价任务：评价选项

  TaskConfiguration({
    this.durationMinutes,
    this.repeatCount,
    this.evaluationOptions,
  });

  /// 任务配置组合规则：
  /// 允许的组合：
  /// 1. 纯计时（durationMinutes）
  /// 2. 纯计数（repeatCount）
  /// 3. 纯评价（evaluationOptions）
  /// 4. 计时+计数（durationMinutes + repeatCount）
  /// 5. 计数+评价（repeatCount + evaluationOptions）
  /// 6. 简单任务（无任何配置）
  ///
  /// 不允许的组合：
  /// - 计时+评价（durationMinutes + evaluationOptions）- 互斥
  /// - 计时+计数+评价（全部配置）- 过于复杂

  // 获取任务类型
  TaskType get taskType {
    // 业务规则：计时和评价互斥
    if (durationMinutes != null && evaluationOptions != null) {
      throw BusinessRuleException("计时和评价不能同时存在");
    }

    // 判断任务类型
    if (durationMinutes != null && repeatCount != null) {
      return TaskType.timerWithCount;  // 计时+计数
    }
    if (durationMinutes != null) {
      return TaskType.timer;            // 纯计时
    }
    if (repeatCount != null && evaluationOptions != null && evaluationOptions!.isNotEmpty) {
      return TaskType.counterWithEval;  // 计数+评价
    }
    if (repeatCount != null) {
      return TaskType.counter;          // 纯计数
    }
    if (evaluationOptions != null && evaluationOptions!.isNotEmpty) {
      return TaskType.evaluation;       // 评价任务
    }
    return TaskType.simple;             // 简单任务
  }

  // 验证配置
  bool get isValid {
    // 计时和评价不能共存
    if (durationMinutes != null && evaluationOptions != null) {
      return false;
    }
    // 计时时长必须大于0
    if (durationMinutes != null && durationMinutes! <= 0) {
      return false;
    }
    // 重复次数必须大于0
    if (repeatCount != null && repeatCount! <= 0) {
      return false;
    }
    // 评价选项至少2个
    if (evaluationOptions != null && evaluationOptions!.length < 2) {
      return false;
    }
    return true;
  }
}

enum TaskType {
  timer,           // 计时任务
  counter,         // 计数任务
  evaluation,      // 评价任务
  timerWithCount,  // 计时+计数任务
  counterWithEval, // 计数+评价任务
  simple           // 简单任务
}
```

### 1.5 Task（任务）实体

任务是系统自动生成的执行单元，用户实际执行的对象。

**重要设计变更** (v4.0):
- ❌ **移除字段**: `repeatExecutionCount`, `originalTaskId`
- ❌ **移除属性**: `isRepeatExecution`, `canRepeat`
- ✅ **设计理念**: 每个任务都是独立实体,没有"重复执行"概念
- ✅ **再次执行**: 通过创建新的独立任务实现,而非在原任务上追加记录
- ✅ **软删除**: 使用 `status='deleted'` 进行软删除，与 Goal 和 Plan 保持一致

```dart
class Task {
  // 基础字段
  String id;                    // 唯一标识符（UUID）
  String userId;                // 所属用户ID
  String planId;                // 来源计划ID（必填）

  // 任务信息（从计划继承）
  String name;                  // 任务名称
  String? description;          // 任务描述
  TaskConfiguration config;     // 任务配置

  // 执行窗口
  DateTime windowStartTime;     // 执行窗口开始时间
  DateTime windowEndTime;       // 执行窗口结束时间（截止时间）

  // 状态和执行数据
  TaskStatus status;            // 状态（active/completed/skipped/deleted）
  int currentCount;             // 当前完成次数（用于counter任务）

  // 完成信息
  DateTime? completedAt;        // 完成时间
  DateTime? skippedAt;          // 跳过时间
  int? actualDurationMinutes;   // 实际执行时长（timer任务）
  String? evaluationResult;     // 评价结果（evaluation任务）
  String? executionNote;        // 执行备注

  // 时间戳
  DateTime createdAt;           // 创建时间（任务生成时间）
  DateTime? deletedAt;          // 删除时间（用于审计跟踪）

  // 计算属性
  bool get isDeleted => status == TaskStatus.deleted;  // 从 status 计算得出
  bool get isExpired => DateTime.now().isAfter(windowEndTime);
  bool get canExecute => status == TaskStatus.active && !isExpired;
  bool get isInCurrentWindow {
    final now = DateTime.now();
    return now.isAfter(windowStartTime) && now.isBefore(windowEndTime);
  }
  double get progress {
    if (config.repeatCount == null) return 0;
    return (currentCount / config.repeatCount!).clamp(0.0, 1.0);
  }
}

enum TaskStatus {
  active,     // 待执行
  completed,  // 已完成
  skipped,    // 已跳过
  deleted     // 已删除（软删除状态）
}

enum TaskFilter {
  all('全部'),        // 所有任务
  active('待执行'),   // 待执行任务
  completed('已完成'), // 已完成任务
  skipped('已跳过');  // 已跳过任务

  const TaskFilter(this.label);
  final String label;  // 显示标签
}
```

### 1.6 User（用户）实体

系统用户信息。

```dart
class User {
  // 基础字段
  String id;                    // 唯一标识符（UUID）
  String username;              // 用户名（唯一）
  String email;                 // 邮箱地址（唯一）
  String passwordHash;          // 密码哈希

  // 个人信息
  String? displayName;          // 显示名称
  String? avatarUrl;            // 头像URL

  // 状态和时间戳
  UserStatus status;            // 状态（激活/停用）
  DateTime createdAt;           // 注册时间
  DateTime updatedAt;           // 更新时间

  // 统计信息（计算属性）
  int get totalGoals;           // 目标总数
  int get completedGoals;       // 已完成目标数
  int get activePlans;          // 活跃计划数
  int get completedTasks;       // 已完成任务数
}

enum UserStatus {
  active,      // 激活
  deactivated  // 停用
}
```

### 1.7 UserSettings（用户设置）实体

用户个性化设置。

```dart
class UserSettings {
  // 关联用户
  String userId;                // 用户ID（主键）

  // 显示设置
  ThemeMode themeMode;          // 主题模式
  String locale;                // 语言设置（zh_CN/en_US）
  double fontScale;             // 字体缩放（0.8-1.3）

  // 通知设置
  bool enableNotifications;     // 启用通知
  bool enableSound;             // 启用声音
  bool enableVibration;         // 启用震动

  // 数据同步设置
  bool autoSync;                // 自动同步
  DateTime? lastSyncTime;       // 最后同步时间

  // 任务设置
  bool autoRefreshTasks;        // 自动刷新任务
  int defaultTimerMinutes;      // 默认计时时长

  UserSettings({
    required this.userId,
    this.themeMode = ThemeMode.system,
    this.locale = 'zh_CN',
    this.fontScale = 1.0,
    this.enableNotifications = true,
    this.enableSound = true,
    this.enableVibration = true,
    this.autoSync = true,
    this.autoRefreshTasks = true,
    this.defaultTimerMinutes = 25,
  });
}

enum ThemeMode {
  light,   // 浅色主题
  dark,    // 深色主题
  system   // 跟随系统
}
```

## 2. 实体关系

### 2.1 关系图

```
User (1) ────┬──→ (N) Goal
             │
             ├──→ (N) Plan
             │         │
             │         └──→ (N) Task
             │
             └──→ (1) UserSettings

Goal (1) ────→ (N) Plan [组合关系]
Plan (1) ────→ (N) Task [组合关系]
```

### 2.2 关系规则

1. **用户与数据的关系**
   - 一个用户可以有多个目标
   - 一个用户可以有多个计划
   - 每个用户有唯一的设置

2. **目标与计划的关系**
   - 一个目标可以包含多个计划
   - 计划必须属于某个目标（组合关系）
   - 软删除目标时，相关计划也会被级联软删除（设置status='deleted'和deleted_at）

3. **计划与任务的关系**
   - 一个计划可以生成多个任务
   - 任务必须来源于某个计划（组合关系）
   - 软删除计划时，相关任务也会被级联软删除（设置status='deleted'和deleted_at）
   - 每个计划同一时间只能有一个活跃任务

4. **任务生成规则**
   - 任务由系统自动生成，不允许手动创建
   - 根据计划的重复规则生成下一个任务
   - 任务窗口结束后自动生成新任务

## 2. 状态定义与流转规则

本系统使用统一的状态管理机制，所有实体（Goal、Plan、Task）都采用 `status` 字段 + `deleted` 状态实现软删除。

### 2.1 GoalStatus（目标状态）

目标的完整生命周期状态定义：

```dart
enum GoalStatus {
  active,      // 活跃   - 目标正在被执行
  paused,      // 暂停   - 目标暂时停止，可以恢复
  completed,   // 已完成 - 目标达成
  deleted      // 已删除 - 软删除状态
}
```

#### 状态说明

| 状态 | 含义 | 可编辑 | 关联计划 | UI显示 |
|------|------|--------|----------|--------|
| **active** | 目标活跃，用户正在执行相关计划 | ✅ 是 | 可新增/修改 | 正常显示 |
| **paused** | 目标暂停，不生成新任务，保留现有数据 | ✅ 是 | 暂停状态 | 置灰显示 |
| **completed** | 目标已完成，所有计划结束 | ❌ 否 | 只读 | 标记完成 |
| **deleted** | 目标已删除（软删除），不显示在列表中 | ❌ 否 | 级联删除 | 不显示 |

#### 状态流转规则

```
创建 → active ⟷ paused
           ↓
      completed
           ↓
        deleted
```

- **active ⟷ paused**: 可自由切换，暂停不影响数据
- **active/paused → completed**: 手动标记完成或所有计划完成
- **任意状态 → deleted**: 软删除操作，不可恢复

#### 业务规则

1. **编辑限制**：completed 状态的目标不可修改（只读）
2. **删除机制**：删除目标会级联软删除所有关联的计划和任务
3. **暂停影响**：暂停目标会暂停所有关联计划，停止生成新任务
4. **默认状态**：新创建的目标默认为 `active`

---

### 2.2 PlanStatus（计划状态）

计划的完整生命周期状态定义：

```dart
enum PlanStatus {
  active,      // 活跃   - 正在生成任务
  paused,      // 暂停   - 停止生成新任务
  completed,   // 已完成 - 计划周期结束
  deleted      // 已删除 - 软删除状态
}
```

#### 状态说明

| 状态 | 含义 | 生成任务 | 可编辑 | UI显示 |
|------|------|----------|--------|--------|
| **active** | 计划活跃，按重复规则自动生成任务 | ✅ 是 | ✅ 是 | 正常显示 |
| **paused** | 计划暂停，停止生成新任务，现有任务保留 | ❌ 否 | ✅ 是 | 置灰显示 |
| **completed** | 计划已完成，达到结束日期或手动完成 | ❌ 否 | ❌ 否 | 标记完成 |
| **deleted** | 计划已删除（软删除），不显示在列表中 | ❌ 否 | ❌ 否 | 不显示 |

#### 状态流转规则

```
创建 → active ⟷ paused
           ↓
       completed
           ↓
        deleted
```

- **active ⟷ paused**: 可自由切换，用于临时停止计划
- **active/paused → completed**: 到达 endDate 或手动标记完成
- **任意状态 → deleted**: 软删除操作，级联删除所有任务

#### 业务规则

1. **任务生成**：只有 `active` 状态的计划才会生成新任务
2. **暂停保留**：暂停计划不删除已生成的任务，只是停止生成新任务
3. **完成条件**：达到 endDate 或手动标记完成
4. **删除影响**：删除计划会软删除所有关联任务（设置 status='deleted'）
5. **默认状态**：新创建的计划默认为 `active`
6. **父状态影响**：如果所属目标为 paused，则计划自动暂停

---

### 2.3 TaskStatus（任务状态）

任务的完整生命周期状态定义：

```dart
enum TaskStatus {
  active,     // 待执行 - 任务在执行窗口内，等待用户执行
  completed,  // 已完成 - 任务已完成
  skipped,    // 已跳过 - 任务被用户跳过或窗口过期
  deleted     // 已删除 - 软删除状态
}
```

#### 状态说明

| 状态 | 含义 | 可执行 | 可编辑 | 触发条件 |
|------|------|--------|--------|----------|
| **active** | 任务待执行，在时间窗口内 | ✅ 是 | ❌ 否 | 系统生成 |
| **completed** | 任务已完成，记录执行数据 | ❌ 否 | ❌ 否 | 用户完成 |
| **skipped** | 任务已跳过，不会执行 | ❌ 否 | ❌ 否 | 手动跳过/自动过期 |
| **deleted** | 任务已删除（软删除） | ❌ 否 | ❌ 否 | 计划删除时级联 |

#### 状态流转规则

```
系统生成 → active → completed
                 ↘ skipped
                      ↓
                   deleted
```

**重要特性**：
- ✅ **单向流转**：active → completed/skipped，**不可逆**
- ❌ **不可重置**：已完成/已跳过的任务不能恢复为 active
- ✅ **可重复执行**：通过生成新任务实现，而非修改状态

#### 业务规则

1. **不可编辑**：任务创建后除 status 外，其他字段不可修改
2. **单向流转**：active → completed/skipped，流转后不可逆
3. **自动过期**：
   - 当 `DateTime.now() > windowEndTime` 且 status 仍为 active
   - 系统自动将状态更新为 `skipped`
   - 在刷新任务列表时触发（打开页面/定时刷新）
4. **重复执行机制**：
   - 已完成的任务可"再次执行"
   - 实现方式：创建一个**新的独立任务**（新ID），复制配置
   - 而非在原任务上记录多次执行
5. **软删除触发**：
   - 当所属计划被删除时，所有任务自动软删除
   - 设置 `status='deleted'` 和 `deleted_at` 时间戳
6. **默认状态**：系统生成的任务默认为 `active`

#### 特殊计算属性

```dart
class Task {
  // 是否已删除
  bool get isDeleted => status == TaskStatus.deleted;

  // 是否已过期（超出执行窗口）
  bool get isExpired => DateTime.now().isAfter(windowEndTime);

  // 是否可执行（未过期且为active状态）
  bool get canExecute => status == TaskStatus.active && !isExpired;
}
```

---

### 2.4 软删除机制统一说明

本系统所有核心实体（Goal、Plan、Task）都采用**软删除**机制，确保数据可追溯和可恢复。

#### 实现方式

1. **状态标记**：使用 `status='deleted'` 标记删除状态
2. **时间戳记录**：`deleted_at` 字段记录删除时间（用于审计）
3. **级联软删除**：
   - 删除目标 → 软删除所有计划和任务
   - 删除计划 → 软删除所有任务
   - 使用触发器或应用层代码实现

#### 查询过滤

所有查询默认过滤已删除数据：

```sql
-- 示例：查询活跃计划
SELECT * FROM plans
WHERE user_id = ?
  AND status != 'deleted'  -- 过滤已删除
ORDER BY created_at DESC;

-- 索引优化
CREATE INDEX idx_plans_active
ON plans(user_id, status)
WHERE status != 'deleted';
```

#### 优势

1. **数据安全**：防止误删除，可恢复
2. **审计跟踪**：保留删除时间和历史记录
3. **统计完整**：历史统计包含已删除数据
4. **性能优化**：通过索引过滤，不影响查询性能

---

### 2.5 状态管理最佳实践

#### 1. 检查状态前置条件

```dart
// ❌ 错误：直接修改状态
task.status = TaskStatus.completed;

// ✅ 正确：检查状态和条件
Future<void> completeTask(Task task) async {
  // 检查状态
  if (task.status != TaskStatus.active) {
    throw BusinessException('只有待执行的任务才能完成');
  }

  // 检查时间窗口
  if (task.isExpired) {
    throw BusinessException('任务已过期');
  }

  // 更新状态
  await taskRepository.updateTask(
    task.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime.now(),
    ),
  );
}
```

#### 2. 级联状态更新

```dart
// 删除目标时级联更新
Future<void> deleteGoal(String goalId) async {
  // 1. 软删除所有计划
  await planRepository.softDeleteByGoalId(goalId);

  // 2. 软删除所有任务
  await taskRepository.softDeleteByGoalId(goalId);

  // 3. 软删除目标
  await goalRepository.softDelete(goalId);
}
```

#### 3. 查询已删除数据

```dart
// 正常查询：过滤已删除
Future<List<Goal>> getActiveGoals(String userId) async {
  return await goalRepository.query(
    where: 'user_id = ? AND status != ?',
    whereArgs: [userId, 'deleted'],
  );
}

// 管理查询：包含已删除（用于审计）
Future<List<Goal>> getAllGoalsIncludingDeleted(String userId) async {
  return await goalRepository.query(
    where: 'user_id = ?',
    whereArgs: [userId],
  );
}
```

## 3. 业务规则约束

### 3.1 目标相关规则
- 目标标题不能为空
- 目标优先级默认为中等
- 已完成的目标不能修改

### 3.2 计划相关规则
- 计划使用UUID作为主键ID（自动生成）
- 计划名称（name）创建后不可修改（immutable），在用户范围内必须唯一
- 计划必须关联到某个目标（goalId不可修改）
- 结束日期必须大于或等于开始日期
- 自定义重复天数必须大于0
- 开始日期（startDate）创建后不建议修改（可能影响已生成的任务）

### 3.3 任务相关规则
- 任务只能由系统自动生成
- 任务创建后不可编辑（只能改变状态）
- 状态流转：Active → Completed/Skipped（不可逆）
- 执行窗口过期后自动标记为跳过
- 已完成的任务在窗口期内可以再次执行（生成新任务）

### 3.4 任务配置规则
- 计时和评价不能同时存在
- 计时可以与计数组合
- 评价选项至少需要2个
- 简单任务不需要任何配置

## 4. 数据验证

### 4.1 字段验证规则

```dart
class ValidationRules {
  // 目标验证
  static bool validateGoal(Goal goal) {
    if (goal.title.isEmpty) return false;
    if (goal.deadline != null && goal.deadline!.isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  // 计划验证
  static bool validatePlan(Plan plan) {
    if (plan.name.isEmpty) return false;
    if (plan.endDate.isBefore(plan.startDate)) return false;
    if (plan.repeatRule.type == RepeatType.custom &&
        (plan.repeatRule.customDays == null || plan.repeatRule.customDays! <= 0)) {
      return false;
    }
    return plan.taskConfig.isValid;
  }

  // 任务验证
  static bool validateTask(Task task) {
    if (task.windowEndTime.isBefore(task.windowStartTime)) return false;
    if (task.currentCount < 0) return false;
    return true;
  }
}
```

## 5. 数据模型使用示例

### 5.1 创建目标

```dart
final goal = Goal(
  id: generateUuid(),
  userId: currentUserId,
  title: "学习Flutter开发",
  description: "掌握Flutter框架，能够独立开发跨平台应用",
  tags: ["学习", "技术"],
  deadline: DateTime(2024, 12, 31),
  priority: Priority.high,
  status: GoalStatus.active,
  successCriteria: "完成一个完整的Flutter应用",
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  planIds: [],
  isDeleted: false,
  deletedAt: null,
);
```

### 5.2 创建计划

```dart
final plan = Plan(
  id: generateUuid(),  // 使用UUID作为ID
  userId: currentUserId,
  name: "每日代码练习",  // 名称在用户范围内唯一
  description: "每天练习编程1小时",
  goalId: goal.id,
  startDate: DateTime.now(),
  endDate: DateTime(2024, 12, 31),
  repeatRule: RepeatRule(type: RepeatType.daily),
  taskConfig: TaskConfiguration(
    durationMinutes: 60,
    repeatCount: null,
    evaluationOptions: null,
  ),
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  isDeleted: false,
  deletedAt: null,
);
```

### 5.3 生成任务

```dart
final task = Task(
  id: generateUuid(),
  userId: plan.userId,
  planId: plan.id,
  name: plan.name,
  description: plan.description,
  config: plan.taskConfig,
  windowStartTime: DateTime.now(),
  windowEndTime: DateTime.now().add(Duration(days: 1)),
  status: TaskStatus.active,
  currentCount: 0,
  createdAt: DateTime.now(),
  isDeleted: false,
  deletedAt: null,
);
```

## 6. 数据持久化

所有实体都需要支持：
1. **序列化/反序列化**：与JSON相互转换
2. **数据库映射**：与SQLite表结构对应
3. **网络传输**：API请求/响应格式
4. **本地缓存**：离线数据存储

```dart
// 示例：Goal的序列化
extension GoalSerialization on Goal {
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'description': description,
    'tags': tags,
    'deadline': deadline?.toIso8601String(),
    'priority': priority.name,
    'status': status.name,
    'successCriteria': successCriteria,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'planIds': planIds,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'],
    userId: json['userId'],
    title: json['title'],
    description: json['description'],
    tags: List<String>.from(json['tags']),
    deadline: json['deadline'] != null
      ? DateTime.parse(json['deadline'])
      : null,
    priority: Priority.values.byName(json['priority']),
    status: GoalStatus.values.byName(json['status']),
    successCriteria: json['successCriteria'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    planIds: List<String>.from(json['planIds']),
    deletedAt: json['deletedAt'] != null
      ? DateTime.parse(json['deletedAt'])
      : null,
  );
}
```

## 总结

本文档定义了任务管理系统的完整数据模型，包括：
- 7个核心实体及其所有字段
- 实体间的关系和约束
- 业务规则和验证逻辑
- 数据使用示例

这些数据模型是整个系统的基础，后续的业务逻辑、数据库设计和API接口都将基于这些定义进行实现。