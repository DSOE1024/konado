---
title: シーン形式のリソース
order: 8
---

# シーン形式のリソース

キャラクターと背景は `PackedScene` を参照します。シーンには画像、動画、Spine、Live2D、シェーダー、独自ノードを配置できます。

キャラクターシーンは `KND_CharacterSceneBase` を継承し、`apply_state(state_name)` で状態を反映します。舞台アニメーションには、KS のモーション名と同名のアニメーションを持つ `KND_ActorMotionLayer` を使用します。

背景シーンは `KND_BackgroundSceneBase` を継承します。カメラ命令を使う場合は、一意な名前の `KonadoCamera2D` を追加してください。組み込みトランジションは `KND_BackgroundTransitionLayer` が処理します。
