import 'package:mockito/annotations.dart';
import 'package:myassistant/domain/repositories/i_task_repository.dart';
import 'package:myassistant/domain/repositories/i_plan_repository.dart';
import 'package:myassistant/domain/repositories/i_goal_repository.dart';
import 'package:myassistant/data/services/task_generation_service.dart';

@GenerateMocks([
  ITaskRepository,
  IPlanRepository,
  IGoalRepository,
  TaskGenerationService,
])
void main() {}
