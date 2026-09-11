---
title: 對話回退（上一句）
order: 9
---

# 對話回退（上一句）

對話回退讓玩家回到**上一句**可顯示內容（台詞、選項或全螢幕文字）並從中斷處繼續。預設對話範本在功能列提供「上一句」按鈕。

## 執行階段 API

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

```gdscript
# 是否可回退（存在可到達的上一句且未被邊界阻擋）
var can: bool = dialogue_manager.timeline.can_step_back()

# 回退到上一句；成功回傳 true
if dialogue_manager.timeline.can_step_back():
    dialogue_manager.timeline.step_back()

# 需要回退的已提交指令數（0 表示無法回退）
var steps: int = dialogue_manager.timeline.previous_dialogue_steps()

# Backlog 條目回退：條目自帶 VM 提交序號，可直接查詢與回退
var reachable: bool = dialogue_manager.timeline.can_rollback_to_entry(serial)
dialogue_manager.timeline.rollback_to_entry(serial)
```

## 原子性

回退重用虛擬機的**可逆交易回滾**，並依目標行的**完整快照**精確還原場景，再確定性地重放目標句。整個過程：

- 取消目前進行中的交易（打字、語音、等待中的非同步操作）並使其權杖失效；
- 依整行快照還原鏡頭、角色、背景、音訊、介面與變數，而不是依賴逐條指令的增量累加，因此非同步鏡頭與帶過渡的演出也能被精確還原（快照保留最近 128 句）；
- 在同一幀內完成重放後才更新畫面，因此**不會閃現更早的畫面**；
- 還原失敗時進入安全停止狀態，絕不留下半還原的畫面。

## 邊界

只有 `end`（`halt`）構成邊界。`jump`（`jump.script`）**可以**被跨越：回退會連同該行所屬的劇本一起還原，因此「上一句」會回到你跳來的劇本，繼續前進時會再次執行 `jump`。

可跨越的副作用：`signal` 與 `asyncam` 會在繼續播放經過它們時**重新執行**（訊號重新發射、相機重新運鏡），因此重選分支會再次觸發訊號處理函式；成就指令（`achievement unlock` / `increment` / `set_flag`）屬於外部累計狀態，跨越後**不會重放**，成就不會被收回也不會二次累加。非同步相機回退時會先取消進行中的 Tween 再依快照還原變換。訊號處理函式若改動**快照之外**的狀態，需要自行保證幂等（見「變數與副作用」）。

以下情況仍會拒絕回退（`can_step_back()` 回傳 `false`）：

- 上一句之前存在 `end`（`halt`），即劇本已結束；
- 存在等待處理的執行階段錯誤；
- 執行歷史已被清空或超出保留容量（預設保留 512 條指令），或所需的那一行快照已被淘汰（快照快取保留最近閱讀的 128 行，並受 4 MiB 預算約束）。

## 分支回退

若上一句是**選項**，回退會重新顯示全部選項，玩家可以重新選擇：

```gdscript
dialogue_manager.timeline.step_back()  # 選項重新出現
```

重新選擇後會寫入一筆新的選項記錄；在預設的 `TRIM` 歷史策略下，被放棄的那次選擇會從歷史中移除。若使用 `KEEP` 策略，兩次選擇都會保留。

再回退一次會落到提問句**之前**的那一句：選項不會改寫對話框文字，因此選項所依附的上一句其實仍在畫面上，回退會一次跳過它，而不是讓玩家點到一個毫無變化的一步。被取消的選項展示會同時移除，因此按鈕不會殘留在更早的台詞畫面上。

## Backlog 跳轉（回退到任意一句）

預設模板的 Backlog 面板支援**點擊任意一句直接回退**——Ren'Py 的歷史介面預設唯讀，要跳轉得自己寫程式：

```gdscript
# Backlog 條目攜帶它對應的 VM 提交序號
var entries: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, false)

# 該條目是否可以作為回退落點
if dialogue_manager.timeline.can_rollback_to_entry(entries[0]["serial"]):
    # 回退到那一句：與「上一句」共用同一條原子路徑
    dialogue_manager.timeline.rollback_to_entry(entries[0]["serial"])
```

語意與「上一句」完全一致：依該行快照精確還原場景、同一幀內重放、可跨劇本（`jump`）回退、跨越的不可逆副作用按策略處理、還原失敗即進入安全停止。

以下條目不可回退：

- **目前正在顯示的那一行**（尚未提交，序號為 0）——面板裡它只作展示，不可點擊；
- 序號無效，或該行的快照已超出保留範圍（最近 128 行，見「邊界」）。

回退後面板記錄會同步裁剪到目標行；繼續前進時，被跨越的可重放副作用（`signal`）會重新執行，因此最終狀態與首次播放一致。

