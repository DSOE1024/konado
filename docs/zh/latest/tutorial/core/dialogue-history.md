---
title: 对话历史（Backlog）
order: 8
---

# 对话历史（Backlog）

对话历史（Backlog）用于回顾玩家已经读过的台词。它由运行时服务 `KonadoDialogueHistory` 维护，并由默认对话模板提供一个可直接打开的历史面板。

## 行为约定

- 历史是**会话级**的：只保存在内存中，不写入存档，因此不会改变现有的存档格式，旧存档仍然可以正常读取。
- 记录以**原子事务**为单位：只有被虚拟机成功提交的对话指令才会写入历史；被取消、失败或被取代的指令不会留下任何记录。
- 当前正在显示、尚未推进的那一行会作为**待提交条目**暴露，方便面板在打开时显示当前台词。
- 条目数量受 `max_dialogue_history_entries` 限制（默认 `256`），超出后自动淘汰最旧的条目。

## 运行时 API

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

```gdscript
# 获取历史条目（时间正序）；include_pending 为 true 时附带当前尚未推进的行
var entries: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, true)

# 仅获取已提交条目
var committed: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, false)

# 已提交条目数量
var count: int = dialogue_manager.dialogue_history.size()

# 清空历史（同时丢弃待提交条目）
dialogue_manager.dialogue_history.clear()
```

每条条目包含以下字段：

| 字段 | 说明 |
| --- | --- |
| `kind` | 条目类型：`dialogue`（台词）、`choice`（选项）或 `screen_text`（全屏文本） |
| `speaker` | 解析后的署名 |
| `text` | 已插值、已本地化的正文；`choice` 条目为被选中的选项文本 |
| `options` | 该次选择展示过的全部选项文本（仅 `choice` 条目） |
| `instruction_id` | 稳定的指令 ID，例如 `ks:id:start` |
| `shot_path` | 所属剧本文源路径 |
| `line` | 台词或选项在脚本中的行号 |
| `serial` | 对应的虚拟机提交序号 |
| `pending` | 是否为尚未推进的当前行 |

### 实时通知

```gdscript
dialogue_manager.dialogue_history.entry_committed.connect(
    func(entry: Dictionary) -> void:
        print("新台词：", entry["speaker"], entry["text"])
)
```

## 选项历史

玩家的选择同样会被记录。当玩家点选某个分支后会写入一条 `kind` 为 `choice` 的条目：`text` 是**被选中的选项文本**，`options` 是当时**展示过的全部选项**。默认历史面板会列出全部选项，并用 `▶` 高亮被选中的那一项。选项与台词一样遵循原子事务：只有成功提交的选择才会进入历史。

## 全屏文本历史

屏幕文本（`screentext` 指令，NVL 全屏正文）会记录为一条 `kind` 为 `screen_text` 的条目：`text` 为按换行拼接的全部文本，`lines` 为逐行文本数组。默认历史面板会逐行展示该段文本。它同样遵循原子事务：只有整段文本播放并被提交后才进入历史。

## 与事务、回滚的关系

历史记录与虚拟机原子事务一一对应。默认策略 `TRIM` 会让历史在回滚或恢复检查点后与时间线保持一致：被回滚的台词会从历史中移除。若希望采用经典视觉小说“看过的都保留”的行为，可将策略改为 `KEEP`：

```gdscript
dialogue_manager.dialogue_history.rollback_policy = (
    KonadoDialogueHistory.RollbackPolicy.KEEP
)
```

历史面板的每一行也是**回退入口**：点击已提交的条目会直接回退到那一句（详见[对话回退（上一句）](./dialogue-rollback.md) 的「Backlog 跳转」）。条目自带 VM 提交序号，因此自定义界面也能直接驱动：

```gdscript
dialogue_manager.timeline.can_rollback_to_entry(serial)
dialogue_manager.timeline.rollback_to_entry(serial)
```

## 默认模板

默认对话模板在功能栏提供“历史记录”按钮，并实例化 `res://addons/konado/templates/default/backlog_panel.tscn`，其脚本为 `res://addons/konado/runtime/ui/backlog/konado_backlog_panel.gd`。若在自定义模板中未连接这两个导出，功能会自动禁用，不影响其他逻辑。
