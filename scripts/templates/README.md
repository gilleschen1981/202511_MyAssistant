# 模板格式说明

本文档详细说明 Goal 和 Plan 模板的 JSON 格式。

## 模板文件结构

```json
{
  "template_name": "模板名称",
  "description": "模板描述（可选）",
  "version": "1.0",
  "exported_at": "2025-01-22T14:30:00Z",
  "author": "作者名称（可选）",
  "goals": [ ... ],
  "plans": [ ... ]
}
```

### 顶层字段

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `template_name` | String | 是 | 模板的显示名称 |
| `description` | String | 否 | 模板的详细描述 |
| `version` | String | 是 | 模板格式版本号（当前为 "1.0"） |
| `exported_at` | ISO 8601 String | 是 | 导出时间戳 |
| `author` | String | 否 | 模板创建者 |
| `goals` | Array | 是 | Goal 对象数组 |
| `plans` | Array | 是 | Plan 对象数组 |

## Goal 对象格式

```json
{
  "title": "目标标题",
  "description": "目标的详细描述",
  "priority": "high",
  "tags": ["标签1", "标签2", "标签3"],
  "status": "active",
  "deadline": "2025-12-31T23:59:59Z",
  "successCriteria": "成功的衡量标准"
}
```

### Goal 字段说明

| 字段 | 类型 | 必需 | 说明 | 可选值 |
|------|------|------|------|---------|
| `title` | String | 是 | 目标标题 | - |
| `description` | String | 否 | 目标描述 | - |
| `priority` | String | 否 | 优先级 | `low`, `medium`, `high` (默认: `medium`) |
| `tags` | Array<String> | 否 | 标签列表 | - |
| `status` | String | 否 | 状态 | `active`, `paused`, `completed`, `deleted` (默认: `active`) |
| `deadline` | ISO 8601 String / null | 否 | 截止日期 | ISO 8601 格式或 `null` |
| `successCriteria` | String | 否 | 成功标准 | - |

**注意**：
- 导入时会忽略 `id`, `userId`, `planIds`, `createdAt`, `updatedAt`, `deletedAt` 字段
- 这些字段会在导入时自动生成

## Plan 对象格式

```json
{
  "goal_index": 0,
  "name": "计划名称",
  "description": "计划的详细描述",
  "startDate": "2025-01-01T00:00:00Z",
  "endDate": "2025-03-31T23:59:59Z",
  "status": "active",
  "repeatRule": {
    "type": "weekly",
    "interval": 1,
    "daysOfWeek": [1, 2, 3, 4, 5],
    "dayOfMonth": null,
    "monthOfYear": null
  },
  "taskConfig": {
    "durationMinutes": 30,
    "repeatCount": null,
    "evaluationOptions": null
  }
}
```

### Plan 字段说明

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `goal_index` | Integer | 是* | 关联的 Goal 在 `goals` 数组中的索引（从 0 开始） |
| `goal_title` | String | 是* | 关联的 Goal 标题（二选一） |
| `name` | String | 是 | 计划名称（导入后不可修改） |
| `description` | String | 否 | 计划描述 |
| `startDate` | ISO 8601 String | 是 | 开始日期 |
| `endDate` | ISO 8601 String | 是 | 结束日期 |
| `status` | String | 否 | 状态 (`active`, `paused`, `completed`, `deleted`) |
| `repeatRule` | Object | 是 | 重复规则（见下文） |
| `taskConfig` | Object | 是 | 任务配置（见下文） |

**\* 关联 Goal 的两种方式**：
1. **通过 `goal_index`**：指向 `goals` 数组的索引（适用于单个模板文件）
2. **通过 `goal_title`**：通过标题查找已存在的 Goal（适用于导入到已有 Goals）

**注意**：
- 导入时会忽略 `id`, `userId`, `goalId`, `createdAt`, `updatedAt`, `deletedAt` 字段
- 统计字段 (`totalTaskCount`, `completedTaskCount` 等) 会被重置为 0

