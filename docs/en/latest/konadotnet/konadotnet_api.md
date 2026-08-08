---
title: API Usage
order: 2
---

# Konado .NET API

## Introduction

Konado.NET is the C# API extension for the Konado dialogue system. It does not replace the main Konado plugin; it provides a C# layer for:

- Finding and controlling `KND_DialogueManager`
- Listening to Konado dialogue flow signals
- Parsing `.ks` scripts from C#
- Reading and creating wrappers for Konado GDScript resources
- Calling the current Konado autoplay and save APIs

Konado.NET exposes the `KonadoAPI` autoload. Most C# code starts from `KonadoAPI.DialogueManagerApi`.

## Requirements

### Project Type

Konado.NET only works in Godot projects with C# support. Use the .NET build of Godot 4.7.1 or later.

If the plugin is enabled in a non-.NET project, the editor may fail to load:

```text
res://addons/konadotnet/Konadotnet.cs
```

This does not affect the main Konado plugin, but the C# API cannot be used until the project is opened and built with Godot .NET.

### Plugin Order

Enable the `Konado` plugin first, then enable `Konadotnet`. Konadotnet checks that `res://addons/konado/plugin.cfg` exists and that the main plugin is enabled.

### Dialogue Manager Node

The current scene must contain a dialogue manager that provides the complete public API contract of `KND_DialogueManager`:

```text
res://addons/konado/scripts/dialogue/knd_dialogue_manager.gd
```

Konado.NET scans the current scene tree when the API enters the tree and automatically binds a matching manager added later. The node name does not affect discovery.

If a scene contains multiple dialogue managers, bind one explicitly with `BindDialogueManager(Node? source)`.

## Quick Start

```csharp
using Godot;
using Konado.Runtime.API;
using Konado.Wrapper;

public partial class DialogueExample : Node
{
    public override void _Ready()
    {
        var dialogueManager = KonadoAPI.DialogueManagerApi;
        if (dialogueManager == null)
            return;

        dialogueManager.DialogueLineStart += (string nodeId) =>
        {
            GD.Print($"Node started: {nodeId}");
        };

        dialogueManager.CustomSignal += (string content) =>
        {
            GD.Print($"Custom signal: {content}");
        };

        var interpreter = new KonadoScriptsInterpreter();
        var shot = interpreter.ProcessScriptsToData("res://sample/demo/demo_01.ks");
        if (shot == null)
            return;

        dialogueManager.SetShot(shot);
        dialogueManager.InitDialogue();
        dialogueManager.StartDialogue();
    }
}
```

## API Entry Point

### KonadoAPI

`KonadoAPI` is the autoload node created by the Konadotnet plugin.

| Member | Type | Description |
| --- | --- | --- |
| `IsApiReady` | `bool` | Whether the `KonadoAPI` autoload has initialized. This does not guarantee that a `KND_DialogueManager` was found; use `DialogueManagerApi.IsReady` for that. |
| `API` | `static KonadoAPI?` | Static reference to the current autoload instance; `null` before the autoload initializes or after it exits the tree. |
| `DialogueManagerApi` | `static DialogueManagerAPI?` | Dialogue manager API instance; `null` while the autoload is unavailable. |
| `InternationalizationApi` | `static InternationalizationAPI?` | Locale, translation, and localized-story API; `null` while the autoload is unavailable. |

```csharp
if (KonadoAPI.API?.IsApiReady == true
    && KonadoAPI.DialogueManagerApi is { IsReady: true } dialogueManager)
{
    dialogueManager.StartDialogue();
}
```

## InternationalizationAPI

```csharp
var i18n = KonadoAPI.InternationalizationApi;
if (i18n is { IsReady: true })
{
    i18n.LocaleChanged += locale => GD.Print(locale);
    i18n.SetLocale("ja");
    var shot = i18n.LoadLocalizedScript("res://dialogues/chapter.ks", "ja");
    if (shot != null)
        KonadoAPI.DialogueManagerApi?.SetShot(shot);
}
```

