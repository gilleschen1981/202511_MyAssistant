// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_list_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$TaskListState {
  List<TaskModel> get allTasks => throw _privateConstructorUsedError;
  List<TaskModel> get todayTasks => throw _privateConstructorUsedError;
  List<TaskModel> get activeTasks => throw _privateConstructorUsedError;
  List<TaskModel> get completedTasks => throw _privateConstructorUsedError;
  Map<String, TimerSession> get activeSessions =>
      throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of TaskListState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskListStateCopyWith<TaskListState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskListStateCopyWith<$Res> {
  factory $TaskListStateCopyWith(
    TaskListState value,
    $Res Function(TaskListState) then,
  ) = _$TaskListStateCopyWithImpl<$Res, TaskListState>;
  @useResult
  $Res call({
    List<TaskModel> allTasks,
    List<TaskModel> todayTasks,
    List<TaskModel> activeTasks,
    List<TaskModel> completedTasks,
    Map<String, TimerSession> activeSessions,
    String? error,
  });
}

/// @nodoc
class _$TaskListStateCopyWithImpl<$Res, $Val extends TaskListState>
    implements $TaskListStateCopyWith<$Res> {
  _$TaskListStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskListState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? allTasks = null,
    Object? todayTasks = null,
    Object? activeTasks = null,
    Object? completedTasks = null,
    Object? activeSessions = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            allTasks: null == allTasks
                ? _value.allTasks
                : allTasks // ignore: cast_nullable_to_non_nullable
                      as List<TaskModel>,
            todayTasks: null == todayTasks
                ? _value.todayTasks
                : todayTasks // ignore: cast_nullable_to_non_nullable
                      as List<TaskModel>,
            activeTasks: null == activeTasks
                ? _value.activeTasks
                : activeTasks // ignore: cast_nullable_to_non_nullable
                      as List<TaskModel>,
            completedTasks: null == completedTasks
                ? _value.completedTasks
                : completedTasks // ignore: cast_nullable_to_non_nullable
                      as List<TaskModel>,
            activeSessions: null == activeSessions
                ? _value.activeSessions
                : activeSessions // ignore: cast_nullable_to_non_nullable
                      as Map<String, TimerSession>,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TaskListStateImplCopyWith<$Res>
    implements $TaskListStateCopyWith<$Res> {
  factory _$$TaskListStateImplCopyWith(
    _$TaskListStateImpl value,
    $Res Function(_$TaskListStateImpl) then,
  ) = __$$TaskListStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<TaskModel> allTasks,
    List<TaskModel> todayTasks,
    List<TaskModel> activeTasks,
    List<TaskModel> completedTasks,
    Map<String, TimerSession> activeSessions,
    String? error,
  });
}

