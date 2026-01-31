import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:intl/intl.dart';

/// Task history calendar widget
///
/// Displays task completion history in a calendar view with:
/// - Color-coded task status (completed: green, skipped: orange)
/// - Special colors for evaluation tasks based on evaluation results
/// - Count indicator when multiple tasks completed on same day
class TaskHistoryCalendar extends StatefulWidget {
  final Map<DateTime, List<TaskModel>> tasksByDate;

  const TaskHistoryCalendar({
    super.key,
    required this.tasksByDate,
  });

  @override
  State<TaskHistoryCalendar> createState() => _TaskHistoryCalendarState();
}

class _TaskHistoryCalendarState extends State<TaskHistoryCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Calendar
        TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now(),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarStyle: CalendarStyle(
            markersMaxCount: 1,
            markerDecoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            selectedDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            // Custom marker builder for each day
            markerBuilder: (context, date, events) {
              return _buildDayMarker(context, date);
            },
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextFormatter: (date, locale) =>
                DateFormat('yyyy年MM月', locale).format(date),
          ),
        ),

        const SizedBox(height: 16),

        // Selected day tasks
        if (_selectedDay != null) _buildSelectedDayTasks(context),

        // Legend
        const SizedBox(height: 16),
        _buildLegend(context),
      ],
    );
  }

  /// Build marker for a specific day
  Widget? _buildDayMarker(BuildContext context, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final tasksForDay = widget.tasksByDate[normalizedDate];

    if (tasksForDay == null || tasksForDay.isEmpty) {
      return null;
    }

    // Get task statistics for this day
    final stats = _getTaskStatsForDay(tasksForDay);

    // Determine color based on task type and status
    final color = _getDayColor(tasksForDay, stats);

    // Check if we need to show count
    final showCount = stats.totalCompleted > 1 || stats.totalSkipped > 1;

    return Positioned(
      bottom: 1,
      child: Container(
        width: 40,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
        child: showCount
            ? Center(
                child: Text(
                  '${stats.totalCompleted + stats.totalSkipped}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  /// Get color for a day based on tasks
  Color _getDayColor(List<TaskModel> tasks, _DayTaskStats stats) {
    // If there are evaluation tasks, use evaluation-based color
    if (stats.hasEvaluationTask) {
      return _getEvaluationColor(tasks);
    }

    // If all tasks are skipped, use skip color
    if (stats.totalSkipped > 0 && stats.totalCompleted == 0) {
      return Colors.orange;
    }

    // If all tasks are completed, use complete color
    if (stats.totalCompleted > 0 && stats.totalSkipped == 0) {
      return Colors.green;
    }

    // Mixed: both completed and skipped
    if (stats.totalCompleted > 0 && stats.totalSkipped > 0) {
      return Colors.amber;
    }

    return Colors.grey;
  }

  /// Get color based on evaluation results
  Color _getEvaluationColor(List<TaskModel> tasks) {
    // Find evaluation tasks
    final evalTasks = tasks.where((t) =>
        t.config.evaluationOptions != null &&
        t.config.evaluationOptions!.isNotEmpty &&
        t.evaluationResult != null).toList();

    if (evalTasks.isEmpty) {
      return Colors.green; // Default to green if no evaluation
    }

    // Get the first evaluation result as representative
    // In the future, we could average or aggregate multiple evaluations
    final evaluationResult = evalTasks.first.evaluationResult!;
    final evaluationOptions = evalTasks.first.config.evaluationOptions!;

    // Map evaluation result to color based on position in options
    // Assuming options are ordered from best to worst
    final index = evaluationOptions.indexOf(evaluationResult);
    if (index < 0) return Colors.grey;

    final normalizedScore = 1 - (index / (evaluationOptions.length - 1));

    if (normalizedScore >= 0.8) {
      return Colors.green; // 优秀
    } else if (normalizedScore >= 0.6) {
      return Colors.lightGreen; // 良好
    } else if (normalizedScore >= 0.4) {
      return Colors.yellow; // 及格
    } else {
      return Colors.orange; // 不及格
    }
  }

  /// Get task statistics for a specific day
  _DayTaskStats _getTaskStatsForDay(List<TaskModel> tasks) {
    var totalCompleted = 0;
    var totalSkipped = 0;
    var hasEvaluationTask = false;

    for (final task in tasks) {
      if (task.status == TaskStatus.completed) {
        totalCompleted++;
      } else if (task.status == TaskStatus.skipped) {
        totalSkipped++;
      }

      if (task.config.evaluationOptions != null &&
          task.config.evaluationOptions!.isNotEmpty) {
        hasEvaluationTask = true;
      }
    }

    return _DayTaskStats(
      totalCompleted: totalCompleted,
      totalSkipped: totalSkipped,
      hasEvaluationTask: hasEvaluationTask,
    );
  }

  /// Build tasks list for selected day
  Widget _buildSelectedDayTasks(BuildContext context) {
    final normalizedDate = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );
    final tasks = widget.tasksByDate[normalizedDate];

    if (tasks == null || tasks.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('当天没有任务记录'),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              DateFormat('yyyy年MM月dd日').format(_selectedDay!),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Divider(height: 1),
          ...tasks.map((task) => _buildTaskListItem(context, task)),
        ],
      ),
    );
  }

  /// Build a single task list item
  Widget _buildTaskListItem(BuildContext context, TaskModel task) {
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
      dense: true,
      leading: Icon(statusIcon, color: statusColor, size: 20),
      title: Text(
        task.name,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusText,
            style: TextStyle(color: statusColor, fontSize: 12),
          ),
          if (task.completedAt != null)
            Text(
              '完成于: ${DateFormat('HH:mm').format(task.completedAt!)}',
              style: const TextStyle(fontSize: 11),
            ),
          if (task.actualDurationMinutes != null)
            Text(
              '用时: ${task.actualDurationMinutes} 分钟',
              style: const TextStyle(fontSize: 11),
            ),
          if (task.evaluationResult != null)
            Text(
              '评价: ${task.evaluationResult}',
              style: const TextStyle(fontSize: 11),
            ),
        ],
      ),
    );
  }

  /// Build legend to explain colors
  Widget _buildLegend(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '图例',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildLegendItem('已完成', Colors.green),
                _buildLegendItem('已跳过', Colors.orange),
                _buildLegendItem('混合', Colors.amber),
                _buildLegendItem('优秀', Colors.green),
                _buildLegendItem('良好', Colors.lightGreen),
                _buildLegendItem('及格', Colors.yellow),
                _buildLegendItem('不及格', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build a single legend item
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

/// Task statistics for a specific day
class _DayTaskStats {
  final int totalCompleted;
  final int totalSkipped;
  final bool hasEvaluationTask;

  _DayTaskStats({
    required this.totalCompleted,
    required this.totalSkipped,
    required this.hasEvaluationTask,
  });
}