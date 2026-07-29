---
title: KonadoScript Editor
order: 5
---

# Built-in Godot KonadoScript Editor

After enabling the Konado plugin, double-clicking a `.ks` file in the FileSystem dock opens it in Godot's Script workspace, just like a `.gd` file. KonadoScript uses Godot's native code editor and document tabs instead of a bottom dock.

## Editing Features

- Edit `.ks`, `.gd`, and other scripts together in Godot's script document tabs
- While editing `.ks`, replace the upper-left script list with the component and command tree; on first open, the component and branch regions use a 2:1 height ratio, the sliding toggle in the header expands or collapses every group while retaining the top-level categories, selecting an entry inserts its statement, and the lower member outline remains available for branch navigation
- Open documentation for the matching Konado major/minor version and editor locale from Online Docs; Godot's API help search is hidden while editing `.ks` because it does not support KonadoScript, and the original interface returns when another script language is active
- Let Godot manage undo and redo, unsaved state, external changes, and close confirmation
- Use the Script Editor's find and replace, go to line, zoom, bookmarks, and shortcuts
- Create a KonadoScript with valid starter content from the FileSystem Create menu
- Browse `branch` declarations in the member outline; branches, variables, and signals support Go to Definition, Find References, and safe rename
- Ctrl-click (Command-click on macOS) a background, actor, state, motion, BGM, sound effect, voice, camera setup, or `jump` path to open its actual scene, resource, or target KonadoScript; choose from a target list when a name is ambiguous
- Hover commands and resource identifiers to inspect signatures, purpose, resolved paths, or unresolved status; an underline appears only when a real navigation target exists
- Auto-indent conditional and full-screen text blocks using Godot's indentation settings
- Save directly to the original `.ks` file and refresh the runtime `KND_Shot` compiled by the resource loader

## Highlighting and Completion

`KND_KsHighlighter` is built on Godot's `EditorSyntaxHighlighter` and is registered with the Script Editor when the plugin starts. Highlighting and completion share `KS_LanguageCatalog`, while valid keywords come from the parser's `KS_Token.KEYWORDS`. Automated checks keep both sources aligned.

Completion offers commands, subcommands, insertable statement templates, and parameter signatures. It indexes project resources for KonadoScript paths, actors, states, motions, backgrounds, audio, and cameras. States and custom motions are filtered for the selected actor, dialogue voice completion handles quoted text containing spaces, and branches, variables, and signals from the current document are suggested immediately. Highlighting expressions are compiled once, and each line records only color transitions.

The default highlighting resource is located at:

```text
res://addons/konado/editor/ks_editor/highlighter.tres
```

Other `CodeEdit` controls can also instantiate the highlighter directly:

```gdscript
set_syntax_highlighter(KND_KsHighlighter.new())
```

## Live Diagnostics

After a short typing pause, Godot asks the KonadoScript language bridge to run lexical, syntax, and semantic analysis without generating a runtime `KND_Shot`. Errors and warnings appear on the relevant source lines and in the Script Editor's built-in problems panels, in Chinese or English according to the Godot editor language. Independent errors on multiple lines are reported together. Checks cover trailing arguments, invalid numeric and Boolean values, invalid jump paths, unknown resource IDs, missing target files, and actor lifecycle errors; malformed input cannot stall live analysis.

Click a problem to jump to the relevant location. Existing files remain open and repairable even when they contain syntax errors. The resource loader performs the authoritative compilation after saving, so live diagnostics do not replace the final load result.

## Shortcuts

| Action | Windows / Linux | macOS |
| --- | --- | --- |
| Save | `Ctrl+S` | `Command+S` |
| Close current tab | `Ctrl+W` | `Command+W` |
| Find | `Ctrl+F` | `Command+F` |
| Find and replace | `Ctrl+H` | `Command+Option+F` |
| Go to line | `Ctrl+L` | `Command+L` |
