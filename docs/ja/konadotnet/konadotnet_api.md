---
title: API の使用
order: 2
---

# Konado .NET API

> この機能はまだ実験的な機能であり、いくつかの問題が存在する可能性があります。

## 概要

Konado.NET は Konado 会話システムの C# API 拡張です。Konado.NET を使用すると、開発者は C# プロジェクト内で会話内容を簡単に作成、管理、実行できます。

## 使用方法

### 非 .NET プロジェクト

非 .NET プロジェクトで Konado .NET API を使用すると、以下のエラーが発生します。これは正常な現象です。
```
 ERROR: core/io/resource_loader.cpp:568 - Condition "local_path.is_empty()" is true. Returning: Ref<ResourceLoader::LoadToken>()
  ERROR: Failed to create an autoload, can't load from UID or path: uid://ptylvcqylq7j.
  ERROR: editor/settings/editor_autoload_settings.cpp:571 - Condition "!info->node" is true. Continuing.

```

この問題は Konado の基本機能の使用には影響しませんが、Konado .NET API は使用できません。

### プラグインの有効化

先に Konado プラグインを有効化し、その後 Konado .NET API プラグインを有効化してください。

シーンには DialogueManager ノードが含まれている必要があります。含まれていない場合、Konado .NET API は正常に動作しません。

Konado.NET を初めて有効化すると、以下のエラーが発生する場合があります。

```
パス “res://addons/konadotnet/Konadotnet.cs” からアドオンスクリプトを読み込めません：スクリプトにコードエラーがある可能性があります。
さらなるエラーを防ぐため “res://addons/konadotnet/plugin.cfg” のアドオンを無効化しています。
```

```
Unable to load addon script from path: 'res://addons/konadotnet/Konadotnet.cs'.
```

これは正常です。Godot で Konado.NET を再ビルドし、プロジェクトを再度開くと解決できます。

プラグインを有効化できず、MSBuild にエラーがない場合は、プロジェクトを閉じてプロジェクトルートの `.godot/` フォルダーを削除し、プロジェクトを再生成してみてください。

## API リファレンス

### KonadoAPI

Konado システムへのアクセスを提供するコア API クラスです。

#### プロパティ

- `bool IsApiReady`: API の準備が完了しているかを示します
- `KonadoAPI API`: Konado API へのアクセスを提供する静的インスタンス
- `DialogueManagerAPI DialogueManagerApi`: 会話マネージャー API インスタンス

### DialogueManagerAPI

会話の実行を制御するための会話マネージャー API です。

#### メソッド

- `InitDialogue()`: 会話を初期化
- `StartDialogue()`: 会話を開始
- `StopDialogue()`: 会話を停止

#### イベント

- `ShotStart`: 会話シーン開始時に発火
- `ShotEnd`: 会話シーン終了時に発火
- `DialogueLineStart(int line)`: 会話行開始時に発火
- `DialogueLineEnd(int line)`: 会話行終了時に発火

### ActingInterface

背景トランジション効果タイプを定義する演出インターフェースです。

#### enum

- `BackgroundTransitionEffectsType`: 背景トランジション効果タイプ
  - `NoneEffect`: 効果なし
  - `EraseEffect`: 消去効果
  - `BlindsEffect`: ブラインド効果
  - `WaveEffect`: 波効果
  - `AlphaFadeEffect`: 透明度フェード効果
  - `VortexSwapEffect`: 渦切り替え効果
  - `WindmillEffect`: 風車効果
  - `CyberGlitchEffect`: サイバーグリッチ効果

### Wrapper クラス

Wrapper クラスは GDScript オブジェクトを C# で扱うためのラッパーを提供し、開発者が C# から Konado の各種データ構造を操作できるようにします。ただし、現時点ではこれらのクラスは完全には実装されておらず、一部のプロパティとメソッドのみを提供しています。今後さらに改善される予定です。

#### Dialogue

単一の会話要素を表す会話オブジェクトラッパーです。

##### プロパティ