The API exposes `IsReady`, `Source`, `Bind`, `Locale`, `AvailableLocales`,
`SetLocale`, `NormalizeLocale`, `RegisterTranslation`, `UnregisterTranslation`,
`ResolveScriptPath`, and `LoadLocalizedScript`. `ResolveScriptPath()` returns an
empty string and `LoadLocalizedScript()` returns `null` when the API is not ready
or the localized script cannot be loaded.

## DialogueManagerAPI

`DialogueManagerAPI` is the C# control layer for `KND_DialogueManager`. It forwards calls to the underlying GDScript node.

### Properties

| Property | Type | Description |
| --- | --- | --- |
| `IsReady` | `bool` | Whether the API is bound to a usable `KND_DialogueManager`. |
| `Source` | `Node?` | The bound source Godot node, or `null` when the binding is unavailable. Use this only when direct GDScript access is needed. |

### Methods

| Method | Description |
| --- | --- |
| `bool BindDialogueManager(Node? source = null)` | Bind a specific dialogue manager, or traverse the scene tree when omitted. Returns `true` on success. |
| `void InitDialogue()` | Calls `init_dialogue()`. Usually called after `SetShot()` and before `StartDialogue()`. |
| `void InitDialogue(Callable callback)` | Initializes the dialogue and invokes `callback` when initialization finishes. |
| `void SetShot(Resource shot)` / `void SetShot(KndShot shot)` | Sets both the current shot and the source used by the next `InitDialogue()` call. Wrappers can be passed directly. |
| `void StartDialogue()` | Calls `start_dialogue()` and starts playback. |
| `void StopDialogue()` | Calls `stop_dialogue()` and stops playback. |
| `void StartAutoplay(bool value)` | Toggles autoplay. |
| `void SetCharaList(Resource charaList)` | Sets the character resource list. |
| `void SetBackgroundList(Resource backgroundList)` | Sets the background resource list. |
| `void SetBgmList(Resource bgmList)` | Sets the BGM resource list. |
| `Dictionary GetDialogueVariable(string key)` | Returns a dictionary containing `value`, or an empty dictionary when unavailable. |
| `bool SaveGame(int saveId)` | Saves progress to a save slot. Returns `false` if the API is not ready or saving fails. |
| `bool LoadGame(int saveId)` | Loads a save slot. |
| `bool DeleteSave(int saveId)` | Deletes a save slot. |
| `Dictionary GetSaveInfo(int saveId)` | Gets one save record. Returns an empty dictionary when the API is not ready. |
| `Array<Dictionary> GetAllSaveInfo()` | Gets all save records. Returns an empty array when the API is not ready. |
| `void SetSaveStrategy(Dictionary strategy)` | Sets the main plugin's save strategy. |
| `Dictionary GetSaveStrategy()` | Gets the save strategy, or an empty dictionary when unavailable. |
| `bool ReloadLocalizedScript(string locale)` | Reloads the current localized script while preserving the current node when possible. |
| `void EmitWaitSignal(string signalName)` | Continues a `waitsignal` instruction whose name matches `signalName`. |

Manual binding example:

```csharp
var manager = GetNode<Node>("UI/KonadoDialogueManager");
KonadoAPI.DialogueManagerApi?.BindDialogueManager(manager);
```

Typical playback order:

```csharp
var shot = interpreter.ProcessScriptsToData("res://dialogues/chapter_01.ks");
dialogueManager.SetShot(shot);
dialogueManager.InitDialogue();
dialogueManager.StartDialogue();
```

### Events

| Event | Description |
| --- | --- |
| `ShotStart` | Bound to `shot_start`. Fired when a shot starts. |
| `ShotEnd` | Bound to `shot_end`. Fired when a shot ends. |
| `DialogueLineStart(string nodeId)` | Bound to `dialogue_line_start(node_id)`. Current Konado releases use node IDs rather than legacy line numbers. |
| `DialogueLineEnd(string nodeId)` | Bound to `dialogue_line_end(node_id)`. |
| `CustomSignal(string content)` | Bound to `custom_signal(content)`. Fired by `.ks` lines such as `signal something`. |

```csharp
dialogueManager.CustomSignal += (string content) =>
{
    if (content == "affection_up")
    {
        GD.Print("Handle affection update");
    }
};
```

## ActingInterface

