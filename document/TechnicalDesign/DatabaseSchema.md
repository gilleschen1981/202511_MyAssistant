# 数据库设计

本文档定义了任务管理系统的SQLite数据库架构，包括表结构、索引、约束和数据迁移策略。

## 1. 数据库概述

### 1.1 技术选型
- **数据库引擎**：SQLite 3.x
- **ORM框架**：使用sqflite原生API
- **版本管理**：内置版本控制和迁移机制

### 1.2 设计原则
1. 数据完整性：使用外键约束确保引用完整性
2. 性能优化：合理使用索引提升查询效率
3. 扩展性：预留字段支持未来功能扩展
4. 软删除：重要数据使用软删除策略

## 2. 表结构设计

### 2.1 用户表（users）

```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY,                    -- UUID
    username TEXT NOT NULL UNIQUE,          -- 用户名
    email TEXT NOT NULL UNIQUE,             -- 邮箱
    password_hash TEXT NOT NULL,            -- 密码哈希
    display_name TEXT,                      -- 显示名称
    avatar_url TEXT,                        -- 头像URL
    status TEXT NOT NULL DEFAULT 'active',  -- 状态: active/deactivated
    created_at INTEGER NOT NULL,            -- 创建时间(Unix时间戳)
    updated_at INTEGER NOT NULL,            -- 更新时间
    deleted_at INTEGER,                     -- 删除时间(软删除)

    CHECK (status IN ('active', 'deactivated'))
);

-- 索引
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_status ON users(status) WHERE deleted_at IS NULL;
```

### 2.2 用户设置表（user_settings）

```sql
CREATE TABLE user_settings (
    user_id TEXT PRIMARY KEY,               -- 用户ID
    theme_mode TEXT DEFAULT 'system',       -- 主题模式: light/dark/system
    locale TEXT DEFAULT 'zh_CN',            -- 语言设置
    font_scale REAL DEFAULT 1.0,            -- 字体缩放(0.8-1.3)
    enable_notifications INTEGER DEFAULT 1,  -- 启用通知(0/1)
    enable_sound INTEGER DEFAULT 1,         -- 启用声音
    enable_vibration INTEGER DEFAULT 1,     -- 启用震动
    auto_sync INTEGER DEFAULT 1,            -- 自动同步
    last_sync_time INTEGER,                 -- 最后同步时间
    auto_refresh_tasks INTEGER DEFAULT 1,   -- 自动刷新任务
    default_timer_minutes INTEGER DEFAULT 25, -- 默认计时时长

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CHECK (theme_mode IN ('light', 'dark', 'system')),
    CHECK (font_scale BETWEEN 0.8 AND 1.3)
);
```

### 2.3 目标表（goals）

**重要说明**: 目标表使用 `status='deleted'` 进行软删除，而不是单独的 `is_deleted` 字段。
这是因为 GoalStatus 枚举已经包含了 `deleted` 状态。

```sql
CREATE TABLE goals (
    id TEXT PRIMARY KEY,                    -- UUID
    user_id TEXT NOT NULL,                  -- 用户ID
    title TEXT NOT NULL,                    -- 标题
    description TEXT,                       -- 描述
    tags TEXT,                              -- 标签(JSON数组)
    deadline INTEGER,                       -- 截止日期
    priority TEXT NOT NULL DEFAULT 'medium', -- 优先级: high/medium/low
    status TEXT NOT NULL DEFAULT 'active',     -- 状态: active/paused/completed/deleted
    success_criteria TEXT,                  -- 成功标准
    created_at INTEGER NOT NULL,            -- 创建时间
    updated_at INTEGER NOT NULL,            -- 更新时间
    deleted_at INTEGER,                     -- 删除时间(用于审计跟踪)

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CHECK (priority IN ('high', 'medium', 'low')),
    CHECK (status IN ('active', 'paused', 'completed', 'deleted'))
);

-- 索引（使用 status 字段过滤已删除的记录）
CREATE INDEX idx_goals_user_id ON goals(user_id) WHERE status != 'deleted';
CREATE INDEX idx_goals_status ON goals(status) WHERE status != 'deleted';
CREATE INDEX idx_goals_priority ON goals(priority) WHERE status != 'deleted';
CREATE INDEX idx_goals_deadline ON goals(deadline) WHERE status != 'deleted';
```

### 2.4 计划表（plans）

