import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:myassistant/data/services/task_refresh_service.dart';
import 'package:myassistant/di/providers/service_providers.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';
import 'package:myassistant/core/utils/app_logger.dart';

part 'app_lifecycle_provider.g.dart';

/// App lifecycle manager
///
/// Manages app lifecycle events and triggers appropriate actions:
/// - Refresh tasks when app resumes from background
/// - Start periodic refresh (optional)
/// - Clean up resources when app pauses
@riverpod
class AppLifecycleManager extends _$AppLifecycleManager {
  late TaskRefreshService _refreshService;
  AppLifecycleListener? _lifecycleListener;

  @override
  bool build() {
    _refreshService = ref.watch(taskRefreshServiceProvider);

    // Set up lifecycle listener
    _setupLifecycleListener();

    // Clean up when provider is disposed
    ref.onDispose(() {
      AppLogger.d('Disposing app lifecycle manager', tag: 'AppLifecycleManager');
      _lifecycleListener?.dispose();
      _refreshService.stopPeriodicRefresh();
    });

    return true; // Initialized
  }

  /// Set up app lifecycle listener
  void _setupLifecycleListener() {
    AppLogger.i('Setting up app lifecycle listener', tag: 'AppLifecycleManager');

    _lifecycleListener = AppLifecycleListener(
      // Called when app resumes from background
      onResume: () async {
        AppLogger.i('App resumed from background', tag: 'AppLifecycleManager');
        await _handleAppResume();
      },

      // Called when app goes to background
      onPause: () {
        AppLogger.d('App paused', tag: 'AppLifecycleManager');
        _handleAppPause();
      },

      // Called when app is detached
      onDetach: () {
        AppLogger.d('App detached', tag: 'AppLifecycleManager');
        _refreshService.stopPeriodicRefresh();
      },
    );
  }

  /// Handle app resume - refresh tasks
  Future<void> _handleAppResume() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      AppLogger.d('No user logged in, skipping refresh', tag: 'AppLifecycleManager');
      return;
    }

    try {
      AppLogger.i('Refreshing tasks on app resume...', tag: 'AppLifecycleManager');
      final result = await _refreshService.refreshOnResume(user.id);

      if (result.success) {
        AppLogger.i(
          'Resume refresh completed: ${result.generatedCount} new tasks, ${result.expiredCount} expired',
          tag: 'AppLifecycleManager',
        );
      } else {
        AppLogger.w('Resume refresh failed: ${result.error}', tag: 'AppLifecycleManager');
      }
    } catch (e) {
      AppLogger.e('Error during resume refresh', tag: 'AppLifecycleManager', error: e);
    }
  }

  /// Handle app pause
  void _handleAppPause() {
    // Could save state or prepare for background
    // Currently just logging
    AppLogger.d('App paused, no action needed', tag: 'AppLifecycleManager');
  }

  /// Start periodic background refresh (optional feature)
  ///
  /// Note: For mobile apps, periodic refresh should be used sparingly
  /// to preserve battery life. Consider using this only when app is in foreground.
  void startPeriodicRefresh({Duration interval = const Duration(hours: 1)}) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    AppLogger.i('Starting periodic refresh with interval: $interval', tag: 'AppLifecycleManager');

    _refreshService.startPeriodicRefresh(
      userId: user.id,
      interval: interval,
      onRefresh: (result) {
        if (result.success) {
          AppLogger.d(
            'Periodic refresh: ${result.generatedCount} new, ${result.expiredCount} expired',
            tag: 'AppLifecycleManager',
          );
        } else {
          AppLogger.w('Periodic refresh failed: ${result.error}', tag: 'AppLifecycleManager');
        }
      },
    );
  }

  /// Stop periodic refresh
  void stopPeriodicRefresh() {
    AppLogger.d('Stopping periodic refresh', tag: 'AppLifecycleManager');
    _refreshService.stopPeriodicRefresh();
  }

  /// Force refresh tasks now
  Future<void> refreshNow() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    AppLogger.i('Manual refresh triggered', tag: 'AppLifecycleManager');

    try {
      final result = await _refreshService.refreshAllTasks(user.id);

      if (result.success) {
        AppLogger.i(
          'Manual refresh completed: ${result.generatedCount} new tasks, ${result.expiredCount} expired',
          tag: 'AppLifecycleManager',
        );
      } else {
        AppLogger.w('Manual refresh failed: ${result.error}', tag: 'AppLifecycleManager');
      }
    } catch (e) {
      AppLogger.e('Error during manual refresh', tag: 'AppLifecycleManager', error: e);
    }
  }
}