`ActingInterface` currently exposes the background transition enum used by the main plugin.

| Enum Value | Effect |
| --- | --- |
| `NoneEffect` | No transition |
| `EraseEffect` | Erase transition |
| `BlindsEffect` | Blinds transition |
| `WaveEffect` | Wave transition |
| `AlphaFadeEffect` | Alpha fade transition |
| `VortexSwapEffect` | Vortex swap transition |
| `WindmillEffect` | Windmill transition |
| `CyberGlitchEffect` | Cyber glitch transition |
| `BlinkEffect` | Blink transition |
| `Null` | Unspecified effect; maps to the underlying value `-1` |

## Wrapper Classes

Wrapper classes are lightweight C# wrappers around Konado GDScript resources.

General rules:

- Constructors for existing resources validate that the resource script matches.
- Empty constructors create the underlying GDScript resource.
- Use `SourceResource` only when a Godot API explicitly requires the underlying `Resource`; `SetShot(KndShot)` accepts its wrapper directly.
- Wrappers do not clone data; property reads and writes act on the underlying GDScript object.

## Dialogue

`Dialogue` wraps `KND_Dialogue`:

```text
res://addons/konado/scripts/dialogue/knd_dialogue.gd
```

### Constructors

| Member | Description |
| --- | --- |
| `Dialogue()` | Creates a new `KND_Dialogue` resource. |
| `Dialogue(GodotObject source)` | Wraps an existing `KND_Dialogue` resource. Throws if the source is invalid. |
| `SourceResource` | Returns the underlying `Resource`. |

### Properties

| Property | Type | Description |
| --- | --- | --- |
| `SourceFileLine` | `int` | Source `.ks` line number for debugging and errors. |
| `DialogueType` | `Dialogue.Type` | Node type used by the main plugin playback logic. |
| `NodeId` | `string` | Dialogue graph node ID. |
| `NextId` | `string` | Default next node ID. |
| `IfNextId` | `string` | Node ID used when a condition is true. |
| `ElseNextId` | `string` | Node ID used when a condition is false. |
| `VarName` | `string` | Variable name used by conditional nodes. |
| `ConditionOperator` | `int` | Condition operator: `0 ==`, `1 >`, `2 <`, `3 >=`, `4 <=`. |
| `TargetValue` | `int` | Target value for conditional comparison. |
| `CharacterId` | `string` | Speaker character ID. |
| `DialogueContent` | `string` | Dialogue text. |
| `VoiceId` | `string` | Voice ID for the dialogue line. |
| `CharacterName` | `string` | Character ID to display or create. |
| `CharacterState` | `string` | Character state or portrait state ID. |
| `ActorPosition` | `Vector2` | Actor display position. Current Konado releases use grid-style positioning. |
| `ExitActor` | `string` | Actor ID to hide or remove. |
| `ChangeStateActor` | `string` | Actor ID whose state should change. |
| `ChangeState` | `string` | Target state ID. |
| `TargetMoveChara` | `string` | Actor ID to move. |
| `TargetMovePos` | `Vector2` | Target movement position. |
| `MotionActor` | `string` | Actor ID whose stage motion should play. |
| `MotionName` | `string` | Stage motion name. |
| `Choices` | `Array<DialogueChoice>` | Choice list. Each choice points to a target node through `NextId`. |
| `JumpShotPath` | `string` | Resource path for jumping to another `KND_Shot`. |
| `JumpBranchTarget` | `string` | Branch label target in the current shot. |
| `BgmName` | `string` | BGM name to play. |
| `SoundeffectName` | `string` | Sound effect name to play. |
| `BackgroundName` | `string` | Background name to switch to. |
| `BackgroundToggleEffects` | `BackgroundTransitionEffectsType` | Background transition effect. |
| `TargetCam` | `string` | Target camera ID for camera movement nodes. |
| `CamTweenTime` | `float` | Camera movement or reset duration in seconds. |
| `CamTweenType` | `string` | Camera transition type written by the corresponding KonadoScript command. |
| `CamShakeTime` | `float` | Camera shake duration in seconds. |
| `TextContent` | `Array<string>` | NVL screen-text lines. |
| `TextboxDuration` | `float` | Dialogue-box show or hide duration in seconds; `0.0` changes it immediately. |
| `WaitSignalName` | `string` | External signal name awaited by a `WaitSignal` node. |
| `CustomSignalName` | `string` | Payload emitted through `CustomSignal`. |
| `AchievementId` | `string` | Achievement ID. |
| `AchievementValue` | `int` | Achievement progress value. |
| `AchievementFlagName` | `string` | Achievement flag name. |
| `AchievementFlagValue` | `bool` | Achievement flag value. |
| `VariableName` | `string` | Variable name to modify. |
| `VariableOperation` | `int` | Variable operation: `0 SET`, `1 ADD`, `2 SUB`, `3 MUL`, `4 DIV`. |
| `VariableOperand` | `string` | Operand stored as text and parsed by the main plugin at runtime. |
| `IsPersistent` | `bool` | Whether the variable is persistent. `%` variables are usually persistent; `$` variables are temporary. |