**重要说明**: 计划表使用 `status='deleted'` 进行软删除，与 Goal 表保持一致。

```sql
CREATE TABLE plans (
    id TEXT PRIMARY KEY,                    -- UUID
    user_id TEXT NOT NULL,                  -- 用户ID
    goal_id TEXT NOT NULL,                  -- 目标ID
    name TEXT NOT NULL,                     -- 计划名称（用户范围内唯一）
    description TEXT,                       -- 描述
    start_date INTEGER NOT NULL,            -- 开始日期
    end_date INTEGER NOT NULL,              -- 结束日期
    repeat_type TEXT NOT NULL,              -- 重复类型
    custom_days INTEGER,                    -- 自定义天数
    task_config TEXT NOT NULL,              -- 任务配置(JSON)
    status TEXT NOT NULL DEFAULT 'active',  -- 状态: active/paused/completed/deleted
    created_at INTEGER NOT NULL,            -- 创建时间
    updated_at INTEGER NOT NULL,            -- 更新时间
    deleted_at INTEGER,                     -- 删除时间(用于审计跟踪)

    -- 统计字段(冗余存储，提高查询性能)
    total_task_count INTEGER DEFAULT 0,     -- 总任务数
    completed_task_count INTEGER DEFAULT 0, -- 完成任务数
    skipped_task_count INTEGER DEFAULT 0,   -- 跳过任务数
    completion_rate REAL DEFAULT 0.0,       -- 完成率

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (goal_id) REFERENCES goals(id) ON DELETE CASCADE,
    CHECK (repeat_type IN ('oneTime', 'daily', 'weekly', 'monthly', 'custom')),
    CHECK (end_date >= start_date),
    CHECK (custom_days IS NULL OR custom_days > 0),
    CHECK (status IN ('active', 'paused', 'completed', 'deleted'))
);

-- 索引（使用 status 字段过滤已删除的记录）
CREATE INDEX idx_plans_user_id ON plans(user_id) WHERE status != 'deleted';
CREATE INDEX idx_plans_goal_id ON plans(goal_id) WHERE status != 'deleted';
CREATE INDEX idx_plans_active ON plans(start_date, end_date) WHERE status != 'deleted';
CREATE UNIQUE INDEX idx_plans_user_name ON plans(user_id, name) WHERE status != 'deleted';
CREATE INDEX idx_plans_status ON plans(status) WHERE status != 'deleted';
```

### 2.5 任务表（tasks）

**设计理念**：
- 每个任务都是独立的实体,没有父子关系
- **支持软删除**（当所属计划被删除时）
- 任务"重复执行"通过创建新的独立任务实现,而非在原任务上记录多次执行

**重要说明**：
- ❌ 没有 `repeat_execution_count` 字段
- ❌ 没有 `original_task_id` 字段
- ❌ 不再有 `task_executions` 表
- ✅ 每次用户想"再次执行"时,系统会创建一个全新的任务(新ID),复制原任务的配置
- ✅ 任务使用 `status='deleted'` 进行软删除，当所属计划被删除时会级联软删除

```sql
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,                    -- UUID
    user_id TEXT NOT NULL,                  -- 用户ID
    plan_id TEXT NOT NULL,                  -- 计划ID
    name TEXT NOT NULL,                     -- 任务名称
    description TEXT,                       -- 描述
    config TEXT NOT NULL,                   -- 任务配置(JSON)
    window_start_time INTEGER NOT NULL,     -- 执行窗口开始
    window_end_time INTEGER NOT NULL,       -- 执行窗口结束
    status TEXT NOT NULL DEFAULT 'active',  -- 状态: active/completed/skipped/deleted
    current_count INTEGER DEFAULT 0,        -- 当前计数(用于计数类任务)
    completed_at INTEGER,                   -- 完成时间
    skipped_at INTEGER,                     -- 跳过时间
    actual_duration_minutes INTEGER,        -- 实际执行时长(计时任务)
    evaluation_result TEXT,                 -- 评价结果(评价任务)
    execution_note TEXT,                    -- 执行备注
    created_at INTEGER NOT NULL,            -- 创建时间
    deleted_at INTEGER,                     -- 删除时间(用于审计跟踪)

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE,
    CHECK (status IN ('active', 'completed', 'skipped', 'deleted')),
    CHECK (window_end_time >= window_start_time)
);

-- 索引（使用 status 字段过滤已删除的记录）
CREATE INDEX idx_tasks_user_id ON tasks(user_id) WHERE status != 'deleted';
CREATE INDEX idx_tasks_plan_id ON tasks(plan_id) WHERE status != 'deleted';
CREATE INDEX idx_tasks_status ON tasks(status) WHERE status != 'deleted';
CREATE INDEX idx_tasks_window ON tasks(window_start_time, window_end_time) WHERE status != 'deleted';
CREATE INDEX idx_tasks_user_status ON tasks(user_id, status) WHERE status != 'deleted';
CREATE INDEX idx_tasks_plan_status ON tasks(plan_id, status) WHERE status != 'deleted';
-- 复合索引优化常用查询
CREATE INDEX idx_tasks_user_window_status ON tasks(user_id, window_start_time, status) WHERE status != 'deleted';
```

