---
title: 場景化資源
order: 8
---

# 場景化資源

角色與背景項目現在參照 `PackedScene`。場景中可以放置圖片、影片、Spine、Live2D、shader 或自訂節點。

角色場景應繼承 `KND_CharacterSceneBase`，並在 `apply_state(state_name)` 套用狀態。舞台動作應放在 `KND_ActorMotionLayer` 場景，其動畫名稱需與 KS 動作名稱一致。

背景場景應繼承 `KND_BackgroundSceneBase`。如需使用鏡頭指令，請加入名稱唯一的 `KonadoCamera2D`。內建轉場由 `KND_BackgroundTransitionLayer` 處理。
