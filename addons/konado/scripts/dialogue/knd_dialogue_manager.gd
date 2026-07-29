extends Control
class_name KND_DialogueManager

## KND_DialogueManager
##
## Konado对话管理器是对话系统的核心管理类，负责统一调度和管理对话流程的全生命周期。
## 包括对话初始化、播放控制、对话指令执行、状态管理和错误处理。
## 将该脚本挂载到场景中的Control节点上，在编辑器面板中配置配置对话资源后即可开始使用

## 镜头开启播放的信号
signal shot_start

## 镜头结束播放的信号
signal shot_end

## 对话开始播放的信号
signal dialogue_line_start(node_id: String)

## 对话结束播放的信号
signal dialogue_line_end(node_id: String)

## 自定义信号
signal custom_signal(content: String)

## 对话状态（0:关闭，1:播放，2:播放完成下一个）
enum DialogState { OFF = 0, PLAYING = 1, PAUSED = 2 }

const DIALOGUE_SERVICES := preload("res://addons/konado/scripts/dialogue/knd_dialogue_services.gd")

@export_category("Playback Settings")

## 是否检查对话节点可见，如果不可见不会执行后续初始化和播放操作，同时会订阅hidden信号，在节点隐藏时停止对话
## 建议设置为true
@export var check_visable: bool = true

## 是否在游戏开始时自动初始化对话，如果为true，则在游戏开始时自动初始化对话，否则需要手动初始化对话
## 手动初始化对话的方法为：在游戏开始时，调用`init_dialogue`方法
@export var init_onstart: bool = true

## 是否自动开始对话，如果为true，则在游戏开始时自动开始对话，否则需要手动开始对话
## 手动开始对话的方法为：在游戏开始时，调用`start_dialogue`方法
@export var autostart: bool = true

## 是否开启演员自动高亮，如果为true，则根据对话中的角色姓名自动高亮对应的演员，否则不自动高亮
## 一般来说大部分场景可能需要打开能获得更好的效果
@export var actor_auto_highlight: bool = true

## 自动播放
@export var autoplay: bool = false
## 对话打字播放速度
@export var _typing_interval: float = 0.04
## 自动播放速度
@export var autoplayspeed: float = 2

@export_category("Global Variable")

## 对话全局变量存储（%前缀，持久化）
@export var variable_store: KND_VariableStore

@export_category("UI Settings")

## 自动显示dialogue_box
@export var auto_show_dialogue_box: bool = true

## 演员画布横向分块
@export var horizontal_division: int = 5

## 对话界面接口类
@export var _konado_choice_interface: KND_ChoiceInterface

## 对话框
@export var _konado_dialogue_box: KND_DialogueBox

## 屏幕文本（NVL Overlay）
@export var _screen_text: KND_ScreenText

## 背景和角色UI界面接口
@export var _acting_interface: KND_ActingInterface
## 音频接口
@export var _audio_interface: KND_AudioInterface

## 自动播放按钮
@export var _auto_play_button: Button

## 设置按钮
@export var _settings_button: Button

## 资源列表
@export_category("Dialogue Resources")
## 对话资源
@export var start_dialogue_shot: KND_Shot = null
## 角色列表
@export var chara_list: KND_CharacterList
## 背景列表
@export var background_list: KND_BackgroundList
## BGM列表
@export var bgm_list: KND_BgmList
## 配音资源列表
@export var voice_list: DialogVoiceList
## 音效列表
@export var soundeffect_list: KND_SoundEffectList

@export_category("Log Tool")
## 是否显示错误日志覆盖
@export var enable_overlay_log: bool = true
## 报错提示面板
@export var error_tooltip_panel: ColorRect
@export var error_tooltip_label: Label
@export var error_skip_btn: Button
## 浏览器各种快捷键调试功能，Godot默认会拦截，如果需要在web调试请打开
@export var enable_web_devtool: bool = false

@export_category("System")
## 存档系统
@export var save_system: KND_SaveSystem

## 设置桥接器
@export var _settings_bridge: KND_SettingsBridge

@export_category("Camera")
## 相机管理器
@export var _konado_cam_manager: KonadoCameraManager

var option_triggered: bool = false

var dialogue_state: DialogState

## 当前对话
var cur_dialogue_shot: KND_Shot

## 当前对话节点ID
var cur_node_id: String = ""

## 是否第一进入当前句对话，由于一些方法只需要在首次进入当前行对话时调用一次，而一些方法需要循环调用（如检查打字动画是否完成的方法）
## 因此，需要判断是否第一次进入当前行对话
var justenter: bool

