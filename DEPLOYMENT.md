# Android 部署指南

本文档详细说明如何将 MyAssistant 应用部署到 Android 设备，以及如何使用脚本工具进行数据导入导出。

## 目录

- [系统要求](#系统要求)
- [开发环境部署](#开发环境部署)
- [生产环境部署](#生产环境部署)
- [应用签名配置](#应用签名配置)
- [数据管理脚本](#数据管理脚本)
- [常见问题排查](#常见问题排查)

---

## 系统要求

### 应用要求

- **最低 Android 版本**: Android 6.0 (API 23)
- **目标 Android 版本**: 最新稳定版
- **包名**: `com.example.myassistant`
- **当前版本**: 1.0.0 (Build 1)

### 开发环境要求

1. **Flutter SDK**
   ```bash
   # 检查 Flutter 版本
   flutter --version
   # 要求: Flutter 3.x 或更高版本
   ```

2. **Android SDK**
   - Android SDK Platform-Tools
   - Android SDK Build-Tools
   - Android API 23 及以上

3. **开发工具**
   - Android Studio (推荐) 或 VS Code
   - Java JDK 11 或更高版本

4. **命令行工具** (用于数据管理脚本)
   - `adb` (Android Debug Bridge)
   - `sqlite3` (SQLite 命令行工具)
   - `jq` (JSON 处理工具，仅导入模板时需要)
   - `uuidgen` (UUID 生成工具，macOS 通常已预装)

---

## 开发环境部署

### 1. 环境准备

#### 1.1 安装依赖包

```bash
# 克隆项目后，安装 Flutter 依赖
flutter pub get

# 生成必要的代码文件 (JSON 序列化、依赖注入等)
flutter pub run build_runner build --delete-conflicting-outputs
```

#### 1.2 验证环境

```bash
# 检查 Flutter 环境
flutter doctor -v

# 确保 Android toolchain、Android Studio、Connected device 等都显示 ✓
```

### 2. 运行到 Android 设备

#### 2.1 使用 Android 模拟器 (推荐用于开发)

**创建模拟器 (如果还没有):**

1. 打开 Android Studio
2. Tools → Device Manager
3. Create Virtual Device
4. 选择设备类型 (推荐: Pixel 5 或更新)
5. 选择系统镜像 (API 23 或更高)
6. 完成创建

**启动模拟器并运行:**

```bash
# 查看可用的模拟器
flutter emulators

# 启动指定模拟器
flutter emulators --launch <emulator_id>

# 或直接在 Android Studio 中启动模拟器

# 确认设备连接
flutter devices

# 运行应用 (Debug 模式)
flutter run -d <device_id>

# 或简单地运行到第一个可用设备
flutter run
```

#### 2.2 使用真实 Android 设备

**设置步骤:**

1. **开启开发者选项**
   - 进入: 设置 → 关于手机
   - 连续点击 "版本号" 7 次
   - 返回设置，找到 "开发者选项"

2. **开启 USB 调试**
   - 开发者选项 → USB 调试 → 开启
   - 开发者选项 → USB 安装 (可选) → 开启

3. **连接设备**
   - 使用 USB 数据线连接手机和电脑
   - 手机上会弹出 "允许 USB 调试" 对话框 → 允许
   - 可勾选 "始终允许来自此计算机的调试"

4. **验证连接**
   ```bash
   # 确认设备已连接
   adb devices
   # 应显示: <设备序列号>    device

   flutter devices
   # 应显示你的设备信息
   ```

5. **运行应用**
   ```bash
   flutter run -d <device_id>
   ```

### 3. 调试模式构建

#### 3.1 Debug APK

```bash
# 构建 Debug APK
flutter build apk --debug

# APK 位置
# build/app/outputs/flutter-apk/app-debug.apk
```

#### 3.2 安装 Debug APK 到设备

```bash
# 方法 1: 使用 adb 安装
adb install build/app/outputs/flutter-apk/app-debug.apk

# 方法 2: 直接运行 (自动安装)
flutter install -d <device_id>
```

---

## 生产环境部署

### 1. 版本管理

#### 1.1 更新应用版本

编辑 `pubspec.yaml`:

```yaml
version: 1.0.0+1
# 格式: major.minor.patch+buildNumber
# major.minor.patch = versionName (显示给用户)
# buildNumber = versionCode (Google Play 内部版本号)
```

**版本号规则:**
- **versionName** (1.0.0): 语义化版本号，用户可见
  - major: 重大更新，不兼容的 API 变更
  - minor: 新功能添加，向下兼容
  - patch: Bug 修复，向下兼容
- **versionCode** (1): 递增的整数，每次发布都必须增加

**示例:**
```yaml
version: 1.0.0+1   # 首次发布
version: 1.0.1+2   # Bug 修复
version: 1.1.0+3   # 新功能
version: 2.0.0+4   # 重大更新
```

### 2. 构建生产版本

#### 2.1 Release APK (无签名)

```bash
# 构建 Release APK (使用 debug 签名)
flutter build apk --release

# APK 位置
# build/app/outputs/flutter-apk/app-release.apk
```

**注意**: 此 APK 使用 debug 签名，仅用于测试。Google Play 不接受 debug 签名的应用。

#### 2.2 Release APK (自定义签名)

**步骤 1: 生成签名密钥**

```bash
# 使用 keytool 生成密钥库
keytool -genkey -v -keystore ~/myassistant-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias myassistant

# 按提示输入:
# - 密钥库密码 (妥善保管!)
# - 密钥密码
# - 组织信息 (CN, OU, O, L, ST, C)
```

**步骤 2: 配置签名**

创建 `android/key.properties`:

```properties
storePassword=<密钥库密码>
keyPassword=<密钥密码>
keyAlias=myassistant
storeFile=<密钥库文件路径，例如: /Users/username/myassistant-keystore.jks>
```

**重要**: 将 `key.properties` 添加到 `.gitignore`，切勿提交到版本控制!

```bash
echo "android/key.properties" >> .gitignore
```

**步骤 3: 修改 `android/app/build.gradle.kts`**

在文件开头添加:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

在 `android` 块中添加 `signingConfigs`:

```kotlin
android {
    // ... 现有配置 ...

    signingConfigs {
        create("release") {
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

**步骤 4: 构建签名的 Release APK**

```bash
# 构建使用自定义签名的 Release APK
flutter build apk --release

# APK 位置
# build/app/outputs/flutter-apk/app-release.apk
```

#### 2.3 App Bundle (推荐用于 Google Play)

```bash
# 构建 App Bundle (AAB 格式)
flutter build appbundle --release

# AAB 位置
# build/app/outputs/bundle/release/app-release.aab
```

**App Bundle 优势:**
- Google Play 自动优化 APK 大小
- 针对不同设备配置生成优化的 APK
- 更小的下载大小
- 必须使用此格式上传到 Google Play

### 3. 验证构建产物

#### 3.1 检查 APK 信息

```bash
# 查看 APK 详细信息
aapt dump badging build/app/outputs/flutter-apk/app-release.apk

# 检查关键信息:
# - package: name='com.example.myassistant'
# - versionCode
# - versionName
# - sdkVersion
```

#### 3.2 安装并测试

```bash
# 安装 Release APK 到设备
adb install -r build/app/outputs/flutter-apk/app-release.apk

# 启动应用
adb shell am start -n com.example.myassistant/.MainActivity

# 查看应用日志
adb logcat | grep flutter
```

### 4. 上传到 Google Play

#### 4.1 准备工作

1. **创建 Google Play 开发者账号**
   - 访问: https://play.google.com/console
   - 注册费用: $25 (一次性)

2. **创建应用**
   - 登录 Google Play Console
   - 创建应用 → 输入应用名称 → 选择默认语言

3. **完善应用信息**
   - 应用类别
   - 隐私政策 URL (必需)
   - 应用图标 (512x512 PNG)
   - 功能图片 (1024x500 PNG)
   - 屏幕截图 (手机: 至少 2 张)
   - 应用说明

#### 4.2 上传 App Bundle

1. 在 Google Play Console 中:
   - 生产 → 创建新版本
   - 上传 `app-release.aab`
   - 填写版本说明

2. 提交审核
   - 审核通常需要 1-7 天

#### 4.3 内部测试 (推荐先测试)

1. 测试 → 内部测试 → 创建新版本
2. 上传 AAB
3. 添加测试人员邮箱
4. 发布到内部测试轨道
5. 测试人员会收到测试链接

---

## 应用签名配置

### 1. 推荐的签名密钥管理

#### 1.1 生产密钥

```bash
# 生成生产签名密钥 (10000 天有效期)
keytool -genkey -v \
  -keystore ~/upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload

# 妥善保管密钥库文件和密码!
# 建议存储在:
# - 密码管理器 (如 1Password, LastPass)
# - 安全的云存储 (加密)
# - 离线备份 (USB 驱动器)
```

#### 1.2 密钥信息记录

创建 `KEYSTORE_INFO.md` (不要提交到 Git):

```markdown
# 签名密钥信息

## 密钥库位置
/Users/username/myassistant-keystore.jks

## 密钥别名
myassistant

## 密钥库密码
[记录在密码管理器中]

## 密钥密码
[记录在密码管理器中]

## 生成日期
2025-01-22

## 有效期
2055-01-15 (10000 天)

## SHA-256 指纹
[运行命令获取]:
keytool -list -v -keystore ~/myassistant-keystore.jks -alias myassistant
```

### 2. Google Play App Signing

#### 2.1 启用 Google Play App Signing (推荐)

**优势:**
- Google 管理应用签名密钥
- 即使上传密钥丢失，应用仍可更新
- 自动优化 APK 大小

**设置步骤:**
1. Google Play Console → 应用完整性
2. 应用签名 → 继续
3. 选择 "让 Google 管理和保护您的应用签名密钥"
4. 上传后，Google 会为你生成应用签名密钥

**密钥类型:**
- **应用签名密钥**: Google 保管，用于签署 APK
- **上传密钥**: 你保管，用于签署上传的 AAB

### 3. 签名验证

```bash
# 验证 APK 签名
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk

# 查看签名证书信息
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk

# 获取 SHA-256 指纹 (用于 Firebase、Google APIs)
keytool -list -v -keystore ~/myassistant-keystore.jks -alias myassistant
```

---

## 数据管理脚本

项目提供了一套完整的数据管理脚本，位于 `scripts/` 目录，用于数据备份、恢复和模板导入导出。

### 1. 脚本概览

```
scripts/
├── backup_db.sh          # 完整数据库备份
├── restore_db.sh         # 完整数据库恢复
├── export_templates.sh   # 导出 Goal/Plan 模板
├── import_templates.sh   # 导入 Goal/Plan 模板
├── export_db.sh          # 导出数据库用于调试
│
├── backups/              # 完整备份存储目录
│   ├── *.db              # 数据库备份文件
│   └── *.json            # 备份元数据
│
└── templates/            # 模板存储目录
    └── *.json            # Goal/Plan 模板文件
```

### 2. 前置要求

#### 2.1 安装必需工具

**macOS:**

```bash
# 1. Android Platform-Tools (包含 adb)
brew install android-platform-tools

# 2. SQLite3 (通常已预装)
which sqlite3  # 检查是否已安装

# 3. jq (JSON 处理工具)
brew install jq

# 4. uuidgen (通常已预装)
which uuidgen  # 检查是否已安装

# 验证工具安装
adb --version
sqlite3 --version
jq --version
uuidgen
```

**Linux (Ubuntu/Debian):**

```bash
sudo apt-get update
sudo apt-get install android-tools-adb sqlite3 jq uuid-runtime
```

#### 2.2 设备连接

**使用 Android 模拟器:**

```bash
# 启动模拟器 (通过 Android Studio 或命令行)
flutter emulators --launch <emulator_id>

# 验证连接
adb devices
# 应显示: emulator-5554    device
```

**使用真实设备:**

```bash
# 1. 开启 USB 调试 (参见前文)
# 2. 连接 USB 数据线
# 3. 验证连接
adb devices
# 应显示: <设备序列号>    device
```

### 3. 完整数据库备份/恢复

#### 3.1 创建备份

**基本用法:**

```bash
cd scripts

# 创建备份 (自动命名)
./backup_db.sh

# 创建备份 (自定义名称)
./backup_db.sh my_backup_name
```

**输出示例:**

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

**备份文件说明:**
- `.db` 文件: 完整的 SQLite 数据库
- `.json` 文件: 备份元数据 (时间戳、版本、统计信息)

#### 3.2 恢复备份

**查看可用备份:**

```bash
./restore_db.sh
# 会列出 backups/ 目录中所有可用的备份文件
```

**恢复指定备份:**

```bash
./restore_db.sh backups/username_backup_20251122_143025.db
```

**恢复流程:**

1. 验证备份文件完整性
2. 显示备份信息和统计
3. **自动创建当前数据库的安全备份**
4. 请求确认 (需输入 `yes`)
5. 停止应用并替换数据库
6. 验证恢复结果

**输出示例:**

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

📱 Creating safety backup of current database...
✓ Safety backup created at: .temp_restore/safety_backup/...

⚠ WARNING: This will replace the current database!
  All current data on the device will be overwritten.

Are you sure you want to restore this backup? (yes/no): yes

📱 Restoring database...
✓ Database restored successfully!
```

**重要提示:**
- 恢复操作会**完全替换**当前数据库
- 脚本会自动创建安全备份在 `.temp_restore/safety_backup/`
- 恢复后务必验证数据，确认无误后再删除安全备份

### 4. 模板导出/导入

模板功能用于导出和分享 Goals 和 Plans 的结构，不包含已生成的 Tasks 和执行记录。

#### 4.1 导出模板

**交互式导出 (推荐):**

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

选择编号后，会导出该 Goal 及其所有 Plans 到 `templates/` 目录。

**导出所有 Goals:**

```bash
./export_templates.sh all
# 或
./export_templates.sh
# 然后输入: all
```

**导出指定 Goal (通过 ID):**

```bash
./export_templates.sh <goal_id> <output_name>

# 示例
./export_templates.sh abc-123-def-456 fitness_plan
# 输出: templates/fitness_plan_20251122_143025.json
```

**输出示例:**

```
📤 Goal & Plan Template Exporter

📋 Available Goals:
1. 健康管理 (3 plans)
   Description: 保持健康的生活方式
   Status: active
   Created: 2025-01-15

Select goal number (or 'all' for all goals): 1

📤 Exporting goal: 健康管理

✓ Exported template: templates/健康管理_20251122_143025.json

📊 Template contains:
  Goals: 1
  Plans: 3
  Size: 2.5 KB
```

#### 4.2 导入模板

```bash
cd scripts
./import_templates.sh templates/健康管理_20251122_143025.json
```

**导入流程:**

1. 验证 JSON 格式
2. 显示模板信息
3. 请求确认
4. 导入到当前登录用户
5. 自动生成新的 UUID (避免冲突)
6. 重建 Goal-Plan 关系

**输出示例:**

```
📥 Goal & Plan Template Importer

📄 Validating template file...
✓ Valid JSON format

📋 Template Information:
  Name: 健康管理
  Description: 保持健康的生活方式
  Goals: 1
  Plans: 3

🔍 Getting user information...
✓ User ID: user_123

⚠ This will import:
  • 1 goal(s)
  • 3 plan(s)

Continue with import? (y/n): y

📥 Importing templates...
✓ Imported goal: 健康管理 (id: new-uuid-123...)
✓ Imported plan: 晨跑计划 (id: new-uuid-456...)
✓ Imported plan: 饮食管理 (id: new-uuid-789...)
✓ Imported plan: 睡眠管理 (id: new-uuid-abc...)

✅ Import completed successfully!
✓ Imported 1 goal(s)
✓ Imported 3 plan(s)

💡 Note: Tasks will be auto-generated based on plan repeat rules
   when you next open the app or when the scheduled time arrives.
```

**导入后:**
- Goals 和 Plans 立即可见
- Tasks 会根据 Plan 的重复规则自动生成
- 建议重启应用以刷新数据

### 5. 模板文件格式

#### 5.1 基本结构

```json
{
  "template_name": "健康管理",
  "description": "保持健康的生活方式",
  "version": "1.0",
  "exported_at": "2025-01-22T14:30:00Z",
  "goals": [
    {
      "title": "健康管理",
      "description": "通过合理饮食、运动和睡眠保持健康",
      "priority": "high",
      "tags": ["健康", "生活"],
      "status": "active",
      "deadline": null,
      "successCriteria": "BMI 维持在正常范围，每周运动 3 次"
    }
  ],
  "plans": [
    {
      "goal_index": 0,
      "name": "晨跑计划",
      "description": "每天早晨进行 30 分钟跑步",
      "startDate": "2025-01-01T00:00:00Z",
      "endDate": "2025-12-31T23:59:59Z",
      "status": "active",
      "repeatRule": {
        "type": "daily",
        "interval": 1,
        "startTime": "06:00",
        "endTime": "08:00"
      },
      "taskConfig": {
        "type": "timer",
        "durationMinutes": 30
      }
    }
  ]
}
```

#### 5.2 字段说明

**模板元数据:**
- `template_name`: 模板名称
- `description`: 模板描述
- `version`: 模板格式版本
- `exported_at`: 导出时间 (ISO 8601)

**Goal 字段:**
- `title`: 目标标题 (必需)
- `description`: 目标描述
- `priority`: 优先级 (`low`, `medium`, `high`)
- `tags`: 标签数组
- `status`: 状态 (`active`, `completed`, `paused`)
- `deadline`: 截止日期 (ISO 8601 或 null)
- `successCriteria`: 成功标准

**Plan 字段:**
- `goal_index`: 关联的 Goal 在 `goals` 数组中的索引
- `name`: 计划名称 (必需，不可修改)
- `description`: 计划描述
- `startDate`: 开始日期 (ISO 8601)
- `endDate`: 结束日期 (ISO 8601)
- `status`: 状态
- `repeatRule`: 重复规则对象
- `taskConfig`: 任务配置对象

**repeatRule 类型:**
- `daily`: 每天
- `weekly`: 每周
- `monthly`: 每月
- `custom`: 自定义

**taskConfig 类型:**
- `simple`: 简单打卡
- `timer`: 计时任务
- `counter`: 计数任务
- `evaluation`: 评分任务

详细格式说明请参考: `scripts/templates/README.md`

### 6. 常见使用场景

#### 6.1 设备数据迁移

```bash
# 旧设备
cd scripts
./backup_db.sh device_migration

# 将备份文件传输到新设备 (通过云存储、USB 等)

# 新设备
cd scripts
./restore_db.sh backups/device_migration_*.db
```

#### 6.2 定期数据备份

```bash
# 每周备份 (使用周数命名)
./backup_db.sh weekly_$(date +%Y%W)

# 示例: weekly_202504 (2025年第4周)
```

**自动清理旧备份:**

```bash
# 保留最近 10 个备份，删除其他
cd backups
ls -t *.db | tail -n +11 | xargs rm
ls -t *.json | tail -n +11 | xargs rm
```

#### 6.3 分享计划模板

**导出并分享:**

```bash
# 导出你的健康管理计划
./export_templates.sh
# 选择要导出的 Goal

# 将生成的 JSON 文件发送给他人
# 例如: templates/健康管理_20251122_143025.json
```

**接收并导入:**

```bash
# 接收到模板文件后
./import_templates.sh received_template.json
```

#### 6.4 测试环境数据准备

```bash
# 1. 备份当前数据
./backup_db.sh before_testing

# 2. 导入测试模板
./import_templates.sh templates/test_data.json

# 3. 进行测试...

# 4. 恢复原数据
./restore_db.sh backups/before_testing_*.db
```

### 7. 脚本使用注意事项

#### 7.1 权限要求

- 脚本需要访问设备上的应用私有数据
- **仅在 Debug 构建中可用** (使用 `run-as` 命令)
- Release 构建无法使用这些脚本 (受 Android 安全限制)

#### 7.2 数据安全

**备份文件包含敏感信息:**
- 用户账户信息
- 所有 Goals、Plans、Tasks
- 执行记录

**建议:**
- 不要将备份文件提交到 Git
- 加密存储备份文件
- 定期删除不需要的旧备份

#### 7.3 版本兼容性

- 备份的数据库版本必须兼容应用版本
- 如果数据库 schema 发生变化，旧备份可能需要迁移
- 恢复前检查备份的 `database_version`

### 8. 故障排查

#### 8.1 常见错误

**错误: `No Android device connected`**

```bash
# 检查设备连接
adb devices

# 如果未显示设备:
# - 确保模拟器正在运行
# - 或确保真机已连接且开启 USB 调试
# - 尝试重启 adb: adb kill-server && adb start-server
```

**错误: `No user found in database`**

```bash
# 原因: 应用未初始化或未注册用户
# 解决:
# 1. 启动应用
# 2. 完成用户注册流程
# 3. 重试脚本
```

**错误: `Failed to export database`**

```bash
# 原因: 应用是 Release 构建或权限问题
# 解决:
# 1. 确保使用 Debug 构建
# 2. 重新安装应用: flutter run -d <device_id>
```

**错误: `Invalid SQLite database`**

```bash
# 原因: 备份文件损坏
# 解决: 使用其他备份文件
```

#### 8.2 调试技巧

**导出数据库用于手动检查:**

```bash
./export_db.sh

# 使用 sqlite3 检查
sqlite3 debug_db/myassistant.db

# 或使用 GUI 工具
# - DB Browser for SQLite (推荐)
# - SQLiteStudio
```

**验证 JSON 格式:**

```bash
# 检查模板文件是否有效
jq empty templates/your_template.json

# 如果无输出，则格式正确
# 如果有错误，会显示详细信息
```

**查看数据库统计:**

```bash
./export_db.sh

sqlite3 debug_db/myassistant.db <<EOF
SELECT COUNT(*) as total_goals FROM goals WHERE deleted_at IS NULL;
SELECT COUNT(*) as total_plans FROM plans WHERE deleted_at IS NULL;
SELECT COUNT(*) as total_tasks FROM tasks;
SELECT COUNT(*) as total_executions FROM task_executions;
EOF
```

---

## 常见问题排查

### 1. 构建问题

#### Q: Flutter 构建失败，提示 SDK 版本不兼容

```bash
# 解决方法 1: 升级 Flutter
flutter upgrade

# 解决方法 2: 切换到稳定版本
flutter channel stable
flutter upgrade

# 重新获取依赖
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

#### Q: build_runner 代码生成失败

```bash
# 清理缓存
flutter clean
flutter pub get

# 删除旧的生成文件
find lib -name "*.g.dart" -type f -delete
find lib -name "*.freezed.dart" -type f -delete

# 重新生成
flutter pub run build_runner build --delete-conflicting-outputs
```

#### Q: Gradle 同步失败

```bash
# 清理 Gradle 缓存
cd android
./gradlew clean

# 或删除缓存目录
cd android
rm -rf .gradle build
cd app
rm -rf .gradle build
cd ../..

# 重新构建
flutter clean
flutter build apk --debug
```

### 2. 设备连接问题

#### Q: adb devices 不显示设备

**模拟器:**
```bash
# 重启 adb
adb kill-server
adb start-server

# 确保模拟器正在运行
flutter emulators
flutter emulators --launch <emulator_id>
```

**真实设备:**
```bash
# 检查 USB 连接
# 1. 更换 USB 数据线
# 2. 更换 USB 端口
# 3. 手机上重新授权 USB 调试

# macOS: 安装 Android File Transfer
# https://www.android.com/filetransfer/

# 重启 adb
adb kill-server
adb start-server
```

#### Q: 设备显示为 unauthorized

```bash
# 手机上操作:
# 1. 撤销 USB 调试授权
#    开发者选项 → 撤销 USB 调试授权
# 2. 重新连接 USB
# 3. 点击"允许"授权对话框
# 4. 勾选"始终允许"
```

### 3. 运行时问题

#### Q: 应用闪退或白屏

```bash
# 查看日志
adb logcat | grep -i flutter

# 或
flutter logs
```

常见原因:
- 数据库初始化失败
- 权限未授予 (通知权限等)
- 资源文件缺失

#### Q: 数据库版本冲突

```bash
# 卸载应用 (清除所有数据)
adb uninstall com.example.myassistant

# 重新安装
flutter run -d <device_id>
```

### 4. 脚本问题

详见前文 [数据管理脚本 - 故障排查](#81-常见错误)

---

## 最佳实践

### 1. 版本控制

#### 1.1 不要提交的文件

确保 `.gitignore` 包含:

```gitignore
# Android 签名密钥
*.jks
*.keystore
android/key.properties

# 数据库备份
scripts/backups/
scripts/debug_db/

# 敏感脚本临时文件
scripts/.temp_*/

# Flutter 构建产物
build/
```

#### 1.2 提交的文件

应该提交:
- 脚本文件 (`scripts/*.sh`)
- 模板示例 (`scripts/templates/example_template.json`)
- 文档 (`scripts/README.md`, `DEPLOYMENT.md`)

### 2. 发布流程

**推荐的发布流程:**

```bash
# 1. 更新版本号
# 编辑 pubspec.yaml: version: 1.1.0+2

# 2. 生成变更日志
# 编辑 CHANGELOG.md

# 3. 运行测试
flutter test

# 4. 构建 Release
flutter build appbundle --release

# 5. 验证构建产物
aapt dump badging build/app/outputs/bundle/release/app-release.aab

# 6. 提交代码
git add .
git commit -m "Release v1.1.0"
git tag v1.1.0
git push origin main --tags

# 7. 上传到 Google Play
# 在 Google Play Console 中上传 AAB

# 8. 创建备份
cd scripts
./backup_db.sh release_v1.1.0_baseline
```

### 3. 数据备份策略

**建议的备份频率:**

- **开发环境**: 每天或每次重大变更前
- **测试环境**: 每次测试开始前
- **生产数据**: 每周 + 重大操作前

**备份存储:**

```bash
# 本地备份
scripts/backups/

# 云端备份 (加密后上传)
# - Google Drive
# - Dropbox
# - iCloud Drive

# 版本控制备份 (仅测试数据)
# 可以考虑将测试模板提交到 Git
```

### 4. 团队协作

#### 4.1 共享测试数据

```bash
# 开发者 A: 创建测试模板
./export_templates.sh all
git add templates/test_data_*.json
git commit -m "Add test data template"
git push

# 开发者 B: 导入测试模板
git pull
./import_templates.sh templates/test_data_*.json
```

#### 4.2 文档维护

团队成员应保持以下文档更新:
- `DEPLOYMENT.md`: 部署流程变更
- `scripts/README.md`: 脚本使用说明
- `CHANGELOG.md`: 版本变更记录

---

## 附录

### A. 相关文档

- [脚本使用指南](scripts/README.md) - 详细的脚本功能说明
- [快速参考](scripts/QUICK_REFERENCE.md) - 常用命令速查
- [模板格式说明](scripts/templates/README.md) - 模板文件格式详解
- [项目指南](CLAUDE.md) - 项目架构和开发规范

### B. 有用的命令

```bash
# Flutter 相关
flutter doctor -v                    # 环境检查
flutter clean                        # 清理构建缓存
flutter pub get                      # 安装依赖
flutter pub upgrade                  # 升级依赖
flutter pub outdated                 # 查看过时依赖
flutter build apk --release          # 构建 Release APK
flutter build appbundle --release    # 构建 App Bundle
flutter install -d <device_id>       # 安装到设备

# ADB 相关
adb devices                          # 列出设备
adb shell pm list packages           # 列出已安装应用
adb install -r app.apk               # 安装 APK
adb uninstall com.example.myassistant  # 卸载应用
adb logcat                           # 查看日志
adb shell am start -n <package>/<activity>  # 启动应用

# Gradle 相关
cd android && ./gradlew tasks        # 列出所有任务
cd android && ./gradlew assembleDebug      # 构建 Debug APK
cd android && ./gradlew assembleRelease    # 构建 Release APK
cd android && ./gradlew clean        # 清理构建

# 签名相关
keytool -list -v -keystore <keystore_file>  # 查看密钥库信息
jarsigner -verify -verbose app.apk   # 验证 APK 签名
apksigner verify --verbose app.apk   # 验证 APK 签名 (新)
```

### C. 故障排查清单

**构建前检查:**
- [ ] Flutter 版本兼容 (`flutter doctor`)
- [ ] 依赖已安装 (`flutter pub get`)
- [ ] 代码已生成 (`build_runner`)
- [ ] 没有编译错误 (`flutter analyze`)

**部署前检查:**
- [ ] 版本号已更新 (`pubspec.yaml`)
- [ ] 签名密钥已配置 (`key.properties`)
- [ ] 测试已通过 (`flutter test`)
- [ ] Release 构建成功 (`flutter build appbundle`)
- [ ] APK/AAB 签名正确 (`jarsigner -verify`)

**数据脚本检查:**
- [ ] 工具已安装 (`adb`, `sqlite3`, `jq`)
- [ ] 设备已连接 (`adb devices`)
- [ ] 应用已安装且为 Debug 版本
- [ ] 用户已注册 (首次启动应用)

---

## 技术支持

如果遇到问题:

1. **查看文档**
   - 本文档 (DEPLOYMENT.md)
   - 脚本文档 (scripts/README.md)
   - Flutter 官方文档: https://flutter.dev/docs

2. **检查日志**
   ```bash
   flutter logs
   adb logcat | grep flutter
   ```

3. **清理并重试**
   ```bash
   flutter clean
   cd android && ./gradlew clean && cd ..
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **社区支持**
   - Flutter GitHub Issues
   - Stack Overflow (tag: flutter)

---

**文档版本**: 1.0
**最后更新**: 2025-01-22
**适用应用版本**: MyAssistant 1.0.0+
