## Cheap touches to the picture that work with every look (look.gd):
##   blob()       a soft dark patch under a person or a truck, for Lite, where
##                the sun's shadows are low-res and soft (W12)
##   grime()      the site's wear painted onto the ground: tyre tracks into
##                the truck bay, slurry round the hopper, the washout stain,
##                oil under the pump, scuffs at the ladder (W11)
##   vignette()   a faint darkening at the screen's corners (W13)
## All drawn as a handful of decals and one flat overlay: no extra passes.
extends RefCounted


static var _blob_tex: Texture2D
static var lite := false   # (main.apply_graphics keeps it: blobs show on Lite only)
static var _tex := {}

## A soft round patch, darkest in the middle (also the base for the stains).
static func _soft(size: int, noise: float, seed_v: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = 0.045
	n.fractal_octaves = 3
	var h := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - h + 0.5, y - h + 0.5).length() / h
			var edge := 1.0 - d + noise * n.get_noise_2d(x, y)
			var a := clampf(edge * 1.6, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

## Two tyre tracks running the length of the texture (u across, v along).
static func _tracks(seed_v: int) -> ImageTexture:
	var w := 64
	var l := 256
	var img := Image.create(w, l, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = 0.06
	for y in l:
		var along := float(y) / l
		var fade := smoothstep(0.0, 0.18, along) * (1.0 - smoothstep(0.82, 1.0, along))
		for x in w:
			var u := float(x) / w
			var tr := 0.0
			for c in [0.2, 0.8]:
				tr = maxf(tr, 1.0 - smoothstep(0.07, 0.13, absf(u - c)))
			# (tread blocks across each track)
			tr *= 0.75 + 0.25 * (1.0 if fposmod(y * 0.18, 1.0) >= 0.5 else 0.0)
			var a := clampf(tr * fade * (0.65 + 0.5 * n.get_noise_2d(x, y)), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

static func _decal(tex: Texture2D, size: Vector3, tint: Color) -> Decal:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = size
	d.modulate = tint
	d.albedo_mix = 1.0
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.distance_fade_enabled = true
	d.distance_fade_begin = 140.0
	d.distance_fade_length = 40.0
	return d

## A blob shadow under something `size` (x along, z across) standing on its
## origin: projects down onto whatever's under it (deck, ground, rungs).
## In the "look_blob" group: shown on Lite only (main.apply_graphics).
static func blob(size: Vector2) -> Decal:
	if _blob_tex == null:
		_blob_tex = _soft(64, 0.0, 1)
	var d := _decal(_blob_tex, Vector3(size.x, 2.4, size.y), Color(0, 0, 0, 0.42))
	d.position = Vector3(0, 0.6, 0)
	d.add_to_group("look_blob")
	d.visible = lite
	return d

## The site's wear on the ground, under `root` (line.gd and ops.gd say where
## the bay, hopper, pump, pit and ladder are).
static func grime(root: Node3D, LineScript, OpsScript) -> void:
	var stain := _soft(128, 0.55, 7) as Texture2D
	var stain2 := _soft(128, 0.7, 19) as Texture2D
	var tracks := _tracks(3) as Texture2D
	var dir: Vector3 = (LineScript.BAY - LineScript.HOPPER).normalized()
	var put := func(tex: Texture2D, at: Vector3, size: Vector3, tint: Color, yaw := 0.0) -> void:
		var d := _decal(tex, size, tint)
		d.name = "Grime"
		d.position = at + Vector3(0, size.y * 0.3, 0)
		d.rotation.y = yaw
		root.add_child(d)
	var yaw := atan2(dir.x, dir.z)
	# Tyre tracks: each truck's wheels back in along the same line
	for side in [0.0, 1.6]:
		var at: Vector3 = LineScript.BAY + dir * 4.0 + Vector3(-dir.z, 0, dir.x) * side
		put.call(tracks, at, Vector3(2.5, 1.0, 12.0), Color(0.24, 0.2, 0.16, 0.55), yaw)
	# Slurry splashed round the hopper, grey and pale
	put.call(stain, LineScript.HOPPER + dir * 0.6, Vector3(4.2, 1.2, 4.2), Color(0.62, 0.62, 0.6, 0.6))
	put.call(stain2, LineScript.HOPPER + dir * 2.4, Vector3(2.6, 1.0, 3.0), Color(0.58, 0.58, 0.56, 0.45), yaw)
	# Oil and diesel under the pump
	put.call(stain2, LineScript.PUMP_POS, Vector3(2.6, 1.0, 3.4), Color(0.08, 0.08, 0.09, 0.4), yaw)
	# The washout's grey stain spreading from the settling pit
	put.call(stain, OpsScript.PIT, Vector3(5.5, 1.2, 4.0), Color(0.5, 0.5, 0.48, 0.5))
	# Scuffed dirt at the foot of the tower ladder
	put.call(stain2, LineScript.LADDER_FOOT, Vector3(2.0, 1.0, 2.0), Color(0.3, 0.25, 0.18, 0.45))

## The corners of the screen a touch darker, under everything on screen.
static func vignette(parent: Node) -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.name = "Vignette"
	cl.layer = -1
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.32)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.08, 1.08)
	t.width = 256
	t.height = 256
	var r := TextureRect.new()
	r.texture = t
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(r)
	parent.add_child(cl)
	return cl
