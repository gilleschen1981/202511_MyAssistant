import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/presentation/providers/task_list_notifier.dart';
import 'package:myassistant/presentation/features/tasks/widgets/task_execution_dialog.dart';
import 'package:myassistant/core/utils/app_logger.dart';

/// Quick action menu for tasks
/// Displays a floating menu with three action buttons: Timer, Complete, Skip
class TaskQuickMenu {
  /// Show the quick menu at the given position
  static void show(
    BuildContext context,
    TaskModel task,
    Offset tapPosition,
  ) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Size overlaySize = overlay.size;

    // Menu dimensions (2 buttons × 80dp)
    const double menuWidth = 160;
    const double menuHeight = 56;

    // Calculate menu position to keep it on screen
    double left = tapPosition.dx;
    double top = tapPosition.dy;

    // Adjust horizontally if menu would overflow right edge
    if (left + menuWidth > overlaySize.width) {
      left = overlaySize.width - menuWidth - 8;
    }

    // Adjust vertically if menu would overflow bottom edge
    if (top + menuHeight > overlaySize.height) {
      top = tapPosition.dy - menuHeight - 8;
    }

    // Ensure menu doesn't go off top or left edges
    if (left < 8) left = 8;
    if (top < 8) top = 8;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        left,
        top,
        overlaySize.width - left - menuWidth,
        overlaySize.height - top - menuHeight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 4,
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _QuickMenuContent(task: task),
        ),
      ],
    );
  }
}

/// Content of the quick menu
class _QuickMenuContent extends ConsumerWidget {
  final TaskModel task;

