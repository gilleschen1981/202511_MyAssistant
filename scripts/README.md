# 数据库管理工具

这些脚本用于在 Android 设备（模拟器或真机）上管理数据库，包括完整备份/恢复和模板导入/导出。

## 功能说明

### 数据库备份/恢复
- **完整备份** (`backup_db.sh`)：备份整个数据库，包含所有表和数据
- **完整恢复** (`restore_db.sh`)：恢复完整的数据库备份
- **包含所有数据**：Users、Goals、Plans、Tasks、Executions、Notifications 等所有表
- **安全保护**：恢复前自动创建安全备份

### 模板导入/导出
- **导出模板** (`export_templates.sh`)：从 Android 设备导出 Goals 和 Plans 为 JSON 模板文件
- **导入模板** (`import_templates.sh`)：将 JSON 模板文件导入到 Android 设备
- **不包含 Tasks**：模板仅包含 Goals 和 Plans，不包含已生成的 Tasks
- **自动生成任务**：导入后，Tasks 会根据 Plan 的重复规则自动生成

### 开发调试工具
- **导出数据库** (`export_db.sh`)：导出数据库文件到本地用于调试

## 前置要求

### 必需工具

1. **Android SDK Platform-Tools** (包含 adb)
   ```bash
   # macOS 安装
   brew install android-platform-tools

   # 或通过 Android Studio 安装
   ```

2. **SQLite3**
   ```bash
   # macOS 通常已预装
   which sqlite3

   # 如未安装
   brew install sqlite3
   ```

3. **jq** (JSON 处理工具，导入时必需)
   ```bash
   brew install jq
   ```

4. **uuidgen** (UUID 生成，macOS 通常已预装)
   ```bash
   which uuidgen
   ```

### Android 设备设置

#### 方案一：Android 模拟器（推荐用于开发）

1. 确保 Android Studio 中有正在运行的模拟器
2. 验证连接：
   ```bash
   adb devices
   # 应该显示：emulator-5554    device
   ```

#### 方案二：真实 Android 手机

1. **开启开发者选项**
   - 进入：设置 → 关于手机
   - 连续点击"版本号" 7 次
   - 返回设置，找到"开发者选项"

2. **开启 USB 调试**
   - 开发者选项 → USB 调试 → 开启

3. **连接手机**
   - 使用 USB 线连接手机和电脑
   - 手机上会弹出"允许 USB 调试"对话框 → 允许

4. **验证连接**
   ```bash
   adb devices
   # 应该显示：<设备序列号>    device
   ```

## 使用方法

### 数据库完整备份

#### 基本用法

```bash
cd scripts
./backup_db.sh
```

脚本会：
1. 导出整个数据库文件
2. 显示数据统计（用户、Goals、Plans、Tasks 等）
3. 生成备份文件和元数据文件
4. 保存到 `backups/` 目录

**输出示例：**
```
💾 Database Backup Tool

📱 Exporting database from device...
✓ Database exported

📊 Database Statistics:
  Users: 1
  Goals: 5 (active)
  Plans: 12 (active)
  Tasks: 156
  Executions: 89
  Notifications: 23

✅ Backup completed successfully!

📁 Backup files:
  Database: backups/username_backup_20251122_143025.db (256KB)
  Metadata: backups/username_backup_20251122_143025.json (512B)
```

#### 指定备份名称

```bash
./backup_db.sh my_weekly_backup
# 将保存为: backups/my_weekly_backup_20251122_143025.db
```

### 数据库恢复

#### 查看可用备份

```bash
./restore_db.sh
# 会列出所有可用的备份文件
```

#### 恢复指定备份

```bash
./restore_db.sh backups/username_backup_20251122_143025.db
```

脚本会：
1. 验证备份文件的完整性
2. 显示备份信息和数据统计
3. **自动创建当前数据库的安全备份**
4. 请求确认（需要输入 `yes`）
5. 停止应用并替换数据库
6. 验证恢复结果

