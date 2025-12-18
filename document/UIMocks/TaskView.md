# 主界面布局

> **屏幕方向**: 所有布局均为竖屏模式设计，应用不支持横屏旋转

## 1.1 主界面布局
```
┌─────────────────────────────────────┐
│  任务                               │ <- AppBar (48dp)
├─────────────────────────────────────┤
│  [全部] [待执行] [已完成] [已跳过]   │ <- 过滤栏 (48dp)
├─────────────────────────────────────┤
│                                     │
│  ▼ 今日 (5)                        │ <- 可折叠分组
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │ 晨跑  │ │ 阅读  │ │代码练│       │ <- 任务卡片网格
│  │ 30分 │ │ (2/5)│ │ 60分 │       │    (3列布局)
│  └──────┘ └──────┘ └──────┘       │
│  ┌──────┐ ┌──────┐                 │
│  │冥想   │ │番茄钟 │                 │
│  │ (1/2)│ │25分×(1/4)│               │ <- 同时有计时和次数
│  └──────┘ └──────┘                 │
│                                     │
│  ▶ 本周 (2)。                      │ <- 已折叠分组
│                                     │
│  ▼ 本月 (1)。                      │
│  ┌──────┐                          │
│  │读书   │                          │
│  │⭐评价 │                          │
│  └──────┘                          │
│                                     │
│  ▼ 一次性任务 (3)                  │
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │报告  │ │会议  │ │采购  │       │
│  │      │ │ 14:00│ │      │       │
│  └──────┘ └──────┘ └──────┘       │
│                                     │
└─────────────────────────────────────┘
   任务    目标    回顾    我的
   ━━━━
```

## 1.1.1 过滤栏设计
```
过滤栏布局（水平滚动）:
┌─────────────────────────────────────────┐
│  [■全部] [待执行] [已完成] [已跳过]      │
└─────────────────────────────────────────┘

过滤器芯片样式：
- 未选中：
  ┌─────────┐
  │  全部   │  <- 灰色背景，深灰文字
  └─────────┘

- 选中：
  ┌─────────┐
  │ ■全部   │  <- 主色背景，蓝色边框，粗体文字
  └─────────┘

交互效果：
- 点击芯片：切换过滤器，更新任务列表
- 任务列表会根据过滤器实时更新
- 默认显示"全部"任务
```

## 1.2 任务卡片详细设计
```
正常尺寸 (屏幕宽度/3 - 间距):

┌────────────┐
│  晨跑      │  <- 任务名称 (14sp)
│  30分钟    │  <- 时间/次数 (12sp灰色)
└────────────┘

状态通过背景色表示：
- Active: 白色背景 + 蓝色左边框
- Completed: 淡绿色背景
- Skipped: 灰色背景 + 删除线

不同类型任务卡片示例：

计时型：           计量型：          简单型：
┌────────────┐    ┌────────────┐    ┌────────────┐
│  代码练习   │    │  俯卧撑     │    │  浇花      │
│  60分钟    │    │  (3/10)    │    │           │
└────────────┘    └────────────┘    └────────────┘

评价型：           计时+计量型：     已完成：
┌────────────┐    ┌────────────┐    ┌────────────┐
│  工作总结   │    │  番茄钟     │    │  ✓ 晨跑    │
│  ⭐ 评价    │    │  25分×(2/4) │    │  30分钟    │
└────────────┘    └────────────┘    └────────────┘

已跳过：          计量+评价型：
┌────────────┐    ┌────────────┐
│  会议      │    │  冥想练习   │
│  (跳过)    │    │  (2/4)·⭐评价 │
└────────────┘    └────────────┘
```

## 1.3 分组展开/折叠交互
```
展开状态：
▼ 今日 (4)        <- 点击整行可折叠，数字表示任务总数
  任务卡片网格...

折叠状态：
▶ 本周 (2)        <- 点击整行可展开，数字表示任务总数

分组类型说明：
- 今日：当天需要执行的任务
- 本周：本周内需要执行的任务（不含今日）
- 本月：本月内需要执行的任务（不含本周）
- 一次性任务：没有重复周期的任务

注：任务自动根据执行时间分组，无需手动分类
```

## 1.4 任务点击后的操作菜单
```
点击任务卡片后弹出小型悬浮菜单 (类似右键菜单):

任务卡片位置：
┌──────────┐
│  晨跑     │  <- 点击的任务卡片
│  30分钟   │
└──────────┘
      ↓
┌─────────────────────────────┐
│  ⏱ 计时  │  ✓ 完成  │  ⏭ 跳过  │  <- 横向三个按钮
└─────────────────────────────┘

菜单特性：
- 位置：在任务卡片下方或上方（根据屏幕位置自动调整）
- 背景：白色背景 + 轻微阴影 (elevation 4dp)
- 按钮宽度：每个按钮约 80dp
- 按钮高度：48dp
- 圆角：8dp
- 分割线：按钮之间用竖线分隔 (1dp #E0E0E0)

交互效果：
- 点击任务卡片：显示菜单
- 点击菜单外部：关闭菜单
- 点击任意按钮：执行对应操作并关闭菜单

按钮功能说明：
⏱ 计时：开始执行任务（跳转到执行页面）
✓ 完成：直接标记任务为完成状态
⏭ 跳过：标记任务为跳过状态

长按交互：
长按任务卡片直接查看任务详情（只读模式）：
- 显示任务完整信息
- 查看执行历史记录
- 查看今日执行情况
注：任务从Plan克隆生成，不可编辑或删除


## 1.5 设计规格说明

### 颜色定义
```
过滤栏芯片颜色:
- 未选中背景: surfaceContainerHighest (Material 3)
- 未选中文字: onSurface
- 选中背景: primaryContainer (Material 3)
- 选中文字: onPrimaryContainer
- 选中边框: primary (1dp)

