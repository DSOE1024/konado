---
title: API Usage
order: 2
---

# Konado .NET API

> This feature is still experimental and may have some issues.

## Introduction

Konado.NET is a C# API extension for the Konado dialogue system. With Konado.NET, developers can easily create, manage, and execute dialogue content in C# projects.

## Usage

### Non-.NET Projects

If you use the Konado .NET API in a non-.NET project, you may see the following error. This is normal:
```
 ERROR: core/io/resource_loader.cpp:568 - Condition "local_path.is_empty()" is true. Returning: Ref<ResourceLoader::LoadToken>()
  ERROR: Failed to create an autoload, can't load from UID or path: uid://ptylvcqylq7j.
  ERROR: editor/settings/editor_autoload_settings.cpp:571 - Condition "!info->node" is true. Continuing.

```

This issue does not affect the basic Konado features, but the Konado .NET API cannot be used.

### Enable the Plugin

Enable the Konado plugin first, then enable the Konado .NET API plugin.

The scene should contain a DialogueManager node; otherwise the Konado .NET API will not work correctly.

When enabling Konado.NET for the first time, you may encounter the following error:

```
Unable to load addon script from path “res://addons/konadotnet/Konadotnet.cs”: the script may contain code errors.
Disabling addon at “res://addons/konadotnet/plugin.cfg” to prevent further errors.
```

```
Unable to load addon script from path: 'res://addons/konadotnet/Konadotnet.cs'.
```

This is normal. Rebuild Konado.NET in Godot, then reopen the project to resolve it.

If the plugin cannot be enabled and MSBuild reports no errors, try closing the project, deleting the `.godot/` folder in the project root, and rebuilding the project.

## API Reference

### KonadoAPI

Core API class that provides access to the Konado system.

#### Properties

- `bool IsApiReady`: Indicates whether the API is ready
- `KonadoAPI API`: Static instance that provides access to the Konado API
- `DialogueManagerAPI DialogueManagerApi`: Dialogue manager API instance

### DialogueManagerAPI

Dialogue manager API used to control dialogue execution.

#### Methods

- `InitDialogue()`: Initialize dialogue
- `StartDialogue()`: Start dialogue
- `StopDialogue()`: Stop dialogue

#### Events

- `ShotStart`: Triggered when a dialogue scene starts
- `ShotEnd`: Triggered when a dialogue scene ends
- `DialogueLineStart(int line)`: Triggered when a dialogue line starts
- `DialogueLineEnd(int line)`: Triggered when a dialogue line ends

### ActingInterface

Acting interface that defines background transition effect types.

#### Enum

- `BackgroundTransitionEffectsType`: Background transition effect type
  - `NoneEffect`: No effect
  - `EraseEffect`: Erase effect
  - `BlindsEffect`: Blinds effect
  - `WaveEffect`: Wave effect
  - `AlphaFadeEffect`: Alpha fade effect
  - `VortexSwapEffect`: Vortex swap effect
  - `WindmillEffect`: Windmill effect
  - `CyberGlitchEffect`: Cyber glitch effect

### Wrapper Classes

Wrapper classes provide C# wrappers around GDScript objects, allowing developers to operate Konado data structures from C#. These classes are not fully implemented yet and only provide some properties and methods. Further improvements are planned.

#### Dialogue

Dialogue object wrapper representing a single dialogue element.

##### Properties

- `Type DialogueType`: Dialogue type (enum)
- `string BranchId`: Branch ID
- `Array<Dialogue> BranchDialogue`: Branch dialogue
- `bool IsBranchLoaded`: Whether the branch has been loaded
- `string CharacterId`: Character ID
- `string DialogueContent`: Dialogue content
- `DialogueActor ShowActor`: Actor to display
- `string ExitActor`: Actor to exit
- `string ChangeStateActor`: Actor whose state changes
- `string TargetMoveChara`: Target actor to move
- `Vector2 TargetMovePos`: Target movement position
- `Array<DialogueChoice> Choices`: Dialogue choices
- `string BgmName`: Background music name
- `string VoiceId`: Voice ID
- `string SoundeffectName`: Sound effect name
- `string BackgroundImageName`: Background image name
- `BackgroundTransitionEffectsType BackgroundToggleEffects`: Background switching effect
- `string JumpShotId`: Target scene ID
- `string LabelNotes`: Label notes
- `Dictionary ActorSnapshots`: Actor snapshots

