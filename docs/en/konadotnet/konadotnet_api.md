---
title: API Reference
order: 2
---

# Konado .NET API

> This feature is still experimental and may have some issues.

## Introduction

Konado.NET is a C# API extension for the Konado dialogue system. Using Konado.NET, developers can easily create, manage and execute dialogue content in C# projects.

## Usage

### Enabling the Plugin

First enable the Konado plugin, then enable the Konado .NET API plugin.

Your scene must contain a DialogueManager node for the Konado .NET API to work correctly.

When first enabling Konado.NET, you may encounter the following error:

```
Unable to load addon script from path: 'res://addons/konadotnet/Konadotnet.cs': The script may have code errors.
Disabling addon at 'res://addons/konadotnet/plugin.cfg' to prevent further errors.
```

```
Unable to load addon script from path: 'res://addons/konadotnet/Konadotnet.cs'.
```

This is normal. Recompile Konado.NET in Godot, then reopen the project to resolve the issue.

If you are unable to enable the plugin and there are no errors in MSBuild, try closing the project, deleting the `.godot/` folder in the project root, then regenerating the project.

## API Reference

### KonadoAPI

Core API class providing access to the Konado system.

#### Properties

- `bool IsApiReady`: Indicates whether the API is ready
- `KonadoAPI API`: Static instance providing access to the Konado API
- `DialogueManagerAPI DialogueManagerApi`: Dialogue manager API instance

### DialogueManagerAPI

Dialogue manager API for controlling dialogue execution.

#### Methods

- `InitDialogue()`: Initialise dialogue
- `StartDialogue()`: Start dialogue
- `StopDialogue()`: Stop dialogue

#### Events

- `ShotStart`: Emitted when a dialogue scene starts
- `ShotEnd`: Emitted when a dialogue scene ends
- `DialogueLineStart(int line)`: Emitted when a dialogue line starts
- `DialogueLineEnd(int line)`: Emitted when a dialogue line ends

### ActingInterface

Performance interface defining background transition effect types.

#### Enum

- `BackgroundTransitionEffectsType`: Background transition effect types
  - `NoneEffect`: No effect
  - `EraseEffect`: Erase effect
  - `BlindsEffect`: Blinds effect
  - `WaveEffect`: Wave effect
  - `AlphaFadeEffect`: Alpha fade effect
  - `VortexSwapEffect`: Vortex swap effect
  - `WindmillEffect`: Windmill effect
  - `CyberGlitchEffect`: Cyber glitch effect

### Wrapper Classes

Wrapper classes provide C# wrappers for GDScript objects, allowing developers to manipulate various Konado data structures in C#. Note that these classes are not yet fully implemented and only provide some properties and methods, pending further development.

#### Dialogue

Dialogue object wrapper representing a single dialogue element.

##### Properties

- `Type DialogueType`: Dialogue type (enum)
- `string BranchId`: Branch ID
- `Array<Dialogue> BranchDialogue`: Branch dialogue
- `bool IsBranchLoaded`: Whether the branch is loaded
- `string CharacterId`: Character ID
- `string DialogueContent`: Dialogue content
- `DialogueActor ShowActor`: Actor to show
- `string ExitActor`: Actor to exit
- `string ChangeStateActor`: Actor changing state
- `string TargetMoveChara`: Target character to move
- `Vector2 TargetMovePos`: Target move position
- `Array<DialogueChoice> Choices`: Dialogue choices
- `string BgmName`: Background music name
- `string VoiceId`: Voice ID
- `string SoundeffectName`: Sound effect name
- `string BackgroundImageName`: Background image name
- `BackgroundTransitionEffectsType BackgroundToggleEffects`: Background transition effect
- `string JumpShotId`: Jump shot ID
- `string LabelNotes`: Label notes
- `Dictionary ActorSnapshots`: Actor snapshots

##### Dialogue Type Enum

- `Start`: Start
- `OrdinaryDialog`: Ordinary dialogue
- `DisplayActor`: Display actor
- `ActorChangeState`: Actor state change
- `MoveActor`: Move actor
- `SwitchBackground`: Switch background
- `ExitActor`: Exit actor
- `PlayBgm`: Play background music
- `StopBgm`: Stop background music
- `PlaySoundEffect`: Play sound effect
- `ShowChoice`: Show choice
- `Branch`: Branch
- `JumpTag`: Jump tag
- `JumpShot`: Jump shot
- `TheEnd`: The end
- `Label`: Label

#### DialogueActor

Dialogue actor wrapper representing an actor object in dialogue.

##### Properties

- `string CharacterName`: Character name
- `string CharacterState`: Character state
- `Vector2 ActorPosition`: Actor position
- `Vector2 ActorScale`: Actor scale
- `bool ActorMirror`: Actor mirror

#### DialogueChoice

Dialogue choice wrapper representing a choice object in dialogue.

##### Properties

- `string ChoiceText`: Choice text
- `string JumpTag`: Jump tag

#### KndData

Konado KND_Data base data class wrapper.

##### Properties

- `string Type`: Data type
- `bool Love`: Whether it is a favourite
- `string Tip`: Tip information

#### KndShot

Konado KND_Shot shot wrapper, inheriting from KndData.

##### Properties

- `string Name`: Scene name
- `string ShotId`: Shot ID
- `string SourceStory`: Source story
- `Array<Dictionary> DialoguesSourceData`: Dialogue source data
- `Dictionary Branches`: Branches
- `Dictionary<string, Dictionary> SourceBranches`: Source branches
- `Dictionary<string, int> ActorCharacterMap`: Actor character map

#### KonadoScriptsInterpreter

KonadoScriptsInterpreter script interpreter wrapper for parsing Konado script files.

##### Methods

- `KndShot ProcessScriptsToData(string path)`: Process a script file into data
- `Dialogue ParseSingleLine(string line, long lineNumber, string path)`: Parse a single script line

## Example Code

### Dialogue Management

```csharp
using Konado.Runtime.API;

// Get the Konado API instance
var konadoAPI = KonadoAPI.API;
var dialogueManager = KonadoAPI.DialogueManagerApi;

// Check if the API is ready
if (dialogueManager.IsReady)
{
    // Initialise dialogue
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

### Parsing Konado Scripts

```csharp
using Konado.Wrapper;

// Create a script interpreter
var flags = new Godot.Collections.Dictionary<string, Variant>();
var interpreter = new KonadoScriptsInterpreter(flags);

// Parse an entire script file
var shot = interpreter.ProcessScriptsToData("res://dialogues/example.ks");
```