## 当前对话的类型
var cur_dialogue_type: KND_Dialogue.Type

## 成就系统单例引用
var achievement_mgr: Node = null

## 对话临时变量存储（$前缀，仅脚本内有效，每次镜头重置）
var _temp_variables: Dictionary = {}

## 等待中的外部信号名称（用于 WAIT_SIGNAL 类型）
var _waiting_signal_name: String = ""

## 对话资源ID
var _dialog_data_id: int = 0

## 运行时国际化服务
var _i18n_service: Node
var _dialogue_services: RefCounted
var _logger: KND_Logger


func _services() -> RefCounted:
	if _dialogue_services == null:
		_dialogue_services = DIALOGUE_SERVICES.new(self)
	return _dialogue_services


## 获取当前对话节点
func _current_dialogue() -> KND_Dialogue:
	if cur_dialogue_shot == null or cur_node_id.is_empty():
		return null
	return cur_dialogue_shot.find_node(cur_node_id)


## 设置变更处理
func _on_setting_changed(category: String, key: String, value: Variant) -> void:
	_services()._apply_setting(category, key, value)


func _ready() -> void:
	_i18n_service = get_tree().root.get_node_or_null("KND_I18n")
	if _i18n_service != null:
		if not _i18n_service.call("is_initialized"):
			await Signal(_i18n_service, "initialized")
			if not is_inside_tree():
				return
		_i18n_service.call("register_dialogue_manager", self)
		var localized_start := _load_localized_shot(start_dialogue_shot)
		if localized_start != null:
			start_dialogue_shot = localized_start

	# 读取自动播放设置
	if _settings_bridge:
		var auto = _settings_bridge.get_auto_mode()
		var auto_delay = _settings_bridge.get_auto_delay()
		autoplayspeed = auto_delay
		await get_tree().process_frame
		start_autoplay(auto)
	if check_visable:
		if not self.is_visible_in_tree():
			printerr("对话已隐藏，不做任何操作")
			return
		self.hidden.connect(
			func():
				printerr("对话已隐藏，自动停止")
				stop_dialogue()
		)

	if enable_overlay_log:
		print("开启日志记录器")
		# 初始化Logger
		_logger = KND_Logger.new()
		OS.add_logger(_logger)
		# 使用Deferred避免线程问题
		_logger.error_caught.connect(_show_error, ConnectFlags.CONNECT_DEFERRED)

		if error_skip_btn:
			error_skip_btn.pressed.connect(func(): error_tooltip_panel.hide())
		else:
			push_warning("未指定 error_skip_btn")

	if _konado_dialogue_box:
		_konado_dialogue_box.on_dialogue_click.connect(_process_next)
	else:
		push_error("未指定 _konado_dialogue_box")

	if _auto_play_button:
		_auto_play_button.toggled.connect(start_autoplay)
	else:
		push_error("未指定 _auto_play_button")

	if _konado_dialogue_box and _audio_interface and _audio_interface.voice_player:
		_konado_dialogue_box.bind_voice_player(_audio_interface.voice_player)

	# 如果有设置系统
	if _settings_bridge:
		_settings_bridge.setting_changed.connect(_on_setting_changed)
		if _settings_button:
			_settings_button.pressed.connect(func(): _settings_bridge.show_settings_panel())

	# 设置存档系统的对话管理器引用
	if save_system:
		save_system.set_dialogue_manager(self)

	## 尝试获取成就系统
	achievement_mgr = get_tree().root.get_node_or_null("KND_AchievementManager")
	if achievement_mgr == null:
		print("成就系统不可用")

	if not variable_store:
		variable_store = KND_VariableStore.new()
		print("变量存储自动初始化")

	# 自动初始化和开始对话
	if init_onstart:
		print("自动初始化对话")
		# 初始化对话
		if not autostart:
			init_dialogue(func(): print("请手动开始对话"))
		else:
			init_dialogue(
				func():
					print("自动开始对话")
					await get_tree().process_frame
					start_dialogue()
			)
	else:
		print("请手动初始化对话")


func _exit_tree() -> void:
	if _i18n_service != null and is_instance_valid(_i18n_service):
		_i18n_service.call("unregister_dialogue_manager", self)
	if _logger != null:
		if _logger.error_caught.is_connected(_show_error):
			_logger.error_caught.disconnect(_show_error)
		OS.remove_logger(_logger)
		_logger = null


