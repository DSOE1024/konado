---
title: 会話履歴（バックログ）
order: 8
---

# 会話履歴（バックログ）

会話履歴（バックログ）は、プレイヤーが既に読んだセリフを振り返るための機能です。ランタイムサービス `KonadoDialogueHistory` が管理し、デフォルトの会話テンプレートにはそのまま開ける履歴パネルが含まれます。

## 動作仕様

- 履歴は**セッション単位**です。メモリ上にのみ保持され、セーブデータには書き込まれないため、既存のセーブ形式は変更されず、古いセーブも引き続き読み込めます。
- 記録は**アトミックトランザクション**単位です。仮想マシンが正常にコミットした会話命令だけが履歴に入り、キャンセル・失敗・上書きされた命令は記録を残しません。
- 画面に表示中でまだ進めていない行は**保留エントリ**として公開され、パネルを開いたときに現在のセリフを表示できます。
- エントリ数は `max_dialogue_history_entries`（既定 `256`）で制限され、超えると最も古いものから削除されます。

## ランタイム API

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

```gdscript
# 時系列順のエントリ。include_pending が true なら未確定の現在行も含む
var entries: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, true)

# コミット済みエントリのみ
var committed: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, false)

# コミット済みエントリ数
var count: int = dialogue_manager.dialogue_history.size()

# 履歴を消去（保留中の行も破棄）
dialogue_manager.dialogue_history.clear()
```

各エントリには `kind`（`dialogue`、`choice`、または `screen_text`）、`speaker`、`text`、`options`（`choice` のみ、提示された全選択肢）、`instruction_id`、`shot_path`、`line`、`serial`、`pending` が含まれます。

### リアルタイム通知

```gdscript
dialogue_manager.dialogue_history.entry_committed.connect(
    func(entry: Dictionary) -> void:
        print("新しいセリフ：", entry["speaker"], entry["text"])
)
```

## 選択履歴

プレイヤーの選択も記録されます。分岐を選ぶと `kind` が `choice` のエントリが書き込まれ、`text` は**選択された選択肢**、`options` は**そのとき提示されたすべての選択肢**になります。既定のパネルは全選択肢を並べ、選ばれたものを `▶` で強調します。選択も台詞と同じくアトミックトランザクションに従い、コミットされた選択だけが履歴に入ります。

## 全画面テキスト履歴

全画面テキスト（`screentext` コマンド、NVL 本文）は `kind` が `screen_text` の 1 エントリとして記録されます。`text` は全行を改行で連結した文字列、`lines` は行ごとのテキスト配列です。既定のパネルは行ごとに表示します。台詞と同じくアトミックトランザクションに従い、最後まで再生してコミットされた時点で履歴に入ります。

## トランザクションとロールバック

履歴は仮想マシンのアトミックトランザクションと一対一に対応します。既定の `TRIM` ポリシーでは、ロールバックやチェックポイント復元後に履歴がタイムラインと一致し、巻き戻されたセリフは履歴から削除されます。これまで見た内容をすべて残す古典的な挙動にする場合は `KEEP` を使用します。

```gdscript
dialogue_manager.dialogue_history.rollback_policy = (
    KonadoDialogueHistory.RollbackPolicy.KEEP
)
```

## デフォルトテンプレート

デフォルトの会話テンプレートは機能バーに「バックログ」ボタンを追加し、`res://addons/konado/templates/default/backlog_panel.tscn`（スクリプトは `res://addons/konado/runtime/ui/backlog/konado_backlog_panel.gd`）を生成します。カスタムテンプレートでこれらのエクスポートを設定しない場合、機能は自動的に無効になり、他への影響はありません。
