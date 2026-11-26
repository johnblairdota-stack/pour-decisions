## The fly-in as a film: one camera flight through the Blender model of Brisbane, rendered frame by
## frame (tools/blender/spire/render_film.py, film_pack.py), from high in the cloud all the way down
## to the floor pick's own view. Its last part runs straight down the tower's face, standing on every
## deck's view for one frame (cams.json "floors"), and the film is slowed and stopped on the frame of
## the deck the crew is up to (`stop_t`, `film_t`): it never flies past them. The game's own camera
## flies the same line under it (the film's cameras are in <tower>_cams.json). If the floor pick
## stands on none of the film's frames, the game's camera goes on there live as the film fades.
## Nothing here places or shows equipment.
extends RefCounted

const CLOUD := preload("res://shaders/fly_cloud.gdshader")
const CLOUD_T := 1.4        # s: the cloud parts
const BLEND_T := 1.3        # s before the film's last frame the city round the site starts to change over to the game's own
const HAND_T := 0.9         # s after the film's last frame (it holds there): it fades off, onto the live site
const LIVE_T := 1.6         # s live from the film's last frame onto the floor pick, if that's somewhere else
const WORLD_LAYER := 1 << 12  # the render layer the surroundings sit on while the film plays
const FAR_M := 300.0         # m: a part of the game bigger than this, or further off, is the city's, not the site's
## Parts of the surroundings' model that are the site's own (the podium the deck stands on): they stay with the site.
const SITE_PARTS := ["SLAB_", "COLUMNS_", "FORMWORK_", "PROPS", "hoarding"]
const COVER_LAYER := 1 << 13  # and the one their black stand-ins are on, for the site's camera alone
const COVER_MIN := 6.0        # m: nothing smaller than this hides the site
## Parts of the surroundings that lie flat or are too slight to stand in front of anything.
const FLAT_PARTS := ["ground", "roads", "river", "footpaths", "footways", "kerb", "streetname", "busonly", "line", "car_park", "area_flat_", "street", "far_land"]
const SITE := preload("res://shaders/fly_site.gdshader")
const COVER := preload("res://shaders/fly_cover.gdshader")
const STAY_M := 0.12         # m: the camera's left the view the film ended on
const LEAVE_T := 0.6         # s: the film's city gives way to the game's own, once it has
const SAME := 0.75          # m: nearer the floor pick's own camera than this, the film ends on it
const EASE := 0.6           # s of film: it slows to a stop over the last this much (taking twice as long)
const WIDE := preload("res://shaders/fly_wide.gdshader")
const DOWN_MAX := 66.0      # degrees: it never looks down more steeply than this (the wide frames end a little past it)
const LOOK_BY := 0.85       # of the way from the run in to the stop: by then it is looking at the deck's own floor pick
const CREEP := 0.12         # the slowest the film runs before it stops (so it always gets to its frame)

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
	if _wide(d):
		# (the film's last part is wide frames, and the game's own view is cut from them: fly_wide.gdshader)
		var wd: Dictionary = d["wide"]
		var wm := ShaderMaterial.new()
		wm.shader = WIDE
		var sz := Vector2(wd["size"][0], wd["size"][1])
		var rc: Array = wd["rect"]
		wm.set_shader_parameter("tex_size", sz)
		wm.set_shader_parameter("ppd", float(wd["ppd"]))
		wm.set_shader_parameter("rect", Vector4(rc[0] / sz.x, rc[1] / sz.y, rc[2] / sz.x, rc[3] / sz.y))
		wm.set_shader_parameter("rect_aspect", float(rc[2]) / float(rc[3]))
		v.material = wm
	v.play()
	return layer

static func _wide(d: Dictionary) -> bool:
	return d.has("wide") and not (d["wide"] as Dictionary).is_empty() and int(d["wide"]["from"]) >= 0

## Which way the middle of the film's wide frames looks, in the game's own directions (`to_game`
## turns a place in the model's metres into the game's).
static func set_wide(layer: CanvasLayer, to_game: Callable) -> void:
	var d: Dictionary = layer.get_meta("cams")
	if not _wide(d) or layer.has_meta("wide_basis"):
		return
	var w: Array = d["wide"]["dir"]
	var dir: Vector3 = (to_game.call(Vector3(w[0], w[1], w[2])) as Vector3) - (to_game.call(Vector3.ZERO) as Vector3)
	layer.set_meta("wide_basis", Basis.looking_at(dir.normalized(), Vector3.UP))

