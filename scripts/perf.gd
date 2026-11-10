extends CanvasLayer
## The frame-rate readout and the benchmark: what the game costs to draw on
## this machine, so a change to the visuals can be measured before and after
## on the PC and on the tablet instead of guessed at.
##
##   F4, or Settings > Frame rate readout
##       a small panel, bottom right: frames a second now, the frame time,
##       what's being drawn, and a summary of the last full minute. Each
##       minute's summary is also written to user://perf_log.txt.
##   -- --autotest --nophones --bench[=seconds] [--startlevel=N]
##       an all-bot crew pours while it measures that many seconds of the
##       pour (60 if not given), prints one "[bench]" line and quits.
##
##   --benchoff=shadows,msaa,glow,labels,particles,hud,views,world
##       with --bench: switches those parts off as the pour starts, to see
##       what each one costs (views = the split-screen and close-up cameras,
##       world = everything beyond the site: streets, trees, traffic, river).
##
## The [bench] line also splits the frame: "script" is the game's own code,
## "draw cpu" is the engine getting the frame ready, "gpu" is the graphics
## card drawing it. Paused frames aren't counted. "low" is the 1% low: the frame rate of the
## slowest one frame in a hundred, which is what a stutter feels like.

const UI := preload("res://scripts/ui.gd")

const WINDOW := 60.0     # s in a summary
const REFRESH := 0.5     # s between updates of the numbers on screen
const LOG := "user://perf_log.txt"

var game
var on := false
var bench_secs := -1.0   # s of pour to measure, -1 when not benchmarking

var _panel: PanelContainer
var _label: Label
var _ms := PackedFloat32Array()   # this window's frame times
var _win_t := 0.0
var _recent := PackedFloat32Array()
var _recent_t := 0.0
var _prev_us := 0
var _last := ""
var _off: PackedStringArray = []   # --benchoff
var _off_done := false
var _views: Array = []             # viewport RIDs being timed
var _views_t := 0.0
var _cost := Vector3.ZERO          # summed ms: script, draw cpu, gpu
const WORLD := ["surrounds", "neighbours", "flora", "fences", "wildlife", "cars", "people", "street", "water", "citycat", "yard"]

func setup(owner_game) -> void:
	game = owner_game
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = UI.panel(UI.GLASS_SOLID, 10, UI.EDGE, 1, Vector4(12, 6, 12, 8))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	UI.place(_panel, Vector2(1, 1), Vector2(-16, -16))
	_label = UI.label("", 20, UI.WHITE, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_label)
	_panel.visible = false
	for arg in OS.get_cmdline_user_args():
		if arg == "--bench":
			bench_secs = WINDOW
		elif arg.begins_with("--bench="):
			bench_secs = maxf(5.0, float(arg.substr(8)))
		elif arg.begins_with("--benchoff="):
			_off = arg.substr(11).split(",", false)
	if bench_secs > 0.0:
		on = true
		_panel.visible = true

func toggle() -> void:
	on = not on
	_panel.visible = on
	_reset()
	_find_views()
	_last = ""

func _reset() -> void:
	_ms.clear()
	_win_t = 0.0
	_recent.clear()
	_recent_t = 0.0
	_prev_us = 0
	_cost = Vector3.ZERO
	_views_t = 0.0

## Every viewport that's drawing (the split screen and the close-ups have
## their own), timed by the engine while the readout's on.
func _find_views() -> void:
	for rid in _views:
		RenderingServer.viewport_set_measure_render_time(rid, false)
	_views.clear()
	if not on:
		return
	var all: Array = [get_viewport()]
	all.append_array(get_tree().root.find_children("*", "SubViewport", true, false))
	for v in all:
		if v is SubViewport and (v as SubViewport).render_target_update_mode == SubViewport.UPDATE_DISABLED:
			continue
		var rid: RID = (v as Viewport).get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(rid, true)
		_views.append(rid)

