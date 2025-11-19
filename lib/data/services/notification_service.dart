import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';

/// Notification service for task reminders and alerts
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialize
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Parse payload to determine action
    final payload = response.payload;
    if (payload != null) {
      // Navigate to appropriate screen based on payload
      // This will be handled by the navigation service
      // TODO: Implement navigation based on payload
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    // Android 13+ requires runtime permission
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    // iOS permission
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Show notification
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationDetails? details,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    details ??= const NotificationDetails(
      android: AndroidNotificationDetails(
        'task_channel',
        'Task Notifications',
        channelDescription: 'Notifications for task reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// Schedule notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    NotificationDetails? details,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    details ??= const NotificationDetails(
      android: AndroidNotificationDetails(
        'task_channel',
        'Task Notifications',
        channelDescription: 'Notifications for task reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    // Convert DateTime to TZDateTime for scheduling
    final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(scheduledDate, tz.local);

    // Use timezone-aware scheduling
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledTZDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Notify new tasks
  Future<void> notifyNewTasks(List<TaskModel> tasks) async {
    if (tasks.isEmpty) return;

    final count = tasks.length;
    final title = count == 1 ? 'New Task Available' : '$count New Tasks Available';

    final body = count == 1
        ? 'You have a new task: ${tasks.first.name}'
        : 'You have $count new tasks to complete';

    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: 'new_tasks',
    );
  }

  /// Notify task completed
  Future<void> notifyTaskCompleted(TaskModel task) async {
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Task Completed!',
      body: 'Great job! You completed: ${task.name}',
      payload: 'task_completed:${task.id}',
    );
  }

  /// Notify task skipped
  Future<void> notifyTaskSkipped(TaskModel task) async {
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Task Skipped',
      body: 'Task "${task.name}" has been skipped',
      payload: 'task_skipped:${task.id}',
    );
  }

  /// Schedule task reminder
  Future<void> scheduleTaskReminder({
    required TaskModel task,
    required DateTime reminderTime,
  }) async {
    await _scheduleNotification(
      id: task.id.hashCode,
      title: 'Task Reminder',
      body: 'Don\'t forget to complete: ${task.name}',
      scheduledDate: reminderTime,
      payload: 'task_reminder:${task.id}',
    );
  }

  /// Schedule daily reminder for tasks
  Future<void> scheduleDailyReminder({
    required DateTime time,
    required String userId,
  }) async {
    // Schedule a daily notification at specified time
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder',
        'Daily Reminders',
        channelDescription: 'Daily task reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.periodicallyShow(
      0, // Fixed ID for daily reminder
      'Daily Task Reminder',
      'Check your tasks for today',
      RepeatInterval.daily,
      details,
      payload: 'daily_reminder:$userId',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancel notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Show task progress notification
  Future<void> showProgressNotification({
    required int progress,
    required int total,
  }) async {
    final percentage = ((progress / total) * 100).round();

    await _showNotification(
      id: 999, // Fixed ID for progress notification
      title: 'Daily Progress',
      body: '$progress of $total tasks completed ($percentage%)',
      payload: 'progress',
      details: NotificationDetails(
        android: AndroidNotificationDetails(
          'progress_channel',
          'Progress Notifications',
          channelDescription: 'Task progress updates',
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: total,
          progress: progress,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Notify plan ending soon
  Future<void> notifyPlanEndingSoon(PlanModel plan, int daysRemaining) async {
    await _showNotification(
      id: plan.id.hashCode,
      title: 'Plan Ending Soon',
      body: '${plan.name} will end in $daysRemaining days',
      payload: 'plan_ending:${plan.id}',
    );
  }

  /// Notify goal deadline approaching
  Future<void> notifyGoalDeadline({
    required String goalTitle,
    required int daysRemaining,
  }) async {
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Goal Deadline Approaching',
      body: '$goalTitle deadline in $daysRemaining days',
      payload: 'goal_deadline',
    );
  }
}