## RepeatRule 对象格式

定义计划的重复规则。

### 类型：OneTime（一次性）

```json
{
  "type": "oneTime",
  "interval": 1,
  "daysOfWeek": null,
  "dayOfMonth": null,
  "monthOfYear": null
}
```

### 类型：Daily（每日）

```json
{
  "type": "daily",
  "interval": 1,
  "daysOfWeek": null,
  "dayOfMonth": null,
  "monthOfYear": null
}
```

**说明**：
- `interval`: 间隔天数（1 = 每天，2 = 每隔一天）

### 类型：Weekly（每周）

```json
{
  "type": "weekly",
  "interval": 1,
  "daysOfWeek": [1, 2, 3, 4, 5],
  "dayOfMonth": null,
  "monthOfYear": null
}
```

**说明**：
- `interval`: 间隔周数（1 = 每周，2 = 每两周）
- `daysOfWeek`: 星期几执行，1=周一，7=周日（数组）

**示例**：
- 每周一三五：`[1, 3, 5]`
- 每周末：`[6, 7]`
- 工作日：`[1, 2, 3, 4, 5]`

### 类型：Monthly（每月）

```json
{
  "type": "monthly",
  "interval": 1,
  "daysOfWeek": null,
  "dayOfMonth": 1,
  "monthOfYear": null
}
```

**说明**：
- `interval`: 间隔月数（1 = 每月，3 = 每季度）
- `dayOfMonth`: 每月的第几天（1-31）

### 类型：Custom（自定义）

```json
{
  "type": "custom",
  "interval": 1,
  "daysOfWeek": [1, 3, 5],
  "dayOfMonth": null,
  "monthOfYear": null
}
```

**说明**：可以组合使用各种规则。

### RepeatRule 字段总览

| 字段 | 类型 | 必需 | 说明 | 示例 |
|------|------|------|------|------|
| `type` | String | 是 | 重复类型 | `oneTime`, `daily`, `weekly`, `monthly`, `custom` |
| `interval` | Integer | 是 | 间隔数量 | `1` (每次), `2` (每隔一次) |
| `daysOfWeek` | Array<Integer> / null | 否 | 星期几（1-7） | `[1, 3, 5]` (周一三五) |
| `dayOfMonth` | Integer / null | 否 | 每月第几天（1-31） | `15` (每月15号) |
| `monthOfYear` | Integer / null | 否 | 每年第几月（1-12） | `6` (每年6月) |

## TaskConfig 对象格式

定义任务的执行配置。

### 配置类型 1：Simple（简单复选框）

```json
{
  "durationMinutes": null,
  "repeatCount": null,
  "evaluationOptions": null
}
```

**说明**：最简单的任务类型，仅需打勾完成。

### 配置类型 2：Timer（计时任务）

```json
{
  "durationMinutes": 30,
  "repeatCount": null,
  "evaluationOptions": null
}
```

**说明**：
- `durationMinutes`: 任务持续时间（分钟）
- 用于需要计时的任务（如跑步 30 分钟）

### 配置类型 3：Counter（计数任务）

```json
{
  "durationMinutes": null,
  "repeatCount": 50,
  "evaluationOptions": null
}
```

**说明**：
- `repeatCount`: 重复次数
- 用于需要计数的任务（如做 50 个俯卧撑）

### 配置类型 4：Evaluation（评估任务）

```json
{
  "durationMinutes": null,
  "repeatCount": null,
  "evaluationOptions": ["优秀", "良好", "一般", "需改进"]
}
```

**说明**：
- `evaluationOptions`: 评估选项数组（字符串数组）
- 用于需要质量评估的任务（如饮食健康程度）

### 配置类型 5：Timer + Counter（计时+计数）

```json
{
  "durationMinutes": 60,
  "repeatCount": 100,
  "evaluationOptions": null
}
```

