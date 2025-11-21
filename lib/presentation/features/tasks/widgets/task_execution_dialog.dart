import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/presentation/providers/task_list_notifier.dart';

/// Base task execution dialog
abstract class TaskExecutionDialog extends ConsumerStatefulWidget {
  final TaskModel task;

  const TaskExecutionDialog({
    super.key,
    required this.task,
  });

  static Future<bool?> show(BuildContext context, TaskModel task) {
    final taskType = task.config.taskType;

    Widget dialog;
    switch (taskType) {
      case TaskType.simple:
        dialog = SimpleTaskDialog(task: task);
        break;
      case TaskType.timer:
        dialog = TimerTaskDialog(task: task);
        break;
      case TaskType.counter:
        dialog = CounterTaskDialog(task: task);
        break;
      case TaskType.evaluation:
        dialog = EvaluationTaskDialog(task: task);
        break;
      case TaskType.timerWithCount:
        dialog = TimerCounterTaskDialog(task: task);
        break;
      case TaskType.counterWithEval:
        dialog = CounterEvaluationTaskDialog(task: task);
        break;
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => dialog,
    );
  }
}

/// Simple task execution dialog (checkbox)
class SimpleTaskDialog extends TaskExecutionDialog {
  const SimpleTaskDialog({super.key, required super.task});

  @override
  ConsumerState<SimpleTaskDialog> createState() => _SimpleTaskDialogState();
}

