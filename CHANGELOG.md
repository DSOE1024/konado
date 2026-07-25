## 2.6 - Ketchup

Konado 2.6 is officially released. Codenamed "Ketchup", this version focuses on live performance enhancement and script expression capability. It introduces a camera system (move, reset, shake), character animation system (slide-in/out), runtime internationalization, NVL full-screen text, dialogue box show/hide control, wait signal, and the Konado Showcase page, further completing the visual novel development pipeline.

### Added

#### Camera System

- Added `cam move`, `cam reset`, `cam shake` camera commands for script-level camera control
- Added `KonadoCameraManager` camera manager node for managing multiple camera targets and transitions
- Added `cam shake` camera shake with configurable duration
- Added tween animation type and duration parameters for smooth camera transitions

#### Character Animation System

- Refactored character animation system with slide-in/out animations
- Added `enter_exit_anim_config.gd` animation configuration resource for custom entry/exit duration and curves
- Centralized character animation logic in `animated_actor_layer.gd`

#### NVL Screen Text (Overlay Text)

- Added `screentext` script command for full-screen NVL text display
- Added `KND_ScreenText` scene and component with line-by-line fade-in animation
- Supports independent RichTextLabel per line with custom line spacing, left padding, and top padding
- Blinking triangle arrow indicator appears after each line completes, prompting click to play next line
- Provides `display_finished` callback signal for seamless dialogue flow integration

#### Dialogue Box Show/Hide Control

- Added `showtextbox` script command with configurable fade-in duration for dialogue box display
- Added `hidetextbox` script command with configurable fade-out duration for dialogue box hiding
- Set duration to `0.0` to disable animation (instant show/hide)
- Added `show_dialogue_box_with_duration()` and `hide_dialogue_box_with_duration()` methods in `KND_DialogueBox`

#### Wait Signal

- Added `waitsignal` script command to pause dialogue flow and wait for an external signal
- Added `emit_wait_signal(signal_name: String)` method for external code to trigger signal continuation
- Suitable for cutscenes, minigames, custom interactions, and more

#### Runtime Internationalization

- Added runtime script internationalization support (i18n runtime), enabling dynamic language switching during gameplay
- Added `KND_I18n` internationalization service node with registration and translation interfaces
- Dialogue manager supports loading localized dialogue resources

#### Voice & Audio

- Added voice progress display in dialogue box showing voice playback progress
- Added `voice_progress_display.tscn` progress display template scene
- Supports toggling progress display via dialogue box node settings

#### Documentation & Showcase

- Added Konado Showcase page generator that automatically fetches and displays games made with Konado
- Added multi-language (Chinese/English/Japanese/Korean) Konado Showcase pages
- Added multi-language documentation version management, default documentation version updated to 2.6
- Added 2.6 camera, text, and other new feature tutorial documentation
- Added Korean (ko) and Japanese (ja) full documentation translations

#### Other

- Replaced project license with multi-license, updated documentation
- Changed `middle` theme to `default` inherited scene for correct inheritance

### Syntax Changes

- **New `screentext` command**: NVL full-screen text display
  ```ks
  screentext {
      "This is the first line of full-screen text"
      "This is the second line"
  }
  ```

- **New `showtextbox` / `hidetextbox` commands**: Dialogue box show/hide control
  ```ks
  showtextbox 1.0    # Show dialogue box with 1s fade-in animation
  hidetextbox 0.5    # Hide dialogue box with 0.5s fade-out animation
  showtextbox 0.0    # Disable animation, show instantly
  ```

- **New `waitsignal` command**: Wait for external signal
  ```ks
  waitsignal "over"        # Wait for signal named "over"
  waitsignal minigame_done # Identifier form
  ```

- **Extended `cam` command**: Camera shake
  ```ks
  cam shake          # Shake with default duration
  cam shake 2.0      # Shake for 2 seconds
  cam move target linear 1.0  # Linear transition over 1 second
  cam reset fade 2.0          # Fade transition over 2 seconds
  ```

### Fixed

- Fixed main menu quit button node path issue in non-editor environments
- Fixed `middle` theme inheritance scene configuration as default theme

### Improvements

- Refactored character animation system, centralized animation logic for easier extension
- Voice progress display supports toggle configuration for flexible project adaptation
- Konado Showcase auto-generation reduces community showcase maintenance cost

### Compatibility Notes