  const _QuickMenuContent({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if task has timer configuration
    final hasTimer = task.config.durationMinutes != null;
    // Check if task has counter configuration
    final hasCounter = task.config.repeatCount != null;

    return Container(
      width: 160, // 2 buttons × 80dp
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Show Timer button if task has timer configuration
          // Otherwise show Complete button
          if (hasTimer)
            _MenuButton(
              icon: Icons.timer,
              label: '计时',
              onTap: () async {
                Navigator.pop(context);
                // Show execution dialog for timer-based tasks
                final completed =
                    await TaskExecutionDialog.show(context, task);
                if (completed == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('任务已完成！'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            )
          else
            _MenuButton(
              icon: Icons.check,
              label: '完成',
              onTap: () async {
                Navigator.pop(context);

                // Counter task: increment count (auto-completes when reaching target)
                if (hasCounter) {
                  await _handleCounterTask(context, task, ref);
                }
                // Evaluation task: show evaluation menu
                else if (task.config.evaluationOptions != null &&
                    task.config.evaluationOptions!.isNotEmpty) {
                  _showEvaluationMenu(context, task, ref);
                }
                // Simple task: directly complete
                else {
                  await ref.read(taskListNotifierProvider.notifier).completeTask(
                        task: task,
                        actualDurationMinutes: null,
                        evaluationResult: null,
                        executionNote: null,
                      );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('任务已完成！'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),

          // Divider
          Container(
            width: 1,
            height: 56,
            color: const Color(0xFFE0E0E0),
          ),

          // Skip button (always shown)
          _MenuButton(
            icon: Icons.skip_next,
            label: '跳过',
            onTap: () => _handleSkipTask(context, task, ref),
          ),
        ],
      ),
    );
  }

  /// Handle counter task completion
  Future<void> _handleCounterTask(
    BuildContext context,
    TaskModel task,
    WidgetRef ref,
  ) async {
    // Check if this is the last count (will complete the task)
    final willComplete = task.currentCount + 1 >= task.config.repeatCount!;

    // If counter has evaluation AND this is the last count, show evaluation menu
    if (willComplete &&
        task.config.evaluationOptions != null &&
        task.config.evaluationOptions!.isNotEmpty) {
      // Show evaluation menu and increment count with evaluation
      _showEvaluationMenuForCounter(context, task, ref);
    } else {
      // Just increment count (may auto-complete if reaching target)
      await ref.read(taskListNotifierProvider.notifier).incrementCount(task);

      if (context.mounted) {
        if (willComplete) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('任务已完成！'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final newCount = task.currentCount + 1;
          final target = task.config.repeatCount!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('进度：$newCount/$target'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    }
  }

  /// Show evaluation menu for tasks requiring evaluation
  void _showEvaluationMenu(
    BuildContext context,
    TaskModel task,
    WidgetRef ref,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => _EvaluationMenu(
        task: task,
        isCounter: false,
      ),
    );
  }

  /// Show evaluation menu for counter tasks (on final count)
  void _showEvaluationMenuForCounter(
    BuildContext context,
    TaskModel task,
    WidgetRef ref,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => _EvaluationMenu(
        task: task,
        isCounter: true,
      ),
    );
  }

  /// Handle skip task action
  void _handleSkipTask(
    BuildContext context,
    TaskModel task,
    WidgetRef ref,
  ) async {
    AppLogger.d('Skip button tapped for task: ${task.id}', tag: 'TaskQuickMenu');

    // Close the quick menu first
    Navigator.pop(context);

    // Show skip reason dialog
    AppLogger.d('Showing skip reason dialog', tag: 'TaskQuickMenu');
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _SkipReasonDialog(),
    );

    AppLogger.d('Dialog returned reason: $reason', tag: 'TaskQuickMenu');

    // Check if user confirmed (reason won't be null even if empty)
    if (reason != null) {
      AppLogger.d('Calling skipTask with reason: $reason', tag: 'TaskQuickMenu');

      try {
        await ref.read(taskListNotifierProvider.notifier).skipTask(
          task: task,
          skipReason: reason.isEmpty ? null : reason,
        );

        // Show success message (find the scaffold context)
        if (context.mounted) {
          AppLogger.d('Showing success snackbar', tag: 'TaskQuickMenu');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('任务已跳过'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        AppLogger.e('Error skipping task: $e', tag: 'TaskQuickMenu', error: e);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('跳过失败: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      AppLogger.d('Skip cancelled by user', tag: 'TaskQuickMenu');
    }
  }
}

/// Individual menu button
class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Evaluation menu for tasks requiring evaluation
class _EvaluationMenu extends ConsumerWidget {
  final TaskModel task;
  final bool isCounter;

  const _EvaluationMenu({
    required this.task,
    required this.isCounter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = task.config.evaluationOptions ?? [];

    // Organize options into rows of 2
    final rows = <List<String>>[];
    for (var i = 0; i < options.length; i += 2) {
      rows.add(options.sublist(i, (i + 2 > options.length) ? options.length : i + 2));
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var j = 0; j < rows[i].length; j++) ...[
                      if (j > 0) const SizedBox(width: 8),
                      _EvaluationButton(
                        label: rows[i][j],
                        onTap: () => _handleEvaluationSelected(
                          context,
                          ref,
                          rows[i][j],
                        ),
                      ),
                    ],
                  ],
                ),
                if (i < rows.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleEvaluationSelected(
    BuildContext context,
    WidgetRef ref,
    String rating,
  ) async {
    Navigator.pop(context);

    if (isCounter) {
      // For counter tasks: increment count then complete with evaluation
      await ref.read(taskListNotifierProvider.notifier).incrementCount(task);
      // If this completes the counter, the evaluation should be handled separately
      // This is a simplified migration - may need refinement
    } else {
      // For regular evaluation tasks: complete with evaluation result
      await ref.read(taskListNotifierProvider.notifier).completeTask(
            task: task,
            actualDurationMinutes: null,
            evaluationResult: rating,
            executionNote: null,
          );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('任务已完成！'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

/// Individual evaluation button
class _EvaluationButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _EvaluationButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 80,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Skip reason dialog
class _SkipReasonDialog extends StatefulWidget {
  @override
  State<_SkipReasonDialog> createState() => _SkipReasonDialogState();
}

class _SkipReasonDialogState extends State<_SkipReasonDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('跳过任务'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('为什么要跳过这个任务？'),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              hintText: '输入原因（可选）',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, _reasonController.text);
          },
          child: const Text('跳过'),
        ),
      ],
    );
  }
}
