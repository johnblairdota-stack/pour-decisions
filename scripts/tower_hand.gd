## The tower pick, "The hand" (John's pick from the design board, 15 Nov): three playing cards fanned
## low at the bottom of the screen, a slow river flight behind them (main.gd). Left / right fans
## through, A plays the focused card: it jumps out of the hand and spins face-on, the view pushes into
## its picture, and main.gd flies low up the river to that tower (reloading on the other site behind the
## picture when it's there) before the crew page. The cards are real 3D in their own little world
## (a SubViewport over the game), their faces drawn by 2D pages into textures.
extends Control

const UI := preload("res://scripts/ui.gd")
const Settings := preload("res://scripts/settings.gd")

const CARD_W := 1.0
const CARD_H := 1.4
const CARD_T := 0.018
const FACE_PX := Vector2i(600, 840)
const FAN_DEG := 12.0
const PIVOT := Vector3(0, -4.6, 0)
const RADIUS := 3.35
const CREAM := Color("f6f1e6")
const EDGE := Color("d9cfba")
const GOLD := Color("ffd23f")

## The towers, left to right. "site" is the run it lives in (main.gd builds one site per run).
const TOWERS := [
	{"id": "water", "site": "riverlight", "kit": "tutorial", "code": "WT", "suit": "drop", "suit_col": Color("2e7d6b"),
		"kind": "TUTORIAL", "name": "WATER TOWER", "place": "Your first job · a round tank on a shaft",
		"chips": ["2 POURS", "1 CLIMB", "GUIDED"], "art": "res://assets/cards/art_water.jpg",
		"caption": "WATER TOWER · HAMILTON · YOUR FIRST JOB"},
	{"id": "riverlight", "site": "riverlight", "kit": "tower", "code": "RL", "suit": "wave", "suit_col": Color("1f5f8b"),
		"kind": "HAMILTON", "name": "RIVERLIGHT", "place": "Hamilton Reach, Brisbane · 2016-2018",
		"chips": ["11 LEVELS", "BOOM CLIMBS", "WEST WING CREW"], "art": "res://assets/cards/art_riverlight.jpg",
		"caption": "RIVERLIGHT · HAMILTON REACH · 11 LEVELS"},
	{"id": "spire", "site": "spire", "kit": "tower", "code": "SP", "suit": "spire", "suit_col": Color("b5553a"),
		"kind": "CBD", "name": "SPIRE", "place": "550 Queen St, Brisbane · 2015-2018",
		"chips": ["34 POURS", "L6 TRANSFER", "2 BOOMS"], "art": "res://assets/cards/art_spire.jpg",
		"caption": "SPIRE · 550 QUEEN ST · L6 TRANSFER SLAB"},
]

## The card being played, carried over the reload to the other site: main.gd flies there, then the
## crew page. Empty when there's nothing to fly.
static var arrival := {}
## The card the hand last had up (it comes back to it)
static var last_focus := -1

var game = null
var focus := 1
var _f := 1.0                 # the fan's focus, eased towards `focus`
var _cool := 0.0
var _busy := false
var _t := 0.0
var _deal_t := 0.0            # the deal: face down in from below, then each flips
var _cards: Array = []        # {node, face, back, outline}
var _vp: SubViewport
var _cam: Camera3D
var _prompts: Control
var _title: Label
var _play_t := -1.0           # playing the focused card
var _zoom: TextureRect        # its picture, growing to fill the screen

signal picked(card: Dictionary)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var site: String = game.site if game != null else "riverlight"
	if last_focus >= 0:
		focus = last_focus
	else:
		focus = 2 if site == "spire" else (1 if Settings.value("tut_done") else 0)
	_f = float(focus)
	# the cards' own little world, drawn over the game
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(_vp)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 0, 6.0)
	_cam.fov = 40.0
	_vp.add_child(_cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	_vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 0.96, 0.9)
	env.environment.ambient_light_energy = 0.75
	_vp.add_child(env)
	# a shadow catcher for the hand (the cards cast onto it, nothing else draws)
	var back := _back_texture()
	for i in TOWERS.size():
		_cards.append(_make_card(TOWERS[i], back))
	# title and prompts
	_title = UI.head("PICK A TOWER", 44, Color("f4f2ec"), 8)
	_title.add_theme_font_override("font", UI.font("head"))
	add_child(_title)
	UI.place(_title, Vector2(0, 0), Vector2(44, 30))
	_prompts = HBoxContainer.new()
	_prompts.add_theme_constant_override("separation", 14)
	add_child(_prompts)
	UI.place(_prompts, Vector2(1, 0), Vector2(-40, 34))
	_prompts.add_child(_prompt("◀▶", "FAN THROUGH"))
	_prompts.add_child(_prompt("A", "PLAY THIS CARD"))
	_zoom = TextureRect.new()
	_zoom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_zoom.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_zoom.visible = false
	_zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_zoom)
	_layout(0.0)

