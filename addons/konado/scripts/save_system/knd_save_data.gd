class_name KND_SaveData

## KND_SaveData
##
## 存档数据类，用于存储游戏状态的快照
## 包含对话状态、变量、音频状态、演员状态和背景状态等信息

## 对话状态
var dialogue_state: Dictionary = {}

## 游戏变量
var variables: Dictionary = {}

## 音频状态
var audio_state: Dictionary = {}

## 演员状态
var actor_state: Dictionary = {}

## 背景状态
var background_state: Dictionary = {}

## 存档时间
var save_time: Dictionary = {}

## 存档版本
var version: String = "1.0"

## 转换为字典
func to_dict() -> Dictionary:
	return {
		"dialogue_state": dialogue_state,
		"variables": variables,
		"audio_state": audio_state,
		"actor_state": actor_state,
		"background_state": background_state,
		"save_time": save_time,
		"version": version
	}

## 从字典加载
func from_dict(data: Dictionary) -> void:
	if data.has("dialogue_state"):
		dialogue_state = data["dialogue_state"]
	
	if data.has("variables"):
		variables = data["variables"]
	
	if data.has("audio_state"):
		audio_state = data["audio_state"]
	
	if data.has("actor_state"):
		actor_state = data["actor_state"]
	
	if data.has("background_state"):
		background_state = data["background_state"]
	
	if data.has("save_time"):
		save_time = data["save_time"]
	
	if data.has("version"):
		version = data["version"]