**输出示例：**
```
🔄 Database Restore Tool

📄 Validating backup file...
✓ Valid database file

📊 Backup Information:
  File: username_backup_20251122_143025.db
  Size: 256KB
  Database Version: 1

📈 Data Statistics:
  Users: 1
  Goals: 5 (active)
  Plans: 12 (active)
  Tasks: 156
  Executions: 89

📱 Creating safety backup of current database...
✓ Safety backup created

⚠ WARNING: This will replace the current database!
  All current data on the device will be overwritten.
  A safety backup has been created at: ./.temp_restore/safety_backup/...

Are you sure you want to restore this backup? (yes/no):
```

### 导出模板

#### 1. 导出单个 Goal 及其 Plans

```bash
cd scripts
./export_templates.sh
```

脚本会显示可用的 Goals 列表：
```
📋 Available Goals:

1. 健康管理 (3 plans)
2. 职业发展 (5 plans)
3. 学习成长 (2 plans)

Select goal number (or 'all' for all goals): 1
```

选择一个编号，脚本会：
- 导出该 Goal 的信息
- 导出该 Goal 下所有的 Plans
- 保存为 `templates/健康管理_20250122_143025.json`

#### 2. 导出所有 Goals 和 Plans

```bash
./export_templates.sh
# 输入: all
```

或直接：
```bash
./export_templates.sh all
```

#### 3. 指定输出文件名

```bash
./export_templates.sh <goal_id> <output_name>

# 示例
./export_templates.sh abc-123-def fitness_plan
# 将保存为: templates/fitness_plan_20250122_143025.json
```

### 导入模板

```bash
cd scripts
./import_templates.sh templates/健康管理_20250122_143025.json
```

脚本会：
1. 验证 JSON 格式
2. 显示模板信息（名称、Goals 数量、Plans 数量）
3. 请求确认
4. 导入到当前登录用户的账户
5. 自动生成新的 UUID（避免 ID 冲突）
6. 重新建立 Goal-Plan 关系

**输出示例：**
```
📥 Goal & Plan Template Importer

📄 Validating template file...
✓ Valid JSON format

📋 Template Information:
  Name: 健康管理
  Goals: 1
  Plans: 3

🔍 Getting user information...
✓ User ID: user_123

⚠ This will import:
  • 1 goal(s)
  • 3 plan(s)

Continue with import? (y/n): y

📥 Importing templates...
✓ Imported goal: 健康管理 (id: abc12345...)
✓ Imported plan: 晨跑计划 (id: def67890...)
✓ Imported plan: 饮食管理 (id: ghi01234...)
✓ Imported plan: 睡眠管理 (id: jkl56789...)

✅ Import completed successfully!
✓ Imported 1 goal(s)
✓ Imported 3 plan(s)

💡 Note: Tasks will be auto-generated based on plan repeat rules
   when you next open the app or when the scheduled time arrives.
```

## 模板文件格式

详见 `templates/README.md` 和 `templates/example_template.json`

基本结构：
```json
{
  "template_name": "模板名称",
  "description": "模板描述",
  "version": "1.0",
  "exported_at": "2025-01-22T14:30:00Z",
  "goals": [
    {
      "title": "目标标题",
      "description": "目标描述",
      "priority": "high",
      "tags": ["标签1", "标签2"],
      "status": "active",
      "deadline": null,
      "successCriteria": "成功标准"
    }
  ],
  "plans": [
    {
      "goal_index": 0,
      "name": "计划名称",
      "description": "计划描述",
      "startDate": "2025-01-01T00:00:00Z",
      "endDate": "2025-03-31T23:59:59Z",
      "status": "active",
      "repeatRule": { ... },
      "taskConfig": { ... }
    }
  ]
}
```

## 常见问题

### 备份/恢复相关

### Q: 备份和模板导出有什么区别？

**A:**
- **备份** (`backup_db.sh`)：保存完整数据库，包含所有数据（Users、Goals、Plans、Tasks、Executions等），用于完整恢复
- **模板导出** (`export_templates.sh`)：只导出 Goals 和 Plans 的结构，不包含 Tasks 和执行记录，用于分享和快速创建新计划

