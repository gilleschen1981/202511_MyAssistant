import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/presentation/providers/plan_state_provider.dart';
import 'package:myassistant/presentation/providers/goal_state_provider.dart';
import 'package:myassistant/presentation/features/planning/widgets/plan_card.dart';
import 'package:myassistant/presentation/features/planning/widgets/edit_goal_dialog.dart';
import 'package:myassistant/presentation/features/planning/widgets/create_plan_dialog.dart';
import 'package:myassistant/presentation/features/planning/widgets/edit_plan_dialog.dart';
import 'package:myassistant/core/utils/app_logger.dart';

/// Goal detail screen - displays goal information and all its associated plans
class GoalDetailScreen extends ConsumerStatefulWidget {
  final GoalModel goal;

  const GoalDetailScreen({super.key, required this.goal});

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  late GoalModel _currentGoal;

  @override
  void initState() {
    super.initState();
    _currentGoal = widget.goal;
    // Load plans for this goal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(planListProvider.notifier).loadGoalPlans(widget.goal.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(planListProvider);
    final theme = Theme.of(context);

    // Filter plans for this goal
    final goalPlans = [...planState.activePlans, ...planState.completedPlans]
        .where((plan) => plan.goalId == _currentGoal.id)
        .toList();

    final activePlans = goalPlans.where((p) => p.isActive).toList();
    final completedPlans = goalPlans.where((p) => !p.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('目标详情'),
        actions: [
          // Show Complete button only for active or paused goals
          if (_currentGoal.status == GoalStatus.active || _currentGoal.status == GoalStatus.paused)
            IconButton(
              icon: const Icon(Icons.check_circle),
              tooltip: '完成目标',
              onPressed: () => _confirmCompleteGoal(),
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditGoalDialog(),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Goal Header
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
                        Icons.flag,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currentGoal.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_currentGoal.description != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _currentGoal.description!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Goal info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        context,
                        Icons.calendar_today,
                        '创建于 ${_formatDate(_currentGoal.createdAt)}',
                      ),
                      if (_currentGoal.deadline != null)
                        _buildInfoChip(
                          context,
                          Icons.event,
                          '截止 ${_formatDate(_currentGoal.deadline!)}',
                        ),
                      _buildInfoChip(
                        context,
                        _getStatusIcon(_currentGoal.status),
                        _getStatusLabel(_currentGoal.status),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Plans Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '关联计划',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      _showCreatePlanDialog();
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('新建计划'),
                  ),
                ],
              ),
            ),
          ),

          // Loading state
          if (planState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),

          // Empty state
          if (!planState.isLoading && goalPlans.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyPlansState(context),
            ),

          // Active Plans Section
          if (activePlans.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                      '进行中的计划 (${activePlans.length})',
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
                  final plan = activePlans[index];
                  return PlanCard(
                    plan: plan,
                    onTap: () => _showEditPlanDialog(plan),
                    onEdit: () => _showEditPlanDialog(plan),
                    onDelete: () => _confirmDeletePlan(plan),
                  );
                },
                childCount: activePlans.length,
              ),
            ),
          ],

          // Completed Plans Section
          if (completedPlans.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '已完成的计划 (${completedPlans.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade700,
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
                  final plan = completedPlans[index];
                  return PlanCard(
                    plan: plan,
                    onTap: () => _showEditPlanDialog(plan),
                  );
                },
                childCount: completedPlans.length,
              ),
            ),
          ],

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
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

  Widget _buildEmptyPlansState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '还没有计划',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '为这个目标创建计划，将大目标分解为可执行的任务',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showCreatePlanDialog,
              icon: const Icon(Icons.add),
              label: const Text('创建第一个计划'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditGoalDialog() async {
    final updatedGoal = await showDialog<GoalModel>(
      context: context,
      builder: (context) => EditGoalDialog(goal: _currentGoal),
    );

    if (updatedGoal != null) {
      setState(() {
        _currentGoal = updatedGoal;
      });
    }
  }

  Future<void> _showCreatePlanDialog() async {
    final plan = await showDialog<PlanModel>(
      context: context,
      builder: (context) => CreatePlanDialog(
        goalId: _currentGoal.id,
        goalTitle: _currentGoal.title,
        goalDeadline: _currentGoal.deadline,
      ),
    );

    // Reload plans if a new plan was created
    if (plan != null) {
      ref.read(planListProvider.notifier).loadGoalPlans(_currentGoal.id);
    }
  }

  Future<void> _showEditPlanDialog(PlanModel plan) async {
    final updatedPlan = await showDialog<PlanModel>(
      context: context,
      builder: (context) => EditPlanDialog(plan: plan),
    );

    // Reload plans if plan was updated
    if (updatedPlan != null) {
      ref.read(planListProvider.notifier).loadGoalPlans(_currentGoal.id);
    }
  }

  Future<void> _confirmDeletePlan(PlanModel plan) async {
    AppLogger.d('_confirmDeletePlan called for plan: ${plan.name} (${plan.id})', tag: 'GoalDetailScreen');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除计划'),
        content: Text('确定要删除计划"${plan.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    AppLogger.d('User confirmation: $confirmed', tag: 'GoalDetailScreen');
    if (confirmed == true) {
      AppLogger.d('Calling deletePlan...', tag: 'GoalDetailScreen');
      final success = await ref.read(planListProvider.notifier).deletePlan(plan.id);
      AppLogger.d('Delete success: $success', tag: 'GoalDetailScreen');

      if (success && mounted) {
        AppLogger.d('Showing success message and reloading plans', tag: 'GoalDetailScreen');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('计划"${plan.name}"已删除')),
        );
        // Reload plans
        ref.read(planListProvider.notifier).loadGoalPlans(_currentGoal.id);
      } else if (mounted) {
        AppLogger.d('Showing failure message', tag: 'GoalDetailScreen');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除计划失败,请重试')),
        );
      }
    } else {
      AppLogger.d('User cancelled deletion', tag: 'GoalDetailScreen');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  IconData _getStatusIcon(GoalStatus status) {
    switch (status) {
      case GoalStatus.active:
        return Icons.play_circle_outline;
      case GoalStatus.paused:
        return Icons.pause_circle_outline;
      case GoalStatus.completed:
        return Icons.check_circle_outline;
      case GoalStatus.deleted:
        return Icons.delete_outline;
    }
  }

  String _getStatusLabel(GoalStatus status) {
    switch (status) {
      case GoalStatus.active:
        return '进行中';
      case GoalStatus.paused:
        return '已暂停';
      case GoalStatus.completed:
        return '已完成';
      case GoalStatus.deleted:
        return '已删除';
    }
  }

  Future<void> _confirmCompleteGoal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完成目标'),
        content: Text(
          '确定要完成目标"${_currentGoal.title}"吗？\n\n'
          '这将会：\n'
          '• 跳过所有计划中当前执行窗口内的活跃任务\n'
          '• 将所有计划标记为已完成\n'
          '• 将目标标记为已完成\n\n'
          '此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认完成'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final completedGoal = await ref.read(goalListProvider.notifier).completeGoal(_currentGoal.id);

        if (mounted) {
          // Close loading indicator
          Navigator.pop(context);

          if (completedGoal != null) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('目标"${_currentGoal.title}"已完成')),
            );
            // Navigate back to goal list
            Navigator.pop(context);
          } else {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('完成目标失败，请重试')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          // Close loading indicator
          Navigator.pop(context);
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('完成目标失败: ${e.toString()}')),
          );
        }
      }
    }
  }
}