func _prompt(key: String, text: String) -> Control:
	var pill := UI.pill(Color(0.06, 0.07, 0.09, 0.78), Vector4(8, 5, 16, 5))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pill.add_child(h)
	h.add_child(UI.glyph(key, 26) if key.length() == 1 else UI.head(key, 26, GOLD))
	var l := UI.head(text, 26, Color("f4f2ec"))
	h.add_child(l)
	return pill

# ------------------------------------------------------------------ the cards

## A rounded rectangle (card units, centred), corner radius r.
static func _round_rect(w: float, h: float, r: float, seg := 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cs := [Vector2(w * 0.5 - r, h * 0.5 - r), Vector2(-w * 0.5 + r, h * 0.5 - r), Vector2(-w * 0.5 + r, -h * 0.5 + r), Vector2(w * 0.5 - r, -h * 0.5 + r)]
	for c in 4:
		for s in seg + 1:
			var a := PI * 0.5 * c + PI * 0.5 * s / seg
			out.append(cs[c] + Vector2(cos(a), sin(a)) * r)
	return out

## A flat mesh of a rounded card outline at depth z, facing +z (or -z), UVs over the card.
static func _face_mesh(w: float, h: float, r: float, z: float, front: bool) -> ArrayMesh:
	var poly := _round_rect(w, h, r)
	var tris := Geometry2D.triangulate_polygon(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var order := [0, 2, 1] if front else [0, 1, 2]     # (Godot's front faces wind clockwise)
	for i in range(0, tris.size(), 3):
		for o in order:
			var p: Vector2 = poly[tris[i + o]]
			st.set_normal(Vector3(0, 0, 1 if front else -1))
			st.set_uv(Vector2(p.x / w + 0.5 if front else 0.5 - p.x / w, 0.5 - p.y / h))
			st.add_vertex(Vector3(p.x, p.y, z))
	return st.commit()

## The card stock round the edge: a band between the two faces.
static func _edge_mesh(w: float, h: float, r: float, t: float) -> ArrayMesh:
	var poly := _round_rect(w, h, r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := poly.size()
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var nrm := Vector3(b.y - a.y, -(b.x - a.x), 0).normalized()
		for v in [Vector3(a.x, a.y, t * 0.5), Vector3(b.x, b.y, t * 0.5), Vector3(b.x, b.y, -t * 0.5),
				Vector3(a.x, a.y, t * 0.5), Vector3(b.x, b.y, -t * 0.5), Vector3(a.x, a.y, -t * 0.5)]:
			st.set_normal(nrm)
			st.add_vertex(v)
	return st.commit()

func _make_card(c: Dictionary, back_tex: Texture2D) -> Dictionary:
	var node := Node3D.new()
	_vp.add_child(node)
	var r := 0.06
	var face_vp := _face_viewport(c)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = face_vp.get_texture()
	fm.roughness = 0.25          # (glossy card stock)
	fm.metallic_specular = 0.6
	var face := MeshInstance3D.new()
	face.mesh = _face_mesh(CARD_W, CARD_H, r, CARD_T * 0.5, true)
	face.material_override = fm
	node.add_child(face)
	var bm := StandardMaterial3D.new()
	bm.albedo_texture = back_tex
	bm.roughness = 0.3
	var back := MeshInstance3D.new()
	back.mesh = _face_mesh(CARD_W, CARD_H, r, -CARD_T * 0.5, false)
	back.material_override = bm
	node.add_child(back)
	var em := StandardMaterial3D.new()
	em.albedo_color = EDGE
	em.cull_mode = BaseMaterial3D.CULL_DISABLED
	var edge := MeshInstance3D.new()
	edge.mesh = _edge_mesh(CARD_W, CARD_H, r, CARD_T)
	edge.material_override = em
	node.add_child(edge)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = GOLD
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var outline := MeshInstance3D.new()
	outline.mesh = _face_mesh(CARD_W + 0.06, CARD_H + 0.06, r + 0.03, -CARD_T * 0.5 - 0.002, true)
	outline.material_override = gm
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(outline)
	var dim := MeshInstance3D.new()           # the side cards are dimmed about 35%
	dim.mesh = _face_mesh(CARD_W, CARD_H, r, CARD_T * 0.5 + 0.002, true)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.05, 0.06, 0.08, 0.35)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dim.material_override = dmat
	dim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(dim)
	return {"node": node, "outline": outline, "dim": dim, "dmat": dmat, "vp": face_vp, "card": c}

## A card's face, drawn once by a little 2D page into a texture.
func _face_viewport(c: Dictionary) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = FACE_PX
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var s := float(FACE_PX.x) / 300.0          # (laid out at 300 x 420, drawn at twice that)
	var root := Control.new()
	root.size = Vector2(FACE_PX)
	vp.add_child(root)
	var bg := ColorRect.new()
	bg.color = CREAM
	bg.size = Vector2(FACE_PX)
	root.add_child(bg)
	var v := VBoxContainer.new()
	v.position = Vector2(16, 12) * s
	v.size = Vector2(300 - 32, 420 - 24) * s
	v.add_theme_constant_override("separation", int(6 * s))
	root.add_child(v)
	# corner row: suit + code, kind on the right
	var row := HBoxContainer.new()
	v.add_child(row)
	var suit := Suit.new()
	suit.kind = c["suit"]
	suit.color = c["suit_col"]
	suit.custom_minimum_size = Vector2(22, 22) * s
	row.add_child(suit)
	var code := UI.head(" " + c["code"], int(22 * s), c["suit_col"])
	row.add_child(code)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	row.add_child(UI.head(c["kind"], int(15 * s), Color("8a8270")))
	# the picture window
	var pic := Panel.new()
	pic.custom_minimum_size = Vector2(268, 176) * s
	pic.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color.WHITE
	psb.set_corner_radius_all(int(10 * s))
	pic.add_theme_stylebox_override("panel", psb)
	v.add_child(pic)
	var art := TextureRect.new()
	art.texture = load(c["art"])
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size = Vector2(268, 176) * s
	pic.add_child(art)
	# name, place, chips
	var nm := UI.head(c["name"], int(40 * s), Color("1d2023"))
	v.add_child(nm)
	var pl := UI.label(c["place"], int(13 * s), Color("5f5a4e"), 0)
	v.add_child(pl)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", int(5 * s))
	v.add_child(chips)
	for ch in c["chips"]:
		var p := UI.pill(Color("23262d"), Vector4(7, 2, 8, 2) * s)
		p.add_child(UI.head(ch, int(13 * s), GOLD))
		chips.add_child(p)
	# medals and the status stamp
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", int(6 * s))
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(bottom)
	var pr: Array = _progress(c)
	for m in pr[0]:
		var md := Medal.new()
		md.tier = m
		md.custom_minimum_size = Vector2(24, 24) * s
		md.size_flags_vertical = Control.SIZE_SHRINK_END
		bottom.add_child(md)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp2)
	var stamp := UI.pill(Color(0, 0, 0, 0), Vector4(8, 1, 8, 1) * s, pr[2], int(3 * s))
	stamp.add_child(UI.head(pr[1], int(17 * s), pr[2]))
	stamp.rotation = -0.09
	stamp.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(stamp)
	return vp

## [the best three medals (2 gold, 1 silver, 0 bronze, -1 none), the stamp's text, its colour]
func _progress(c: Dictionary) -> Array:
	if c["id"] == "water":
		var done: bool = Settings.value("tut_done")
		return [[-1, -1, -1], "DONE" if done else "NOT STARTED", Color("2e8f5a") if done else Color("8a8d97")]
	var key := "medals_spire" if c["site"] == "spire" else "medals"
	var m = Settings.value(key)
	var arr: Array = m if m is Array else []
	var got: Array = []
	var far := -1
	for i in arr.size():
		if int(arr[i]) >= 0:
			got.append(int(arr[i]))
			far = i
	got.sort()
	got.reverse()
	var best: Array = []
	for i in 3:
		best.append(got[i] if i < got.size() else -1)
	var total := 34 if c["site"] == "spire" else 11
	if far < 0:
		return [best, "NOT STARTED", Color("8a8d97")]
	if far >= total - 1:
		return [best, "TOPPED OUT", Color("2e8f5a")]
	var lv := "L%02d" % (far + 7) if c["site"] == "spire" else "LEVEL %d" % (far + 2)
	return [best, lv, Color("1f5f8b")]

## The back: navy stripes, a gold border, a round PD badge, POUR DECISIONS.
func _back_texture() -> Texture2D:
	var vp := SubViewport.new()
	vp.size = FACE_PX
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var b := CardBack.new()
	b.size = Vector2(FACE_PX)
	vp.add_child(b)
	return vp.get_texture()

# ------------------------------------------------------------------ the fan

func _layout(delta: float) -> void:
	_f = lerpf(_f, float(focus), minf(1.0, delta * 9.0)) if delta > 0.0 else _f
	var deal := clampf(_deal_t / 1.2, 0.0, 1.0)
	for i in _cards.size():
		var c: Dictionary = _cards[i]
		var n: Node3D = c["node"]
		var d := float(i) - _f
		var on := clampf(1.0 - absf(d), 0.0, 1.0)          # 1 on the focused card
		var a := deg_to_rad(-d * FAN_DEG)
		var p := PIVOT + Vector3(-sin(a) * RADIUS, cos(a) * RADIUS, -absf(d) * 0.06)
		p.y += on * 0.42
		p.z += on * 0.25
		# the deal: each card up from below in turn, face down, then it flips
		var di := clampf(deal * 1.6 - i * 0.25, 0.0, 1.0)
		p.y -= (1.0 - ease(di, -2.0)) * 3.5
		var flip := clampf(_deal_t - 1.2 - i * 0.18, 0.0, 0.45) / 0.45
		var spin := PI * (1.0 - ease(flip, -2.0))
		var s := lerpf(1.0, 1.18, on)
		if _play_t >= 0.0:
			if i == focus:
				var u := clampf(_play_t / 0.7, 0.0, 1.0)
				p = p.lerp(Vector3(0, 0.15, 2.6), ease(u, -2.0))
				spin += TAU * ease(u, -1.6)
				s = lerpf(s, 1.6, u)
			else:
				p.y -= ease(clampf(_play_t / 0.5, 0.0, 1.0), 2.0) * 4.0
		n.position = p
		n.rotation = Vector3(0, spin, a * (1.0 - on))
		n.scale = Vector3.ONE * s
		(c["outline"] as Node3D).visible = on > 0.6 and flip >= 1.0 and _play_t < 0.0
		(c["dmat"] as StandardMaterial3D).albedo_color.a = 0.35 * (1.0 - on)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var was := _deal_t
	_deal_t += delta
	for i in _cards.size():
		var at := 1.2 + i * 0.18
		if was < at and _deal_t >= at and game != null:
			game.sfx.hit("tink")       # (each card's flip)
	if _play_t >= 0.0:
		_play_t += delta
		_play_step()
	_layout(delta)
	_title.modulate.a = 1.0 if _play_t < 0.0 else maxf(0.0, 1.0 - _play_t * 3.0)
	_prompts.modulate.a = _title.modulate.a

## Dev: `--pickshots=<dir>` saves the hand, the focused card, then plays Spire's card and saves the
## flight and the arrival (main.gd), then quits.
static var shots := ""
static var _demo_began := false
var _demo_t := 0.0
var _demo_i := 0

static func shot(name: String, vp: Viewport) -> void:
	if shots == "":
		return
	vp.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	print("[pickshots] " + name)

func _demo(delta: float) -> void:
	if not _demo_began:
		_demo_began = true
		if game != null and game.site != "riverlight":
			Settings.put("site", "riverlight")
			get_tree().reload_current_scene()
			return
	if _demo_t == 0.0:
		focus = 1
		_f = 1.0
	_demo_t += delta
	if _demo_i == 0 and _demo_t > 3.5:
		_demo_i = 1
		shot("pick_hand", get_viewport())
		focus = 2
		game.sfx.hit("clank")
	elif _demo_i == 1 and _demo_t > 4.6:
		_demo_i = 2
		shot("pick_focus", get_viewport())
		play()

## One frame of input from the crew (stick, A); select.gd calls it while the hand is up.
func step(delta: float, mv: Vector2, pressed: bool) -> void:
	if shots == "":
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--pickshots="):
				shots = a.substr(12)
	if shots != "" and not _busy:
		_demo(delta)
		return
	_cool = maxf(0.0, _cool - delta)
	if _busy or _deal_t < 1.0:
		return
	if _cool <= 0.0 and absf(mv.x) > 0.5:
		var nf := clampi(focus + int(signf(mv.x)), 0, TOWERS.size() - 1)
		if nf != focus:
			focus = nf
			last_focus = nf
			if game != null:
				game.sfx.hit("clank")   # (the card snap)
		_cool = 0.25
	elif _cool <= 0.0 and pressed:
		play()

## Plays the focused card: out of the hand, face-on, then into its picture.
func play() -> void:
	if _busy:
		return
	_busy = true
	_play_t = 0.0
	last_focus = focus
	if game != null:
		game.sfx.hit("thunk")

func _play_step() -> void:
	var c: Dictionary = TOWERS[focus]
	if _play_t >= 0.7 and not _zoom.visible:
		# into the picture: it grows from the card's window to the whole screen
		_zoom.texture = load(c["art"])
		_zoom.visible = true
		var ss := get_viewport_rect().size
		var w := ss.y * 0.36
		_zoom.position = ss * 0.5 - Vector2(w * 0.8, w * 0.75)
		_zoom.size = Vector2(w * 1.6, w)
		_zoom.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_zoom, "modulate:a", 1.0, 0.15)
		tw.tween_property(_zoom, "position", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(_zoom, "size", ss, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if _play_t >= 1.4 and _play_t - get_process_delta_time() < 1.4:
		arrival = {"card": c, "t": 0.0}
		picked.emit(c)

## The played card's picture, full screen, on the tree's root: it stays up over a reload to the other
## site, and main.gd fades it as the flight starts (uncover).
static var _cover: CanvasLayer

static func cover(tree: SceneTree, c: Dictionary) -> void:
	if _cover != null and is_instance_valid(_cover):
		_cover.queue_free()
	_cover = CanvasLayer.new()
	_cover.layer = 90
	var pic := TextureRect.new()
	pic.texture = load(c["art"])
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.add_child(pic)
	tree.root.add_child(_cover)

## Fades the cover out (0 shown .. 1 gone).
static func uncover(f: float) -> void:
	if _cover == null or not is_instance_valid(_cover):
		return
	if f >= 1.0:
		_cover.queue_free()
		_cover = null
		return
	(_cover.get_child(0) as CanvasItem).modulate.a = 1.0 - f

# ------------------------------------------------------------------ drawn bits

## A suit mark: a water drop, a river wave, or a spire.
class Suit extends Control:
	var kind := "drop"
	var color := Color.BLACK
	func _draw() -> void:
		var s := size
		match kind:
			"drop":
				var pts := PackedVector2Array()
				for k in 24:
					var a := PI * 0.5 + TAU * k / 24.0
					var r := 0.32 * s.x
					var p := Vector2(cos(a) * r, sin(a) * r) + Vector2(s.x * 0.5, s.y * 0.62)
					if sin(a) < -0.2:
						p = p.lerp(Vector2(s.x * 0.5, 0.0), clampf(-sin(a) - 0.2, 0.0, 1.0) * 1.2)
					pts.append(p)
				draw_colored_polygon(pts, color)
			"wave":
				for row in 2:
					var pts2 := PackedVector2Array()
					for k in 13:
						var x := s.x * k / 12.0
						pts2.append(Vector2(x, s.y * (0.38 + 0.3 * row) + sin(k * 0.9) * s.y * 0.1))
					draw_polyline(pts2, color, s.y * 0.13, true)
			_:
				draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.5, 0), Vector2(s.x * 0.86, s.y), Vector2(s.x * 0.14, s.y)]), color)

