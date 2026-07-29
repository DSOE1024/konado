---
title: KonadoScript Editor
order: 5
---

# Built-in Godot KonadoScript Editor

After enabling the Konado plugin, double-click a `.ks` file in the FileSystem dock to open it in the bottom `KonadoEdit` panel. The editor modifies the original KonadoScript file and asks Godot to reimport it after each save.

## Editing Features

- Edit multiple `.ks` files in tabs while preserving each document's caret and unsaved state
- Save recovery drafts automatically and offer to restore them after an editor or plugin interruption
- Detect external file changes, reload clean documents automatically, and ask before resolving conflicts
- Find and replace text, go to a line, and navigate local branch symbols
- Insert every currently supported KonadoScript command from the statement catalog

## Highlighting and Completion

`KND_KsHighlighter` is built on Godot's `SyntaxHighlighter`. Highlighting, completion, and statement templates share `KS_LanguageCatalog`, while valid keywords come from the parser's `KS_Token.KEYWORDS`. Automated checks keep both sources aligned whenever a command is added or removed.

Highlighting expressions are compiled once, and each line records only color transitions. This avoids recompiling regular expressions or producing a dictionary entry for every character during editing and scrolling.

The default highlighting resource is located at:

```text
res://addons/konado/editor/ks_editor/highlighter.tres
```

Custom editors can also instantiate the highlighter directly:

```gdscript
set_syntax_highlighter(KND_KsHighlighter.new())
```

## Live Diagnostics

After a short typing pause, the editor runs lexical, syntax, and semantic analysis without generating runtime `KND_Shot` resources. Errors and warnings appear in both:

- Gutter markers and line background colors
- The problem list below the editor

Click a problem or its gutter marker to jump to the relevant location. Saving still runs the normal Godot import, so live diagnostics do not replace the final import result.

## Shortcuts

| Action | Windows / Linux | macOS |
| --- | --- | --- |
| Save | `Ctrl+S` | `Command+S` |
| Close current tab | `Ctrl+W` | `Command+W` |
| Find | `Ctrl+F` | `Command+F` |
| Find and replace | `Ctrl+H` | `Command+Option+F` |
| Go to line | `Ctrl+L` | `Command+L` |
