import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/presentation/providers/goal_state_provider.dart';
import 'package:myassistant/presentation/features/planning/widgets/goal_card.dart';
import 'package:myassistant/presentation/features/planning/widgets/create_goal_dialog.dart';

/// Planning screen - displays all goals and their associated plans
class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load goals on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(goalListProvider.notifier).loadGoals();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goalState = ref.watch(goalListProvider);

    return Column(
      children: [
        // Tab bar
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag, size: 18),
                    const SizedBox(width: 8),
                    Text('进行中 (${goalState.activeGoals.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 18),
                    const SizedBox(width: 8),
                    Text('已完成 (${goalState.completedGoals.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Active goals
              _buildGoalList(goalState.activeGoals, GoalStatus.active),

              // Completed goals
              _buildGoalList(goalState.completedGoals, GoalStatus.completed),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalList(List<GoalModel> goals, GoalStatus filterStatus) {
    if (goals.isEmpty) {
      return _buildEmptyState(filterStatus);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(goalListProvider.notifier).loadGoals();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: goals.length,
        itemBuilder: (context, index) {
          final goal = goals[index];
          return GoalCard(
            goal: goal,
            onTap: () {
              // Navigate to goal detail page to show plans
              context.push('/goal/${goal.id}');
            },
            onStatusChange: filterStatus != GoalStatus.completed
                ? (newStatus) => _updateGoalStatus(goal, newStatus)
                : null,
            onDelete: filterStatus != GoalStatus.completed
                ? () => _deleteGoal(goal)
                : null,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(GoalStatus filterStatus) {
    String message;
    String subtitle;
    IconData icon;

    switch (filterStatus) {
      case GoalStatus.active:
        message = '还没有目标';
        subtitle = '创建您的第一个目标，开始规划之旅！';
        icon = Icons.add_task;
        break;
      case GoalStatus.completed:
        message = '还没有完成的目标';
        subtitle = '继续努力，实现您的梦想！';
        icon = Icons.flag;
        break;
      case GoalStatus.paused:
        message = '没有暂停的目标';
        subtitle = '所有目标都在正轨上！';
        icon = Icons.play_circle_outline;
        break;
      case GoalStatus.deleted:
        message = '没有已删除的目标';
        subtitle = '所有目标都完好无损！';
        icon = Icons.delete_outline;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (filterStatus == GoalStatus.active) ...[
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _showCreateGoalDialog,
                icon: const Icon(Icons.add),
                label: const Text('创建目标'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCreateGoalDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateGoalDialog(),
    );

    if (result == true && mounted) {
      // Reload goals after successful creation
      ref.read(goalListProvider.notifier).loadGoals();
    }
  }

  Future<void> _updateGoalStatus(GoalModel goal, GoalStatus newStatus) async {
    if (newStatus == GoalStatus.completed) {
      await ref.read(goalListProvider.notifier).archiveGoal(goal.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('目标已完成'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteGoal(GoalModel goal) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除目标'),
        content: Text('确定要删除目标 "${goal.title}" 吗？\n\n此操作将同时删除所有关联的计划和任务，且无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(goalListProvider.notifier).deleteGoal(goal.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '目标已删除' : '删除失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}