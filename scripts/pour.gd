## The slab pour. Fresh concrete lives in a heightfield over the formwork deck:
## the boom drops it in a mound, the mound slumps while it is steeper than the
## concrete can stand, then keeps seeping outward slowly until it is level.
##
## Each cell also tracks how long its concrete has been placed. Past the open
## time it goes off: it stops flowing, and fresh concrete placed against it
## leaves a cold joint (a weak seam). That's why crews pour to a plan in bays,
## from the far end back toward the boom, keeping a wet edge. Concrete also has
## to be vibrated with the poker; any that goes off unvibrated is honeycombed.
##
## Also builds the deck itself: plywood, edge forms, two rebar mats on bar
## chairs, and starter bars poking up for the next level's columns.
extends Node3D

const F := preload("res://scripts/factory.gd")
const SURFACE := preload("res://shaders/concrete.gdshader")

## Grid size: 48 x 36 on the old 16 x 12 slab; bigger slabs get coarser cells
## so the grid stays near MAX_CELLS (it's stepped every frame in GDScript)
var NX := 48
var NZ := 36
const CELL_MIN := 1.0 / 3.0   # m, the finest cell
const MAX_CELLS := 4200
const SLAB := 0.25        # finished slab thickness, m
const FORM_H := 0.45      # edge form height; concrete above it spills over
const REPOSE := 0.24      # steepest slope (rise/run) fresh concrete holds
const SLUMP_K := 11.0     # how fast it slumps when steeper than that
const SEEP_K := 0.22      # slow self-levelling seep below that slope
const SEEP_MIN := 0.07    # thinner than this and it stops creeping
const SPLASH := 0.42      # m, spread of the hose discharge where it lands
const BAR := 0.045        # drawn rebar thickness (chunkier than real N16 so it reads)
var BAYS := 4             # pour plan: bays from the far end back to the boom
const SET_MIN_H := 0.08   # thinner than this doesn't count as having gone off
const COLD_RISE := 0.05   # fresh concrete this deep over gone-off concrete = cold joint
const DONE := 0.85        # vibrated enough: the poker's job is done here

var bw := 16.0
var bd := 12.0
var dx := 1.0 / 3.0
## A bigger slab than the old 16 x 12 takes the same truckloads in the same
## time (game m³ are game scale): each game m³ out of the hose covers this
## many times more deck, landing in a wider spread to match.
var vol_k := 1.0
var splash_r := SPLASH
var h := PackedFloat32Array()
var age := PackedFloat32Array()
var set_h := PackedFloat32Array()    # -1 while workable, else its height when it went off
var cold := PackedByteArray()
var vib := PackedFloat32Array()
var reach := PackedByteArray()       # 1 where the boom can put the hose
var bleed := PackedByteArray()       # 1 where it was over-vibrated
var scr := PackedFloat32Array()      # 0..1, how well it's been screeded flat
var shiver := PackedVector4Array()   # pokers in the concrete right now: x, z, strength, 0
var edge_left := 99.0     # s before the oldest workable concrete goes off
var at_risk := 0.0        # share of the slab about to go off un-vibrated
var open_time := 35.0
var raining := false
var poured := 0.0         # m³ out of the hose this level
var spilled := 0.0        # m³ over the edge forms
var out_of_seq := 0.0     # m³ placed ahead of the bay being poured
var rain_m3 := 0.0        # m³ placed during heavy rain
var hand_placed := 0      # cells beyond the boom's reach the crew had to place by hand
var cur_bay := 0
var bay_cov: Array[float] = []
var img: Image
var tex: ImageTexture
var state_img: Image
var state_tex: ImageTexture
var _state := PackedByteArray()
var surface: MeshInstance3D
var smat: ShaderMaterial
var rebar: Node3D
var screed_bar: MeshInstance3D
var splash: CPUParticles3D
var bay_box: MeshInstance3D
var bay_label: Label3D
var _kernel: Array = []
var mask := PackedByteArray()        # 1 where there's slab (a round slab leaves the corners out)
var mask_n := NX * NZ
var round_r := 0.0                   # > 0: a round slab of this radius (the water tower)
var _rect_parts: Array = []
var _columns: Array = []
var _flip := false
var _coverage := 0.0
var _reach_cov := 0.0
var _t := 0.0