### 2.6 任务历史表（task_history）

用于记录任务的所有状态变更，支持审计和分析。

```sql
CREATE TABLE task_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,   -- 自增ID
    task_id TEXT NOT NULL,                  -- 任务ID
    user_id TEXT NOT NULL,                  -- 用户ID
    action TEXT NOT NULL,                   -- 操作: created/completed/skipped
    old_status TEXT,                        -- 原状态
    new_status TEXT,                        -- 新状态
    metadata TEXT,                          -- 额外数据(JSON)
    created_at INTEGER NOT NULL,            -- 操作时间

    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 索引
CREATE INDEX idx_task_history_task_id ON task_history(task_id);
CREATE INDEX idx_task_history_user_id ON task_history(user_id);
CREATE INDEX idx_task_history_created_at ON task_history(created_at);
```

**任务历史表特点**：
- 由数据库 trigger 自动维护,无需手动插入
- 记录所有任务状态变更,用于审计和分析
- 支持查询任务的完整生命周期

### 2.7 任务重复执行设计

#### 设计理念

**核心原则**: 没有"重复执行(repeat execution)"概念,每次执行都是独立的新任务

#### 实现方式

当用户想要"再次执行"一个已完成的任务时:

1. **检查前置条件**:
   - 原任务状态必须为 `completed`
   - 原任务必须仍在时间窗口内 (`isInCurrentWindow`)

2. **创建新任务**:
   ```dart
   // 复制原任务的配置,生成新ID
   TaskModel newTask = TaskModel(
     id: generateNewUUID(),           // 全新的UUID
     userId: original.userId,
     planId: original.planId,
     name: original.name,             // 复制名称
     description: original.description,
     config: original.config,         // 复制配置
     windowStartTime: original.windowStartTime,
     windowEndTime: original.windowEndTime,
     status: TaskStatus.active,       // 新任务默认active
     currentCount: 0,                 // 重置计数
     createdAt: DateTime.now(),       // 新的创建时间
   );
   ```

3. **关键特性**:
   - ✅ 新任务有独立的 `id`
   - ✅ 新任务有独立的状态生命周期
   - ✅ 两个任务之间**没有任何关联关系**
   - ✅ 可以在数据库中独立查询、更新、删除

#### 数据库层面

- ❌ 不使用外键关联原任务
- ❌ 不记录任务之间的父子关系
- ❌ 不需要 `task_executions` 表
- ✅ 每个任务都是平等的、独立的记录

#### 业务逻辑

```dart
// TaskDao.createRepeatExecution()
Future<TaskModel?> createRepeatExecution(String originalTaskId) async {
  final originalTask = await getTaskById(originalTaskId);

  // 验证条件
  if (originalTask.status != TaskStatus.completed) return null;
  if (!originalTask.isInCurrentWindow) return null;

  // 创建新任务
  final newTask = TaskModel(
    id: _uuid.v4(),  // 新UUID
    // ... 复制配置
  );

  return await insertTask(newTask);
}
```

## 3. 视图设计

### 3.1 活跃任务视图

```sql
CREATE VIEW v_active_tasks AS
SELECT
    t.*,
    p.name as plan_name,
    p.goal_id,
    g.title as goal_title,
    g.priority as goal_priority
FROM tasks t
INNER JOIN plans p ON t.plan_id = p.id AND p.status != 'deleted'
INNER JOIN goals g ON p.goal_id = g.id AND g.status != 'deleted'
WHERE t.status = 'active'
  AND datetime('now') BETWEEN datetime(t.window_start_time, 'unixepoch')
                           AND datetime(t.window_end_time, 'unixepoch');
```

