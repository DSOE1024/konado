---
title: 自訂對話框
order: 4
---

# 自訂對話介面

## 介紹

若作品需要自訂對話介面，請先將選用的範本場景複製到專案自己的目錄（例如 `res://ui/dialogue/`），再編輯副本或套用自訂主題。

不要直接修改 `res://addons/konado/` 內的檔案；外掛升級會替換外掛目錄。使用專案內副本後即可正常升級 Konado。

## 編輯範本檔案

`res://addons/konado/template/` 保存內建對話介面範本。將需要的 `.tscn` 複製到專案目錄，在自己的對話場景中實例化副本，並把其中的 `KND_DialogueBox` 節點指派給 `KND_DialogueManager` 的 `_konado_dialogue_box` 屬性。

一般情況下請不要修改節點上的腳本，而是透過修改節點屬性來達到自訂效果。

## 自訂語音進度顯示

一般對話已設定語音標籤且語音正在播放時，對話框會顯示播放進度；沒有語音、資源無法解析或播放結束時會自動隱藏。可在 `KonadoDialogueBox` 節點關閉 `show_voice_progress`。

內建元件來源位於 `res://addons/konado/template/default/voice_progress_display.tscn`。請將它複製到專案後修改顏色、圓角、尺寸或節點結構，再由對話框副本引用。若完全替換元件，請保留以下介面：

```gdscript
func set_progress(current: float, total: float) -> void
func hide_progress() -> void
```