class _SimpleTaskDialogState extends ConsumerState<SimpleTaskDialog> {
  final _noteController = TextEditingController();
  bool _isCompleting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.task.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.task.description != null) ...[
              Text(
                widget.task.description!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Execution Note (Optional)',
                hintText: 'Add any notes about this task...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCompleting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isCompleting ? null : _completeTask,
          icon: _isCompleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Complete'),
        ),
      ],
    );
  }

  Future<void> _completeTask() async {
    setState(() => _isCompleting = true);

    await ref.read(taskListNotifierProvider.notifier).completeTask(
          task: widget.task,
          executionNote: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}

/// Timer task execution dialog
class TimerTaskDialog extends TaskExecutionDialog {
  const TimerTaskDialog({super.key, required super.task});

  @override
  ConsumerState<TimerTaskDialog> createState() => _TimerTaskDialogState();
}

class _TimerTaskDialogState extends ConsumerState<TimerTaskDialog> {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _isCompleted = false;
  bool _isCompleting = false;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _remainingSeconds = (widget.task.config.durationMinutes ?? 25) * 60;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _stopTimer();
        setState(() => _isCompleted = true);
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isCompleted = true;
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = 1 -
        (_remainingSeconds /
            ((widget.task.config.durationMinutes ?? 25) * 60));

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.timer),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.task.name)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.task.description != null) ...[
              Text(
                widget.task.description!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],

            // Timer display
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isCompleted ? Colors.green : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(_remainingSeconds),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _isCompleted ? Colors.green : null,
                        ),
                      ),
                      if (_isCompleted)
                        const Text(
                          'Completed!',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Timer controls
            if (!_isCompleted)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isRunning)
                    FilledButton.icon(
                      onPressed: _startTimer,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                    )
                  else ...[
                    OutlinedButton.icon(
                      onPressed: _pauseTimer,
                      icon: const Icon(Icons.pause),
                      label: const Text('Pause'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _stopTimer,
                      icon: const Icon(Icons.stop),
                      label: const Text('Finish'),
                    ),
                  ],
                ],
              ),

            if (_isCompleted) ...[
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Execution Note (Optional)',
                  hintText: 'Add any notes about this task...',
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCompleting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        if (_isCompleted)
          FilledButton.icon(
            onPressed: _isCompleting ? null : _completeTask,
            icon: _isCompleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Submit'),
          ),
      ],
    );
  }

  Future<void> _completeTask() async {
    setState(() => _isCompleting = true);

    final actualMinutes = ((widget.task.config.durationMinutes ?? 25) * 60 -
            _remainingSeconds) ~/
        60;

    await ref.read(taskListNotifierProvider.notifier).completeTask(
          task: widget.task,
          actualDurationMinutes: actualMinutes,
          executionNote: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}

/// Counter task execution dialog
class CounterTaskDialog extends TaskExecutionDialog {
  const CounterTaskDialog({super.key, required super.task});

  @override
  ConsumerState<CounterTaskDialog> createState() => _CounterTaskDialogState();
}

class _CounterTaskDialogState extends ConsumerState<CounterTaskDialog> {
  int _currentCount = 0;
  bool _isCompleting = false;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentCount = widget.task.currentCount;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetCount = widget.task.config.repeatCount ?? 1;
    final progress = targetCount > 0 ? _currentCount / targetCount : 0.0;
    final isCompleted = _currentCount >= targetCount;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.numbers),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.task.name)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.task.description != null) ...[
              Text(
                widget.task.description!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],

            // Counter display
            Center(
              child: Column(
                children: [
                  Text(
                    '$_currentCount / $targetCount',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.green : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? Colors.green : theme.colorScheme.primary,
                    ),
                  ),
                  if (isCompleted) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Target reached!',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Counter controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: _currentCount > 0
                      ? () => setState(() => _currentCount--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 24),
                FilledButton.icon(
                  onPressed: _currentCount < targetCount
                      ? () => setState(() => _currentCount++)
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Execution Note (Optional)',
                hintText: 'Add any notes about this task...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCompleting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isCompleting || !isCompleted ? null : _completeTask,
          icon: _isCompleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Complete'),
        ),
      ],
    );
  }

  Future<void> _completeTask() async {
    setState(() => _isCompleting = true);

    // Complete with updated count
    await ref.read(taskListNotifierProvider.notifier).completeTask(
          task: widget.task.copyWith(currentCount: _currentCount),
          executionNote: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}

/// Evaluation task execution dialog
class EvaluationTaskDialog extends TaskExecutionDialog {
  const EvaluationTaskDialog({super.key, required super.task});

  @override
  ConsumerState<EvaluationTaskDialog> createState() =>
      _EvaluationTaskDialogState();
}

class _EvaluationTaskDialogState extends ConsumerState<EvaluationTaskDialog> {
  String? _selectedOption;
  bool _isCompleting = false;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = widget.task.config.evaluationOptions ?? [];

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.star),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.task.name)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.task.description != null) ...[
              Text(
                widget.task.description!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],

            Text(
              'How did it go?',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Evaluation options
            ...options.map((option) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ChoiceChip(
                    label: Text(option),
                    selected: _selectedOption == option,
                    onSelected: (selected) {
                      setState(() {
                        _selectedOption = selected ? option : null;
                      });
                    },
                  ),
                )),

            const SizedBox(height: 16),

            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes (Optional)',
                hintText: 'Add any notes about this evaluation...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCompleting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isCompleting || _selectedOption == null
              ? null
              : _completeTask,
          icon: _isCompleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Submit'),
        ),
      ],
    );
  }

  Future<void> _completeTask() async {
    setState(() => _isCompleting = true);

    await ref.read(taskListNotifierProvider.notifier).completeTask(
          task: widget.task,
          evaluationResult: _selectedOption,
          executionNote: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}

/// Timer + Counter combined task dialog
class TimerCounterTaskDialog extends TaskExecutionDialog {
  const TimerCounterTaskDialog({super.key, required super.task});

  @override
  ConsumerState<TimerCounterTaskDialog> createState() =>
      _TimerCounterTaskDialogState();
}

class _TimerCounterTaskDialogState
    extends ConsumerState<TimerCounterTaskDialog> {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _currentCount = 0;
  bool _isRunning = false;
  bool _isCompleting = false;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _remainingSeconds = (widget.task.config.durationMinutes ?? 25) * 60;
    _currentCount = widget.task.currentCount;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _pauseTimer();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetCount = widget.task.config.repeatCount ?? 1;
    final timerProgress = 1 -
        (_remainingSeconds /
            ((widget.task.config.durationMinutes ?? 25) * 60));
    final countProgress = targetCount > 0 ? _currentCount / targetCount : 0.0;
    final isCountCompleted = _currentCount >= targetCount;
    final isTimerCompleted = _remainingSeconds == 0;
    final isFullyCompleted = isCountCompleted && isTimerCompleted;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.timelapse),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.task.name)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.task.description != null) ...[
              Text(
                widget.task.description!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],

            // Timer section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer, size: 20),
                        const SizedBox(width: 8),
                        const Text('Timer'),
                        const Spacer(),
                        Text(
                          _formatTime(_remainingSeconds),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isTimerCompleted ? Colors.green : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: timerProgress,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isTimerCompleted
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Counter section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.numbers, size: 20),
                        const SizedBox(width: 8),
                        const Text('Counter'),
                        const Spacer(),
                        Text(
                          '$_currentCount / $targetCount',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isCountCompleted ? Colors.green : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: countProgress,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCountCompleted
                            ? Colors.green
                            : theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Timer control
                if (!_isRunning)
                  OutlinedButton.icon(
                    onPressed: _remainingSeconds > 0 ? _startTimer : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Timer'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _pauseTimer,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),

                // Counter controls
                Row(
                  children: [
                    IconButton(
                      onPressed: _currentCount > 0
                          ? () => setState(() => _currentCount--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton.filled(
                      onPressed: _currentCount < targetCount
                          ? () => setState(() => _currentCount++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),

            if (isFullyCompleted) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Execution Note (Optional)',
                  hintText: 'Add any notes about this task...',
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCompleting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isCompleting || !isFullyCompleted
              ? null
              : _completeTask,
          icon: _isCompleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Complete'),
        ),
      ],
    );
  }

  Future<void> _completeTask() async {
    setState(() => _isCompleting = true);

    final actualMinutes = ((widget.task.config.durationMinutes ?? 25) * 60 -
            _remainingSeconds) ~/
        60;

    await ref.read(taskListNotifierProvider.notifier).completeTask(
          task: widget.task.copyWith(currentCount: _currentCount),
          actualDurationMinutes: actualMinutes,
          executionNote: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}

/// Counter + Evaluation combined task dialog
class CounterEvaluationTaskDialog extends TaskExecutionDialog {
  const CounterEvaluationTaskDialog({super.key, required super.task});

  @override
  ConsumerState<CounterEvaluationTaskDialog> createState() =>
      _CounterEvaluationTaskDialogState();
}

class _CounterEvaluationTaskDialogState
    extends ConsumerState<CounterEvaluationTaskDialog> {
  int _currentCount = 0;
  String? _selectedOption;
  bool _isCompleting = false;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentCount = widget.task.currentCount;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetCount = widget.task.config.repeatCount ?? 1;
    final countProgress = targetCount > 0 ? _currentCount / targetCount : 0.0;
    final isCountCompleted = _currentCount >= targetCount;
    final options = widget.task.config.evaluationOptions ?? [];

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.analytics),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.task.name)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.task.description != null) ...[
              Text(
                widget.task.description!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],

            // Counter section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '$_currentCount / $targetCount',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isCountCompleted ? Colors.green : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: countProgress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCountCompleted
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.outlined(
                          onPressed: _currentCount > 0
                              ? () => setState(() => _currentCount--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: _currentCount < targetCount
                              ? () => setState(() => _currentCount++)
                              : null,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (isCountCompleted) ...[
              const SizedBox(height: 16),
              Text(
                'How did it go?',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              // Evaluation options
              Wrap(
                spacing: 8,
                children: options
                    .map((option) => ChoiceChip(
                          label: Text(option),
                          selected: _selectedOption == option,
                          onSelected: (selected) {
                            setState(() {
                              _selectedOption = selected ? option : null;
                            });
                          },
                        ))
                    .toList(),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  hintText: 'Add any notes...',
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCompleting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isCompleting ||
                  !isCountCompleted ||
                  _selectedOption == null
              ? null
              : _completeTask,
          icon: _isCompleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Complete'),
        ),
      ],
    );
  }

  Future<void> _completeTask() async {
    setState(() => _isCompleting = true);

    await ref.read(taskListNotifierProvider.notifier).completeTask(
          task: widget.task.copyWith(currentCount: _currentCount),
          evaluationResult: _selectedOption,
          executionNote: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}