func build(width: float, depth: float, columns: Array) -> void:
	bw = width
	bd = depth
	dx = maxf(CELL_MIN, sqrt(bw * bd / MAX_CELLS))
	NX = maxi(4, roundi(bw / dx))
	dx = bw / NX
	NZ = maxi(4, roundi(bd / dx))
	mask_n = NX * NZ
	_bay_c1 = NX
	vol_k = maxf(1.0, bw * bd / 192.0)
	splash_r = SPLASH * pow(vol_k, 0.75)
	h.resize(NX * NZ)
	age.resize(NX * NZ)
	set_h.resize(NX * NZ)
	cold.resize(NX * NZ)
	vib.resize(NX * NZ)
	reach.resize(NX * NZ)
	bleed.resize(NX * NZ)
	scr.resize(NX * NZ)
	reach.fill(1)
	mask.resize(NX * NZ)
	mask.fill(1)
	_state.resize(NX * NZ * 4)

	var ply := F.mat("ply")
	_rect_parts.append(F.box(Vector3(bw + 0.6, 0.12, bd + 0.6), ply, Vector3(0, -0.06, 0)))
	var form_mat := F.color_mat(Color("b07a45"))
	var t := 0.05
	_rect_parts.append(F.box(Vector3(bw + 2 * t, FORM_H, t), form_mat, Vector3(0, FORM_H * 0.5, bd * 0.5 + t * 0.5)))
	_rect_parts.append(F.box(Vector3(bw + 2 * t, FORM_H, t), form_mat, Vector3(0, FORM_H * 0.5, -bd * 0.5 - t * 0.5)))
	_rect_parts.append(F.box(Vector3(t, FORM_H, bd), form_mat, Vector3(bw * 0.5 + t * 0.5, FORM_H * 0.5, 0)))
	_rect_parts.append(F.box(Vector3(t, FORM_H, bd), form_mat, Vector3(-bw * 0.5 - t * 0.5, FORM_H * 0.5, 0)))
	for part in _rect_parts:
		add_child(part)

	rebar = Node3D.new()
	add_child(rebar)
	_columns = columns
	_build_rebar(columns)

	# The concrete surface: a fine plane displaced by the heightfield, coloured
	# by the state texture (how long it's been placed, cold joints, vibrated)
	img = Image.create(NX, NZ, false, Image.FORMAT_RF)
	tex = ImageTexture.create_from_image(img)
	state_img = Image.create(NX, NZ, false, Image.FORMAT_RGBA8)
	state_tex = ImageTexture.create_from_image(state_img)
	var pm := PlaneMesh.new()
	pm.size = Vector2(bw, NZ * dx)
	pm.subdivide_width = NX * 2 - 1
	pm.subdivide_depth = NZ * 2 - 1
	surface = MeshInstance3D.new()
	surface.mesh = pm
	smat = ShaderMaterial.new()
	smat.shader = SURFACE
	smat.set_shader_parameter("height_tex", tex)
	smat.set_shader_parameter("state_tex", state_tex)
	smat.set_shader_parameter("cell_m", Vector2(dx, dx))
	smat.set_shader_parameter("slab_size", Vector2(bw, NZ * dx))
	surface.material_override = smat
	surface.custom_aabb = AABB(Vector3(-bw * 0.5, -0.2, -bd * 0.5), Vector3(bw, 2.5, bd))
	add_child(surface)

	# Aluminium screed bar the concreters drag across at the end
	screed_bar = F.box(Vector3(bw + 0.4, 0.08, 0.16), F.color_mat(Color("c9ced4")), Vector3.ZERO)
	screed_bar.visible = false
	add_child(screed_bar)

	# The pour plan on the deck: a bold green line round everything that's
	# been poured so far plus the bay going in now, like a spray-painted line
	bay_box = MeshInstance3D.new()
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line_mat.albedo_color = LINE_GREEN
	bay_box.material_override = _line_mat
	bay_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bay_box)
	# A soft glow either side of it, so it reads from the far side of the room
	_bay_glow = MeshInstance3D.new()
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.albedo_color = Color(LINE_GREEN, 0.28)
	_bay_glow.material_override = _glow_mat
	_bay_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bay_box.add_child(_bay_glow)
	# The joint line across the slab, thin, so it marks the bay without hiding it
	_joint = MeshInstance3D.new()
	_joint.material_override = _line_mat
	_joint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bay_box.add_child(_joint)
	# Footprints left in fresh concrete
	_prints_mm = MultiMesh.new()
	_prints_mm.transform_format = MultiMesh.TRANSFORM_3D
	var pq := QuadMesh.new()
	pq.size = Vector2(0.15, 0.3)
	pq.orientation = PlaneMesh.FACE_Y
	_prints_mm.mesh = pq
	_prints_mm.instance_count = PRINTS_MAX
	_prints_mm.visible_instance_count = 0
	var pmi := MultiMeshInstance3D.new()
	pmi.multimesh = _prints_mm
	var fpm := StandardMaterial3D.new()
	fpm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fpm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fpm.albedo_color = Color(0.22, 0.22, 0.24, 0.65)
	fpm.albedo_texture = _sole_texture()
	pmi.material_override = fpm
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pmi)
	bay_label = F.label3d("BAY 1", 44, Color("7cd992"))
	add_child(bay_label)

	splash = CPUParticles3D.new()
	splash.amount = 70
	splash.lifetime = 0.55
	splash.emitting = false
	splash.direction = Vector3(0, 1, 0)
	splash.spread = 80.0
	splash.initial_velocity_min = 1.2
	splash.initial_velocity_max = 3.2
	splash.gravity = Vector3(0, -12, 0)
	splash.scale_amount_min = 0.5
	splash.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = F.color_mat(Color("6f7276"))
	splash.mesh = sm
	add_child(splash)

	# Discharge kernel: a soft round splat, normalised to 1
	var sum := 0.0
	var kr := maxi(3, ceili(3.0 * splash_r / dx))
	for oz in range(-kr, kr + 1):
		for ox in range(-kr, kr + 1):
			var d2 := (ox * ox + oz * oz) * dx * dx
			var w := exp(-d2 / (2.0 * splash_r * splash_r))
			if w > 0.02:
				_kernel.append([ox, oz, w])
				sum += w
	for e in _kernel:
		e[2] = e[2] / sum
	reset()

func _build_rebar(columns: Array) -> void:
	var steel := F.color_mat(Color("8a4a2b"))
	var chair := F.color_mat(Color("d8d2c4"))
	var bars := MultiMesh.new()
	bars.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	bm.material = steel
	bars.mesh = bm
	var xforms: Array[Transform3D] = []
	var spacing := 0.4
	for y in [0.06, 0.15]:  # bottom and top mats, with cover under the finished slab level
		var z := -bd * 0.5 + 0.2
		while z <= bd * 0.5 - 0.15:
			if round_r > 0.0:
				# A round slab: each bar runs chord to chord
				if absf(z) < round_r - 0.2:
					var half := sqrt(pow(round_r - 0.15, 2) - z * z)
					xforms.append(Transform3D(Basis().scaled(Vector3(half * 2.0, BAR, BAR)), Vector3(0, y, z)))
			else:
				xforms.append(Transform3D(Basis().scaled(Vector3(bw - 0.3, BAR, BAR)), Vector3(0, y, z)))
			z += spacing
		var x := -bw * 0.5 + 0.2
		while x <= bw * 0.5 - 0.15:
			if round_r > 0.0:
				if absf(x) < round_r - 0.2:
					var half2 := sqrt(pow(round_r - 0.15, 2) - x * x)
					xforms.append(Transform3D(Basis().scaled(Vector3(BAR, BAR, half2 * 2.0)), Vector3(x, y + BAR, 0)))
			else:
				xforms.append(Transform3D(Basis().scaled(Vector3(BAR, BAR, bd - 0.3)), Vector3(x, y + BAR, 0)))
			x += spacing
	# Starter bars for the next level's columns
	for c in columns:
		var p: Vector2 = c
		for off in [Vector2(-0.18, -0.18), Vector2(0.18, -0.18), Vector2(-0.18, 0.18), Vector2(0.18, 0.18)]:
			xforms.append(Transform3D(Basis().scaled(Vector3(BAR, 1.3, BAR)), Vector3(p.x + off.x, 0.65, p.y + off.y)))
	bars.instance_count = xforms.size()
	for i in xforms.size():
		bars.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = bars
	rebar.add_child(mmi)

	var chairs := MultiMesh.new()
	chairs.transform_format = MultiMesh.TRANSFORM_3D
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.07
	cm.height = 0.07
	cm.radial_segments = 6
	cm.material = chair
	chairs.mesh = cm
	var cx: Array[Vector3] = []
	var zz := -bd * 0.5 + 0.8
	while zz < bd * 0.5:
		var xx := -bw * 0.5 + 0.8
		while xx < bw * 0.5:
			if round_r <= 0.0 or Vector2(xx, zz).length() < round_r - 0.3:
				cx.append(Vector3(xx, 0.035, zz))
			xx += 1.2
		zz += 1.2
	chairs.instance_count = cx.size()
	for i in cx.size():
		chairs.set_instance_transform(i, Transform3D(Basis(), cx[i]))
	var cmi := MultiMeshInstance3D.new()
	cmi.multimesh = chairs
	rebar.add_child(cmi)

