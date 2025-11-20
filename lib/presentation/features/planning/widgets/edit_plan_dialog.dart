import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myassistant/data/models/plan_model.dart';
import 'package:myassistant/presentation/providers/plan_state_provider.dart';

/// Dialog for editing an existing plan
/// Note: Plan names cannot be edited due to database constraint
class EditPlanDialog extends ConsumerStatefulWidget {
  final PlanModel plan;

  const EditPlanDialog({
    super.key,
    required this.plan,
  });

  @override
  ConsumerState<EditPlanDialog> createState() => _EditPlanDialogState();
}

class _EditPlanDialogState extends ConsumerState<EditPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  // Time settings
  DateTime? _endDate;

  // Task configuration - optional fields that determine task type
  int? _durationMinutes;
  int? _repeatCount;
  final List<String> _evaluationOptions = [];
  final _evaluationController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize with existing plan values
    _descriptionController.text = widget.plan.description ?? '';
    _endDate = widget.plan.endDate;
    _durationMinutes = widget.plan.taskConfig.durationMinutes;
    _repeatCount = widget.plan.taskConfig.repeatCount;
    if (widget.plan.taskConfig.evaluationOptions != null) {
      _evaluationOptions.addAll(widget.plan.taskConfig.evaluationOptions!);
    }
  }

  @override
  void dispose() {
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
                    Icons.edit,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '编辑计划',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '计划: ${widget.plan.name}',
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
                      // Note about immutable name
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '计划名称创建后不可修改',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
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

                      // Start date (read-only)
                      _buildDateField(
                        context,
                        label: '开始日期 (不可修改)',
                        date: widget.plan.startDate,
                        onTap: null, // Read-only
                        isReadOnly: true,
                      ),
                      const SizedBox(height: 12),

                      // End date
                      _buildDateField(
                        context,
                        label: '结束日期',
                        date: _endDate,
                        onTap: () => _selectEndDate(context),
                        isReadOnly: false,
                      ),
                      const SizedBox(height: 24),

                      // Task configuration
                      Text(
                        '任务配置',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '根据需要修改任务配置选项',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Duration configuration
                      TextFormField(
                        initialValue: _durationMinutes?.toString() ?? '',
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
                        initialValue: _repeatCount?.toString() ?? '',
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
                        : const Text('保存'),
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
    required VoidCallback? onTap,
    required bool isReadOnly,
  }) {
    return InkWell(
      onTap: isReadOnly ? null : onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_today),
          enabled: !isReadOnly,
        ),
        child: Text(
          date != null ? _formatDate(date) : '选择日期',
          style: date != null
              ? (isReadOnly ? TextStyle(color: Colors.grey[600]) : null)
              : TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? widget.plan.startDate.add(const Duration(days: 7)),
      firstDate: widget.plan.startDate,
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
        const SnackBar(content: Text('评估选项至少需要2个,或者不添加')),
      );
      return;
    }

    if (_endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择结束日期')),
      );
      return;
    }

    if (_endDate!.isBefore(widget.plan.startDate)) {
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

      // Update plan
      final plan = await ref.read(planListProvider.notifier).updatePlan(
        planId: widget.plan.id,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        endDate: _endDate,
        taskConfig: taskConfig,
      );

      if (plan != null && mounted) {
        Navigator.pop(context, plan);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('计划"${plan.name}"更新成功')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新计划失败,请重试')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
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
}
