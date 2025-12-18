# 任务执行交互设计

> **屏幕方向**: 所有布局均为竖屏模式设计，应用不支持横屏旋转

## 1. 计时页面（计时任务专用）

当用户点击计时任务的"计时"按钮时，弹出全屏计时页面：

```
┌─────────────────────────────────────┐
│  ✕                   晨跑30分钟      │ <- 关闭按钮 + 任务名称
├─────────────────────────────────────┤
│                                     │
│                                     │
│         ┌─────────────────┐         │
│         │                 │         │
│         │    15:30       │         │ <- 大号倒计时
│         │                 │         │     (240dp圆形)
│         │                 │         │
│         │  ███████████░░  │         │ <- 环形进度条
│         └─────────────────┘         │
│                                     │
│                                     │
│  开始时间: 07:00                    │
│  预计结束: 07:30                    │
│                                     │
│                                     │
│                                     │
│  ┌────────┬────────┬────────┐      │
│  │   ⏸   │   ✓   │   ✕   │      │ <- 横向按钮组
│  │ 暂停  │ 完成  │ 放弃  │      │    每个按钮80dp宽
│  └────────┴────────┴────────┘      │    图标24dp，文字12sp
│                                     │
└─────────────────────────────────────┐

暂停状态：
┌─────────────────────────────────────┐
│  ✕                   晨跑30分钟      │
├─────────────────────────────────────┤
│                                     │
│         ┌─────────────────┐         │
│         │                 │         │
│         │    15:30       │         │ <- 时间静止
│         │    已暂停       │         │ <- 显示暂停状态
│         │                 │         │
│         │  ███████████░░  │         │ <- 进度保持
│         └─────────────────┘         │
│                                     │
│  已用时: 14分30秒                   │
│                                     │
│                                     │
│  ┌────────┬────────┬────────┐      │
│  │   ▶   │   ✓   │   ✕   │      │ <- 继续按钮替换暂停
│  │ 继续  │ 完成  │ 放弃  │      │
│  └────────┴────────┴────────┘      │
│                                     │
└─────────────────────────────────────┘

设计说明：
- 全屏模式，专注于计时
- 大号倒计时显示，清晰可见
- 环形进度条直观展示进度
- 支持暂停/继续功能
- 可提前完成或放弃任务
- 倒计时结束自动标记完成并返回
```

## 2. 评价选择菜单（评价任务专用）

当用户点击带评价任务的"完成"按钮时，弹出评价选择菜单（类似右键菜单）：

```
任务卡片位置：
┌──────────┐
│ 工作总结  │  <- 点击"完成"的任务
│  ⭐ 评价  │
└──────────┘
      ↓
┌─────────────────────────────┐
│  😊 优秀  │  😐 良好        │  <- 横向评价选项
├───────────┼─────────────────┤     (2行2列布局)
│  😟 一般  │  😴 较差        │     每项80dp宽
└─────────────────────────────┘

或者竖向布局（根据屏幕位置自动调整）：
┌──────────┐
│ 工作总结  │
│  ⭐ 评价  │
└──────────┘
      ↓
┌─────────────┐
│  😊 优秀    │
├─────────────┤
│  😐 良好    │
├─────────────┤
│  😟 一般    │
├─────────────┤
│  😴 较差    │
└─────────────┘

设计说明：
- 悬浮菜单形式，类似右键菜单
- 位置：在任务卡片下方或上方（根据屏幕位置自动调整）
- 背景：白色背景 + 轻微阴影 (elevation 4dp)
- 每个选项：80dp宽，48dp高
- 点击任意选项：直接完成任务并记录评价
- 点击菜单外部：关闭菜单，任务保持未完成状态
- 圆角：8dp
```

## 3. 任务完成交互流程

### 计时任务流程：
1. 用户点击任务卡片 → 显示快捷菜单
2. 点击"计时" → 打开全屏计时页面
3. 计时结束/提前完成 → 自动返回任务列表，任务标记完成

### 评价任务流程：
1. 用户点击任务卡片 → 显示快捷菜单
2. 点击"完成" → 弹出评价选择菜单
3. 点击任意评价选项 → 任务直接标记完成并记录评价

### 计量任务流程（次数型）：
1. 用户点击任务卡片 → 显示快捷菜单
2. 点击"完成" → 直接标记完成（如果需要记录具体次数，可在任务详情中补充）