- Godot 4.7 or later is recommended.
- Direct upgrade from 2.4 to 2.6 is not supported; project migration is recommended.
- Runtime internationalization requires additional `KND_I18n` node configuration; it is an optional feature.

## 2.5 - Diguoji

Konado 2.5 is officially released. Codenamed "Diguoji", this version focuses on game flow completeness and development experience enhancement. It introduces quick save/load functionality, a game startup main menu, character scene-based architecture, background transition effects, and launches a VSCode syntax highlighting extension along with editor skill packs, further improving the out-of-the-box development experience.

### Added

#### Save System

- Added quick save/quick load functionality with QuickSave and QuickLoad buttons in dialogue templates
- Added quick save indicator in save UI component, slot 0 marked as quick save slot
- Implemented `_on_quick_save_pressed()` and `_on_quick_load_pressed()` methods in dialogue manager
- Added confirmation dialog before quick load to prevent accidental loss of unsaved progress
- Added lightweight toast notifications to display save/load operation results

#### Game Interface

- Added game startup main menu screen (`main.tscn`) with Start Game, Load Save, Settings, and Quit buttons
- Main menu uses theme background image with unified button styles
- Quit button automatically hidden on Web platform for browser compatibility

#### Character System

- Added character scenes as an alternative portrait form, supporting any node type for character scenes
- Added `motion` command for executing stage actions
- Added custom animation support in `ActorMotionLayer` with sample animations included
- Centralized motion logic in `actor_motion_layer`, eliminating hardcoded animations

#### Background System

- Backgrounds converted to scenes, supporting shaders in scene-based backgrounds
- Added "blink" background transition visual effect
- Added background transition demo scene (`demo_06_bg_effects.ks`) and demo images
- Added warnings when background transition effects are invalid

#### Development Tools

- Added VSCode Konado script syntax highlighting extension for `.ks` file coloring
- Added VSCode workspace extension recommendations configuration (`.vscode/extensions.json`)
- Optimized KS syntax plugin internal configuration structure
- Added Konado DSL editor enhancement skill pack (`skills/konado-script`)
- Added `.marketplace.json` configuration file for registering konado-script-skill plugin and its skill paths

#### Documentation

- Added scene-based documentation
- Added versioned documentation structure
- Updated README documentation links with inline contributor information

#### Syntax Changes

- **New `actor motion` command**: Execute character stage actions
  ```ks
  # Execute built-in motions
  actor motion Kona shake
  actor motion Kona jump
  actor motion Kona bounce
  
  # Motions defined in AnimationPlayer within actor_motion_layer.tscn
  ```

- **Simplified `actor show` command**: Removed redundant `y` coordinate, `scale`, and `mirror` parameters
  ```ks
  # 2.5 syntax (simplified)
  actor show Kona 正常 at 3
  
  # Old syntax (removed)
  # actor show Kona 正常 at 2 5 scale 0.3 mirror
  ```

- **`actor change` command**: Change character state (expression)
  ```ks
  actor change Kona 害羞
  actor change Kona 惊讶
  ```

- **Extended background transition effects**: Added "blink" visual effect
  ```ks
  background bg1 fade    # Fade in/out
  background bg1 windmill # Windmill effect
  background bg1 blink    # Blink effect (new)
  ```

- **Repeated `actor show` compatibility**: Allows reusing `show` command on already displayed characters, reusing existing nodes with new state
  ```ks
  actor show Kona 正常 at 3
  actor show Kona 害羞 at 2  # Reuse node, change state and position
  ```

### Fixed

- Fixed achievement close exception bug
- Fixed conditional branch continue cleanup issue, correcting if-branch not jumping problem
- Fixed version switcher selection stability issue
- Fixed actor show reuse issue, allowing repeated actor show statements that reuse existing nodes with new state
- Fixed waiting for actor shown signal issue
- Fixed batch actor stage position updates issue
- Fixed variable system demo scene not working issue

### Improvements

- Improved documentation details, added quick save/load documentation
- Refactored plugin README with new compatible editor descriptions and optimized installation steps
- Optimized KS syntax plugin README command descriptions
- Updated documentation site version configuration with 2.5 version branch
- Removed redundant y-coordinate parameter, simplified character positioning
- Optimized Demo scene: updated scripts, assets, and .gitignore
- Added Tripo acknowledgement logo
- Updated community projects list with "雨夜重逢" game and Akonado derived project

### Removed

