# 快速参考指南

## 数据库完整备份/恢复

```bash
# 创建完整备份
./backup_db.sh                    # 使用默认名称
./backup_db.sh my_backup          # 指定备份名称

# 恢复备份
./restore_db.sh                   # 查看可用备份
./restore_db.sh backups/xxx.db    # 恢复指定备份
```

## 模板导出/导入

```bash
# 导出模板
./export_templates.sh             # 交互式选择 Goal
./export_templates.sh all         # 导出所有 Goals
./export_templates.sh <id> <name> # 导出指定 Goal

# 导入模板
./import_templates.sh templates/xxx.json
```

## 开发调试

```bash
# 导出数据库文件用于调试
./export_db.sh                    # 导出到 debug_db/ 目录
```

## 常用操作流程

### 设备迁移

```bash
# 旧设备
cd scripts
./backup_db.sh device_migration

# 新设备
./restore_db.sh backups/device_migration_*.db
```

### 定期备份

```bash
# 每周备份
./backup_db.sh weekly_$(date +%Y%W)

# 清理旧备份 (保留最近10个)
cd backups
ls -t *.db | tail -n +11 | xargs rm
ls -t *.json | tail -n +11 | xargs rm
```

### 分享模板

```bash
# 导出
./export_templates.sh all
# 发送 templates/all_templates_*.json 给他人

# 导入
./import_templates.sh received_template.json
```

### 测试数据重置

```bash
# 1. 备份当前数据
./backup_db.sh before_reset

# 2. 导入测试模板
./import_templates.sh templates/test_data.json

# 3. 恢复原数据(如需要)
./restore_db.sh backups/before_reset_*.db
```

## 文件位置

| 类型 | 目录 | 说明 |
|------|------|------|
| 完整备份 | `backups/` | 数据库备份文件 (.db + .json) |
| 模板 | `templates/` | Goal/Plan 模板 (.json) |
| 调试导出 | `debug_db/` | 开发调试用数据库文件 |
| 临时文件 | `.temp_*` | 自动清理的临时目录 |

## 前置要求检查

```bash
# 检查工具是否安装
which adb          # Android Debug Bridge
which sqlite3      # SQLite 数据库工具
which jq           # JSON 处理工具(仅导入模板需要)
which uuidgen      # UUID 生成工具

# 检查设备连接
adb devices

# 检查应用是否安装
adb shell pm list packages | grep myassistant
```

## 故障排除

| 错误 | 原因 | 解决方法 |
|------|------|---------|
| `No Android device connected` | 设备未连接 | `adb devices` 检查连接 |
| `No user found in database` | 应用未初始化 | 先启动应用并注册用户 |
| `Failed to export database` | 权限问题 | 确保使用 debug 构建版本 |
| `Invalid SQLite database` | 备份文件损坏 | 使用其他备份文件 |

## 注意事项

1. **恢复操作不可逆**：恢复前会自动创建安全备份，但仍需谨慎
2. **版本兼容性**：确保备份和应用版本兼容
3. **设备连接**：所有操作都需要设备连接且应用可调试
4. **数据验证**：恢复后建议验证关键数据是否正确
5. **定期清理**：定期清理旧备份文件节省空间
