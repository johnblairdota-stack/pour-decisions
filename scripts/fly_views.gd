## The rendered fly-in: down out of the cloud over Brisbane to a tower, on pictures from the Blender
## model (tools/blender/spire/render_fly.py), then the last of it flown live onto the floor pick.
##
## The pictures are all taken along one straight line to the tower with the same look, each RATIO
## nearer than the last: pushing one in by RATIO lines it up with the next, which comes up through
## its middle. So the fall is one steady push, with no banking, float or boat to follow, and it's
## short. Nothing here places or shows equipment.
extends RefCounted

const SHADER := preload("res://shaders/fly_views.gdshader")
const CLOUD_T := 1.5        # s: the cloud parts
const STEP_T := 0.85        # s a view (the fall takes one view's distance off every STEP_T)
const LIVE_T := 3.6         # s live, from the last view's place onto the floor pick
const BLEND := 0.45         # of a step: the next view comes up over this much of it
const HAND_T := 0.7         # s the last view dissolves onto the live site

## The views of a flight ("views" in Flight.TOWERS): how many, how far each steps in, where from.
static func ready(fl: Dictionary) -> bool:
	if not fl.has("views"):
		return false
	var v: Dictionary = fl["views"]
	for i in int(v["n"]):
		if not ResourceLoader.exists(String(v["pics"]) % i):
			return false
	return true

static func total(fl: Dictionary) -> float:
	return fall_t(fl) + LIVE_T

static func fall_t(fl: Dictionary) -> float:
	return 0.5 + STEP_T * (int(fl["views"]["n"]) - 1)

## The overlay the views are drawn on, under every page and the card's own picture.
static func make(parent: Node, fl: Dictionary) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = -1
	parent.add_child(layer)
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	r.material = m
	layer.add_child(r)
	var pics: Array = []
	for i in int(fl["views"]["n"]):
		pics.append(load(String(fl["views"]["pics"]) % i))
	layer.set_meta("pics", pics)
	return layer

## Where the fall's got to at t: views gone by (a whole number and the part of the next). It eases
## out of the cloud and then holds its rate: the live flight picks it up at that speed.
static func gone(fl: Dictionary, t: float) -> float:
	var n := int(fl["views"]["n"]) - 1
	# (the rate comes up over the first second, as a smoothstep: its sum is t^3 - t^4 / 2, half a second lost)
	var u := (t * t * t - 0.5 * t * t * t * t) / STEP_T if t < 1.0 else (t - 0.5) / STEP_T
	return clampf(u, 0.0, float(n))

## Draw the fall at t (s) and hand back how much of the screen is still picture (1: all of it, 0: the
## live view has it).
static func draw(layer: CanvasLayer, fl: Dictionary, t: float) -> float:
	var r := layer.get_child(0) as ColorRect
	var m := r.material as ShaderMaterial
	var pics: Array = layer.get_meta("pics")
	var ratio := float(fl["views"]["ratio"])
	var n := pics.size() - 1
	var u := gone(fl, t)
	var i := mini(int(u), n)
	var f := u - float(i)
	if i >= n:
		i = n - 1
		f = 1.0
	m.set_shader_parameter("pic_a", pics[i])
	m.set_shader_parameter("pic_b", pics[i + 1])
	m.set_shader_parameter("za", pow(ratio, f))
	m.set_shader_parameter("zb", pow(ratio, f - 1.0))
	m.set_shader_parameter("mix_b", smoothstep(1.0 - BLEND, 1.0, f))
	var vs := r.get_viewport_rect().size
	var sa := vs.x / maxf(1.0, vs.y)
	var pa := float((pics[0] as Texture2D).get_width()) / float((pics[0] as Texture2D).get_height())
	m.set_shader_parameter("fit", Vector2(minf(1.0, sa / pa), minf(1.0, pa / sa)))
	m.set_shader_parameter("aspect", sa)
	m.set_shader_parameter("cloud", 1.0 - smoothstep(0.15, CLOUD_T, t))
	m.set_shader_parameter("cloud_t", t)
	var left := 1.0 - smoothstep(fall_t(fl) - 0.1, fall_t(fl) + HAND_T, t)
	m.set_shader_parameter("fade", left)
	layer.visible = left > 0.0
	return left

## The camera of view i in the model's own metres (x east, y north, z AHD): [place, look].
static func view_cam(fl: Dictionary, i: int) -> Array:
	var v: Dictionary = fl["views"]
	var s := float(v["last"]) * pow(float(v["ratio"]), float(int(v["n"]) - 1 - i))
	var el := deg_to_rad(float(v["el"]))
	var tg := Vector3(float(v["target"][0]), float(v["target"][1]), float(v["target"][2]))
	var d := Vector3(float(v["dir"][0]) * cos(el), float(v["dir"][1]) * cos(el), sin(el))
	return [tg + d * s, tg]