/// @nodoc
class __$$TaskListStateImplCopyWithImpl<$Res>
    extends _$TaskListStateCopyWithImpl<$Res, _$TaskListStateImpl>
    implements _$$TaskListStateImplCopyWith<$Res> {
  __$$TaskListStateImplCopyWithImpl(
    _$TaskListStateImpl _value,
    $Res Function(_$TaskListStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaskListState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? allTasks = null,
    Object? todayTasks = null,
    Object? activeTasks = null,
    Object? completedTasks = null,
    Object? activeSessions = null,
    Object? error = freezed,
  }) {
    return _then(
      _$TaskListStateImpl(
        allTasks: null == allTasks
            ? _value._allTasks
            : allTasks // ignore: cast_nullable_to_non_nullable
                  as List<TaskModel>,
        todayTasks: null == todayTasks
            ? _value._todayTasks
            : todayTasks // ignore: cast_nullable_to_non_nullable
                  as List<TaskModel>,
        activeTasks: null == activeTasks
            ? _value._activeTasks
            : activeTasks // ignore: cast_nullable_to_non_nullable
                  as List<TaskModel>,
        completedTasks: null == completedTasks
            ? _value._completedTasks
            : completedTasks // ignore: cast_nullable_to_non_nullable
                  as List<TaskModel>,
        activeSessions: null == activeSessions
            ? _value._activeSessions
            : activeSessions // ignore: cast_nullable_to_non_nullable
                  as Map<String, TimerSession>,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$TaskListStateImpl implements _TaskListState {
  const _$TaskListStateImpl({
    required final List<TaskModel> allTasks,
    required final List<TaskModel> todayTasks,
    required final List<TaskModel> activeTasks,
    required final List<TaskModel> completedTasks,
    required final Map<String, TimerSession> activeSessions,
    this.error,
  }) : _allTasks = allTasks,
       _todayTasks = todayTasks,
       _activeTasks = activeTasks,
       _completedTasks = completedTasks,
       _activeSessions = activeSessions;

  final List<TaskModel> _allTasks;
  @override
  List<TaskModel> get allTasks {
    if (_allTasks is EqualUnmodifiableListView) return _allTasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allTasks);
  }

  final List<TaskModel> _todayTasks;
  @override
  List<TaskModel> get todayTasks {
    if (_todayTasks is EqualUnmodifiableListView) return _todayTasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_todayTasks);
  }

  final List<TaskModel> _activeTasks;
  @override
  List<TaskModel> get activeTasks {
    if (_activeTasks is EqualUnmodifiableListView) return _activeTasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_activeTasks);
  }

  final List<TaskModel> _completedTasks;
  @override
  List<TaskModel> get completedTasks {
    if (_completedTasks is EqualUnmodifiableListView) return _completedTasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_completedTasks);
  }

  final Map<String, TimerSession> _activeSessions;
  @override
  Map<String, TimerSession> get activeSessions {
    if (_activeSessions is EqualUnmodifiableMapView) return _activeSessions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_activeSessions);
  }

  @override
  final String? error;

  @override
  String toString() {
    return 'TaskListState(allTasks: $allTasks, todayTasks: $todayTasks, activeTasks: $activeTasks, completedTasks: $completedTasks, activeSessions: $activeSessions, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskListStateImpl &&
            const DeepCollectionEquality().equals(other._allTasks, _allTasks) &&
            const DeepCollectionEquality().equals(
              other._todayTasks,
              _todayTasks,
            ) &&
            const DeepCollectionEquality().equals(
              other._activeTasks,
              _activeTasks,
            ) &&
            const DeepCollectionEquality().equals(
              other._completedTasks,
              _completedTasks,
            ) &&
            const DeepCollectionEquality().equals(
              other._activeSessions,
              _activeSessions,
            ) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_allTasks),
    const DeepCollectionEquality().hash(_todayTasks),
    const DeepCollectionEquality().hash(_activeTasks),
    const DeepCollectionEquality().hash(_completedTasks),
    const DeepCollectionEquality().hash(_activeSessions),
    error,
  );

  /// Create a copy of TaskListState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskListStateImplCopyWith<_$TaskListStateImpl> get copyWith =>
      __$$TaskListStateImplCopyWithImpl<_$TaskListStateImpl>(this, _$identity);
}

abstract class _TaskListState implements TaskListState {
  const factory _TaskListState({
    required final List<TaskModel> allTasks,
    required final List<TaskModel> todayTasks,
    required final List<TaskModel> activeTasks,
    required final List<TaskModel> completedTasks,
    required final Map<String, TimerSession> activeSessions,
    final String? error,
  }) = _$TaskListStateImpl;

  @override
  List<TaskModel> get allTasks;
  @override
  List<TaskModel> get todayTasks;
  @override
  List<TaskModel> get activeTasks;
  @override
  List<TaskModel> get completedTasks;
  @override
  Map<String, TimerSession> get activeSessions;
  @override
  String? get error;

  /// Create a copy of TaskListState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskListStateImplCopyWith<_$TaskListStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$TaskStatistics {
  int get total => throw _privateConstructorUsedError;
  int get completed => throw _privateConstructorUsedError;
  int get active => throw _privateConstructorUsedError;
  int get skipped => throw _privateConstructorUsedError;
  double get completionRate => throw _privateConstructorUsedError;

