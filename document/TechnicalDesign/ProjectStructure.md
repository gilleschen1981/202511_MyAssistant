# Flutter项目结构设计

本文档定义了Flutter任务管理应用的完整项目结构，采用分层架构和模块化设计。

## 平台支持说明

### 目标平台
- **唯一支持平台**: Android
  - 最低版本: Android 5.0 (API 21)
  - 推荐版本: Android 6.0+ (API 23+)
  - 目标版本: 最新稳定Android版本

### 开发和测试环境
- **主要开发环境**: Android Studio with Android SDK
- **测试环境**: Android Emulator (推荐使用 Pixel 系列模拟器)
- **物理设备测试**: 支持通过USB调试在Android设备上测试

### 不支持的平台
- **iOS**: 项目不支持iOS平台，相关目录仅为Flutter框架结构保留
- **Web**: 不作为发布目标，仅可能用于开发调试
- **Desktop**: 不支持Windows/macOS/Linux桌面平台

## 1. 项目整体结构

```
my_assistant/
├── android/                    # Android平台配置和原生代码（唯一支持平台）
├── ios/                        # iOS目录（Flutter框架保留，项目不支持）
├── web/                        # Web目录（Flutter框架保留，项目不支持）
├── lib/                        # 主要源代码目录
├── test/                       # 单元测试
├── integration_test/           # 集成测试（Android Emulator运行）
├── assets/                     # 资源文件
│   ├── images/                 # 图片资源
│   ├── fonts/                  # 字体文件
│   └── icons/                  # 图标资源
├── scripts/                    # 开发工具脚本
│   ├── export_templates.sh     # Goal/Plan模板导出脚本
│   ├── import_templates.sh     # Goal/Plan模板导入脚本
│   ├── export_db.sh           # 数据库导出脚本
│   ├── reset_db.sh            # 数据库重置脚本
│   ├── README.md              # 脚本使用说明
│   └── templates/             # 模板文件目录
│       ├── README.md          # 模板格式说明
│       ├── example_template.json  # 示例模板
│       └── *.json             # 导出的模板文件
├── document/                   # 项目文档
│   ├── TechnicalDesign/        # 技术设计文档
│   │   ├── ProjectStructure.md # 项目结构说明（本文档）
│   │   ├── DatabaseSchema.md   # 数据库设计
│   │   └── Architecture.md     # 架构设计
│   └── UserGuide/              # 用户指南
├── pubspec.yaml               # 项目配置和依赖
└── README.md                  # 项目说明文档
```

## 2. lib/目录详细结构

