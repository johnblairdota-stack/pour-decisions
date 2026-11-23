## The fly-in as a film: one camera flight through the Blender model of Brisbane, rendered frame by
## frame (tools/blender/spire/render_film.py, film_pack.py), from high in the cloud all the way down
## to the floor pick's own view of the first deck. The game's own camera flies the same line under it
## (the film's cameras are in <tower>_cams.json), and the film only fades off once both are standing
## still on the same view. If the floor pick stands somewhere else (a later deck), the game's camera
## goes on there live as the film fades.
## Nothing here places or shows equipment.
extends RefCounted

const CLOUD := preload("res://shaders/fly_cloud.gdshader")
const CLOUD_T := 1.4        # s: the cloud parts
const BLEND_T := 1.3        # s before the film's last frame the city round the site starts to change over to the game's own
const HAND_T := 0.9         # s after the film's last frame (it holds there): it fades off, onto the live site
const LIVE_T := 1.6         # s live from the film's last frame onto the floor pick, if that's somewhere else
const WORLD_LAYER := 1 << 12  # the render layer the surroundings sit on while the film plays
const FAR_M := 300.0         # m: a part of the game bigger than this, or further off, is the city's, not the site's
const SAME := 0.75          # m: nearer the floor pick's own camera than this, the film ends on it

## The film of a flight ("film" in Flight.TOWERS): {"video", "cams"}.
static func ready(fl: Dictionary) -> bool:
	return fl.has("film") and ResourceLoader.exists(String(fl["film"]["video"])) and FileAccess.file_exists(String(fl["film"]["cams"]))

## The film's screen (under every page) and its cameras.
static func make(parent: Node, fl: Dictionary) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = -1
	parent.add_child(layer)
	var v := VideoStreamPlayer.new()
	v.stream = load(String(fl["film"]["video"]))
	v.expand = true
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.volume_db = -80.0
	layer.add_child(v)
	# (the game's own site, drawn over the film: see `site`)
	var o := TextureRect.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	o.stretch_mode = TextureRect.STRETCH_SCALE
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.visible = false
	layer.add_child(o)
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = CLOUD
	r.material = m
	layer.add_child(r)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(fl["film"]["cams"])))
	layer.set_meta("cams", d)
	v.play()
	return layer

## How long the film runs, s.
static func dur(layer: CanvasLayer) -> float:
	return float(layer.get_meta("cams")["dur"])

## Lay the film out for this frame, t s in. `gone`: skipped, the film's off and the live flight runs on.
static func draw(layer: CanvasLayer, t: float, gone: bool) -> void:
	var v := layer.get_child(0) as VideoStreamPlayer
	var r := layer.get_child(2) as ColorRect
	var d := dur(layer)
	var vs := r.get_viewport_rect().size
	var tex := v.get_video_texture()
	if tex != null and tex.get_width() > 0:
		var ts := Vector2(tex.get_width(), tex.get_height())
		var fit := maxf(vs.x / ts.x, vs.y / ts.y)
		v.size = ts * fit
		v.position = (vs - v.size) * 0.5
	var left := 0.0 if gone else 1.0 - smoothstep(d - BLEND_T, d + HAND_T, t)
	v.modulate.a = left
	if (gone or t >= d + HAND_T) and v.is_playing():
		v.stop()
	var m := r.material as ShaderMaterial
	m.set_shader_parameter("cloud", 0.0 if gone else 1.0 - smoothstep(0.1, CLOUD_T, t))
	m.set_shader_parameter("cloud_t", t)
	m.set_shader_parameter("aspect", vs.x / maxf(1.0, vs.y))
	layer.visible = left > 0.0

## The film's camera t s in, in the model's own metres (x east, y north, z AHD): [place, look].
static func cam(layer: CanvasLayer, t: float) -> Array:
	var d: Dictionary = layer.get_meta("cams")
	var cams: Array = d["cams"]
	var f := clampf(t * float(d["fps"]), 0.0, float(cams.size() - 1))
	var i := mini(int(f), cams.size() - 2)
	var a: Array = cams[i]
	var b: Array = cams[i + 1]
	var p := Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), f - float(i))
	if d.has("looks"):
		var la: Array = d["looks"][i]
		var lb: Array = d["looks"][i + 1]
		return [p, Vector3(la[0], la[1], la[2]).lerp(Vector3(lb[0], lb[1], lb[2]), f - float(i))]
	var tg: Array = d["target"]
	return [p, Vector3(tg[0], tg[1], tg[2])]

## The game's own site over the film. The film is the city; the tower, its deck, the crane and the crew
## are the game's own from the first frame, drawn by a second camera that leaves the game's city out
## (`world`: the surroundings' model, put on a layer of its own for as long as the film's up). So when
## the film fades there is only the city behind that changes over: the site is the same picture.
static func site(layer: CanvasLayer, world: Node3D, cam: Camera3D, env: Environment) -> void:
	if layer.has_meta("site"):
		return
	var sv := SubViewport.new()
	sv.transparent_bg = true
	sv.msaa_3d = layer.get_viewport().msaa_3d
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	layer.add_child(sv)
	var c := Camera3D.new()
	c.cull_mask = cam.cull_mask & ~WORLD_LAYER
	var e := env.duplicate() as Environment
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.glow_enabled = false
	e.fog_enabled = false
	e.volumetric_fog_enabled = false
	c.environment = e
	sv.add_child(c)
	(layer.get_child(1) as TextureRect).texture = sv.get_texture()
	(layer.get_child(1) as TextureRect).visible = true
	layer.set_meta("site", c)
	# (and whatever else of the game's lies out in the city, not on the site: the free roam's streets,
	# the CityCat. The film has the city.)
	var out: Array = [world]
	for ch in world.get_parent().get_children():
		if ch is Node3D and ch != world:
			var bx := _box(ch)
			if maxf(bx.size.x, bx.size.z) > FAR_M or Vector2(bx.get_center().x, bx.get_center().z).length() > FAR_M:
				out.append(ch)
	layer.set_meta("world", out)
	for n in out:
		_layers(n, true)

static func _layers(n: Node, on: bool) -> void:
	if n is VisualInstance3D:
		var vi := n as VisualInstance3D
		if on:
			vi.set_meta("fly_layers", vi.layers)
			vi.layers = WORLD_LAYER
		elif vi.has_meta("fly_layers"):
			vi.layers = int(vi.get_meta("fly_layers"))
			vi.remove_meta("fly_layers")
	for ch in n.get_children():
		_layers(ch, on)

## Every frame, once the game's camera is placed: the site's camera stands where it does.
static func follow(layer: CanvasLayer, cam: Camera3D) -> void:
	if not layer.has_meta("site"):
		return
	var c := layer.get_meta("site") as Camera3D
	var sv := c.get_parent() as SubViewport
	var want := Vector2i(layer.get_viewport().get_visible_rect().size)
	if sv.size != want:
		sv.size = want
	c.global_transform = cam.global_transform
	c.fov = cam.fov
	c.near = cam.near
	c.far = cam.far

## The film's over: the surroundings go back on their own layers.
static func done(layer: CanvasLayer) -> void:
	for n in layer.get_meta("world", []):
		if is_instance_valid(n):
			_layers(n as Node, false)

static func _box(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if x is VisualInstance3D and (x as VisualInstance3D).is_visible_in_tree():
			var b: AABB = (x as VisualInstance3D).global_transform * (x as VisualInstance3D).get_aabb()
			out = b if first else out.merge(b)
			first = false
		stack.append_array(x.get_children())
	return out