### 3.2 目标进度视图

```sql
CREATE VIEW v_goal_progress AS
SELECT
    g.id,
    g.title,
    g.priority,
    g.status,
    COUNT(DISTINCT p.id) as plan_count,
    AVG(p.completion_rate) as overall_progress,
    SUM(p.completed_task_count) as total_completed_tasks,
    SUM(p.total_task_count) as total_tasks
FROM goals g
LEFT JOIN plans p ON g.id = p.goal_id AND p.status != 'deleted'
WHERE g.status != 'deleted'
GROUP BY g.id;
```

### 3.3 每日任务统计视图

```sql
CREATE VIEW v_daily_task_stats AS
SELECT
    user_id,
    date(window_start_time, 'unixepoch') as task_date,
    COUNT(*) as total_tasks,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_count,
    SUM(CASE WHEN status = 'skipped' THEN 1 ELSE 0 END) as skipped_count,
    SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active_count,
    AVG(CASE WHEN status = 'completed' AND actual_duration_minutes IS NOT NULL
             THEN actual_duration_minutes ELSE NULL END) as avg_duration
FROM tasks
WHERE status != 'deleted'
GROUP BY user_id, date(window_start_time, 'unixepoch');
```

## 4. 触发器设计

### 4.1 更新时间戳触发器

```sql
-- 更新goals表的updated_at
CREATE TRIGGER update_goal_timestamp
AFTER UPDATE ON goals
FOR EACH ROW
WHEN NEW.updated_at = OLD.updated_at
BEGIN
    UPDATE goals SET updated_at = strftime('%s', 'now')
    WHERE id = NEW.id;
END;

-- 更新plans表的updated_at
CREATE TRIGGER update_plan_timestamp
AFTER UPDATE ON plans
FOR EACH ROW
WHEN NEW.updated_at = OLD.updated_at
BEGIN
    UPDATE plans SET updated_at = strftime('%s', 'now')
    WHERE id = NEW.id;
END;
```

### 4.2 任务统计触发器

```sql
-- 任务完成时更新计划统计
CREATE TRIGGER update_plan_stats_on_complete
AFTER UPDATE ON tasks
FOR EACH ROW
WHEN NEW.status = 'completed' AND OLD.status != 'completed'
BEGIN
    UPDATE plans
    SET completed_task_count = completed_task_count + 1,
        total_task_count = total_task_count + 1,
        completion_rate = CAST(completed_task_count + 1 AS REAL) / (total_task_count + 1)
    WHERE id = NEW.plan_id;
END;

-- 任务跳过时更新计划统计
CREATE TRIGGER update_plan_stats_on_skip
AFTER UPDATE ON tasks
FOR EACH ROW
WHEN NEW.status = 'skipped' AND OLD.status != 'skipped'
BEGIN
    UPDATE plans
    SET skipped_task_count = skipped_task_count + 1,
        total_task_count = total_task_count + 1,
        completion_rate = CAST(completed_task_count AS REAL) / (total_task_count + 1)
    WHERE id = NEW.plan_id;
END;
```

### 4.3 任务历史记录触发器

```sql
-- 记录任务状态变更
CREATE TRIGGER log_task_status_change
AFTER UPDATE ON tasks
FOR EACH ROW
WHEN NEW.status != OLD.status
BEGIN
    INSERT INTO task_history (task_id, user_id, action, old_status, new_status, created_at)
    VALUES (NEW.id, NEW.user_id,
            CASE NEW.status
                WHEN 'completed' THEN 'completed'
                WHEN 'skipped' THEN 'skipped'
                ELSE 'updated'
            END,
            OLD.status, NEW.status, strftime('%s', 'now'));
END;
```

## 5. 数据库初始化代码

### 5.1 数据库助手类