## A round slab of radius `r` (the water tower's tank floor and roof): the
## corners of the grid are left out of everything, the deck and edge form go
## round, and the rebar is cut to the circle.
func set_round(r: float) -> void:
	round_r = r
	mask_n = 0
	for i in NX * NZ:
		var c := cell_center(i)
		mask[i] = 1 if Vector2(c.x, c.z).length() <= r else 0
		mask_n += mask[i]
		reach[i] = mask[i]
	for part in _rect_parts:
		(part as Node3D).visible = false
	var deck := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = r + 0.3
	dm.bottom_radius = r + 0.3
	dm.height = 0.12
	dm.radial_segments = 48
	deck.mesh = dm
	deck.material_override = F.mat("ply")
	deck.position.y = -0.06
	add_child(deck)
	var form := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = r + 0.03
	fm.bottom_radius = r + 0.03
	fm.height = FORM_H
	fm.radial_segments = 48
	fm.cap_top = false
	fm.cap_bottom = false
	form.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color("b07a45")
	fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	form.material_override = fmat
	form.position.y = FORM_H * 0.5
	add_child(form)
	for c in rebar.get_children():
		c.queue_free()
	_build_rebar([])
	smat.set_shader_parameter("round_r", r)
	_bay_c0 = NX
	_bay_c1 = 0
	for ix in NX:
		for iz in NZ:
			if mask[iz * NX + ix] == 1:
				_bay_c0 = mini(_bay_c0, ix)
				_bay_c1 = maxi(_bay_c1, ix + 1)
	_bay_meshes.clear()
	screed_bar.scale.x = (r * 2.0 + 0.4) / (bw + 0.4)

## The boom reaches all of the slab (none of the corners a round slab leaves out).
func reach_all() -> void:
	for i in NX * NZ:
		reach[i] = mask[i]

func reset() -> void:
	_skip.clear()
	_bay_meshes.clear()
	_prints.clear()
	if _prints_mm:
		_prints_mm.visible_instance_count = 0
	h.fill(0.0)
	age.fill(0.0)
	set_h.fill(-1.0)
	cold.fill(0)
	bleed.fill(0)
	scr.fill(0.0)
	vib.fill(0.0)
	poured = 0.0
	spilled = 0.0
	out_of_seq = 0.0
	rain_m3 = 0.0
	hand_placed = 0
	cur_bay = 0
	bay_cov.resize(BAYS)
	bay_cov.fill(0.0)
	_coverage = 0.0
	_reach_cov = 0.0
	smat.set_shader_parameter("cured", 0.0)
	screed_bar.visible = false
	splash.emitting = false
	bay_box.visible = false
	bay_label.visible = false
	_upload()

func needed() -> float:
	return bw * bd * SLAB * float(mask_n) / (NX * NZ) / vol_k

func _cell(ix: int, iz: int) -> int:
	return clampi(iz, 0, NZ - 1) * NX + clampi(ix, 0, NX - 1)

func bay_of_x(local_x: float) -> int:
	var ix := clampi(int((local_x + bw * 0.5) / dx), 0, NX - 1)
	return bay_of_col(ix)

## The bays split whatever slab there is (a square slab, or the width of a
## round one) into four equal runs of columns, far end first.
var _bay_c0 := 0
var _bay_c1 := NX     # one past the last slab column

func bay_of_col(ix: int) -> int:
	var w := float(_bay_c1 - _bay_c0) / BAYS
	return clampi(int(float(ix - _bay_c0) / w), 0, BAYS - 1)

## [first column, one past the last] of bay `b`.
func bay_cols(b: int) -> Vector2i:
	var w := float(_bay_c1 - _bay_c0) / BAYS
	return Vector2i(_bay_c0 + int(round(w * b)), _bay_c0 + int(round(w * (b + 1))))

## Local x of the middle of bay `b`, and its width.
func bay_x(b: int) -> Vector2:
	var c := bay_cols(b)
	var xa := -bw * 0.5 + c.x * dx
	var xb := -bw * 0.5 + c.y * dx
	return Vector2((xa + xb) * 0.5, xb - xa)

func cell_center(i: int) -> Vector3:
	return Vector3(-bw * 0.5 + dx * (i % NX + 0.5), 0, -bd * 0.5 + dx * (i / NX + 0.5))

## Marks which cells the boom can reach. `can_reach` is Callable(Vector3 local) -> bool.
func set_reach(can_reach: Callable) -> void:
	for i in NX * NZ:
		reach[i] = 1 if can_reach.call(cell_center(i)) else 0

func reach_full() -> bool:
	for r in reach:
		if r == 0:
			return false
	return true

## Drops `volume` m³ of concrete where the hose is pointing (local x/z).
func deposit(local: Vector3, volume: float, fresh := true) -> void:
	if fresh:
		poured += volume
		if raining:
			rain_m3 += volume
		if bay_of_x(local.x) > cur_bay:
			out_of_seq += volume
	var fx := (local.x + bw * 0.5) / dx - 0.5
	var fz := (local.z + bd * 0.5) / dx - 0.5
	var ix := int(round(fx))
	var iz := int(round(fz))
	if ix < -2 or ix > NX + 1 or iz < -2 or iz > NZ + 1:
		spilled += volume
		return
	# (the screed's surplus is real concrete moved about, not game m³)
	var k := vol_k if fresh else 1.0
	var per_area := volume * k / (dx * dx)
	for e in _kernel:
		var c := _cell(ix + e[0], iz + e[1])
		if not fresh and set_h[c] >= 0.0:
			continue
		var add: float = per_area * e[2]
		if mask[c] == 0:
			# Off the edge of a round slab: over the form and gone
			if fresh:
				spilled += add * dx * dx / k
			continue
		var old := h[c]
		if set_h[c] < 0.0:
			# Fresh concrete: mass-weighted age. A real new layer on top needs
			# vibrating again; a little top-up (or the screed's surplus) doesn't.
			age[c] = age[c] * old / (old + add)
			if fresh and add > 0.2 * (old + add):
				vib[c] = vib[c] * old / (old + add)
		if fresh and add > 0.03:
			scr[c] = 0.0
		h[c] = old + add

## One flow step: slump anything steeper than the repose slope, seep the rest.
## Concrete that has gone off doesn't flow any more.
var _gap_t := 0.0

func step(dt: float) -> void:
	_print_t -= dt
	if _print_t <= 0.0 and not _prints.is_empty():
		_print_t = 0.25
		_draw_prints()
	_t += dt
	_gap_t += dt
	if _gap_t > 0.4:
		_gap_t = 0.0
		_fill_gaps()
	var slump := SLUMP_K * dx * dt
	var seep := SEEP_K * dt
	var inv := 1.0 / dx
	_flip = not _flip
	for r in NZ:
		var iz := r if _flip else NZ - 1 - r
		var row := iz * NX
		for q in NX:
			var ix := q if _flip else NX - 1 - q
			var i := row + ix
			if ix + 1 < NX:
				_pair(i, i + 1, slump, seep, inv)
			if iz + 1 < NZ:
				_pair(i, i + NX, slump, seep, inv)
	# Ageing: past the open time a placed patch goes off
	for i in NX * NZ:
		var hi := h[i]
		if hi > 0.005 and set_h[i] < 0.0:
			age[i] += dt
			if age[i] > open_time and hi > SET_MIN_H:
				set_h[i] = hi
		elif set_h[i] >= 0.0 and hi > set_h[i] + COLD_RISE and cold[i] == 0:
			cold[i] = 1
	# Anything piled higher than the edge forms runs over them
	var area := dx * dx
	for ix in NX:
		_spill(ix, dt, area)
		_spill((NZ - 1) * NX + ix, dt, area)
	for iz in NZ:
		_spill(iz * NX, dt, area)
		_spill(iz * NX + NX - 1, dt, area)
	_upload()

