extends RefCounted
class_name KonadoRuntimeFailureReporter

## Builds and publishes the canonical runtime failure payload.
##
## Execution ownership and cancellation stay in KonadoDialogueManager; this
## object only snapshots immutable provenance and performs the single final log.


static func capture_context(host: Node, instruction: KonadoInstruction) -> Dictionary:
	return {
		"instruction_id": instruction.stable_key() if instruction != null else "",
		"source_line": instruction.source_line() if instruction != null else -1,
		"program_counter": instruction.pc if instruction != null else KonadoProgram.INVALID_PC,
		"opcode": KonadoOpcode.name_of(instruction.opcode()) if instruction != null else "",
		"source_path": _source_path(host),
	}


static func publish(
	host: Node, failure: KonadoExecutionFailure, instruction_context: Dictionary
) -> void:
	var report := failure.to_dictionary()
	for context_key in instruction_context:
		report[context_key] = instruction_context[context_key]
	var key := String(report.get("instruction_id", ""))
	var line := int(report.get("source_line", -1))
	var source_path := String(report.get("source_path", ""))
	var location := "%s:%d" % [source_path, line]
	push_error(
		(
			"Konado [%s]: %s (%s，指令=%s)"
			% [String(failure.code), failure.console_message(), location, key]
		)
	)
	host.runtime_failure_reported.emit(report.duplicate(true))
	host.runtime_failed.emit(failure.message, key, line)


static func _source_path(host: Node) -> String:
	if host.current_shot == null:
		return ""
	if host.current_shot.program != null:
		return host.current_shot.program.source_path
	return host.current_shot.source_path
