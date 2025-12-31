import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:myassistant/core/constants/app_constants.dart';
import 'package:myassistant/core/constants/demo_user_constants.dart';
import 'package:myassistant/data/data_sources/local/database/database_interface.dart';
import 'package:myassistant/core/utils/app_logger.dart';

/// Main database class for the application
class AppDatabase implements DatabaseInterface {
  static final AppDatabase instance = AppDatabase._internal();
  factory AppDatabase() => instance;
  AppDatabase._internal();

  Database? _database;

  /// Get database instance
  @override
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    AppLogger.i('Starting database initialization...', tag: 'AppDatabase');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);
    AppLogger.i('Database path: $path', tag: 'AppDatabase');

    final database = await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
      onOpen: _onOpen,
    );

    return database;
  }

  /// Configure database settings
  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Called when database is opened
  Future<void> _onOpen(Database db) async {
    AppLogger.i('Database opened, checking demo user...', tag: 'AppDatabase');

    // Check if demo user exists
    final users = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [DemoUserConstants.userId],
      limit: 1,
    );

    if (users.isEmpty) {
      AppLogger.i('Demo user not found, creating...', tag: 'AppDatabase');
      final now = getCurrentTimestamp();

      // Insert demo user
      await db.insert(
        'users',
        DemoUserConstants.getUserData(now),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // Insert demo user settings
      await db.insert(
        'user_settings',
        DemoUserConstants.getUserSettingsData(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      AppLogger.i('Demo user created successfully', tag: 'AppDatabase');
    } else {
      AppLogger.i('Demo user already exists', tag: 'AppDatabase');
    }
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    AppLogger.i('Creating database tables, version: $version', tag: 'AppDatabase');
    final batch = db.batch();

    // Users table
    batch.execute('''
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
    ''');

    // User settings table
    batch.execute('''
      CREATE TABLE user_settings (
        user_id TEXT PRIMARY KEY,
        theme_mode TEXT DEFAULT 'system',
        locale TEXT DEFAULT 'zh_CN',
        font_scale REAL DEFAULT 1.0,
        enable_notifications INTEGER DEFAULT 1,
        enable_sound INTEGER DEFAULT 1,
        enable_vibration INTEGER DEFAULT 1,
        auto_sync INTEGER DEFAULT 1,
        last_sync_time INTEGER,
        auto_refresh_tasks INTEGER DEFAULT 1,
        default_timer_minutes INTEGER DEFAULT 25,
        enable_analytics INTEGER DEFAULT 0,
        enable_crash_reporting INTEGER DEFAULT 1,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        CHECK (theme_mode IN ('light', 'dark', 'system')),
        CHECK (font_scale BETWEEN 0.8 AND 1.3)
      )
    ''');

    // Goals table (uses status='deleted' for soft delete, no need for is_deleted)
    batch.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        tags TEXT,
        deadline INTEGER,
        priority TEXT NOT NULL DEFAULT 'medium',
        status TEXT NOT NULL DEFAULT 'active',
        success_criteria TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        CHECK (priority IN ('high', 'medium', 'low')),
        CHECK (status IN ('active', 'paused', 'completed', 'deleted'))
      )
    ''');

    // Plans table - with UUID as ID and immutable unique name
    batch.execute('''
      CREATE TABLE plans (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        goal_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        start_date INTEGER NOT NULL,
        end_date INTEGER NOT NULL,
        repeat_type TEXT NOT NULL,
        custom_days INTEGER,
        selected_days_of_week TEXT,
        task_config TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        total_task_count INTEGER DEFAULT 0,
        completed_task_count INTEGER DEFAULT 0,
        skipped_task_count INTEGER DEFAULT 0,
        completion_rate REAL DEFAULT 0.0,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (goal_id) REFERENCES goals(id) ON DELETE CASCADE,
        CHECK (repeat_type IN ('oneTime', 'daily', 'weekly', 'monthly', 'daysOfWeek', 'custom')),
        CHECK (end_date >= start_date),
        CHECK (custom_days IS NULL OR custom_days > 0),
        CHECK (status IN ('active', 'paused', 'completed', 'deleted'))
      )
    ''');

    // Tasks table - with soft delete support
    batch.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        plan_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        config TEXT NOT NULL,
        window_start_time INTEGER NOT NULL,
        window_end_time INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        current_count INTEGER DEFAULT 0,
        completed_at INTEGER,
        skipped_at INTEGER,
        actual_duration_minutes INTEGER,
        evaluation_result TEXT,
        execution_note TEXT,
        created_at INTEGER NOT NULL,
        deleted_at INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE,
        CHECK (status IN ('active', 'completed', 'skipped', 'deleted')),
        CHECK (window_end_time >= window_start_time)
      )
    ''');

    // Task history table
    batch.execute('''
      CREATE TABLE task_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        old_status TEXT,
        new_status TEXT,
        metadata TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // Create indexes
    _createIndexes(batch);

    // Create views for automatic statistics and data aggregation
    _createViews(batch);

    // Create triggers for auto-timestamps and data integrity
    _createTriggers(batch);

    // Create initial demo user
    _createDemoUser(batch);

    await batch.commit(noResult: true);
    AppLogger.i('Database tables created successfully', tag: 'AppDatabase');
  }

  /// Create database indexes
  void _createIndexes(Batch batch) {
    // Users indexes
    batch.execute('CREATE INDEX idx_users_email ON users(email)');
    batch.execute('CREATE INDEX idx_users_username ON users(username)');
    batch.execute('CREATE INDEX idx_users_status ON users(status) WHERE deleted_at IS NULL');

    // Goals indexes (filter by status != 'deleted' instead of is_deleted)
    batch.execute("CREATE INDEX idx_goals_user_id ON goals(user_id) WHERE status != 'deleted'");
    batch.execute("CREATE INDEX idx_goals_status ON goals(status) WHERE status != 'deleted'");
    batch.execute("CREATE INDEX idx_goals_priority ON goals(priority) WHERE status != 'deleted'");
    batch.execute("CREATE INDEX idx_goals_deadline ON goals(deadline) WHERE status != 'deleted'");
    batch.execute("CREATE UNIQUE INDEX idx_goals_user_title ON goals(user_id, title) WHERE status != 'deleted'");

    // Plans indexes
    batch.execute('CREATE INDEX idx_plans_user_id ON plans(user_id) WHERE status != \'deleted\'');
    batch.execute('CREATE INDEX idx_plans_goal_id ON plans(goal_id) WHERE status != \'deleted\'');
    batch.execute('CREATE INDEX idx_plans_active ON plans(start_date, end_date) WHERE status != \'deleted\'');
    batch.execute('CREATE UNIQUE INDEX idx_plans_user_name ON plans(user_id, name) WHERE status != \'deleted\'');

    // Tasks indexes
    batch.execute('CREATE INDEX idx_tasks_user_id ON tasks(user_id) WHERE status != \'deleted\'');
    batch.execute('CREATE INDEX idx_tasks_plan_id ON tasks(plan_id) WHERE status != \'deleted\'');
    batch.execute('CREATE INDEX idx_tasks_status ON tasks(status) WHERE status != \'deleted\'');
    batch.execute('CREATE INDEX idx_tasks_window ON tasks(window_start_time, window_end_time) WHERE status != \'deleted\'');
    batch.execute('CREATE INDEX idx_tasks_user_status ON tasks(user_id, status) WHERE status != \'deleted\'');
    batch.execute('CREATE INDEX idx_tasks_plan_status ON tasks(plan_id, status) WHERE status != \'deleted\'');
    batch.execute('CREATE INDEX idx_tasks_user_window_status ON tasks(user_id, window_start_time, status) WHERE status != \'deleted\'');

    // Task history indexes
    batch.execute('CREATE INDEX idx_task_history_task_id ON task_history(task_id)');
    batch.execute('CREATE INDEX idx_task_history_user_id ON task_history(user_id)');
    batch.execute('CREATE INDEX idx_task_history_created_at ON task_history(created_at)');
  }

  /// Create initial demo user
  void _createDemoUser(Batch batch) {
    AppLogger.i('Creating demo user...', tag: 'AppDatabase');
    final now = getCurrentTimestamp();

    // Insert demo user
    batch.insert(
      'users',
      DemoUserConstants.getUserData(now),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    AppLogger.i('Demo user insert queued', tag: 'AppDatabase');

    // Insert demo user settings
    batch.insert(
      'user_settings',
      DemoUserConstants.getUserSettingsData(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Create database views
  void _createViews(Batch batch) {
    // Active tasks view
    batch.execute('''
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
                                 AND datetime(t.window_end_time, 'unixepoch')
    ''');

    // Goal progress view
    batch.execute('''
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
      GROUP BY g.id
    ''');

    // Daily task statistics view
    batch.execute('''
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
      GROUP BY user_id, date(window_start_time, 'unixepoch')
    ''');
  }

  /// Create database triggers
  void _createTriggers(Batch batch) {
    // Update goals timestamp trigger
    batch.execute('''
      CREATE TRIGGER update_goal_timestamp
      AFTER UPDATE ON goals
      FOR EACH ROW
      WHEN NEW.updated_at = OLD.updated_at
      BEGIN
        UPDATE goals SET updated_at = strftime('%s', 'now')
        WHERE id = NEW.id;
      END
    ''');

    // Update plans timestamp trigger
    batch.execute('''
      CREATE TRIGGER update_plan_timestamp
      AFTER UPDATE ON plans
      FOR EACH ROW
      WHEN NEW.updated_at = OLD.updated_at
      BEGIN
        UPDATE plans SET updated_at = strftime('%s', 'now')
        WHERE id = NEW.id;
      END
    ''');

    // Update plan stats on task completion
    batch.execute('''
      CREATE TRIGGER update_plan_stats_on_complete
      AFTER UPDATE ON tasks
      FOR EACH ROW
      WHEN NEW.status = 'completed' AND OLD.status != 'completed'
      BEGIN
        UPDATE plans
        SET completed_task_count = completed_task_count + 1,
            total_task_count = CASE
              WHEN OLD.status = 'active' THEN total_task_count + 1
              ELSE total_task_count
            END,
            completion_rate = CAST(completed_task_count + 1 AS REAL) /
                            (CASE
                              WHEN OLD.status = 'active' THEN total_task_count + 1
                              ELSE CASE WHEN total_task_count > 0 THEN total_task_count ELSE 1 END
                            END)
        WHERE id = NEW.plan_id;
      END
    ''');

    // Update plan stats on task skip
    batch.execute('''
      CREATE TRIGGER update_plan_stats_on_skip
      AFTER UPDATE ON tasks
      FOR EACH ROW
      WHEN NEW.status = 'skipped' AND OLD.status != 'skipped'
      BEGIN
        UPDATE plans
        SET skipped_task_count = skipped_task_count + 1,
            total_task_count = CASE
              WHEN OLD.status = 'active' THEN total_task_count + 1
              ELSE total_task_count
            END,
            completion_rate = CAST(completed_task_count AS REAL) /
                            (CASE
                              WHEN OLD.status = 'active' THEN total_task_count + 1
                              ELSE CASE WHEN total_task_count > 0 THEN total_task_count ELSE 1 END
                            END)
        WHERE id = NEW.plan_id;
      END
    ''');

    // Log task status changes
    batch.execute('''
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
      END
    ''');

    // Note: Task configuration validation (Timer + Evaluation coexistence check)
    // is handled in Dart code (plan_model.dart) to ensure compatibility with
    // older SQLite versions that don't support json_extract (< 3.38.0)
  }

  /// Close database connection
  @override
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Get current timestamp
  static int getCurrentTimestamp() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  /// Convert DateTime to Unix timestamp
  static int dateTimeToTimestamp(DateTime dateTime) {
    return dateTime.millisecondsSinceEpoch ~/ 1000;
  }

  /// Convert Unix timestamp to DateTime
  static DateTime timestampToDateTime(int timestamp) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }
}