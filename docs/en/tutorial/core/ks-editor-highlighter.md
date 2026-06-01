---
title: Syntax Highlighter
order: 5
---

# KND_KsHighlighter Editor Syntax Highlighting

## Introduction

Syntax highlighting is an essential part of any editor. It helps developers visually identify code structure, improving both writing efficiency and readability.

`KND_KsHighlighter` is a highlighter based on Godot's `SyntaxHighlighter`, specifically designed for KS scripts. It centralises all highlighting rules in a single script, making customisation and extension highly flexible — you can easily adjust existing rules or add entirely new colour schemes.

## Basic Implementation

In `KND_KsHighlighter`, highlighting rules are stored as an array. Each array element is a dictionary containing two keys:

- `regex` — A regular expression for matching text (Godot RegEx syntax).
- `color` — The colour of the matched text, expressed as `Color(r, g, b, a)`, where `a` is the alpha value (optional, defaults to 1.0).

Example structure:

```gdscript
{
    "regex": "\\b(if|else|endif)\\b",
    "color": Color(1.0, 0.8, 0.2)
}
```

The highlighter matches rules in array order. Rules applied later may override earlier matches, so the order of rules is important (it is recommended to place general commands first, with strings and comments afterwards, to ensure proper coverage).

## Custom Colour Schemes

You can apply custom highlighting to the editor in two ways:

### Method 1: Modify the Resource File (Recommended)

The default colour scheme is stored as a resource file at:
```
res://addons/konado/editor/ks_editor/ks_syntax_highlighter.tres
```

Editing this resource file directly preserves your changes and avoids regeneration each time.

Load and use the resource in code:

```gdscript
set_syntax_highlighter(load("res://addons/konado/editor/ks_editor/ks_syntax_highlighter.tres"))
```

### Method 2: Create an Instance Dynamically

You can also create a new `KND_KsHighlighter` instance in code and set custom rules for it (by modifying `highlight_rules` in the script):

```gdscript
set_syntax_highlighter(KND_KsHighlighter.new())
```

> **Note**: If you modify the `KND_KsHighlighter.gd` script directly, you may need to regenerate the resource file for the changes to take effect. Using the resource file approach is recommended for easier colour management.
