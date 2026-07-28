extends SceneTree

const SERVICE_PATH := "res://addons/konado/i18n/knd_i18n.gd"

var _failures := 0
var _service: Node


class FakeSettings:
	extends Node

	signal setting_changed(category: String, key: String, value: Variant)

	var values := {"display": {"language": "tc"}}
	var set_calls: Array[Array] = []

	func get_setting(category: String, key: String) -> Variant:
		return values.get(category, {}).get(key)

	func set_setting(category: String, key: String, value: Variant) -> void:
		if not values.has(category):
			values[category] = {}
		values[category][key] = value
		set_calls.append([category, key, value])
		setting_changed.emit(category, key, value)


class FakeDialogueManager:
	extends Node

	var reloaded_locales: Array[String] = []

	func reload_localized_script(locale: String) -> bool:
		reloaded_locales.append(locale)
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service_script := load(SERVICE_PATH)
	_expect(service_script != null, "KND_I18n service script should exist")
	if service_script == null:
		_finish()
		return
	_expect(service_script.can_instantiate(), "KND_I18n service script should compile")
	if not service_script.can_instantiate():
		_finish()
		return

	var service: Node = service_script.new()
	_service = service
	root.add_child(service)
	var required_methods := [
		"normalize_locale",
		"get_script_candidates",
		"choose_initial_locale",
		"set_locale",
		"get_locale",
		"get_available_locales",
		"register_translation",
		"unregister_translation",
		"initialize",
		"is_initialized",
		"resolve_script_path",
		"load_localized_script",
		"register_dialogue_manager",
		"unregister_dialogue_manager",
		"choose_restore_node_id",
		"get_builtin_translation",
	]
	for method: String in required_methods:
		_expect(service.has_method(method), "KND_I18n should expose %s()" % method)
	if _failures > 0:
		_finish()
		return
	_test_locale_normalization(service)
	_test_legacy_locale_migration(service)
	_test_script_candidates(service)
	_test_initial_locale_selection(service)
	_test_initialization_lifecycle(service)
	_test_custom_translation_registration(service)
	_test_runtime_locale_change(service)
	_test_settings_integration(service)
	_test_script_resolution(service)
	_test_localized_script_loading(service)
	_test_dialogue_manager_notifications(service)
	_test_restore_node_selection(service)
	_test_real_dialogue_manager_reload(service)
	_test_builtin_ui_translations(service)
	_test_demo_localized_scripts(service)
	_finish()


func _test_locale_normalization(service: Node) -> void:
	_expect_equal(service.normalize_locale("zh-CN"), "zh_Hans", "zh-CN maps to simplified Chinese")
	_expect_equal(service.normalize_locale("zh_SG"), "zh_Hans", "zh_SG maps to simplified Chinese")
	_expect_equal(service.normalize_locale("zh-TW"), "zh_Hant", "zh-TW maps to traditional Chinese")
	_expect_equal(service.normalize_locale("zh_HK"), "zh_Hant", "zh_HK maps to traditional Chinese")
	_expect_equal(
		service.normalize_locale("zh-Hans-CN"),
		"zh_Hans",
		"Hans script locale maps to simplified Chinese"
	)
	_expect_equal(
		service.normalize_locale("zh-Hant-HK"),
		"zh_Hant",
		"Hant script locale maps to traditional Chinese"
	)
	_expect_equal(
		service.normalize_locale("pt-br"), "pt_BR", "arbitrary locales keep a canonical region"
	)


func _test_legacy_locale_migration(service: Node) -> void:
	_expect_equal(service.normalize_locale("zh"), "zh_Hans", "legacy zh maps to zh_Hans")
	_expect_equal(service.normalize_locale("tc"), "zh_Hant", "legacy tc maps to zh_Hant")


func _test_script_candidates(service: Node) -> void:
	_expect_equal(
		service.get_script_candidates("res://story/chapter1.ks", "zh_Hans"),
		PackedStringArray(
			[
				"res://story/chapter1.zh_Hans.ks",
				"res://story/chapter1.zh.ks",
				"res://story/chapter1.ks",
			]
		),
		"script candidates use full locale, base language, then original"
	)
	_expect_equal(
		service.get_script_candidates("res://story/chapter1.en.ks", "ja"),
		PackedStringArray(
			[
				"res://story/chapter1.ja.ks",
				"res://story/chapter1.ks",
			]
		),
		"an already localized path is resolved from its base name"
	)
	_expect_equal(
		service.get_script_candidates("res://story/chapter.one.ks", "en"),
		PackedStringArray(
			[
				"res://story/chapter.one.en.ks",
				"res://story/chapter.one.ks",
			]
		),
		"a three-letter filename suffix is not mistaken for a locale"
	)
	_expect_equal(
		service.get_script_candidates("res://story/chapter.v1.ks", "en"),
		PackedStringArray(
			[
				"res://story/chapter.v1.en.ks",
				"res://story/chapter.v1.ks",
			]
		),
		"a two-character filename suffix must be an alphabetic locale"
	)
	_expect_equal(
		service.get_script_candidates("res://story/chapter", "en"),
		PackedStringArray(
			[
				"res://story/chapter.en",
				"res://story/chapter",
			]
		),
		"extensionless paths do not gain a trailing dot"
	)


