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

  // 计算属性
  int get planCount => planIds.length;
  double get overallProgress;   // 所有计划的平均完成率
  int get daysRemaining;        // 剩余天数
}

enum Priority {
  high,    // 高优先级
  medium,  // 中优先级
  low      // 低优先级
}

enum GoalStatus {
  inProgress,  // 进行中
  paused,      // 暂停
  completed    // 已完成
}
```

### 1.2 Plan（计划）实体

计划是目标的具体执行方案，包含时间规则和任务配置。

```dart
class Plan {
  // 基础字段
  String id;                    // 唯一标识符（UUID）
  String userId;                // 所属用户ID
  String name;                  // 计划名称（必填，用户范围内唯一）
  String? description;          // 计划描述（选填）

  // 关联关系
  String goalId;                // 所属目标ID（必填，计划必须属于某个目标）

  // 时间设置
  DateTime startDate;           // 开始日期（必填）
  DateTime endDate;             // 结束日期（必填）
  RepeatRule repeatRule;        // 重复规则

  // 任务配置
  TaskConfiguration taskConfig; // 任务配置（计时/计数/评价等）

  // 时间戳
  DateTime createdAt;           // 创建时间
  DateTime updatedAt;           // 更新时间

  // 计算属性
  double get completionRate;    // 完成率
  int get totalTaskCount;       // 总任务数
  int get completedTaskCount;   // 已完成任务数
  int get skippedTaskCount;     // 已跳过任务数
  bool get isActive;            // 是否处于活动期
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
  TaskStatus status;            // 状态（待执行/已完成/已跳过）
  int currentCount;             // 当前完成次数（用于repeatCount任务）

  // 完成信息
  DateTime? completedAt;        // 完成时间
  DateTime? skippedAt;          // 跳过时间
  int? actualDurationMinutes;   // 实际执行时长（计时任务）
  String? evaluationResult;     // 评价结果（评价任务）
  String? executionNote;        // 执行备注

  // 时间戳
  DateTime createdAt;           // 创建时间（任务生成时间）

  // 计算属性
  bool get isExpired => DateTime.now().isAfter(windowEndTime);
  bool get canExecute => status == TaskStatus.active && !isExpired;
  double get progress {
    if (config.repeatCount == null) return 0;
    return currentCount / config.repeatCount!;
  }
}

enum TaskStatus {
  active,     // 待执行
  completed,  // 已完成
  skipped     // 已跳过
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
   - 删除目标时，相关计划也会被删除

3. **计划与任务的关系**
   - 一个计划可以生成多个任务
   - 任务必须来源于某个计划（组合关系）
   - 删除计划时，相关任务也会被删除
   - 每个计划同一时间只能有一个活跃任务

4. **任务生成规则**
   - 任务由系统自动生成，不允许手动创建
   - 根据计划的重复规则生成下一个任务
   - 任务窗口结束后自动生成新任务

## 3. 业务规则约束

### 3.1 目标相关规则
- 目标标题不能为空
- 目标优先级默认为中等
- 已完成的目标不能修改

### 3.2 计划相关规则
- 计划名称作为ID，创建后不可修改
- 计划必须关联到某个目标
- 结束日期必须大于开始日期
- 自定义重复天数必须大于0

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
  status: GoalStatus.inProgress,
  successCriteria: "完成一个完整的Flutter应用",
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  planIds: [],
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