---
title: 播放语音 API
order: 4
---

# 播放语音 API

`KND_AudioInterface` 提供语音播放、等待播放完成和停止播放的运行时 API，适用于需要在 GDScript 中直接控制语音的场景。

## 获取音频接口

在脚本中导出 `KND_AudioInterface` 引用，然后在 Inspector 中将对话场景的 `KonadoAudioInterface` 节点赋给它：

```gdscript
@export var audio_interface: KND_AudioInterface
@export var voice: AudioStream
```

## 非阻塞播放

`play_voice()` 开始播放后立即返回，不会等待语音结束：

```gdscript
audio_interface.play_voice(voice)
```

如果当前已有语音正在播放，新语音会替换它。

## 播放并等待

需要等待播放结果时，使用 `play_voice_and_wait()`：

```gdscript
var completed := await audio_interface.play_voice_and_wait(voice)
if completed:
	print("语音自然播放完成")
else:
	print("语音被停止、替换或未能开始播放")
```

返回值含义：

| 返回值 | 含义 |
|---|---|
| `true` | 语音自然播放完成 |
| `false` | 语音被 `stop_voice()` 停止、被新语音替换，或未能开始播放 |

## 停止播放

```gdscript
audio_interface.stop_voice()
```

## 监听自然播放完成

`voice_finish_playing` 信号只会在语音自然播放完成时发出。主动停止或被新语音替换时不会发出：

```gdscript
func _ready() -> void:
	audio_interface.voice_finish_playing.connect(_on_voice_finished)


func _on_voice_finished() -> void:
	print("语音自然播放完成")
```
