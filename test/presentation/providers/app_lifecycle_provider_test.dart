import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/presentation/providers/app_lifecycle_provider.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';
import 'package:myassistant/data/services/task_refresh_service.dart';
import 'package:myassistant/data/models/user_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/di/providers/service_providers.dart';

import 'app_lifecycle_provider_test.mocks.dart';

@GenerateMocks([TaskRefreshService])
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late MockTaskRefreshService mockRefreshService;
  late ProviderContainer container;

  setUp(() {
    mockRefreshService = MockTaskRefreshService();
  });

  tearDown(() {
    container.dispose();
    // Reset lifecycle state back to resumed for subsequent tests.
    // After container.dispose(), the lifecycle listener is removed,
    // so these calls only update the binding's internal state.
    final currentState = binding.lifecycleState;
    if (currentState != null && currentState != AppLifecycleState.resumed) {
      // Walk through valid transitions back to resumed
      if (currentState == AppLifecycleState.detached) {
        // ignore: invalid_use_of_protected_member
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      } else {
        if (currentState == AppLifecycleState.paused) {
          // ignore: invalid_use_of_protected_member
          binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        }
        if (currentState == AppLifecycleState.paused ||
            currentState == AppLifecycleState.hidden) {
          // ignore: invalid_use_of_protected_member
          binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        }
        // ignore: invalid_use_of_protected_member
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
    }
  });

  /// Helper to create a test user
  UserModel createTestUser({String id = 'test-user-123'}) {
    final now = DateTime.now();
    return UserModel(
      id: id,
      username: 'testuser',
      email: 'test@example.com',
      passwordHash: 'test-hash',
      status: UserStatus.active,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Helper to create container with a logged-in user
  ProviderContainer createContainerWithUser() {
    final testUser = createTestUser();
    return ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => testUser),
        taskRefreshServiceProvider.overrideWith((ref) => mockRefreshService),
      ],
    );
  }

  /// Helper to create container with no logged-in user
  ProviderContainer createContainerWithoutUser() {
    return ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => null),
        taskRefreshServiceProvider.overrideWith((ref) => mockRefreshService),
      ],
    );
  }

  group('AppLifecycleManager - Initialization', () {
    test('build should return true when initialized', () {
      container = createContainerWithUser();

      final result = container.read(appLifecycleManagerProvider);

      expect(result, isTrue);
    });

    test('build should return true even without a logged-in user', () {
      container = createContainerWithoutUser();

      final result = container.read(appLifecycleManagerProvider);

      expect(result, isTrue);
    });
  });

  group('AppLifecycleManager - refreshNow', () {
    test('should call refreshAllTasks when user is logged in', () async {
      final refreshResult = RefreshResult()
        ..success = true
        ..generatedCount = 2
        ..expiredCount = 1;

      when(mockRefreshService.refreshAllTasks('test-user-123'))
          .thenAnswer((_) async => refreshResult);

      container = createContainerWithUser();
      container.read(appLifecycleManagerProvider);

      await container
          .read(appLifecycleManagerProvider.notifier)
          .refreshNow();

      verify(mockRefreshService.refreshAllTasks('test-user-123')).called(1);
    });

    test('should not call refreshAllTasks when no user is logged in', () async {
      container = createContainerWithoutUser();
      container.read(appLifecycleManagerProvider);

      await container
          .read(appLifecycleManagerProvider.notifier)
          .refreshNow();

      verifyNever(mockRefreshService.refreshAllTasks(any));
    });

    test('should handle exception without rethrowing', () async {
      when(mockRefreshService.refreshAllTasks('test-user-123'))
          .thenThrow(Exception('Network error'));

      container = createContainerWithUser();
      container.read(appLifecycleManagerProvider);

      // Should complete without throwing
      await container
          .read(appLifecycleManagerProvider.notifier)
          .refreshNow();

      verify(mockRefreshService.refreshAllTasks('test-user-123')).called(1);
    });

    test('should handle failed RefreshResult without throwing', () async {
      final refreshResult = RefreshResult()
        ..success = false
        ..error = 'Database error';

      when(mockRefreshService.refreshAllTasks('test-user-123'))
          .thenAnswer((_) async => refreshResult);

      container = createContainerWithUser();
      container.read(appLifecycleManagerProvider);

      await container
          .read(appLifecycleManagerProvider.notifier)
          .refreshNow();

      verify(mockRefreshService.refreshAllTasks('test-user-123')).called(1);
    });
  });

  group('AppLifecycleManager - startPeriodicRefresh', () {
    test('should call service startPeriodicRefresh when user is logged in',
        () {
      container = createContainerWithUser();
      container.read(appLifecycleManagerProvider);

      container
          .read(appLifecycleManagerProvider.notifier)
          .startPeriodicRefresh(interval: const Duration(minutes: 30));

      verify(mockRefreshService.startPeriodicRefresh(
        userId: 'test-user-123',
        interval: const Duration(minutes: 30),
        onRefresh: anyNamed('onRefresh'),
      )).called(1);
    });

    test('should use default interval of 1 hour', () {
      container = createContainerWithUser();
      container.read(appLifecycleManagerProvider);

      container
          .read(appLifecycleManagerProvider.notifier)
          .startPeriodicRefresh();

      verify(mockRefreshService.startPeriodicRefresh(
        userId: 'test-user-123',
        interval: const Duration(hours: 1),
        onRefresh: anyNamed('onRefresh'),
      )).called(1);
    });

    test('should not call service when no user is logged in', () {
      container = createContainerWithoutUser();
      container.read(appLifecycleManagerProvider);

      container
          .read(appLifecycleManagerProvider.notifier)
          .startPeriodicRefresh();

      verifyNever(mockRefreshService.startPeriodicRefresh(
        userId: anyNamed('userId'),
        interval: anyNamed('interval'),
        onRefresh: anyNamed('onRefresh'),
      ));
    });
  });

  group('AppLifecycleManager - stopPeriodicRefresh', () {
    test('should call service stopPeriodicRefresh', () {
      container = createContainerWithUser();
      container.read(appLifecycleManagerProvider);

      container
          .read(appLifecycleManagerProvider.notifier)
          .stopPeriodicRefresh();

      verify(mockRefreshService.stopPeriodicRefresh()).called(1);
    });
  });

  group('AppLifecycleManager - Dispose cleanup', () {
    test('should stop periodic refresh when provider is disposed', () {
      // Use a local container so tearDown does not double-dispose
      final localContainer = createContainerWithUser();
      localContainer.read(appLifecycleManagerProvider);

      // Clear any interactions from build
      clearInteractions(mockRefreshService);

      // Dispose triggers onDispose callback
      localContainer.dispose();

      verify(mockRefreshService.stopPeriodicRefresh()).called(1);

      // Assign a fresh container for tearDown
      container = ProviderContainer();
    });
  });

  group('AppLifecycleManager - Lifecycle onResume', () {
    test('should call refreshOnResume when user is logged in', () async {
      final refreshResult = RefreshResult()
        ..success = true
        ..generatedCount = 1
        ..expiredCount = 0;

      when(mockRefreshService.refreshOnResume('test-user-123'))
          .thenAnswer((_) async => refreshResult);

      container = createContainerWithUser();
      container.read(appLifecycleManagerProvider);

      // Simulate app going to background following valid lifecycle transitions:
      // resumed -> inactive -> hidden -> paused
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      // Simulate app resuming: paused -> hidden -> inactive -> resumed
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      // Allow the async callback to complete
      await Future<void>.delayed(Duration.zero);

      verify(mockRefreshService.refreshOnResume('test-user-123')).called(1);
    });

    test('should not call refreshOnResume when no user is logged in',
        () async {
      container = createContainerWithoutUser();
      container.read(appLifecycleManagerProvider);

      // Go to background
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      // Resume
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await Future<void>.delayed(Duration.zero);

      verifyNever(mockRefreshService.refreshOnResume(any));
    });

    test('should handle exception in onResume gracefully', () async {
      when(mockRefreshService.refreshOnResume('test-user-123'))
          .thenThrow(Exception('Refresh failed'));

      container = createContainerWithUser();
      container.read(appLifecycleManagerProvider);

      // Go to background
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      // Resume - should not throw even when the service throws
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await Future<void>.delayed(Duration.zero);

      verify(mockRefreshService.refreshOnResume('test-user-123')).called(1);
    });

    test('should handle failed RefreshResult on resume', () async {
      final refreshResult = RefreshResult()
        ..success = false
        ..error = 'Some error occurred';

      when(mockRefreshService.refreshOnResume('test-user-123'))
          .thenAnswer((_) async => refreshResult);

      container = createContainerWithUser();
      container.read(appLifecycleManagerProvider);

      // Go to background
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      // Resume
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await Future<void>.delayed(Duration.zero);

      verify(mockRefreshService.refreshOnResume('test-user-123')).called(1);
    });
  });

  group('AppLifecycleManager - Lifecycle onPause', () {
    test('should not interact with refresh service on pause', () {
      container = createContainerWithUser();
      container.read(appLifecycleManagerProvider);

      // Clear any interactions from build
      clearInteractions(mockRefreshService);

      // Simulate pause with valid transitions: resumed -> inactive -> hidden -> paused
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      // _handleAppPause only logs, should not call any service methods
      verifyZeroInteractions(mockRefreshService);
    });
  });

  group('AppLifecycleManager - Lifecycle onDetach', () {
    test('should stop periodic refresh on detach', () {
      container = createContainerWithUser();
      container.read(appLifecycleManagerProvider);

      // Clear any interactions from build
      clearInteractions(mockRefreshService);

      // Simulate going to background then detach:
      // resumed -> inactive -> hidden -> paused -> detached
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      // ignore: invalid_use_of_protected_member
      binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);

      verify(mockRefreshService.stopPeriodicRefresh()).called(1);
    });
  });
}