## 显示报错
func _show_error(msg: String) -> void:
	_services()._show_error(msg)


## 初始化对话的方法
func init_dialogue(callback: Callable = Callable()) -> void:
	# 如果对话数据为空，则默认为第一个对话数据
	if start_dialogue_shot == null:
		push_error("未设置对话镜头")
		return
	# 如果不为空，复制一份start_dialogue_shot
	cur_dialogue_shot = start_dialogue_shot.duplicate()
	# 将角色表传给acting_interface
	_acting_interface.chara_list = chara_list

	# 初始化各管理器
	_acting_interface.delete_all_actor()

	justenter = true
	dialogue_state = DialogState.OFF
	_temp_variables.clear()
	_waiting_signal_name = ""
	if cur_dialogue_shot.start_node_id and not cur_dialogue_shot.start_node_id.is_empty():
		cur_node_id = cur_dialogue_shot.start_node_id
	elif cur_dialogue_shot.dialogues.size() > 0:
		cur_node_id = cur_dialogue_shot.dialogues[0].node_id
	else:
		cur_node_id = ""
	print_rich(
		(
			"[color=yellow]初始化对话 [/color]"
			+ "justenter: "
			+ str(justenter)
			+ " 当前节点ID: "
			+ str(cur_node_id)
			+ " 当前状态: "
			+ str(dialogue_state)
		)
	)
	print("---------------------------------------------")
	if callback:
		callback.call()


## 设置对话数据的方法
func set_shot(new_shot: KND_Shot) -> void:
	var localized_shot := _load_localized_shot(new_shot)
	if localized_shot != null:
		new_shot = localized_shot
	cur_dialogue_shot = new_shot.duplicate()
	_temp_variables.clear()
	_waiting_signal_name = ""
	if cur_dialogue_shot.start_node_id and not cur_dialogue_shot.start_node_id.is_empty():
		cur_node_id = cur_dialogue_shot.start_node_id
	elif cur_dialogue_shot.dialogues.size() > 0:
		cur_node_id = cur_dialogue_shot.dialogues[0].node_id
	else:
		cur_node_id = ""


## 重新加载当前镜头的语言脚本，并尽量保持当前节点。
func reload_localized_script(locale: String) -> bool:
	return _services()._reload_localized_script(locale)


func _get_i18n_service() -> Node:
	return _services()._get_i18n_service()


func _load_localized_shot(shot: KND_Shot) -> KND_Shot:
	return _services()._load_localized_shot(shot)


func _refresh_current_localized_dialogue() -> void:
	_services()._refresh_current_localized_dialogue()


## 设置角色表的方法
func set_chara_list(chara_list: KND_CharacterList) -> void:
	_services()._set_character_list(chara_list)


func set_background_list(background_list: KND_BackgroundList) -> void:
	_services()._set_background_list(background_list)


func set_bgm_list(bgm_list: KND_BgmList) -> void:
	_services()._set_bgm_list(bgm_list)


## 获取对话变量
func get_dialogue_variable(key: String) -> Dictionary:
	return _services()._get_dialogue_variable(key)


## 开始对话的方法
func start_dialogue() -> void:
	if _konado_choice_interface:
		_konado_choice_interface.show()
	if _acting_interface:
		_acting_interface.show()
	_dialogue_goto_state(DialogState.PLAYING)
	print_rich("[color=yellow]开始对话 [/color]")
	# 播放镜头信号
	shot_start.emit()