```dart
class DatabaseHelper {
  static const String _databaseName = 'task_manager.db';
  static const int _databaseVersion = 1;

  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // 启用外键约束
    await db.execute('PRAGMA foreign_keys = ON');

    // 优化性能设置
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA cache_size = 10000');
    await db.execute('PRAGMA temp_store = MEMORY');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 创建所有表
    await db.execute(_createUsersTable);
    await db.execute(_createUserSettingsTable);
    await db.execute(_createGoalsTable);
    await db.execute(_createPlansTable);
    await db.execute(_createTasksTable);
    await db.execute(_createTaskHistoryTable);

    // 创建索引
    await _createIndexes(db);

    // 创建视图
    await _createViews(db);

    // 创建触发器
    await _createTriggers(db);

    // 插入默认数据
    await _insertDefaultData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 数据库迁移逻辑
    if (oldVersion < 2) {
      // 版本1到版本2的迁移
      await _migrateV1ToV2(db);
    }
    // 更多版本迁移...
  }

  static const String _createUsersTable = '''
    CREATE TABLE users (
      id TEXT PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      display_name TEXT,
      avatar_url TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER,
      CHECK (status IN ('active', 'deactivated'))
    )
  ''';

  // ... 其他表创建语句

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX idx_users_email ON users(email)');
    await db.execute('CREATE INDEX idx_users_username ON users(username)');
    // ... 其他索引
  }

  Future<void> _createViews(Database db) async {
    await db.execute(_createActiveTasksView);
    await db.execute(_createGoalProgressView);
    await db.execute(_createDailyStatsView);
  }

  Future<void> _createTriggers(Database db) async {
    await db.execute(_createUpdateTimestampTrigger);
    await db.execute(_createTaskStatsTrigger);
    await db.execute(_createTaskHistoryTrigger);
  }

  Future<void> _insertDefaultData(Database db) async {
    // 插入默认用户（用于测试）
    await db.insert('users', {
      'id': 'default_user',
      'username': 'guest',
      'email': 'guest@example.com',
      'password_hash': 'hashed_password',
      'status': 'active',
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });

    // 插入默认用户设置
    await db.insert('user_settings', {
      'user_id': 'default_user',
      'theme_mode': 'system',
      'locale': 'zh_CN',
    });
  }
}
```

## 6. DAO（数据访问对象）实现

### 6.1 基础DAO接口

```dart
abstract class BaseDao<T> {
  Future<T?> getById(String id);
  Future<List<T>> getAll();
  Future<void> insert(T item);
  Future<void> update(T item);
  Future<void> delete(String id);
  Future<void> softDelete(String id);
}
```

### 6.2 任务DAO实现

```dart
class TaskDao implements BaseDao<Task> {
  final Database _db;

  TaskDao(this._db);

  @override
  Future<Task?> getById(String id) async {
    final maps = await _db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  @override
  Future<List<Task>> getAll() async {
    final maps = await _db.query('tasks');
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  @override
  Future<void> insert(Task task) async {
    await _db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> update(Task task) async {
    await _db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> softDelete(String id) async {
    // 任务表使用软删除（当所属计划被删除时）
    await _db.update(
      'tasks',
      {
        'status': 'deleted',
        'deleted_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 特定查询方法
  Future<List<Task>> getActiveTasksByUserId(String userId) async {
    final maps = await _db.query(
      'tasks',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'active'],
      orderBy: 'window_start_time ASC',
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getTasksByPlanId(String planId) async {
    final maps = await _db.query(
      'tasks',
      where: 'plan_id = ? AND status != ?',
      whereArgs: [planId, 'deleted'],
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<Task?> getLastTaskForPlan(String planId) async {
    final maps = await _db.query(
      'tasks',
      where: 'plan_id = ? AND status != ?',
      whereArgs: [planId, 'deleted'],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  Future<List<Task>> getExpiredActiveTasks() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final maps = await _db.query(
      'tasks',
      where: 'status = ? AND window_end_time < ?',
      whereArgs: ['active', now],
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getTasksByDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;
    final endTimestamp = endDate.millisecondsSinceEpoch ~/ 1000;

    final maps = await _db.query(
      'tasks',
      where: 'user_id = ? AND window_start_time >= ? AND window_start_time <= ? AND status != ?',
      whereArgs: [userId, startTimestamp, endTimestamp, 'deleted'],
      orderBy: 'window_start_time ASC',
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  // 批量操作
  Future<void> batchInsert(List<Task> tasks) async {
    final batch = _db.batch();

    for (final task in tasks) {
      batch.insert('tasks', task.toMap());
    }

    await batch.commit(noResult: true);
  }

  Future<void> batchUpdateStatus(List<String> taskIds, TaskStatus status) async {
    final batch = _db.batch();

    for (final id in taskIds) {
      batch.update(
        'tasks',
        {'status': status.name},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    await batch.commit(noResult: true);
  }
}
```

