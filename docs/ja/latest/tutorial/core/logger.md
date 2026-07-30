---
title: Logger
order: 4
---

# ロガー KND_Logger

## はじめに

KND_Logger は Godot Logger の実装を基にしたログモジュールです。ログレベル、ログ形式、ログ出力、ログファイルなどをサポートし、Konado 実行時のログ情報を記録するために使用します。

## ログパス

ログファイルの論理パスは `user://konado_log.log` です。実際のディレクトリは現在の OS とプロジェクト名に応じて Godot が解決し、`OS.get_user_data_dir()` で確認できます。`LOG_FILE_PATH` は組み込み定数のため、保存先を変更する場合はカスタム版プラグインでこの定数を管理してください。

## 画面オーバーレイログ

エラー発生時、会話シーンは画面上にログウィンドウを重ねて表示し、エラー情報を示してゲーム実行を中断します。この機能を無効にしたい場合は、`KND_DialogueManager` の `enable_overlay_log` プロパティを `false` に設定してください。

## ログコールバック

`KND_Logger` のインスタンスは `error_caught(msg)` と `message_caught(message, error)` シグナルを送出します。`KND_DialogueManager` はシーンツリーに入ると内部ロガーを作成して Godot に登録し、`error_caught` で画面オーバーレイを制御します。ロガーはグローバルな自動読み込みではありません。別の `KND_Logger` を作成するカスタム連携では `OS.add_logger()` で登録し、解放前に `OS.remove_logger()` を呼び出して、重複記録や無効なインスタンスの残留を防いでください。