func _process(_delta) -> void:
	match dialogue_state:
		# 关闭状态
		DialogState.OFF:
			if justenter:
				print_rich("[color=cyan][b]当前状态：[/b][/color][color=orange]关闭状态[/color]")
				justenter = false
		# 播放状态
		DialogState.PLAYING:
			if justenter:
				justenter = false
				print_rich("[color=cyan][b]当前状态：[/b][/color][color=orange]播放状态[/color]")
				if cur_dialogue_shot == null:
					print_rich("[color=red]对话为空[/color]")
					return
				var dialog = _current_dialogue()
				if dialog == null:
					print_rich("[color=red]当前节点为空，节点ID: %s[/color]" % cur_node_id)
					_dialogue_goto_state(DialogState.OFF)
					return
				var cam_manager := _konado_cam_manager
				cur_dialogue_type = dialog.dialog_type
				dialogue_line_start.emit(cur_node_id)
				_konado_choice_interface._choice_container.hide()
				if cur_dialogue_type == KND_Dialogue.Type.ORDINARY_DIALOG:
					var play_dialogue = func():
						var chara_id
						var content
						var voice_id
						if dialog.character_id != null:
							chara_id = dialog.character_id
						if dialog.dialog_content != null:
							content = _interpolate_variables(dialog.dialog_content)
						if dialog.voice_id:
							voice_id = dialog.voice_id

						var playvoice: bool = false
						var voice_wait_time: float = 0.0
						if voice_id:
							playvoice = true

						if voice_id:
							voice_wait_time = _play_voice(voice_id)
						else:
							if _konado_dialogue_box:
								_konado_dialogue_box.clear_voice_progress()

						if _konado_dialogue_box.typing_completed.is_connected(isfinishtyping):
							_konado_dialogue_box.typing_completed.disconnect(isfinishtyping)

						_konado_dialogue_box.typing_completed.connect(
							isfinishtyping.bind(playvoice, voice_wait_time)
						)
						if actor_auto_highlight:
							if chara_id:
								_acting_interface.highlight_actor(chara_id)
						_konado_dialogue_box.typing_interval = _typing_interval
						_konado_dialogue_box.dialogue_text = content
						_konado_dialogue_box.character_name = chara_id

					if auto_show_dialogue_box:
						if not _konado_dialogue_box.is_dialogue_box_visible():
							_konado_dialogue_box.show_dialogue_box(play_dialogue)
					else:
						if not _konado_dialogue_box.is_dialogue_box_visible():
							printerr("请先让对话框显示")
						play_dialogue.call()
				elif cur_dialogue_type == KND_Dialogue.Type.SWITCH_BACKGROUND:
					var bg_name = dialog.background_name
					if bg_name.is_empty():
						bg_name = dialog.background_image_name
					var bg_effect = dialog.background_toggle_effects
					var s = _acting_interface.background_change_finished
					if not s.is_connected(_auto_process_next.bind(s)):
						s.connect(_auto_process_next.bind(s))
					_acting_interface.show()
					_display_background(bg_name, bg_effect)
				elif cur_dialogue_type == KND_Dialogue.Type.DISPLAY_ACTOR:
					var s = _acting_interface.character_shown
					if not s.is_connected(_auto_process_next.bind(s)):
						s.connect(_auto_process_next.bind(s))
					_acting_interface.show()
					_display_character(dialog)
				elif cur_dialogue_type == KND_Dialogue.Type.ACTOR_CHANGE_STATE:
					var actor = dialog.change_state_actor
					var target_state = dialog.change_state
					var s = _acting_interface.character_state_changed
					if not s.is_connected(_auto_process_next.bind(s)):
						s.connect(_auto_process_next.bind(s))
					_actor_change_state(actor, target_state)
				elif cur_dialogue_type == KND_Dialogue.Type.MOVE_ACTOR:
					var actor = dialog.target_move_chara
					var pos = dialog.target_move_pos
					var s = _acting_interface.character_moved
					if not s.is_connected(_auto_process_next.bind(s)):
						s.connect(_auto_process_next.bind(s))
					_acting_interface.move_actor(actor, pos.x)
				elif cur_dialogue_type == KND_Dialogue.Type.ACTOR_MOTION:
					var actor = dialog.motion_actor
					var motion_name = dialog.motion_name
					var s = _acting_interface.character_motion_finished
					var auto_next := _auto_process_next_from_motion.bind(s)
					if not s.is_connected(auto_next):
						s.connect(auto_next)
					_acting_interface.play_actor_motion(actor, motion_name)
				elif cur_dialogue_type == KND_Dialogue.Type.EXIT_ACTOR:
					var actor = dialog.exit_actor
					var s = _acting_interface.character_deleted
					if not s.is_connected(_auto_process_next.bind(s)):
						s.connect(_auto_process_next.bind(s))
					_exit_actor(actor)
				elif cur_dialogue_type == KND_Dialogue.Type.MOVE_CAM:
					var callback = func():
						print("镜头移动完毕")
						_dialogue_goto_state(DialogState.PAUSED)
						_process_next()
					cam_manager.move_cam(
						dialog.target_cam, dialog.cam_tween_time, callback, dialog.cam_tween_type
					)
				elif cur_dialogue_type == KND_Dialogue.Type.RESET_CAM:
					var callback = func():
						print("镜头重置完毕")
						_dialogue_goto_state(DialogState.PAUSED)
						_process_next()
					cam_manager.reset_cam(
						true, dialog.cam_tween_time, callback, dialog.cam_tween_type
					)
				elif cur_dialogue_type == KND_Dialogue.Type.CAM_SHAKE:
					var callback = func():
						print("镜头晃动完毕")
						_dialogue_goto_state(DialogState.PAUSED)
						_process_next()
					_konado_cam_manager.shake_cam(dialog.cam_shake_time, callback)
				elif cur_dialogue_type == KND_Dialogue.Type.ASYNC_MOVE_CAM:
					print("异步移动镜头: %s" % dialog.target_cam)
					cam_manager.async_move_cam(
						dialog.target_cam, dialog.cam_tween_time, dialog.cam_tween_type
					)
					_dialogue_goto_state(DialogState.PAUSED)
					_process_next()
				elif cur_dialogue_type == KND_Dialogue.Type.ASYNC_RESET_CAM:
					print("异步重置镜头")
					cam_manager.async_reset_cam(dialog.cam_tween_time, dialog.cam_tween_type)
					_dialogue_goto_state(DialogState.PAUSED)
					_process_next()
				elif cur_dialogue_type == KND_Dialogue.Type.ASYNC_CAM_SHAKE:
					print("异步镜头晃动: %.2f 秒" % dialog.cam_shake_time)
					_konado_cam_manager.async_shake_cam(dialog.cam_shake_time)
					_dialogue_goto_state(DialogState.PAUSED)
					_process_next()
				elif cur_dialogue_type == KND_Dialogue.Type.ASYNC_CAM_STOP:
					print("强制停止异步相机动画")
					_konado_cam_manager.async_stop_all()
					_dialogue_goto_state(DialogState.PAUSED)
					_process_next()
				elif cur_dialogue_type == KND_Dialogue.Type.SCREEN_TEXT:
					if _screen_text == null:
						printerr("未指定 _screen_text 组件，跳过")
						_dialogue_goto_state(DialogState.PAUSED)
						_process_next()
						return

					var s = _screen_text.display_finished
					if not s.is_connected(_auto_process_next.bind(s)):
						s.connect(_auto_process_next.bind(s))

					_screen_text.display(dialog.text_content)
				elif cur_dialogue_type == KND_Dialogue.Type.SHOW_TEXTBOX:
					if _konado_dialogue_box == null:
						printerr("未指定 _konado_dialogue_box 组件，跳过")
						_dialogue_goto_state(DialogState.PAUSED)
						_process_next()
						return

					var s = _konado_dialogue_box.on_dialogue_show_completed
					if not s.is_connected(_auto_process_next.bind(s)):
						s.connect(_auto_process_next.bind(s))
					_konado_dialogue_box.show_dialogue_box_with_duration(dialog.textbox_duration)
				elif cur_dialogue_type == KND_Dialogue.Type.HIDE_TEXTBOX:
					if _konado_dialogue_box == null:
						printerr("未指定 _konado_dialogue_box 组件，跳过")
						_dialogue_goto_state(DialogState.PAUSED)
						_process_next()
						return

					var s = _konado_dialogue_box.on_dialogue_hide_completed
					if not s.is_connected(_auto_process_next.bind(s)):
						s.connect(_auto_process_next.bind(s))
					_konado_dialogue_box.hide_dialogue_box_with_duration(dialog.textbox_duration)
				elif cur_dialogue_type == KND_Dialogue.Type.WAIT_SIGNAL:
					_waiting_signal_name = dialog.wait_signal_name
				elif cur_dialogue_type == KND_Dialogue.Type.SHOW_CHOICE:
					var dialog_choices = dialog.choices
					if dialog_choices.size() <= 0:
						printerr("当前没有任何选项，为不影响运行跳过")
						_dialogue_goto_state(DialogState.PAUSED)
						await get_tree().process_frame
						_process_next()
					else:
						print_rich("[color=green]显示选项，共 %d 个选项[/color]" % dialog_choices.size())
						for c in dialog_choices:
							print_rich(
								'[color=green]  "%s" -> %s[/color]' % [c.choice_text, c.next_id]
							)
						_konado_choice_interface.display_options(dialog_choices, self)
						_acting_interface.show()
						_konado_choice_interface.show()
						_konado_choice_interface._choice_container.show()
				elif cur_dialogue_type == KND_Dialogue.Type.PLAY_BGM:
					var bgm_name = dialog.bgm_name
					_play_bgm(bgm_name)
					_dialogue_goto_state(DialogState.PAUSED)
					_process_next()
				elif cur_dialogue_type == KND_Dialogue.Type.STOP_BGM:
					_audio_interface.stop_bgm()
					_dialogue_goto_state(DialogState.PAUSED)
					_process_next()
				elif cur_dialogue_type == KND_Dialogue.Type.PLAY_SOUND_EFFECT:
					var se_name = dialog.soundeffect_name
					_play_soundeffect(se_name)
					_dialogue_goto_state(DialogState.PAUSED)
					_process_next()
				elif cur_dialogue_type == KND_Dialogue.Type.IFELSE_BRANCH:
					print("ifelse流程控制分支")
					var condition_met = false
					var current_value: Variant = null

					if dialog.is_persistent:
						if variable_store and variable_store.has(dialog.varname):
							current_value = variable_store.get_value(dialog.varname)
					else:
						if _temp_variables.has(dialog.varname):
							current_value = _temp_variables[dialog.varname]

					if current_value != null:
						match dialog.condition_operator:
							0:
								condition_met = (float(current_value) == float(dialog.target_value))
							1:
								condition_met = (float(current_value) > float(dialog.target_value))
							2:
								condition_met = (float(current_value) < float(dialog.target_value))
							3:
								condition_met = (float(current_value) >= float(dialog.target_value))
							4:
								condition_met = (float(current_value) <= float(dialog.target_value))
							5:
								condition_met = (float(current_value) != float(dialog.target_value))
					else:
						printerr("无法获取变量: " + dialog.varname)

					if condition_met and not dialog.if_next_id.is_empty():
						# 条件成立，跳转到if分支
						cur_node_id = dialog.if_next_id
						_dialogue_goto_state(DialogState.PLAYING)
					elif not condition_met and not dialog.else_next_id.is_empty():
						# 条件不成立，跳转到else分支
						cur_node_id = dialog.else_next_id
						_dialogue_goto_state(DialogState.PLAYING)
					else:
						# 没有对应分支，走主线next_id
						if not dialog.next_id.is_empty():
							cur_node_id = dialog.next_id
							_dialogue_goto_state(DialogState.PLAYING)
						else:
							_dialogue_goto_state(DialogState.OFF)
				elif cur_dialogue_type == KND_Dialogue.Type.BRANCH:
					print_rich("[color=orange]分支对话（已弃用）[/color]")
					if not dialog.next_id.is_empty():
						cur_node_id = dialog.next_id
						_dialogue_goto_state(DialogState.PLAYING)
					else:
						_dialogue_goto_state(DialogState.OFF)
				elif cur_dialogue_type == KND_Dialogue.Type.JUMP:
					var load_path = dialog.jump_shot_path
					if load_path:
						var res = load(load_path) as KND_Shot
						print(res.dialogues)
						_dialogue_goto_state(DialogState.OFF)
						set_shot(res)
						_dialogue_goto_state(DialogState.PLAYING)
				elif cur_dialogue_type == KND_Dialogue.Type.JUMP_BRANCH:
					if not dialog.next_id.is_empty():
						cur_node_id = dialog.next_id
						_dialogue_goto_state(DialogState.PLAYING)
					else:
						printerr("jump_branch 目标节点为空")
						_dialogue_goto_state(DialogState.OFF)
				elif cur_dialogue_type == KND_Dialogue.Type.SIGNAL:
					var content = dialog.custom_signal_name
					custom_signal.emit(content)
					await get_tree().process_frame
					_dialogue_goto_state(DialogState.PAUSED)
					_process_next()
				elif cur_dialogue_type == KND_Dialogue.Type.ACHIEVEMENT_UNLOCK:
					if achievement_mgr:
						achievement_mgr.unlock_achievement(dialog.achievement_id)
					_dialogue_goto_state(DialogState.PAUSED)
					await get_tree().process_frame
					_process_next()
				elif cur_dialogue_type == KND_Dialogue.Type.ACHIEVEMENT_PROGRESS:
					if achievement_mgr:
						achievement_mgr.increment_progress(
							dialog.achievement_id, dialog.achievement_value
						)
					_dialogue_goto_state(DialogState.PAUSED)
					await get_tree().process_frame
					_process_next()
				elif cur_dialogue_type == KND_Dialogue.Type.ACHIEVEMENT_FLAG:
					if achievement_mgr:
						achievement_mgr.set_flag(
							dialog.achievement_flag_name, dialog.achievement_flag_value
						)
					_dialogue_goto_state(DialogState.PAUSED)
					await get_tree().process_frame
					_process_next()
				elif cur_dialogue_type == KND_Dialogue.Type.SET_VARIABLE:
					_handle_variable_operation(dialog)
					_dialogue_goto_state(DialogState.PAUSED)
					_process_next()
				elif cur_dialogue_type == KND_Dialogue.Type.THE_END:
					stop_dialogue()

		# 完成下一个状态
		DialogState.PAUSED:
			if justenter:
				justenter = false
				print_rich("[color=cyan][b]状态：[/b][/color][color=orange]播放完成状态[/color]")


