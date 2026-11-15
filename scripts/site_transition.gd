## The fly between two sites on the pick screen (select.gd): the camera rises off the tower into a
## flat map of the Brisbane River, slides along the river to the other site's pin, and dives into it.
## The game restarts on the other site behind the map (main.gd builds one site per run), so the load's
## hitch is hidden while the map sits on the new pin. Lives on the tree's root, not in the game's
## scene, so it carries on through the restart. 2D only: cheap on the tablet. Any key, button or
## click skips ahead.
extends CanvasLayer

const UI := preload("res://scripts/ui.gd")

## The river from Toowong out past the Gateway Bridge, a little smoothed (lat, lon). Hand-read from
## the map, stylised: it only has to read as the river and put the sites in the right bends.
const RIVER := [
	Vector2(-27.4870, 152.9905), Vector2(-27.4800, 153.0010), Vector2(-27.4760, 153.0110), Vector2(-27.4725, 153.0180),
	Vector2(-27.4705, 153.0225), Vector2(-27.4730, 153.0285), Vector2(-27.4745, 153.0330), Vector2(-27.4705, 153.0360),
	Vector2(-27.4640, 153.0365), Vector2(-27.4590, 153.0400), Vector2(-27.4595, 153.0460), Vector2(-27.4650, 153.0505),
	Vector2(-27.4700, 153.0550), Vector2(-27.4690, 153.0615), Vector2(-27.4610, 153.0645), Vector2(-27.4520, 153.0660),
	Vector2(-27.4460, 153.0700), Vector2(-27.4425, 153.0780), Vector2(-27.4420, 153.0880), Vector2(-27.4440, 153.0990),
	Vector2(-27.4455, 153.1110),
]
const CBD := Vector2(-27.4690, 153.0260)
const STORY_BRIDGE := [Vector2(-27.4625, 153.0352), Vector2(-27.4655, 153.0378)]
const GATEWAY := [Vector2(-27.4400, 153.1080), Vector2(-27.4510, 153.1125)]
## The sites' pins (lat, lon) and names
const PINS := {
	"spire": {"at": Vector2(-27.4637, 153.0312), "name": "SPIRE", "sub": "550 Queen St"},
	"riverlight": {"at": Vector2(-27.4398, 153.0772), "name": "RIVERLIGHT", "sub": "Hamilton Reach"},
}
const RISE_T := 0.45
const SLIDE_T := 0.85
const DIVE_T := 0.6

var from_site := "riverlight"
var to_site := "spire"
var t := 0.0
var _reloaded := false
var _ready_frames := 0
var _skip := false
var _view: Control
var _old_scene: Node
static var shot_dir := ""     # (dev: --pickshots saves a frame of the fly here)
var _shot := false

## Starts the fly from one site to the other; `restart` is called once the map's on the new pin.
static func fly(tree: SceneTree, from: String, to: String) -> void:
	var tr = load("res://scripts/site_transition.gd").new()
	tr.from_site = from
	tr.to_site = to
	tr._old_scene = tree.current_scene
	tree.root.add_child(tr)

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_map)
	add_child(_view)

func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed():
		_skip = true

func _process(delta: float) -> void:
	t += delta * (4.0 if _skip else 1.0)
	if not _reloaded and t >= RISE_T + SLIDE_T:
		_reloaded = true
		t = RISE_T + SLIDE_T
		get_tree().reload_current_scene()
	if _reloaded and _ready_frames < 3:
		# (hold on the pin until the new site's built and has drawn a couple of frames)
		if get_tree().current_scene != null and get_tree().current_scene != _old_scene:
			_ready_frames += 1
		t = RISE_T + SLIDE_T
	if t >= RISE_T + SLIDE_T + DIVE_T:
		queue_free()
	_view.queue_redraw()
	if shot_dir != "" and not _shot and t > RISE_T + SLIDE_T * 0.5:
		_shot = true
		(func(): get_viewport().get_texture().get_image().save_png(shot_dir.path_join("pick_fly.png"))).call_deferred()

func _ll(p: Vector2) -> Vector2:
	# lat/lon -> a flat map (x east, y south), about metres / 100
	return Vector2((p.y - 153.05) * 985.0, -(p.x + 27.46) * 1110.0)

