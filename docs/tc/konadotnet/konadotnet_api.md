# Konado .NET API

## 簡介

Konado.NET 是 Konado 對話系統的 C# API 擴充，透過 Konado.NET，開發者可以在 C# 專案中輕鬆地建立、管理和執行對話內容。

## 使用方法

### 啟用插件


請先啟用 Konado 插件，然後再啟用 Konado .NET API 插件。

場景中應包含 DialogueManager 節點，否則 Konado .NET API 將無法正常工作。

首次啟用 Konado.NET，會遇到如下報錯：

```
無法從路徑 “res://addons/konadotnet/Konadotnet.cs” 加載附加組件腳本：該腳本可能有代碼錯誤。
正在禁用位於 “res://addons/konadotnet/plugin.cfg” 的附加組件以阻止其進一步報錯。
```

```
Unable to load addon script from path: 'res://addons/konadotnet/Konadotnet.cs'.
```

這是正常現象，請重新在 Godot 編譯 Konado.NET，然後重新打開專案即可解決。

如果無法啟用插件，並且在 MSBuild 中沒有任何報錯，可以嘗試關閉專案後，刪除專案根目錄的 `.godot/` 資料夾，然後重新生成專案。


## API 參考

### KonadoAPI

核心 API 類別，提供對 Konado 系統的存取。

#### 屬性

- `bool IsApiReady`: 指示 API 是否已準備就緒
- `KonadoAPI API`: 靜態實例，提供對 Konado API 的存取
- `DialogueManagerAPI DialogueManagerApi`: 對話管理器 API 實例

### DialogueManagerAPI

對話管理器 API，用於控制對話的執行。

#### 方法

- `InitDialogue()`: 初始化對話
- `StartDialogue()`: 開始對話
- `StopDialogue()`: 停止對話

#### 事件

- `ShotStart`: 對話場景開始時觸發
- `ShotEnd`: 對話場景結束時觸發
- `DialogueLineStart(int line)`: 對話行開始時觸發
- `DialogueLineEnd(int line)`: 對話行結束時觸發

### ActingInterface

表演介面，定義背景過渡效果類型。

#### 枚舉

- `BackgroundTransitionEffectsType`: 背景過渡效果類型
  - `NoneEffect`: 無效果
  - `EraseEffect`: 擦除效果
  - `BlindsEffect`: 百葉窗效果
  - `WaveEffect`: 波浪效果
  - `AlphaFadeEffect`: 透明度漸變效果
  - `VortexSwapEffect`: 渦流切換效果
  - `WindmillEffect`: 風車效果
  - `CyberGlitchEffect`: 賽博故障效果

### Wrapper 類別

Wrapper 類別提供了對 GDScript 物件的 C# 封裝，使開發者可以在 C# 中操作 Konado 的各種資料結構，不過目前這些類別並未完全實作，僅提供了部分屬性和方法，有待進一步完善。

#### Dialogue

對話物件包裝器，表示單個對話元素。

##### 屬性

- `Type DialogueType`: 對話類型（枚舉）
- `string BranchId`: 分支 ID
- `Array<Dialogue> BranchDialogue`: 分支對話
- `bool IsBranchLoaded`: 分支是否已載入
- `string CharacterId`: 角色 ID
- `string DialogueContent`: 對話內容
- `DialogueActor ShowActor`: 顯示的角色
- `string ExitActor`: 退出的角色
- `string ChangeStateActor`: 狀態變更的角色
- `string TargetMoveChara`: 移動目標角色
- `Vector2 TargetMovePos`: 移動目標位置
- `Array<DialogueChoice> Choices`: 對話選項
- `string BgmName`: 背景音樂名稱
- `string VoiceId`: 語音 ID
- `string SoundeffectName`: 音效名稱
- `string BackgroundImageName`: 背景圖像名稱
- `BackgroundTransitionEffectsType BackgroundToggleEffects`: 背景切換效果
- `string JumpShotId`: 跳轉場景 ID
- `string LabelNotes`: 標籤註釋
- `Dictionary ActorSnapshots`: 角色快照

##### 對話類型枚舉

- `Start`: 開始
- `OrdinaryDialog`: 普通對話
- `DisplayActor`: 顯示角色
- `ActorChangeState`: 角色狀態變更
- `MoveActor`: 移動角色
- `SwitchBackground`: 切換背景
- `ExitActor`: 角色退出
- `PlayBgm`: 播放背景音樂
- `StopBgm`: 停止背景音樂
- `PlaySoundEffect`: 播放音效
- `ShowChoice`: 顯示選項
- `Branch`: 分支
- `JumpTag`: 跳轉標籤
- `JumpShot`: 跳轉場景
- `TheEnd`: 結束
- `Label`: 標籤

#### DialogueActor

對話角色包裝器，表示對話中的角色物件。

##### 屬性

- `string CharacterName`: 角色名稱
- `string CharacterState`: 角色狀態
- `Vector2 ActorPosition`: 角色位置
- `Vector2 ActorScale`: 角色縮放
- `bool ActorMirror`: 角色鏡像

#### DialogueChoice

對話選項包裝器，表示對話中的選項物件。

##### 屬性

- `string ChoiceText`: 選項文字
- `string JumpTag`: 跳轉標籤

#### KndData

Konado KND_Data 資料基底類別包裝器。

##### 屬性

- `string Type`: 資料類型
- `bool Love`: 是否為喜愛內容
- `string Tip`: 提示資訊

#### KndShot

Konado KND_Shot 鏡頭包裝器，繼承自 KndData。

##### 屬性

- `string Name`: 場景名稱
- `string ShotId`: 場景 ID
- `string SourceStory`: 源故事
- `Array<Dictionary> DialoguesSourceData`: 對話源資料
- `Dictionary Branches`: 分支
- `Dictionary<string, Dictionary> SourceBranches`: 源分支
- `Dictionary<string, int> ActorCharacterMap`: 角色映射

#### KonadoScriptsInterpreter

KonadoScriptsInterpreter 腳本直譯器包裝器，用於解析 Konado 腳本檔案。

##### 方法

- `KndShot ProcessScriptsToData(string path)`: 處理腳本檔案為資料
- `Dialogue ParseSingleLine(string line, long lineNumber, string path)`: 解析單行腳本

## 範例程式碼

### 對話管理

```csharp
using Konado.Runtime.API;

// 獲取 Konado API 實例
var konadoAPI = KonadoAPI.API;
var dialogueManager = KonadoAPI.DialogueManagerApi;

// 檢查 API 是否就緒
if (dialogueManager.IsReady)
{
    // 初始化對話
    dialogueManager.InitDialogue();

    // 開始對話
    dialogueManager.StartDialogue();

    // 停止對話
    dialogueManager.StopDialogue();
}
```

### 對話事件監聽

```csharp
// 監聽對話開始事件
dialogueManager.ShotStart += () => {
    GD.Print("對話場景開始");
};

// 監聽對話結束事件
dialogueManager.ShotEnd += () => {
    GD.Print("對話場景結束");
};

// 監聽對話行開始事件
dialogueManager.DialogueLineStart += (int line) => {
    GD.Print($"對話行 {line} 開始");
};

// 監聽對話行結束事件
dialogueManager.DialogueLineEnd += (int line) => {
    GD.Print($"對話行 {line} 結束");
};
```

### 解析 Konado 腳本

```csharp
using Konado.Wrapper;

// 建立腳本直譯器
var flags = new Godot.Collections.Dictionary<string, Variant>();
var interpreter = new KonadoScriptsInterpreter(flags);

// 解析整個腳本檔案
var shot = interpreter.ProcessScriptsToData("res://dialogues/example.ks");
```