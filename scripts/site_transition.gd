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
## The Brisbane River's centreline from OpenStreetMap (waterway=river), Toowong to past Hamilton,
## simplified to 25 m (lat, lon)
const RIVER := [
	Vector2(-27.47294, 153.00764),
	Vector2(-27.46886, 153.01386),
	Vector2(-27.46841, 153.01600),
	Vector2(-27.46860, 153.01713),
	Vector2(-27.47146, 153.02013),
	Vector2(-27.47675, 153.02447),
	Vector2(-27.47959, 153.02608),
	Vector2(-27.48043, 153.02695),
	Vector2(-27.48098, 153.02834),
	Vector2(-27.48060, 153.03103),
	Vector2(-27.47788, 153.03289),
	Vector2(-27.47495, 153.03314),
	Vector2(-27.46891, 153.03214),
	Vector2(-27.46670, 153.03238),
	Vector2(-27.46511, 153.03319),
	Vector2(-27.46397, 153.03431),
	Vector2(-27.46379, 153.03555),
	Vector2(-27.46392, 153.03654),
	Vector2(-27.46493, 153.03777),
	Vector2(-27.47248, 153.03994),
	Vector2(-27.47516, 153.04140),
	Vector2(-27.47642, 153.04327),
	Vector2(-27.47676, 153.04610),
	Vector2(-27.47500, 153.05025),
	Vector2(-27.47360, 153.05258),
	Vector2(-27.47071, 153.05538),
	Vector2(-27.46851, 153.05574),
	Vector2(-27.46663, 153.05521),
	Vector2(-27.46310, 153.05295),
	Vector2(-27.46106, 153.05229),
	Vector2(-27.45176, 153.05088),
	Vector2(-27.44654, 153.04920),
	Vector2(-27.44281, 153.04919),
	Vector2(-27.44164, 153.05030),
	Vector2(-27.44101, 153.05220),
	Vector2(-27.44073, 153.05609),
	Vector2(-27.44120, 153.06029),
	Vector2(-27.44175, 153.06361),
	Vector2(-27.44521, 153.07572),
	Vector2(-27.44768, 153.08677),
	Vector2(-27.44777, 153.08995),
	Vector2(-27.44733, 153.09367),
]
const CBD := Vector2(-27.4690, 153.0260)
const STORY_BRIDGE := [Vector2(-27.46171, 153.03570), Vector2(-27.46570, 153.03580)]   # OSM Bradfield Hwy, bridge=yes
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

## The river point nearest a pin
func _nearest(at: Vector2) -> int:
	var best := 0
	for i in RIVER.size():
		if (RIVER[i] as Vector2).distance_to(at) < (RIVER[best] as Vector2).distance_to(at):
			best = i
	return best

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
	for br in [STORY_BRIDGE]:
		_view.draw_line(to_px.call(br[0]), to_px.call(br[1]), Color(0.92, 0.9, 0.84, 0.8 * show), maxf(3.0, zoom * 0.5))
	var font := UI.font("head")
	var fs := 22
	_view.draw_string(font, to_px.call(STORY_BRIDGE[0]).lerp(to_px.call(STORY_BRIDGE[1]), 0.5) + Vector2(maxf(14.0, zoom * 1.6), 6), "STORY BRIDGE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 6, Color(1, 1, 1, 0.55 * show))
	_view.draw_string(font, cbd + Vector2(-20, zoom * 6.0 + 22), "CBD", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 4, Color(1, 1, 1, 0.5 * show))
	_view.draw_string(font, to_px.call(Vector2(-27.4560, 153.0560)) + Vector2(10, 0), "BRISBANE RIVER", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 6, Color(0.7, 0.86, 0.95, 0.6 * show))
	# the trip: dots along the river from pin to pin, filling in as the camera goes
	if t > RISE_T * 0.6:
		var a0 := _nearest(PINS[from_site]["at"])
		var b0 := _nearest(PINS[to_site]["at"])
		var lo := mini(a0, b0)
		var hi := maxi(a0, b0)
		var prog := clampf((t - RISE_T) / SLIDE_T, 0.0, 1.0)
		var path: Array = []
		for i in range(lo, hi + 1):
			path.append(to_px.call(RIVER[i]))
		if a0 > b0:
			path.reverse()
		var total := 0.0
		for i in range(1, path.size()):
			total += (path[i] as Vector2).distance_to(path[i - 1])
		var gap := 14.0
		var walked := 0.0
		var next := 0.0
		for i in range(1, path.size()):
			var p0: Vector2 = path[i - 1]
			var p1: Vector2 = path[i]
			var sl := p0.distance_to(p1)
			while next <= walked + sl:
				if next > total * prog:
					break
				_view.draw_circle(p0.lerp(p1, (next - walked) / maxf(sl, 0.001)), 3.5, Color(UI.GOLD, 0.9 * show))
				next += gap
			walked += sl
	# the pins
	for key in PINS:
		var pin: Dictionary = PINS[key]
		var at: Vector2 = to_px.call(pin["at"])
		var on: bool = key == to_site
		var col := UI.GOLD if on else Color(1, 1, 1, 0.85)
		var pulse := 1.0 + (0.25 * sin(t * 9.0) if on else 0.0)
		_view.draw_circle(at, 13.0 * pulse, Color(col, show))
		_view.draw_circle(at, 6.0, Color(0.1, 0.1, 0.12, show))
		var left: bool = key == "spire"      # (the Story Bridge is just east of Spire: its label goes west)
		var nw := font.get_string_size(pin["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs + (8 if on else 0)).x
		var sw := font.get_string_size(pin["sub"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 6).x
		_view.draw_string(font, at + Vector2(-20 - nw if left else 20, -2), pin["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs + (8 if on else 0), Color(col, show))
		_view.draw_string(font, at + Vector2(-20 - sw if left else 20, 24), pin["sub"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 6, Color(1, 1, 1, 0.6 * show))
	# (loading: a small note while it waits on the new site)
	if _reloaded and _ready_frames < 3:
		_view.draw_string(font, Vector2(size.x * 0.5 - 60, size.y - 50), "LOADING SITE...", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.7))
