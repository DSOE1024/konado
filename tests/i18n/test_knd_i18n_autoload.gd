extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := root.get_node_or_null("KND_I18n")
	var settings := root.get_node_or_null("KND_Settings")
	_expect(service != null, "KND_I18n autoload exists")
	_expect(settings != null, "KND_Settings autoload exists")
	if service == null or settings == null:
		_finish()
		return

	for _frame in range(10):
		if service.is_initialized():
			break
		await process_frame

	_expect(service.is_initialized(), "KND_I18n initializes after all autoloads are ready")
	var saved_locale: String = service.normalize_locale(
		str(settings.get_setting("display", "language"))
	)
	_expect_equal(service.get_locale(), saved_locale, "runtime locale matches persisted settings")
	_expect_equal(
		TranslationServer.get_locale(),
		service.get_locale(),
		"TranslationServer matches the runtime locale"
	)
	for locale: String in ["zh_Hans", "zh_Hant", "en", "ja", "ko"]:
		_expect(
			locale in service.get_available_locales(), "built-in locale is available: " + locale
		)
		_expect(
			service.get_builtin_translation(locale) != null,
			"built-in translation is loaded: " + locale
		)
	_finish()


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
	if _failures == 0:
		print("PASS: KND_I18n autoload integration tests")
	quit(_failures)
