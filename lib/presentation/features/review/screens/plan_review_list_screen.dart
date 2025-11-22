import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myassistant/presentation/providers/plan_review_provider.dart';
import 'package:myassistant/presentation/providers/auth_state_provider.dart';
import 'package:myassistant/presentation/features/review/widgets/plan_review_card.dart';
import 'package:myassistant/di/providers/repository_providers.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:intl/intl.dart';

/// Plan Review List Screen - shows all plans with their statistics
class PlanReviewListScreen extends ConsumerStatefulWidget {
  const PlanReviewListScreen({super.key});

  @override
  ConsumerState<PlanReviewListScreen> createState() => _PlanReviewListScreenState();
}

class _PlanReviewListScreenState extends ConsumerState<PlanReviewListScreen> {
  String? _selectedGoalId;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Load reviews on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.read(planReviewListProvider(user.id).notifier).loadPlanReviews();
      }
    });
  }

  void _applyFilters(String userId) {
    if (_selectedGoalId != null) {
      ref.read(planReviewListProvider(userId).notifier).loadGoalPlanReviews(_selectedGoalId!);
    } else if (_selectedDateRange != null) {
      ref.read(planReviewListProvider(userId).notifier).loadPlanReviewsByDateRange(
        _selectedDateRange!.start,
        _selectedDateRange!.end,
      );
    } else {
      ref.read(planReviewListProvider(userId).notifier).loadPlanReviews();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Center(
        child: Text('请先登录'),
      );
    }

    final state = ref.watch(planReviewListProvider(user.id));

    return Column(
      children: [
        // Summary statistics header
        if (state.summaryStats != null)
          _buildSummaryHeader(context, state.summaryStats!),

        // Filter and sort options
        _buildFilterBar(context, user.id),

        // Reviews list
        Expanded(
          child: _buildReviewsList(context, state, user.id),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader(
    BuildContext context,
    Map<String, dynamic> stats,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '回顾总览',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: '总计划数',
                  value: stats['totalPlans'].toString(),
                  icon: Icons.folder_outlined,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: '进行中',
                  value: stats['activePlans'].toString(),
                  icon: Icons.play_circle_outline,
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: '总任务',
                  value: stats['totalTasks'].toString(),
                  icon: Icons.task_alt,
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: '平均完成率',
                  value: '${(stats['averageCompletionRate'] * 100).toStringAsFixed(0)}%',
                  icon: Icons.trending_up,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final itemColor = color ?? theme.colorScheme.primary;

    return Column(
      children: [
        Icon(icon, size: 24, color: itemColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: itemColor,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context, String userId) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Row(
            children: [
              // Sort button
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: '排序',
                onSelected: (value) {
                  final notifier = ref.read(planReviewListProvider(userId).notifier);
                  switch (value) {
                    case 'completion_desc':
                      notifier.sortByCompletionRate(ascending: false);
                      break;
                    case 'completion_asc':
                      notifier.sortByCompletionRate(ascending: true);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'completion_desc',
                    child: Text('完成率：高到低'),
                  ),
                  const PopupMenuItem(
                    value: 'completion_asc',
                    child: Text('完成率：低到高'),
                  ),
                ],
              ),

              const SizedBox(width: 8),

              // Goal filter button
              if (user != null)
                _buildGoalFilterButton(context, userId, user.id),

              const SizedBox(width: 8),

              // Date range filter button
              _buildDateRangeFilterButton(context, userId),

              const Spacer(),

              // Refresh button
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '刷新',
                onPressed: () {
                  setState(() {
                    _selectedGoalId = null;
                    _selectedDateRange = null;
                  });
                  ref.read(planReviewListProvider(userId).notifier).loadPlanReviews();
                },
              ),
            ],
          ),

          // Active filters display
          if (_selectedGoalId != null || _selectedDateRange != null) ...[
            const SizedBox(height: 8),
            _buildActiveFilters(context, userId),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalFilterButton(BuildContext context, String userId, String currentUserId) {
    return FutureBuilder<List<GoalModel>>(
      future: ref.read(goalRepositoryProvider).getUserGoals(currentUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final goals = snapshot.data!;
        if (goals.isEmpty) {
          return const SizedBox.shrink();
        }

        return PopupMenuButton<String?>(
          icon: Icon(
            Icons.filter_list,
            color: _selectedGoalId != null ? Theme.of(context).colorScheme.primary : null,
          ),
          tooltip: '按目标筛选',
          onSelected: (goalId) {
            setState(() {
              _selectedGoalId = goalId;
              _selectedDateRange = null;
            });
            _applyFilters(userId);
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String?>(
              value: null,
              child: Text('全部目标'),
            ),
            ...goals.map((goal) => PopupMenuItem<String?>(
              value: goal.id,
              child: Text(goal.title),
            )),
          ],
        );
      },
    );
  }

  Widget _buildDateRangeFilterButton(BuildContext context, String userId) {
    return IconButton(
      icon: Icon(
        Icons.date_range,
        color: _selectedDateRange != null ? Theme.of(context).colorScheme.primary : null,
      ),
      tooltip: '按日期范围筛选',
      onPressed: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: _selectedDateRange,
        );

        if (picked != null) {
          setState(() {
            _selectedDateRange = picked;
            _selectedGoalId = null;
          });
          _applyFilters(userId);
        }
      },
    );
  }

  Widget _buildActiveFilters(BuildContext context, String userId) {
    return Wrap(
      spacing: 8,
      children: [
        if (_selectedGoalId != null)
          FutureBuilder<GoalModel?>(
            future: ref.read(goalRepositoryProvider).getGoalById(_selectedGoalId!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final goal = snapshot.data!;

              return Chip(
                label: Text('目标: ${goal.title}'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    _selectedGoalId = null;
                  });
                  _applyFilters(userId);
                },
              );
            },
          ),
        if (_selectedDateRange != null)
          Chip(
            label: Text(
              '${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.start)} - ${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.end)}',
            ),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () {
              setState(() {
                _selectedDateRange = null;
              });
              _applyFilters(userId);
            },
          ),
      ],
    );
  }

  Widget _buildReviewsList(
    BuildContext context,
    PlanReviewListState state,
    String userId,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(planReviewListProvider(userId).notifier).loadPlanReviews();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.reviews.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(planReviewListProvider(userId).notifier).loadPlanReviews();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.reviews.length,
        itemBuilder: (context, index) {
          final review = state.reviews[index];
          return PlanReviewCard(
            review: review,
            onTap: () {
              // Navigate to plan detail review page
              context.push('/review/plan/${review.plan.id}');
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assessment_outlined,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '暂无计划',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '创建您的第一个计划开始追踪进度',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                // Navigate to planning screen
                context.go('/planning');
              },
              icon: const Icon(Icons.add),
              label: const Text('创建计划'),
            ),
          ],
        ),
      ),
    );
  }
}