**使用场景：**
- 数据迁移到新设备 → 使用备份
- 分享你的计划模板给别人 → 使用模板导出
- 定期数据保护 → 使用备份
- 快速创建类似的计划 → 使用模板导出

### Q: 恢复备份会删除当前数据吗？

**A:** 是的，恢复会完全替换当前数据库。但是：
1. 脚本会**自动创建安全备份**在恢复前
2. 需要输入 `yes` 明确确认才会执行
3. 安全备份保存在 `.temp_restore/safety_backup/` 目录
4. 建议在恢复后验证数据，确认无误后再删除安全备份

### Q: 备份文件可以在不同设备之间使用吗？

**A:** 可以！备份是完整的 SQLite 数据库文件，可以：
1. 在多个 Android 设备之间迁移数据
2. 在模拟器和真机之间同步
3. 保存到云存储（Dropbox、Google Drive 等）作为异地备份
4. 用于开发和测试环境的数据同步

**注意：** 确保应用版本兼容，数据库版本需要匹配或支持自动升级。

### Q: 如何验证备份是否成功？

**A:** 备份后会显示详细的统计信息：
```bash
./backup_db.sh

# 输出会显示：
📊 Database Statistics:
  Users: 1
  Goals: 5
  Plans: 12
  Tasks: 156
```

你还可以：
1. 检查备份文件大小是否合理
2. 查看元数据 JSON 文件的内容
3. 使用 DB Browser for SQLite 打开备份文件验证

### Q: 备份占用多少空间？

**A:** 取决于你的数据量：
- 空数据库：约 20KB
- 包含 100 个任务：约 50-100KB
- 包含 1000 个任务和执行记录：约 200-500KB
- 一般使用场景：小于 1MB

建议定期清理旧备份，保留最近 10-20 个即可。

### Q: 可以自动定期备份吗？

**A:** 当前需要手动执行，但可以通过以下方式实现自动化：

**方法1：cron 定时任务（需要设备始终连接）**
```bash
# 编辑 crontab
crontab -e

# 添加每日备份任务（每天凌晨2点）
0 2 * * * cd /path/to/myassistant/scripts && ./backup_db.sh daily_auto_backup
```

**方法2：Git hooks（提交前自动备份）**
```bash
# 在 .git/hooks/pre-commit 中添加
cd scripts && ./backup_db.sh pre_commit_backup
```

**方法3：应用内实现（需要开发）**
- 在应用中添加定期备份功能
- 可以设置每周/每月自动备份到本地存储
- 未来可以支持云端备份

### 模板相关

### Q: 导出/导入失败，提示 "No Android device connected"

**A:** 检查：
1. 模拟器是否正在运行
2. 或手机是否已连接并开启 USB 调试
3. 运行 `adb devices` 查看设备列表

### Q: 导入失败，提示 "No user found in database"

**A:** 确保：
1. 应用已安装并首次启动
2. 已完成用户注册/登录流程
3. 数据库已初始化

### Q: 导入后看不到数据

**A:** 尝试：
1. 重启应用（下拉刷新）
2. 检查 Goal 的 status 是否为 'active'
3. 查看数据库是否成功插入：`./export_db.sh`

### Q: 能否在真机上不使用 USB 连接导入模板？

**A:** 当前版本不支持。未来可考虑：
1. **内置开发者菜单**：在应用内置隐藏功能，通过特殊手势触发（如长按版本号）
2. **Assets 打包模板**：将模板打包在 `assets/templates/`，应用内选择导入
3. **云端模板库**：通过 URL 下载模板 JSON 并导入
4. **文件选择器**：使用 `file_picker` 包，从 Downloads 文件夹读取 JSON

这些方案需要修改 Flutter 代码，添加 UI 功能。

### Q: 导出的模板可以手动编辑吗？

