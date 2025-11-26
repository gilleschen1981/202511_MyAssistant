import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/presentation/providers/task_list_notifier.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Full-screen timer page for timer tasks
class TimerScreen extends ConsumerStatefulWidget {
  final TaskModel task;

  const TimerScreen({
    super.key,
    required this.task,
  });

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _currentCount = 0;
  bool _isRunning = false;
  bool _isCompleting = false;
  final _noteController = TextEditingController();
  final _audioPlayer = AudioPlayer();

  // Check if this is a timer+counter task
  bool get _hasCounter => widget.task.config.repeatCount != null;

  // Get current task from state (to get latest currentCount)
  TaskModel get _currentTask {
    final tasksState = ref.read(taskListNotifierProvider);
    return tasksState.value?.allTasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    ) ?? widget.task;
  }

  @override
  void initState() {
    super.initState();
    _remainingSeconds = (widget.task.config.durationMinutes ?? 25) * 60;
    if (_hasCounter) {
      _currentCount = widget.task.currentCount;
    }
    // Enable wakelock to prevent screen from sleeping
    WakelockPlus.enable();
    // Auto-start the timer
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _noteController.dispose();
    _audioPlayer.dispose();
    // Disable wakelock when leaving the screen
    WakelockPlus.disable();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _pauseTimer();
        _playCompletionSound();
        _handleTimerFinished();
      }
    });
  }

  /// Play completion sound when timer finishes
  /// Uses a three-layer fallback mechanism:
  /// 1. Custom audio file (if available)
  /// 2. System notification sound
  /// 3. Enhanced vibration (always triggered for additional feedback)
  Future<void> _playCompletionSound() async {
    bool soundPlayed = false;

    // First layer: Try to play custom audio file
    try {
      await _audioPlayer.play(AssetSource('sounds/timer_complete.mp3'));
      soundPlayed = true;
    } catch (e) {
      // Audio file doesn't exist or playback failed, continue to next layer
    }

    // Second layer: Try to play system notification sound
    if (!soundPlayed) {
      try {
        FlutterRingtonePlayer().playNotification();
        soundPlayed = true;
      } catch (e) {
        // System notification sound failed, but continue
      }
    }

    // Third layer: Vibration feedback (always triggered regardless of sound)
    try {
      // Check if device has vibrator capability
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Use strong vibration pattern: 500ms vibration
        await Vibration.vibrate(duration: 500);
      }
    } catch (e) {
      // Vibration failed, silently ignore
    }
  }

  // Handle when timer reaches zero
  Future<void> _handleTimerFinished() async {
    if (_hasCounter) {
      // For timer+counter tasks: increment count in database
      final targetCount = widget.task.config.repeatCount ?? 1;

      try {
        // Calculate actual duration for this round
        final configuredMinutes = widget.task.config.durationMinutes ?? 25;
        final actualMinutes = ((configuredMinutes * 60 - _remainingSeconds) / 60).ceil();

        // Increment count in database (will auto-complete if target reached)
        final updatedTask = await ref.read(taskListNotifierProvider.notifier).incrementCount(
          _currentTask,
          actualDurationMinutes: actualMinutes,
        );

        // Use the returned updated task
        final newCount = updatedTask.currentCount;

        if (updatedTask.status == TaskStatus.completed) {
          // Task completed, close page
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('任务已完成！'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop(true);
          }
        } else {
          // Not yet completed, show progress and exit page
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已完成 $newCount/$targetCount 次'),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 2),
              ),
            );
            // Exit the timer page after showing progress
            context.pop(true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // For pure timer tasks: complete immediately
      await _completeTask(_currentCount);
    }
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resumeTimer() {
    if (_remainingSeconds > 0) {
      _startTimer();
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Complete the task (called when timer finishes or user manually ends)
  Future<void> _completeTask(int finalCount) async {
    if (_isCompleting) return;

    setState(() => _isCompleting = true);

    final actualMinutes = ((widget.task.config.durationMinutes ?? 25) * 60 -
            _remainingSeconds) ~/
        60;

    try {
      await ref.read(taskListNotifierProvider.notifier).completeTask(
            task: _hasCounter
                ? widget.task.copyWith(currentCount: finalCount)
                : widget.task,
            actualDurationMinutes: actualMinutes,
            executionNote: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );

      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('完成任务失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Manual finish - complete current round and close page
  Future<void> _finishTask() async {
    if (_isCompleting) return;

    // Stop the timer first
    _pauseTimer();

    if (_hasCounter) {
      // For timer+counter tasks: increment count (auto-completes if target reached)
      final targetCount = widget.task.config.repeatCount ?? 1;

      try {
        setState(() => _isCompleting = true);

        // Calculate actual duration for this round
        final configuredMinutes = widget.task.config.durationMinutes ?? 25;
        final actualMinutes = ((configuredMinutes * 60 - _remainingSeconds) / 60).ceil();

        // Increment count using current task state - this will auto-complete task if target reached
        final updatedTask = await ref.read(taskListNotifierProvider.notifier).incrementCount(
          _currentTask,
          actualDurationMinutes: actualMinutes,
        );

        // Use the returned updated task to check status
        final newCount = updatedTask.currentCount;

        if (mounted) {
          // Show message and close page
          if (updatedTask.status == TaskStatus.completed) {
            // Task completed
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('任务已完成！'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            // Just incremented count
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已完成 $newCount/$targetCount 次'),
                backgroundColor: Colors.blue,
              ),
            );
          }
          context.pop(true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isCompleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // For pure timer tasks: complete immediately
      await _completeTask(_currentCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = 1 -
        (_remainingSeconds /
            ((widget.task.config.durationMinutes ?? 25) * 60));
    final isTimerFinished = _remainingSeconds == 0;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with task name
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.task.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Main content area
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Timer display
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 280,
                          height: 280,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 12,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isTimerFinished
                                  ? Colors.green
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(_remainingSeconds),
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 72,
                                color: isTimerFinished ? Colors.green : null,
                              ),
                            ),
                            if (isTimerFinished)
                              const Text(
                                '时间到！',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Counter display (if applicable) - read-only progress indicator
                    if (_hasCounter) ...[
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                '进度',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$_currentCount / ${widget.task.config.repeatCount}',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: (widget.task.config.repeatCount ?? 1) > 0
                                    ? _currentCount /
                                        (widget.task.config.repeatCount ?? 1)
                                    : 0.0,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Note input (always shown)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          labelText: '备注（可选）',
                          hintText: '添加任务备注...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isCompleting ? null : () => context.pop(false),
                      icon: const Icon(Icons.close),
                      label: const Text('取消'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Pause/Resume button
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isCompleting
                          ? null
                          : (_isRunning ? _pauseTimer : _resumeTimer),
                      icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                      label: Text(_isRunning ? '暂停' : '继续'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: theme.colorScheme.secondary,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Finish button
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isCompleting ? null : _finishTask,
                      icon: _isCompleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text('结束'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
