extends Node

## 是否启用 Web 开发者工具快捷键放行
@export var enable_web_devtool: bool = true

## F12：打开开发者工具
@export var enable_f12: bool = true
## F5：刷新页面
@export var enable_f5: bool = true
## F11：全屏切换
@export var enable_f11: bool = true
## Ctrl+Shift+I (Win/Linux) / Cmd+Opt+I (Mac)：打开元素面板
@export var enable_ctrl_shift_i: bool = true
## Ctrl+Shift+J (Win/Linux) / Cmd+Opt+J (Mac)：打开控制台
@export var enable_ctrl_shift_j: bool = true
## Ctrl+Shift+C (Win/Linux) / Cmd+Shift+C (Mac)：检查元素模式
@export var enable_ctrl_shift_c: bool = true
## Ctrl+U (Win/Linux) / Cmd+U (Mac)：查看页面源码
@export var enable_ctrl_u: bool = true
## Ctrl+R (Win/Linux) / Cmd+R (Mac)：刷新页面
@export var enable_ctrl_r: bool = true


func _ready() -> void:
	if enable_web_devtool and OS.has_feature("web"):
		_inject_web_shortcut_handler()


func _inject_web_shortcut_handler() -> void:
	JavaScriptBridge.eval("""
		(function() {
			if (window.__konado_devtool_injected) return;
			window.__konado_devtool_injected = true;

			// 根据当前配置动态构建快捷键列表
			var shortcuts = [];
	""" + _build_shortcuts_js_array() + """

			document.addEventListener('keydown', function(e) {
				for (var i = 0; i < shortcuts.length; i++) {
					var s = shortcuts[i];
					var keyMatch = e.key === s.key || e.keyCode === s.keyCode;
					if (!keyMatch) continue;

					var ctrlMatch = s.ctrl ? (e.ctrlKey || e.metaKey) : true;
					var shiftMatch = s.shift ? e.shiftKey : true;

					if (ctrlMatch && shiftMatch) {
						e.stopImmediatePropagation();
						return;
					}
				}
			}, true);
		})();
	""")


func _build_shortcuts_js_array() -> String:
	var items: Array[String] = []
	
	if enable_f12:
		items.append("{ key: 'F12', keyCode: 123 }")
	if enable_f5:
		items.append("{ key: 'F5', keyCode: 116 }")
	if enable_f11:
		items.append("{ key: 'F11', keyCode: 122 }")
	if enable_ctrl_shift_i:
		items.append("{ key: 'I', keyCode: 73, ctrl: true, shift: true }")
	if enable_ctrl_shift_j:
		items.append("{ key: 'J', keyCode: 74, ctrl: true, shift: true }")
	if enable_ctrl_shift_c:
		items.append("{ key: 'C', keyCode: 67, ctrl: true, shift: true }")
	if enable_ctrl_u:
		items.append("{ key: 'U', keyCode: 85, ctrl: true }")
	if enable_ctrl_r:
		items.append("{ key: 'R', keyCode: 82, ctrl: true }")
	
	if items.is_empty():
		return "// No shortcuts enabled"
	else:
		return "shortcuts = [" + ", ".join(items) + "];"
