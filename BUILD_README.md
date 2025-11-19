# MyAssistant - 编译运行指南

本文档提供详细的步骤指导，帮助你成功编译和运行MyAssistant项目。

## 📋 前置要求

### 1. 系统要求
- **操作系统**:
  - macOS (用于iOS和Android开发)
  - Windows 10/11 (仅Android开发)
  - Linux (仅Android开发)
- **磁盘空间**: 至少10GB可用空间
- **内存**: 建议8GB以上RAM

### 2. 必需软件

#### Flutter SDK
- **版本要求**: Flutter 3.x 或更高版本
- **Dart SDK**: 3.8.1 或更高版本（Flutter自带）

#### 开发工具
- **Android Studio** 或 **VS Code** (推荐)
- **Xcode** (仅macOS，用于iOS开发)

## 🚀 快速开始

### 第一步：安装Flutter

#### macOS
```bash
# 使用Homebrew安装
brew install --cask flutter

# 或者手动下载
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"
```

#### Windows
1. 下载Flutter SDK: https://flutter.dev/docs/get-started/install/windows
2. 解压到合适位置（如 `C:\flutter`）
3. 添加到系统PATH环境变量

#### Linux
```bash
# 下载Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# 安装依赖
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa
```

### 第二步：验证Flutter安装

```bash
# 检查Flutter环境
flutter doctor

# 输出应该显示✓标记，如果有问题按提示修复
# 示例输出：
# [✓] Flutter (Channel stable, 3.x.x, on macOS 13.x.x)
# [✓] Android toolchain
# [✓] Xcode (仅macOS)
# [✓] Chrome
# [✓] Android Studio
# [✓] VS Code
```

### 第三步：配置Android环境

1. **安装Android Studio**
   - 下载地址: https://developer.android.com/studio
   - 安装Android SDK (API 23及以上)
   - 安装Android SDK Build-Tools
   - 安装Android SDK Platform-Tools

2. **配置Android模拟器**
   ```bash
   # 在Android Studio中：
   # Tools -> AVD Manager -> Create Virtual Device
   # 选择设备型号 -> 下载系统镜像(推荐API 30+) -> 完成创建
   ```

3. **接受Android许可**
   ```bash
   flutter doctor --android-licenses
   ```

### 第四步：配置iOS环境（仅macOS）

```bash
# 安装Xcode命令行工具
xcode-select --install

# 安装CocoaPods
sudo gem install cocoapods

# 配置iOS模拟器
open -a Simulator
```

## 📦 项目设置

### 1. 克隆项目

```bash
# 克隆项目（如果还没有）
git clone [你的项目地址]
cd myassistant
```

### 2. 安装依赖

```bash
# 获取Flutter依赖包
flutter pub get

# 这会下载pubspec.yaml中定义的所有依赖包
```

### 3. 生成代码

```bash
# 生成JSON序列化代码（.g.dart文件）
flutter pub run build_runner build --delete-conflicting-outputs

# 如果遇到冲突，强制重新生成
flutter pub run build_runner build --delete-conflicting-outputs
```

## 🏗️ 编译运行

### 方式一：使用命令行

#### 运行在模拟器/真机

```bash
# 查看可用设备
flutter devices

# 运行项目（自动选择可用设备）
flutter run

# 指定设备运行
flutter run -d [device_id]

# 示例：
# flutter run -d iPhone_14_Pro  # iOS模拟器
# flutter run -d emulator-5554  # Android模拟器
```

#### 运行在Web浏览器（仅开发测试）

```bash
# 在Chrome浏览器中运行
flutter run -d chrome

# 在Edge浏览器中运行
flutter run -d edge
```

#### 热重载和热重启

运行后在终端中：
- 输入 `r` - 热重载（保持状态）
- 输入 `R` - 热重启（重置状态）
- 输入 `q` - 退出

### 方式二：使用VS Code

1. 安装Flutter和Dart插件
2. 打开项目文件夹
3. 按 `F5` 或点击 "Run and Debug"
4. 选择设备
5. 开始调试

### 方式三：使用Android Studio

1. 安装Flutter插件
2. Open -> 选择项目文件夹
3. 选择设备/模拟器
4. 点击运行按钮（绿色三角）

## 📱 构建发布版本

### Android APK

