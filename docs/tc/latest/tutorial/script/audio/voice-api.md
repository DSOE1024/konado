---
title: 播放語音 API
order: 4
---

# 播放語音 API

`KND_AudioInterface` 提供語音播放、等待播放完成和停止播放的執行階段 API，適用於需要在 GDScript 中直接控制語音的場景。

## 取得音訊介面

在腳本中匯出 `KND_AudioInterface` 參照，然後在 Inspector 中將對話場景的 `KonadoAudioInterface` 節點指派給它：

```gdscript
@export var audio_interface: KND_AudioInterface
@export var voice: AudioStream
```

## 非阻塞播放

`play_voice()` 開始播放後立即返回，不會等待語音結束：

```gdscript
audio_interface.play_voice(voice)
```

如果目前已有語音正在播放，新語音會取代它。

## 播放並等待

需要等待播放結果時，使用 `play_voice_and_wait()`：

```gdscript
var completed := await audio_interface.play_voice_and_wait(voice)
if completed:
	print("語音自然播放完成")
else:
	print("語音已停止、被取代或未能開始播放")
```

返回值含義：

| 返回值 | 含義 |
|---|---|
| `true` | 語音自然播放完成 |
| `false` | 語音被 `stop_voice()` 停止、被新語音取代，或未能開始播放 |

## 停止播放

```gdscript
audio_interface.stop_voice()
```

## 監聽自然播放完成

`voice_finish_playing` 訊號只會在語音自然播放完成時發出。主動停止或被新語音取代時不會發出：

```gdscript
func _ready() -> void:
	audio_interface.voice_finish_playing.connect(_on_voice_finished)


func _on_voice_finished() -> void:
	print("語音自然播放完成")
```
