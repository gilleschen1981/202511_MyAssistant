# MyAssistant API Documentation

This document provides comprehensive API documentation for the MyAssistant application, covering services, repositories, providers, and data models.

## Table of Contents
- [Data Models](#data-models)
- [Services](#services)
- [Repositories](#repositories)
- [Providers](#providers)
- [Database Operations](#database-operations)

## Data Models

### UserModel
Represents a user account in the system.

```dart
class UserModel {
  final String id;           // Unique identifier
  final String username;      // Unique username
  final String email;         // Email address
  final String passwordHash;  // Hashed password
  final String? displayName;  // Optional display name
  final String? avatarUrl;    // Profile picture URL
  final DateTime createdAt;   // Account creation time
  final DateTime updatedAt;   // Last update time
  final UserStatus status;    // Active/Deactivated

  // Statistics
  final int totalGoals;
  final int completedGoals;
  final int activePlans;
  final int completedTasks;
}

enum UserStatus {
  active,
  deactivated,
  suspended
}
```

### GoalModel
Represents a user's goal.

```dart
class GoalModel {
  final String id;           // UUID
  final String userId;       // Owner's ID
  final String title;        // Goal title
  final String? description; // Optional description
  final DateTime deadline;   // Target completion date
  final List<String> tags;   // Categorization tags
  final GoalStatus status;   // Current status
  final DateTime createdAt;  // Creation time
  final DateTime? completedAt; // Completion time
  final bool isDeleted;      // Soft delete flag
}

enum GoalStatus {
  active,
  completed,
  archived,
  failed
}
```

### PlanModel
Represents an action plan for achieving a goal.

```dart
class PlanModel {
  final String id;              // UUID (immutable)
  final String userId;          // Owner's ID
  final String goalId;          // Associated goal
  final String name;            // Plan name (immutable)
  final String? description;    // Optional description
  final DateTime startDate;     // Plan start date
  final DateTime endDate;       // Plan end date
  final RepeatRule repeatRule;  // Recurrence configuration
  final List<TaskConfiguration> taskConfigs; // Task templates
  final PlanStatus status;      // Current status
  final DateTime createdAt;     // Creation time
  final bool isDeleted;         // Soft delete flag
}

class RepeatRule {
  final RepeatType type;         // daily/weekly/monthly
  final List<int>? weekdays;     // For weekly (1-7)
  final List<int>? monthDays;    // For monthly (1-31)
  final TimeOfDay? startTime;    // Daily start time
  final TimeOfDay? endTime;      // Daily end time
}

enum RepeatType {
  daily,
  weekly,
  monthly,
  custom
}

enum PlanStatus {
  draft,
  active,
  paused,
  completed,
  archived
}
```

### TaskModel
Represents an individual task instance.

```dart
class TaskModel {
  final String id;                    // Unique identifier
  final String userId;                // Owner's ID
  final String planId;                // Parent plan ID
  final String name;                  // Task name
  final String? description;          // Optional description
  final TaskConfiguration config;     // Execution configuration
  final DateTime windowStartTime;     // Execution window start
  final DateTime windowEndTime;       // Execution window end
  final TaskStatus status;            // Current status
  final int currentCount;             // Progress counter
  final DateTime createdAt;           // Creation time
  final DateTime? completedAt;        // Completion time
  final String? skipReason;           // If skipped
  final String? originalTaskId;       // For repeat executions
  final int repeatExecutionCount;     // Repeat counter

  // Computed properties
  bool get isExpired => DateTime.now().isAfter(windowEndTime);
  bool get canExecute => status == TaskStatus.active && !isExpired;
  bool get canRepeat => status == TaskStatus.completed && !isExpired;
  double get progress; // 0.0 to 1.0
}

class TaskConfiguration {
  final int? durationMinutes;        // Timer duration
  final int? repeatCount;            // Counter target
  final List<String>? evaluationOptions; // Evaluation choices

  TaskType get taskType {
    // Logic to determine task type
    // simple, timer, counter, evaluation,
    // timerWithCount, counterWithEval
  }
}

enum TaskStatus {
  active,
  completed,
  skipped,
  expired
}

enum TaskType {
  simple,           // Basic checkbox
  timer,            // Time-based
  counter,          // Count-based
  evaluation,       // Quality assessment
  timerWithCount,   // Combined timer+counter
  counterWithEval   // Combined counter+evaluation
}
```

## Services

### AuthenticationService
Handles user authentication and session management.

```dart
class AuthenticationService {
  /// Signs in a user with email and password
  /// Returns authenticated UserModel
  /// Throws AuthException on failure
  Future<UserModel> signIn({
    required String email,
    required String password,
  });

  /// Registers a new user
  /// Returns created UserModel
  /// Throws AuthException if user exists
  Future<UserModel> signUp({
    required String username,
    required String email,
    required String password,
    String? displayName,
  });

  /// Signs out current user
  /// Clears session data
  Future<void> signOut();

  /// Gets current authenticated user
  /// Returns null if not authenticated
  Future<UserModel?> getCurrentUser();

  /// Updates user password
  /// Requires current password for verification
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Checks if user is authenticated
  /// Returns true if valid session exists
  Future<bool> isAuthenticated();

  /// Refreshes authentication token
  /// Extends session validity
  Future<void> refreshToken();
}
```

### GoalService
Manages goal-related operations.

```dart
class GoalService {
  /// Creates a new goal
  Future<GoalModel> createGoal({
    required String userId,
    required String title,
    String? description,
    required DateTime deadline,
    List<String>? tags,
  });

  /// Updates existing goal
  Future<GoalModel> updateGoal({
    required String goalId,
    String? title,
    String? description,
    DateTime? deadline,
    List<String>? tags,
    GoalStatus? status,
  });

  /// Marks goal as completed
  Future<void> completeGoal(String goalId);

  /// Archives a goal (soft delete)
  Future<void> archiveGoal(String goalId);

  /// Gets user's goals
  Future<List<GoalModel>> getUserGoals({
    required String userId,
    GoalStatus? status,
    bool includeDeleted = false,
  });

  /// Gets goal by ID
  Future<GoalModel?> getGoalById(String goalId);

  /// Calculates goal progress
  Future<double> calculateGoalProgress(String goalId);
}
```

### PlanService
Handles plan creation and management.

```dart
class PlanService {
  /// Creates a new plan
  /// Note: Plan name is immutable after creation
  Future<PlanModel> createPlan({
    required String userId,
    required String goalId,
    required String name, // Immutable
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    required RepeatRule repeatRule,
    required List<TaskConfiguration> taskConfigs,
  });

  /// Updates plan (name cannot be changed)
  Future<PlanModel> updatePlan({
    required String planId,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    RepeatRule? repeatRule,
    PlanStatus? status,
  });

  /// Generates tasks for a plan
  /// Creates task instances based on plan configuration
  Future<List<TaskModel>> generateTasks({
    required String planId,
    required DateTime date,
  });

  /// Gets plans for a goal
  Future<List<PlanModel>> getPlansForGoal(String goalId);

  /// Activates a plan
  Future<void> activatePlan(String planId);

  /// Pauses a plan
  Future<void> pausePlan(String planId);

  /// Archives a plan (soft delete)
  Future<void> archivePlan(String planId);
}
```

### TaskService
Manages task execution and tracking.

```dart
class TaskService {
  /// Gets tasks for today
  Future<List<TaskModel>> getTodayTasks({
    required String userId,
    TaskStatus? status,
  });

  /// Gets tasks for a specific date
  Future<List<TaskModel>> getTasksForDate({
    required String userId,
    required DateTime date,
    TaskStatus? status,
  });

  /// Completes a task
  /// Note: Tasks cannot be deleted
  Future<TaskModel> completeTask({
    required String taskId,
    Map<String, dynamic>? executionData,
  });

  /// Skips a task with reason
  Future<void> skipTask({
    required String taskId,
    String? reason,
  });

  /// Creates repeat execution of completed task
  /// Tasks can be repeated unlimited times within window
  Future<TaskModel> repeatTask({
    required String originalTaskId,
  });

  /// Updates task progress (for counter tasks)
  Future<void> updateTaskProgress({
    required String taskId,
    required int currentCount,
  });

  /// Records task execution data
  Future<void> recordExecution({
    required String taskId,
    required Map<String, dynamic> data,
    required DateTime timestamp,
  });

  /// Gets task statistics
  Future<TaskStatistics> getTaskStatistics({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  });
}

class TaskStatistics {
  final int totalTasks;
  final int completedTasks;
  final int skippedTasks;
  final double completionRate;
  final Map<TaskType, int> tasksByType;
  final Duration totalTimeSpent;
}
```

### NotificationService
Handles local notifications for reminders.

```dart
class NotificationService {
  /// Initializes notification service
  Future<void> initialize();

  /// Requests notification permissions
  Future<bool> requestPermissions();

  /// Schedules task reminder
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskName,
    required DateTime scheduledTime,
  });

  /// Cancels scheduled notification
  Future<void> cancelNotification(String taskId);

  /// Shows immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  });

  /// Updates notification settings
  Future<void> updateSettings({
    bool? enabledForTasks,
    bool? enabledForGoals,
    TimeOfDay? defaultReminderTime,
  });

  /// Gets notification settings
  Future<NotificationSettings> getSettings();
}
```

## Repositories

### UserRepository
Data access layer for user operations.

```dart
abstract class UserRepository {
  Future<UserModel?> getUserById(String id);
  Future<UserModel?> getUserByEmail(String email);
  Future<UserModel> createUser(UserModel user);
  Future<UserModel> updateUser(UserModel user);
  Future<void> deleteUser(String id);
  Future<bool> checkUsernameExists(String username);
}
```

### GoalRepository
Data access layer for goal operations.

```dart
abstract class GoalRepository {
  Future<GoalModel> createGoal(GoalModel goal);
  Future<GoalModel> updateGoal(GoalModel goal);
  Future<void> deleteGoal(String id); // Soft delete
  Future<GoalModel?> getGoalById(String id);
  Future<List<GoalModel>> getUserGoals(String userId);
  Future<List<GoalModel>> getActiveGoals(String userId);
}
```

### PlanRepository
Data access layer for plan operations.

```dart
abstract class PlanRepository {
  Future<PlanModel> createPlan(PlanModel plan);
  Future<PlanModel> updatePlan(PlanModel plan);
  Future<void> deletePlan(String id); // Soft delete
  Future<PlanModel?> getPlanById(String id);
  Future<List<PlanModel>> getPlansForGoal(String goalId);
  Future<List<PlanModel>> getActivePlans(String userId);
  Future<bool> checkPlanNameExists(String name, String userId);
}
```

### TaskRepository
Data access layer for task operations.

```dart
abstract class TaskRepository {
  Future<TaskModel> createTask(TaskModel task);
  Future<TaskModel> updateTask(TaskModel task);
  // Note: No deleteTask - tasks cannot be deleted
  Future<TaskModel?> getTaskById(String id);
  Future<List<TaskModel>> getTasksForPlan(String planId);
  Future<List<TaskModel>> getTasksInTimeRange({
    required String userId,
    required DateTime start,
    required DateTime end,
  });
}
```

## Providers

### Authentication Providers

```dart
// Current user provider
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges();
});

// Auth state provider
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ref);
});

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
}
```

### Task Management Providers

```dart
// Today's tasks provider
final todayTasksProvider = FutureProvider<List<TaskModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return [];

  final taskService = ref.watch(taskServiceProvider);
  return taskService.getTodayTasks(userId: user.id);
});

// Task list state provider
final taskListProvider = StateNotifierProvider<TaskListNotifier, TaskListState>((ref) {
  return TaskListNotifier(ref);
});

class TaskListState {
  final List<TaskModel> todayTasks;
  final List<TaskModel> activeTasks;
  final List<TaskModel> completedTasks;
  final bool isLoading;
  final String? error;
}
```

### Goal Management Providers

```dart
// User goals provider
final goalsProvider = FutureProvider.family<List<GoalModel>, String>((ref, userId) {
  final goalService = ref.watch(goalServiceProvider);
  return goalService.getUserGoals(userId: userId);
});

// Goal list state provider
final goalListProvider = StateNotifierProvider<GoalListNotifier, GoalListState>((ref) {
  return GoalListNotifier(ref);
});
```

### Plan Management Providers

```dart
// Active plans provider
final activePlansProvider = FutureProvider<List<PlanModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return [];

  final planService = ref.watch(planServiceProvider);
  return planService.getActivePlans(user.id);
});

// Plan list state provider
final planListProvider = StateNotifierProvider<PlanListNotifier, PlanListState>((ref) {
  return PlanListNotifier(ref);
});
```

## Database Operations

### Database Schema

```sql
-- Users table
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  status TEXT NOT NULL
);

-- Goals table
CREATE TABLE goals (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  deadline TEXT NOT NULL,
  tags TEXT, -- JSON array
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  completed_at TEXT,
  is_deleted INTEGER DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users (id)
);

-- Plans table (name is immutable)
CREATE TABLE plans (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  goal_id TEXT NOT NULL,
  name TEXT NOT NULL, -- Immutable, unique per user
  description TEXT,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  repeat_rule TEXT NOT NULL, -- JSON object
  task_configs TEXT NOT NULL, -- JSON array
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  is_deleted INTEGER DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users (id),
  FOREIGN KEY (goal_id) REFERENCES goals (id),
  UNIQUE (user_id, name) -- Ensure unique plan names per user
);

-- Tasks table (no deletion support)
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  plan_id TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  config TEXT NOT NULL, -- JSON object
  window_start_time TEXT NOT NULL,
  window_end_time TEXT NOT NULL,
  status TEXT NOT NULL,
  current_count INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  completed_at TEXT,
  skip_reason TEXT,
  original_task_id TEXT, -- For repeat executions
  repeat_execution_count INTEGER DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users (id),
  FOREIGN KEY (plan_id) REFERENCES plans (id)
);

-- Task executions table
CREATE TABLE task_executions (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL,
  execution_data TEXT, -- JSON object
  timestamp TEXT NOT NULL,
  FOREIGN KEY (task_id) REFERENCES tasks (id)
);
```

### Database Helper

```dart
class DatabaseHelper {
  static const String _databaseName = 'myassistant.db';
  static const int _databaseVersion = 1;

  Future<Database> get database async {
    return await openDatabase(
      _databaseName,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create tables
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle migrations
  }
}
```

## Error Handling

### Custom Exceptions

```dart
class AuthException implements Exception {
  final String message;
  final String? code;
  AuthException(this.message, {this.code});
}

class ValidationException implements Exception {
  final String field;
  final String message;
  ValidationException(this.field, this.message);
}

class DatabaseException implements Exception {
  final String message;
  final String? query;
  DatabaseException(this.message, {this.query});
}

class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  NetworkException(this.message, {this.statusCode});
}
```

### Error Codes

```dart
class ErrorCodes {
  static const String authFailed = 'AUTH_FAILED';
  static const String userNotFound = 'USER_NOT_FOUND';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String sessionExpired = 'SESSION_EXPIRED';
  static const String planNameExists = 'PLAN_NAME_EXISTS';
  static const String taskExpired = 'TASK_EXPIRED';
  static const String databaseError = 'DATABASE_ERROR';
  static const String networkError = 'NETWORK_ERROR';
}
```

## Rate Limiting

API operations implement rate limiting:

```dart
class RateLimiter {
  static const Map<String, int> limits = {
    'auth.signIn': 5,        // 5 attempts per minute
    'auth.signUp': 3,        // 3 attempts per minute
    'task.complete': 100,    // 100 per minute
    'notification.send': 10, // 10 per minute
  };
}
```

## Versioning

API versioning strategy:
- Current version: v1
- Backward compatibility maintained for 2 versions
- Deprecation notices provided 30 days in advance
- Version specified in request headers

```dart
const String apiVersion = 'v1';
const String minSupportedVersion = 'v1';
```

## Response Formats

### Success Response
```json
{
  "success": true,
  "data": {
    // Response data
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### Error Response
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Error description",
    "field": "field_name" // Optional
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### Pagination Response
```json
{
  "success": true,
  "data": {
    "items": [],
    "total": 100,
    "page": 1,
    "pageSize": 20,
    "hasNext": true,
    "hasPrevious": false
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```