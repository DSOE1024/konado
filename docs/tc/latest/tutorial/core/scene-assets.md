---
title: 場景化資源
order: 8
---

# 場景化資源

角色與背景項目現在參照 `PackedScene`。場景中可以放置圖片、影片、Spine、Live2D、shader 或自訂節點。

角色場景應繼承 `KND_CharacterSceneBase`，並覆寫 `_apply_status(resolved_status_name, original_status_name)` 來套用狀態；系統會透過 `apply_status(status_name)` 呼叫它。`actor change` 預設會在角色掛載層上依序執行淡出、套用狀態和淡入，不會複製角色場景。轉場完成後才會繼續執行劇情，詳細設定請參閱[演員切換狀態](../script/actor/actor-change-state.md)。舞台動作應放在 `KND_ActorMotionLayer` 場景，其動畫名稱需與 KS 動作名稱一致。

背景場景應繼承 `KND_BackgroundSceneBase`。如需使用鏡頭指令，請加入名稱唯一的 `KonadoCamera2D`。內建轉場由 `KND_BackgroundTransitionLayer` 處理，預設會透過 `SubViewport` 擷取完整場景。只有最終畫面與單張未修改的原始紋理完全一致時，才能選擇 `DIRECT_TEXTURE`；使用版面配置、變換、鏡頭、動畫、材質、染色或多個可繪製節點的背景必須保留 `VIEWPORT_CAPTURE`。