## Map view: [centre in map units, zoom (pixels per map unit)], and how much of the map shows (0..1)
func _cam() -> Array:
	var a := _ll(PINS[from_site]["at"])
	var b := _ll(PINS[to_site]["at"])
	var mid := (a + b) * 0.5
	var size := _view.size
	var fit := minf(size.x / (absf(a.x - b.x) + 22.0), size.y / (absf(a.y - b.y) + 16.0))
	var close := fit * 5.0
	if t < RISE_T:
		var e := ease(t / RISE_T, -2.0)
		return [a, lerpf(close, fit * 1.3, e), e]
	if t < RISE_T + SLIDE_T:
		var e2 := ease((t - RISE_T) / SLIDE_T, -2.0)
		return [a.lerp(b, e2).lerp(mid, sin(e2 * PI) * 0.35), fit * 1.3 * (1.0 - 0.25 * sin(e2 * PI)), 1.0]
	var e3 := ease(clampf((t - RISE_T - SLIDE_T) / DIVE_T, 0.0, 1.0), -2.0)
	return [b, lerpf(fit * 1.3, close * 1.6, e3), 1.0 - e3]

func _draw_map() -> void:
	var c: Array = _cam()
	var centre: Vector2 = c[0]
	var zoom: float = c[1]
	var show: float = c[2]
	var size := _view.size
	var to_px := func(p: Vector2) -> Vector2:
		return (_ll(p) - centre) * zoom + size * 0.5
	var land := Color("1c2a24")
	var water := Color("2d6a8f")
	_view.draw_rect(Rect2(Vector2.ZERO, size), Color(land, show))
	# a faint street grid, so it reads as a city map
	var grid := Color(1, 1, 1, 0.05 * show)
	var step := maxf(28.0, zoom * 2.0)
	var x0 := fmod(-centre.x * zoom + size.x * 0.5, step)
	var y0 := fmod(-centre.y * zoom + size.y * 0.5, step)
	var gx := x0
	while gx < size.x:
		_view.draw_line(Vector2(gx, 0), Vector2(gx, size.y), grid, 1.0)
		gx += step
	var gy := y0
	while gy < size.y:
		_view.draw_line(Vector2(0, gy), Vector2(size.x, gy), grid, 1.0)
		gy += step
	# the CBD: a pale block
	var cbd: Vector2 = to_px.call(CBD)
	_view.draw_circle(cbd, zoom * 6.0, Color(0.85, 0.82, 0.74, 0.12 * show))
	# the river
	var pts := PackedVector2Array()
	for p in RIVER:
		pts.append(to_px.call(p))
	_view.draw_polyline(pts, Color(water, show), maxf(6.0, zoom * 2.6), true)
	_view.draw_polyline(pts, Color(0.55, 0.78, 0.92, 0.35 * show), maxf(1.5, zoom * 0.4), true)
	# bridges
	for br in [STORY_BRIDGE, GATEWAY]:
		_view.draw_line(to_px.call(br[0]), to_px.call(br[1]), Color(0.92, 0.9, 0.84, 0.8 * show), maxf(3.0, zoom * 0.5))
	var font := UI.font("head")
	var fs := 22
	_view.draw_string(font, to_px.call(STORY_BRIDGE[1]) + Vector2(10, 22), "STORY BRIDGE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 6, Color(1, 1, 1, 0.55 * show))
	_view.draw_string(font, cbd + Vector2(-40, -zoom * 6.0 - 8), "CBD", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 4, Color(1, 1, 1, 0.5 * show))
	_view.draw_string(font, to_px.call(RIVER[3]) + Vector2(-60, 40), "BRISBANE RIVER", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 6, Color(0.7, 0.86, 0.95, 0.6 * show))
	# the pins
	for key in PINS:
		var pin: Dictionary = PINS[key]
		var at: Vector2 = to_px.call(pin["at"])
		var on: bool = key == to_site
		var col := UI.GOLD if on else Color(1, 1, 1, 0.85)
		var pulse := 1.0 + (0.25 * sin(t * 9.0) if on else 0.0)
		_view.draw_circle(at, 13.0 * pulse, Color(col, show))
		_view.draw_circle(at, 6.0, Color(0.1, 0.1, 0.12, show))
		_view.draw_string(font, at + Vector2(20, -2), pin["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs + (8 if on else 0), Color(col, show))
		_view.draw_string(font, at + Vector2(20, 24), pin["sub"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 6, Color(1, 1, 1, 0.6 * show))
	# (loading: a small note while it waits on the new site)
	if _reloaded and _ready_frames < 3:
		_view.draw_string(font, Vector2(size.x * 0.5 - 60, size.y - 50), "LOADING SITE...", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.7))
