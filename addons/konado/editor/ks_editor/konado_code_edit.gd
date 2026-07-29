@tool
extends CodeEdit
class_name KonadoCodeEdit

signal save_requested
signal close_requested
signal find_requested(show_replace: bool)
signal goto_line_requested

const COMPLETION_DELAY := 0.08

var _completion_timer: Timer


func _ready() -> void:
	code_completion_enabled = true
	code_completion_prefixes = [" ", '"', "%", "$"]

	clear_string_delimiters()
	add_string_delimiter('"', '"', false)
	set_syntax_highlighter(load("res://addons/konado/editor/ks_editor/highlighter.tres"))

	_completion_timer = Timer.new()
	_completion_timer.one_shot = true
	_completion_timer.wait_time = COMPLETION_DELAY
	_completion_timer.timeout.connect(request_code_completion)
	add_child(_completion_timer)
	text_changed.connect(_schedule_completion)


func _schedule_completion() -> void:
	if not editable or _completion_timer == null:
		return
	_completion_timer.start()


func _request_code_completion(_force: bool) -> void:
	var line := get_caret_line()
	var column := get_caret_column()
	var line_prefix := get_line(line).left(column)
	var candidates := _get_completion_candidates(line_prefix)

	cancel_code_completion()
	for candidate: Dictionary in candidates:
		add_code_completion_option(
			candidate.get("kind", CodeCompletionKind.KIND_PLAIN_TEXT),
			candidate["text"],
			candidate.get("insert_text", candidate["text"]),
			candidate.get("color", Color.WHITE),
			null,
			candidate.get("value", null),
			CodeCompletionLocation.LOCATION_LOCAL
		)
	update_code_completion_options(false)


func _get_completion_candidates(line_prefix: String) -> Array[Dictionary]:
	var stripped := line_prefix.strip_edges()
	var candidates: Array[Dictionary] = []
	var ends_with_space := line_prefix.ends_with(" ") or line_prefix.ends_with("\t")
	var tokens := stripped.replace("\t", " ").split(" ", false)
	if tokens.is_empty():
		candidates = _make_candidates(KS_LanguageCatalog.ROOT_KEYWORDS, "")
	else:
		var root_keyword := tokens[0]
		var partial := "" if ends_with_space else tokens[-1]
		var context_values := KS_LanguageCatalog.get_context_completions(root_keyword)
		if stripped.is_empty():
			candidates = _make_candidates(KS_LanguageCatalog.ROOT_KEYWORDS, "")
		elif tokens.size() == 1 and not ends_with_space:
			candidates = _make_candidates(KS_LanguageCatalog.ROOT_KEYWORDS, root_keyword)
		elif (
			not context_values.is_empty()
			and (
				(tokens.size() == 1 and ends_with_space)
				or (tokens.size() == 2 and not ends_with_space)
			)
		):
			candidates = _make_candidates(context_values, partial)
		elif (
			root_keyword == "background"
			and tokens.size() >= 2
			and (tokens.size() >= 3 or ends_with_space)
		):
			candidates = _make_candidates(KS_LanguageCatalog.get_background_effects(), partial)
		elif root_keyword in ["jump_branch", "choice"]:
			candidates = _make_candidates(_collect_branch_names(), partial)
		elif root_keyword == "actor" and tokens.size() >= 2:
			var actor_action := tokens[1]
			if (
				actor_action == "show"
				and (
					(tokens.size() == 4 and ends_with_space)
					or (tokens.size() == 5 and not ends_with_space)
				)
			):
				candidates = _make_candidates(PackedStringArray(["at"]), partial)
			elif actor_action in ["exit", "change", "move", "motion"]:
				candidates = _make_candidates(_collect_actor_names(), partial)
		elif root_keyword in ["set", "add", "sub", "mul", "div", "if"]:
			candidates = _make_candidates(_collect_variable_names(), partial)
	return candidates


func _make_candidates(values: PackedStringArray, partial: String) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var normalized_partial := partial.to_lower()
	for value: String in values:
		if (
			not normalized_partial.is_empty()
			and not value.to_lower().begins_with(normalized_partial)
		):
			continue
		(
			candidates
			. append(
				{
					"kind": CodeCompletionKind.KIND_KEYWORD,
					"text": value,
					"insert_text": value,
					"color": Color(0.85, 0.72, 1.0),
				}
			)
		)
	return candidates


func _collect_branch_names() -> PackedStringArray:
	return _collect_matches("(?m)^\\s*branch\\s+([\\p{L}_][\\p{L}\\p{N}_-]*)")


func _collect_actor_names() -> PackedStringArray:
	return _collect_matches("(?m)^\\s*actor\\s+show\\s+([\\p{L}_][\\p{L}\\p{N}_-]*)")


func _collect_variable_names() -> PackedStringArray:
	return _collect_matches("(?m)(?:%|\\$)([\\p{L}_][\\p{L}\\p{N}_]*)", true)


func _collect_matches(pattern: String, include_prefix: bool = false) -> PackedStringArray:
	var values := PackedStringArray()
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return values
	for match_result: RegExMatch in regex.search_all(text):
		var value := match_result.get_string(0) if include_prefix else match_result.get_string(1)
		if include_prefix:
			var prefix_position := maxi(value.find("%"), value.find("$"))
			value = value.substr(prefix_position)
		if not values.has(value):
			values.append(value)
	values.sort()
	return values


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var command_pressed := key_event.ctrl_pressed or key_event.meta_pressed
	if not command_pressed:
		return

	match key_event.keycode:
		KEY_S:
			save_requested.emit()
			accept_event()
		KEY_W:
			close_requested.emit()
			accept_event()
		KEY_F:
			find_requested.emit(key_event.meta_pressed and key_event.alt_pressed)
			accept_event()
		KEY_H:
			if key_event.ctrl_pressed and not key_event.meta_pressed:
				find_requested.emit(true)
				accept_event()
		KEY_L:
			goto_line_requested.emit()
			accept_event()
