---
title: 演员景别
order: 5
---

# 演员景别

演员景别用于调整单个演员的缩放、偏移和构图中心，不会移动背景、其他演员或舞台摄像机。需要移动整个画面时使用 `cam`；需要改变某个演员在同一背景中的远近时使用演员景别，两者可以叠加。

## 内置景别

Konado 默认提供 `default`、`full`、`medium`、`close` 和 `extreme_close`。不同立绘的尺寸和面部位置可能不同，正式项目应为角色配置专属的 `KonadoActorFramingProfile`。

## KonadoScript

显示演员时可直接指定初始景别：

```text
actor show Kona normal at 3 [framing=medium]
```

演员在场时可平滑切换景别：

```text
actor framing Kona close [duration=0.4] [transition=ease_in_out]
```

`transition` 支持 `linear`、`ease_in`、`ease_out` 和 `ease_in_out`。默认等待过渡完成；设置 `[wait=false]` 后剧情会立即继续，可用于同一时刻调整多个演员：

```text
actor framing Kona close [duration=0.4] [wait=false]
actor framing Mia medium [duration=0.4] [wait=false]
```

景别是演员的持久状态。演员切换表情、播放动作、存档、读档或剧情回滚后都会保留正确景别；新的景别请求会安全取代尚未完成的旧请求。

## 自定义预设

在 Godot 中创建 `KonadoActorFramingProfile` 资源，为其添加 `KonadoActorFramingPreset`，再将资源分配给角色定义的 `actor_framing_profile`。每个预设可设置 ID、缩放、像素偏移、归一化构图中心以及默认过渡时长和缓动。

## 代码调用

GDScript 可通过对话管理器的舞台控制器调整一个或多个演员：

```gdscript
dialogue_manager.stage_controller.set_actor_framing("Kona", &"close", 0.4, "ease_in_out")
dialogue_manager.stage_controller.set_actor_framings({"Kona": "close", "Mia": "medium"}, 0.4)
```

批量接口会先验证全部演员和预设；任一配置无效时不会只修改其中一部分。Konado.NET 提供对应的 `SetActorFraming()` 与 `SetActorFramings()`。
