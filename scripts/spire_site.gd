## Spire Residences, 550 Queen St, Brisbane: the playable tower from L6 (the 1250 mm transfer slab) to
## the roof, 34 pours. Data and model come from the Blender build (tools/blender/spire/export_game.py:
## data/spire_site.json, assets/spire/spire_site.glb).
##
## Each level has two pours split by a construction joint round the core. The players (bots fill any
## empty jobs) pour the Ann St side, pour A, with their boom; at the same time a bot crew pours pour B
## with the other Schwing KVM 26 (spire_bots: a cheap fill, paced by the players' pour). Both finish,
## then the deck goes up a floor and the core's jump form jumps (it stays LEAD levels ahead).
##
## The game's frame: the site is turned so Ann St runs along the game's street (x) with the lot on its
## -z side, and slid so the players' boom tower (main.LAT_X, 0, 0) stands at the Ann St face of pour A.
## Then the pump, the hopper and the trucks (line.gd, which stay where Riverlight has them) land on the
## Ann St footpath and kerb lane, outside the Ann St gate, the way the real job fed the pump. y is metres
## above the Ann St kerb at the gate.
extends RefCounted

const F := preload("res://scripts/factory.gd")
const DATA := "res://data/spire_site.json"
const ANN_ST_Z := 4.5          # game z of the Ann St boundary (the pump's nose is on it)
const TOWER := Vector2(12.0, 0.0)   # main.LAT_X: the players' boom tower

static var d := {}
static var th := 0.0           # local -> game rotation
static var off := Vector2.ZERO
static var street := 0.0       # AHD of the Ann St kerb at the gate (game y 0)

## Loads the data and works out the frame. False if the data is missing.
static func setup() -> bool:
	if not d.is_empty():
		return true
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f == null:
		push_error("Spire: %s missing (run tools/blender/spire/export_game.py)" % DATA)
		return false
	d = JSON.parse_string(f.get_as_text())
	var along: Array = d["truck_gate"]["along"]
	th = atan2(float(along[1]), -float(along[0]))
	street = float(d.get("street_ahd", d["ground_ahd"]))
	off = Vector2.ZERO
	var gate := g(d["truck_gate"]["xy"])
	off.y = ANN_ST_Z - gate.y
	# the players' tower at the middle of pour A's Ann St face, a little in from the edge
	var a := poly("A")
	var zmax := -1e9
	for p in a:
		zmax = maxf(zmax, p.y)
	var xs := []
	for p in a:
		if p.y > zmax - 3.0:
			xs.append(p.x)
	var mid := (float(xs.min()) + float(xs.max())) * 0.5
	off.x = TOWER.x - mid
	return true

## Local metres (x east, y north) -> game x/z.
static func g(p) -> Vector2:
	var x := float(p[0])
	var y := float(p[1])
	var rx := x * cos(th) - y * sin(th)
	var ry := x * sin(th) + y * cos(th)
	return Vector2(rx + off.x, -ry + off.y)

static func poly(key: String) -> PackedVector2Array:
	var src: Array = d["pours"][key] if key in ["A", "B"] else d[key]
	var out := PackedVector2Array()
	for p in src:
		out.append(g(p))
	if Geometry2D.is_polygon_clockwise(out):
		out.reverse()
	return out

static func levels() -> Array:
	return d["levels"]

static func level_name(i: int) -> String:
	var lv: Array = d["levels"]
	return String(lv[clampi(i, 0, lv.size() - 1)]["name"])

static func is_transfer(i: int) -> bool:
	return String(d["levels"][clampi(i, 0, d["levels"].size() - 1)]["kind"]) == "transfer"

## Game y of the top of the slab poured at playable level i (0 = L6).
static func top_y(i: int) -> float:
	var lv: Array = d["levels"]
	return float(lv[clampi(i, 0, lv.size() - 1)]["top_ahd"]) - street