func _test_initial_locale_selection(service: Node) -> void:
	_expect_equal(
		service.choose_initial_locale("", "ja_JP"), "ja", "supported system language is selected"
	)
	_expect_equal(
		service.choose_initial_locale("", "fr_FR"),
		"zh_Hans",
		"unsupported system language falls back"
	)
	_expect_equal(
		service.choose_initial_locale("zh-TW", "en_US"), "zh_Hant", "saved locale wins and migrates"
	)


func _test_initialization_lifecycle(service: Node) -> void:
	_expect(not service.is_initialized(), "service starts uninitialized before deferred setup")
	var initialized_locales: Array[String] = []
	service.initialized.connect(func(locale: String) -> void: initialized_locales.append(locale))
	var manager := FakeDialogueManager.new()
	var settings := FakeSettings.new()
	settings.values["display"]["language"] = ""
	service.register_dialogue_manager(manager)
	service.initialize(settings, "ja_JP")
	_expect(service.is_initialized(), "service reports initialized")
	_expect_equal(service.get_locale(), "ja", "system locale initializes the service")
	_expect_equal(initialized_locales, ["ja"], "initialized emits exactly once")
	_expect_equal(
		manager.reloaded_locales,
		["ja"],
		"managers registered before initialization receive the initial locale"
	)
	service.initialize(settings, "ja_JP")
	_expect_equal(initialized_locales, ["ja"], "repeated initialization is idempotent")
	_expect_equal(
		manager.reloaded_locales,
		["ja"],
		"repeated initialization does not reload an unchanged locale"
	)
	service.unregister_dialogue_manager(manager)
	manager.free()
	settings.free()


func _test_custom_translation_registration(service: Node) -> void:
	var translation := Translation.new()
	translation.locale = "fr-CA"
	translation.add_message("Konado custom locale test", "Traduction personnalisée")
	_expect(service.register_translation(translation), "custom translation registers")
	_expect(
		"fr_CA" in service.get_available_locales(),
		"custom locale is exposed through the locale catalog"
	)
	service.set_locale("fr_CA", false)
	_expect_equal(
		TranslationServer.translate("Konado custom locale test"),
		"Traduction personnalisée",
		"custom translation participates in Godot translation"
	)
	_expect(service.unregister_translation("fr-CA"), "custom translation unregisters")
	_expect(
		"fr_CA" not in service.get_available_locales(),
		"unregistered custom locale leaves the locale catalog"
	)
	var override := Translation.new()
	override.locale = "en"
	override.add_message("保存进度", "Custom save")
	_expect(service.register_translation(override), "built-in locale can be overridden")
	service.set_locale("en", false)
	_expect_equal(
		TranslationServer.translate("保存进度"),
		"Custom save",
		"custom translation overrides a built-in locale"
	)
	_expect(service.unregister_translation("en"), "built-in override unregisters")
	service.set_locale("en", false)
	_expect_equal(
		TranslationServer.translate("保存进度"),
		"Save",
		"unregistering an override restores the built-in translation"
	)
	service.set_locale("ja", false)


func _test_runtime_locale_change(service: Node) -> void:
	var emitted: Array[String] = []
	service.locale_changed.connect(func(locale: String) -> void: emitted.append(locale))
	service.set_locale("fr-CA", false)
	_expect_equal(service.get_locale(), "fr_CA", "developer-defined locale can be selected")
	_expect_equal(TranslationServer.get_locale(), "fr_CA", "Godot TranslationServer stays in sync")
	_expect_equal(emitted, ["fr_CA"], "locale_changed emits the canonical locale once")
	TranslationServer.set_locale("en")
	service.set_locale("fr-CA", false)
	_expect_equal(
		TranslationServer.get_locale(),
		"fr_CA",
		"setting the current locale repairs external TranslationServer drift"
	)
	_expect_equal(
		emitted, ["fr_CA"], "repairing TranslationServer drift does not emit a false change"
	)