  /// Create a copy of TaskStatistics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskStatisticsCopyWith<TaskStatistics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskStatisticsCopyWith<$Res> {
  factory $TaskStatisticsCopyWith(
    TaskStatistics value,
    $Res Function(TaskStatistics) then,
  ) = _$TaskStatisticsCopyWithImpl<$Res, TaskStatistics>;
  @useResult
  $Res call({
    int total,
    int completed,
    int active,
    int skipped,
    double completionRate,
  });
}

/// @nodoc
class _$TaskStatisticsCopyWithImpl<$Res, $Val extends TaskStatistics>
    implements $TaskStatisticsCopyWith<$Res> {
  _$TaskStatisticsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskStatistics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? total = null,
    Object? completed = null,
    Object? active = null,
    Object? skipped = null,
    Object? completionRate = null,
  }) {
    return _then(
      _value.copyWith(
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as int,
            completed: null == completed
                ? _value.completed
                : completed // ignore: cast_nullable_to_non_nullable
                      as int,
            active: null == active
                ? _value.active
                : active // ignore: cast_nullable_to_non_nullable
                      as int,
            skipped: null == skipped
                ? _value.skipped
                : skipped // ignore: cast_nullable_to_non_nullable
                      as int,
            completionRate: null == completionRate
                ? _value.completionRate
                : completionRate // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TaskStatisticsImplCopyWith<$Res>
    implements $TaskStatisticsCopyWith<$Res> {
  factory _$$TaskStatisticsImplCopyWith(
    _$TaskStatisticsImpl value,
    $Res Function(_$TaskStatisticsImpl) then,
  ) = __$$TaskStatisticsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int total,
    int completed,
    int active,
    int skipped,
    double completionRate,
  });
}

/// @nodoc
class __$$TaskStatisticsImplCopyWithImpl<$Res>
    extends _$TaskStatisticsCopyWithImpl<$Res, _$TaskStatisticsImpl>
    implements _$$TaskStatisticsImplCopyWith<$Res> {
  __$$TaskStatisticsImplCopyWithImpl(
    _$TaskStatisticsImpl _value,
    $Res Function(_$TaskStatisticsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaskStatistics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? total = null,
    Object? completed = null,
    Object? active = null,
    Object? skipped = null,
    Object? completionRate = null,
  }) {
    return _then(
      _$TaskStatisticsImpl(
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as int,
        completed: null == completed
            ? _value.completed
            : completed // ignore: cast_nullable_to_non_nullable
                  as int,
        active: null == active
            ? _value.active
            : active // ignore: cast_nullable_to_non_nullable
                  as int,
        skipped: null == skipped
            ? _value.skipped
            : skipped // ignore: cast_nullable_to_non_nullable
                  as int,
        completionRate: null == completionRate
            ? _value.completionRate
            : completionRate // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$TaskStatisticsImpl implements _TaskStatistics {
  const _$TaskStatisticsImpl({
    required this.total,
    required this.completed,
    required this.active,
    required this.skipped,
    required this.completionRate,
  });

  @override
  final int total;
  @override
  final int completed;
  @override
  final int active;
  @override
  final int skipped;
  @override
  final double completionRate;

  @override
  String toString() {
    return 'TaskStatistics(total: $total, completed: $completed, active: $active, skipped: $skipped, completionRate: $completionRate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskStatisticsImpl &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.active, active) || other.active == active) &&
            (identical(other.skipped, skipped) || other.skipped == skipped) &&
            (identical(other.completionRate, completionRate) ||
                other.completionRate == completionRate));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    total,
    completed,
    active,
    skipped,
    completionRate,
  );

  /// Create a copy of TaskStatistics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskStatisticsImplCopyWith<_$TaskStatisticsImpl> get copyWith =>
      __$$TaskStatisticsImplCopyWithImpl<_$TaskStatisticsImpl>(
        this,
        _$identity,
      );
}

abstract class _TaskStatistics implements TaskStatistics {
  const factory _TaskStatistics({
    required final int total,
    required final int completed,
    required final int active,
    required final int skipped,
    required final double completionRate,
  }) = _$TaskStatisticsImpl;

  @override
  int get total;
  @override
  int get completed;
  @override
  int get active;
  @override
  int get skipped;
  @override
  double get completionRate;

  /// Create a copy of TaskStatistics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskStatisticsImplCopyWith<_$TaskStatisticsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