- Removed image-based expression switching compatibility, now using scenes only
- Removed old image format compatibility, switching to scene-based state transitions

### Compatibility Notes

- Godot 4.7 or later is recommended.
- 2.5 introduces a new main menu scene, ensure correct startup scene configuration in projects.
- Backgrounds and character portraits are now scene-based, old image formats are no longer compatible and need migration to scene configuration.
- Removed redundant y-coordinate parameter, character positioning uses horizontal grid positions only.

## 2.4.5 LTS - Macaron

Konado 2.4.5 is officially released. This version is a Long-Term Support (LTS) maintenance update for the 2.4 series, focusing on KS script compiler pipeline refactoring and editor experience enhancement, implementing a complete compilation chain and adding useful editor tool features.

### Added

#### KS Compiler

- Refactored KS compiler with complete compilation pipeline including lexer, parser, analyzer, and emitter
- Added editor tooltip plugin for KS script files, displaying script line count, dialogue count, and dependency characters

### Removed

- Removed deprecated dialogue scene file `konado_dialogue.tscn`, which was a legacy file from the 2.3 dialogue system and is no longer used

### Compatibility Notes

- Removed deprecated dialogue scenes. Please use the new `knd_dialogue_box_middle.tscn` and `knd_dialogue_box_left.tscn` dialogue scene templates. This may cause issues in projects relying on the old dialogue scene. It is recommended to back up before upgrading or manually add missing dialogue scenes after migration.
- Godot 4.6.2 or later is recommended.

## 2.4.4 LTS - Macaron

Konado 2.4.4 is officially released. This version is a Long-Term Support (LTS) maintenance update for the 2.4 series, focusing on option parsing fixes in the KS interpreter, resolving branch option display and jump issues, further improving script parsing stability and accuracy.

### Fixed

#### KS Interpreter

- Fixed legacy option syntax parsing from 2.3, restricting one option per line. Removed the `choice "text1" -> tag1 "text2" -> tag2` format, enforcing the standard `choice "text" -> tag` single-option-per-line format.
- Fixed branch option jump target parsing, added post-processing step to convert `next_id` from tag names to node IDs within branches, resolving branch option jump failures.
- Fixed consecutive `choice` line merging logic within branches, allowing multiple `choice` lines in branches to correctly merge into a single option group, resolving single-option display in branches.

### Added

#### Samples and Assets

- Added `demo_choice_test.ks` option system test script demonstrating main-line multi-option, branch multi-option, and nested option jump scenarios for verifying option parsing functionality.

### Compatibility Notes

- 2.4.4 enforces one option per line. Old scripts with multiple options on a single line need to be split into multiple lines. This may cause breaking changes.
- Godot 4.6.2 or later is recommended.

## 2.4.3 LTS - Macaron

Konado 2.4.3 is officially released. This version is a Long-Term Support (LTS) maintenance update for the 2.4 series. It focuses on editor interaction fixes, dialogue playback flow improvements, and sample asset completion, further improving out-of-the-box stability and usability.

### Fixes

#### Performance System

- Removed the ShaderMaterial from the scene and now dynamically creates and assigns it to the background node in the ready function. This unifies material initialization and prevents issues where the material is null and cannot be configured when the scene loads.


## 2.4.2 LTS - Macaron

Konado 2.4.2 is officially released. This version is a Long-Term Support (LTS) maintenance update for the 2.4 series. It focuses on editor interaction fixes, dialogue playback flow improvements, and sample asset completion, further improving out-of-the-box stability and usability.

### Fixes

#### Editor

- Fixed the KS editor display logic so it no longer leaves an abnormal blank area occupying the main screen.
- Fixed visibility control in the editor `_edit` method by using `ks_dock.make_visible()` instead of the incorrect `ks_editor.show()` approach.

#### Dialogue System

- Fixed dialogue manager autoplay logic by adjusting the execution flow after typewriter completion and moving `_process_next()` to the correct branch. This resolves incorrect flow jumps in scenes that do not wait for voice playback.
- Improved voice playback logic by refactoring `_play_voice` to return the audio duration, optimizing the timing coordination between autoplay and waiting for voice playback after typewriter completion.
- Fixed autoplay settings loading timing so settings are loaded during dialogue manager initialization instead of being read on demand at runtime.

### Improvements

#### Dialogue Manager

- Added exception handling for empty current dialogue to avoid blank dialogue causing the flow to stall.
- Optimized debug log output with clearer runtime status messages to make troubleshooting easier.