func _test_settings_integration(service: Node) -> void:
	var old_settings := FakeSettings.new()
	service.initialize(old_settings, "en_US")
	_expect_equal(service.get_locale(), "zh_Hant", "legacy saved setting initializes the locale")
	_expect_equal(
		old_settings.values["display"]["language"],
		"zh_Hant",
		"legacy setting is migrated in storage"
	)
	_expect_equal(old_settings.set_calls.size(), 1, "legacy migration persists only once")

	var settings := FakeSettings.new()
	settings.values["display"]["language"] = "en"
	service.initialize(settings, "zh_Hans")
	old_settings.set_setting("display", "language", "ja")
	_expect_equal(
		service.get_locale(), "en", "reinitialization disconnects the previous settings source"
	)
	settings.set_setting("display", "language", "ja")
	_expect_equal(service.get_locale(), "ja", "the current settings source controls the locale")
	service.set_locale("ko")
	_expect_equal(
		settings.values["display"]["language"], "ko", "locale changes persist through KND_Settings"
	)
	old_settings.free()
	settings.free()


func _test_script_resolution(service: Node) -> void:
	_expect_equal(
		service.resolve_script_path("res://tests/i18n/fixtures/story.ks", "zh_Hant"),
		"res://tests/i18n/fixtures/story.zh_Hant.ks",
		"resolver selects the full locale script"
	)
	_expect_equal(
		service.resolve_script_path("res://tests/i18n/fixtures/story.ks", "ko", false),
		"res://tests/i18n/fixtures/story.ks",
		"resolver falls back to the base script"
	)


func _test_localized_script_loading(service: Node) -> void:
	var shot: KND_Shot = service.load_localized_script(
		"res://tests/i18n/fixtures/story.ks", "zh_Hant"
	)
	_expect(shot != null, "localized script loader returns a KND_Shot")
	if shot != null:
		_expect_equal(
			shot.ks_path,
			"res://tests/i18n/fixtures/story.zh_Hant.ks",
			"localized shot retains its resolved source path"
		)


func _test_dialogue_manager_notifications(service: Node) -> void:
	var manager := FakeDialogueManager.new()
	service.register_dialogue_manager(manager)
	service.register_dialogue_manager(manager)
	service.set_locale("ja", false)
	_expect_equal(manager.reloaded_locales, ["ja"], "registered managers reload on locale change")
	service.unregister_dialogue_manager(manager)
	service.set_locale("en", false)
	_expect_equal(manager.reloaded_locales, ["ja"], "unregistered managers stop receiving changes")
	manager.free()


func _test_restore_node_selection(service: Node) -> void:
	var old_shot := _make_shot(["intro", "middle", "ending"], "intro")
	var translated_by_id := _make_shot(["intro", "middle", "ending"], "intro")
	_expect_equal(
		service.choose_restore_node_id(old_shot, translated_by_id, "middle"),
		"middle",
		"stable node ID is preferred"
	)
	var translated_by_index := _make_shot(["new_intro", "new_middle"], "new_intro")
	_expect_equal(
		service.choose_restore_node_id(old_shot, translated_by_index, "middle"),
		"new_middle",
		"matching index is used when the node ID changed"
	)
	var translated_from_start := _make_shot(["only"], "only")
	_expect_equal(
		service.choose_restore_node_id(old_shot, translated_from_start, "ending"),
		"only",
		"start node is used when the previous index is unavailable"
	)


func _test_real_dialogue_manager_reload(service: Node) -> void:
	var manager := KND_DialogueManager.new()
	_expect(
		manager.has_method("reload_localized_script"),
		"KND_DialogueManager should expose reload_localized_script()"
	)
	if not manager.has_method("reload_localized_script"):
		manager.free()
		return
	manager.set("_i18n_service", service)
	var base_shot: KND_Shot = service.load_localized_script(
		"res://tests/i18n/fixtures/story.ks", "ko", false
	)
	manager.start_dialogue_shot = base_shot
	manager.cur_dialogue_shot = base_shot.duplicate()
	manager.cur_node_id = base_shot.dialogues[1].node_id
	var previous_node_id: String = manager.cur_node_id
	var reloaded: bool = manager.reload_localized_script("zh_Hant")
	_expect(reloaded, "dialogue manager reload succeeds")
	_expect_equal(
		manager.cur_dialogue_shot.ks_path,
		"res://tests/i18n/fixtures/story.zh_Hant.ks",
		"dialogue manager swaps to the localized shot"
	)
	_expect_equal(
		manager.cur_node_id, previous_node_id, "dialogue manager preserves the stable node ID"
	)
	_expect_equal(
		manager.cur_dialogue_shot.find_node(manager.cur_node_id).dialog_content,
		"Traditional second line",
		"current dialogue content comes from the localized script"
	)
	manager.free()


