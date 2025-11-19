import 'package:flutter/material.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/priority.dart';

/// Goal card widget for displaying individual goals
class GoalCard extends StatelessWidget {
  final GoalModel goal;
  final VoidCallback? onTap;
  final Function(GoalStatus)? onStatusChange;
  final VoidCallback? onDelete;

  const GoalCard({
    super.key,
    required this.goal,
    this.onTap,
    this.onStatusChange,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = goal.status == GoalStatus.inProgress;
    final isCompleted = goal.status == GoalStatus.completed;

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
                  _buildStatusIcon(context, goal.status),
                  const SizedBox(width: 12),

                  // Goal title and deadline
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCompleted
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        if (goal.deadline != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(goal.deadline!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _getDeadlineColor(context, goal.deadline!),
                                ),
                              ),
                              if (goal.daysRemaining != null && goal.daysRemaining! >= 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '(${goal.daysRemaining} days)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _getDeadlineColor(context, goal.deadline!),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Priority indicator
                  _buildPriorityBadge(context, goal.priority),
                ],
              ),

              // Description (if available)
              if (goal.description != null && goal.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  goal.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Tags and plan count
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (goal.planCount > 0)
                    _buildBadge(
                      context: context,
                      label: '${goal.planCount} Plans',
                      icon: Icons.task_alt,
                      color: theme.colorScheme.tertiary,
                    ),
                  ...goal.tags.take(3).map((tag) => _buildBadge(
                        context: context,
                        label: tag,
                        icon: Icons.label,
                        color: theme.colorScheme.primary,
                      )),
                  if (goal.tags.length > 3)
                    _buildBadge(
                      context: context,
                      label: '+${goal.tags.length - 3}',
                      icon: Icons.more_horiz,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),

              // Action buttons for active goals
              if (isActive) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (onStatusChange != null)
                      FilledButton.icon(
                        onPressed: () => onStatusChange!(GoalStatus.completed),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Complete'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context, GoalStatus status) {
    final theme = Theme.of(context);
    IconData icon;
    Color color;

    switch (status) {
      case GoalStatus.inProgress:
        icon = Icons.flag;
        color = theme.colorScheme.primary;
        break;
      case GoalStatus.paused:
        icon = Icons.pause_circle;
        color = Colors.orange;
        break;
      case GoalStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
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

  Widget _buildPriorityBadge(BuildContext context, Priority priority) {
    Color color;
    String label;

    switch (priority) {
      case Priority.high:
        color = Colors.red;
        label = 'High';
        break;
      case Priority.medium:
        color = Colors.orange;
        label = 'Medium';
        break;
      case Priority.low:
        color = Colors.blue;
        label = 'Low';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 12, color: color),
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

  Color _getDeadlineColor(BuildContext context, DateTime deadline) {
    final daysRemaining = deadline.difference(DateTime.now()).inDays;
    if (daysRemaining < 0) {
      return Theme.of(context).colorScheme.error;
    } else if (daysRemaining <= 7) {
      return Colors.orange;
    } else {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}