## 打字完成回调
func isfinishtyping(wait_voice: bool, wait_voice_time: float) -> void:
	_dialogue_goto_state(DialogState.PAUSED)
	if autoplay:
		if wait_voice:
			print("等待音频播放完成")
			# 创建计时器
			var timer = get_tree().create_timer(wait_voice_time)
			timer.timeout.connect(func(): _process_next())
		else:
			await get_tree().create_timer(autoplayspeed).timeout
			_process_next()
			print("触发打字完成信号")
	else:
		var current = _current_dialogue()
		if current == null:
			print("当前对话为空，无法获取下一句")
			return

		var next_id = current.next_id
		# 检查下一句是否是选项，如果是自动下一句
		var nd: KND_Dialogue = cur_dialogue_shot.find_node(next_id)
		if nd != null and nd.dialog_type == KND_Dialogue.Type.SHOW_CHOICE:
			print("选项自动下一个")
			await get_tree().create_timer(0.05).timeout
			_process_next()
		print("触发打字完成信号")


## 触发等待的外部信号，匹配成功则继续下一句对话
## 外部调用示例： $dialogue_manager.emit_wait_signal("over")
func emit_wait_signal(signal_name: String) -> void:
	if _waiting_signal_name.is_empty():
		return
	if _waiting_signal_name == signal_name:
		_waiting_signal_name = ""
		_dialogue_goto_state(DialogState.PAUSED)
		_process_next()


