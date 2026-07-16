extends Control
class_name SaveLoadUI

## 存读档界面

@export var save_componect: PackedScene = preload("res://addons/konado/template/ui_template/save_commponect/save_componect.tscn")

@export var root_container: BoxContainer

@export var save_slot_count: int = 20

## 存档系统引用
@export var save_system: KND_SaveSystem

## 存档组件列表
var save_components: Array[SaveComponent] = []

func _ready() -> void:
	_create_save_slot()
	update_all_save_info()
	var i18n := get_tree().root.get_node_or_null("KND_I18n")
	if i18n != null:
		i18n.locale_changed.connect(_on_locale_changed)



## 创建存档
func _create_save_slot() -> void:
	for i in save_slot_count:
		var save_slot: SaveComponent = save_componect.instantiate() as SaveComponent
		# 确保实例化成功
		if save_slot:
			root_container.add_child(save_slot)
			save_slot.save_id = i
			
			# 设置存档名称
			if i == 0:
				save_slot.save_name = tr("快速保存")
				save_slot.quicksave_sign.visible = true
			else:
				save_slot.save_name = tr("存档%02d") % (i + 1)
			save_slot.save_time = tr("未知时间")
			
			save_slot.init_empty_save_slot()
			
			# 添加到组件列表
			save_components.append(save_slot)

## 更新所有存档信息
func update_all_save_info() -> void:
	if not save_system:
		return
	
	# 获取所有存档信息
	var save_infos = save_system.get_all_save_info()
	
	# 更新每个存档组件的信息
	for i in range(min(save_components.size(), save_infos.size())):
		var save_component = save_components[i]
		var save_info = save_infos[i]
		
		# 设置存档系统
		save_component.set_save_system(save_system)
		
		# 更新存档信息
		save_component.update_save_info(save_info)

## 打开存档界面
func open_save_ui() -> void:
	# 更新存档信息
	update_all_save_info()
	# 显示界面
	visible = true

## 关闭存档界面
func close_save_ui() -> void:
	# 隐藏界面
	visible = false


func _on_locale_changed(_locale: String) -> void:
	if save_system:
		update_all_save_info()
	else:
		for save_component: SaveComponent in save_components:
			save_component.init_empty_save_slot()

func _process(delta: float) -> void:
	pass
