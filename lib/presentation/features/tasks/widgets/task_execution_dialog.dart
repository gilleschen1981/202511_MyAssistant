import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/presentation/providers/task_list_notifier.dart';
import 'package:myassistant/core/utils/evaluation_score_helper.dart';

/// Base task execution dialog
abstract class TaskExecutionDialog extends ConsumerStatefulWidget {
  final TaskModel task;

  const TaskExecutionDialog({
    super.key,
    required this.task,
  });

  static Future<bool?> show(BuildContext context, TaskModel task) {
    final taskType = task.config.taskType;

    // Timer tasks should use the full-screen TimerScreen instead
    // This method is only for non-timer task types
    Widget dialog;
    switch (taskType) {
      case TaskType.simple:
        dialog = SimpleTaskDialog(task: task);
        break;
      case TaskType.timer:
      case TaskType.timerWithCount:
        // Timer tasks should use TimerScreen (full-screen page) instead
        throw UnsupportedError(
          'Timer tasks should use TimerScreen. Use context.push(AppRoutes.timer, extra: task) instead.',
        );
      case TaskType.counter:
        dialog = CounterTaskDialog(task: task);
        break;
      case TaskType.evaluation:
        dialog = EvaluationTaskDialog(task: task);
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

            // Evaluation options with scores
            ...options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final score = EvaluationScoreHelper.calculateScore(options, index);
              final isSelected = _selectedOption == option;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedOption = option;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          ),
                        if (isSelected) const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getScoreColor(score),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$score分',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

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

  Color _getScoreColor(int score) {
    if (score >= 80) {
      return Colors.green;
    } else if (score >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
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

              // Evaluation options with scores
              ...options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final score = EvaluationScoreHelper.calculateScore(options, index);
                final isSelected = _selectedOption == option;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedOption = option;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            ),
                          if (isSelected) const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getScoreColor(score),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$score分',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

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

  Color _getScoreColor(int score) {
    if (score >= 80) {
      return Colors.green;
    } else if (score >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}