func _test_builtin_ui_translations(service: Node) -> void:
	var message_keys := PackedStringArray(
		[
			"音频",
			"主音量",
			"调节游戏的整体音量",
			"音乐音量",
			"音效音量",
			"语音音量",
			"文本播放",
			"文字速度",
			"自动等待",
			"自动模式",
			"跳过已读",
			"跳过全部",
			"画面",
			"全屏",
			"语言",
			"调试模式",
			"游戏设置",
			"恢复默认",
			"关闭",
			"确定要将当前类别恢复为默认设置吗？",
			"简体中文",
			"繁體中文",
			"英语",
			"日语",
			"韩语",
			"成就",
			"重置所有成就",
			"未知",
			"此成就是隐藏的。",
			"%d 点",
			"已解锁",
			"未解锁",
			"成就解锁",
			"存档",
			"自动播放",
			"停止播放",
			"快速保存",
			"快速读取",
			"设置",
			"主菜单",
			"关闭界面",
			"删除存档",
			"读取存档",
			"保存进度",
			"空存档",
			"未知时间",
			"存档%02d",
			"开始游戏",
			"退出游戏",
			"Konado视觉小说插件 简要使用教程",
			"—— · Konado视觉小说插件 简要使用教程 · ——",
			"快速保存成功",
			"快速保存失败",
			"无快速存档可读取",
			"快速读取失败",
			"读取会失去未保存的进度。\n\n你确定要这么做吗？",
			"Skip this error...",
		]
	)
	var reference_translation: Translation = service.get_builtin_translation("zh_Hans")
	var reference_keys := reference_translation.get_message_list()
	reference_keys.sort()
	for locale: String in ["zh_Hans", "zh_Hant", "en", "ja", "ko"]:
		var translation: Translation = service.get_builtin_translation(locale)
		_expect(translation != null, "built-in translation exists for %s" % locale)
		if translation == null:
			continue
		_expect_equal(
			translation.locale, locale, "%s resource declares the correct locale" % locale
		)
		var translation_keys := translation.get_message_list()
		translation_keys.sort()
		_expect_equal(
			translation_keys,
			reference_keys,
			"%s has exactly the same message catalog as zh_Hans" % locale
		)
		for message_key: String in message_keys:
			_expect(
				not str(translation.get_message(message_key)).is_empty(),
				"%s contains %s" % [locale, message_key]
			)
	service.set_locale("en", false)
	_expect_equal(
		TranslationServer.translate("保存进度"), "Save", "runtime UI follows TranslationServer locale"
	)


func _test_demo_localized_scripts(service: Node) -> void:
	var expected_second_lines := {
		"zh_Hans": "和我一起用Konado做视觉小说吧！",
		"zh_Hant": "和我一起用 Konado 製作視覺小說吧！",
		"en": "Let's create a visual novel with Konado!",
		"ja": "Konadoで一緒にビジュアルノベルを作りましょう！",
		"ko": "Konado로 함께 비주얼 노벨을 만들어 봐요!",
	}
	var expected_node_count := -1
	for locale: String in expected_second_lines:
		var shot: KND_Shot = service.load_localized_script("res://sample/demo/demo_01.ks", locale)
		_expect(shot != null, "demo script loads for %s" % locale)
		if shot == null:
			continue
		_expect_equal(
			shot.ks_path,
			"res://sample/demo/demo_01.%s.ks" % locale,
			"demo resolves an independent script for %s" % locale
		)
		if expected_node_count < 0:
			expected_node_count = shot.dialogues.size()
		_expect_equal(
			shot.dialogues.size(),
			expected_node_count,
			"demo node structure matches for %s" % locale
		)
		var dialogue_lines: Array[String] = []
		for dialogue: KND_Dialogue in shot.dialogues:
			if dialogue.dialog_type == KND_Dialogue.Type.ORDINARY_DIALOG:
				dialogue_lines.append(dialogue.dialog_content)
		_expect_equal(
			dialogue_lines[1],
			expected_second_lines[locale],
			"demo dialogue is translated for %s" % locale
		)


func _make_shot(node_ids: Array[String], start_node_id: String) -> KND_Shot:
	var shot := KND_Shot.new()
	shot.start_node_id = start_node_id
	for node_id: String in node_ids:
		var dialogue := KND_Dialogue.new()
		dialogue.node_id = node_id
		shot.dialogues.append(dialogue)
	return shot


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: " + message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failures += 1
	printerr("FAIL: %s\n  expected: %s\n  actual:   %s" % [message, expected, actual])


func _finish() -> void:
	if is_instance_valid(_service):
		root.remove_child(_service)
		_service.free()
	if _failures == 0:
		print("PASS: KND_I18n core tests")
	quit(_failures)