func _pair(a: int, b: int, slump: float, seep: float, inv: float) -> void:
	var ha := h[a]
	var hb := h[b]
	if ha <= 0.0005 and hb <= 0.0005:
		return
	if mask[a] == 0 or mask[b] == 0:
		return   # the edge form of a round slab
	var d := ha - hb
	var src := a if d > 0.0 else b
	if set_h[src] >= 0.0:
		return
	if set_h[b if d > 0.0 else a] >= 0.0:
		return   # fresh concrete just banks up against a face that's gone off
	var ad := absf(d)
	var m := 0.0
	var s := ad * inv
	if s > REPOSE:
		m = slump * (s - REPOSE)
	if maxf(ha, hb) > SEEP_MIN:
		m += seep * ad
	m = minf(m, ad * 0.25)
	if m <= 0.0:
		return
	var dst := b if d > 0.0 else a
	var hd := h[dst]
	if set_h[dst] < 0.0 and hd + m > 0.0:
		age[dst] = (age[dst] * hd + age[src] * m) / (hd + m)
		# A trickle of raw concrete seeping in doesn't undo vibrated concrete
		if vib[dst] < DONE or hd < 0.06:
			vib[dst] = (vib[dst] * hd + vib[src] * m) / (hd + m)
	h[src] -= m
	h[dst] = hd + m

func _spill(i: int, dt: float, area: float) -> void:
	if h[i] > FORM_H:
		var m := (h[i] - FORM_H) * minf(1.0, 3.0 * dt)
		h[i] -= m
		spilled += m * area / vol_k

func _upload() -> void:
	img.set_data(NX, NZ, false, Image.FORMAT_RF, h.to_byte_array())
	tex.update(img)
	var n := 0
	var nr := 0
	var rcount := 0
	var need := SLAB * 0.85
	var bn: Array[int] = []
	var bt: Array[int] = []
	bn.resize(BAYS)
	bt.resize(BAYS)
	var oldest := 0.0
	var edge_oldest := 0.0
	var risky := 0
	for i in h.size():
		var full := h[i] >= need
		if full and mask[i] == 1:
			n += 1
		if reach[i] == 1:
			rcount += 1
			bt[bay_of_col(i % NX)] += 1
			if full:
				nr += 1
				bn[bay_of_col(i % NX)] += 1
		var k := i * 4
		var a := 255 if set_h[i] >= 0.0 else int(clampf(age[i] / open_time, 0.0, 1.0) * 254.0)
		_state[k] = a
		var we := _wet_edge(i)
		if we:
			edge_oldest = maxf(edge_oldest, age[i])
		_state[k + 1] = 255 if cold[i] == 1 else (128 if bleed[i] == 1 else (64 if we else 0))
		_state[k + 2] = int(clampf(vib[i], 0.0, 1.0) * 255.0)
		_state[k + 3] = int(clampf(scr[i], 0.0, 1.0) * 255.0)
		if set_h[i] < 0.0 and h[i] > 0.08:
			oldest = maxf(oldest, age[i])
			if vib[i] < 0.5 and h[i] > 0.14 and age[i] > open_time * 0.55:
				risky += 1
	_coverage = float(n) / maxf(1.0, mask_n)
	# The wet edge's age is the age of the concrete at the front of the pour
	# (where the next load goes against it), not the oldest anywhere
	edge_left = open_time - edge_oldest
	at_risk = float(risky) / maxf(1.0, mask_n)
	_reach_cov = float(nr) / maxf(1.0, rcount)
	# A bay's progress counts only what the boom can reach
	for b in BAYS:
		bay_cov[b] = 1.0 if bt[b] == 0 else float(bn[b]) / bt[b]
	while cur_bay < BAYS - 1 and bay_cov[cur_bay] >= 0.97:
		cur_bay += 1
	state_img.set_data(NX, NZ, false, Image.FORMAT_RGBA8, _state)
	state_tex.update(state_img)

## The wet edge: workable concrete with unpoured deck right beside it. New
## concrete has to land against it before it goes off, or it's a cold joint.
func _wet_edge(i: int) -> bool:
	const PLACED := 0.08
	if set_h[i] >= 0.0 or h[i] < PLACED:
		return false
	var ix := i % NX
	var iz := i / NX
	# Two cells deep, so the band reads from across the site
	for d in [1, 2]:
		if ix - d >= 0 and h[i - d] < PLACED and reach[i - d] == 1:
			return true
		if ix + d < NX and h[i + d] < PLACED and reach[i + d] == 1:
			return true
		if iz - d >= 0 and h[i - NX * d] < PLACED and reach[i - NX * d] == 1:
			return true
		if iz + d < NZ and h[i + NX * d] < PLACED and reach[i + NX * d] == 1:
			return true
	return false

const LINE_GREEN := Color("2bea6a")
const LINE_W := 0.45       # m, the painted line
const GLOW_W := 1.1        # m, the glow round it
var _line_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _bay_glow: MeshInstance3D
var _joint: MeshInstance3D
var _line_t := 0.0

## Shows the pour plan, out on the scaffold walkway so it never covers the
## slab's edges: a bold green line along the walkway beside every bay poured
## so far and the one going in now, and a thin line across the slab where the
## joint will be. It grows bay by bay until it rings the whole slab.
func show_bays(on: bool) -> void:
	bay_box.visible = on
	bay_label.visible = false   # (the task bar says which bay; the line shows where)
	if not on:
		return
	if not _bay_meshes.has(cur_bay):
		var c1 := bay_cols(cur_bay).y
		var xb := -bw * 0.5 + c1 * dx
		var whole := cur_bay >= BAYS - 1 or c1 >= _bay_c1
		var o := _outline(xb, whole)
		var joint: ArrayMesh = null
		if not (o[2] as PackedVector2Array).is_empty():
			joint = _ribbon(o[2], JOINT_W, false)
		_bay_meshes[cur_bay] = [_ribbon(o[0], LINE_W, o[1]), _ribbon(o[0], GLOW_W, o[1]), joint]
	bay_box.mesh = _bay_meshes[cur_bay][0]
	_bay_glow.mesh = _bay_meshes[cur_bay][1]
	_joint.mesh = _bay_meshes[cur_bay][2]
	_joint.visible = _joint.mesh != null
	bay_box.position = Vector3(0, 0.03, 0)
	_bay_glow.position = Vector3(0, -0.005, 0)
	_joint.position = Vector3(0, SLAB + 0.1, 0)
	# A slow breathe
	_line_t += get_process_delta_time()
	var pl := 0.5 + 0.5 * sin(_line_t * 3.0)
	_line_mat.albedo_color = LINE_GREEN.lightened(0.25 * pl)
	_glow_mat.albedo_color = Color(LINE_GREEN, 0.18 + 0.17 * pl)
	var bx := bay_x(cur_bay)
	bay_label.position = Vector3(bx.x, FORM_H + 1.0, -bd * 0.5 + 0.8)
	bay_label.text = "BAY %d of %d" % [cur_bay + 1, BAYS]

