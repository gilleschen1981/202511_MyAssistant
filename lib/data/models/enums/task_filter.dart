/// Task filter options for filtering task list
enum TaskFilter {
  /// All tasks regardless of status
  all('全部'),

  /// Only active tasks (pending execution)
  active('待执行'),

  /// Only completed tasks
  completed('已完成'),

  /// Only skipped tasks
  skipped('已跳过');

  const TaskFilter(this.label);

  /// Display label for the filter
  final String label;
}