```
lib/
├── main.dart                   # 应用程序入口
├── app.dart                    # 应用程序配置
│
├── core/                       # 核心模块（跨功能的通用代码）
│   ├── constants/              # 常量定义
│   │   ├── app_constants.dart
│   │   ├── color_constants.dart
│   │   ├── route_constants.dart
│   │   └── string_constants.dart
│   │
│   ├── theme/                  # 主题配置
│   │   ├── app_theme.dart
│   │   ├── light_theme.dart
│   │   ├── dark_theme.dart
│   │   └── theme_provider.dart
│   │
│   ├── utils/                  # 工具类
│   │   ├── date_utils.dart
│   │   ├── time_utils.dart
│   │   ├── validators.dart
│   │   ├── formatter_utils.dart
│   │   └── id_generator.dart
│   │
│   ├── errors/                 # 错误处理
│   │   ├── failures.dart
│   │   ├── exceptions.dart
│   │   └── error_handler.dart
│   │
│   └── network/                # 网络层（预留）
│       ├── api_client.dart
│       ├── api_endpoints.dart
│       └── network_info.dart
│
├── data/                       # 数据层
│   ├── models/                 # 数据模型
│   │   ├── goal_model.dart
│   │   ├── plan_model.dart
│   │   ├── task_model.dart
│   │   ├── user_model.dart
│   │   ├── user_settings_model.dart
│   │   └── enums/
│   │       ├── priority.dart
│   │       ├── status.dart
│   │       ├── task_filter.dart
│   │       └── task_type.dart
│   │
│   ├── repositories/           # 仓库实现
│   │   ├── goal_repository.dart
│   │   ├── plan_repository.dart
│   │   ├── task_repository.dart
│   │   ├── user_repository.dart
│   │   └── settings_repository.dart
│   │
│   ├── data_sources/           # 数据源
│   │   ├── local/              # 本地数据源
│   │   │   ├── database/
│   │   │   │   ├── app_database.dart
│   │   │   │   ├── database_helper.dart
│   │   │   │   └── tables/
│   │   │   │       ├── goals_table.dart
│   │   │   │       ├── plans_table.dart
│   │   │   │       ├── tasks_table.dart
│   │   │   │       └── users_table.dart
│   │   │   ├── dao/            # 数据访问对象
│   │   │   │   ├── goal_dao.dart
│   │   │   │   ├── plan_dao.dart
│   │   │   │   ├── task_dao.dart
│   │   │   │   └── user_dao.dart
│   │   │   └── preferences/
│   │   │       └── shared_preferences_helper.dart
│   │   │
│   │   └── remote/             # 远程数据源（预留）
│   │       ├── goal_remote_data_source.dart
│   │       ├── plan_remote_data_source.dart
│   │       ├── task_remote_data_source.dart
│   │       └── auth_remote_data_source.dart
│   │
│   └── services/               # 业务逻辑服务
│       ├── task_generation_service.dart
│       ├── task_refresh_service.dart
│       ├── task_execution_service.dart
│       ├── sync_service.dart
│       └── notification_service.dart
│
├── domain/                     # 领域层（Clean Architecture）
│   ├── entities/               # 领域实体（纯业务逻辑）
│   │   ├── goal_entity.dart
│   │   ├── plan_entity.dart
│   │   └── task_entity.dart
│   │
│   ├── repositories/           # 仓库接口
│   │   ├── i_goal_repository.dart
│   │   ├── i_plan_repository.dart
│   │   └── i_task_repository.dart
│   │
│   └── use_cases/              # 用例
│       ├── goal/
│       │   ├── create_goal.dart
│       │   ├── update_goal.dart
│       │   ├── delete_goal.dart
│       │   └── get_goals.dart
│       ├── plan/
│       │   ├── create_plan.dart
│       │   ├── update_plan.dart
│       │   ├── delete_plan.dart
│       │   └── get_plans.dart
│       └── task/
│           ├── complete_task.dart
│           ├── skip_task.dart
│           ├── refresh_tasks.dart
│           └── get_tasks.dart
│
├── presentation/               # 展示层
│   ├── common/                 # 通用组件
│   │   ├── widgets/
│   │   │   ├── custom_app_bar.dart
│   │   │   ├── custom_button.dart
│   │   │   ├── loading_indicator.dart
│   │   │   ├── error_view.dart
│   │   │   ├── empty_state.dart
│   │   │   ├── custom_dialog.dart
│   │   │   └── custom_snackbar.dart
│   │   │
│   │   ├── animations/
│   │   │   ├── fade_animation.dart
│   │   │   ├── slide_animation.dart
│   │   │   └── celebration_animation.dart
│   │   │
│   │   └── layouts/
│   │       ├── responsive_layout.dart
│   │       └── master_detail_layout.dart
│   │
│   ├── features/               # 功能模块
│   │   ├── splash/             # 启动页
│   │   │   └── splash_screen.dart
│   │   │
│   │   ├── auth/               # 认证模块
│   │   │   ├── screens/
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── register_screen.dart
│   │   │   │   └── forgot_password_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── auth_form.dart
│   │   │   │   ├── password_field.dart
│   │   │   │   └── social_login_buttons.dart
│   │   │   └── providers/
│   │   │       └── auth_provider.dart
│   │   │
│   │   ├── tasks/              # 任务模块
│   │   │   ├── screens/
│   │   │   │   ├── task_list_screen.dart
│   │   │   │   ├── timer_screen.dart
│   │   │   │   └── task_detail_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── task_card.dart
│   │   │   │   ├── task_group_header.dart
│   │   │   │   ├── quick_action_menu.dart
│   │   │   │   ├── evaluation_menu.dart
│   │   │   │   ├── timer_display.dart
│   │   │   │   ├── timer_controls.dart
│   │   │   │   └── task_filter_bar.dart
│   │   │   └── providers/
│   │   │       ├── task_list_provider.dart
│   │   │       └── timer_provider.dart
│   │   │
│   │   ├── goals/              # 目标模块
│   │   │   ├── screens/
│   │   │   │   ├── goal_list_screen.dart
│   │   │   │   ├── goal_detail_screen.dart
│   │   │   │   └── goal_form_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── goal_card.dart
│   │   │   │   ├── priority_badge.dart
│   │   │   │   ├── goal_progress.dart
│   │   │   │   ├── goal_form.dart
│   │   │   │   └── plan_list_item.dart
│   │   │   └── providers/
│   │   │       └── goal_provider.dart
│   │   │
│   │   ├── plans/              # 计划模块
│   │   │   ├── screens/
│   │   │   │   ├── plan_list_screen.dart
│   │   │   │   ├── plan_detail_screen.dart
│   │   │   │   └── plan_form_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── plan_card.dart
│   │   │   │   ├── plan_progress_bar.dart
│   │   │   │   ├── repeat_rule_picker.dart
│   │   │   │   ├── task_config_form.dart
│   │   │   │   ├── plan_statistics.dart
│   │   │   │   ├── step_form.dart
│   │   │   │   └── date_range_picker.dart
│   │   │   └── providers/
│   │   │       └── plan_provider.dart
│   │   │
│   │   ├── review/             # 回顾模块
│   │   │   ├── screens/
│   │   │   │   ├── review_home_screen.dart
│   │   │   │   ├── plan_history_screen.dart
│   │   │   │   ├── task_history_screen.dart
│   │   │   │   └── statistics_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── plan_overview_card.dart
│   │   │   │   ├── completion_trend_chart.dart
│   │   │   │   ├── time_distribution_chart.dart
│   │   │   │   ├── heatmap_calendar.dart
│   │   │   │   ├── timeline_view.dart
│   │   │   │   └── history_list_item.dart
│   │   │   └── providers/
│   │   │       └── review_provider.dart
│   │   │
│   │   ├── profile/            # 用户模块
│   │   │   ├── screens/
│   │   │   │   ├── profile_screen.dart
│   │   │   │   ├── settings_screen.dart
│   │   │   │   ├── account_screen.dart
│   │   │   │   └── about_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── profile_header.dart
│   │   │   │   ├── settings_section.dart
│   │   │   │   ├── settings_tile.dart
│   │   │   │   ├── theme_selector.dart
│   │   │   │   └── language_selector.dart
│   │   │   └── providers/
│   │   │       ├── profile_provider.dart
│   │   │       └── settings_provider.dart
│   │   │
│   │   └── home/               # 主页导航
│   │       ├── screens/
│   │       │   └── home_screen.dart
│   │       └── widgets/
│   │           ├── bottom_nav_bar.dart
│   │           └── navigation_rail.dart
│   │
│   └── routes/                 # 路由管理
│       ├── app_router.dart
│       ├── route_names.dart
│       └── route_guards.dart
│
└── di/                         # 依赖注入
    ├── injection_container.dart
    ├── service_locator.dart
    └── modules/
        ├── data_module.dart
        ├── domain_module.dart
        └── presentation_module.dart
```