var _bay_meshes := {}
var walk_mid := 0.85      # m out from the slab edge to the walkway's centreline (set by the site)
const JOINT_W := 0.1

## [the line along the walkway (x, z points), whether it's a closed loop,
## the joint line across the slab] for everything up to local x `xb`.
func _outline(xb: float, whole: bool) -> Array:
	var pts := PackedVector2Array()
	var joint := PackedVector2Array()
	if round_r > 0.0:
		var r := round_r + walk_mid
		var n := 72
		if whole:
			for k in n:
				var a := TAU * k / n
				pts.append(Vector2(cos(a), sin(a)) * r)
			return [pts, true, joint]
		var t0 := acos(clampf(xb / r, -1.0, 1.0))
		for k in n + 1:
			var a := lerpf(t0, TAU - t0, float(k) / n)
			pts.append(Vector2(cos(a), sin(a)) * r)
		var zc := sqrt(maxf(0.0, round_r * round_r - xb * xb))
		joint.append(Vector2(xb, -zc))
		joint.append(Vector2(xb, zc))
		return [pts, false, joint]
	var A := bw * 0.5 + walk_mid
	var B := bd * 0.5 + walk_mid
	if whole:
		pts.append(Vector2(-A, -B))
		pts.append(Vector2(A, -B))
		pts.append(Vector2(A, B))
		pts.append(Vector2(-A, B))
		return [pts, true, joint]
	pts.append(Vector2(xb, -B))
	pts.append(Vector2(-A, -B))
	pts.append(Vector2(-A, B))
	pts.append(Vector2(xb, B))
	joint.append(Vector2(xb, -bd * 0.5))
	joint.append(Vector2(xb, bd * 0.5))
	return [pts, false, joint]