任务状态颜色:
- Active: #FFFFFF (白色背景) + #2196F3 (蓝色左边框 4dp)
- Completed: #E8F5E9 (淡绿背景)
- Skipped: #F5F5F5 (灰色背景)

分组标题:
- 文字: #424242 (深灰)
- 背景: transparent
- 展开/折叠图标: #757575
```

### 尺寸规格
```
过滤栏:
- 容器高度: 48dp
- 水平内边距: 16dp
- 垂直内边距: 8dp
- 芯片间距: 8dp
- 芯片圆角: 8dp
- 芯片内边距: 12dp (水平) × 8dp (垂直)
- 文字大小: 14sp
- 边框宽度: 1dp (选中状态)

任务卡片:
- 宽度: (屏幕宽度 - 32dp) / 3
- 高度: 64dp
- 圆角: 8dp
- 内边距: 8dp
- 卡片间距: 8dp

分组:
- 标题高度: 48dp
- 左边距: 16dp
- 文字大小: 14sp (Medium)

操作菜单 (快捷菜单):
- 菜单总宽度: 240dp (3个按钮 × 80dp)
- 菜单高度: 48dp
- 按钮宽度: 80dp
- 按钮高度: 48dp
- 圆角: 8dp
- 阴影: elevation 4dp
- 文字大小: 14sp
- 图标大小: 18dp
- 分割线: 1dp #E0E0E0 (竖线)

长按菜单:
- 菜单宽度: 160dp
- 每项高度: 48dp
- 文字大小: 14sp
- 分割线: 1dp #E0E0E0 (横线)
```

### Flutter实现示例
```dart
// 任务卡片网格
GridView.builder(
  padding: EdgeInsets.symmetric(horizontal: 16),
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    childAspectRatio: 1.5,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
  ),
  itemBuilder: (context, index) {
    return TaskCard(task: tasks[index]);
  },
)

// 任务卡片
Container(
  decoration: BoxDecoration(
    color: _getStatusColor(task.status),
    borderRadius: BorderRadius.circular(8),
    border: task.status == TaskStatus.active
      ? Border(left: BorderSide(color: Colors.blue, width: 4))
      : null,
  ),
  padding: EdgeInsets.all(8),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        task.name,
        style: TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // 处理多种配置组合
      _buildTaskInfo(task),
    ],
  ),
)

// 任务状态管理
// 任务状态定义
enum TaskStatus {
  active,     // 待执行（活跃状态）
  completed,  // 已完成
  skipped,    // 已跳过
}

// 任务状态流转规则：
// - active -> completed (完成执行)
// - active -> skipped (跳过任务)
// 注：已完成和已跳过的任务状态不可逆

// 构建任务信息显示
// 根据任务配置组合规则显示不同的信息
// 注意：计时和评价不能同时存在（互斥）
Widget _buildTaskInfo(Task task) {
  // 计时+计数组合
  if (task.duration != null && task.repeatCount != null) {
    return Text(
      '${task.duration}分×(${task.currentCount}/${task.repeatCount})',
      style: TextStyle(fontSize: 12, color: Colors.grey),
    );
  }
  // 计数+评价组合
  else if (task.repeatCount != null && task.hasEvaluation) {
    return Text(
      '(${task.currentCount}/${task.repeatCount})·⭐评价',
      style: TextStyle(fontSize: 12, color: Colors.grey),
    );
  }
  // 纯计时
  else if (task.duration != null) {
    return Text(
      '${task.duration}分钟',
      style: TextStyle(fontSize: 12, color: Colors.grey),
    );
  }
  // 纯计数
  else if (task.repeatCount != null) {
    return Text(
      '(${task.currentCount}/${task.repeatCount})',
      style: TextStyle(fontSize: 12, color: Colors.grey),
    );
  }
  // 纯评价
  else if (task.hasEvaluation) {
    return Text(
      '⭐ 评价',
      style: TextStyle(fontSize: 12, color: Colors.grey),
    );
  }
  // 简单任务，不显示额外信息
  else {
    return SizedBox.shrink();
  }
}

// 操作菜单实现
void _showQuickMenu(BuildContext context, Task task) {
  showMenu(
    context: context,
    position: RelativeRect.fromLTRB(100, 200, 100, 0), // 根据实际位置调整
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    elevation: 4,
    items: [
      PopupMenuItem(
        height: 48,
        child: Container(
          width: 240,
          child: Row(
            children: [
              _buildMenuButton(
                icon: Icons.timer,
                label: '计时',
                onTap: () => _startTimer(task),
              ),
              VerticalDivider(width: 1, color: Colors.grey[300]),
              _buildMenuButton(
                icon: Icons.check,
                label: '完成',
                onTap: () => _markComplete(task),
              ),
              VerticalDivider(width: 1, color: Colors.grey[300]),
              _buildMenuButton(
                icon: Icons.skip_next,
                label: '跳过',
                onTap: () => _skipTask(task),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildMenuButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      width: 80,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 14)),
        ],
      ),
    ),
  );
}
```