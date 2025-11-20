import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/presentation/providers/task_state_provider.dart';
import 'package:myassistant/presentation/features/tasks/widgets/compact_task_card.dart';
import 'package:myassistant/presentation/features/tasks/widgets/task_execution_dialog.dart';
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
                return CompactTaskCard(
                  task: task,
                  onTap: () => _showTaskDetails(task),
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

  void _showTaskDetails(TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TaskDetailsSheet(task: task),
    );
  }
}

/// Task details bottom sheet
class _TaskDetailsSheet extends ConsumerWidget {
  final TaskModel task;

  const _TaskDetailsSheet({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  task.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          if (task.description != null) ...[
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(task.description!),
            const SizedBox(height: 16),
          ],

          // Task type info
          _buildInfoRow(
            context,
            'Type',
            task.config.taskType.name,
            Icons.category,
          ),
          const SizedBox(height: 8),

          // Status
          _buildInfoRow(
            context,
            'Status',
            task.status.name,
            Icons.info,
          ),
          const SizedBox(height: 8),

          // Window time
          _buildInfoRow(
            context,
            'Time Window',
            '${_formatTime(task.windowStartTime)} - ${_formatTime(task.windowEndTime)}',
            Icons.schedule,
          ),

          const SizedBox(height: 24),

          // Actions
          if (task.status == TaskStatus.active) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final reason = await showDialog<String>(
                        context: context,
                        builder: (context) => _SkipReasonDialog(),
                      );

                      if (reason != null && context.mounted) {
                        await ref.read(taskListProvider.notifier).skipTask(
                              task: task,
                              skipReason: reason,
                            );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Task skipped'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final completed = await TaskExecutionDialog.show(context, task);
                      if (completed == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Task completed!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    child: const Text('Complete'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Skip reason dialog
class _SkipReasonDialog extends StatefulWidget {
  @override
  State<_SkipReasonDialog> createState() => _SkipReasonDialogState();
}

class _SkipReasonDialogState extends State<_SkipReasonDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Skip Task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Why are you skipping this task?'),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              hintText: 'Enter reason (optional)',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, _reasonController.text);
          },
          child: const Text('Skip'),
        ),
      ],
    );
  }
}