## A flat band `w` wide along a line of points (a loop if `closed`), mitred
## at the corners.
func _ribbon(pts: PackedVector2Array, w: float, closed := true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var outer := PackedVector3Array()
	var inner := PackedVector3Array()
	for i in n:
		var p1: Vector2 = pts[i]
		var p0: Vector2 = pts[(i - 1 + n) % n] if (closed or i > 0) else p1 - (pts[1] - p1)
		var p2: Vector2 = pts[(i + 1) % n] if (closed or i < n - 1) else p1 + (p1 - pts[n - 2])
		var d1 := (p1 - p0).normalized()
		var d2 := (p2 - p1).normalized()
		var n1 := Vector2(-d1.y, d1.x)
		var n2 := Vector2(-d2.y, d2.x)
		var m := (n1 + n2).normalized()
		var k := (w * 0.5) / maxf(0.35, m.dot(n1))
		outer.append(Vector3(p1.x + m.x * k, 0, p1.y + m.y * k))
		inner.append(Vector3(p1.x - m.x * k, 0, p1.y - m.y * k))
	for i in (n if closed else n - 1):
		var j := (i + 1) % n
		for v in [outer[i], inner[i], inner[j], outer[i], inner[j], outer[j]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()

## Share of the slab at least 85% of full depth.
## (test) Game m³ sitting on the slab now, and the depth of the deepest tenth of it.
func debug_volume() -> Vector2:
	var tot := 0.0
	var hs: Array = []
	for i in h.size():
		if mask[i] == 1 and h[i] > 0.01:
			tot += h[i]
			hs.append(h[i])
	hs.sort()
	var deep: float = hs[int(hs.size() * 0.9)] if hs.size() > 10 else 0.0
	return Vector2(tot * dx * dx / vol_k, deep)

func coverage() -> float:
	return _coverage

## The same, counting only the cells the boom can reach.
func reach_coverage() -> float:
	return _reach_cov

func height_at(local: Vector3) -> float:
	var ix := int(round((local.x + bw * 0.5) / dx - 0.5))
	var iz := int(round((local.z + bd * 0.5) / dx - 0.5))
	if ix < 0 or ix >= NX or iz < 0 or iz >= NZ:
		return 0.0
	return h[iz * NX + ix]

func peak() -> float:
	var m := 0.0
	for v in h:
		m = maxf(m, v)
	return m

## Local x/z of the lowest reachable point, sampled coarsely (used by the test
## bot). With `bay` >= 0 it only looks inside that bay.
func lowest_point(bay := -1) -> Vector3:
	var best := 1e9
	var bi := 0
	if bay >= 0 and bay_cov[bay] >= 0.97:
		bay = -1
	for iz in range(1, NZ, 3):
		for ix in range(1, NX, 3):
			if bay >= 0 and bay_of_col(ix) != bay:
				continue
			var i := iz * NX + ix
			if reach[i] == 0:
				continue
			var v := h[i]
			if v < best:
				best = v
				bi = i
	return cell_center(bi)

## Where the boom should lay concrete next, to keep one working face moving
## through the bay: the bay is taken in strips about two metres wide from the
## far end back toward the boom, and the hose works the lowest spot in the
## first strip that isn't full yet. Each new load goes against the last, the
## wet edge stays at the front of the pour, and nothing behind it is left to
## go off and be come back to.
## `from` (slab-local, optional): where the hose is now. Among the low spots
## the nearest wins, so the boom works along the face instead of jumping to
## its far end (which matters on a wide bay).
func next_face_point(bay: int, from := Vector3.INF) -> Vector3:
	return _next_face(bay, from)

## How many cells in from the edge forms the boom aims, so its splash stays
## inside them.
func edge_cells() -> int:
	return 1 if vol_k <= 1.0 else ceili(splash_r * 2.0 / dx) - 1

## Spots the boom gave up on (a hole against a column that won't fill
## without piling up the deck beside it): cell -> time it's wanted again.
var _skip := {}
## How far in from the forms the boom should aim for the spot
## next_face_point last gave (m).
var aim_margin := 0.75

func skip_near(local: Vector3, radius: float, secs: float) -> void:
	var r := ceili(radius / dx)
	var cx := int((local.x + bw * 0.5) / dx)
	var cz := int((local.z + bd * 0.5) / dx)
	for oz in range(-r, r + 1):
		for ox in range(-r, r + 1):
			var ix := cx + ox
			var iz := cz + oz
			if ix >= 0 and ix < NX and iz >= 0 and iz < NZ:
				_skip[iz * NX + ix] = _t + secs

## In from the edge forms by the boom's aim margin (see edge_cells).
func _inner(ix: int, iz: int) -> bool:
	var m := edge_cells()
	return iz >= m and iz < NZ - m and ix >= m and ix < NX - m

func _next_face(bay: int, from: Vector3) -> Vector3:
	bay = clampi(bay, 0, BAYS - 1)
	var bc := bay_cols(bay)
	var x0 := bc.x
	var per_bay := bc.y - bc.x
	var full := SLAB * 0.85
	var strip := 6
	for sidx in range(0, per_bay, strip):
		var n := 0
		var ok := 0
		var best := 1e9
		var bi := -1
		for ox in strip:
			var ix := x0 + sidx + ox
			if ix >= NX or ix >= bc.y:
				continue
			for iz in NZ:
				var i := iz * NX + ix
				if reach[i] == 0:
					continue
				# (in from the forms by about a splash: the concrete flows out
				# to them, and doesn't go over them. On a big slab the strip's
				# done once that middle is: the flow, the end hose and the
				# screed take it out to the forms)
				var m := edge_cells()
				var inner := iz >= m and iz < NZ - m and ix >= m and ix < NX - m
				if inner or vol_k <= 1.0:
					n += 1
					if h[i] >= full:
						ok += 1
				if inner and not (_skip.has(i) and float(_skip[i]) > _t):
					var score := h[i]
					# (half full is already taken: move on to fresh deck,
					# so the hose doesn't stand piling up one spot)
					if h[i] > SLAB * 0.5:
						score += 1.0
					if from.x != INF:
						score += 0.012 * cell_center(i).distance_to(Vector3(from.x, 0, from.z))
					if score < best:
						best = score
						bi = i
		if n > 0 and float(ok) / n < 0.92 and bi >= 0:
			aim_margin = (edge_cells() + 0.5) * dx
			return cell_center(bi)
	# (the middle's done: last, the strip along the forms, the lowest spot
	# nearest the hose, aiming in closer to them)
	aim_margin = 0.75
	if vol_k > 1.0:
		var best2 := 1e9
		var bi2 := -1
		for ix in range(x0, bc.y):
			for iz in NZ:
				var i := iz * NX + ix
				if reach[i] == 0 or h[i] >= full or (_skip.has(i) and float(_skip[i]) > _t):
					continue
				var sc2 := h[i]
				if from.x != INF:
					sc2 += 0.03 * cell_center(i).distance_to(Vector3(from.x, 0, from.z))
				if sc2 < best2:
					best2 = sc2
					bi2 = i
		if bi2 >= 0:
			return cell_center(bi2)
	return lowest_point(bay)

## First column of the leading strip of bay `b` (the strip a boom operator
## should be filling: the first one, from the far end, that isn't full yet).
func leading_strip(b: int) -> Vector2i:
	var bc := bay_cols(clampi(b, 0, BAYS - 1))
	var full := SLAB * 0.85
	var strip := 6
	for sidx in range(0, bc.y - bc.x, strip):
		var n := 0
		var ok := 0
		for ox in strip:
			var ix := bc.x + sidx + ox
			if ix >= bc.y:
				continue
			for iz in NZ:
				var i := iz * NX + ix
				if reach[i] == 0:
					continue
				if vol_k > 1.0 and not _inner(ix, iz):
					continue
				n += 1
				if h[i] >= full:
					ok += 1
		if n > 0 and float(ok) / n < 0.92:
			return Vector2i(bc.x + sidx, mini(bc.x + sidx + strip, bc.y))
	return bc

## Gold for the boom operator: the hose is over concrete that's wanted now,
## in the leading strip of the bay being poured and not yet full.
func good_pour_spot(local: Vector3) -> bool:
	var ix := int((local.x + bw * 0.5) / dx)
	var iz := int((local.z + bd * 0.5) / dx)
	if ix < 0 or ix >= NX or iz < 0 or iz >= NZ:
		return false
	var i := iz * NX + ix
	if mask[i] == 0 or h[i] >= SLAB * 0.8:
		return false
	if bay_of_col(ix) != cur_bay:
		return false
	var ls := leading_strip(cur_bay)
	return ix >= ls.x - 1 and ix < ls.y + 2

## Gold for the poker: share (0..1) of a poker's circle at `local` that's
## raw concrete still waiting to be vibrated.
func raw_share(local: Vector3, radius: float) -> float:
	var cells := _cells_in(local, radius)
	var n := 0
	for i in cells:
		if mask[i] == 1:
			n += 1
	return float(raw_count(local, radius)) / float(maxi(1, n))

## Gold for the screeder: fresh concrete at `local` that hasn't been screeded.
func unscreeded_at(local: Vector3) -> bool:
	var ix := int((local.x + bw * 0.5) / dx)
	var iz := int((local.z + bd * 0.5) / dx)
	if ix < 0 or ix >= NX or iz < 0 or iz >= NZ:
		return false
	var i := iz * NX + ix
	return mask[i] == 1 and h[i] > SLAB * 0.6 and scr[i] < 0.7 and set_h[i] < 0.0 and vib[i] >= DONE

func _cells_in(local: Vector3, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var cx := int((local.x + bw * 0.5) / dx)
	var cz := int((local.z + bd * 0.5) / dx)
	var rc := int(ceil(radius / dx))
	for oz in range(-rc, rc + 1):
		for ox in range(-rc, rc + 1):
			if (ox * ox + oz * oz) * dx * dx > radius * radius:
				continue
			var ix := cx + ox
			var iz := cz + oz
			if ix < 0 or ix >= NX or iz < 0 or iz >= NZ:
				continue
			out.append(iz * NX + ix)
	return out

## The poker in at `local`: compacts the fresh concrete within its radius of
## action over `compact_t` seconds. Returns how many cells are still raw.
func vibrate(local: Vector3, radius: float, dt: float, compact_t := 1.0) -> int:
	var left := 0
	for i in _cells_in(local, radius):
		if set_h[i] < 0.0 and h[i] > 0.05:
			# Forgiving at the edge of the poker's reach, and it never spoils
			# the screeder's finish (the two jobs can go in either order)
			vib[i] = minf(1.0, vib[i] + dt / compact_t)
			if vib[i] < DONE:
				left += 1
	return left

## The crew keeps vibrating behind the last of the pour: still-fresh concrete
## gets `amount` of a full compaction. Concrete that already went off doesn't.
func finish_vibration(amount: float) -> void:
	for i in h.size():
		if set_h[i] < 0.0 and h[i] > 0.05:
			vib[i] = minf(1.0, vib[i] + amount)

## Raw (un-vibrated) fresh concrete cells within `radius` of `local`.
func raw_count(local: Vector3, radius: float) -> int:
	var n := 0
	for i in _cells_in(local, radius):
		if set_h[i] < 0.0 and h[i] > 0.05 and vib[i] < DONE:
			n += 1
	return n

## The patches of raw concrete closest to going off, a few metres apart:
## [[local position, how close it is to going off 0..1], ...]
func raw_spots(max_n := 3, min_sep := 3.5) -> Array:
	var cands: Array = []
	for iz in range(1, NZ, 2):
		for ix in range(1, NX, 2):
			var i := iz * NX + ix
			if h[i] > 0.12 and vib[i] < DONE and set_h[i] < 0.0:
				cands.append([age[i] / open_time, cell_center(i)])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var out: Array = []
	for c in cands:
		var ok := true
		for o in out:
			if (o[0] as Vector3).distance_to(c[1]) < min_sep:
				ok = false
				break
		if ok:
			out.append([c[1], c[0]])
			if out.size() >= max_n:
				break
	return out

## What's left to do on concrete that's still workable, as shares of the
## slab: [still to vibrate, still to screed]. Concrete that's gone off is
## past saving and doesn't count (it shows up on the report instead).
func work_left() -> Vector2:
	var raw := 0
	var rough := 0
	for i in h.size():
		if set_h[i] >= 0.0:
			continue
		if h[i] > 0.12 and vib[i] < DONE:
			raw += 1
		if h[i] > SLAB * 0.8 and scr[i] < 0.5:
			rough += 1
	return Vector2(float(raw), float(rough)) / maxf(1.0, mask_n)

## A boot sole: a rounded toe, a narrow waist and a heel, with tread bars.
static func _sole_texture() -> ImageTexture:
	var w := 32
	var hh := 64
	var img := Image.create(w, hh, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for y in hh:
		for x in w:
			var u := (x + 0.5) / w - 0.5
			var v := (y + 0.5) / hh
			var half := 0.0
			if v < 0.55:
				half = 0.46 * sqrt(maxf(0.0, 1.0 - pow((v - 0.3) / 0.3, 2.0)))
			elif v < 0.66:
				half = 0.3
			else:
				half = 0.38 * sqrt(maxf(0.0, 1.0 - pow((v - 0.83) / 0.17, 2.0)))
			if absf(u) < half:
				var tread := 0.8 if int(v * 22.0) % 2 == 0 else 1.0
				img.set_pixel(x, y, Color(1, 1, 1, tread))
	return ImageTexture.create_from_image(img)

const PRINTS_MAX := 240
var _prints_mm: MultiMesh
var _prints: Array = []    # {cell, xf}
var _print_t := 0.0

## A boot coming down at `local`. 0: nothing there to mark (bare deck, or
## concrete that's gone off: dry enough not to matter). 1: a print in fresh
## concrete that hasn't been screeded yet (the screed will take it out).
## 2: a print in the finished, screeded surface: it's spoiled there and the
## screed has to come back over it.
func footprint(local: Vector3, yaw: float) -> int:
	var ix := int((local.x + bw * 0.5) / dx)
	var iz := int((local.z + bd * 0.5) / dx)
	if ix < 0 or ix >= NX or iz < 0 or iz >= NZ:
		return 0
	var i := iz * NX + ix
	if mask[i] == 0 or h[i] < 0.06 or set_h[i] >= 0.0:
		return 0
	var res := 1
	if scr[i] >= 0.7:
		res = 2
		for c in _cells_in(local, 0.22):
			if set_h[c] < 0.0:
				scr[c] = minf(scr[c], 0.45)
		_upload()
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(local.x, h[i] + 0.008, local.z))
	_prints.append({"cell": i, "xf": xf})
	if _prints.size() > PRINTS_MAX:
		_prints.pop_front()
	_draw_prints()
	return res

## Prints the screed has since been back over are gone.
func _draw_prints() -> void:
	if _prints_mm == null:
		return
	_prints = _prints.filter(func(e): return scr[int(e["cell"])] < 0.7)
	var n := 0
	for e in _prints:
		var xf: Transform3D = e["xf"]
		xf.origin.y = h[int(e["cell"])] + 0.008
		_prints_mm.set_instance_transform(n, xf)
		n += 1
	_prints_mm.visible_instance_count = n

## The concreters finish whatever's left by hand (hand poker, a float):
## every fresh cell still needing vibrating or screeding is done. Returns how
## many there were.
func finish_by_hand() -> int:
	var n := 0
	for i in h.size():
		if set_h[i] >= 0.0:
			continue
		var did := false
		if h[i] > 0.12 and vib[i] < DONE:
			vib[i] = 1.0
			did = true
		elif h[i] > 0.05 and vib[i] < DONE:
			vib[i] = 1.0   # (thin edges: tidied, not counted)
		if h[i] > SLAB * 0.8 and scr[i] < 0.5:
			scr[i] = 1.0
			did = true
		if did:
			n += 1
	if n > 0:
		_upload()
	return n

## Dev: where the unscreeded / unvibrated fresh cells are (pour-local).
func debug_left() -> String:
	var out := ""
	var n := 0
	for i in h.size():
		if set_h[i] >= 0.0:
			continue
		var r := h[i] > SLAB * 0.8 and scr[i] < 0.5
		var v := h[i] > 0.12 and vib[i] < DONE
		if r or v:
			n += 1
			if n <= 14:
				var c := cell_center(i)
				out += " (%.1f,%.1f h%.2f v%.2f s%.2f a%.0f)" % [c.x, c.z, h[i], vib[i], scr[i], age[i]]
	return "%d cells:%s" % [n, out]

## Little missed slivers between plunges: the vibration carries into them.
func _fill_gaps() -> void:
	for iz in range(NZ):
		for ix in range(NX):
			var i := iz * NX + ix
			if vib[i] >= DONE or h[i] < 0.05 or set_h[i] >= 0.0:
				continue
			var n := 0
			var done := 0
			for oz in [-1, 0, 1]:
				for ox in [-1, 0, 1]:
					if ox == 0 and oz == 0:
						continue
					var jx: int = ix + ox
					var jz: int = iz + oz
					if jx < 0 or jz < 0 or jx >= NX or jz >= NZ:
						continue
					var j := jz * NX + jx
					if h[j] < 0.05:
						continue
					n += 1
					if vib[j] >= DONE:
						done += 1
			if n > 0 and float(done) / n >= 0.6:
				vib[i] = DONE

## Held in too long: bleed water comes up and leaves a weak, watery skin.
func mark_bleed(local: Vector3, radius: float) -> void:
	for i in _cells_in(local, radius):
		if h[i] > 0.05:
			bleed[i] = 1

## Nearest fresh, thick, unvibrated concrete to `from` (for the crew).
func needs_vibrating(from: Vector3) -> Vector3:
	var best := 1e9
	var out := Vector3(INF, 0, 0)
	for iz in range(1, NZ, 2):
		for ix in range(1, NX, 2):
			var i := iz * NX + ix
			if h[i] > 0.1 and vib[i] < 0.5 and set_h[i] < 0.0:
				var c := cell_center(i)
				var d := c.distance_squared_to(from)
				if d < best:
					best = d
					out = c
	return out

## End-of-slab numbers for the grade card.
func defects() -> Dictionary:
	var n_cold := 0
	var n_void := 0
	var n_thick := 0
	var n_bleed := 0
	for i in h.size():
		if cold[i] == 1:
			n_cold += 1
		if bleed[i] == 1:
			n_bleed += 1
		if h[i] > 0.12:
			n_thick += 1
			if vib[i] < 0.5:
				n_void += 1
	return {"cold": float(n_cold) / maxf(1.0, mask_n), "voids": float(n_void) / maxf(1.0, n_thick), "bleed": float(n_bleed) / maxf(1.0, mask_n)}

## The screed board dragged along the segment a..b (pour-local), cutting the
## high spots down to slab level and carrying the surplus (`carry`, m³) along
## in a roll in front of the board to fill the low ones. Gone-off concrete
## can't be worked. Returns {carry, done (cells just finished), raw (cells
## screeded before they were vibrated)}.
func screed_strip(a: Vector3, b: Vector3, dt: float, carry: float) -> Dictionary:
	var area := dx * dx
	var done := 0
	var raw := 0
	var mid := (a + b) * 0.5
	var half := a.distance_to(b) * 0.5 + 0.3
	var ab := b - a
	var abl := maxf(0.001, ab.length_squared())
	for i in _cells_in(mid, half):
		var c := cell_center(i)
		var u := clampf((c - a).dot(ab) / abl, 0.0, 1.0)
		if c.distance_to(a + ab * u) > 0.3:
			continue
		if h[i] < 0.06:
			continue
		if set_h[i] >= 0.0:
			# Gone off: the board can still knock a ridge down to level, but
			# it tears rather than finishes (and still counts against quality)
			if h[i] > SLAB + 0.02:
				h[i] -= (h[i] - SLAB) * minf(1.0, dt * 6.0)
				set_h[i] = h[i]
				scr[i] = maxf(scr[i], 0.3)
			continue
		var k := minf(1.0, dt * 24.0)
		if h[i] > SLAB:
			var cut := (h[i] - SLAB) * k
			h[i] -= cut
			carry += cut * area
		elif carry > 0.0:
			var add := minf((SLAB - h[i]) * k, carry / area)
			h[i] += add
			carry -= add * area
		if absf(h[i] - SLAB) < 0.055 and scr[i] < 1.0:
			# Pokers first, screed after: the board only finishes concrete
			# that's been vibrated. Forgiving, though: a small missed spot
			# with vibrated concrete all round it counts as done
			if not vib_ok(i):
				raw += 1
				continue
			scr[i] = minf(1.0, scr[i] + dt * 14.0)
			if scr[i] >= 1.0:
				done += 1
	return {"carry": carry, "done": done, "raw": raw}

## Vibrated enough to screed: this cell, or most of the cells round it.
func vib_ok(i: int) -> bool:
	if vib[i] >= 0.5:
		return true
	var ix := i % NX
	var iz := i / NX
	var n := 0
	var ok := 0
	for oz in [-2, -1, 0, 1, 2]:
		for ox in [-2, -1, 0, 1, 2]:
			var jx: int = ix + ox
			var jz: int = iz + oz
			if (ox == 0 and oz == 0) or jx < 0 or jz < 0 or jx >= NX or jz >= NZ:
				continue
			var j := jz * NX + jx
			if h[j] < 0.12:
				continue
			n += 1
			if vib[j] >= DONE * 0.9:
				ok += 1
	return n > 0 and float(ok) / n >= 0.7

## Pour-local spot of fresh, vibrated, full-depth concrete nobody has screeded,
## oldest first (the bit closest to going off). INF if there's none.
func needs_screed(from: Vector3, avoid: Vector3, avoid_r: float, skip: Array = []) -> Vector3:
	var best := -1e9
	var out := Vector3(INF, 0, 0)
	for iz in range(NZ):
		for ix in range(NX):
			var i := iz * NX + ix
			if h[i] > SLAB * 0.8 and scr[i] < 0.5 and set_h[i] < 0.0 and vib_ok(i):
				var c := cell_center(i)
				if Vector2(c.x - avoid.x, c.z - avoid.z).length() < avoid_r:
					continue
				var skipped := false
				for sk in skip:
					if Vector2(c.x - sk.x, c.z - sk.z).length() < 0.6:
						skipped = true
						break
				if skipped:
					continue
				var score := age[i] * 2.0 - c.distance_to(from)
				if score > best:
					best = score
					out = c
	return out

## Cells still wanting the screed in the strip x0..x1 (pour-local).
func strip_work(x0: float, x1: float) -> int:
	var n := 0
	for iz in range(NZ):
		for ix in range(NX):
			var i := iz * NX + ix
			var c := cell_center(i)
			if c.x < x0 or c.x > x1:
				continue
			if h[i] > SLAB * 0.8 and scr[i] < 0.5 and set_h[i] < 0.0 and vib_ok(i):
				n += 1
	return n

## Where along the strip x0..x1 the work is: Vector2(nearest z, farthest z)
## of the cells still wanting the screed, or (INF, -INF) if none.
func strip_band(x0: float, x1: float) -> Vector2:
	var out := Vector2(INF, -INF)
	for iz in range(NZ):
		for ix in range(NX):
			var i := iz * NX + ix
			var c := cell_center(i)
			if c.x < x0 or c.x > x1:
				continue
			if h[i] > SLAB * 0.8 and scr[i] < 0.5 and set_h[i] < 0.0 and vib_ok(i):
				out.x = minf(out.x, c.z)
				out.y = maxf(out.y, c.z)
	return out

## Share of the placed slab that went off before anyone screeded it. (Still
## fresh at the end of the pour is fine: the crew finishes it off.)
func rough_share() -> float:
	var n := 0
	var bad := 0
	for i in h.size():
		if h[i] > 0.12:
			n += 1
			if set_h[i] >= 0.0 and scr[i] < 0.5:
				bad += 1
	return float(bad) / maxf(1.0, n)

## Share of the placed slab screeded so far.
func screed_share() -> float:
	var n := 0
	var ok := 0
	for i in h.size():
		if h[i] > 0.12:
			n += 1
			if scr[i] >= 0.5:
				ok += 1
	return float(ok) / maxf(1.0, n)

## Concrete the crew had to shovel into corners the boom couldn't reach.
func hand_place() -> void:
	var need := SLAB * 0.85
	for i in h.size():
		if reach[i] == 0 and h[i] < need and mask[i] == 1:
			hand_placed += 1
			poured += (SLAB - h[i]) * dx * dx / vol_k
			h[i] = SLAB
	_upload()

## Screed pass: drags everything toward finished slab level. u is 0..1 across the slab.
func screed(u: float, dt: float) -> void:
	screed_bar.visible = true
	var z := -bd * 0.5 + bd * u
	screed_bar.position = Vector3(0, SLAB + 0.05, z)
	var row := clampi(int((z + bd * 0.5) / dx), 0, NZ)
	for iz in row:
		for ix in NX:
			var i := iz * NX + ix
			h[i] = lerpf(h[i], SLAB, minf(1.0, dt * 10.0))
			scr[i] = maxf(scr[i], 0.7)
	_upload()

func set_cured(u: float) -> void:
	smat.set_shader_parameter("cured", u)
	screed_bar.visible = u < 0.5

var _views := Vector2.ZERO

## Work overlays: x = poker (what's still to vibrate), y = screed (what's ready).
func set_edge_view(v: float) -> void:
	if smat:
		smat.set_shader_parameter("edge_view", v)

func set_views(poker: bool, screed: bool, dt: float) -> void:
	var want := Vector2(1.0 if poker else 0.0, 1.0 if screed else 0.0)
	_views = _views.move_toward(want, dt * 3.0)
	smat.set_shader_parameter("poker_view", _views.x)
	smat.set_shader_parameter("screed_view", _views.y)

## Pokers in the concrete make the surface around them tremble.
func set_shiver(list: Array) -> void:
	var v := PackedVector4Array()
	for e in list:
		v.append(e)
	while v.size() < 4:
		v.append(Vector4(0, 0, 0, 0))
	smat.set_shader_parameter("shiver", v)

func set_splash(on: bool, local: Vector3) -> void:
	splash.emitting = on
	if on:
		splash.position = Vector3(local.x, height_at(local) + 0.05, local.z)