```bash
# 构建APK（用于直接安装）
flutter build apk --release

# APK文件位置: build/app/outputs/flutter-apk/app-release.apk

# 构建App Bundle（用于Google Play发布）
flutter build appbundle --release

# Bundle位置: build/app/outputs/bundle/release/app-release.aab
```

### iOS（仅macOS）

```bash
# 构建iOS应用
flutter build ios --release

# 使用Xcode打开项目
open ios/Runner.xcworkspace

# 在Xcode中进行签名和发布
```

### 分割APK（减小包体积）

```bash
# 按ABI分割构建
flutter build apk --split-per-abi --release

# 会生成多个APK：
# app-arm64-v8a-release.apk (64位设备)
# app-armeabi-v7a-release.apk (32位设备)
# app-x86_64-release.apk (x64模拟器)
```

## 🔧 常见问题

### 1. 依赖安装失败

```bash
# 清理并重新获取
flutter clean
flutter pub get
```

### 2. 代码生成失败

```bash
# 清理生成的文件
flutter clean
rm -rf .dart_tool/
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Android构建失败

```bash
# 清理Android构建
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### 4. iOS构建失败（macOS）

```bash
# 清理iOS构建
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
```

### 5. 设备未识别

```bash
# Android设备
adb devices  # 确保设备已连接并授权

# iOS设备
flutter doctor  # 检查iOS工具链
```

## 🧪 测试运行

```bash
# 运行所有测试
flutter test

# 运行特定测试文件
flutter test test/models/goal_model_test.dart

# 运行测试并生成覆盖率报告
flutter test --coverage

# 运行集成测试
flutter test integration_test/
```

## 🔍 调试技巧

### 启用详细日志

```bash
# 运行时显示详细日志
flutter run -v

# 构建时显示详细日志
flutter build apk -v
```

### 性能分析

```bash
# 在profile模式运行（性能接近release）
flutter run --profile

# 在release模式运行（最终性能）
flutter run --release
```

### Flutter Inspector

在VS Code或Android Studio中运行时，可以使用Flutter Inspector查看Widget树和性能。

## 📝 项目结构说明

```
myassistant/
├── lib/                    # 源代码
│   ├── main.dart          # 应用入口
│   ├── core/              # 核心工具类
│   ├── data/              # 数据层
│   │   ├── models/        # 数据模型
│   │   ├── repositories/  # 仓库实现
│   │   └── services/      # 业务服务
│   ├── domain/            # 领域层
│   └── presentation/      # 表现层
│       ├── features/      # 功能模块
│       └── routes/        # 路由配置
├── test/                  # 测试代码
├── assets/                # 静态资源
├── pubspec.yaml          # 项目配置
└── README.md             # 项目说明
```

## 🛠️ 开发环境配置建议

### VS Code推荐插件
- Flutter
- Dart
- Flutter Widget Snippets
- Awesome Flutter Snippets
- Error Lens

### Android Studio推荐插件
- Flutter
- Flutter Enhancement Suite
- Rainbow Brackets

### 代码格式化

```bash
# 格式化所有代码
flutter format lib/ test/

# 分析代码问题
flutter analyze
```

## 📚 相关资源

- [Flutter官方文档](https://flutter.dev/docs)
- [Dart语言文档](https://dart.dev/guides)
- [项目需求文档](./document/Requirement.md)
- [技术设计文档](./document/TechnicalDesign/)
- [Flutter中文社区](https://flutterchina.club/)

## ⚠️ 注意事项

1. **首次运行**可能需要下载Gradle和其他依赖，请保持网络畅通
2. **iOS开发**需要Apple开发者账号才能在真机上运行
3. **Android真机调试**需要开启开发者模式和USB调试
4. **生成的.g.dart文件**不要手动修改，会被覆盖
5. **数据库迁移**：如果更改了数据库结构，需要处理版本升级

## 🤝 获取帮助

如果遇到问题：
1. 首先运行 `flutter doctor` 检查环境
2. 查看 [Flutter故障排除指南](https://flutter.dev/docs/development/tools/flutter-fix)
3. 搜索具体错误信息
4. 在项目Issues中提问

---

**最后更新**: 2025-11-12
**Flutter版本要求**: 3.x+
**Dart版本要求**: 3.8.1+