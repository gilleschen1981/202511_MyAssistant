import 'package:flutter/material.dart';
import 'package:myassistant/data/models/plan_review_model.dart';
import 'package:intl/intl.dart';

/// Plan Review Card Widget
class PlanReviewCard extends StatelessWidget {
  final PlanReviewModel review;
  final VoidCallback? onTap;

  const PlanReviewCard({
    super.key,
    required this.review,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final plan = review.plan;
    final stats = review.statistics;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Plan name and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(context),
                ],
              ),

              if (plan.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  plan.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Date range
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
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
                  const Spacer(),
                  Text(
                    '${plan.durationDays} 天',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Statistics
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context,
                      label: '总数',
                      value: stats.totalTasks.toString(),
                      icon: Icons.task_alt,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      context,
                      label: '完成',
                      value: stats.completedTasks.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      context,
                      label: '跳过',
                      value: stats.skippedTasks.toString(),
                      icon: Icons.skip_next,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Completion rate progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '完成率',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${(stats.completionRate * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getCompletionRateColor(stats.completionRate),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stats.completionRate,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        _getCompletionRateColor(stats.completionRate),
                      ),
                    ),
                  ),
                ],
              ),

              // Average duration if available
              if (stats.avgDurationMinutes != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '平均用时: ${stats.avgDurationMinutes!.toStringAsFixed(0)} 分钟',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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

  Widget _buildStatusChip(BuildContext context) {
    final theme = Theme.of(context);
    final plan = review.plan;

    Color chipColor;
    String label;

    if (plan.hasEnded) {
      chipColor = Colors.grey;
      label = '已结束';
    } else if (plan.isActive) {
      chipColor = Colors.green;
      label = '进行中';
    } else {
      chipColor = Colors.blue;
      label = '未开始';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: chipColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final statColor = color ?? theme.colorScheme.primary;

    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: statColor,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: statColor,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Color _getCompletionRateColor(double rate) {
    if (rate >= 0.8) return Colors.green;
    if (rate >= 0.5) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }
}