**说明**：同时需要计时和计数（如 60 分钟内完成 100 次跳绳）

### 配置类型 6：Counter + Evaluation（计数+评估）

```json
{
  "durationMinutes": null,
  "repeatCount": 3,
  "evaluationOptions": ["美味", "一般", "难吃"]
}
```

**说明**：计数并评估质量（如吃 3 餐并评估每餐质量）

### TaskConfig 字段总览

| 字段 | 类型 | 必需 | 说明 | 限制 |
|------|------|------|------|------|
| `durationMinutes` | Integer / null | 是 | 持续时间（分钟） | > 0 或 `null` |
| `repeatCount` | Integer / null | 是 | 重复次数 | > 0 或 `null` |
| `evaluationOptions` | Array<String> / null | 是 | 评估选项 | 2-5 个选项或 `null` |

**重要限制**：
- ❌ **不能同时使用 Timer 和 Evaluation**
- ✅ Timer + Counter 可以组合
- ✅ Counter + Evaluation 可以组合

## 完整示例

### 示例 1：健身计划

```json
{
  "template_name": "30天健身挑战",
  "description": "适合初学者的全面健身计划",
  "version": "1.0",
  "exported_at": "2025-01-22T14:30:00Z",
  "author": "Fitness Coach",
  "goals": [
    {
      "title": "提升体能",
      "description": "通过规律运动提升身体素质和耐力",
      "priority": "high",
      "tags": ["健康", "运动", "挑战"],
      "status": "active",
      "deadline": "2025-02-22T23:59:59Z",
      "successCriteria": "完成30天打卡，体重降低2kg，跑步距离提升50%"
    }
  ],
  "plans": [
    {
      "goal_index": 0,
      "name": "晨跑训练",
      "description": "每周5天，循序渐进提升跑步时长和距离",
      "startDate": "2025-01-23T00:00:00Z",
      "endDate": "2025-02-22T23:59:59Z",
      "status": "active",
      "repeatRule": {
        "type": "weekly",
        "interval": 1,
        "daysOfWeek": [1, 2, 3, 4, 5],
        "dayOfMonth": null,
        "monthOfYear": null
      },
      "taskConfig": {
        "durationMinutes": 30,
        "repeatCount": null,
        "evaluationOptions": null
      }
    },
    {
      "goal_index": 0,
      "name": "力量训练",
      "description": "核心肌群训练，每组动作做标准",
      "startDate": "2025-01-23T00:00:00Z",
      "endDate": "2025-02-22T23:59:59Z",
      "status": "active",
      "repeatRule": {
        "type": "weekly",
        "interval": 1,
        "daysOfWeek": [2, 4, 6],
        "dayOfMonth": null,
        "monthOfYear": null
      },
      "taskConfig": {
        "durationMinutes": 20,
        "repeatCount": 50,
        "evaluationOptions": null
      }
    },
    {
      "goal_index": 0,
      "name": "饮食记录",
      "description": "记录每日三餐，评估饮食健康程度",
      "startDate": "2025-01-23T00:00:00Z",
      "endDate": "2025-02-22T23:59:59Z",
      "status": "active",
      "repeatRule": {
        "type": "daily",
        "interval": 1,
        "daysOfWeek": null,
        "dayOfMonth": null,
        "monthOfYear": null
      },
      "taskConfig": {
        "durationMinutes": null,
        "repeatCount": null,
        "evaluationOptions": ["非常健康", "比较健康", "一般", "需改进"]
      }
    }
  ]
}
```

### 示例 2：学习计划

