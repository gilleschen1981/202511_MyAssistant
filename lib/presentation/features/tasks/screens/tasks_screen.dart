import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/presentation/providers/task_state_provider.dart';
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

  // Track last tap position for quick menu
  Offset _lastTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    // Load tasks on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskListProvider.notifier).loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskListProvider);
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
        await ref.read(taskListProvider.notifier).refreshTasks();
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
                return GestureDetector(
                  onTapDown: (details) {
                    // Store tap position for menu
                    _lastTapPosition = details.globalPosition;
                  },
                  child: CompactTaskCard(
                    task: task,
                    onTap: () => _showQuickMenu(task),
                  ),
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

  void _showQuickMenu(TaskModel task) {
    // Show quick action menu at tap position
    TaskQuickMenu.show(context, task, _lastTapPosition);
  }
}