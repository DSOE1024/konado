@tool
extends KND_Data
class_name KND_Shot

@export var shot_id: String = "新镜头"

## 对话
@export var dialogues: Array[KND_Dialogue] = []

## 分支
@export var branches: Dictionary = {}