#### Samples and Assets

- Added the missing Demo scene voice list resource `voice_list.tres`, including sample voice entries.
- Renamed `new_resource.tres` to `character_list.tres` to standardize resource naming.
- Completed resource references for the character list, background list, BGM list, and voice list in the Demo scene.

### Compatibility Notes

- 2.4.2 continues the bottom Dock layout introduced in 2.4.1, but adjusts the visibility control logic.
- Godot 4.6.2 or later is recommended.


## 2.4.1 LTS - Macaron

Konado 2.4.1 is officially released. This version is a Long-Term Support (LTS) maintenance update for the 2.4 series. Compared with version 2.4.0, this update focuses on editor interface experience optimization and core functionality improvements, while comprehensively fixing various issues reported by the community, further enhancing stability and usability.

### Changes

- Added the KND_SettingsBridge settings bridge node for dialogue settings access.
- Added settings listener and settings button functionality to the dialogue manager.
- Integrated volume synchronization logic in the audio interface.

### Fixes

#### Editor

- Fixed theme and button styles, reset the editor position to the bottom, and allowed it to pop up freely for convenient simultaneous preview of game scenes and dialogue editing.
- Fixed the editor panel minimum height to 300px, ensuring the editor panel is visible during initialization.
- Fixed compatibility issues with Godot 4.6 API changes.

### Improvements

#### Themes, Samples, and Assets

- Added `NotoSansSC-VF.otf` and `ResourceHanRoundedCN-Medium.ttf` font files and corresponding SIL OFL license documents.
- Fixed font file paths in `left_theme.tres` and `middle_theme.tres` theme resources.

#### Documentation

- Added `.gdignore` configuration in the `docs` directory to prevent Godot from abnormally loading unnecessary documentation files.
- Updated documentation and syntax highlighter instructions.
- Optimized multilingual Konado project descriptions.

### Compatibility Notes

- 2.4.1 adjusts the editor panel position to the bottom. It is recommended to disable the old plugin version first, exit the project for a complete update, and then re-enable it to avoid cache issues.
- Due to Godot 4.6 API changes, older versions of Godot may not work properly and need to be upgraded to Godot 4.6 or later.
- Since new font files have been imported, if they do not take effect, it is recommended to delete the font resource cache files under the `.godot` directory.

## 2.4.0 LTS - Macaron

Konado 2.4.0 is a long-term support release. Compared with 2.3, this version focuses on the core dialogue flow, variable and save/load capabilities, reusable plugin ecosystem, template assets, and documentation system, bringing a major improvement in both functionality and stability.

### Highlights

- Added a complete variable system with persistent variables, temporary variables, variable interpolation, and conditional checks.
- Added a complete save/load system that can store dialogue state, variables, audio, actors, and background state.
- Added a fade-in typewriter text component with BBCode rich text support and GPU-accelerated per-character fade-in rendering.
- Added three standalone plugins: Konado Achievement, Konado Settings, and Konado WebTool.
- Reworked the documentation site into Chinese, English, and Traditional Chinese multilingual structures, with 2.4-related tutorials completed.
- Added the Graph Editor (Beta), which uses visual graph nodes to organize dialogue flow, branches, and jumps.

### Changes

#### Dialogue System and Script Capabilities

- Added the `addons/konado/graph_editor` graph editor module:
  - `knd_graph_edit.gd`: visual graph editor.
  - `knd_graph_node_factory.gd`: dialogue node factory.
  - `knd_graph_converter.gd`: converter between KS scripts and graph structures.
- Added `%variable_name` persistent variables and `$variable_name` temporary variables.
- Added variable operation statements: `set`, `add`, `sub`, `mul`, and `div`.
- Added dialogue text variable interpolation, allowing variables such as `%love` and `$score` to be displayed directly in dialogue lines.
- Added `if / else / endif` conditional branches with support for `==`, `!=`, `>`, `<`, `>=`, and `<=`.
- Improved choice and branch jumps, optimizing parsing and execution for `choice`, `branch`, and `jump_branch`.
- Added the custom signal instruction `signal <name>`, allowing dialogue scripts to trigger external game logic.
- Added achievement script instruction examples, including direct unlocks, counter progress, and flag conditions.
- Added background clearing.
- Added dialogue visibility checks.

#### Save System

