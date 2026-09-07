// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_list_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$todayTasksHash() => r'c87c97205cd76f5e565709dee19d8eb1b927d510';

/// Computed providers for specific task lists
///
/// Copied from [todayTasks].
@ProviderFor(todayTasks)
final todayTasksProvider = AutoDisposeProvider<List<TaskModel>>.internal(
  todayTasks,
  name: r'todayTasksProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$todayTasksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TodayTasksRef = AutoDisposeProviderRef<List<TaskModel>>;
String _$activeTasksHash() => r'2d2cefeefe5d9d7dd5b650c2f78fd9d65e65ef66';

/// See also [activeTasks].
@ProviderFor(activeTasks)
final activeTasksProvider = AutoDisposeProvider<List<TaskModel>>.internal(
  activeTasks,
  name: r'activeTasksProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeTasksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveTasksRef = AutoDisposeProviderRef<List<TaskModel>>;
String _$completedTasksHash() => r'5132092c5d9f4b8d9a548d01d986402d57fb7ffd';

/// See also [completedTasks].
@ProviderFor(completedTasks)
final completedTasksProvider = AutoDisposeProvider<List<TaskModel>>.internal(
  completedTasks,
  name: r'completedTasksProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$completedTasksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CompletedTasksRef = AutoDisposeProviderRef<List<TaskModel>>;
String _$activeSessionsHash() => r'fddd52530f42866caacb00e7bb7ec770bd444550';

/// See also [activeSessions].
@ProviderFor(activeSessions)
final activeSessionsProvider =
    AutoDisposeProvider<Map<String, TimerSession>>.internal(
      activeSessions,
      name: r'activeSessionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$activeSessionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveSessionsRef = AutoDisposeProviderRef<Map<String, TimerSession>>;
String _$isMakeUpModeHash() => r'06f0a14f0c9306264cb93b7af42d519e1f1fc6c8';

/// See also [isMakeUpMode].
@ProviderFor(isMakeUpMode)
final isMakeUpModeProvider = AutoDisposeProvider<bool>.internal(
  isMakeUpMode,
  name: r'isMakeUpModeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isMakeUpModeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsMakeUpModeRef = AutoDisposeProviderRef<bool>;
String _$makeUpTasksHash() => r'dfe461b88e9c071aea6385cc9c636376f535ee52';

/// See also [makeUpTasks].
@ProviderFor(makeUpTasks)
final makeUpTasksProvider = AutoDisposeProvider<List<TaskModel>>.internal(
  makeUpTasks,
  name: r'makeUpTasksProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$makeUpTasksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MakeUpTasksRef = AutoDisposeProviderRef<List<TaskModel>>;
String _$taskStatisticsHash() => r'c15023c4e44b76222980d0646b71cfef3dbe4dbc';

/// Task statistics provider
///
/// Copied from [taskStatistics].
@ProviderFor(taskStatistics)
final taskStatisticsProvider =
    AutoDisposeFutureProvider<TaskStatistics>.internal(
      taskStatistics,
      name: r'taskStatisticsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$taskStatisticsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TaskStatisticsRef = AutoDisposeFutureProviderRef<TaskStatistics>;
String _$taskListNotifierHash() => r'5d2412dd1a711f8870feaa64cbf1e8c2101c922a';

/// Task list notifier using modern AsyncNotifier pattern
///
/// Copied from [TaskListNotifier].
@ProviderFor(TaskListNotifier)
final taskListNotifierProvider =
    AutoDisposeAsyncNotifierProvider<TaskListNotifier, TaskListState>.internal(
      TaskListNotifier.new,
      name: r'taskListNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$taskListNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TaskListNotifier = AutoDisposeAsyncNotifier<TaskListState>;
String _$selectedTaskHash() => r'd3601d0a86bd56025df90ae52dbcd65c8144a6cc';

/// Selected task provider
///
/// Copied from [SelectedTask].
@ProviderFor(SelectedTask)
final selectedTaskProvider =
    AutoDisposeNotifierProvider<SelectedTask, TaskModel?>.internal(
      SelectedTask.new,
      name: r'selectedTaskProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$selectedTaskHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedTask = AutoDisposeNotifier<TaskModel?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
