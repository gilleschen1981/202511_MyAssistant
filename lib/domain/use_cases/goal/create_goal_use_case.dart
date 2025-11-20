import 'package:myassistant/domain/use_cases/base_use_case.dart';
import 'package:myassistant/domain/repositories/i_goal_repository.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/enums/status.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:uuid/uuid.dart';

/// Parameters for creating a goal
class CreateGoalParams {
  final String userId;
  final String title;
  final String? description;
  final List<String>? tags;
  final DateTime? deadline;
  final Priority priority;
  final String? successCriteria;

  const CreateGoalParams({
    required this.userId,
    required this.title,
    this.description,
    this.tags,
    this.deadline,
    this.priority = Priority.medium,
    this.successCriteria,
  });
}

/// Use case for creating a new goal
/// Encapsulates the business logic for goal creation
class CreateGoalUseCase extends BaseUseCase<UseCaseResult<GoalModel>, CreateGoalParams> {
  final IGoalRepository _goalRepository;
  final _uuid = const Uuid();

  CreateGoalUseCase(this._goalRepository);

  @override
  Future<UseCaseResult<GoalModel>> call(CreateGoalParams params) async {
    try {
      // Validate input
      if (params.title.trim().isEmpty) {
        return const UseCaseResult.failure('Goal title cannot be empty');
      }

      if (params.title.length > 200) {
        return const UseCaseResult.failure('Goal title is too long (max 200 characters)');
      }

      if (params.deadline != null && params.deadline!.isBefore(DateTime.now())) {
        return const UseCaseResult.failure('Deadline cannot be in the past');
      }

      // Create goal model
      final now = DateTime.now();
      final goal = GoalModel(
        id: _uuid.v4(),
        userId: params.userId,
        title: params.title.trim(),
        description: params.description?.trim(),
        tags: params.tags ?? const [],
        deadline: params.deadline,
        priority: params.priority,
        status: GoalStatus.active,
        successCriteria: params.successCriteria?.trim(),
        planIds: const [], // New goal has no plans yet
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      );

      // Save to repository - pass the created goal
      final savedGoal = await _goalRepository.createGoal(
        userId: goal.userId,
        title: goal.title,
        description: goal.description,
        tags: goal.tags,
        deadline: goal.deadline,
        priority: goal.priority,
        successCriteria: goal.successCriteria,
      );

      return UseCaseResult.success(savedGoal);
    } catch (e) {
      return UseCaseResult.failure('Failed to create goal: ${e.toString()}');
    }
  }
}