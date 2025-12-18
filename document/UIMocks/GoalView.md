# 目标与计划页面

> **屏幕方向**: 所有布局均为竖屏模式设计，应用不支持横屏旋转

## 1. 目标列表 - 网格视图
```
┌─────────────────────────────────────┐
│  目标管理                    [+]    │
├─────────────────────────────────────┤
│  进行中  已完成  全部               │ <- Tab栏
│  ━━━━━                              │
├─────────────────────────────────────┤
│                                     │
│ ┌────────────┐  ┌────────────┐      │
│ │🔴 高优先级  │  │🟠 中优先级  │      │ <- 目标卡片网格
│ │学习Flutter │  │  健康生活  │      │    (2列布局)
│ │            │  │            │      │    按优先级和截止日期排序
│ │ 📅 3月15日 │  │ 📅 6月30日 │      │
│ │ 5个计划    │  │ 3个计划    │      │
│ └────────────┘  └────────────┘      │
│                                     │
│ ┌────────────┐  ┌────────────┐      │
│ │🟡 低优先级  │  │🟢 低优先级  │      │
│ │  英语学习  │  │  阅读计划  │      │
│ │            │  │            │      │
│ │ 📅 2月28日 │  │ 📅 12月31日│      │
│ │ 2个计划    │  │ 4个计划    │      │
│ └────────────┘  └────────────┘      │
│                                     │
└─────────────────────────────────────┘

优先级标识：
🔴 高优先级 (High)
🟠 中优先级 (Medium)
🟡 低优先级 (Low)
🟢 已完成 (Completed)

排序规则：
1. 优先级（高→中→低）
2. 截止日期（近→远）
3. 创建时间（新→旧）
```

## 2. 目标详情页
```
┌─────────────────────────────────────┐
│  < 返回     目标详情        [编辑]  │
├─────────────────────────────────────┤
│                                     │
│  🎯 学习Flutter开发                 │
│  🔴 高优先级                        │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  描述                               │
│  掌握Flutter框架，能够独立开发      │
│  跨平台移动应用                     │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  时间信息                           │
│  创建时间：2024-01-01               │
│  截止日期：2024-03-15               │
│  剩余时间：45天                     │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  关联计划 (5)                       │
│  ┌─────────────────────────────┐    │
│  │ 📋 每日代码练习              │    │
│  │    ████████░░ 80%           │    │ <- Plan有进度条
│  ├─────────────────────────────┤    │
│  │ 📖 Flutter文档阅读          │    │
│  │    ██████░░░░ 60%           │    │
│  ├─────────────────────────────┤    │
│  │ 🛠 实战项目开发             │    │
│  │    ████░░░░░░ 40%           │    │
│  ├─────────────────────────────┤    │
│  │ 📝 学习笔记整理             │    │
│  │    ██████████ 100%          │    │
│  ├─────────────────────────────┤    │
│  │ 🎓 在线课程学习             │    │
│  │    ███░░░░░░░ 30%           │    │
│  └─────────────────────────────┘    │
│                                     │
│         [添加计划]                  │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  整体进度                           │
│  已完成计划：1/5                    │
│  平均完成率：62%                    │
│                                     │
│  [标记完成]     [删除目标]          │
│                                     │
└─────────────────────────────────────┘
```

