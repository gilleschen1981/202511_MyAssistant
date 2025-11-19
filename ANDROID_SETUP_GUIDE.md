# Android模拟器安装指南

## 1. 下载Android Studio

### 方法1：官网下载（推荐）
1. 访问：https://developer.android.com/studio
2. 点击"Download Android Studio"
3. 选择"Mac with Apple chip"（适用于M1/M2/M3芯片）
4. 接受条款并下载（约1GB）

### 方法2：使用Homebrew（需要先安装Homebrew）
```bash
brew install --cask android-studio
```

## 2. 安装Android Studio

1. 打开下载的`.dmg`文件
2. 将Android Studio拖到Applications文件夹
3. 打开Android Studio（在Applications中找到）

## 3. 初始设置向导

首次启动时，Android Studio会引导您完成设置：

1. **Welcome界面**
   - 点击"Next"

2. **Install Type**
   - 选择"Standard"（标准安装）
   - 点击"Next"

3. **Select UI Theme**
   - 选择您喜欢的主题（Light或Dark）
   - 点击"Next"

4. **SDK Components Setup**
   - 确保以下项目被选中：
     - ✓ Android SDK
     - ✓ Android SDK Platform
     - ✓ Android Virtual Device (AVD)
   - 点击"Next"

5. **Verify Settings**
   - 检查安装摘要
   - 点击"Next"

6. **License Agreement**
   - 接受所有许可协议
   - 点击"Finish"

7. **下载组件**
   - 等待下载完成（约2-3GB，需要10-30分钟）

## 4. 创建Android虚拟设备（AVD）

### 在Android Studio中：

1. **打开AVD Manager**
   - 点击"More Actions" → "Virtual Device Manager"
   - 或从菜单：Tools → AVD Manager

2. **创建虚拟设备**
   - 点击"Create Virtual Device"

3. **选择设备**
   - 推荐：Pixel 6 或 Pixel 7
   - 点击"Next"

4. **选择系统镜像**
   - 推荐：API 33 (Android 13) 或 API 34 (Android 14)
   - 如果旁边有"Download"链接，点击下载
   - 点击"Next"

5. **配置AVD**
   - 名称：保持默认或自定义
   - 点击"Finish"

6. **启动模拟器**
   - 在AVD列表中，点击绿色三角形▶️启动

## 5. 配置Flutter环境

### 设置Android SDK路径：
```bash
# 查看Android SDK位置（通常在）
echo $HOME/Library/Android/sdk

# 配置Flutter
flutter config --android-sdk $HOME/Library/Android/sdk
```

### 接受Android许可：
```bash
flutter doctor --android-licenses
# 输入 y 接受所有许可
```

## 6. 验证安装

```bash
# 检查Flutter环境
flutter doctor

# 列出可用设备
flutter devices

# 应该看到类似：
# emulator-5554 • android-arm64 • Android 13 (API 33)
```

## 7. 运行应用

```bash
# 确保模拟器已启动，然后运行
flutter run

# 或指定设备
flutter run -d emulator-5554
```

## 常见问题

### Q: 模拟器运行很慢？
A: 确保在AVD设置中启用了硬件加速（HAXM/WHPX）

### Q: 找不到Android Studio？
A: 可能安装在自定义位置，使用：
```bash
flutter config --android-studio-dir <path-to-android-studio>
```

### Q: 模拟器无法启动？
A: 检查是否有足够的磁盘空间（需要至少10GB）

## 快速命令参考

```bash
# 列出所有模拟器
flutter emulators

# 启动特定模拟器
flutter emulators --launch <emulator-id>

# 创建新模拟器（命令行）
avdmanager create avd -n test -k "system-images;android-33;google_apis;arm64-v8a"

# 列出已安装的系统镜像
sdkmanager --list | grep system-images
```

## 预计时间

- 下载Android Studio：5-15分钟（取决于网速）
- 安装和初始设置：15-30分钟
- 下载系统镜像：10-20分钟
- 总计：约30-60分钟

---

完成后，您就可以在Android模拟器上测试MyAssistant应用了！