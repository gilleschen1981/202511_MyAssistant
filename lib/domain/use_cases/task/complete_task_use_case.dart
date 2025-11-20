import 'package:myassistant/domain/use_cases/base_use_case.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/data/models/task_model.dart';
import 'package:myassistant/data/models/enums/status.dart';

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

  CompleteTaskUseCase(this._taskRepository);

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

      // Note: Task regeneration is handled by TaskGenerationService
      // based on plan's repeat rules, not individual task properties

      return UseCaseResult.success(
        CompleteTaskResult(
          completedTask: completedTask,
          nextTask: null,
          shouldGenerateNext: false,
        ),
      );
    } catch (e) {
      return UseCaseResult.failure('Failed to complete task: ${e.toString()}');
    }
  }
}