static func centroid(pp: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pp:
		c += p
	return c / maxf(1.0, pp.size())

## The camera's yaw for the players' pour: looking across pour A from its far side towards the core,
## so the core and its jump form stand behind the slab, never in front of it.
static func cam_yaw() -> float:
	var a := centroid(poly("A"))
	var c := centroid(poly("core"))
	var v := a - c            # from the core out over pour A: the camera sits out along it
	return atan2(v.x, v.y)

## Everything round the tower: the Blender model, turned and slid into the game's frame.
static func build_world(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "SpireSite"
	var scene = load(String(d["model"]["glb"]))
	if scene is PackedScene:
		var m: Node3D = scene.instantiate()
		m.rotation.y = th
		_tint(m)
		root.add_child(m)
		# glTF y-up: (x, ahd, -y). A turn of th about y maps it onto the game's frame
		root.position = Vector3(off.x, -street, off.y)
	else:
		push_warning("Spire: the site model hasn't been imported yet (open the project in the editor once)")
	parent.add_child(root)
	return root

## glTF carries only the clay colours: the bare ground reads as a grey slab. Ground goes the game's
## park green, rock a warm sandstone, water the river's blue-green.
static func _tint(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat is BaseMaterial3D:
				var nm := String(mat.resource_name)
				var col := Color(-1, 0, 0)
				if nm == "clay_ground" or nm == "far_land":
					col = Color("7f9a5c")
				elif nm == "clay_rock":
					col = Color("b49a76")
				elif nm == "clay_water":
					col = Color("3f6f78")
				if col.r >= 0.0:
					var m2 := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					m2.albedo_color = col
					if nm == "clay_water":
						m2.roughness = 0.08
						m2.metallic_specular = 0.9
					mi.set_surface_override_material(s, m2)
	for c in n.get_children():
		_tint(c)

# ------------------------------------------------------------------ the tower as it climbs

## One finished level of the whole plate (both pours), with the core opening, edge columns and
## the dark open frame of the storey under it.
static func floor_slab(parent: Node3D, slab_y: float, thick: float, ftf: float) -> void:
	var plate := poly("plate")
	var core := poly("core")
	var parts: Array = Geometry2D.clip_polygons(plate, core)
	var grey := F.color_mat(Color("b5b6b3"))
	for part in parts:
		parent.add_child(F.prism(part, slab_y - thick, thick, grey))
	var inset: Array = Geometry2D.offset_polygon(plate, -1.2)
	if not inset.is_empty():
		parent.add_child(F.prism(inset[0], slab_y - thick - ftf + 0.02, ftf - thick - 0.04, F.color_mat(Color("3a3f45")), false))

## The core: walls from the podium roof up to `top_y`, and the jump form's screened rig round its top.
static func build_core(parent: Node3D) -> Dictionary:
	var core := poly("core")
	var walls := Node3D.new()
	walls.name = "SpireCore"
	parent.add_child(walls)
	var rig := Node3D.new()
	rig.name = "JumpForm"
	parent.add_child(rig)
	var out: Array = Geometry2D.offset_polygon(core, float(d["jump_form"]["rig_out_m"]))
	var ring: PackedVector2Array = out[0] if not out.is_empty() else core
	var screen := F.color_mat(Color("e6e2d4"))
	var n := ring.size()
	for j in n:
		var a: Vector2 = ring[j]
		var b: Vector2 = ring[(j + 1) % n]
		var mid := (a + b) * 0.5
		var s := F.box(Vector3(a.distance_to(b), 1.0, 0.12), screen, Vector3(mid.x, 0.5, mid.y))
		s.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		rig.add_child(s)
	var lab := F.label3d("JUMP FORM", 56, Color("1d2023"))
	lab.name = "Label"
	rig.add_child(lab)
	return {"walls": walls, "rig": rig, "core": core, "ring": ring}

## Sets the core's height: walls up to `top`, the rig over the top `rig_levels` storeys.
static func set_core(parts: Dictionary, bottom: float, top: float, ftf: float) -> void:
	var walls: Node3D = parts["walls"]
	for c in walls.get_children():
		c.queue_free()
	var core: PackedVector2Array = parts["core"]
	var inner: Array = Geometry2D.offset_polygon(core, -float(d["core_wall_m"]))
	var mat := F.mat("core")
	var cut: Array = Geometry2D.clip_polygons(core, inner[0]) if not inner.is_empty() else [core]
	for piece in cut:
		walls.add_child(F.prism(piece, bottom, top - bottom, mat))
	var rig: Node3D = parts["rig"]
	var rig_h := ftf * float(d["jump_form"]["rig_levels"]) + 1.5
	rig.position.y = top - rig_h + 1.5
	rig.scale.y = rig_h
	var lab: Label3D = rig.get_node("Label")
	lab.scale.y = 1.0 / rig_h
	lab.position = Vector3(centroid(core).x, 1.0 + 0.4 / rig_h, centroid(core).y)

# ------------------------------------------------------------------ the bot crew's pour B

## Pour B's deck, its concrete (a cheap fill that sweeps across it), the parked/live second boom and
## a few bot figures. Returns the parts; update with bot_update().
static func build_bots(parent: Node3D) -> Dictionary:
	var b := poly("B")
	var root := Node3D.new()
	root.name = "PourB"
	parent.add_child(root)
	var deck := F.prism(b, -0.12, 0.12, F.mat("ply"))
	root.add_child(deck)
	var conc := Node3D.new()
	conc.name = "Concrete"
	root.add_child(conc)
	# strips across B along its long axis: each fills in turn as their pour goes
	var bb := Rect2(b[0], Vector2.ZERO)
	for p in b:
		bb = bb.expand(p)
	var strips := []
	var n := 10
	var long_x := bb.size.x >= bb.size.y
	for s in n:
		var t0 := float(s) / n
		var t1 := float(s + 1) / n
		var cut: PackedVector2Array
		if long_x:
			cut = PackedVector2Array([Vector2(bb.position.x + bb.size.x * t0, bb.position.y - 1), Vector2(bb.position.x + bb.size.x * t1, bb.position.y - 1),
				Vector2(bb.position.x + bb.size.x * t1, bb.end.y + 1), Vector2(bb.position.x + bb.size.x * t0, bb.end.y + 1)])
		else:
			cut = PackedVector2Array([Vector2(bb.position.x - 1, bb.position.y + bb.size.y * t0), Vector2(bb.end.x + 1, bb.position.y + bb.size.y * t0),
				Vector2(bb.end.x + 1, bb.position.y + bb.size.y * t1), Vector2(bb.position.x - 1, bb.position.y + bb.size.y * t1)])
		var piece := Node3D.new()
		for part in Geometry2D.intersect_polygons(b, cut):
			piece.add_child(F.prism(part, 0.0, 0.25, F.color_mat(Color("8e8f8b"))))
		piece.visible = false
		conc.add_child(piece)
		strips.append(piece)
	# their boom: a KVM 26 on its pedestal through the deck (the real job had one per pour area)
	var bp := g(d["booms"][1]["xy"])
	var boom := Node3D.new()
	boom.name = "BoomB"
	boom.position = Vector3(bp.x, 0, bp.y)
	root.add_child(boom)
	var mast := F.cylinder(0.45, 1.0, F.mat("orange"), Vector3.ZERO, 10)
	mast.name = "Mast"
	boom.add_child(mast)
	var turret := Node3D.new()
	turret.name = "Turret"
	boom.add_child(turret)
	turret.add_child(F.box(Vector3(1.6, 1.2, 1.6), F.mat("orange"), Vector3(0, 0.6, 0)))
	var arm := Node3D.new()
	arm.name = "Arm"
	turret.add_child(arm)
	arm.add_child(F.beam(Vector3(0, 1.4, 0), Vector3(12.0, 4.2, 0), 0.32, F.mat("orange")))
	arm.add_child(F.beam(Vector3(12.0, 4.2, 0), Vector3(22.0, 1.6, 0), 0.26, F.mat("orange")))
	arm.add_child(F.beam(Vector3(22.0, 1.6, 0), Vector3(22.0, -1.2, 0), 0.12, F.mat("hose")))
	var lab := F.label3d("POUR B · BOT CREW", 40, Color("ffc72c"))
	lab.position = Vector3(0, 6.0, 0)
	boom.add_child(lab)
	var men := []
	for i in 3:
		var c := F.chibi(Color("ff7a1a"), Color("f4f7fa"))
		root.add_child(c)
		men.append(c)
	return {"root": root, "strips": strips, "boom": boom, "turret": turret, "men": men, "bb": bb, "long_x": long_x, "poly": b}

## Their pour follows ours (`frac`, 0..1): strips fill in turn, the boom slews to the strip being
## poured and the crew works along its front. `deck_y` is the deck's top this level.
static func bot_update(p: Dictionary, deck_y: float, frac: float, t: float, mast_base: float) -> void:
	var root: Node3D = p["root"]
	root.position.y = deck_y
	var strips: Array = p["strips"]
	var n := strips.size()
	var lit := clampi(int(frac * n + 0.0001), 0, n)
	for i in n:
		(strips[i] as Node3D).visible = i < lit or (i == lit and frac > 0.0 and frac < 1.0 and fmod(t, 0.6) < 0.3)
	var bb: Rect2 = p["bb"]
	var u := clampf(frac, 0.0, 1.0)
	var front := Vector2(bb.position.x + bb.size.x * u, bb.get_center().y) if p["long_x"] else Vector2(bb.get_center().x, bb.position.y + bb.size.y * u)
	var boom: Node3D = p["boom"]
	var mast: Node3D = boom.get_node("Mast")
	var h := deck_y - mast_base
	mast.scale.y = maxf(0.1, h + 2.5)
	mast.position.y = -h * 0.5 + 1.25
	var turret: Node3D = p["turret"]
	turret.position.y = 2.5
	var to := front + Vector2(sin(t * 0.7) * 3.0, cos(t * 0.5) * 2.0) - Vector2(boom.position.x, boom.position.z)
	var want := atan2(-to.y, to.x)
	turret.rotation.y = lerp_angle(turret.rotation.y, want, 0.05)
	var men: Array = p["men"]
	for i in men.size():
		var m: Node3D = men[i]
		var s := float(i) - 1.0
		var at := front + (Vector2(0, s * 3.0) if p["long_x"] else Vector2(s * 3.0, 0)) + Vector2(sin(t + i) * 0.6, cos(t * 1.3 + i) * 0.6)
		if not Geometry2D.is_point_in_polygon(at, p["poly"]):
			at = front
		m.position = Vector3(at.x, 0.0, at.y)
