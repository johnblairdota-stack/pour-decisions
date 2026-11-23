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
const HAND_T := 0.9         # s after the film's last frame (it holds there): it fades off, onto the live site
const LIVE_T := 1.6         # s live from the film's last frame onto the floor pick, if that's somewhere else
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
	var r := layer.get_child(1) as ColorRect
	var d := dur(layer)
	var vs := r.get_viewport_rect().size
	var tex := v.get_video_texture()
	if tex != null and tex.get_width() > 0:
		var ts := Vector2(tex.get_width(), tex.get_height())
		var fit := maxf(vs.x / ts.x, vs.y / ts.y)
		v.size = ts * fit
		v.position = (vs - v.size) * 0.5
	var left := 0.0 if gone else 1.0 - smoothstep(d, d + HAND_T, t)
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
