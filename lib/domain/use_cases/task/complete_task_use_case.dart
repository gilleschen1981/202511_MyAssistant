import 'package:myassistant/domain/use_cases/base_use_case.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/data_sources/local/dao/task_execution_dao.dart';

/// Parameters for completing a task
class CompleteTaskParams {
  final TaskModel task;
  final int? actualDurationMinutes;
  final String? evaluationResult;
  final String? executionNote;
  final int? counterValue;

  const CompleteTaskParams({
    required this.task,
    this.actualDurationMinutes,
    this.evaluationResult,
    this.executionNote,
    this.counterValue,
  });
}

/// Result of completing a task
class CompleteTaskResult {
  final TaskModel completedTask;
  final TaskModel? nextTask;
  final bool shouldGenerateNext;

  const CompleteTaskResult({
    required this.completedTask,
    this.nextTask,
    required this.shouldGenerateNext,
  });
}

/// Use case for completing a task
/// Encapsulates the business logic for task completion
class CompleteTaskUseCase extends BaseUseCase<UseCaseResult<CompleteTaskResult>, CompleteTaskParams> {
  final ITaskRepository _taskRepository;
  final TaskExecutionDao _executionDao;

  CompleteTaskUseCase(this._taskRepository, this._executionDao);

  @override
  Future<UseCaseResult<CompleteTaskResult>> call(CompleteTaskParams params) async {
    try {
      final task = params.task;

      // Validate task can be completed
      if (task.status != TaskStatus.active) {
        return UseCaseResult.failure('Task is not active (current status: ${task.status})');
      }

      if (task.isExpired) {
        return const UseCaseResult.failure('Cannot complete expired task');
      }

      // Validate timer configuration
      if (task.config.durationMinutes != null && params.actualDurationMinutes == null) {
        return const UseCaseResult.failure('Timer duration is required for timer tasks');
      }

      // Validate counter configuration
      if (task.config.repeatCount != null && params.counterValue == null) {
        return const UseCaseResult.failure('Counter value is required for counter tasks');
      }

      // Validate evaluation configuration
      if (task.config.evaluationOptions != null && params.evaluationResult == null) {
        return const UseCaseResult.failure('Evaluation result is required for evaluation tasks');
      }

      // Complete the task through repository
      final completedTask = await _taskRepository.completeTask(
        taskId: task.id,
        actualDurationMinutes: params.actualDurationMinutes,
        evaluationResult: params.evaluationResult,
        executionNote: params.executionNote,
      );

      // Record execution in task_executions table
      await _executionDao.createFromTaskCompletion(
        taskId: task.id,
        userId: task.userId,
        executionType: _getExecutionType(task.config),
        startedAt: DateTime.now().subtract(
          Duration(minutes: params.actualDurationMinutes ?? 0),
        ),
        completedAt: DateTime.now(),
        durationMinutes: params.actualDurationMinutes,
        counterValue: params.counterValue,
        evaluationScore: params.evaluationResult,
        notes: params.executionNote,
      );

      // Check if next task should be generated
      TaskModel? nextTask;
      bool shouldGenerateNext = false;

      // For tasks with repeat configuration, check if we can repeat
      if (task.canRepeat && !task.isExpired) {
        shouldGenerateNext = true;
        // Note: Actual generation would be handled by TaskGenerationService
        // This use case just indicates that generation is needed
      }

      return UseCaseResult.success(
        CompleteTaskResult(
          completedTask: completedTask,
          nextTask: nextTask,
          shouldGenerateNext: shouldGenerateNext,
        ),
      );
    } catch (e) {
      return UseCaseResult.failure('Failed to complete task: ${e.toString()}');
    }
  }

  String _getExecutionType(TaskConfiguration config) {
    if (config.durationMinutes != null && config.repeatCount != null) {
      return 'timerWithCount';
    } else if (config.repeatCount != null && config.evaluationOptions != null) {
      return 'countWithEvaluation';
    } else if (config.durationMinutes != null) {
      return 'timer';
    } else if (config.repeatCount != null) {
      return 'counter';
    } else if (config.evaluationOptions != null) {
      return 'evaluation';
    } else {
      return 'simple';
    }
  }
}