## 7. 数据迁移策略

### 7.1 版本管理

```dart
class MigrationManager {
  static const List<Migration> migrations = [
    Migration(
      version: 2,
      up: _migrateV1ToV2,
      down: _migrateV2ToV1,
    ),
    // 更多迁移...
  ];

  static Future<void> migrate(Database db, int fromVersion, int toVersion) async {
    if (fromVersion < toVersion) {
      // 升级
      for (int v = fromVersion + 1; v <= toVersion; v++) {
        final migration = migrations.firstWhere((m) => m.version == v);
        await migration.up(db);
      }
    } else if (fromVersion > toVersion) {
      // 降级
      for (int v = fromVersion; v > toVersion; v--) {
        final migration = migrations.firstWhere((m) => m.version == v);
        await migration.down(db);
      }
    }
  }

  static Future<void> _migrateV1ToV2(Database db) async {
    // 添加新列
    await db.execute('ALTER TABLE tasks ADD COLUMN tags TEXT');

    // 创建新索引
    await db.execute('CREATE INDEX idx_tasks_tags ON tasks(tags)');
  }

  static Future<void> _migrateV2ToV1(Database db) async {
    // SQLite不支持直接删除列，需要重建表
    await db.execute('''
      CREATE TABLE tasks_temp AS
      SELECT id, user_id, plan_id, name, description, config,
             window_start_time, window_end_time, status, current_count,
             completed_at, skipped_at, actual_duration_minutes,
             evaluation_result, execution_note, created_at
      FROM tasks
    ''');

    await db.execute('DROP TABLE tasks');
    await db.execute('ALTER TABLE tasks_temp RENAME TO tasks');

    // 重建索引
    await _recreateTaskIndexes(db);
  }

  static Future<void> _recreateTaskIndexes(Database db) async {
    await db.execute('CREATE INDEX idx_tasks_user_id ON tasks(user_id)');
    await db.execute('CREATE INDEX idx_tasks_plan_id ON tasks(plan_id)');
    await db.execute('CREATE INDEX idx_tasks_status ON tasks(status)');
  }
}

class Migration {
  final int version;
  final Future<void> Function(Database) up;
  final Future<void> Function(Database) down;

  const Migration({
    required this.version,
    required this.up,
    required this.down,
  });
}
```

## 8. 性能优化

### 8.1 查询优化

```dart
class QueryOptimizer {
  // 使用预编译语句
  static final Map<String, String> _preparedStatements = {
    'getActiveTasks': '''
      SELECT t.*, p.name as plan_name, g.title as goal_title
      FROM tasks t
      INNER JOIN plans p ON t.plan_id = p.id
      INNER JOIN goals g ON p.goal_id = g.id
      WHERE t.user_id = ? AND t.status = 'active'
      ORDER BY t.window_start_time ASC
      LIMIT ?
    ''',
    'getDailyStats': '''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
        SUM(CASE WHEN status = 'skipped' THEN 1 ELSE 0 END) as skipped
      FROM tasks
      WHERE user_id = ?
        AND date(window_start_time, 'unixepoch') = date('now')
    ''',
  };

  static String getStatement(String name) {
    return _preparedStatements[name] ?? '';
  }
}

// 批量查询优化
class BatchQueryExecutor {
  final Database _db;

  BatchQueryExecutor(this._db);

  Future<Map<String, List<Task>>> getTasksForMultiplePlans(
    List<String> planIds,
  ) async {
    // 使用IN查询替代多次单独查询
    final placeholders = List.filled(planIds.length, '?').join(',');
    final query = 'SELECT * FROM tasks WHERE plan_id IN ($placeholders)';

    final maps = await _db.rawQuery(query, planIds);

    // 按计划ID分组
    final Map<String, List<Task>> result = {};
    for (final map in maps) {
      final task = Task.fromMap(map);
      result.putIfAbsent(task.planId, () => []).add(task);
    }

    return result;
  }
}
```

### 8.2 缓存策略