| Method | Description |
| --- | --- |
| `void AddChoice(string text, string targetId)` | Adds a choice that points to the target node ID. |
| `void ClearChoices()` | Removes every choice from the dialogue node. |

### Dialogue.Type

| Value | Description |
| --- | --- |
| `OrdinaryDialog` | Regular dialogue text. |
| `DisplayActor` | Display or create an actor. |
| `ActorChangeState` | Change actor state. |
| `MoveActor` | Move an actor. |
| `SwitchBackground` | Switch background. |
| `ExitActor` | Hide or remove an actor. |
| `PlayBgm` | Play BGM. |
| `StopBgm` | Stop BGM. |
| `PlaySoundEffect` | Play sound effect. |
| `ShowChoice` | Show choices. |
| `IfElseBranch` | Conditional branch. |
| `Branch` | Deprecated compatibility enum value. |
| `Jump` | Jump node. |
| `JumpBranch` | Jump to branch label. |
| `Signal` | Custom signal node. |
| `AchievementUnlock` | Unlock achievement. |
| `AchievementProgress` | Update achievement progress. |
| `AchievementFlag` | Set achievement flag. |
| `SetVariable` | Set or modify variable. |
| `TheEnd` | End node. |
| `ActorMotion` | Play an actor stage motion. |
| `MoveCam` | Move to a target camera and wait. |
| `ResetCam` | Reset the camera and wait. |
| `CamShake` | Shake the camera and wait. |
| `ScreenText` | Display NVL screen text. |
| `ShowTextbox` | Show the dialogue box. |
| `HideTextbox` | Hide the dialogue box. |
| `WaitSignal` | Wait for an external signal. |
| `AsyncMoveCam` | Move to a target camera asynchronously. |
| `AsyncResetCam` | Reset the camera asynchronously. |
| `AsyncCamShake` | Shake the camera asynchronously. |
| `AsyncCamStop` | Stop all asynchronous camera animations. |

## DialogueChoice

`DialogueChoice` wraps `KND_DialogueChoice`:

```text
res://addons/konado/scripts/dialogue/knd_dialogue_choice.gd
```

| Member | Description |
| --- | --- |
| `DialogueChoice()` | Creates a new choice resource. |
| `DialogueChoice(GodotObject source)` | Wraps an existing choice resource. |
| `SourceResource` | Underlying `Resource`. |

| Property | Type | Description |
| --- | --- | --- |
| `ChoiceText` | `string` | Text displayed to the player. |
| `NextId` | `string` | Target node ID selected by this choice. |

```csharp
var choice = new DialogueChoice
{
    ChoiceText = "Continue",
    NextId = "node_004"
};

Godot.Collections.Dictionary data = choice.SerializeToDictionary();
choice.DeserializeFromDictionary(data);
```

## KndData

`KndData` is the base wrapper for Konado data resources. Most code uses concrete wrappers such as `KndShot`, `Dialogue`, or `DialogueChoice`.

| Member | Description |
| --- | --- |
| `KndData()` | Creates a new `KND_Data` resource. |
| `KndData(GodotObject source)` | Wraps an existing resource. |
| `SourceResource` | Returns the underlying `Resource`. |

## KndShot

`KndShot` wraps `KND_Shot`:

