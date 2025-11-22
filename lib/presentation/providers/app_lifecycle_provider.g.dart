// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_lifecycle_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appLifecycleManagerHash() =>
    r'33f0409b84fb93f0303fa16f90173e348b162a69';

/// App lifecycle manager
///
/// Manages app lifecycle events and triggers appropriate actions:
/// - Refresh tasks when app resumes from background
/// - Start periodic refresh (optional)
/// - Clean up resources when app pauses
///
/// Copied from [AppLifecycleManager].
@ProviderFor(AppLifecycleManager)
final appLifecycleManagerProvider =
    AutoDisposeNotifierProvider<AppLifecycleManager, bool>.internal(
      AppLifecycleManager.new,
      name: r'appLifecycleManagerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$appLifecycleManagerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AppLifecycleManager = AutoDisposeNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
