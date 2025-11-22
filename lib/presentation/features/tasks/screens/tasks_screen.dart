import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/presentation/providers/task_list_notifier.dart';
import 'package:myassistant/presentation/features/tasks/widgets/compact_task_card.dart';
import 'package:myassistant/presentation/features/tasks/widgets/task_quick_menu.dart';
import 'package:myassistant/presentation/features/tasks/utils/task_grouping.dart';

/// Tasks screen - displays tasks grouped by deadline
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  // Track expanded state for each group
  final Map<String, bool> _expandedGroups = {
    'today': true,
    'tomorrow': true,
    'thisWeek': false,
    'thisMonth': false,
    'later': false,
  };

  @override
  void initState() {
    super.initState();
    // Tasks auto-load with AsyncNotifier
    // Trigger refresh when screen opens to generate new tasks and handle expired ones
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskListNotifierProvider.notifier).refreshTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskListAsync = ref.watch(taskListNotifierProvider);

    // Handle loading and error states
    if (taskListAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (taskListAsync.hasError) {
      return Center(
        child: Text('Error: ${taskListAsync.error}'),
      );
    }

    final taskState = taskListAsync.value!;
    // Filter out deleted tasks
    final allTasks = taskState.todayTasks
        .where((task) => task.status != TaskStatus.deleted)
        .toList();

    if (allTasks.isEmpty) {
      return _buildEmptyState();
    }

    // Group tasks by deadline
    final groupedTasks = TaskGrouping.groupByDeadline(allTasks);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(taskListNotifierProvider.notifier).refreshTasks();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Render each group
          for (final groupKey in TaskGrouping.orderedGroupKeys)
            if (groupedTasks[groupKey]!.isNotEmpty)
              _buildTaskGroup(
                groupKey: groupKey,
                tasks: groupedTasks[groupKey]!,
              ),
        ],
      ),
    );
  }

  /// Build a task group with header and grid
  Widget _buildTaskGroup({
    required String groupKey,
    required List<TaskModel> tasks,
  }) {
    final isExpanded = _expandedGroups[groupKey] ?? false;
    final groupName = TaskGrouping.getGroupDisplayName(groupKey, tasks.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        InkWell(
          onTap: () {
            setState(() {
              _expandedGroups[groupKey] = !isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Expand/collapse icon
                Icon(
                  isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                  color: Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                // Group name
                Text(
                  groupName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Task grid (only shown when expanded)
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3 columns as per design
                childAspectRatio: 1.5, // Width:Height ratio
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return CompactTaskCard(
                  task: task,
                  onTap: () {}, // Empty onTap to enable gesture detection
                  onTapWithPosition: (position) => _showQuickMenu(task, position),
                );
              },
            ),
          ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.celebration,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks\nEnjoy your free time!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  void _showQuickMenu(TaskModel task, Offset tapPosition) {
    // Menu display conditions (see document/TechnicalDesign/BusinessLogic.md § 5.6.1)
    // Only active and completed tasks show the quick menu
    final shouldShowMenu = task.status == TaskStatus.active ||
                           task.status == TaskStatus.completed;

    // Active tasks with expired window should not show menu
    // (They will be auto-skipped by TaskRefreshService)
    final isExpiredActive = task.status == TaskStatus.active && task.isExpired;

    if (!shouldShowMenu || isExpiredActive) {
      // Don't show menu for skipped, deleted, or expired active tasks
      return;
    }

    // Show quick action menu at tap position
    TaskQuickMenu.show(context, task, tapPosition);
  }
}