## Dev: switch parts of the picture off, to weigh them.
func _apply_off() -> void:
	_off_done = true
	if _off.is_empty() or game == null:
		return
	var root := get_tree().root
	if "shadows" in _off:
		for l in root.find_children("*", "Light3D", true, false):
			(l as Light3D).shadow_enabled = false
	if "msaa" in _off:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		for v in root.find_children("*", "SubViewport", true, false):
			(v as SubViewport).msaa_3d = Viewport.MSAA_DISABLED
	if "glow" in _off and game.env != null:
		game.env.glow_enabled = false
	if "labels" in _off:
		for l in root.find_children("*", "Label3D", true, false):
			(l as Node3D).visible = false
	if "particles" in _off:
		for q in root.find_children("*", "CPUParticles3D", true, false):
			(q as CPUParticles3D).emitting = false
			(q as Node3D).visible = false
	if "hud" in _off:
		game.hud_off = true
	if "views" in _off:
		for v in root.find_children("*", "SubViewport", true, false):
			(v as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	if "world" in _off:
		for n in root.find_children("*", "Node", true, false):
			var sc = n.get_script()
			if sc != null and sc.resource_path.get_file().get_basename() in WORLD:
				n.process_mode = Node.PROCESS_MODE_DISABLED
				if n is Node3D:
					(n as Node3D).visible = false
	print("[bench] switched off: %s" % ", ".join(_off))

func _process(_delta: float) -> void:
	if not on:
		return
	var now := Time.get_ticks_usec()
	var first := _prev_us == 0
	var ms := (now - _prev_us) / 1000.0
	_prev_us = now
	if first or get_tree().paused or ms > 2000.0:
		return   # (a pause, or a hitch from the window being dragged: not the game)
	# The benchmark only counts the pour itself
	if bench_secs > 0.0 and (game == null or game.phase != "pour"):
		return
	if bench_secs > 0.0 and not _off_done:
		_apply_off()
	_views_t -= ms / 1000.0
	if _views_t <= 0.0:
		_views_t = 2.0
		_find_views()
	var cpu := RenderingServer.get_frame_setup_time_cpu()
	var gpu := 0.0
	for rid in _views:
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	_cost += Vector3(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, cpu, gpu)
	_ms.append(ms)
	_win_t += ms / 1000.0
	_recent.append(ms)
	_recent_t += ms / 1000.0
	if _recent_t >= REFRESH:
		_show()
		_recent.clear()
		_recent_t = 0.0
	if _win_t >= (bench_secs if bench_secs > 0.0 else WINDOW):
		var s := summary(_ms)
		var c := _cost / maxf(1.0, float(_ms.size()))
		s["script"] = c.x
		s["cpu"] = c.y
		s["gpu"] = c.z
		_last = "last %d s: avg %d · low %d fps" % [int(round(_win_t)), int(round(s["avg"])), int(round(s["low"]))]
		_write(s)
		if bench_secs > 0.0:
			print("[bench] %s" % _line(s))
			get_tree().quit(0)
			return
		_ms.clear()
		_win_t = 0.0
		_cost = Vector3.ZERO

## Average and 1% low frame rate, and the worst frame, of a run of frame times (ms).
static func summary(ms: PackedFloat32Array) -> Dictionary:
	if ms.is_empty():
		return {"avg": 0.0, "low": 0.0, "worst": 0.0, "frames": 0}
	var sorted := ms.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += v
	var slow: float = sorted[mini(sorted.size() - 1, int(floor(sorted.size() * 0.99)))]
	return {"avg": 1000.0 * sorted.size() / total, "low": 1000.0 / maxf(slow, 0.001), "worst": sorted[sorted.size() - 1], "frames": sorted.size()}

func _show() -> void:
	var s := summary(_recent)
	var draws := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var tris := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var text := "%d fps · %.1f ms · worst %.0f ms\n%d draws · %s tris" % [int(round(s["avg"])), 1000.0 / maxf(s["avg"], 0.001), s["worst"], draws, _short(tris)]
	if bench_secs > 0.0:
		text += "\nbenchmark: %d of %d s" % [int(_win_t), int(bench_secs)]
	elif _last != "":
		text += "\n" + _last
	else:
		text += "\nfirst summary in %d s" % int(ceil(WINDOW - _win_t))
	_label.text = text

static func _short(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 1000:
		return "%dk" % int(round(n / 1000.0))
	return str(n)

func _line(s: Dictionary) -> String:
	var size := get_viewport().get_visible_rect().size
	var where := "level %d %s" % [game.k + 1, game.phase] if game != null else ""
	return "%s | avg %.1f fps | 1%% low %.1f fps | worst %.0f ms | script %.1f ms, draw cpu %.1f ms, gpu %.1f ms | %d frames in %.0f s | %s | %dx%d | %s, %s | %s" % [
		Time.get_datetime_string_from_system(false, true), s["avg"], s["low"], s["worst"], s.get("script", 0.0), s.get("cpu", 0.0), s.get("gpu", 0.0), s["frames"], _win_t, where,
		int(size.x), int(size.y), OS.get_name(), RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method()]

func _write(s: Dictionary) -> void:
	var f := FileAccess.open(LOG, FileAccess.READ_WRITE) if FileAccess.file_exists(LOG) else FileAccess.open(LOG, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(_line(s))
	f.close()
