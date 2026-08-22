---
title: アクターの画角
order: 5
---

# アクターの画角

アクターの画角は、1 人のアクターの拡大率、オフセット、構図の基準点だけを変更します。背景、ほかのアクター、ステージカメラは移動しません。画面全体を動かす場合は `cam`、同じ背景内で特定のアクターの距離感を変える場合は画角を使用し、両方を組み合わせることもできます。

## 組み込み画角

`default`、`full`、`medium`、`close`、`extreme_close` を利用できます。立ち絵ごとにサイズや顔の位置が異なるため、本番プロジェクトでは必要に応じてキャラクター専用の `KonadoActorFramingProfile` を設定してください。

## KonadoScript

表示時に初期画角を指定できます。

```text
actor show Kona normal at 3 [framing=medium]
```

表示中のアクターを滑らかに切り替えることもできます。

```text
actor framing Kona close [duration=0.4] [transition=ease_in_out]
```

`transition` は `linear`、`ease_in`、`ease_out`、`ease_in_out` に対応します。既定では遷移完了を待ちます。`[wait=false]` を指定すると直ちに物語を続行でき、複数アクターを同時に調整できます。

```text
actor framing Kona close [duration=0.4] [wait=false]
actor framing Mia medium [duration=0.4] [wait=false]
```

画角はアクターの永続状態です。状態変更、モーション、セーブ、ロード、物語のロールバック後も保持され、新しい要求は未完了の古い要求を安全に置き換えます。

## カスタムプリセット

Godot で `KonadoActorFramingProfile` リソースを作成し、`KonadoActorFramingPreset` を追加して、キャラクター定義の `actor_framing_profile` に割り当てます。各プリセットでは ID、拡大率、ピクセルオフセット、正規化された構図基準点、既定の遷移時間とイージングを設定できます。

## コードからの呼び出し

```gdscript
dialogue_manager.stage_controller.set_actor_framing("Kona", &"close", 0.4, "ease_in_out")
dialogue_manager.stage_controller.set_actor_framings({"Kona": "close", "Mia": "medium"}, 0.4)
```

一括 API はすべてのアクターとプリセットを先に検証するため、失敗時に一部だけが変更されません。Konado.NET では `SetActorFraming()` と `SetActorFramings()` を利用できます。
