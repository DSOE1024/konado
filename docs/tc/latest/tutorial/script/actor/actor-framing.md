---
title: 演員景別
order: 5
---

# 演員景別

演員景別用於調整單個演員的縮放、偏移與構圖中心，不會移動背景、其他演員或舞臺攝影機。需要移動整個畫面時使用 `cam`；需要改變某個演員在同一背景中的遠近時使用演員景別，兩者可以疊加。

## 內建景別

Konado 預設提供 `default`、`full`、`medium`、`close` 與 `extreme_close`。不同立繪的尺寸和臉部位置可能不同，正式專案應為角色設定專屬的 `KonadoActorFramingProfile`。

## KonadoScript

顯示演員時可直接指定初始景別：

```text
actor show Kona normal at 3 [framing=medium]
```

演員在場時可平滑切換景別：

```text
actor framing Kona close [duration=0.4] [transition=ease_in_out]
```

`transition` 支援 `linear`、`ease_in`、`ease_out` 與 `ease_in_out`。預設等待過渡完成；設定 `[wait=false]` 後劇情會立即繼續，可用於同一時間調整多個演員：

```text
actor framing Kona close [duration=0.4] [wait=false]
actor framing Mia medium [duration=0.4] [wait=false]
```

景別是演員的持久狀態。演員切換表情、播放動作、存檔、讀檔或劇情回滾後都會保留正確景別；新的景別請求會安全取代尚未完成的舊請求。

## 自訂預設

在 Godot 中建立 `KonadoActorFramingProfile` 資源，為其加入 `KonadoActorFramingPreset`，再將資源指派給角色定義的 `actor_framing_profile`。每個預設可設定 ID、縮放、像素偏移、正規化構圖中心，以及預設過渡時間與緩動。

## 程式呼叫

GDScript 可透過 `KonadoDialogueManager` 調整一個或多個演員：

```gdscript
dialogue_manager.stage_controller.set_actor_framing("Kona", &"close", 0.4, "ease_in_out")
dialogue_manager.stage_controller.set_actor_framings({"Kona": "close", "Mia": "medium"}, 0.4)
```

批次介面會先驗證全部演員與預設；任一設定無效時不會只修改其中一部分。Konado.NET 提供對應的 `SetActorFraming()` 與 `SetActorFramings()`。
