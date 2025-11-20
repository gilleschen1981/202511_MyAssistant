/// String constants for i18n
/// This class provides a mapping structure for localized strings
/// Actual translations should be provided through Flutter's intl package
class StringConstants {
  // Priority Labels
  static const String priorityHigh = 'priority_high';
  static const String priorityMedium = 'priority_medium';
  static const String priorityLow = 'priority_low';

  // Goal Status Labels
  static const String goalStatusInProgress = 'goal_status_in_progress';
  static const String goalStatusPaused = 'goal_status_paused';
  static const String goalStatusCompleted = 'goal_status_completed';
  static const String goalStatusDeleted = 'goal_status_deleted';

  // Task Status Labels
  static const String taskStatusActive = 'task_status_active';
  static const String taskStatusCompleted = 'task_status_completed';
  static const String taskStatusSkipped = 'task_status_skipped';
  static const String taskStatusDeleted = 'task_status_deleted';

  // User Status Labels
  static const String userStatusActive = 'user_status_active';
  static const String userStatusDeactivated = 'user_status_deactivated';

  // Task Type Labels
  static const String taskTypeTimer = 'task_type_timer';
  static const String taskTypeCounter = 'task_type_counter';
  static const String taskTypeEvaluation = 'task_type_evaluation';
  static const String taskTypeTimerWithCount = 'task_type_timer_with_count';
  static const String taskTypeCounterWithEval = 'task_type_counter_with_eval';
  static const String taskTypeSimple = 'task_type_simple';

  // Repeat Type Labels
  static const String repeatTypeOneTime = 'repeat_type_one_time';
  static const String repeatTypeDaily = 'repeat_type_daily';
  static const String repeatTypeWeekly = 'repeat_type_weekly';
  static const String repeatTypeMonthly = 'repeat_type_monthly';
  static const String repeatTypeCustom = 'repeat_type_custom';

  // Theme Mode Labels
  static const String themeModeLight = 'theme_mode_light';
  static const String themeModeDark = 'theme_mode_dark';
  static const String themeModeSystem = 'theme_mode_system';

  // Common Actions
  static const String actionAdd = 'action_add';
  static const String actionEdit = 'action_edit';
  static const String actionDelete = 'action_delete';
  static const String actionSave = 'action_save';
  static const String actionCancel = 'action_cancel';
  static const String actionConfirm = 'action_confirm';
  static const String actionComplete = 'action_complete';
  static const String actionSkip = 'action_skip';
  static const String actionStart = 'action_start';
  static const String actionPause = 'action_pause';
  static const String actionResume = 'action_resume';
  static const String actionStop = 'action_stop';

  // Common Labels
  static const String labelGoal = 'label_goal';
  static const String labelPlan = 'label_plan';
  static const String labelTask = 'label_task';
  static const String labelDescription = 'label_description';
  static const String labelStartDate = 'label_start_date';
  static const String labelEndDate = 'label_end_date';
  static const String labelDeadline = 'label_deadline';
  static const String labelPriority = 'label_priority';
  static const String labelStatus = 'label_status';
  static const String labelProgress = 'label_progress';
  static const String labelSettings = 'label_settings';
  static const String labelProfile = 'label_profile';

  // Messages
  static const String messageLoading = 'message_loading';
  static const String messageNoData = 'message_no_data';
  static const String messageError = 'message_error';
  static const String messageSuccess = 'message_success';
  static const String messageConfirmDelete = 'message_confirm_delete';

  // Validation Messages
  static const String validationRequired = 'validation_required';
  static const String validationInvalidEmail = 'validation_invalid_email';
  static const String validationPasswordTooShort = 'validation_password_too_short';
  static const String validationDateRangeInvalid = 'validation_date_range_invalid';
}