**A:** 可以！JSON 格式支持手动编辑，但要注意：
1. 保持 JSON 格式正确（可用 `jq` 验证）
2. 不要修改字段名称（如 `title`, `name`, `repeatRule` 等）
3. `repeatRule` 和 `taskConfig` 必须符合应用的数据模型
4. 导入前建议用 `jq empty <file>` 验证格式

### Q: 如何创建自己的模板？

**A:** 三种方式：
1. **从现有数据导出**：在应用中创建 Goal 和 Plans，然后导出
2. **复制示例模板**：复制 `templates/example_template.json`，修改内容
3. **手动编写**：参考 `templates/README.md` 中的格式说明

## 高级用法

### 批量导入多个模板

```bash
for template in templates/*.json; do
    echo "Importing $template..."
    ./import_templates.sh "$template"
done
```

### 自动化测试数据导入

```bash
# 1. 重置数据库
./reset_db.sh

# 2. 导入测试模板
./import_templates.sh templates/test_data.json
```

### 定期备份策略

**推荐的备份策略：**

```bash
# 每日备份
./backup_db.sh daily_backup

# 每周备份
./backup_db.sh weekly_backup

# 重要操作前备份
./backup_db.sh before_major_change
```

**自动清理旧备份：**
```bash
# 保留最近10个备份，删除其他
cd backups
ls -t *.db | tail -n +11 | xargs rm
ls -t *.json | tail -n +11 | xargs rm
```

### 备份与模板的区别

| 功能 | 完整备份 (`backup_db.sh`) | 模板导出 (`export_templates.sh`) |
|------|---------------------------|----------------------------------|
| 用途 | 完整数据备份/恢复 | 分享 Goal/Plan 结构 |
| 包含内容 | 所有表和数据 | 仅 Goals 和 Plans |
| Tasks | ✅ 包含 | ❌ 不包含 |
| Executions | ✅ 包含 | ❌ 不包含 |
| User 信息 | ✅ 包含 | ❌ 不包含 |
| 格式 | SQLite 数据库 | JSON 文本文件 |
| 可编辑性 | ❌ 不建议 | ✅ 可手动编辑 |
| 使用场景 | 灾难恢复、设备迁移 | 模板分享、快速创建计划 |

## 文件结构

```
scripts/
├── README.md                    # 本文件
│
├── backup_db.sh                 # 完整数据库备份脚本
├── restore_db.sh                # 完整数据库恢复脚本
│
├── export_templates.sh          # Goal/Plan 模板导出脚本
├── import_templates.sh          # Goal/Plan 模板导入脚本
│
├── export_db.sh                 # 数据库导出工具（调试用）
│
├── backups/                     # 完整数据库备份目录
│   ├── username_backup_*.db     # 数据库备份文件
│   └── username_backup_*.json   # 备份元数据文件
│
└── templates/                   # Goal/Plan 模板目录
    ├── README.md                # 模板格式说明
    ├── example_template.json    # 示例模板
    └── (其他导出的模板...)
```

## 技术细节

### 数据清理

导出时会清理以下敏感/自动生成的字段：
- `id`, `userId` (导入时重新生成)
- `createdAt`, `updatedAt` (导入时使用当前时间)
- `deletedAt` (仅导出未删除的数据)
- Plan 的统计字段 (`totalTaskCount`, `completedTaskCount` 等)

### UUID 生成

导入时为每个 Goal 和 Plan 生成新的 UUID，避免与现有数据冲突。

### Goal-Plan 关系

- 导出时：Plans 中包含 `goal_index` 字段，指向 `goals` 数组的索引
- 导入时：根据 `goal_index` 重新建立关联关系

### 数据库访问

通过 `adb shell run-as` 访问应用的私有数据目录：
```bash
adb shell run-as com.example.myassistant sqlite3 /data/data/com.example.myassistant/databases/myassistant.db
```

这要求应用是 debuggable 的（debug 构建）。

## 贡献

欢迎贡献新的模板！请将模板文件放在 `templates/` 目录，并在 `templates/README.md` 中添加说明。

## 许可

这些脚本是 MyAssistant 项目的一部分，遵循项目的整体许可。
