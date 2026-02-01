extends Control
class_name KND_DialogueBox

## 对话框模板
## 可以自定义设置画面显示内容、位置、尺寸

## 点击对话框
signal on_dialogue_click 
signal on_button_pressed
signal on_character_name_click

## 打字完成
signal typing_completed

## 角色对象
@export_group("名字")
@export var character_name : String = "" :
	set(value):
		character_name = value
		update_dialogue()
			
@export var name_size :int=32              ## 名字字体大小
@export var name_bg :Texture2D              ## 名字标签背景
@export var name_color :Color = Color.BLACK ## 名字颜色

## 对话内容
@export_group("对话文本设置")
@export var dialogue_text : String= "":
	set(value):
		dialogue_text = value
		update_dialogue_content()

## 打字间隔（单字符）
@export var typing_interval: float = 0.04:
	set(value):
		typing_interval = value
		update_dialogue_content()
		
@export_group("打字音效配置")
@export var enable_typing_effect_audio: bool = true
@export var typing_effect_audio: AudioStream
@export var audio_trigger_chance: float = 0.8  ## 音效触发概率(0-1)，1=每次必播，0=不播
@export var min_audio_interval: float = 0.02   ## 音效最小播放间隔（秒），适配滴滴声快速节奏
@export var max_audio_interval: float = 0.08   ## 音效最大播放间隔（秒）
@export var audio_volumn: float = 1.0         ## 音效音量(0-1)

@export_group("对话框设置")
@export var dialogue_margins :int = 100     ## 对话框到底部距离
@export var dialogue_bg :Texture2D          ## 对话框背景
@export var dialogue_color :Color = Color.BLACK ## 对话文字颜色
@export var dialogue_hight_max :int = 300  ## 对话文本框最大高度

@export_group("按钮")
@export var button_show :bool =false
@export var button_text:String =""
@export var button_texture :Texture2D


# 动态音频播放器
@onready var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()
# 音效状态变量 - 记录上一次播放时间、当前随机间隔
var last_audio_play_time: float = 0.0
var current_random_interval: float = 0.0

## 加载节点
@onready var character_name_label: Label = %character_name_label
@onready var dialogue_label: RichTextLabel = %dialogue_label
@onready var progress_bar: TextureProgressBar = %ProgressBar
@onready var next_button: Button = %Button
@onready var dialogue_box_bg: NinePatchRect = %dialogue_box_bg

var typing_tween: Tween = null


func _ready() -> void:
	if enable_typing_effect_audio:
		# 将音频播放器添加为子节点，自动完成初始化
		add_child(audio_player)
		audio_player.name = "TypingAudioPlayer"
		# 绑定滴滴音效资源
		audio_player.stream = typing_effect_audio
		# 设置音量，关闭自动播放
		audio_player.volume_db = linear_to_db(audio_volumn)
		audio_player.autoplay = false

		# 初始化随机间隔
		current_random_interval = randf_range(min_audio_interval, max_audio_interval)
		

## 更新对话框
func update_dialogue():
	if not is_inside_tree():
		return
	update_character_name()
	update_dialogue_content()
	
func update_character_name() -> void:
	if not is_inside_tree():
		return
	character_name_label.text = character_name
	character_name_label.label_settings.font_size = name_size
	character_name_label.label_settings.font_color = name_color
	
func update_dialogue_content() -> void:
	if next_button:
		next_button.hide()
	if not is_inside_tree() or dialogue_text.is_empty():
		return
	dialogue_label.visible_ratio = 0
	dialogue_label.text = dialogue_text
	await get_tree().process_frame
	
	# 计算文本高度并限制最大值
	var text_hight:int = dialogue_label.get_content_height()
	dialogue_label.size.y = min(text_hight, dialogue_hight_max)
	dialogue_label.position.y = size.y - dialogue_label.size.y - dialogue_margins
	# 适配对话框背景位置和尺寸
	dialogue_box_bg.position.y = dialogue_label.position.y - 150
	dialogue_box_bg.size.y = dialogue_label.size.y + 200
	
	# 停止原有打字动画
	if typing_tween != null and typing_tween.is_running():
		typing_tween.kill()
	# 重置音效状态 - 重新打字时从头计算间隔
	last_audio_play_time = 0.0
	current_random_interval = randf_range(min_audio_interval, max_audio_interval)
	
	# 创建新的打字动画
	typing_tween = get_tree().create_tween()
	typing_tween.finished.connect(func(): 
		typing_completed.emit())
	# 优化：按**字符数**计算总时长
	var total_typing_time = dialogue_text.length() * typing_interval
	typing_tween.tween_property(dialogue_label, "visible_ratio", 1.0, total_typing_time).set_trans(Tween.TRANS_LINEAR)

# 【核心新增】帧检测 - 实时判断并随机播放滴滴音效
func _process(delta: float) -> void:
	# 仅当打字动画运行、文本非空时，处理音效逻辑
	if not (typing_tween and typing_tween.is_running() and not dialogue_text.is_empty()):
		return
	
	# 获取当前运行时间（秒），用于计算时间间隔
	var current_time = Time.get_unix_time_from_system()
	# 距离上一次播放音效的时间差
	var time_since_last_play = current_time - last_audio_play_time
	
	if enable_typing_effect_audio:
		if time_since_last_play > current_random_interval and randf() < audio_trigger_chance and dialogue_label.visible_ratio < 0.98:
			# 防重叠：播放前先停止上一次音效（避免滴滴声叠加变吵）
			audio_player.stop()
			audio_player.play()
			# 更新上一次播放时间
			last_audio_play_time = current_time
			# 重新生成随机间隔（每次播放后更新，保证间隔不重复）
			current_random_interval = randf_range(min_audio_interval, max_audio_interval)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		on_dialogue_click.emit()

func _on_button_pressed() -> void:
	on_button_pressed.emit()

func _on_character_name_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		on_character_name_click.emit()
