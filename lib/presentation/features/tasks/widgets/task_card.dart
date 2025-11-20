import 'package:flutter/material.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';

/// Task card widget for displaying individual tasks
class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onComplete,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = task.status == TaskStatus.active;
    final isCompleted = task.status == TaskStatus.completed;
    final isSkipped = task.status == TaskStatus.skipped;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Status icon
                  _buildStatusIcon(context, task.status),
                  const SizedBox(width: 12),

                  // Task name and time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted || isSkipped
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCompleted || isSkipped
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatTime(task.windowStartTime)} - ${_formatTime(task.windowEndTime)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  if (isActive) ...[
                    _buildActionButton(
                      context: context,
                      icon: Icons.done,
                      color: theme.colorScheme.primary,
                      onTap: onComplete,
                      tooltip: 'Complete',
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      context: context,
                      icon: Icons.skip_next,
                      color: theme.colorScheme.tertiary,
                      onTap: onSkip,
                      tooltip: 'Skip',
                    ),
                  ],
                ],
              ),

              // Description (if available)
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  task.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Task type badges
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _buildTypeBadge(
                    context: context,
                    label: _getTaskTypeLabel(task.config.taskType),
                    icon: _getTaskTypeIcon(task.config.taskType),
                  ),
                  if (task.planId.isNotEmpty)
                    _buildBadge(
                      context: context,
                      label: 'Plan',
                      icon: Icons.calendar_today,
                      color: theme.colorScheme.tertiary,
                    ),
                ],
              ),

              // Completion/Skip info
              if (isCompleted || isSkipped) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCompleted ? Icons.check_circle : Icons.skip_next,
                        size: 16,
                        color: isCompleted ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isCompleted
                              ? 'Completed at ${_formatTime(task.completedAt!)}'
                              : task.executionNote ?? 'Skipped',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context, TaskStatus status) {
    final theme = Theme.of(context);
    IconData icon;
    Color color;

    // Check if task is expired first
    if (task.isExpired && status == TaskStatus.active) {
      icon = Icons.timer_off;
      color = theme.colorScheme.error;
    } else {
      switch (status) {
        case TaskStatus.active:
          icon = Icons.pending_actions;
          color = theme.colorScheme.primary;
          break;
        case TaskStatus.completed:
          icon = Icons.check_circle;
          color = Colors.green;
          break;
        case TaskStatus.skipped:
          icon = Icons.skip_next;
          color = Colors.orange;
          break;
        case TaskStatus.deleted:
          icon = Icons.delete;
          color = theme.colorScheme.error;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge({
    required BuildContext context,
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return _buildBadge(
      context: context,
      label: label,
      icon: icon,
      color: theme.colorScheme.primary,
    );
  }


  String _getTaskTypeLabel(TaskType type) {
    switch (type) {
      case TaskType.simple:
        return 'Task';
      case TaskType.timer:
        return 'Timer';
      case TaskType.counter:
        return 'Counter';
      case TaskType.evaluation:
        return 'Evaluate';
      case TaskType.timerWithCount:
        return 'Timer+Count';
      case TaskType.counterWithEval:
        return 'Count+Eval';
    }
  }

  IconData _getTaskTypeIcon(TaskType type) {
    switch (type) {
      case TaskType.simple:
        return Icons.check_box;
      case TaskType.timer:
        return Icons.timer;
      case TaskType.counter:
        return Icons.numbers;
      case TaskType.evaluation:
        return Icons.star;
      case TaskType.timerWithCount:
        return Icons.timelapse;
      case TaskType.counterWithEval:
        return Icons.analytics;
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}