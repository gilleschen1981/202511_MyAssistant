import 'package:flutter/material.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/task_type.dart';

/// Plan card widget for displaying individual plans
class PlanCard extends StatelessWidget {
  final PlanModel plan;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PlanCard({
    super.key,
    required this.plan,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = plan.isActive;
    final hasEnded = plan.hasEnded;

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
                  _buildStatusIcon(context, isActive, hasEnded),
                  const SizedBox(width: 12),

                  // Plan name and dates
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: hasEnded
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.date_range,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatDate(plan.startDate)} - ${_formatDate(plan.endDate)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (plan.durationDays > 0) ...[
                              Text(
                                '(${plan.durationDays} days)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Task type indicator
                  _buildTaskTypeBadge(context, plan.taskConfig.taskType),
                ],
              ),

              // Description (if available)
              if (plan.description != null && plan.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  plan.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Info badges
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _buildBadge(
                    context: context,
                    label: _getRepeatLabel(plan.repeatRule),
                    icon: Icons.repeat,
                    color: theme.colorScheme.primary,
                  ),
                  if (plan.taskConfig.durationMinutes != null)
                    _buildBadge(
                      context: context,
                      label: '${plan.taskConfig.durationMinutes} min',
                      icon: Icons.timer,
                      color: theme.colorScheme.secondary,
                    ),
                  if (plan.taskConfig.repeatCount != null)
                    _buildBadge(
                      context: context,
                      label: '${plan.taskConfig.repeatCount}x',
                      icon: Icons.numbers,
                      color: theme.colorScheme.tertiary,
                    ),
                ],
              ),

              // Action buttons for active plans (edit and delete)
              if ((onEdit != null || onDelete != null) && !hasEnded) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onEdit != null)
                      OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('编辑'),
                      ),
                    if (onEdit != null && onDelete != null)
                      const SizedBox(width: 8),
                    if (onDelete != null)
                      OutlinedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('删除'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
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

  Widget _buildStatusIcon(BuildContext context, bool isActive, bool hasEnded) {
    IconData icon;
    Color color;

    if (hasEnded) {
      icon = Icons.archive;
      color = Colors.grey;
    } else if (isActive) {
      icon = Icons.play_circle;
      color = Colors.green;
    } else {
      icon = Icons.pause_circle;
      color = Colors.orange;
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

  Widget _buildTaskTypeBadge(BuildContext context, TaskType type) {
    final theme = Theme.of(context);
    String label = _getTaskTypeLabel(type);
    IconData icon = _getTaskTypeIcon(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.primary,
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

  String _getTaskTypeLabel(TaskType type) {
    switch (type) {
      case TaskType.simple:
        return 'Simple';
      case TaskType.timer:
        return 'Timer';
      case TaskType.counter:
        return 'Counter';
      case TaskType.evaluation:
        return 'Eval';
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

  String _getRepeatLabel(RepeatRule rule) {
    switch (rule.type) {
      case RepeatType.oneTime:
        return 'One Time';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.custom:
        return 'Every ${rule.customDays} days';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}