### 简单任务流程：
1. 用户点击任务卡片 → 显示快捷菜单
2. 点击"完成" → 直接标记完成，无需其他操作

## 4. 设计原则说明

1. **最小化交互**：
   - 简单任务和计量任务直接完成，无需额外页面
   - 只有计时任务需要专门的计时页面
   - 评价通过快捷菜单完成，一次点击即可选择并完成

2. **互斥原则**：
   - 计时和评价不会同时存在于一个任务中
   - 任务类型决定交互方式

3. **快速操作**：
   - 所有操作都可通过2-3次点击完成
   - 减少页面跳转，提高效率

## 5. Flutter实现参考

```dart
// 计时页面实现
class TimerPage extends StatefulWidget {
  final Task task;
  TimerPage({required this.task});

  @override
  _TimerPageState createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  late Timer _timer;
  int _remainingSeconds;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.task.duration * 60; // 转换为秒
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_isPaused && _remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });

        if (_remainingSeconds == 0) {
          _completeTask();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => _showExitConfirmation(),
                ),
                Expanded(
                  child: Text(
                    widget.task.name,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 48), // 平衡布局
              ],
            ),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 圆形进度条和倒计时
                  Container(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: 1 - (_remainingSeconds / (widget.task.duration * 60)),
                          strokeWidth: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation(Colors.blue),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatTime(_remainingSeconds),
                              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                            ),
                            if (_isPaused)
                              Text(
                                '已暂停',
                                style: TextStyle(fontSize: 16, color: Colors.orange),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40),

                  // 时间信息
                  Text('开始时间: ${_getStartTime()}'),
                  Text('预计结束: ${_getEndTime()}'),

                  SizedBox(height: 40),

                  // 操作按钮 - 横向布局
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildControlButton(
                          icon: _isPaused ? Icons.play_arrow : Icons.pause,
                          label: _isPaused ? '继续' : '暂停',
                          onPressed: () {
                            setState(() {
                              _isPaused = !_isPaused;
                            });
                          },
                          isPrimary: true,
                        ),
                        SizedBox(width: 12),
                        _buildControlButton(
                          icon: Icons.check,
                          label: '完成',
                          onPressed: _completeTask,
                        ),
                        SizedBox(width: 12),
                        _buildControlButton(
                          icon: Icons.close,
                          label: '放弃',
                          onPressed: _abandonTask,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // 构建控制按钮
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
    bool isDestructive = false,
  }) {
    Color backgroundColor = isPrimary
        ? Colors.blue
        : isDestructive
            ? Colors.grey[300]!
            : Colors.white;
    Color foregroundColor = isPrimary
        ? Colors.white
        : isDestructive
            ? Colors.grey[600]!
            : Colors.blue;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: Size(80, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isPrimary ? BorderSide.none : BorderSide(color: Colors.grey[300]!),
        ),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// 评价选择菜单
void showEvaluationMenu(BuildContext context, Task task, Offset tapPosition) {
  final RenderBox overlay = Overlay.of(context)!.context.findRenderObject() as RenderBox;

  showMenu(
    context: context,
    position: RelativeRect.fromRect(
      tapPosition & Size(40, 40),
      Offset.zero & overlay.size,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    elevation: 4,
    items: [
      PopupMenuItem(
        padding: EdgeInsets.zero,
        child: Container(
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 2x2 网格布局
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEvaluationMenuItem(
                    emoji: '😊',
                    label: '优秀',
                    onTap: () {
                      Navigator.pop(context);
                      _completeTaskWithEvaluation(task, 'excellent');
                    },
                  ),
                  SizedBox(width: 8),
                  _buildEvaluationMenuItem(
                    emoji: '😐',
                    label: '良好',
                    onTap: () {
                      Navigator.pop(context);
                      _completeTaskWithEvaluation(task, 'good');
                    },
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEvaluationMenuItem(
                    emoji: '😟',
                    label: '一般',
                    onTap: () {
                      Navigator.pop(context);
                      _completeTaskWithEvaluation(task, 'average');
                    },
                  ),
                  SizedBox(width: 8),
                  _buildEvaluationMenuItem(
                    emoji: '😴',
                    label: '较差',
                    onTap: () {
                      Navigator.pop(context);
                      _completeTaskWithEvaluation(task, 'poor');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildEvaluationMenuItem({
  required String emoji,
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      width: 80,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: TextStyle(fontSize: 18)),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}
```