import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/goal_model.dart';
import 'package:myassistant/data/models/enums/priority.dart';
import 'package:myassistant/presentation/providers/goal_state_provider.dart';

/// Dialog for editing an existing goal
class EditGoalDialog extends ConsumerStatefulWidget {
  final GoalModel goal;

  const EditGoalDialog({
    super.key,
    required this.goal,
  });

  @override
  ConsumerState<EditGoalDialog> createState() => _EditGoalDialogState();
}

class _EditGoalDialogState extends ConsumerState<EditGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  late final TextEditingController _successCriteriaController;

  DateTime? _selectedDeadline;
  late Priority _selectedPriority;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with current goal data
    _titleController = TextEditingController(text: widget.goal.title);
    _descriptionController = TextEditingController(text: widget.goal.description ?? '');
    _tagsController = TextEditingController(text: widget.goal.tags.join(', '));
    _successCriteriaController = TextEditingController(text: widget.goal.successCriteria ?? '');

    _selectedDeadline = widget.goal.deadline;
    _selectedPriority = widget.goal.priority;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _successCriteriaController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: '选择截止日期',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (picked != null && picked != _selectedDeadline) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  void _clearDeadline() {
    setState(() {
      _selectedDeadline = null;
    });
  }

  Future<void> _updateGoal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse tags
      final tagsText = _tagsController.text.trim();
      final tags = tagsText.isNotEmpty
          ? tagsText.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList()
          : <String>[];

      // Prepare data
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final successCriteria = _successCriteriaController.text.trim().isEmpty
          ? null
          : _successCriteriaController.text.trim();

      // Update goal
      final result = await ref.read(goalListProvider.notifier).updateGoal(
        goalId: widget.goal.id,
        title: title,
        description: description,
        deadline: _selectedDeadline,
        priority: _selectedPriority,
        tags: tags,
        successCriteria: successCriteria,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result != null) {
        Navigator.pop(context, result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('目标更新成功！'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('更新目标失败，请重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Extract error message from exception
      String errorMessage = e.toString();
      // Remove common exception prefixes for cleaner display
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      } else if (errorMessage.startsWith('ValidationException: ')) {
        errorMessage = errorMessage.substring('ValidationException: '.length);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4), // Give user time to read
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Text(
                  '编辑目标',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Goal Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '目标标题 *',
                    hintText: '输入您的目标...',
                    prefixIcon: Icon(Icons.flag),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入目标标题';
                    }
                    return null;
                  },
                  maxLength: 100,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '目标描述',
                    hintText: '详细描述您的目标...',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  maxLength: 500,
                ),
                const SizedBox(height: 16),

                // Deadline
                InkWell(
                  onTap: _selectDeadline,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: '截止日期',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: const OutlineInputBorder(),
                      suffixIcon: _selectedDeadline != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearDeadline,
                              tooltip: '清除截止日期',
                            )
                          : const Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _selectedDeadline != null
                          ? '${_selectedDeadline!.year}年${_selectedDeadline!.month}月${_selectedDeadline!.day}日'
                          : '选择截止日期（可选）',
                      style: _selectedDeadline != null
                          ? null
                          : TextStyle(color: theme.hintColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Priority
                DropdownButtonFormField<Priority>(
                  value: _selectedPriority,
                  decoration: const InputDecoration(
                    labelText: '优先级',
                    prefixIcon: Icon(Icons.priority_high),
                    border: OutlineInputBorder(),
                  ),
                  items: Priority.values.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag,
                            size: 16,
                            color: _getPriorityColor(priority),
                          ),
                          const SizedBox(width: 8),
                          Text(_getPriorityLabel(priority)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedPriority = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Tags
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: '标签',
                    hintText: '输入标签，用逗号分隔（例如：健康，学习，工作）',
                    prefixIcon: Icon(Icons.label),
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 100,
                ),
                const SizedBox(height: 16),

                // Success Criteria
                TextFormField(
                  controller: _successCriteriaController,
                  decoration: const InputDecoration(
                    labelText: '成功标准',
                    hintText: '如何判断目标是否达成？',
                    prefixIcon: Icon(Icons.check_circle_outline),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 2,
                  maxLength: 200,
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isLoading ? null : _updateGoal,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('更新'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return Colors.red;
      case Priority.medium:
        return Colors.orange;
      case Priority.low:
        return Colors.blue;
    }
  }

  String _getPriorityLabel(Priority priority) {
    switch (priority) {
      case Priority.high:
        return '高';
      case Priority.medium:
        return '中';
      case Priority.low:
        return '低';
    }
  }
}
