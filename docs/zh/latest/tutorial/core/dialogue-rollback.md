---
title: 对话回退（上一句）
order: 9
---

# 对话回退（上一句）

对话回退让玩家回到**上一句**可显示内容（台词、选项或全屏文本）并从中断处继续。默认对话模板在功能栏提供「上一句」按钮。

## 运行时 API

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

```gdscript
# 是否可以回退（存在可到达的上一句且未被边界阻挡）
var can: bool = dialogue_manager.timeline.can_step_back()

# 回退到上一句；成功返回 true
if dialogue_manager.timeline.can_step_back():
    dialogue_manager.timeline.step_back()

# 需要回退的已提交指令数（0 表示无法回退）
var steps: int = dialogue_manager.timeline.previous_dialogue_steps()

# Backlog 条目回退：条目自带 VM 提交序号，可直接查询与回退
var reachable: bool = dialogue_manager.timeline.can_rollback_to_entry(serial)
dialogue_manager.timeline.rollback_to_entry(serial)
```

## 原子性

回退复用虚拟机的**可逆事务回滚**，并按目标行的**完整快照**精确恢复场景，再确定性重放目标句。整个过程：

- 取消当前在途事务（打字、语音、等待中的异步操作）并使其令牌失效；
- 按整行快照还原镜头、角色、背景、音频、界面与变量，而不是依赖逐条指令的增量累加，因此异步镜头与带过渡的演出也能被精确还原（快照保留最近 128 句）；
- 在同一帧内完成重放后才刷新界面，因此**不会闪现更早的画面**；
- 恢复失败时进入安全停止状态，绝不留下半还原的画面。

## 边界

只有 `end`（`halt`）构成边界。`jump`（`jump.script`）**可以**被跨越：回退会连同该行所属的剧本一起还原，因此“上一句”会回到你跳来的那个剧本，继续前进时会再次执行 `jump`。

可跨越的副作用：`signal` 与 `asyncam` 会在继续播放经过它们时**重新执行**（信号重新发射、相机重新运镜），因此重选分支会再次触发信号处理函数；成就指令（`achievement unlock` / `increment` / `set_flag`）属于外部累计状态，跨越后**不会重放**，成就不会被收回也不会二次累加。异步相机回退时会先取消进行中的 Tween 再按快照还原变换。信号处理函数若改动**快照之外**的状态，需要自行保证幂等（见「变量与副作用」）。

以下情况仍会拒绝回退（`can_step_back()` 返回 `false`）：

- 上一句之前存在 `end`（`halt`），即剧本已经结束；
- 存在等待处理的运行时错误；
- 执行历史已被清空或超出保留容量（默认保留 512 条指令），或所需的那一行快照已被淘汰（快照缓存保留最近阅读的 128 行，并受 4 MiB 预算约束）；

## 分支回退

如果上一句是**选项**，回退会重新显示全部选项，玩家可以重新选择：

```gdscript
dialogue_manager.timeline.step_back()  # 选项重新出现
```

重新选择后会写入一条新的选项记录；在默认的 `TRIM` 历史策略下，被放弃的那次选择会从历史中移除。若使用 `KEEP` 策略，两次选择都会保留。

再回退一次会落到提问句**之前**的那一句：选项不会改写对话框文本，因此选项所依附的上一句其实仍在屏幕上，回退会一次跳过它，而不是让玩家点到一个毫无变化的步。被取消的选项展示会同时移除，因此按钮不会残留在更早的台词画面上。

## Backlog 跳转（回退到任意一句）

默认模板的 Backlog 面板支持**点击任意一句直接回退**——Ren'Py 的历史界面默认只读，要跳转得自己写代码：

```gdscript
# Backlog 条目携带它对应的 VM 提交序号
var entries: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, false)

# 该条目是否可以作为回退落点
if dialogue_manager.timeline.can_rollback_to_entry(entries[0]["serial"]):
    # 回退到那一句：与「上一句」共用同一条原子路径
    dialogue_manager.timeline.rollback_to_entry(entries[0]["serial"])
```

语义与「上一句」完全一致：按该行快照精确还原场景、同一帧内重放、可跨剧本（`jump`）回退、跨越的不可逆副作用按策略处理、还原失败即进入安全停止。

以下条目不可回退：

- **当前正在显示的那一行**（尚未提交，序号为 0）——面板里它只作展示，不可点击；
- 序号无效，或该行的快照已超出保留范围（最近 128 行，见「边界」）。

回退后面板记录会同步裁剪到目标行；继续前进时，被跨越的可重放副作用（`signal`）会重新执行，因此最终状态与首次播放一致。

