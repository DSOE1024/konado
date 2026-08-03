---
title: ボイス再生 API
order: 4
---

# ボイス再生 API

`KND_AudioInterface` は、GDScript からボイスの再生、再生完了の待機、再生停止を行うためのランタイム API を提供します。

## オーディオインターフェースの取得

スクリプトで `KND_AudioInterface` の参照をエクスポートし、Inspector でダイアログシーンの `KonadoAudioInterface` ノードを割り当てます。

```gdscript
@export var audio_interface: KND_AudioInterface
@export var voice: AudioStream
```

## 非ブロッキング再生

`play_voice()` は再生を開始するとすぐに制御を返し、ボイスの終了を待ちません。

```gdscript
audio_interface.play_voice(voice)
```

すでに別のボイスが再生中の場合は、新しいボイスに置き換わります。

## 再生して完了を待つ

再生結果を待つ場合は `play_voice_and_wait()` を使用します。

```gdscript
var completed := await audio_interface.play_voice_and_wait(voice)
if completed:
	print("ボイスが最後まで再生されました")
else:
	print("ボイスが停止、置換されたか、再生を開始できませんでした")
```

戻り値：

| 値 | 意味 |
|---|---|
| `true` | ボイスが最後まで自然に再生された |
| `false` | `stop_voice()` で停止された、別のボイスに置き換えられた、または再生を開始できなかった |

## 再生の停止

```gdscript
audio_interface.stop_voice()
```

## 自然終了の検知

`voice_finish_playing` シグナルは、ボイスが最後まで自然に再生された場合にのみ発行されます。停止または置換された場合は発行されません。

```gdscript
func _ready() -> void:
	audio_interface.voice_finish_playing.connect(_on_voice_finished)


func _on_voice_finished() -> void:
	print("ボイスが最後まで再生されました")
```
