# Customizing the Dialogue Interface

## Introduction

If your work requires a custom dialogue interface, you can achieve this by modifying the template dialogue interface. At the same time, Godot Engine itself has a powerful theme system, so you can achieve the effect by modifying custom themes.

However, please note that after modifying the template dialogue interface, do not update the Konado plugin, otherwise your modifications will be overwritten.

## Editing the Scene File

`res://addons/konado/scenes/konado_dialogue.tscn` is the dialogue interface scene. You can customize the dialogue interface by modifying this file.

In general, please do not modify the scripts on the nodes, but achieve custom effects by modifying the properties on the nodes.

## Editing the Save Box

`res://addons/konado/template/ui_template/save_commponect/save_componect.tscn` is the save box scene. You can customize the save box by modifying this file.