## 处理下一个，绑定到下一个按钮
func _process_next() -> void:
	dialogue_line_end.emit(cur_node_id)
	print_rich("[color=yellow]判断状态[/color]")
	match dialogue_state:
		DialogState.OFF:
			print("对话关闭状态，无需做任何操作")
			return
		DialogState.PLAYING:
			if cur_dialogue_type == KND_Dialogue.Type.ORDINARY_DIALOG:
				_konado_dialogue_box.skip_typing_anim()
			else:
				print("对话播放状态，等待播放完成")
			return
		DialogState.PAUSED:
			_audio_interface.stop_voice()
			# 隐藏 NVL 屏幕文本
			if _screen_text and _screen_text.visible:
				_screen_text.hide()
				_screen_text.modulate.a = 0.0
			print("对话播放完成，开始播放下一个")
			# 检查是否还有下一个节点
			var cur: KND_Dialogue = _current_dialogue()
			if (
				cur == null
				or cur.next_id.is_empty()
				or cur_dialogue_shot.find_node(cur.next_id) == null
			):
				# 切换到对话关闭状态
				_dialogue_goto_state(DialogState.OFF)
			else:
				_goto_next_node()
				# 切换到播放状态
				_dialogue_goto_state(DialogState.PLAYING)
			return


## 自动下一个，添加信号解绑功能保证只被触发一次
func _auto_process_next(s: Signal) -> void:
	if _konado_cam_manager:
		_konado_cam_manager.get_all_konado_cameras()
	else:
		printerr("刷新镜头群失败")
	var auto_next := _auto_process_next.bind(s)
	_dialogue_goto_state(DialogState.PAUSED)
	if not s.is_null() and s.is_connected(auto_next):
		s.disconnect(auto_next)
		print("触发自动下一个信号")
	_process_next()


