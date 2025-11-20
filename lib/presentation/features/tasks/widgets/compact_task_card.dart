import 'package:flutter/material.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';

/// Compact task card for grid layout
/// Design based on TaskView.md specification
class CompactTaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;

  const CompactTaskCard({
    super.key,
    required this.task,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = task.status == TaskStatus.completed;
    final isSkipped = task.status == TaskStatus.skipped;

    Color backgroundColor;
    Color? borderColor;
    TextDecoration? textDecoration;

    // Status-based styling (TaskView.md spec)
    if (isCompleted) {
      backgroundColor = const Color(0xFFE8F5E9); // Completed: light green
      borderColor = null;
      textDecoration = null;
    } else if (isSkipped) {
      backgroundColor = const Color(0xFFF5F5F5); // Skipped: gray
      borderColor = null;
      textDecoration = TextDecoration.lineThrough;
    } else {
      backgroundColor = Colors.white; // Active: white + blue left border
      borderColor = const Color(0xFF2196F3);
      textDecoration = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64, // TaskView.md spec
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: borderColor != null
              ? Border(left: BorderSide(color: borderColor, width: 4))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task name (14sp, TaskView.md spec)
            Text(
              task.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: textDecoration,
                color: isCompleted || isSkipped
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Task info (12sp gray, TaskView.md spec)
            _buildTaskInfo(theme),
          ],
        ),
      ),
    );
  }

  /// Build task info based on configuration
  /// According to TaskView.md design patterns
  Widget _buildTaskInfo(ThemeData theme) {
    final config = task.config;
    String infoText = '';

    // Timer + Counter combination
    if (config.durationMinutes != null && config.repeatCount != null) {
      infoText = '${config.durationMinutes}分×(${task.currentCount}/${config.repeatCount})';
    }
    // Counter + Evaluation combination
    else if (config.repeatCount != null && config.evaluationOptions != null && config.evaluationOptions!.isNotEmpty) {
      infoText = '(${task.currentCount}/${config.repeatCount})·⭐评价';
    }
    // Pure timer
    else if (config.durationMinutes != null) {
      infoText = '${config.durationMinutes}分钟';
    }
    // Pure counter
    else if (config.repeatCount != null) {
      infoText = '(${task.currentCount}/${config.repeatCount})';
    }
    // Pure evaluation
    else if (config.evaluationOptions != null && config.evaluationOptions!.isNotEmpty) {
      infoText = '⭐ 评价';
    }
    // Simple task - no need to show deadline (always 23:59)
    else {
      infoText = '';
    }

    return Text(
      infoText,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
