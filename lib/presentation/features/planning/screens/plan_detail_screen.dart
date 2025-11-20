import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/di/providers/repository_providers.dart';
import 'package:myassistant/presentation/features/tasks/widgets/task_card.dart';
import 'package:myassistant/presentation/features/planning/widgets/edit_plan_dialog.dart';

/// Plan detail screen - displays plan information and all its associated tasks
class PlanDetailScreen extends ConsumerStatefulWidget {
  final PlanModel plan;

  const PlanDetailScreen({super.key, required this.plan});

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  late PlanModel _currentPlan;
  List<TaskModel> _tasks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.plan;
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final taskRepository = ref.read(taskRepositoryProvider);
      final tasks = await taskRepository.getPlanTasks(_currentPlan.id);

      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter tasks by status
    final activeTasks = _tasks.where((t) => t.status == TaskStatus.active).toList();
    final completedTasks = _tasks.where((t) => t.status == TaskStatus.completed).toList();
    final skippedTasks = _tasks.where((t) => t.status == TaskStatus.skipped).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditPlanDialog(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: CustomScrollView(
          slivers: [
            // Plan Header
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: theme.colorScheme.onPrimaryContainer,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _currentPlan.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_currentPlan.description != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _currentPlan.description!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Plan info chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          context,
                          Icons.event,
                          '${_formatDate(_currentPlan.startDate)} - ${_formatDate(_currentPlan.endDate)}',
                        ),
                        _buildInfoChip(
                          context,
                          Icons.repeat,
                          _getRepeatLabel(_currentPlan.repeatRule),
                        ),
                        _buildInfoChip(
                          context,
                          _getTaskTypeIcon(_currentPlan.taskConfig.taskType),
                          _getTaskTypeLabel(_currentPlan.taskConfig.taskType),
                        ),
                        _buildInfoChip(
                          context,
                          _getStatusIcon(_currentPlan.status),
                          _getStatusLabel(_currentPlan.status),
                        ),
                      ],
                    ),

                    // Task configuration details
                    if (_hasConfigDetails()) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '任务配置',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._buildConfigDetails(theme),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Tasks Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.assignment, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '任务列表',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_tasks.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Loading state
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),

            // Error state
            if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '加载失败',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _loadTasks,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),

            // Empty state
            if (!_isLoading && _error == null && _tasks.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyTasksState(context),
              ),

            // Active Tasks Section
            if (activeTasks.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '进行中 (${activeTasks.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final task = activeTasks[index];
                    return TaskCard(
                      task: task,
                      onTap: () => _showTaskDetails(task),
                    );
                  },
                  childCount: activeTasks.length,
                ),
              ),
            ],

            // Completed Tasks Section
            if (completedTasks.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '已完成 (${completedTasks.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final task = completedTasks[index];
                    return TaskCard(
                      task: task,
                      onTap: () => _showTaskDetails(task),
                    );
                  },
                  childCount: completedTasks.length,
                ),
              ),
            ],

            // Skipped Tasks Section
            if (skippedTasks.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '已跳过 (${skippedTasks.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final task = skippedTasks[index];
                    return TaskCard(
                      task: task,
                      onTap: () => _showTaskDetails(task),
                    );
                  },
                  childCount: skippedTasks.length,
                ),
              ),
            ],

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTasksState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '还没有任务',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '该计划下还没有生成任务',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasConfigDetails() {
    final config = _currentPlan.taskConfig;
    return config.durationMinutes != null ||
           config.repeatCount != null ||
           (config.evaluationOptions != null && config.evaluationOptions!.isNotEmpty);
  }

  List<Widget> _buildConfigDetails(ThemeData theme) {
    final config = _currentPlan.taskConfig;
    final details = <Widget>[];

    if (config.durationMinutes != null) {
      details.add(
        _buildConfigRow(
          theme,
          Icons.timer,
          '时长',
          '${config.durationMinutes} 分钟',
        ),
      );
    }

    if (config.repeatCount != null) {
      details.add(
        _buildConfigRow(
          theme,
          Icons.numbers,
          '重复次数',
          '${config.repeatCount} 次',
        ),
      );
    }

    if (config.evaluationOptions != null && config.evaluationOptions!.isNotEmpty) {
      details.add(
        _buildConfigRow(
          theme,
          Icons.star,
          '评价选项',
          config.evaluationOptions!.join(', '),
        ),
      );
    }

    return details;
  }

  Widget _buildConfigRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditPlanDialog() async {
    final updatedPlan = await showDialog<PlanModel>(
      context: context,
      builder: (context) => EditPlanDialog(plan: _currentPlan),
    );

    if (updatedPlan != null) {
      setState(() {
        _currentPlan = updatedPlan;
      });
    }
  }

  void _showTaskDetails(TaskModel task) {
    // TODO: Navigate to task detail or show task details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('查看任务: ${task.name}')),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _getRepeatLabel(RepeatRule rule) {
    switch (rule.type) {
      case RepeatType.oneTime:
        return '一次性';
      case RepeatType.daily:
        return '每天';
      case RepeatType.weekly:
        return '每周';
      case RepeatType.monthly:
        return '每月';
      case RepeatType.custom:
        return '每${rule.customDays}天';
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

  String _getTaskTypeLabel(TaskType type) {
    switch (type) {
      case TaskType.simple:
        return '简单任务';
      case TaskType.timer:
        return '计时任务';
      case TaskType.counter:
        return '计数任务';
      case TaskType.evaluation:
        return '评价任务';
      case TaskType.timerWithCount:
        return '计时+计数';
      case TaskType.counterWithEval:
        return '计数+评价';
    }
  }

  IconData _getStatusIcon(PlanStatus status) {
    switch (status) {
      case PlanStatus.active:
        return Icons.play_circle_outline;
      case PlanStatus.paused:
        return Icons.pause_circle_outline;
      case PlanStatus.completed:
        return Icons.check_circle_outline;
      case PlanStatus.deleted:
        return Icons.delete_outline;
    }
  }

  String _getStatusLabel(PlanStatus status) {
    switch (status) {
      case PlanStatus.active:
        return '进行中';
      case PlanStatus.paused:
        return '已暂停';
      case PlanStatus.completed:
        return '已完成';
      case PlanStatus.deleted:
        return '已删除';
    }
  }
}
