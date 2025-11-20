import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/presentation/features/tasks/screens/tasks_screen.dart';
import 'package:myassistant/presentation/features/planning/screens/planning_screen.dart';
import 'package:myassistant/presentation/features/review/screens/review_screen.dart';
import 'package:myassistant/presentation/features/profile/screens/profile_screen.dart';
import 'package:myassistant/presentation/features/planning/widgets/create_goal_dialog.dart';

/// Main home screen with bottom navigation
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const TasksScreen(),
    const PlanningScreen(),
    const ReviewScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    '任务',
    '计划',
    '回顾',
    '设置',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        actions: [
          if (_currentIndex == 0) // Tasks screen
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                // Filter tasks
                // TODO: Implement filter
              },
              tooltip: '筛选',
            ),
          if (_currentIndex == 1) // Planning screen
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                // Add goal
                _showAddGoalDialog();
              },
              tooltip: '添加目标',
            ),
          if (_currentIndex == 3) // Settings screen
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                // Show about
                _showAboutDialog();
              },
              tooltip: '关于',
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: '任务',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: '计划',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: '回顾',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    // Show FAB only on Tasks screen
    if (_currentIndex == 0) {
      return FloatingActionButton(
        onPressed: () {
          // Quick add task
          _showQuickAddTask();
        },
        tooltip: '快速添加任务',
        child: const Icon(Icons.add),
      );
    }
    return null;
  }

  void _showAddGoalDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateGoalDialog(),
    );

    if (result == true && mounted) {
      // Goal created successfully, refresh might happen via provider
      // The planning screen will automatically refresh via Riverpod
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('关于 MyAssistant'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('版本: 1.0.0'),
              SizedBox(height: 8),
              Text('个人任务管理应用'),
              SizedBox(height: 8),
              Text('帮助您管理目标、制定计划、追踪任务'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showQuickAddTask() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const _QuickAddTaskSheet(),
        );
      },
    );
  }
}

/// Quick add task bottom sheet
class _QuickAddTaskSheet extends ConsumerStatefulWidget {
  const _QuickAddTaskSheet();

  @override
  ConsumerState<_QuickAddTaskSheet> createState() => _QuickAddTaskSheetState();
}

class _QuickAddTaskSheetState extends ConsumerState<_QuickAddTaskSheet> {
  final _taskNameController = TextEditingController();

  @override
  void dispose() {
    _taskNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '快速添加任务',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _taskNameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '任务名称',
              hintText: '输入任务名称...',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addTask(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addTask,
                child: const Text('添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addTask() {
    final taskName = _taskNameController.text.trim();
    if (taskName.isEmpty) return;

    // TODO: Implement quick add task
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('任务 "$taskName" 将被添加'),
      ),
    );
    Navigator.pop(context);
  }
}