## What the game's camera looks at, `ft` s into the film (film_t), from `at` (the game's metres). To
## the end of the run in it is the film's own. From there (the wide frames) it turns from the tower
## onto `focus`, what the floor pick it stops at (`stop`) looks at: down onto that deck from above,
## levelling out as it comes down to it.
static func aim(layer: CanvasLayer, ft: float, stop: float, at: Vector3, focus: Vector3, to_game: Callable) -> Vector3:
	var d: Dictionary = layer.get_meta("cams")
	var own: Vector3 = to_game.call(cam(layer, ft)[1])
	var t0 := float(d.get("run_in", 0.0))
	if not _wide(d) or stop < 0.0 or ft <= t0:
		return own
	var tg: Array = d["target"]
	var from: Vector3 = to_game.call(Vector3(tg[0], tg[1], tg[2]))
	var to := from.lerp(focus, smoothstep(0.0, LOOK_BY, (ft - t0) / maxf(0.1, stop - t0))) - at
	# (never steeper than the wide frames go: eased, so there's no corner in the turn)
	var flat := Vector2(to.x, to.z).length()
	var lim := deg_to_rad(DOWN_MAX)
	var pitch := atan2(to.y, flat)
	if pitch < 0.0:
		pitch = -lim * tanh(-pitch / lim)
	return at + Vector3(to.x, tan(pitch) * flat, to.z)

## How long the film runs, s.
static func dur(layer: CanvasLayer) -> float:
	return float(layer.get_meta("cams")["dur"])

## The film's time, s, of the frame that stands on the floor pick's view (`fin`, the game's metres;
## `to_game` turns the model's into them), or -1 if none does.
static func stop_t(layer: CanvasLayer, fin: Vector3, to_game: Callable) -> float:
	var d: Dictionary = layer.get_meta("cams")
	var cams: Array = d["cams"]
	var frames: Array = d.get("floors", [])
	if frames.is_empty():
		frames = [cams.size() - 1]
	var best := -1.0
	var near := SAME
	for f in frames:
		var c: Array = cams[int(f)]
		var m: float = (to_game.call(Vector3(c[0], c[1], c[2])) as Vector3).distance_to(fin)
		if m < near:
			near = m
			best = float(f) / float(d["fps"])
	return best

## When the film's over, s: standing on its stop frame (`stop`, from stop_t), or run right out.
static func end_t(layer: CanvasLayer, stop: float) -> float:
	return dur(layer) if stop < 0.0 else stop + EASE

## Where the film is, s, t s after it started: it slows evenly to a stop on `stop`.
static func film_t(t: float, stop: float) -> float:
	if stop < 0.0 or t <= stop - EASE:
		return t
	var u := minf(1.0, (t - (stop - EASE)) / (2.0 * EASE))
	return stop - EASE + EASE * (2.0 * u - u * u)

