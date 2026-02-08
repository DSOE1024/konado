extends Logger
class_name KND_Logger

## Konado Logger，Konado日志记录器

const LOG_FILE_PATH: String = "user://konado_log.log"

signal error_caught(msg: String)
signal message_caught(msg: String, error: bool)	

static var _mutex := Mutex.new()

static var _error_type_name := ClassDB.class_get_enum_constants("Logger", "ErrorType")	

func _log_error(
	function: String, 
	file: String, 
	line: int, 
	code: String, 
	rationale: String, 
	editor_notify: bool, 
	error_type: int, 
	script_backtraces: Array[ScriptBacktrace]
) -> void:
	
	_mutex.lock()
	
	var sb := PackedStringArray()
	sb.append("Something's broken in Konado!")
	sb.append("=============================")
	sb.append("  Timestamp: " + Time.get_datetime_string_from_system())
	sb.append("  Function: {0}".format([function]))
	sb.append("  File Path: {0}".format([file]))
	sb.append("  Line Number: {0}".format([line]))
	sb.append("  Error Code: {0}".format([code]))
	sb.append("  Reason: {0}".format([rationale]))
	sb.append("  Editor Notify: {0}".format(["YES" if editor_notify else "NO"]))
	sb.append("  Error Type: {0}".format([_error_type_name[error_type] if error_type < _error_type_name.size() else "UNKNOWN"]))
	if script_backtraces.size() > 0:
		sb.append("=============================")
		sb.append("  script backtraces:")
		for i in script_backtraces:
			if i.format().find("res://addons/konado") != -1:
				sb.append("      " + i.format())
				var msg = "\n".join(sb)
				var filestream = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
				filestream.store_string(msg)
				filestream.close()
				error_caught.emit(msg)
	
	_mutex.unlock()

func _log_message(message: String, error: bool) -> void:
	_mutex.lock()
	
	message_caught.emit(message, error)
	
	_mutex.unlock()