## 3. 计划详情页
```
┌─────────────────────────────────────┐
│  < 返回    计划详情         [编辑]  │
├─────────────────────────────────────┤
│                                     │
│  📋 每日代码练习                    │
│                                     │
│  进度：████████░░  80%              │ <- Plan的完成进度
│                                     │
│  所属目标：学习Flutter开发          │
│  ─────────────────────────────────  │
│                                     │
│  时间设置                           │
│  开始：2024-01-01                   │
│  结束：2024-03-31                   │
│  重复：每日                         │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  任务配置                           │
│  类型：计时任务                     │
│  时长：60分钟                       │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  执行统计                           │
│  ┌─────────────────────────────┐    │
│  │ 总任务：45                  │    │
│  │ 已完成：32  (71%)          │    │
│  │ 已跳过：8   (18%)          │    │
│  │ 待执行：5   (11%)          │    │
│  └─────────────────────────────┘    │
│                                     │
│  完成趋势                           │
│  ┌─────────────────────────────┐    │
│  │     ▁▃▅▇█▇▅▃▅▇█           │    │ <- 最近14天完成情况
│  └─────────────────────────────┘    │
│                                     │
│  最近执行记录                       │
│  • 1月15日  ✓ 已完成  65分钟       │
│  • 1月14日  ✓ 已完成  60分钟       │
│  • 1月13日  ⏭ 已跳过              │
│  • 1月12日  ✓ 已完成  58分钟       │
│                                     │
│         [查看完整历史]              │
│                                     │
└─────────────────────────────────────┘
```

## 4. 设计规格说明

### 目标卡片设计
- **尺寸**：(屏幕宽度 - 32dp) / 2
- **内边距**：12dp
- **圆角**：8dp
- **优先级标识**：左上角，16sp
- **标题字体**：16sp Bold
- **日期字体**：12sp Gray
- **计划数量**：12sp Gray

### 优先级颜色定义
- 🔴 高优先级：#FF5252
- 🟠 中优先级：#FF9800
- 🟡 低优先级：#FFC107
- 🟢 已完成：#4CAF50

### 排序逻辑实现
```dart
goals.sort((a, b) {
  // 1. 按优先级排序
  if (a.priority != b.priority) {
    return a.priority.index.compareTo(b.priority.index);
  }
  // 2. 按截止日期排序
  if (a.deadline != b.deadline) {
    return a.deadline.compareTo(b.deadline);
  }
  // 3. 按创建时间排序
  return b.createdAt.compareTo(a.createdAt);
});
```

## 5. Flutter实现参考

### 目标卡片组件
```dart
class GoalCard extends StatelessWidget {
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _navigateToGoalDetail(context),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 优先级和标题
              Row(
                children: [
                  Text(
                    _getPriorityEmoji(goal.priority),
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(width: 4),
                  Text(
                    _getPriorityText(goal.priority),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getPriorityColor(goal.priority),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                goal.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Spacer(),
              // 截止日期
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    _formatDate(goal.deadline),
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              SizedBox(height: 4),
              // 计划数量
              Text(
                '${goal.plans.length}个计划',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPriorityEmoji(Priority priority) {
    switch (priority) {
      case Priority.high:
        return '🔴';
      case Priority.medium:
        return '🟠';
      case Priority.low:
        return '🟡';
      case Priority.completed:
        return '🟢';
    }
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return Color(0xFFFF5252);
      case Priority.medium:
        return Color(0xFFFF9800);
      case Priority.low:
        return Color(0xFFFFC107);
      case Priority.completed:
        return Color(0xFF4CAF50);
    }
  }
}

// 计划进度组件
class PlanProgressItem extends StatelessWidget {
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(plan.icon, style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.name,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          // 进度条
          LinearProgressIndicator(
            value: plan.completionRate,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              plan.completionRate == 1.0 ? Colors.green : Colors.blue,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${(plan.completionRate * 100).toInt()}%',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
```

## 6. 设计要点总结

1. **Goal与Plan的区别**：
   - Goal：显示优先级、截止日期、计划数量，无进度
   - Plan：显示具体执行进度，有进度条

2. **视觉层次**：
   - 使用颜色标识优先级，便于快速识别
   - 卡片式设计，信息层次清晰
   - 进度条直观展示Plan完成情况

3. **交互逻辑**：
   - 点击Goal卡片进入详情页
   - 详情页可查看所有关联Plan
   - 支持添加新Plan、编辑、删除等操作

4. **排序策略**：
   - 自动按重要性和紧急性排序
   - 确保用户优先关注重要目标