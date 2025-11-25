import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/presentation/providers/task_list_notifier.dart';
import 'package:myassistant/presentation/routes/app_router.dart';
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
    const double padding = 8; // Padding from screen edges

    // Calculate menu position to appear near the tap position
    double left = tapPosition.dx;
    double top = tapPosition.dy + padding; // Show below tap point by default

    // Check if there's enough space on the right
    if (left + menuWidth > overlaySize.width - padding) {
      // Not enough space on right, show on left of tap point
      left = tapPosition.dx - menuWidth;
    }

    // Check if there's enough space below
    if (top + menuHeight > overlaySize.height - padding) {
      // Not enough space below, show above tap point
      top = tapPosition.dy - menuHeight - padding;
    }

    // Ensure menu doesn't go off left edge
    if (left < padding) {
      left = padding;
    }

    // Ensure menu doesn't go off top edge
    if (top < padding) {
      top = padding;
    }

    // Final safety check for right edge
    if (left + menuWidth > overlaySize.width - padding) {
      left = overlaySize.width - menuWidth - padding;
    }

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
    // Status checks (see document/TechnicalDesign/BusinessLogic.md § 5.2)
    // Only active and completed tasks should show the quick menu
    final isActive = task.status == TaskStatus.active;
    final isCompleted = task.status == TaskStatus.completed;

    // Skip button only shows for active tasks
    final shouldShowSkipButton = isActive;

    // Check if task is completed and can be re-executed
    // Any completed task can be re-executed, regardless of time window
    final canReExecute = isCompleted;

    // Check if task has timer configuration
    final hasTimer = task.config.durationMinutes != null;
    // Check if task has counter configuration
    final hasCounter = task.config.repeatCount != null;

    // Menu width: 1 button (80dp) or 2 buttons (160dp)
    final menuWidth = shouldShowSkipButton ? 160.0 : 80.0;

    return Container(
      width: menuWidth,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Show Re-execute button for completed tasks in execution window
          if (canReExecute)
            _MenuButton(
              icon: Icons.refresh,
              label: '再次执行',
              onTap: () async {
                Navigator.pop(context);
                await _handleReExecuteTask(context, task, ref);
              },
            )
          // Show Timer button if task has timer configuration
          // Otherwise show Complete button
          else if (hasTimer)
            _MenuButton(
              icon: Icons.timer,
              label: '计时',
              onTap: () async {
                Navigator.pop(context);
                // Navigate to full-screen timer page
                final completed = await context.push(
                  AppRoutes.timer,
                  extra: task,
                );
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

          // Divider (only show if skip button will be shown)
          if (shouldShowSkipButton)
            Container(
              width: 1,
              height: 56,
              color: const Color(0xFFE0E0E0),
            ),

          // Skip button (only for active tasks, see § 5.6.3)
          if (shouldShowSkipButton)
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
      final updatedTask = await ref.read(taskListNotifierProvider.notifier).incrementCount(task);

      if (context.mounted) {
        // Use the actual updated task status to determine the message
        if (updatedTask.status == TaskStatus.completed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('任务已完成！'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final newCount = updatedTask.currentCount;
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

  /// Handle re-execute task action
  Future<void> _handleReExecuteTask(
    BuildContext context,
    TaskModel task,
    WidgetRef ref,
  ) async {
    AppLogger.d('Re-execute button tapped for task: ${task.id}', tag: 'TaskQuickMenu');

    try {
      // Create a new task instance for re-execution
      final newTask = await ref.read(taskListNotifierProvider.notifier).reExecuteTask(task);

      if (newTask != null && context.mounted) {
        AppLogger.i('Task re-execution successful, new task created: ${newTask.id}', tag: 'TaskQuickMenu');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('任务已添加到列表，可以再次执行！'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (context.mounted) {
        AppLogger.w('Task re-execution failed: conditions not met', tag: 'TaskQuickMenu');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法重复执行此任务'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.e('Error re-executing task', tag: 'TaskQuickMenu', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重复执行失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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

    // Directly skip the task without showing dialog
    AppLogger.d('Calling skipTask directly', tag: 'TaskQuickMenu');

    try {
      await ref.read(taskListNotifierProvider.notifier).skipTask(
        task: task,
        skipReason: null,
      );

      // Show success message
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
      // For counter tasks: increment count with evaluation result
      // The service will auto-complete if this is the final count
      await ref.read(taskListNotifierProvider.notifier).incrementCount(
        task,
        evaluationResult: rating,
      );
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
