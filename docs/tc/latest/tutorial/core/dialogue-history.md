---
title: 對話歷史（Backlog）
order: 8
---

# 對話歷史（Backlog）

對話歷史（Backlog）用於回顧玩家已經讀過的台詞。它由執行階段服務 `KonadoDialogueHistory` 維護，並由預設對話範本提供一個可直接開啟的歷史面板。

## 行為約定

- 歷史是**工作階段層級**的：只保存在記憶體中，不寫入存檔，因此不會改變現有存檔格式，舊存檔仍可正常讀取。
- 記錄以**原子交易**為單位：只有被虛擬機成功提交的對話指令才會寫入歷史；被取消、失敗或被取代的指令不會留下任何記錄。
- 目前正在顯示、尚未推進的那一行會作為**待提交項目**暴露，方便面板在開啟時顯示目前台詞。
- 項目數量受 `max_dialogue_history_entries` 限制（預設 `256`），超出後自動淘汰最舊的項目。

## 執行階段 API

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

```gdscript
# 取得歷史項目（時間正序）；include_pending 為 true 時附帶尚未推進的目前行
var entries: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, true)

# 僅取得已提交項目
var committed: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, false)

# 已提交項目數量
var count: int = dialogue_manager.dialogue_history.size()

# 清空歷史（同時丟棄待提交項目）
dialogue_manager.dialogue_history.clear()
```

每個項目包含下列欄位：`kind`（`dialogue`、`choice` 或 `screen_text`）、`speaker`、`text`、`options`（僅 `choice` 項目，當時展示過的全部選項）、`instruction_id`、`shot_path`、`line`、`serial`、`pending`。

### 即時通知

```gdscript
dialogue_manager.dialogue_history.entry_committed.connect(
    func(entry: Dictionary) -> void:
        print("新台詞：", entry["speaker"], entry["text"])
)
```

## 選項歷史

玩家的選擇同樣會被記錄。點選某個分支後會寫入一條 `kind` 為 `choice` 的項目：`text` 是**被選中的選項文字**，`options` 是當時**展示過的全部選項**。預設歷史面板會列出全部選項，並以 `▶` 標示被選中的那一項。選項與台詞一樣遵循原子交易：只有成功提交的選擇才會進入歷史。

## 全螢幕文字歷史

全螢幕文字（`screentext` 指令，NVL 正文）會記錄為一條 `kind` 為 `screen_text` 的項目：`text` 為以換行連接的全部文字，`lines` 為逐行文字陣列。預設面板會逐行顯示。它同樣遵循原子交易：整段文字播放並提交後才會進入歷史。

## 與交易、回滾的關係

歷史記錄與虛擬機原子交易一一對應。預設策略 `TRIM` 會讓歷史在回滾或還原檢查點後與時間線保持一致：被回滾的台詞會從歷史中移除。若希望採用經典視覺小說「看過都保留」的行為，可將策略改為 `KEEP`：

```gdscript
dialogue_manager.dialogue_history.rollback_policy = (
    KonadoDialogueHistory.RollbackPolicy.KEEP
)
```

歷史面板的每一列也是**回退入口**：點擊已提交的條目會直接回退到那一句（詳見[對話回退（上一句）](./dialogue-rollback.md) 的「Backlog 跳轉」）。條目自帶 VM 提交序號，因此自訂介面也能直接驅動：

```gdscript
dialogue_manager.timeline.can_rollback_to_entry(serial)
dialogue_manager.timeline.rollback_to_entry(serial)
```

## 預設範本

預設對話範本在功能列提供「歷史記錄」按鈕，並實例化 `res://addons/konado/templates/default/backlog_panel.tscn`，其腳本為 `res://addons/konado/runtime/ui/backlog/konado_backlog_panel.gd`。若在自訂範本中未連接這兩個匯出，功能會自動停用，不影響其他邏輯。