- Added `KND_SaveSystem`, providing APIs such as `save_game()`, `load_game()`, `delete_save()`, and `get_save_info()`.
- Added `KND_SaveData`, which serializes dialogue, variables, audio, actors, background state, and save metadata in one structure.
- Added automatic save toggle and auto-save interval settings.
- Added save strategy configuration, allowing projects to choose whether to save dialogue state, variables, audio, actors, and background state.
- Updated the save UI component with support for save slots, saving, loading, deletion, and preview information.

#### Text Rendering and Audio

- Added the `KND_TypewriterText` fade-in typewriter text component.
- Added `typewriter_fade.gdshader`, using a CanvasItem shader for per-character fade-in rendering.
- Added BBCode parsing support for bold, italic, underline, strikethrough, color, and font size.
- Added multiline text fade-in support.
- Added documentation for typewriter sound effects.

#### Plugins

- Added the **Achievement System** plugin (`addons/konado_achievement`):
  - JSON-based achievement data configuration.
  - Support for direct unlocks, counters, flag conditions, and hidden achievements.
  - Achievement popup, achievement panel, progress statistics, and reset APIs.
  - Support for custom save/load backends and external platform SDK sync callbacks.
- Added the **Settings System** plugin (`addons/konado_settings`):
  - Dynamically generates settings panels from JSON configuration.
  - Built-in categories for audio, text playback, display, and more.
  - Support for sliders, toggles, option controls, and other UI items.
  - Support for filtering settings by platform and build type.
- Added the **WebTool** plugin (`addons/konado_webtool`):
  - Allows common browser shortcuts in Web exports.
  - Supports configurable F12, F5, F11, Ctrl/Cmd shortcut combinations, and more.

#### Templates, Samples, and Assets

- Added left-aligned and centered dialogue box and dialogue scene templates.
- Added `left_theme.tres` and `middle_theme.tres` theme resources.
- Added the complete variable system sample `sample/demo/demo_03_variable.ks`.
- Added the Konado 2.4 startup banner.
- Added Kona emoji GIF assets.
- Added updated character portrait assets and supporting materials for portrait import and cropping guides.
- Added Chinese font resources: `NotoSansSC-VF.otf` and `ResourceHanRoundedCN-Medium.ttf`.

### Documentation

- Reworked the VitePress documentation configuration and added the sidebar generation script `genSidebar.ts`.
- Added Chinese, English, and Traditional Chinese multilingual documentation structures.
- Added documentation for the achievement system, settings system, WebTool, and Konado .NET API.
- Added tutorials for the variable system, conditional branches, custom signals, typewriter effect, and typewriter sound effects.
- Added core tutorials for the save system, background transitions, script highlighting, logging, shots, and dialogue.
- Added community contribution, documentation contribution, feedback, resources, and join-us pages.
- Updated the version roadmap: 2.4 is codenamed Macaron and marked as LTS.

### Improvements

- Updated the main Konado plugin version to `2.4.0`.
- Refactored `KND_DialogueManager` and the KS interpreter to support variables, conditions, branches, and save state management.
- Improved integration between actor management and the save system.
- Improved actor layout logic so character images are positioned from their bottom anchor on grid positions.
- Improved highlighting logic and added BBCode syntax definitions.
- Improved move instructions and sample resources.
- Improved the Konado Settings panel UI and cleaned up redundant configuration.
- Updated the plugin author list.
- Updated README multilingual links and project description.
- Updated LICENSE copyright information.

### Fixes

- Fixed texture expand and stretch mode configuration in the character template.
- Fixed some documentation paths, image import paths, and sidebar generation configuration.

### Removed

- Removed old unused shots editor plugin files from the Inspector integration.
- Removed old actor scaling, mirroring, and vertical positioning parameters. Actor display and movement now use horizontal grid positions.
- Removed outdated documentation directories such as `docs/about`, old `docs/script`, and old `docs/tutorial`.
- Removed Spanish and French README links and their corresponding README files.
- Removed old `assets/kona/1.0` portrait assets.

### Compatibility Notes

- 2.4.0 changes the actor positioning model. Old scripts that rely on `actor show ... at <x> <y> scale <value> [mirror]` need to migrate to the new grid-based positioning approach.
- The variable system is split into persistent variables (`%`) and temporary variables (`$`). Persistent variables are included in save data, while temporary variables are only used in the current flow.
- WebTool is only enabled on the Web platform and does not inject browser shortcut handling logic on other platforms.
