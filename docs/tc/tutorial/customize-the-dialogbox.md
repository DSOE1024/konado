# 自訂對話介面

## 介紹

如果你的作品需要自訂對話介面，你可以透過修改模板對話介面來實現，同時 Godot Engine 本身就擁有強大的主題系統，你可以透過修改自訂主題來達到效果。

但是請注意，修改模板對話介面後請不要更新 Konado 插件，否則你的修改會被覆蓋。

## 編輯場景檔案

`res://addons/konado/scenes/konado_dialogue.tscn` 是對話介面場景，你可以透過修改這個檔案來自訂對話介面。

一般情況下請不要修改節點上的腳本，而是透過修改節點上的屬性來達到自訂的效果。

## 編輯存檔框

`res://addons/konado/template/ui_template/save_commponect/save_componect.tscn` 是存檔框場景，你可以透過修改這個檔案來自訂存檔框。