---
title: 自定义对话框
order: 4
---

# 自定义对话界面

## 介绍

如果你的作品需要自定义对话界面，你可以通过修改模板对话界面来实现，同时Godot Engine本身就拥有强大的主题系统，你可以通过修改自定义主题来达到效果。

但是请注意，修改模板对话界面后请不要更新Konado插件，否则你的修改会被覆盖。

## 编辑模板文件

`res://addons/konado/template/` 是对话界面场景，你可以通过修改这个文件来自定义对话界面。

一般情况下请不要修改节点上的脚本，而是通过修改节点上的属性来达到自定义的效果。

## 自定义音频进度显示

普通对话设置了配音标签，并且对应语音资源正在播放时，对话框右下角会显示音频播放进度。没有配音标签、没有找到语音资源，或语音播放结束后，进度显示会自动隐藏。

该功能默认开启。如果项目不需要显示语音进度，可以选中对话框节点 `KonadoDialogueBox`，在检查器中关闭 `show_voice_progress`。

音频进度显示是一个独立组件，默认场景位于：

```text
res://addons/konado/template/voice_progress_display.tscn
```

如果只是修改进度条的颜色、圆角、尺寸或内部布局，优先编辑这个场景。默认组件中包含：

| 节点 | 作用 |
|------|------|
| `VoiceProgressDisplay` | 音频进度显示组件根节点 |
| `VoiceProgressBar` | 实际显示进度的 `ProgressBar` |

常见自定义位置：

| 需求 | 修改位置 |
|------|----------|
| 修改进度条宽高 | `VoiceProgressDisplay.custom_minimum_size` |
| 修改背景颜色 | `VoiceProgressBar` 的 `background` StyleBox |
| 修改进度颜色 | `VoiceProgressBar` 的 `fill` StyleBox |
| 修改圆角 | `background` 和 `fill` StyleBox 的 `corner_radius_*` |
| 改成更复杂的显示样式 | 在 `voice_progress_display.tscn` 中替换或增加子节点 |

如果要调整进度显示在对话框中的位置，请编辑对应对话框模板里的 `VoiceProgressDisplay` 实例，例如：

```text
res://addons/konado/template/knd_dialogue_box.tscn
res://addons/konado/template/knd_dialogue_box_left.tscn
res://addons/konado/template/knd_dialogue_box_middle.tscn
```

组件脚本通过两个方法接收对话框传入的状态：

```gdscript
func set_progress(current: float, total: float) -> void
func hide_progress() -> void
```

如果你想完全替换显示方式，可以保留这两个方法的含义：`set_progress()` 用于接收当前播放时间和总时长，`hide_progress()` 用于在没有配音或播放结束时隐藏组件。