##### Dialogue Type Enum

- `Start`: Start
- `OrdinaryDialog`: Ordinary dialogue
- `DisplayActor`: Display actor
- `ActorChangeState`: Actor state change
- `MoveActor`: Move actor
- `SwitchBackground`: Switch background
- `ExitActor`: Actor exits
- `PlayBgm`: Play background music
- `StopBgm`: Stop background music
- `PlaySoundEffect`: Play sound effect
- `ShowChoice`: Show choices
- `Branch`: Branch
- `JumpTag`: Jump to tag
- `JumpShot`: Jump to scene
- `TheEnd`: End
- `Label`: Label

#### DialogueActor

Dialogue actor wrapper representing an actor object in dialogue.

##### Properties

- `string CharacterName`: Character name
- `string CharacterState`: Character state
- `Vector2 ActorPosition`: Actor position
- `Vector2 ActorScale`: Actor scale
- `bool ActorMirror`: Actor mirroring

#### DialogueChoice

Dialogue choice wrapper representing a choice object in dialogue.

##### Properties

- `string ChoiceText`: Choice text
- `string JumpTag`: Jump tag

#### KndData

Wrapper for the Konado KND_Data data base class.

##### Properties

- `string Type`: Data type
- `bool Love`: Whether it is favorite content
- `string Tip`: Tip information

#### KndShot

Wrapper for Konado KND_Shot scenes, inherited from KndData.

##### Properties

- `string Name`: Scene name
- `string ShotId`: Scene ID
- `string SourceStory`: Source story
- `Array<Dictionary> DialoguesSourceData`: Dialogue source data
- `Dictionary Branches`: Branches
- `Dictionary<string, Dictionary> SourceBranches`: Source branches
- `Dictionary<string, int> ActorCharacterMap`: Actor mapping

#### KonadoScriptsInterpreter

Wrapper for the KonadoScriptsInterpreter script interpreter, used to parse Konado script files.

##### Methods

- `KndShot ProcessScriptsToData(string path)`: Process a script file into data
- `Dialogue ParseSingleLine(string line, long lineNumber, string path)`: Parse a single script line

## Example Code

### Dialogue Management

```csharp
using Konado.Runtime.API;

// Get Konado API instance
var konadoAPI = KonadoAPI.API;
var dialogueManager = KonadoAPI.DialogueManagerApi;

// Check whether the API is ready
if (dialogueManager.IsReady)
{
    // Initialize dialogue
    dialogueManager.InitDialogue();

    // Start dialogue
    dialogueManager.StartDialogue();

    // Stop dialogue
    dialogueManager.StopDialogue();
}
```

### Dialogue Event Listening

```csharp
// Listen for dialogue start event
dialogueManager.ShotStart += () => {
    GD.Print("Dialogue scene started");
};

// Listen for dialogue end event
dialogueManager.ShotEnd += () => {
    GD.Print("Dialogue scene ended");
};

// Listen for dialogue line start event
dialogueManager.DialogueLineStart += (int line) => {
    GD.Print($"Dialogue line {line} started");
};

// Listen for dialogue line end event
dialogueManager.DialogueLineEnd += (int line) => {
    GD.Print($"Dialogue line {line} ended");
};
```

### Parse Konado Script

```csharp
using Konado.Wrapper;

// Create script interpreter
var flags = new Godot.Collections.Dictionary<string, Variant>();
var interpreter = new KonadoScriptsInterpreter(flags);

// Parse an entire script file
var shot = interpreter.ProcessScriptsToData("res://dialogues/example.ks");
```