- `Type DialogueType`: 会話タイプ（enum）
- `string BranchId`: 分岐 ID
- `Array<Dialogue> BranchDialogue`: 分岐会話
- `bool IsBranchLoaded`: 分岐が読み込まれているか
- `string CharacterId`: キャラクター ID
- `string DialogueContent`: 会話内容
- `DialogueActor ShowActor`: 表示するキャラクター
- `string ExitActor`: 退場するキャラクター
- `string ChangeStateActor`: 状態が変更されるキャラクター
- `string TargetMoveChara`: 移動対象キャラクター
- `Vector2 TargetMovePos`: 移動先位置
- `Array<DialogueChoice> Choices`: 会話選択肢
- `string BgmName`: BGM 名
- `string VoiceId`: ボイス ID
- `string SoundeffectName`: 効果音名
- `string BackgroundImageName`: 背景画像名
- `BackgroundTransitionEffectsType BackgroundToggleEffects`: 背景切り替え効果
- `string JumpShotId`: ジャンプ先シーン ID
- `string LabelNotes`: ラベル注釈
- `Dictionary ActorSnapshots`: キャラクタースナップショット

##### 会話タイプ enum

- `Start`: 開始
- `OrdinaryDialog`: 通常会話
- `DisplayActor`: キャラクター表示
- `ActorChangeState`: キャラクター状態変更
- `MoveActor`: キャラクター移動
- `SwitchBackground`: 背景切り替え
- `ExitActor`: キャラクター退場
- `PlayBgm`: BGM 再生
- `StopBgm`: BGM 停止
- `PlaySoundEffect`: 効果音再生
- `ShowChoice`: 選択肢表示
- `Branch`: 分岐
- `JumpTag`: タグへジャンプ
- `JumpShot`: シーンへジャンプ
- `TheEnd`: 終了
- `Label`: ラベル

#### DialogueActor

会話内のキャラクターオブジェクトを表す会話キャラクターラッパーです。

##### プロパティ

- `string CharacterName`: キャラクター名
- `string CharacterState`: キャラクター状態
- `Vector2 ActorPosition`: キャラクター位置
- `Vector2 ActorScale`: キャラクター拡大率
- `bool ActorMirror`: キャラクターミラー

#### DialogueChoice

会話内の選択肢オブジェクトを表す会話選択肢ラッパーです。

##### プロパティ

- `string ChoiceText`: 選択肢テキスト
- `string JumpTag`: ジャンプタグ

#### KndData

Konado KND_Data データ基底クラスのラッパーです。

##### プロパティ

- `string Type`: データタイプ
- `bool Love`: お気に入り内容かどうか
- `string Tip`: ヒント情報

#### KndShot

Konado KND_Shot ショットラッパーで、KndData を継承します。

##### プロパティ

- `string Name`: シーン名
- `string ShotId`: シーン ID
- `string SourceStory`: 元ストーリー
- `Array<Dictionary> DialoguesSourceData`: 会話元データ
- `Dictionary Branches`: 分岐
- `Dictionary<string, Dictionary> SourceBranches`: 元分岐
- `Dictionary<string, int> ActorCharacterMap`: キャラクターマッピング

#### KonadoScriptsInterpreter

KonadoScriptsInterpreter スクリプトインタープリターラッパーで、Konado スクリプトファイルの解析に使用します。

##### メソッド

- `KndShot ProcessScriptsToData(string path)`: スクリプトファイルをデータへ処理
- `Dialogue ParseSingleLine(string line, long lineNumber, string path)`: 単一行スクリプトを解析

## サンプルコード

### 会話管理

```csharp
using Konado.Runtime.API;

// Konado API インスタンスを取得
var konadoAPI = KonadoAPI.API;
var dialogueManager = KonadoAPI.DialogueManagerApi;

// API が準備完了か確認
if (dialogueManager.IsReady)
{
    // 会話を初期化
    dialogueManager.InitDialogue();

    // 会話を開始
    dialogueManager.StartDialogue();

    // 会話を停止
    dialogueManager.StopDialogue();
}
```

### 会話イベントの監視

```csharp
// 会話開始イベントを監視
dialogueManager.ShotStart += () => {
    GD.Print("会話シーン開始");
};

// 会話終了イベントを監視
dialogueManager.ShotEnd += () => {
    GD.Print("会話シーン終了");
};

// 会話行開始イベントを監視
dialogueManager.DialogueLineStart += (int line) => {
    GD.Print($"会話行 {line} 開始");
};

// 会話行終了イベントを監視
dialogueManager.DialogueLineEnd += (int line) => {
    GD.Print($"会話行 {line} 終了");
};
```

### Konado スクリプトの解析

```csharp
using Konado.Wrapper;

// スクリプトインタープリターを作成
var flags = new Godot.Collections.Dictionary<string, Variant>();
var interpreter = new KonadoScriptsInterpreter(flags);

// スクリプトファイル全体を解析
var shot = interpreter.ProcessScriptsToData("res://dialogues/example.ks");
```
