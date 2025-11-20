import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/data/models/enums/task_type.dart';
import 'package:myassistant/presentation/providers/plan_state_provider.dart';

/// Dialog for creating a new plan
class CreatePlanDialog extends ConsumerStatefulWidget {
  final String goalId;
  final String goalTitle;

  const CreatePlanDialog({
    super.key,
    required this.goalId,
    required this.goalTitle,
  });

  @override
  ConsumerState<CreatePlanDialog> createState() => _CreatePlanDialogState();
}

class _CreatePlanDialogState extends ConsumerState<CreatePlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Time settings
  DateTime? _startDate;
  DateTime? _endDate;
  RepeatType _repeatType = RepeatType.oneTime;
  int? _customDays;

  // Task configuration - optional fields that determine task type
  int? _durationMinutes;
  int? _repeatCount;
  final List<String> _evaluationOptions = [];
  final _evaluationController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Set default start date to today
    _startDate = DateTime.now();
    // Set default end date to 7 days from now
    _endDate = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _evaluationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '创建新计划',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '目标: ${widget.goalTitle}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Plan name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '计划名称',
                          hintText: '例如: 每日晨跑计划',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.edit),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入计划名称';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: '计划描述 (可选)',
                          hintText: '描述这个计划的目的和内容',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Time settings
                      Text(
                        '时间设置',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Start date
                      _buildDateField(
                        context,
                        label: '开始日期',
                        date: _startDate,
                        onTap: () => _selectStartDate(context),
                      ),
                      const SizedBox(height: 12),

                      // End date
                      _buildDateField(
                        context,
                        label: '结束日期',
                        date: _endDate,
                        onTap: () => _selectEndDate(context),
                      ),
                      const SizedBox(height: 12),

                      // Repeat type
                      DropdownButtonFormField<RepeatType>(
                        value: _repeatType,
                        decoration: const InputDecoration(
                          labelText: '重复频率',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.repeat),
                        ),
                        items: RepeatType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getRepeatTypeLabel(type)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _repeatType = value!;
                          });
                        },
                      ),

                      // Custom days for custom repeat type
                      if (_repeatType == RepeatType.custom) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: '自定义间隔天数',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                            suffix: Text('天'),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _customDays = int.tryParse(value);
                          },
                          validator: (value) {
                            if (_repeatType == RepeatType.custom) {
                              final days = int.tryParse(value ?? '');
                              if (days == null || days <= 0) {
                                return '请输入有效的天数';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Task configuration
                      Text(
                        '任务配置 (可选)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '根据需要配置以下选项，不同的组合会形成不同类型的任务',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Duration configuration
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: '计时时长 (可选)',
                          hintText: '例如: 30',
                          helperText: '设置任务需要计时的时长',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timer),
                          suffixText: '分钟',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            _durationMinutes = value.isEmpty ? null : int.tryParse(value);
                          });
                        },
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final duration = int.tryParse(value);
                            if (duration == null || duration <= 0) {
                              return '请输入有效的时长';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Repeat count configuration
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: '重复次数 (可选)',
                          hintText: '例如: 10',
                          helperText: '设置任务需要重复的次数',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.repeat_one),
                          suffixText: '次',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            _repeatCount = value.isEmpty ? null : int.tryParse(value);
                          });
                        },
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final count = int.tryParse(value);
                            if (count == null || count <= 0) {
                              return '请输入有效的次数';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Evaluation options configuration
                      Text(
                        '评估选项 (可选)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '添加评估选项可以在完成任务时对任务质量进行评价',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _evaluationController,
                              decoration: const InputDecoration(
                                hintText: '例如: 优秀、良好、一般',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _addEvaluationOption(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _addEvaluationOption,
                            icon: const Icon(Icons.add_circle),
                            color: theme.colorScheme.primary,
                            tooltip: '添加选项',
                          ),
                        ],
                      ),
                      if (_evaluationOptions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _evaluationOptions.map((option) {
                            return Chip(
                              label: Text(option),
                              onDeleted: () {
                                setState(() {
                                  _evaluationOptions.remove(option);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],

                      // Warning about timer + evaluation constraint
                      if (_durationMinutes != null && _evaluationOptions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: theme.colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '计时和评估不能同时使用',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('创建计划'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          date != null ? _formatDate(date) : '选择日期',
          style: date != null ? null : TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Ensure end date is after start date
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked.add(const Duration(days: 7));
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate?.add(const Duration(days: 7)) ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _addEvaluationOption() {
    final option = _evaluationController.text.trim();
    if (option.isNotEmpty && !_evaluationOptions.contains(option)) {
      setState(() {
        _evaluationOptions.add(option);
        _evaluationController.clear();
      });
    }
  }


  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validation: timer and evaluation cannot coexist
    if (_durationMinutes != null && _evaluationOptions.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('计时和评估不能同时使用')),
      );
      return;
    }

    // Validation: evaluation needs at least 2 options
    if (_evaluationOptions.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('评估选项至少需要2个，或者不添加')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择开始和结束日期')),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('结束日期必须晚于开始日期')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Create task configuration
      final taskConfig = TaskConfiguration(
        durationMinutes: _durationMinutes,
        repeatCount: _repeatCount,
        evaluationOptions: _evaluationOptions.isNotEmpty ? _evaluationOptions : null,
      );

      // Create repeat rule
      final repeatRule = RepeatRule(
        type: _repeatType,
        customDays: _repeatType == RepeatType.custom ? _customDays : null,
      );

      // Create plan
      final plan = await ref.read(planListProvider.notifier).createPlan(
        goalId: widget.goalId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        startDate: _startDate!,
        endDate: _endDate!,
        repeatRule: repeatRule,
        taskConfig: taskConfig,
      );

      if (plan != null && mounted) {
        Navigator.pop(context, plan);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('计划"${plan.name}"创建成功')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('创建计划失败,请重试')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  String _getRepeatTypeLabel(RepeatType type) {
    switch (type) {
      case RepeatType.oneTime:
        return '一次性';
      case RepeatType.daily:
        return '每日';
      case RepeatType.weekly:
        return '每周';
      case RepeatType.monthly:
        return '每月';
      case RepeatType.custom:
        return '自定义';
    }
  }

}
