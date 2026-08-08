---
title: シーン形式のリソース
order: 8
---

# シーン形式のリソース

キャラクターと背景は `PackedScene` を参照します。シーンには画像、動画、Spine、Live2D、シェーダー、独自ノードを配置できます。

キャラクターシーンは `KND_CharacterSceneBase` を継承し、`_apply_status(resolved_status_name, original_status_name)` をオーバーライドします。システムは `apply_status(status_name)` を通じてこのメソッドを呼び出します。`actor change` はデフォルトでキャラクターマウントをフェードアウトし、状態を適用してからフェードインします。キャラクターシーンは複製されず、トランジションの完了後にストーリーを続行します。設定については[アクター状態の切り替え](../script/actor/actor-change-state.md)を参照してください。舞台アニメーションには、KS のモーション名と同名のアニメーションを持つ `KND_ActorMotionLayer` を使用します。

背景シーンは `KND_BackgroundSceneBase` を継承します。カメラ命令を使う場合は、一意な名前の `KonadoCamera2D` を追加してください。組み込みトランジションは `KND_BackgroundTransitionLayer` が処理し、デフォルトでは `SubViewport` でシーン全体をキャプチャします。最終表示が未加工の単一ソーステクスチャと完全に一致する場合に限り `DIRECT_TEXTURE` を選択できます。レイアウト、変形、カメラ、アニメーション、マテリアル、色調変更、複数の描画ノードを使用する背景では `VIEWPORT_CAPTURE` を維持してください。