## 3. 各层职责说明

### 3.1 Core层
- **constants/**: 定义应用常量，如颜色、路由名、字符串等
- **theme/**: 主题配置，支持亮色/暗色主题切换
- **utils/**: 通用工具类，如日期格式化、验证器等
- **errors/**: 统一的错误处理机制
- **network/**: 网络请求封装（预留给未来云同步功能）

### 3.2 Data层
- **models/**: 数据模型定义，包含序列化/反序列化逻辑
- **repositories/**: 仓库实现，协调本地和远程数据源
- **data_sources/local/**: 本地数据存储，使用SQLite
- **data_sources/remote/**: 远程API调用（预留）
- **services/**: 业务逻辑服务，如任务生成、刷新等

### 3.3 Domain层（可选）
- **entities/**: 纯业务实体，不包含框架相关代码
- **repositories/**: 仓库接口定义
- **use_cases/**: 业务用例，每个用例对应一个业务操作

### 3.4 Presentation层
- **common/**: 跨功能的通用UI组件
- **features/**: 按功能模块组织的UI代码
- **routes/**: 路由配置和导航逻辑

### 3.5 DI层
- **injection_container.dart**: 依赖注入配置
- **service_locator.dart**: 服务定位器
- **modules/**: 模块化的依赖配置

## 4. 文件命名规范

### 4.1 命名约定
- 文件名：使用小写字母和下划线，如 `task_list_screen.dart`
- 类名：使用大驼峰命名法，如 `TaskListScreen`
- 变量名：使用小驼峰命名法，如 `taskList`
- 常量名：使用大写字母和下划线，如 `DEFAULT_TIMEOUT`

### 4.2 文件后缀约定
- `_screen.dart`: 页面文件
- `_widget.dart`: 组件文件
- `_provider.dart`: 状态管理文件
- `_repository.dart`: 仓库文件
- `_service.dart`: 服务文件
- `_model.dart`: 模型文件
- `_dao.dart`: 数据访问对象

## 5. 关键文件功能说明

### 5.1 main.dart
```dart
// 应用程序入口
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化依赖注入
  await setupDependencies();

  // 初始化数据库
  await DatabaseHelper.instance.init();

  runApp(const MyApp());
}
```

### 5.2 app.dart
```dart
// 应用程序配置
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Task Manager',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        initialRoute: RouteNames.splash,
        onGenerateRoute: AppRouter.generateRoute,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

### 5.3 task_generation_service.dart
```dart
// 任务生成服务
class TaskGenerationService {
  // 根据计划规则生成新任务
  Future<Task?> generateNextTask(Plan plan);

  // 计算任务执行窗口
  ExecutionWindow calculateExecutionWindow(Plan plan, Task? lastTask);

  // 检查是否应该生成任务
  bool shouldGenerateTask(Plan plan, Task? lastTask);
}
```

### 5.4 task_list_provider.dart
```dart
// 任务列表状态管理
class TaskListProvider extends StateNotifier<TaskListState> {
  // 加载任务列表
  Future<void> loadTasks();

  // 完成任务
  Future<void> completeTask(Task task);

  // 跳过任务
  Future<void> skipTask(Task task);

  // 刷新任务
  Future<void> refreshTasks();

  // 设置过滤器
  void setFilter(TaskFilter filter);

  // 应用过滤器
  List<TaskModel> _applyFilter(List<TaskModel> tasks, TaskFilter filter);

  // 重新应用当前过滤器
  void _reapplyFilter();
}
```

### 5.5 task_filter_bar.dart
```dart
// 任务过滤条
class TaskFilterBar extends ConsumerWidget {
  // 显示过滤器芯片
  // 支持过滤：全部、待执行、已完成、已跳过
  // 点击芯片切换过滤器
  // 选中状态有视觉反馈
}
```

### 5.6 home_screen.dart
```dart
// 主页面容器（底部导航）
class HomeScreen extends StatefulWidget {
  // 包含底部导航栏
  // 管理页面切换
  // 处理返回按钮
}
```

## 6. 模块间依赖关系

```
Presentation
    ↓
  Domain
    ↓
   Data
    ↓
   Core
```

- **单向依赖**：上层可以依赖下层，反之不行
- **依赖注入**：通过DI容器管理依赖关系
- **接口隔离**：通过接口解耦具体实现

## 7. 第三方库依赖

### 7.1 核心依赖
```yaml
dependencies:
  # 状态管理
  flutter_riverpod: ^2.4.0

  # 本地存储
  sqflite: ^2.3.0
  shared_preferences: ^2.2.0

  # 路由管理
  go_router: ^12.0.0

  # 依赖注入
  get_it: ^7.6.0
  injectable: ^2.3.0

  # 工具库
  intl: ^0.18.0
  uuid: ^4.2.0
  equatable: ^2.0.0
```

### 7.2 UI依赖
```yaml
dependencies:
  # UI组件
  flutter_svg: ^2.0.0
  cached_network_image: ^3.3.0

  # 动画
  lottie: ^2.7.0
  flutter_animate: ^4.3.0

  # 图表
  fl_chart: ^0.64.0

  # 日历
  table_calendar: ^3.0.0
```

### 7.3 开发依赖
```yaml
dev_dependencies:
  # 代码生成
  build_runner: ^2.4.0
  json_serializable: ^6.7.0
  freezed: ^2.4.0

  # 测试
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0

  # 代码质量
  flutter_lints: ^3.0.0
```


## 8. 测试结构

```
test/
├── unit/                       # 单元测试
│   ├── data/
│   ├── domain/
│   └── presentation/
├── widget/                     # 组件测试
│   └── features/
└── integration/               # 集成测试
    └── scenarios/
```

## 9. 开发工具脚本（scripts/）

### 9.1 脚本概述

`scripts/` 目录包含用于开发和测试的命令行工具脚本，主要用于：
- Goal 和 Plan 模板的导入导出
- 数据库管理和调试
- 开发环境的快速设置

### 9.2 模板导入导出工具

#### export_templates.sh
**功能**：从 Android 设备导出 Goals 和 Plans 为 JSON 模板文件

**使用场景**：
- 创建可复用的 Goal/Plan 模板库
- 备份重要的计划数据
- 分享计划模板给其他用户
- 生成测试数据

**使用方法**：
```bash
cd scripts

# 交互式导出（选择要导出的 goal）
./export_templates.sh

# 导出所有 goals 和 plans
./export_templates.sh all

# 导出指定 goal（需要先获取 goal ID）
./export_templates.sh <goal_id> <output_name>
```

**输出**：
- 生成格式化的 JSON 文件到 `templates/` 目录
- 自动清理敏感信息（ID、用户ID、时间戳等）
- 文件命名：`<模板名称>_<时间戳>.json`

#### import_templates.sh
**功能**：将 JSON 模板文件导入到 Android 设备

**使用场景**：
- 快速创建预定义的 Goal 和 Plan
- 导入测试数据
- 使用社区共享的模板
- 在新设备上恢复计划

**使用方法**：
```bash
# 导入指定模板
./import_templates.sh templates/example_template.json

# 导入自定义模板
./import_templates.sh templates/my_fitness_plan.json
```

**特性**：
- 自动生成新的 UUID，避免 ID 冲突
- 关联到当前登录用户
- 导入前验证 JSON 格式
- 支持预览模板内容
- 安全的数据库事务处理

### 9.3 数据库管理工具

#### export_db.sh
**功能**：从 Android 设备导出 SQLite 数据库到本地

**使用场景**：
- 数据库结构查看和分析
- 数据调试和验证
- 使用 DB Browser 等工具查看数据

**使用方法**：
```bash
./export_db.sh
```

**输出**：
- 数据库文件：`debug_db/myassistant.db`
- 自动显示数据库大小和表列表
- 可选：使用 DB Browser for SQLite 打开

#### reset_db.sh
**功能**：重置 Android 设备上的数据库（开发用）

**使用场景**：
- 清除测试数据
- 重新开始测试流程
- 修复数据库错误

**警告**：此操作会删除所有数据，仅用于开发环境

### 9.4 模板格式说明

所有模板文件遵循统一的 JSON 格式，详见 `templates/README.md`

**基本结构**：
```json
{
  "template_name": "模板名称",
  "description": "模板描述",
  "version": "1.0",
  "exported_at": "ISO 8601 时间戳",
  "goals": [
    {
      "title": "目标标题",
      "description": "目标描述",
      "priority": "high|medium|low",
      "tags": ["标签1", "标签2"],
      "status": "active",
      "deadline": "ISO 8601 时间戳或null",
      "successCriteria": "成功标准"
    }
  ],
  "plans": [
    {
      "goal_index": 0,
      "name": "计划名称",
      "description": "计划描述",
      "startDate": "ISO 8601 时间戳",
      "endDate": "ISO 8601 时间戳",
      "status": "active",
      "repeatRule": {
        "type": "oneTime|daily|weekly|monthly",
        "customDays": "位掩码或null"
      },
      "taskConfig": {
        "durationMinutes": "数字或null",
        "repeatCount": "数字或null",
        "evaluationOptions": "数组或null"
      }
    }
  ]
}
```

### 9.5 脚本依赖

**必需工具**：
- `adb` (Android Debug Bridge) - Android SDK Platform-Tools
- `sqlite3` - SQLite 命令行工具
- `jq` - JSON 处理工具

**macOS 安装**：
```bash
# Android SDK Platform-Tools
brew install android-platform-tools

# jq
brew install jq

# sqlite3（通常已预装）
which sqlite3
```

### 9.6 真机使用说明

#### Android 模拟器
直接运行脚本即可，无需额外配置。

#### 真实 Android 手机

**步骤**：
1. 开启开发者选项
   - 设置 → 关于手机 → 连续点击"版本号" 7 次
2. 开启 USB 调试
   - 设置 → 开发者选项 → USB 调试 → 开启
3. USB 连接手机到电脑
   - 手机上允许 USB 调试授权
4. 验证连接：`adb devices`
5. 运行脚本（与模拟器相同）

**真机无 USB 方案（未来可扩展）**：
- 应用内开发者菜单（特殊手势触发）
- Assets 打包预置模板
- 云端模板库（URL 下载）
- 文件选择器（从 Downloads 读取）

### 9.7 示例模板

项目提供了示例模板：`templates/example_template.json`

**内容**：健康生活计划
- 1 个 Goal：健康管理
- 3 个 Plans：
  - 晨跑计划（每周5天，30分钟计时）
  - 健康饮食（每日，质量评估）
  - 睡眠管理（每日，8小时计时）

**用途**：
- 快速测试导入导出功能
- 作为模板格式参考
- 创建自定义模板的起点

### 9.8 最佳实践

1. **开发流程**：
   - 在应用中创建 Goal 和 Plans
   - 使用 `export_templates.sh` 导出为模板
   - 编辑和优化模板 JSON
   - 使用 `import_templates.sh` 测试导入

2. **模板管理**：
   - 为模板使用描述性名称
   - 在 `templates/` 目录组织模板
   - 使用版本控制跟踪模板变更

3. **调试技巧**：
   - 使用 `export_db.sh` 验证数据
   - 使用 `jq` 验证 JSON 格式
   - 检查导入前后的数据库状态

## 10. 文档结构（document/）

### 10.1 技术设计文档（TechnicalDesign/）

- **ProjectStructure.md**（本文档）：项目结构和代码组织
- **DatabaseSchema.md**：数据库设计和表结构
- **Architecture.md**：架构设计和设计模式

### 10.2 用户指南（UserGuide/）

用户使用手册和帮助文档（待补充）

## 总结

本项目结构设计遵循以下原则：
1. **分层架构**：清晰的层次划分，便于维护
2. **模块化**：按功能模块组织代码，高内聚低耦合
3. **可测试性**：通过依赖注入实现可测试性
4. **可扩展性**：预留远程数据源，便于添加云同步
5. **开发友好**：提供丰富的开发工具脚本，提升开发效率
6. **文档完善**：技术文档和脚本说明齐全，易于维护