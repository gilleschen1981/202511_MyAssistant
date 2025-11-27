import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/presentation/providers/task_list_notifier.dart';
import 'package:myassistant/presentation/features/tasks/widgets/compact_task_card.dart';
import 'package:myassistant/presentation/features/tasks/widgets/task_quick_menu.dart';
import 'package:myassistant/presentation/features/tasks/widgets/task_filter_bar.dart';
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
    // Use filtered tasks instead of all today tasks
    final displayTasks = taskState.filteredTasks
        .where((task) => task.status != TaskStatus.deleted)
        .toList();

    if (displayTasks.isEmpty) {
      return Column(
        children: [
          // Undo button and Filter bar row
          Container(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
            child: Row(
              children: [
                // Undo button
                _buildUndoButton(taskState),
                const SizedBox(width: 4),
                // Filter bar
                const Expanded(child: TaskFilterBar()),
              ],
            ),
          ),
          Expanded(child: _buildEmptyState()),
        ],
      );
    }

    // Group tasks by deadline
    final groupedTasks = TaskGrouping.groupByDeadline(displayTasks);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(taskListNotifierProvider.notifier).refreshTasks();
      },
      child: Column(
        children: [
          // Undo button and Filter bar row
          Container(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
            child: Row(
              children: [
                // Undo button
                _buildUndoButton(taskState),
                const SizedBox(width: 4),
                // Filter bar
                const Expanded(child: TaskFilterBar()),
              ],
            ),
          ),
          // Task list
          Expanded(
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
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '暂无任务',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '创建计划后将自动生成任务',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUndoButton(TaskListState taskState) {
    final hasUndoOperation = taskState.lastOperation != null;

    return IconButton(
      icon: const Icon(Icons.undo, size: 20),
      iconSize: 20,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(
        minWidth: 36,
        minHeight: 36,
      ),
      onPressed: hasUndoOperation
        ? () async {
            final operation = taskState.lastOperation;
            await ref.read(taskListNotifierProvider.notifier).undoLastOperation();
            // Show undo feedback
            if (mounted && operation != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(operation.description),
                  backgroundColor: Colors.blue,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        : null,
      color: hasUndoOperation
        ? Theme.of(context).colorScheme.primary
        : Colors.grey,
      tooltip: '撤销',
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