```json
{
  "template_name": "雅思备考计划",
  "description": "3个月雅思考试准备",
  "version": "1.0",
  "exported_at": "2025-01-22T14:30:00Z",
  "goals": [
    {
      "title": "雅思 7.5 分",
      "description": "听说读写全面提升，目标总分 7.5",
      "priority": "high",
      "tags": ["学习", "英语", "考试"],
      "status": "active",
      "deadline": "2025-04-30T23:59:59Z",
      "successCriteria": "听力8.0, 阅读8.5, 写作7.0, 口语7.0"
    }
  ],
  "plans": [
    {
      "goal_index": 0,
      "name": "听力训练",
      "description": "每日剑桥雅思听力练习",
      "startDate": "2025-02-01T00:00:00Z",
      "endDate": "2025-04-30T23:59:59Z",
      "status": "active",
      "repeatRule": {
        "type": "daily",
        "interval": 1,
        "daysOfWeek": null,
        "dayOfMonth": null,
        "monthOfYear": null
      },
      "taskConfig": {
        "durationMinutes": 45,
        "repeatCount": null,
        "evaluationOptions": null
      }
    },
    {
      "goal_index": 0,
      "name": "口语练习",
      "description": "Part 1-3 全真模拟练习",
      "startDate": "2025-02-01T00:00:00Z",
      "endDate": "2025-04-30T23:59:59Z",
      "status": "active",
      "repeatRule": {
        "type": "weekly",
        "interval": 1,
        "daysOfWeek": [2, 5, 7],
        "dayOfMonth": null,
        "monthOfYear": null
      },
      "taskConfig": {
        "durationMinutes": 30,
        "repeatCount": null,
        "evaluationOptions": ["流利", "较好", "磕磕巴巴"]
      }
    },
    {
      "goal_index": 0,
      "name": "写作练习",
      "description": "Task 1 + Task 2 完整写作",
      "startDate": "2025-02-01T00:00:00Z",
      "endDate": "2025-04-30T23:59:59Z",
      "status": "active",
      "repeatRule": {
        "type": "weekly",
        "interval": 1,
        "daysOfWeek": [3, 6],
        "dayOfMonth": null,
        "monthOfYear": null
      },
      "taskConfig": {
        "durationMinutes": 60,
        "repeatCount": 2,
        "evaluationOptions": null
      }
    }
  ]
}
```

## 验证工具

使用 `jq` 验证模板格式：

```bash
# 验证 JSON 格式
jq empty your_template.json

# 查看 goals 数量
jq '.goals | length' your_template.json

# 查看 plans 数量
jq '.plans | length' your_template.json

# 美化格式
jq '.' your_template.json > formatted_template.json
```

## 常见错误

### 1. Goal-Plan 关联错误

❌ **错误**：
```json
{
  "goals": [{ "title": "Goal 1" }],
  "plans": [{ "goal_index": 1, ... }]  // 数组索引越界
}
```

✅ **正确**：
```json
{
  "goals": [{ "title": "Goal 1" }],
  "plans": [{ "goal_index": 0, ... }]  // 索引从 0 开始
}
```

### 2. RepeatRule 类型不匹配

❌ **错误**：
```json
{
  "repeatRule": {
    "type": "weekly",
    "daysOfWeek": null  // weekly 类型必须指定 daysOfWeek
  }
}
```

✅ **正确**：
```json
{
  "repeatRule": {
    "type": "weekly",
    "daysOfWeek": [1, 2, 3, 4, 5]
  }
}
```

### 3. TaskConfig 不兼容组合

❌ **错误**：
```json
{
  "taskConfig": {
    "durationMinutes": 30,
    "evaluationOptions": ["好", "中", "差"]  // Timer 和 Evaluation 不能同时使用
  }
}
```

✅ **正确**：
```json
{
  "taskConfig": {
    "durationMinutes": null,
    "repeatCount": null,
    "evaluationOptions": ["好", "中", "差"]
  }
}
```

## 贡献模板

欢迎贡献你的模板！请遵循：
1. 使用 `example_template.json` 作为基础
2. 确保 JSON 格式正确
3. 添加清晰的 `template_name` 和 `description`
4. 测试模板可以成功导入
5. 在本文档中添加示例说明
