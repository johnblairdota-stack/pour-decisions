## Looks: whole-picture styles to try on the game, side by side.
## Smoko > Settings > Look picks one (kept between sessions), F6 flicks through
## them live, and `--look=N` (or a name: `--look=clay`) starts on one, for
## screenshots.
##
## A look is the shading every toon-lit thing gets (shaders/look.gdshaderinc,
## by shader globals), the character ink lines (outline.gdshader), and the
## finishing: tone mapping, exposure, a colour grade, glow and haze. All of
## that is the same work for the GPU whichever look is on; only Comic Ink's
## lines round everything add a pass (and Lite leaves them off).
##
## Each day's own light (Story.LIGHTS) still plays on top: a look's contrast,
## saturation, ambient and haze multiply the day's.
extends RefCounted

const KEYS := ["toon", "cel", "clay", "golden", "ink", "true"]
const NAMES := ["Site Toon", "Bold Cel", "Soft Clay", "Golden Hour", "Comic Ink", "True Light"]
const BLURB := [
	"How it's always looked: soft toon bands and a light rim.",
	"Hard two-tone cel shading, cool blue shadows, a bright rim, heavier ink on the crew.",
	"Soft wrapped light like a clay model: pale, gentle shadows, little shine, no hard lines.",
	"Warm film grade: teal shadows, golden highlights, a little bloom and more haze.",
	"Three flat bands and ink lines round everything, like a comic panel. Costs a little.",
	"Plain realistic light: no bands, no rim, no outlines, a neutral grade.",
]

## Per look. shade: 0 toon, 1 smooth, 2 banded (look.gdshaderinc).
## tint: the sun's dark side leans to it (a = how much). ink_w: crew line
## weight (0 none). tm: tone mapper. grade: [shadow, mid, highlight] curve
## colours, or [] for none. con/sat/amb/haze/glow: times the day's.
const P := {
	"toon": {"shade": 0, "wrap": 0.0, "bands": 1, "edge": 0.05, "tint": Color(0, 0, 0, 0), "rim": 1.0, "spec": 1.0,
		"ink_w": 1.0, "ink": Color(0, 0, 0, 0), "tm": Environment.TONE_MAPPER_FILMIC, "exp": 1.0, "white": 1.0,
		"grade": [], "con": 1.0, "sat": 1.0, "amb": 1.0, "haze": 1.0, "glow": 1.0, "bloom": 0.0, "edges": false},
	"cel": {"shade": 2, "wrap": 0.1, "bands": 1, "edge": 0.015, "tint": Color(0.36, 0.45, 0.85, 0.32), "rim": 1.5, "spec": 1.3,
		"ink_w": 1.5, "ink": Color(0.04, 0.05, 0.10, 0.6), "tm": Environment.TONE_MAPPER_FILMIC, "exp": 1.05, "white": 1.0,
		"grade": [], "con": 1.06, "sat": 1.18, "amb": 0.85, "haze": 1.0, "glow": 1.0, "bloom": 0.0, "edges": false},
	"clay": {"shade": 1, "wrap": 0.55, "bands": 1, "edge": 0.05, "tint": Color(0.62, 0.52, 0.70, 0.30), "rim": 0.35, "spec": 0.25,
		"ink_w": 0.0, "ink": Color(0, 0, 0, 0), "tm": Environment.TONE_MAPPER_AGX, "exp": 1.18, "white": 1.0,
		"grade": [Color(0.06, 0.05, 0.09), Color(0.53, 0.51, 0.50), Color(1.0, 0.98, 0.95)], "con": 0.92, "sat": 0.86, "amb": 1.3, "haze": 1.3, "glow": 0.8, "bloom": 0.0, "edges": false},
	"golden": {"shade": 1, "wrap": 0.15, "bands": 1, "edge": 0.05, "tint": Color(0.20, 0.50, 0.62, 0.28), "rim": 0.9, "spec": 1.2,
		"ink_w": 0.7, "ink": Color(0.10, 0.06, 0.04, 0.5), "tm": Environment.TONE_MAPPER_ACES, "exp": 1.05, "white": 6.0,
		"grade": [Color(0.0, 0.035, 0.06), Color(0.52, 0.49, 0.43), Color(1.0, 0.94, 0.80)], "con": 1.05, "sat": 1.08, "amb": 0.9, "haze": 1.7, "glow": 2.0, "bloom": 0.08, "edges": false},
	"ink": {"shade": 2, "wrap": 0.2, "bands": 2, "edge": 0.01, "tint": Color(0.30, 0.36, 0.62, 0.22), "rim": 0.0, "spec": 1.2,
		"ink_w": 1.4, "ink": Color(0.02, 0.02, 0.03, 1.0), "tm": Environment.TONE_MAPPER_FILMIC, "exp": 1.08, "white": 1.0,
		"grade": [], "con": 1.12, "sat": 1.22, "amb": 1.0, "haze": 0.7, "glow": 0.0, "bloom": 0.0, "edges": true},
	"true": {"shade": 1, "wrap": 0.0, "bands": 1, "edge": 0.05, "tint": Color(0, 0, 0, 0), "rim": 0.0, "spec": 1.0,
		"ink_w": 0.0, "ink": Color(0, 0, 0, 0), "tm": Environment.TONE_MAPPER_AGX, "exp": 1.1, "white": 1.0,
		"grade": [], "con": 1.0, "sat": 1.0, "amb": 1.1, "haze": 1.0, "glow": 1.0, "bloom": 0.0, "edges": false},
}