```dart
class DatabaseCache {
  static final _cache = <String, CacheEntry>{};
  static const _maxCacheSize = 100;
  static const _defaultTTL = Duration(minutes: 5);

  static Future<T?> getCached<T>(
    String key,
    Future<T?> Function() fetchFunction,
  ) async {
    // 检查缓存
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.data as T?;
    }

    // 从数据库获取
    final data = await fetchFunction();

    // 更新缓存
    _cache[key] = CacheEntry(
      data: data,
      expireTime: DateTime.now().add(_defaultTTL),
    );

    // 限制缓存大小
    if (_cache.length > _maxCacheSize) {
      _evictOldest();
    }

    return data;
  }

  static void invalidate(String? key) {
    if (key != null) {
      _cache.remove(key);
    } else {
      _cache.clear();
    }
  }

  static void _evictOldest() {
    final entries = _cache.entries.toList()
      ..sort((a, b) => a.value.expireTime.compareTo(b.value.expireTime));

    // 删除最旧的20%
    final toRemove = entries.take(_maxCacheSize ~/ 5);
    for (final entry in toRemove) {
      _cache.remove(entry.key);
    }
  }
}
```

## 9. 备份与恢复

### 9.1 数据备份

```dart
class BackupManager {
  static Future<String> createBackup() async {
    final db = await DatabaseHelper.instance.database;
    final dbPath = await getDatabasesPath();
    final backupPath = join(dbPath, 'backup_${DateTime.now().millisecondsSinceEpoch}.db');

    // 执行备份
    await db.execute('BEGIN IMMEDIATE');
    try {
      await db.rawQuery('VACUUM INTO ?', [backupPath]);
      await db.execute('COMMIT');
      return backupPath;
    } catch (e) {
      await db.execute('ROLLBACK');
      rethrow;
    }
  }

  static Future<void> restoreBackup(String backupPath) async {
    final dbPath = await getDatabasesPath();
    final currentPath = join(dbPath, DatabaseHelper._databaseName);

    // 关闭当前数据库
    final db = await DatabaseHelper.instance.database;
    await db.close();

    // 替换数据库文件
    final backupFile = File(backupPath);
    final currentFile = File(currentPath);

    await currentFile.delete();
    await backupFile.copy(currentPath);

    // 重新打开数据库
    DatabaseHelper._database = null;
    await DatabaseHelper.instance.database;
  }

  static Future<Map<String, dynamic>> exportToJson() async {
    final db = await DatabaseHelper.instance.database;

    return {
      'version': await db.getVersion(),
      'exported_at': DateTime.now().toIso8601String(),
      'users': await db.query('users'),
      'goals': await db.query('goals'),
      'plans': await db.query('plans'),
      'tasks': await db.query('tasks'),
      'user_settings': await db.query('user_settings'),
    };
  }

  static Future<void> importFromJson(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      // 清空现有数据
      await txn.delete('tasks');
      await txn.delete('plans');
      await txn.delete('goals');
      await txn.delete('user_settings');
      await txn.delete('users');

      // 导入数据
      for (final user in data['users']) {
        await txn.insert('users', user);
      }
      for (final goal in data['goals']) {
        await txn.insert('goals', goal);
      }
      for (final plan in data['plans']) {
        await txn.insert('plans', plan);
      }
      for (final task in data['tasks']) {
        await txn.insert('tasks', task);
      }
      for (final settings in data['user_settings']) {
        await txn.insert('user_settings', settings);
      }
    });
  }
}
```

## 10. 数据完整性检查

### 10.1 完整性验证