## 變數與副作用

回退只撤銷**快照內的狀態**（腳本變數、鏡頭、角色、背景、音訊、介面與執行位置），其餘按下列規則處理：

| 寫入目標 | 回退時 | 繼續播放經過該指令時 |
| --- | --- | --- |
| `$` 臨時變數 / `%` 持久變數（由 `set`、`add` 等寫入） | 精確還原到目標行：快照內**整體替換**，連快照之後新建的變數也會被移除 | 正常重新執行 |
| `signal` 的自訂訊號 | 處理函式對**快照內**狀態的改動會被一併還原 | **重新發射**，處理函式再次執行 |
| `achievement unlock` / `increment` / `set_flag` | 不撤銷（成就只增不減） | **不重放**，不會二次計數 |
| 快照之外的狀態（單例、外部存檔、自訂 Resource） | 無法撤銷 | 由處理函式自行保證幂等（見範例 3） |

**持久變數（`%`）與臨時變數（`$`）都在快照內**，回退時按目標行整體還原；兩者的差別在於何時變化：

- `%` 持久變數跨鏡頭保留（`jump` 到別的劇本後依然有效），並隨存檔保存；回退會把它還原成**目標行當時的值**。
- `$` 臨時變數在切換鏡頭（`jump`）時被清空；回退會把它還原成目標行當時的值——因此跨劇本回退後，上一劇本的臨時變數會重新出現。

> ⚠️ 因為 `%` 是按目標行的快照**整體替換**，在這兩行之間由對話之外改動過的 `%` 變數（商店、選單、外部程式直接寫 `variable_store`）也會一起被還原：這是「時間回溯」語意。若某個數值必須獨立於劇情回退（例如平台貨幣、帳號進度），請把它放在 Konado 快照之外，而不要用 `%`。

### 範例 1：數值寫在腳本變數裡（建議）

```text
set %love = 0
Kona "要開始基礎教學嗎？"
choice "開始基礎教學" -> start_choice
choice "不看了" -> exit_choice

branch start_choice
    add %love 1
    Kona "我們一起學習吧！"
    end
```

回退到選項再選同一支：`%love` 先隨快照還原為 `0`，重放時 `add %love 1` 再執行一次 → 結果仍是 `1`，既不會殘留成 `2`，也不會遺失。

### 範例 2：`signal` + 只改快照內變數的處理函式

範例 demo 採用的是這種寫法（`sample/demo/demo.gd`）：

```gdscript
func _on_konado_custom_signal(content: Variant) -> void:
    if content == "好感度上升":
        # 改的是 Konado 持久變數：屬於快照狀態
        dialogue_manager.variable_store.apply_operation(
            "love", KonadoVariableStore.Operation.ADD, 1
        )
```

```text
choice "開始基礎教學" -> start_choice

branch start_choice
    ...
    signal 好感度上升
    Kona "感謝你的使用！"
    jump res://sample/demo/demo_02.ks
```

回退跨越這段分支再重選：訊號**重新發射**、處理函式再次 `+1`；而它寫入的 `%love` 也隨行被還原過，因此淨結果仍是 `+1`（不會變成 `+2`，也不會停在 `0`）。

### 範例 3：`signal` + 改快照之外的狀態（必須自行幂等）

```gdscript
func _on_konado_custom_signal(content: Variant) -> void:
    if content != "解鎖畫廊":
        return
    # 只作用於快照之外的系統：回退無法撤銷它
    external_save.unlock_gallery("cg_01")
```

回退跨越這條指令時訊號會重新發射，`unlock_gallery` 會被再次呼叫。請讓它天生幂等，或用**快照內的變數**做守衛：

```gdscript
func _on_konado_custom_signal(content: Variant) -> void:
    if content != "解鎖畫廊":
        return
    if dialogue_manager.variable_store.get_bool("gallery_cg_01"):
        return
    dialogue_manager.variable_store.set_value("gallery_cg_01", true)
    external_save.unlock_gallery("cg_01")
```

> 想讓回退完全可預期：把**權威數值**放進 `%` 持久變數或 `$` 臨時變數，外部系統只做表現層（音效、介面、平台成就同步），並讓它可重複呼叫。

### 成就：跨越後不重放

`achievement unlock` / `achievement increment` / `achievement set_flag` 代表外部累計成就：回退可以跨越它們，但繼續播放經過時**不會再次執行**——成就不會被收回，也不會被記兩次。如果某個成就需要在回退後重新觸發，請改用腳本變數表達。

## 與存檔、歷史的關係

回退是純記憶體操作，不會改變存檔格式；存檔與讀取仍依原有的原子執行邊界運作。對話歷史的裁剪遵循 `KonadoDialogueHistory.RollbackPolicy`（詳見「對話歷史」）。
