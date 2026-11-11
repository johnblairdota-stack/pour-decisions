## Shows the game's own errors on the screen. On a tablet there's no console
## to read, so when something goes wrong there (and only there) this is how
## anyone finds out what: the first few different errors, in small red type
## along the top, each with how many times it's happened. A screenshot of it
## is all a bug report needs.
## It's on by itself on a phone or tablet; `-- --errlog` turns it on anywhere.
extends CanvasLayer

class Catch extends Logger:
	var lines: Array = []
	var counts := {}
	var _m := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text := "%s:%d  %s()  %s  %s" % [file.get_file(), line, function, rationale, code]
		_m.lock()
		if counts.has(text):
			counts[text] = int(counts[text]) + 1
		else:
			counts[text] = 1
			if lines.size() < 10:
				lines.append(text)
		_m.unlock()

	func snapshot() -> Array:
		var out: Array = []
		_m.lock()
		for l in lines:
			out.append("%s   x%d" % [l, int(counts[l])])
		_m.unlock()
		return out

var _catch: Catch
var _label: Label
var _box: PanelContainer
var _t := 0.0
var _shown := 0

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_catch = Catch.new()
	OS.add_logger(_catch)
	_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.02, 0.02, 0.88)
	sb.set_content_margin_all(8)
	_box.add_theme_stylebox_override("panel", sb)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_box.visible = false
	add_child(_box)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color("ff8d85"))
	_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_label)

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var rows := _catch.snapshot()
	if rows.is_empty():
		return
	_box.visible = true
	_label.text = "GAME ERRORS (screenshot this for a bug report)\n" + "\n".join(rows)
	if rows.size() != _shown:
		_shown = rows.size()
		# (and kept in a file beside the game, where it can be)
		var f := FileAccess.open("res://tools/_errors_seen.txt", FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(rows) + "\n")
			f.close()