## 变量与副作用

回退只撤销**快照内的状态**（脚本变量、镜头、角色、背景、音频、界面与执行位置），其余按下面的规则处理：

| 写入目标 | 回退时 | 继续播放经过该指令时 |
| --- | --- | --- |
| `$` 临时变量 / `%` 持久变量（由 `set`、`add` 等写入） | 精确还原到目标行：快照内**整体替换**，连快照之后新建的变量也会被移除 | 正常重新执行 |
| `signal` 的自定义信号 | 处理函数对**快照内**状态的改动会被一并还原 | **重新发射**，处理函数再次执行 |
| `achievement unlock` / `increment` / `set_flag` | 不撤销（成就只增不减） | **不重放**，不会二次计数 |
| 快照之外的状态（单例、外部存档、自定义 Resource） | 无法撤销 | 由处理函数自行保证幂等（见示例 3） |

**持久变量（`%`）与临时变量（`$`）都在快照内**，回退时按目标行整体还原；两者的差别在于何时变化：

- `%` 持久变量跨镜头保留（`jump` 到别的剧本后依然有效），并随存档保存；回退会把它还原成**目标行当时的值**。
- `$` 临时变量在切换镜头（`jump`）时被清空；回退会把它还原成目标行当时的值——因此跨剧本回退后，上一剧本的临时变量会重新出现。

> ⚠️ 因为 `%` 是按目标行的快照**整体替换**，在这两行之间由对话之外改动的 `%` 变量（商店、菜单、外部代码直接写 `variable_store`）也会一起被还原：这是「时间回溯」语义。若某个数值必须独立于剧情回退（例如平台货币、账号级进度），请把它放在 Konado 快照之外，而不要用 `%`。

### 示例 1：数值写在脚本变量里（推荐）

```text
set %love = 0
Kona "要开始基础教学吗？"
choice "开始基础教学" -> start_choice
choice "不看了" -> exit_choice

branch start_choice
    add %love 1
    Kona "我们一起学习吧！"
    end
```

回退到选项再选同一支：`%love` 先随快照还原为 `0`，重放时 `add %love 1` 再执行一次 → 结果仍是 `1`，既不会残留成 `2`，也不会丢失。

### 示例 2：`signal` + 只改快照内变量的处理函数

示例 demo 采用的就是这种写法（`sample/demo/demo.gd`）：

```gdscript
func _on_konado_custom_signal(content: Variant) -> void:
    if content == "好感度上升":
        # 改的是 Konado 持久变量：属于快照状态
        dialogue_manager.variable_store.apply_operation(
            "love", KonadoVariableStore.Operation.ADD, 1
        )
```

```text
choice "开始基础教学" -> start_choice

branch start_choice
    ...
    signal 好感度上升
    Kona "感谢你的使用！"
    jump res://sample/demo/demo_02.ks
```

回退跨越这段分支再重选：信号**重新发射**、处理函数再次 `+1`；而它写入的 `%love` 也随行被还原过，因此净结果仍是 `+1`（不会变成 `+2`，也不会停在 `0`）。

### 示例 3：`signal` + 改快照之外的状态（必须自行幂等）

```gdscript
func _on_konado_custom_signal(content: Variant) -> void:
    if content != "解锁画廊":
        return
    # 只作用于快照之外的系统：回退无法撤销它
    external_save.unlock_gallery("cg_01")
```

回退跨越这条指令时信号会重新发射，`unlock_gallery` 会被再次调用。请让它天然幂等，或用**快照内的变量**做守卫：

```gdscript
func _on_konado_custom_signal(content: Variant) -> void:
    if content != "解锁画廊":
        return
    if dialogue_manager.variable_store.get_bool("gallery_cg_01"):
        return
    dialogue_manager.variable_store.set_value("gallery_cg_01", true)
    external_save.unlock_gallery("cg_01")
```

> 想让回退完全可预期：把**权威数值**放进 `%` 持久变量或 `$` 临时变量，外部系统只做表现层（音效、界面、平台成就同步），并让它可重复调用。

### 成就：跨越后不重放

`achievement unlock` / `achievement increment` / `achievement set_flag` 代表外部累计成就：回退可以跨越它们，但继续播放经过时**不会再次执行**——成就不会被收回，也不会被记两次。如果某个成就需要在回退后重新触发，请改用脚本变量表达。

## 与存档、历史的关系

回退是纯内存操作，不改变存档格式；存档与读取仍按原有的原子执行边界工作。对话历史的裁剪遵循 `KonadoDialogueHistory.RollbackPolicy`（详见「对话历史」）。
