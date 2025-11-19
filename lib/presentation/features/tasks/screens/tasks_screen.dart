import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/presentation/providers/task_state_provider.dart';
import 'package:myassistant/presentation/features/tasks/widgets/task_card.dart';
import 'package:myassistant/presentation/features/tasks/widgets/task_execution_dialog.dart';

/// Tasks screen - displays today's tasks
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load tasks on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskListProvider.notifier).loadTasks();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskListProvider);

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
                    const Icon(Icons.pending_actions, size: 18),
                    const SizedBox(width: 8),
                    Text('Active (${taskState.activeTasks.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 18),
                    const SizedBox(width: 8),
                    Text('Done (${taskState.completedTasks.length})'),
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.today, size: 18),
                    SizedBox(width: 8),
                    Text('All'),
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
              // Active tasks
              _buildTaskList(taskState.activeTasks, TaskStatus.active),

              // Completed tasks
              _buildTaskList(taskState.completedTasks, TaskStatus.completed),

              // All tasks
              _buildTaskList(taskState.todayTasks, null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList(List<TaskModel> tasks, TaskStatus? filterStatus) {
    if (tasks.isEmpty) {
      return _buildEmptyState(filterStatus);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(taskListProvider.notifier).refreshTasks();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return TaskCard(
            task: task,
            onTap: () {
              _showTaskDetails(task);
            },
            onComplete: task.status == TaskStatus.active
                ? () => _completeTask(task)
                : null,
            onSkip: task.status == TaskStatus.active
                ? () => _skipTask(task)
                : null,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(TaskStatus? filterStatus) {
    String message;
    IconData icon;

    if (filterStatus == TaskStatus.active) {
      message = 'No active tasks\nTake a break!';
      icon = Icons.coffee;
    } else if (filterStatus == TaskStatus.completed) {
      message = 'No completed tasks yet\nStart working on your tasks!';
      icon = Icons.pending_actions;
    } else {
      message = 'No tasks for today\nEnjoy your free time!';
      icon = Icons.celebration;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
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

  Future<void> _completeTask(TaskModel task) async {
    // Show appropriate execution dialog based on task type
    final completed = await TaskExecutionDialog.show(context, task);

    if (completed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task completed!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _skipTask(TaskModel task) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _SkipReasonDialog(),
    );

    if (reason != null) {
      await ref.read(taskListProvider.notifier).skipTask(
            task: task,
            skipReason: reason,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task skipped'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
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