func _auto_process_next_from_motion(_actor_id: String, _motion_name: String, s: Signal) -> void:
	var auto_next := _auto_process_next_from_motion.bind(s)
	_dialogue_goto_state(DialogState.PAUSED)
	if not s.is_null() and s.is_connected(auto_next):
		s.disconnect(auto_next)
		print("触发演员动作自动下一个信号")
	_process_next()


## 关闭对话的方法
func stop_dialogue() -> void:
	_acting_interface.delete_all_actor()
	_acting_interface.clean_background(
		KND_ActingInterface.BackgroundTransitionEffectsType.ALPHA_FADE_EFFECT
	)
	# 隐藏 NVL 屏幕文本
	if _screen_text and _screen_text.visible:
		_screen_text.hide()
		_screen_text.modulate.a = 0.0
	print_rich("[color=yellow]关闭对话[/color]")
	# 重置等待信号
	_waiting_signal_name = ""
	# 切换到关闭状态
	_dialogue_goto_state(DialogState.OFF)
	_konado_dialogue_box.hide_dialogue_box()
	shot_end.emit()


## 对话状态切换的方法
func _dialogue_goto_state(dialogstate: DialogState) -> void:
	# 重置justenter状态
	justenter = true
	# 切换状态到
	dialogue_state = dialogstate
	print_rich("[color=yellow]切换状态到: [/color]" + str(dialogue_state))