## A medal circle: gold, silver, bronze, or an empty rim.
class Medal extends Control:
	var tier := -1
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.46
		if tier < 0:
			draw_arc(c, r, 0, TAU, 32, Color("c9bfa8"), r * 0.2, true)
		else:
			var col: Color = [Color("c98a4b"), Color("c3cad3"), Color("f2c230")][clampi(tier, 0, 2)]
			draw_circle(c, r, col)
			draw_arc(c, r * 0.72, 0, TAU, 32, col.darkened(0.25), r * 0.12, true)

## The card back: navy diagonal stripes, a gold border, a round PD badge, POUR DECISIONS.
class CardBack extends Control:
	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color("24314a"))
		var w := s.x * 0.06
		var x := -s.y
		while x < s.x:
			draw_colored_polygon(PackedVector2Array([Vector2(x, s.y), Vector2(x + w, s.y), Vector2(x + w + s.y, 0), Vector2(x + s.y, 0)]), Color("2b3a57"))
			x += w * 2.0
		var m := s.x * 0.06
		draw_rect(Rect2(Vector2(m, m), s - Vector2(m, m) * 2.0), Color("ffd23f"), false, s.x * 0.018)
		var c := s * 0.5
		draw_circle(c, s.x * 0.2, Color("ffd23f"))
		draw_circle(c, s.x * 0.17, Color("24314a"))
		var f: Font = load("res://scripts/ui.gd").font("head")
		var fs := int(s.x * 0.14)
		var tw: float = f.get_string_size("PD", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-tw * 0.5, fs * 0.36), "PD", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffd23f"))
		var fs2 := int(s.x * 0.075)
		var t2 := "POUR DECISIONS"
		var w2: float = f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_string(f, Vector2(c.x - w2 * 0.5, s.y * 0.8), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color("ffd23f"))