## Lay the film out for this frame, t s in. `gone`: skipped, the film's off and the live flight runs on.
## `stop`: the film's time it stops at (stop_t), with `stay`.
static func draw(layer: CanvasLayer, t: float, gone: bool, stay := false, stop := -1.0) -> void:
	var v := layer.get_child(0) as VideoStreamPlayer
	var r := layer.get_child(2) as ColorRect
	var d := end_t(layer, stop)
	var vs := r.get_viewport_rect().size
	var tex := v.get_video_texture()
	if v.material != null:
		v.position = Vector2.ZERO          # (the whole screen: the shader lays the picture out)
		v.size = vs
		(v.material as ShaderMaterial).set_shader_parameter("aspect", vs.x / maxf(1.0, vs.y))
	elif tex != null and tex.get_width() > 0:
		var ts := Vector2(tex.get_width(), tex.get_height())
		var fit := maxf(vs.x / ts.x, vs.y / ts.y)
		v.size = ts * fit
		v.position = (vs - v.size) * 0.5
	# (`stay`: it ends on the floor pick's own view, and stays up behind it: main._film_stay)
	var left := 0.0 if gone else (1.0 if stay else 1.0 - smoothstep(d - BLEND_T, d + HAND_T, t))
	v.modulate.a = left
	# (the site's own layer goes with the last of the film: by then the game's picture under it is the same)
	var o := layer.get_child(1) as TextureRect
	if o.material != null:
		(o.material as ShaderMaterial).set_shader_parameter("show", smoothstep(0.0, 0.35, left))
	if stay and not gone:
		var fps := float(layer.get_meta("cams")["fps"])
		if stop < 0.0:
			if t >= d + 0.3:
				v.paused = true           # (held on its last frame)
		elif not v.paused:
			# (slowed by the same rule the camera under it is, and stopped once its frame is up)
			var rate := clampf(1.0 - (t - (stop - EASE)) / (2.0 * EASE), CREEP, 1.0)
			if v.stream_position >= stop + 0.3 / fps:
				v.paused = true
			elif not is_equal_approx(v.speed_scale, rate):
				v.speed_scale = rate
	elif (gone or t >= d + HAND_T) and v.is_playing():
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
	c.cull_mask = (cam.cull_mask & ~WORLD_LAYER) | COVER_LAYER
	c.environment = Environment.new()
	c.set_meta("env", env)
	c.set_meta("cam_mask", cam.cull_mask)
	cam.cull_mask &= ~COVER_LAYER
	sv.add_child(c)
	var o := layer.get_child(1) as TextureRect
	o.texture = sv.get_texture()
	var om := ShaderMaterial.new()
	om.shader = SITE
	o.material = om
	o.visible = true
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
	# (the city's buildings stand in front of the site wherever they really do: each is drawn for the
	# site's camera alone, in plain black, which the site's picture leaves out)
	var covers := Node3D.new()
	covers.name = "FlyCovers"
	world.get_parent().add_child(covers)
	var cm := ShaderMaterial.new()
	cm.shader = COVER
	_covers(world, covers, cm)
	layer.set_meta("covers", covers)

static func _covers(n: Node, into: Node3D, mat: Material) -> void:
	var nm := String(n.name)
	for pre in SITE_PARTS + FLAT_PARTS:
		if nm.begins_with(pre):
			return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).is_visible_in_tree():
		var src := n as MeshInstance3D
		var box := src.get_aabb()
		if maxf(box.size.x, maxf(box.size.y, box.size.z)) * src.global_transform.basis.get_scale().x > COVER_MIN:
			var m := MeshInstance3D.new()
			m.mesh = src.mesh
			m.material_override = mat
			m.layers = COVER_LAYER
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			into.add_child(m)
			m.global_transform = src.global_transform
	for ch in n.get_children():
		_covers(ch, into, mat)

static func _layers(n: Node, on: bool) -> void:
	for pre in SITE_PARTS:
		if String(n.name).begins_with(pre):
			return
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
	if layer.has_meta("wide_basis"):
		# (the game's own view, cut from the film's wide frame by where its camera looks now)
		var v := layer.get_child(0) as VideoStreamPlayer
		var m := v.material as ShaderMaterial
		m.set_shader_parameter("rot", (layer.get_meta("wide_basis") as Basis).inverse() * cam.global_transform.basis.orthonormalized())
		m.set_shader_parameter("tan_half", tan(deg_to_rad(cam.fov * 0.5)))
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
	# (the same light as the game's own picture, whatever the day's doing to it: only the sky's left out)
	var env := c.get_meta("env") as Environment
	for p in env.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_STORAGE and not String(p["name"]) in ["background_mode", "resource_path", "resource_name", "resource_local_to_scene", "script"]:
			c.environment.set(p["name"], env.get(p["name"]))
	c.environment.background_mode = Environment.BG_CLEAR_COLOR
	c.environment.background_color = Color(0, 0, 0, 0)
	cam.cull_mask &= ~COVER_LAYER

## The film's over: the surroundings go back on their own layers.
static func done(layer: CanvasLayer, cam: Camera3D) -> void:
	for n in layer.get_meta("world", []):
		if is_instance_valid(n):
			_layers(n as Node, false)
	if layer.has_meta("covers"):
		(layer.get_meta("covers") as Node).queue_free()
	if layer.has_meta("site"):
		cam.cull_mask = int((layer.get_meta("site") as Camera3D).get_meta("cam_mask"))

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

## The film's city gives way (main._film_stay): k 1..0.
static func leave(layer: CanvasLayer, k: float) -> void:
	(layer.get_child(0) as CanvasItem).modulate.a = k
	var o := layer.get_child(1) as TextureRect
	if o.material != null:
		(o.material as ShaderMaterial).set_shader_parameter("show", smoothstep(0.0, 0.5, k))
