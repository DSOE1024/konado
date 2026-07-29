extends SceneTree

const SCRIPT_PATH := "res://tests/editor/fixtures/native_editor.ks"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var shot := ResourceLoader.load(SCRIPT_PATH) as KND_Shot
	if shot == null:
		push_error("KonadoScript runtime loader could not load %s" % SCRIPT_PATH)
		quit(1)
		return
	if shot.ks_path != SCRIPT_PATH or shot.dialogues.is_empty():
		push_error("KonadoScript runtime loader returned incomplete compiled data")
		quit(1)
		return
	print("PASS: KonadoScript runtime loader test")
	quit()