```text
res://addons/konado/scripts/dialogue/knd_shot.gd
```

| Property | Type | Description |
| --- | --- | --- |
| `KsPath` | `string` | Source `.ks` path. Written by the interpreter. |
| `ShotId` | `string` | Shot ID. |
| `StartNodeId` | `string` | Start node ID. When empty, the first dialogue node is usually used. |
| `Dialogues` | `Array<Dialogue>` | All dialogue nodes in the shot graph. |
| `DepCharacters` | `Array<string>` | Actor IDs required by the shot. |

| Method | Description |
| --- | --- |
| `Dialogue? FindNode(string nodeId)` | Finds a dialogue node by `node_id`. Returns `null` when not found. |
| `Dialogue? GetStartNode()` | Gets the start node using `StartNodeId`, or the first dialogue node when empty; returns `null` when the shot has no nodes. |

## KonadoScriptsInterpreter

`KonadoScriptsInterpreter` wraps:

```text
res://addons/konado/ks/ks_interpreter.gd
```

| Member | Description |
| --- | --- |
| `KonadoScriptsInterpreter()` | Creates a new interpreter. |
| `KonadoScriptsInterpreter(GodotObject source)` | Wraps an existing interpreter object. |
| `KndShot? ProcessScriptsToData(string path)` | Parses a `.ks` file into a `KND_Shot`; returns `null` when loading or parsing fails. |
| `Dialogue? ParseSingleLine(string line, long lineNumber, string path)` | Parses one Konado script line; returns `null` for empty or invalid input. |

## Complete Examples

### Bind and Listen

```csharp
using Godot;
using Konado.Runtime.API;

public partial class DialogueEvents : Node
{
    public override void _Ready()
    {
        var api = KonadoAPI.DialogueManagerApi;
        if (api == null)
            return;

        if (!api.IsReady)
        {
            api.BindDialogueManager();
        }

        api.ShotStart += () => GD.Print("Shot started");
        api.ShotEnd += () => GD.Print("Shot ended");
        api.DialogueLineStart += (string nodeId) => GD.Print($"Node started: {nodeId}");
        api.DialogueLineEnd += (string nodeId) => GD.Print($"Node ended: {nodeId}");
        api.CustomSignal += (string content) => GD.Print($"Custom signal: {content}");
    }
}
```

### Parse and Play a Script

```csharp
using Godot;
using Konado.Runtime.API;
using Konado.Wrapper;

public partial class PlayKsFile : Node
{
    public override void _Ready()
    {
        var interpreter = new KonadoScriptsInterpreter();
        var shot = interpreter.ProcessScriptsToData("res://sample/demo/demo_01.ks");

        var api = KonadoAPI.DialogueManagerApi;
        if (shot == null || api == null)
            return;
        api.SetShot(shot);
        api.InitDialogue();
        api.StartDialogue();
    }
}
```

### Save Info

```csharp
using Godot;
using Konado.Runtime.API;

public partial class SaveInfoExample : Node
{
    public override void _Ready()
    {
        var api = KonadoAPI.DialogueManagerApi;
        if (api == null)
            return;

        if (api.SaveGame(1))
        {
            var info = api.GetSaveInfo(1);
            GD.Print(info);
        }

        var allSaves = api.GetAllSaveInfo();
        GD.Print($"Save count: {allSaves.Count}");
    }
}
```

## FAQ

### `IsApiReady` is true, but `DialogueManagerApi.IsReady` is false

`IsApiReady` only means the Konado.NET autoload initialized. `DialogueManagerApi.IsReady` means a `KND_DialogueManager` was found. Confirm that the current scene contains a dialogue manager, or bind one manually:

```csharp
KonadoAPI.DialogueManagerApi?.BindDialogueManager(GetNode<Node>("path/to/manager"));
```

### Events do not fire

Check that dialogue playback has started and that the bound `KND_DialogueManager` is the node you expect. In multi-manager scenes, automatic search binds the first matching node.

### `SetShot` does not start playback

`SetShot()` stores and selects the shot, but does not initialize or start playback. Use this order:

```csharp
api.SetShot(shot);
api.InitDialogue();
api.StartDialogue();
```