static var cur := 0
static var _edges: MeshInstance3D

## The look on now (its settings).
static func now() -> Dictionary:
	return P[KEYS[cur]]

## Times the day's value for `what` ("con", "sat", "amb", "haze").
static func k(what: String) -> float:
	return float(now()[what])

## Which look to start on: `--look=` beats the saved setting.
static func pick(saved: int) -> int:
	var i := clampi(saved, 0, KEYS.size() - 1)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--look="):
			var v := arg.substr(7)
			i = KEYS.find(v) if v in KEYS else clampi(int(v), 0, KEYS.size() - 1)
	return i

## Put look `i` on the game (its environment, the shader globals, the lines).
static func apply(game, i: int) -> void:
	cur = clampi(i, 0, KEYS.size() - 1)
	var l := now()
	var g := RenderingServer
	g.global_shader_parameter_set("look_shade", float(l["shade"]))
	g.global_shader_parameter_set("look_wrap", float(l["wrap"]))
	g.global_shader_parameter_set("look_bands", float(l["bands"]))
	g.global_shader_parameter_set("look_edge", float(l["edge"]))
	g.global_shader_parameter_set("look_tint", l["tint"])
	g.global_shader_parameter_set("look_rim", float(l["rim"]))
	g.global_shader_parameter_set("look_spec", float(l["spec"]))
	g.global_shader_parameter_set("look_ink_w", float(l["ink_w"]))
	g.global_shader_parameter_set("look_ink", l["ink"])
	var env: Environment = game.env
	env.tonemap_mode = l["tm"]
	env.tonemap_exposure = float(l["exp"])
	env.tonemap_white = float(l["white"])
	env.glow_intensity = 0.3 * float(l["glow"])
	env.glow_bloom = float(l["bloom"])
	env.glow_enabled = not game.lite and float(l["glow"]) > 0.0
	var gr: Array = l["grade"]
	if gr.is_empty():
		env.adjustment_color_correction = null
	else:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		grad.colors = PackedColorArray([gr[0], gr[1], gr[2]])
		var t := GradientTexture1D.new()
		t.gradient = grad
		t.width = 256
		env.adjustment_color_correction = t
	_set_edges(game, bool(l["edges"]) and not game.lite)
	# (the day's light picks the look's multipliers up on its next frame)
	if game.has_method("relight"):
		game.relight()

static func _set_edges(game, on: bool) -> void:
	if on and not is_instance_valid(_edges):
		_edges = MeshInstance3D.new()
		_edges.name = "InkEdges"
		var q := QuadMesh.new()
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/ink_edges.gdshader")
		m.render_priority = -100
		q.material = m
		_edges.mesh = q
		_edges.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# (it's drawn over the whole screen of whatever camera's looking)
		_edges.extra_cull_margin = 16384.0
		_edges.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
		game.add_child(_edges)
	if is_instance_valid(_edges):
		_edges.visible = on