```dart
class DataIntegrityChecker {
  final Database _db;

  DataIntegrityChecker(this._db);

  Future<IntegrityReport> checkIntegrity() async {
    final report = IntegrityReport();

    // 检查外键约束
    report.foreignKeyViolations = await _checkForeignKeys();

    // 检查孤立数据
    report.orphanedRecords = await _checkOrphanedRecords();

    // 检查数据一致性
    report.inconsistencies = await _checkDataConsistency();

    // 检查索引完整性
    report.indexIssues = await _checkIndexes();

    return report;
  }

  Future<List<String>> _checkForeignKeys() async {
    final violations = <String>[];

    // 检查任务的计划引用
    final orphanedTasks = await _db.rawQuery('''
      SELECT t.id FROM tasks t
      LEFT JOIN plans p ON t.plan_id = p.id
      WHERE p.id IS NULL AND t.status != 'deleted'
    ''');

    if (orphanedTasks.isNotEmpty) {
      violations.add('找到 ${orphanedTasks.length} 个孤立任务');
    }

    // 检查计划的目标引用
    final orphanedPlans = await _db.rawQuery('''
      SELECT p.id FROM plans p
      LEFT JOIN goals g ON p.goal_id = g.id
      WHERE g.id IS NULL AND p.status != 'deleted'
    ''');

    if (orphanedPlans.isNotEmpty) {
      violations.add('找到 ${orphanedPlans.length} 个孤立计划');
    }

    return violations;
  }

  Future<List<String>> _checkOrphanedRecords() async {
    final orphaned = <String>[];

    // 检查没有关联计划的目标
    final emptyGoals = await _db.rawQuery('''
      SELECT g.id FROM goals g
      LEFT JOIN plans p ON g.id = p.goal_id AND p.status != 'deleted'
      WHERE p.id IS NULL AND g.status != 'deleted'
      GROUP BY g.id
    ''');

    if (emptyGoals.isNotEmpty) {
      orphaned.add('找到 ${emptyGoals.length} 个空目标');
    }

    return orphaned;
  }

  Future<List<String>> _checkDataConsistency() async {
    final issues = <String>[];

    // 检查计划统计准确性
    final planStats = await _db.rawQuery('''
      SELECT
        p.id,
        p.total_task_count,
        p.completed_task_count,
        COUNT(t.id) as actual_total,
        SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) as actual_completed
      FROM plans p
      LEFT JOIN tasks t ON p.id = t.plan_id AND t.status != 'deleted'
      WHERE p.status != 'deleted'
      GROUP BY p.id
      HAVING p.total_task_count != actual_total
          OR p.completed_task_count != actual_completed
    ''');

    if (planStats.isNotEmpty) {
      issues.add('找到 ${planStats.length} 个计划统计不一致');
    }

    return issues;
  }

  Future<List<String>> _checkIndexes() async {
    final issues = <String>[];

    // 使用PRAGMA检查索引
    final indexes = await _db.rawQuery('PRAGMA index_list(tasks)');

    // 验证必要的索引存在
    final requiredIndexes = [
      'idx_tasks_user_id',
      'idx_tasks_plan_id',
      'idx_tasks_status',
    ];

    final existingIndexes = indexes.map((idx) => idx['name'] as String).toSet();

    for (final required in requiredIndexes) {
      if (!existingIndexes.contains(required)) {
        issues.add('缺少索引: $required');
      }
    }

    return issues;
  }

  // 修复数据问题
  Future<void> fixIntegrityIssues(IntegrityReport report) async {
    await _db.transaction((txn) async {
      // 软删除孤立记录
      if (report.foreignKeyViolations.isNotEmpty) {
        await txn.rawQuery('''
          UPDATE tasks
          SET status = 'deleted', deleted_at = strftime('%s', 'now')
          WHERE plan_id NOT IN (SELECT id FROM plans WHERE status != 'deleted')
        ''');
      }

      // 重新计算统计
      if (report.inconsistencies.isNotEmpty) {
        await txn.rawQuery('''
          UPDATE plans
          SET total_task_count = (
            SELECT COUNT(*) FROM tasks WHERE plan_id = plans.id AND status != 'deleted'
          ),
          completed_task_count = (
            SELECT COUNT(*) FROM tasks
            WHERE plan_id = plans.id AND status = 'completed'
          )
        ''');
      }
    });
  }
}

class IntegrityReport {
  List<String> foreignKeyViolations = [];
  List<String> orphanedRecords = [];
  List<String> inconsistencies = [];
  List<String> indexIssues = [];

  bool get hasIssues =>
      foreignKeyViolations.isNotEmpty ||
      orphanedRecords.isNotEmpty ||
      inconsistencies.isNotEmpty ||
      indexIssues.isNotEmpty;
}
```

## 总结

本数据库设计文档提供了完整的SQLite数据库架构，包括：

1. **表结构设计**：6个核心表，支持软删除和审计
2. **索引优化**：针对常用查询创建合适的索引
3. **视图设计**：简化复杂查询
4. **触发器**：自动维护数据一致性
5. **DAO实现**：封装数据访问逻辑
6. **迁移策略**：支持版本升级和降级
7. **性能优化**：查询优化和缓存机制
8. **备份恢复**：数据安全保障
9. **完整性检查**：确保数据质量

这个数据库架构设计确保了数据的完整性、一致性和高性能，为任务管理系统提供了坚实的数据层基础。