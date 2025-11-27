import 'package:myassistant/data/models/task_model.dart';

/// Type of undo operation
enum UndoOperationType {
  completeTask,
  skipTask,
  incrementCount,
  decrementCount,
  reExecuteTask,
}

/// Represents an operation that can be undone
/// Stores complete task snapshot before modification
class UndoOperation {
  final UndoOperationType type;
  final String taskId;
  final TaskModel taskSnapshot;  // Complete snapshot before modification
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;  // For extra data like newTaskId

  UndoOperation({
    required this.type,
    required this.taskId,
    required this.taskSnapshot,
    required this.timestamp,
    this.metadata,
  });

  /// Get user-friendly description of the operation
  String get description {
    switch (type) {
      case UndoOperationType.completeTask:
        return '已撤销完成操作';
      case UndoOperationType.skipTask:
        return '已撤销跳过操作';
      case UndoOperationType.incrementCount:
      case UndoOperationType.decrementCount:
        return '已撤销计数变更';
      case UndoOperationType.reExecuteTask:
        return '已删除重复执行的任务';
    }
  }
}
