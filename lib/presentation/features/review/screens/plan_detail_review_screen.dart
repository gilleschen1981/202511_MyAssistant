import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/presentation/providers/plan_review_provider.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:intl/intl.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/presentation/features/review/widgets/completion_rate_trend_chart.dart';

/// Plan Detail Review Screen - shows detailed history and statistics for a plan
class PlanDetailReviewScreen extends ConsumerStatefulWidget {
  final String planId;

  const PlanDetailReviewScreen({
    super.key,
    required this.planId,
  });

  @override
  ConsumerState<PlanDetailReviewScreen> createState() =>
      _PlanDetailReviewScreenState();
}

class _PlanDetailReviewScreenState
    extends ConsumerState<PlanDetailReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviewAsync = ref.watch(planReviewProvider(widget.planId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划回顾'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: '概览'),
            Tab(icon: Icon(Icons.list_alt), text: '任务历史'),
            Tab(icon: Icon(Icons.analytics_outlined), text: '统计分析'),
          ],
        ),
      ),
      body: reviewAsync.when(
        data: (review) {
          if (review == null) {
            return const Center(child: Text('未找到计划'));
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(context, review),
              _buildTaskHistoryTab(context, review),
              _buildStatisticsTab(context, review),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '加载失败',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, dynamic review) {
    final plan = review.plan;
    final stats = review.statistics;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (plan.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      plan.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context,
                    icon: Icons.calendar_today,
                    label: '开始日期',
                    value: DateFormat('yyyy-MM-dd').format(plan.startDate),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    icon: Icons.event,
                    label: '结束日期',
                    value: DateFormat('yyyy-MM-dd').format(plan.endDate),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    icon: Icons.repeat,
                    label: '重复规则',
                    value: _getRepeatRuleText(plan.repeatRule.type.toString()),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Statistics card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '统计数据',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          label: '总任务',
                          value: stats.totalTasks.toString(),
                          icon: Icons.task_alt,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          label: '已完成',
                          value: stats.completedTasks.toString(),
                          icon: Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          label: '已跳过',
                          value: stats.skippedTasks.toString(),
                          icon: Icons.skip_next,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          label: '进行中',
                          value: stats.activeTasks.toString(),
                          icon: Icons.play_circle,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Completion rate
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '完成率',
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            '${(stats.completionRate * 100).toStringAsFixed(1)}%',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getCompletionRateColor(stats.completionRate),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: stats.completionRate,
                          minHeight: 8,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(
                            _getCompletionRateColor(stats.completionRate),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (stats.avgDurationMinutes != null) ...[
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      context,
                      icon: Icons.timer,
                      label: '平均用时',
                      value: '${stats.avgDurationMinutes!.toStringAsFixed(0)} 分钟',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskHistoryTab(BuildContext context, dynamic review) {
    final tasksByDate = review.tasksByDate;
    final theme = Theme.of(context);

    if (tasksByDate.isEmpty) {
      return Center(
        child: Text(
          '暂无任务历史',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final sortedDates = tasksByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // 最新的在前

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final tasks = tasksByDate[date]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(date),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ...tasks.map((task) => _buildTaskItem(context, task)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(BuildContext context, TaskModel task) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (task.status) {
      case TaskStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = '已完成';
        break;
      case TaskStatus.skipped:
        statusColor = Colors.orange;
        statusIcon = Icons.skip_next;
        statusText = '已跳过';
        break;
      case TaskStatus.active:
        statusColor = Colors.blue;
        statusIcon = Icons.play_circle;
        statusText = '进行中';
        break;
      case TaskStatus.deleted:
        statusColor = Colors.grey;
        statusIcon = Icons.delete;
        statusText = '已删除';
        break;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor),
      title: Text(task.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(statusText, style: TextStyle(color: statusColor)),
          if (task.completedAt != null)
            Text('完成于: ${DateFormat('HH:mm').format(task.completedAt!)}'),
          if (task.actualDurationMinutes != null)
            Text('用时: ${task.actualDurationMinutes} 分钟'),
          if (task.evaluationResult != null)
            Text('评价: ${task.evaluationResult}'),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab(BuildContext context, dynamic review) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Completion rate trend chart
          CompletionRateTrendChart(
            trendData: review.getCompletionRateTrend(days: 30),
            days: 30,
          ),

          const SizedBox(height: 16),

          // Skip reasons
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '跳过原因分析',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...review.getSkipReasons().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            '${entry.value} 次',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (review.getSkipReasons().isEmpty)
                    Text(
                      '没有跳过的任务',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Task count by hour
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '执行时段分布',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...review.getTaskCountByHour().entries.map((entry) {
                    final hour = entry.key;
                    final count = entry.value;
                    final maxCount = review.getTaskCountByHour().values.reduce((a, b) => a > b ? a : b);
                    final percentage = count / maxCount;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage,
                                minHeight: 20,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation(
                                  theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 40,
                            child: Text(
                              count.toString(),
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (review.getTaskCountByHour().isEmpty)
                    Text(
                      '暂无数据',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Color _getCompletionRateColor(double rate) {
    if (rate >= 0.8) return Colors.green;
    if (rate >= 0.5) return Colors.orange;
    return Colors.red;
  }

  String _getRepeatRuleText(String type) {
    switch (type) {
      case 'RepeatType.oneTime':
        return '一次性';
      case 'RepeatType.daily':
        return '每日';
      case 'RepeatType.weekly':
        return '每周';
      case 'RepeatType.monthly':
        return '每月';
      case 'RepeatType.custom':
        return '自定义';
      default:
        return type;
    }
  }
}