## 导航到下一个节点
func _goto_next_node() -> void:
	var node := _current_dialogue()
	if node:
		cur_node_id = node.next_id
	print("---------------------------------------------")
	# 打印时间 日期+时间
	print("当前时间：" + str(Time.get_time_string_from_system()))
	print("导航到节点: %s" % cur_node_id)


## 开始自动播放的方法
func start_autoplay(value: bool):
	autoplay = value
	if value:
		_auto_play_button.set_text(tr("停止播放"))
	else:
		_auto_play_button.set_text(tr("自动播放"))
	await get_tree().process_frame
	if autoplay or dialogue_state != DialogState.OFF:
		_process_next()


## 显示背景的方法
func _display_background(
	bg_name: String, effect: KND_ActingInterface.BackgroundTransitionEffectsType
) -> void:
	_services()._display_background(bg_name, effect)


## 演员状态切换的方法
func _actor_change_state(chara_id: String, state_id: String):
	_services()._actor_change_state(chara_id, state_id)


## 从角色列表创建并显示角色
func _display_character(dialogue: KND_Dialogue) -> void:
	_services()._display_character(dialogue)


## 演员退场
func _exit_actor(actor_name: String) -> void:
	_services()._exit_actor(actor_name)


## 播放BGM
func _play_bgm(bgm_name: String) -> void:
	_services()._play_bgm(bgm_name)


## 播放配音，返回音频时长
func _play_voice(voice_name: String) -> float:
	return _services()._play_voice(voice_name)


## 播放音效
func _play_soundeffect(se_name: String) -> void:
	_services()._play_sound_effect(se_name)


func _handle_variable_operation(dialog: KND_Dialogue) -> void:
	_services()._handle_variable_operation(dialog)


## 获取变量字符，比如好感度，角色名称等
func _interpolate_variables(text: String) -> String:
	return _services()._interpolate_variables(text)


## 选项触发方法
func on_option_triggered(choice: KND_DialogueChoice) -> void:
	_konado_choice_interface._choice_container.hide()
	dialogue_line_end.emit(cur_node_id)
	print_rich('[color=green]玩家选择: "%s" -> %s[/color]' % [choice.choice_text, choice.next_id])
	if not choice.next_id.is_empty():
		var target = cur_dialogue_shot.find_node(choice.next_id)
		if target == null:
			printerr("选项目标节点不存在: %s，停止对话" % choice.next_id)
			_dialogue_goto_state(DialogState.OFF)
			return
		cur_node_id = choice.next_id
		_dialogue_goto_state(DialogState.PLAYING)
	else:
		print_rich("[color=yellow]选项没有跳转目标，停止对话[/color]")
		_dialogue_goto_state(DialogState.OFF)


## 保存游戏
func save_game(save_id: int) -> bool:
	return _services()._save_game(save_id)


## 加载游戏
func load_game(save_id: int) -> bool:
	return _services()._load_game(save_id)


## 删除存档
func delete_save(save_id: int) -> bool:
	return _services()._delete_save(save_id)


## 获取存档信息
func get_save_info(save_id: int) -> Dictionary:
	return _services()._get_save_info(save_id)


## 获取所有存档信息
func get_all_save_info() -> Array[Dictionary]:
	return _services()._get_all_save_info()


## 设置存档策略
func set_save_strategy(strategy: Dictionary) -> void:
	_services()._set_save_strategy(strategy)


## 获取存档策略
func get_save_strategy() -> Dictionary:
	return _services()._get_save_strategy()


func _on_achievement_pressed() -> void:
	_services()._show_achievement_panel()


func _on_main_menu_pressed() -> void:
	_services()._open_main_menu()


## 快速保存
func _on_quick_save_pressed() -> void:
	_services()._quick_save()


## 快速读取
func _on_quick_load_pressed() -> void:
	_services()._quick_load()
