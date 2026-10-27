## Climbing the placing boom, Riverlight-style, using SCP's self-climbing frame:
##   1. JACK   the rigger pumps the frame's rams; each stroke lifts the boom ~0.46 m
##             and the locking bars catch it, until there's a gap for a new section
##   2. FLY    the tower crane brings a lattice section over on its hook
##   3. GUIDE  the load is out of the crane driver's sight: the dogman whistles it
##             onto the frame's runway beam while the tag-line hand stops it spinning
##   4. ROLL   the rigger rolls the section along the runway into the gap
##   5. PIN    the rigger inches the frame till the holes line up, drifts each
##             hole true with a podger, drives the pin home with the hammer and
##             fits its R-clip. 4 pins per joint.
##   6. SEAT   the boom settles onto the new section
## The section hangs as a real pendulum, so it swings slowly in any direction,
## spins, and gets pushed around by the wind. Lifting stops at 54 km/h gusts.
extends Node3D

signal finished

const F := preload("res://scripts/factory.gd")
const Settings := preload("res://scripts/settings.gd")

const LAT_X := 12.0
const LS := 4.14
const LW := 2.0
const G := 9.81
const STROKE := 0.46        # m per ram stroke
const CLEAR := 0.15         # extra lift so the new section slides in
const PINS := 4             # pins per joint
const HITS := 3             # clean hammer blows to drive a pin home
const SWEET := 0.6          # hammer swing: let go between here...
const SWEET_W := 0.28       # ...and here plus this
const PODGER_TOL := 0.022   # m the holes can be out and still take the podger
const WIND_STOP := 54.0     # km/h gust at the boom head: lifting stops
const RUNWAY_Z := 4.0
const LAND_TOL := 0.5       # m off the runway stops that still seat
const SPIN_TOL := 0.3       # rad (about 17 degrees)
const MAST := Vector3(11.0, 0.0, -23.0)   # off the south side of the link, between the wings
const CRANE_H := 66.0
const JIB := 52.0
const SLING := 2.4
const OP_DELAY := 0.35      # crane driver's reaction time to a whistle, s
const WRECK_V := 0.8        # m/s: a knock harder than this wrecks the section
const REFETCH_T := 9.0      # s for the crane to rig and bring another section
const PLATFORM_DROP := 0.85 # work platform this far below the joint: the pins sit at a chibi's chest
const WIND_GRACE := 2.0     # s the driver waits for "dog everything" before holding anyway
const ZONE_R := 7.0         # m: the crane's zoning keeps the hook this close to the landing while it's dogged
const LAYDOWN := Vector3(1.0, 0.0, 10.5)   # where the next section stands on the street, waiting to be slung
const SLING_TIME := 2.2     # s of slinging: four legs onto the section's top lugs
const LIFT_K := 2.8         # the crane hoists this much faster lifting off the laydown
## The gin wheel at the deck edge the pin sets come up on: just past the
## slab's +z edge, by the pin sets station.
func _pin_haul() -> Vector3:
	return Vector3(-3.0, 0.0, game.SC.z + game.BD * 0.5 + 0.4)
const HAUL_TIME := 2.6      # s of hauling the pin sets up

var game
var active := false
var stage := ""
var stage_t := 0.0
var sections_left := 0
var knocks := 0
var _t := 0.0

var wind_dir := Vector2(0.8, -0.6).normalized()
var wind_mean := 22.0
var wind_gust := 22.0
var _spike_at := -1.0
var _spike_t := -1.0

var frame_posts: Array[MeshInstance3D] = []
var rams: Array[MeshInstance3D] = []
var runway: Node3D
var platform: Node3D
var sock_pivot: Node3D
var cups: Node3D
var crane_slew: Node3D
var trolley: Node3D
var cable: MeshInstance3D
var hook: MeshInstance3D
var slings: Array[MeshInstance3D] = []
var tag_rope: MeshInstance3D
var load: Node3D
var pin_meshes: Array[MeshInstance3D] = []

var trolley_xz := Vector2(-2.0, 10.0)
var trolley_v := Vector2.ZERO
var cable_len := 30.0
var hoist_v := 0.0
var _cmds: Array = []
var _op_dir := Vector2.ZERO
var _op_vert := 0.0
var swing := Vector2.ZERO
var swing_v := Vector2.ZERO
var spin := 0.0
var spin_v := 0.0
var tagging := false
var tag_from := Vector3.ZERO
var _knock_cd := 0.0
var call_now := "STOP"
var _pending := "STOP"
var _pending_code := "stop"
var _pending_t := 0.0
var _call_since := 0.0
var _last_whistle := -10.0
var _stick := Vector2.ZERO        # the current call's direction as the stick pushes it
var _call := ""                   # the horizontal call being held ("TROLLEY OUT", ...; "" none)
var _zone_hit := false
var _vert := 0.0
var _dogman = null
var tag_strength := 1.1
var _op_slow := false
var _op_dog := false
var _slow := false
var _dog_all := false
var _estop_t := 0.0
var _flinch_t := 0.0
var _touching := false
var _touch_prev := false
var _last_slow_tap := -10.0
var _wind_over_t := 0.0
var _wind_noted := false
var wind_misses := 0
var unclipped := 0
var _speed_k := 1.0         # this call's driver speed (no two drivers are the same)
var _coast := 0.0           # the driver lets it run on a moment after "stop"
var _last_dir := Vector2.ZERO
var _puff_t := 3.0          # little gust bursts while guiding
var _hand_off := Vector2.ZERO

# Pinning props: lug plates with holes, the pins, R-clips, podger and hammer
var lugs: Array = []        # per corner: {lower, upper, hole_lo, hole_up, pin, clip, dir, base}
var podger: Node3D
var hammer: Node3D
var hammer_head_mat: StandardMaterial3D
var sparks: CPUParticles3D
var _podger_t := -1.0
var _strike_t := 0.0
var _clip_t := 0.0
var _clip_hold := 0.0
const CLIP_T := 0.7      # s holding A to push an R-clip through
var rig_npc: Node3D
var _rigger = null
var _ram_queued := false
var _stand_adj := Vector3.ZERO
var _strike_from := 0.0
var _theta := 0.45
var _cam_side := Vector3.ZERO
var _pinning: Node3D = null  # the section being pinned, off the hook (the crane's free for the next)
var _crane_ahead := false   # the crane fetched the next section during the pinning
var _early_fly := false     # the crane is already flying the next section in during the jacking
var _fly_arrived := false
var _lever := 0.0           # how hard the rigger's levering the podger, -1..1
var _wreck_v := Vector3.ZERO
var _wreck_spin := Vector3.ZERO
var _wreck_landed := -1.0
var align_arrow: Node3D
var dog_bot = null          # a crew bot acting as dogman this frame
var _tagger = null          # whoever held the tag line during this lift
# The tag line: only once the crane has the load up over the deck. The hand
# runs out to the dangling line, grabs it, and walks it back to the tag spot,
# holding A all the while; let go and the line drops.
const TAG_REACH := 7.0      # m from the tag spot the line has to hang before anyone runs for it
const TAG_GRAB := 1.1       # m: close enough to grab the line
const TAG_EDGE := 2.5       # m: a line hanging this near the scaffold edge can be reached for
const TAG_FAR := 18.0       # m: past this from the tag spot, it's nobody's to run for
var tag_hand = null         # who's on the tag line right now
var _tag_sub := ""          # "fetch" running out to the line, "hold" walking it back or holding at the spot
var _tag_best := INF        # closest they've got to the line so far
var _tag_stuck := 0.0

# Climb days for the street and the screeder: slinging the next section on the
# laydown, and hauling up the pin sets (each pin with its R-clip on, one piece)
var load_state := ""        # "laydown" waiting to be slung, "lift" going straight up, "" flying
var sling_prog := 0.0
var pinsets := 0            # pin sets on the rigger's platform
var bundle_state := ""      # "ground" waiting at the gin wheel, "carried", "up" delivered
var haul_prog := 0.0
var bundle: Node3D
var haul_rope: MeshInstance3D
var laydown_mark: Node3D
var _pin_split_t := -1.0

# Guide visuals
var ghost: MeshInstance3D
var ghost_label: Label3D
var drop_ring: MeshInstance3D
var drop_mat: StandardMaterial3D
var plumb: MeshInstance3D
var guide_arrows: Array[Node3D] = []   # stick up, down, left, right, then hoist, lower
var motion_arrow: Node3D
var dog_arrow: Node3D
var dog_stop: Label3D
var call_labels: Array[Label3D] = []    # the call by each stick arrow
var stop_ghost: MeshInstance3D
var stop_ghost_mat: StandardMaterial3D
var stop_ghost_at := Vector3.INF        # where it settles on a STOP now (INF: not shown)
var zone_ring: MeshInstance3D
var zone_mat: StandardMaterial3D
var rings: Array[MeshInstance3D] = []
var _ring_t := 10.0
var tag_npc: Node3D

var ram := 0.0
var ram_state := "ready"
var stall_t := 0.0
var lifted := 0.0
var pin_i := 0
var hit_i := 0
var pin_sub := ""           # "align", "podger", "drive", "clip"
var hole_off := 0.0         # m the section's holes sit off the frame's
var power := 0.0            # hammer wind-up, 0..1
var winding := false
var depth := 0.0            # how far the current pin is driven, 0..1
var cool := 0.0
var roll := 0.0
var _seat_from := 0.0

# ------------------------------------------------------------------ build

func build(owner_game) -> void:
	game = owner_game
	var yellow := F.mat("yellow", true)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var post := F.box(Vector3(0.18, 1.0, 0.18), yellow)
			post.set_meta("off", Vector2(sx * 1.25, sz * 1.25))
			add_child(post)
			frame_posts.append(post)
	var chrome := F.color_mat(Color("d6dde4"))
	for sx in [-1.0, 1.0]:
		var r := F.cylinder(0.11, 1.0, chrome, Vector3.ZERO, 10)
		r.set_meta("x", sx * 1.5)
		add_child(r)
		rams.append(r)

	runway = Node3D.new()
	var rail_mat := F.mat("yellow_dark")
	var rail_len := RUNWAY_Z + 1.4 - 0.9
	for sx in [-0.85, 0.85]:
		runway.add_child(F.box(Vector3(0.16, 0.18, rail_len), rail_mat, Vector3(sx, -0.09, 0.9 + rail_len * 0.5)))
	runway.add_child(F.box(Vector3(1.9, 0.3, 0.12), F.mat("orange"), Vector3(0, 0.1, RUNWAY_Z + 1.35)))
	runway.visible = false
	add_child(runway)

	# The climbing frame's work platform: a walkway right round the tower,
	# about a metre below the joint so the rigger works the pins at chest height
	platform = Node3D.new()
	var deck := F.mat("steel")
	var rail := F.mat("orange")
	# Boards: [centre x, centre z, size x, size z] (tower-local). The south
	# (+z) side leaves slots for the riser and the haul rope; the east (+x)
	# side stops short of the tower ladder.
	var boards := [
		[0.0, -2.05, 5.6, 1.5],            # north
		[-2.05, 0.0, 1.5, 2.6],            # west
		[2.05, -0.6, 1.5, 1.4],            # east, short of the ladder
		[-1.65, 2.05, 2.3, 1.5],           # south, west of the riser
		[1.15, 2.05, 1.0, 1.5],            # south, between riser and rope
		[2.7, 2.05, 0.2, 1.5],             # south-east corner strip
		[2.125, 2.325, 0.95, 0.95],        # south-east corner, clear of the rope
		[0.0, 2.5, 1.0, 0.6],              # south, behind the riser
	]
	for b in boards:
		platform.add_child(F.box(Vector3(b[2], 0.1, b[3]), deck, Vector3(b[0], -0.05, b[1])))
	for side in [-1.0, 1.0]:
		for hgt in [0.5, 1.0]:
			platform.add_child(F.box(Vector3(5.6, 0.06, 0.06), rail, Vector3(0, hgt, side * 2.8)))
			platform.add_child(F.box(Vector3(0.06, 0.06, 5.6), rail, Vector3(side * 2.8, hgt, 0)))
		for c in [-2.8, 0.0, 2.8]:
			platform.add_child(F.box(Vector3(0.06, 1.0, 0.06), rail, Vector3(c, 0.5, side * 2.8)))
			platform.add_child(F.box(Vector3(0.06, 1.0, 0.06), rail, Vector3(side * 2.8, 0.5, c)))
	add_child(platform)
	_build_pin_haul()

	# Windsock and anemometer on the boom head
	var pole := F.cylinder(0.05, 3.2, F.mat("white"), Vector3(-1.7, 1.6, -1.7), 6)
	game.head.add_child(pole)
	sock_pivot = Node3D.new()
	sock_pivot.position = Vector3(-1.7, 3.15, -1.7)
	game.head.add_child(sock_pivot)
	for i in 3:
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.26 - i * 0.06
		cm.bottom_radius = 0.3 - i * 0.06
		cm.height = 0.5
		cm.radial_segments = 10
		seg.mesh = cm
		seg.material_override = F.color_mat(Color("ff7a1a") if i % 2 == 0 else Color("f4f7fa"))
		seg.rotation.z = -PI * 0.5
		seg.position.x = 0.25 + i * 0.5
		sock_pivot.add_child(seg)
	cups = Node3D.new()
	cups.position = Vector3(-1.7, 3.5, -1.7)
	game.head.add_child(cups)
	cups.add_child(F.cylinder(0.03, 0.4, F.mat("white"), Vector3(0, -0.2, 0), 6))
	for i in 3:
		var a := TAU * i / 3.0
		var arm := Vector3(cos(a), 0, sin(a)) * 0.35
		cups.add_child(F.beam(Vector3.ZERO, arm, 0.03, F.mat("white")))
		cups.add_child(F.sphere(0.08, F.mat("red"), arm))

	_build_crane()

	tag_rope = F.cylinder(0.025, 1.0, F.color_mat(Color("d9c27a")), Vector3.ZERO, 5)
	tag_rope.visible = false
	add_child(tag_rope)

	_build_pin_props()
	_build_guides()
	_place_frame()

func _overlay_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.no_depth_test = true
	m.render_priority = 10
	return m

## An arrow pointing along +X, about `size` metres long.
func _arrow(c: Color, size := 1.0) -> Node3D:
	var n := Node3D.new()
	var m := _overlay_mat(c)
	var shaft := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.75, 0.16, 0.16) * size
	shaft.mesh = bm
	shaft.position.x = 0.375 * size
	shaft.material_override = m
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(shaft)
	var head := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.32 * size
	cm.height = 0.5 * size
	head.mesh = cm
	head.rotation.z = -PI * 0.5
	head.position.x = 1.0 * size
	head.material_override = m
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(head)
	n.set_meta("mat", m)
	n.visible = false
	add_child(n)
	return n

func _point(a: Node3D, dir3: Vector3) -> void:
	if absf(dir3.y) > 0.5:
		a.rotation = Vector3(0, 0, PI * 0.5 * signf(dir3.y))
	else:
		a.rotation = Vector3(0, atan2(-dir3.z, dir3.x), 0)

func _build_guides() -> void:
	# Ghost of where the section has to sit, on the runway
	ghost = MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(LW, LS, LW)
	ghost.mesh = gb
	ghost.material_override = _overlay_mat(Color(0.49, 0.85, 0.57, 0.38))
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.visible = false
	add_child(ghost)
	ghost_label = F.label3d("SET IT HERE", 44, Color("7cd992"))
	ghost_label.visible = false
	add_child(ghost_label)
	# Where the load would land if lowered now, with a plumb line down to it
	drop_ring = MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 1.05
	rm.bottom_radius = 1.05
	rm.height = 0.04
	drop_ring.mesh = rm
	drop_mat = _overlay_mat(Color(1, 0.6, 0.1, 0.5))
	drop_ring.material_override = drop_mat
	drop_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drop_ring.visible = false
	add_child(drop_ring)
	plumb = F.cylinder(0.03, 1.0, drop_mat, Vector3.ZERO, 6)
	plumb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plumb.visible = false
	add_child(plumb)
	# Stick directions around the load, plus hoist and lower
	for i in 6:
		guide_arrows.append(_arrow(Color(1, 1, 1, 0.45), 1.3))
	motion_arrow = _arrow(Color(1.0, 0.48, 0.1, 0.9), 1.0)
	dog_arrow = _arrow(Color(1.0, 0.78, 0.17, 1.0), 0.9)
	dog_stop = F.label3d("STOP", 54, Color("ff4d4d"))
	dog_stop.visible = false
	add_child(dog_stop)
	# The call each stick arrow makes, in the crane's own words
	for i in 4:
		var l := F.label3d("", 34, Color.WHITE)
		l.visible = false
		add_child(l)
		call_labels.append(l)
	# The stop ghost: where the load settles if the dogman calls STOP now
	stop_ghost = MeshInstance3D.new()
	var sg := BoxMesh.new()
	sg.size = Vector3(LW, LS, LW)
	stop_ghost.mesh = sg
	stop_ghost_mat = _overlay_mat(Color(1, 1, 1, 0.22))
	stop_ghost.material_override = stop_ghost_mat
	stop_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stop_ghost.visible = false
	add_child(stop_ghost)
	# The crane's zoning limit round the landing
	zone_ring = MeshInstance3D.new()
	var zt := TorusMesh.new()
	zt.inner_radius = ZONE_R - 0.08
	zt.outer_radius = ZONE_R + 0.08
	zt.rings = 64
	zone_ring.mesh = zt
	zone_mat = _overlay_mat(Color(1, 0.82, 0.25, 0.25))
	zone_ring.material_override = zone_mat
	zone_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone_ring.visible = false
	add_child(zone_ring)
	for i in 2:
		var r := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.3
		tm.outer_radius = 0.36
		r.mesh = tm
		r.material_override = _overlay_mat(Color(1, 1, 1, 0.8))
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.visible = false
		add_child(r)
		rings.append(r)
	# A crew member on the tag line when no player is
	tag_npc = F.chibi(Color("ff7a1a"), Color("f4f7fa"))
	tag_npc.visible = false
	add_child(tag_npc)

func _build_crane() -> void:
	var crane := Node3D.new()
	crane.position = MAST
	add_child(crane)
	var n := int(ceil(CRANE_H / LS))
	for i in n:
		var s := F.lattice_section(LS, 2.2)
		s.position.y = i * LS
		crane.add_child(s)
	crane_slew = Node3D.new()
	crane_slew.position.y = CRANE_H
	crane.add_child(crane_slew)
	var y := F.mat("yellow", true)
	var steel := F.mat("yellow_dark")
	# Jib: a triangular truss out along +X, counter jib back along -X
	for z in [-0.7, 0.7]:
		crane_slew.add_child(F.beam(Vector3(0, 0, z), Vector3(JIB, 0, z), 0.2, steel))
	crane_slew.add_child(F.beam(Vector3(0, 1.4, 0), Vector3(JIB, 1.4, 0), 0.2, steel))
	var x := 0.0
	while x < JIB:
		crane_slew.add_child(F.beam(Vector3(x, 0, -0.7), Vector3(x + 2.0, 1.4, 0), 0.08, steel))
		crane_slew.add_child(F.beam(Vector3(x, 0, 0.7), Vector3(x + 2.0, 1.4, 0), 0.08, steel))
		x += 4.0
	crane_slew.add_child(F.box(Vector3(16, 0.6, 1.6), steel, Vector3(-8, 0.3, 0)))
	crane_slew.add_child(F.box(Vector3(3, 2.4, 2.0), F.mat("podium"), Vector3(-14, 1.2, 0)))
	crane_slew.add_child(F.box(Vector3(2.2, 2.2, 2.0), y, Vector3(1.4, -1.6, 1.6)))
	crane_slew.add_child(F.beam(Vector3(0, 0, 0), Vector3(0, 7, 0), 0.4, steel))
	crane_slew.add_child(F.beam(Vector3(0, 7, 0), Vector3(JIB * 0.7, 1.4, 0), 0.06, steel))
	crane_slew.add_child(F.beam(Vector3(0, 7, 0), Vector3(-15, 0.6, 0), 0.06, steel))
	trolley = Node3D.new()
	trolley.add_child(F.box(Vector3(1.4, 0.6, 1.8), F.mat("navy"), Vector3(0, -0.3, 0)))
	crane_slew.add_child(trolley)
	cable = F.cylinder(0.04, 1.0, F.mat("hose"), Vector3.ZERO, 6)
	add_child(cable)
	hook = F.box(Vector3(0.6, 0.8, 0.4), F.mat("yellow", true))
	add_child(hook)
	for i in 4:
		var sl := F.cylinder(0.03, 1.0, F.color_mat(Color("3a6bd1")), Vector3.ZERO, 5)
		sl.visible = false
		add_child(sl)
		slings.append(sl)

# ------------------------------------------------------------------ helpers

func gap_bottom() -> float:
	return game.section_count * LS

func head_y() -> float:
	return game.head.position.y

func wind_at_head() -> float:
	return wind_gust

func _line(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var ln := d.length()
	if ln < 0.01:
		m.visible = false
		return
	m.visible = true
	var dir := d / ln
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	m.transform = Transform3D(Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, -PI * 0.5), (a + b) * 0.5)
	m.scale = Vector3(1, ln, 1)

func _place_frame() -> void:
	var gb := gap_bottom()
	var hb := head_y()
	var h := maxf(0.35, hb - gb + 0.3)
	for p in frame_posts:
		var o: Vector2 = p.get_meta("off")
		p.position = Vector3(LAT_X + o.x, gb - 0.3 + h * 0.5, o.y)
		p.scale = Vector3(1, h, 1)
	for r in rams:
		var rx: float = r.get_meta("x")
		r.position = Vector3(LAT_X + rx, gb - 0.3 + h * 0.5, 0)
		r.scale = Vector3(1, h, 1)
	runway.position = Vector3(LAT_X, gb, 0)
	platform.position = Vector3(LAT_X, gb - PLATFORM_DROP, 0)

# ------------------------------------------------------------------ flow

func start(sections: int) -> void:
	active = true
	sections_left = sections
	knocks = 0
	wind_misses = 0
	unclipped = 0
	wind_mean = randf_range(16.0, 30.0)
	_begin_section()

func _set_stage(s: String) -> void:
	var was_t := stage_t
	stage = s
	stage_t = 0.0
	if game.autotest:
		print("[autotest]   (previous stage took %.1fs)" % was_t)
		print("[autotest]   climb: %s (sections left %d, wind gust %.0f)" % [s, sections_left, wind_gust])

func _begin_section() -> void:
	ram = 0.0
	ram_state = "ready"
	lifted = 0.0
	runway.visible = true
	# This joint's four pin sets wait on the street for the screeder to haul up
	if pinsets <= 0:
		bundle_state = "ground"
		haul_prog = 0.0
	_set_stage("jack")
	# The crane doesn't wait for the jacking: it rigs the next section and
	# brings it over while the rigger lifts the boom, so it's hanging there
	# ready the moment the gap opens. (It may have started already, during
	# the last section's pinning.)
	if load == null:
		_make_load()
	_early_fly = true

func _start_fly() -> void:
	_make_load()
	_set_stage("fly")

func _make_load() -> void:
	_early_fly = false
	_fly_arrived = false
	if load:
		load.queue_free()
	load = F.lattice_section(LS, LW)
	add_child(load)
	# (handed over in close to the scaffold edge, so the tag line's in reach)
	_hand_off = Vector2(randf_range(-2.2, 2.2), randf_range(-1.6, -0.8))
	# Every section is picked off the laydown on the street: the crane drops
	# its hook over it and waits for the slinger (the truck hand on climb
	# days) to sling it before it lifts
	_crane_ahead = false
	load_state = "laydown"
	sling_prog = 0.0
	load.position = LAYDOWN
	trolley_v = Vector2.ZERO
	hoist_v = 0.0
	swing = Vector2(0.5, -0.3)
	swing_v = Vector2.ZERO
	spin = 0.5
	spin_v = 0.0
	_cmds.clear()
	_op_dir = Vector2.ZERO
	_op_vert = 0.0
	_spike_at = randf_range(5.0, 12.0) if randf() < 0.6 else -1.0

## The crane driver flies the load in to the hand-off point, just off the
## runway and a couple of metres up. Sets _fly_arrived once it's hanging there.
func _fly_step(delta: float) -> Vector2:
	_fly_arrived = false
	if load_state == "laydown":
		return Vector2.ZERO
	if load_state == "lift":
		# Straight up off the laydown till it's clear of everything, then over
		_command(Vector2.ZERO, 1.0)
		var acc0 := _operate(delta)
		if _load_bottom() > maxf(game.work_y + 1.5, gap_bottom() - 1.0):
			load_state = ""
		return acc0
	var target := Vector2(LAT_X, RUNWAY_Z + 3.0) + _hand_off
	var to := target - trolley_xz
	var dir := to.normalized() * minf(1.0, to.length() / 3.0) if to.length() > 0.05 else Vector2.ZERO
	var want_bottom := gap_bottom() + 2.0
	var bottom := CRANE_H - cable_len - SLING - LS
	var vert := clampf((want_bottom - bottom) * 0.6, -1.0, 1.0)
	_command(dir, vert)
	var acc := _operate(delta)
	_fly_arrived = to.length() < 0.5 and absf(want_bottom - bottom) < 0.4
	return acc

## Over to the dogman: the driver can't see it from here, so it arrives
## swinging and turned.
func _to_guide() -> void:
	_cmds.clear()
	_op_dir = Vector2.ZERO
	_op_vert = 0.0
	_set_stage("guide")
	var tame: float = [0.4, 0.8, 1.0][clampi(help(), 0, 2)]
	var kick := Vector2.from_angle(randf() * TAU) * randf_range(0.35, 0.8) * tame
	swing_v += kick
	spin_v += randf_range(-0.35, 0.35)
	game.sfx.hit("whistle:stop")

## The crane has a load on the hook and is flying or being guided.
func crane_busy() -> bool:
	return load != null and (stage == "fly" or stage == "guide" or (stage in ["jack", "pin", "seat"] and _early_fly))

func _land() -> void:
	if game.autotest:
		print("[autotest]   landed after %.1fs of guiding, %d knocks" % [stage_t, knocks])
	swing = Vector2(LAT_X, RUNWAY_Z) - trolley_xz
	swing_v = Vector2.ZERO
	spin = 0.0
	spin_v = 0.0
	load.position = Vector3(LAT_X, gap_bottom(), RUNWAY_Z)
	load.rotation = Vector3.ZERO
	for s in slings:
		s.visible = false
	game.sfx.hit("thunk")
	game.sfx.hit("whistle:stop")
	game.pop("Landed!", load.position + Vector3(0, LS + 0.9, 0), Color("7cd992"))
	var dogger = _dogman if _dogman != null else dog_bot
	if dogger != null:
		game.score.award(dogger, maxi(20, 60 - 10 * knocks), "Sections landed")
	if _tagger != null:
		game.score.award(_tagger, 20, "Tag line")
	_tagger = null
	var dust := CPUParticles3D.new()
	dust.amount = 40
	dust.lifetime = 0.9
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.0, 0.05, 1.0)
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 80.0
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 2.5
	dust.gravity = Vector3(0, -2, 0)
	var dm := SphereMesh.new()
	dm.radius = 0.12
	dm.height = 0.24
	dm.radial_segments = 6
	dm.rings = 3
	dm.material = F.color_mat(Color("c9c2b4"))
	dust.mesh = dm
	add_child(dust)
	dust.position = load.position
	dust.emitting = true
	get_tree().create_timer(2.0).timeout.connect(dust.queue_free)
	game.hud.toast("Landed on the runway. Slings off.", 1.8)
	roll = 0.0
	_set_stage("roll")

func _finish_section() -> void:
	if _pinning:
		_pinning.queue_free()
		_pinning = null
	for l in lugs:
		for key in ["lower", "upper", "pin", "clip"]:
			(l[key] as Node3D).visible = false
	game._add_section()
	game.head.position.y = game.section_count * LS
	sections_left -= 1
	game.sfx.hit("ding")
	game.pop("Section %d on!" % game.section_count, Vector3(LAT_X, game.head.position.y + 1.0, 0), Color("ffc72c"))
	game.hud.toast("Section %d pinned off" % game.section_count, 1.6)
	if sections_left > 0:
		_crane_ahead = true
		_begin_section()
	else:
		active = false
		runway.visible = false
		stage = ""
		game.hud.show_meter(false)
		game.hud.set_signal("")
		finished.emit()

# ------------------------------------------------------------------ per frame

func update(delta: float) -> void:
	_t += delta
	stage_t += delta
	cool = maxf(0.0, cool - delta)
	_knock_cd = maxf(0.0, _knock_cd - delta)
	_update_wind(delta)
	_carried_pins()
	var trolley_acc := Vector2.ZERO

	match stage:
		"jack":
			_update_ram(delta)
			if _early_fly and load:
				trolley_acc = _fly_step(delta)
			if lifted >= LS + CLEAR - 0.001 and ram_state == "ready":
				if _early_fly and load:
					_early_fly = false
					if _fly_arrived:
						_to_guide()
					else:
						_set_stage("fly")
				else:
					_start_fly()
		"fly":
			trolley_acc = _fly_step(delta)
			if _fly_arrived:
				_to_guide()
		"guide":
			if _collide_test:
				_run_collide_test()
			if _spike_at > 0.0 and stage_t >= _spike_at and _spike_t < 0.0:
				_spike_t = 0.0
				_spike_at = -1.0
			# Small gust bursts nudge the load around
			_puff_t -= delta
			if _puff_t <= 0.0:
				_puff_t = randf_range(3.5, 8.0)
				swing_v += wind_dir * randf_range(0.15, 0.4)
			trolley_acc = _operate(delta)
		"roll":
			load.position.z = lerpf(RUNWAY_Z, 0.0, ease(roll, -1.6))
			if roll >= 1.0:
				if _rigger != null:
					game.score.award(_rigger, 10, "Rigging")
				_start_pins()
				_set_stage("pin")
				# Slings off: that section's the rigger's now, and the crane
				# goes straight back for the next one, so it's slung and on its
				# way up while the pins go in
				_pinning = load
				load = null
				if sections_left > 1:
					_make_load()
					_early_fly = true
		"pin":
			if _early_fly and load:
				trolley_acc = _fly_step(delta)
			if winding:
				power += delta / 1.0
				if power > 1.12:
					winding = false
					power = 0.0
					game.sfx.hit("tink")
					game.hud.toast("Over-swung it. Reset and swing again.", 1.2)
		"wreck":
			_update_wreck(delta)
		"refetch":
			if stage_t > REFETCH_T:
				game.hud.toast("New section's on the hook. Try again, gently.", 2.0)
				_start_fly()
		"seat":
			if _early_fly and load:
				trolley_acc = _fly_step(delta)
			var u := clampf(stage_t / 0.7, 0.0, 1.0)
			game.head.position.y = lerpf(_seat_from, gap_bottom() + LS, u)
			if u >= 1.0:
				_finish_section()

	# Nobody on the tag line? A crew member grabs it.
	var crane_on := crane_busy()
	tag_npc.visible = false
	if tag_npc.visible:
		tag_npc.position = Vector3(9.4, game.work_y, -0.5)
		var lp := load.global_position
		tag_npc.rotation.y = atan2(lp.x - tag_npc.position.x, lp.z - tag_npc.position.z)
		tag_npc.get_node("ArmL").rotation = Vector3(-1.6, 0, -0.25)
		tag_npc.get_node("ArmR").rotation = Vector3(-1.6, 0, 0.25)
		tagging = true
		tag_strength = 0.75
		tag_from = tag_npc.position + Vector3(0, 1.0, 0)
	elif tagging:
		tag_strength = 1.1
	if crane_on and load_state == "laydown":
		_hold_at_laydown(delta)
	elif crane_on:
		_update_load(delta, trolley_acc)
	else:
		_park_crane(delta)
	_update_bundle(delta)
	_draw_crane()
	_place_frame()
	_update_guides(delta)
	_update_pins(delta)
	if stage != "fly" and stage != "guide":
		tagging = false
	if tag_hand != null and (not is_instance_valid(tag_hand) or tag_hand.busy != "tag"):
		tag_hand = null
	# The tag line goes on before the lift and hangs off the load all the way
	# up; the hand on the landing takes it as the load comes within reach
	var flying: bool = load != null and crane_on and load_state != "laydown"
	tag_rope.visible = (tagging and load != null) or flying
	if tag_rope.visible:
		var corner := load.global_transform * Vector3(LW * 0.5, 0.3, LW * 0.5)
		if tagging:
			_line(tag_rope, tag_from, corner)
		else:
			var drop := minf(6.0, maxf(0.3, corner.y - 0.2))
			var swing_end := corner + Vector3(0.35 * sin(_t * 1.3) - swing_v.x * 0.6, -drop, 0.35 * cos(_t * 1.1) - swing_v.y * 0.6)
			_line(tag_rope, corner, swing_end)
	tagging = false   # re-set each frame by whoever is holding the tag line

func _update_wind(delta: float) -> void:
	var base := wind_mean + 5.0 * sin(_t * 0.11) + 3.0 * sin(_t * 0.37 + 1.3)
	var gust := 1.0 + 0.22 * maxf(0.0, sin(_t * 0.8)) * (0.6 + 0.4 * sin(_t * 2.3 + 0.5)) + 0.08 * sin(_t * 1.7)
	var spike := 0.0
	if _spike_t >= 0.0:
		_spike_t += delta
		spike = 30.0 * sin(PI * clampf(_spike_t / 12.0, 0.0, 1.0))
		if _spike_t > 12.0:
			_spike_t = -1.0
	var height := pow(maxf(10.0, head_y()) / 10.0, 0.14)
	wind_gust = maxf(0.0, (base * gust + spike) * height)
	var ang := 0.9 + 0.35 * sin(_t * 0.05)
	wind_dir = Vector2(cos(ang), -sin(ang))
	# Windsock points downwind and lifts as the wind picks up
	sock_pivot.rotation.y = atan2(-wind_dir.y, wind_dir.x) - game.head.rotation.y
	sock_pivot.rotation.z = -lerpf(1.25, 0.05, clampf(wind_gust / 45.0, 0.0, 1.0)) + 0.06 * sin(_t * 7.0)
	cups.rotation.y += delta * wind_gust * 0.12

# ------------------------------------------------------------------ crane and load

func _command(dir: Vector2, vert: float, slow := false, dogged := false) -> void:
	_cmds.append([_t, dir, vert, slow, dogged])

## The crane driver acts on what they heard half a second ago, and holds
## everything still once the gusts are over the limit.
func _operate(delta: float) -> Vector2:
	var lag := _op_delay()
	while _cmds.size() > 1 and _cmds[1][0] <= _t - lag:
		_cmds.pop_front()
	if _cmds.size() > 0 and _cmds[0][0] <= _t - lag:
		_op_dir = _cmds[0][1]
		_op_vert = _cmds[0][2]
		_op_slow = _cmds[0][3] if _cmds[0].size() > 3 else false
		_op_dog = _cmds[0][4] if _cmds[0].size() > 4 else false
	# Over the wind limit the dogman should call "dog everything". If they
	# don't, the driver holds anyway after a moment, and it's noted.
	if wind_gust >= WIND_STOP:
		_wind_over_t += delta
		if _op_dog or _wind_over_t > WIND_GRACE:
			_op_dir = Vector2.ZERO
			_op_vert = 0.0
		if _wind_over_t > WIND_GRACE and not _op_dog and not _wind_noted and stage == "guide":
			_wind_noted = true
			wind_misses += 1
			game.hud.toast("Gusting over the limit with no \"dog everything\" call: the crane's holding, and it's noted", 2.4)
	else:
		_wind_over_t = 0.0
		_wind_noted = false
	if _op_dog or _estop_t > 0.0:
		_op_dir = Vector2.ZERO
		_op_vert = 0.0
	# Heard a knock: the driver eases off for a moment before carrying on
	if _flinch_t > 0.0:
		_flinch_t -= delta
		_op_dir = Vector2.ZERO
		_op_vert = maxf(_op_vert, 0.0)
	# Every call is driven a bit differently, and "stop" runs on a moment
	if _op_dir.length() > 0.1 and _op_dir != _last_dir:
		_speed_k = randf_range(0.9, 1.1)
	if _op_dir.length() < 0.1 and _last_dir.length() > 0.1 and stage == "guide":
		_coast = randf_range(0.0, _coast_max())
	var drive := _op_dir
	if _coast > 0.0:
		_coast -= delta
		drive = _last_dir
	else:
		_last_dir = _op_dir
	var auto_fly := stage != "guide"
	var sp := _drive_speed()
	var dv := (drive * sp - trolley_v).limit_length((1.0 if auto_fly else 0.7) * delta)
	trolley_v += dv
	trolley_xz += trolley_v * delta
	# The crane's zoning: under the dogman's whistle the hook can't be taken
	# further than ZONE_R from the landing, so the load never wanders off
	if stage == "guide":
		var out := trolley_xz - Vector2(LAT_X, RUNWAY_Z)
		if out.length() > ZONE_R:
			trolley_xz = Vector2(LAT_X, RUNWAY_Z) + out.limit_length(ZONE_R)
			var n := out.normalized()
			var vn := trolley_v.dot(n)
			if vn > 0.0:
				trolley_v -= n * vn
				dv = Vector2.ZERO
			if not _zone_hit:
				_zone_hit = true
				game.sfx.hit("tink")
				game.hud.toast("Zone limit: the crane won't take it further out. Bring it back in.", 1.8)
		elif out.length() < ZONE_R - 1.0:
			_zone_hit = false
	var rel := trolley_xz - Vector2(MAST.x, MAST.z)
	if rel.length() > JIB - 2.0 or rel.length() < 6.0:
		rel = rel.limit_length(JIB - 2.0)
		if rel.length() < 6.0:
			rel = rel.normalized() * 6.0
		trolley_xz = Vector2(MAST.x, MAST.z) + rel
		trolley_v = Vector2.ZERO
	var lift_k := LIFT_K if load_state == "lift" else 1.0
	hoist_v += clampf(_op_vert * (0.2 if _op_slow else (1.1 * lift_k if auto_fly else 0.45)) - hoist_v, -1.0 * lift_k * delta, 1.0 * lift_k * delta)
	var floor_y: float = 0.0 if load_state in ["laydown", "lift"] else game.work_y + 0.4
	cable_len = clampf(cable_len - hoist_v * delta, 4.0, CRANE_H - SLING - LS - floor_y)
	return dv / maxf(delta, 0.0001)

## How long the driver takes to act on a whistle. A First Day dogman gets a
## sharp driver.
func _op_delay() -> float:
	return OP_DELAY * (0.5 if stage == "guide" and help() == 0 else 1.0)

## How long "stop" can run on (First Day: not at all).
func _coast_max() -> float:
	return 0.0 if help() == 0 else 0.15

## How fast the driver takes the trolley along on the current call.
func _drive_speed() -> float:
	# Close in, the driver creeps it anyway
	var near_ghost := stage == "guide" and load != null and (Vector2(load.position.x, load.position.z) - Vector2(LAT_X, RUNWAY_Z)).length() < 1.5
	# Flying it in on their own (before the dogman takes it) the driver goes
	# at a working pace; under the dogman's whistle it's slower and careful
	var auto_fly := stage != "guide"
	return (0.35 if _op_slow or near_ghost else (1.6 if auto_fly else 0.8)) * _speed_k

## How quickly the load's swing dies away by itself. The help setting tames
## it: First Day barely swings, Ticketed hangs on a real rope.
func _swing_damp() -> float:
	if stage != "guide":
		return 0.8
	return [2.4, 1.3, 0.8][clampi(help(), 0, 2)]

func _update_load(delta: float, trolley_acc: Vector2) -> void:
	var L := cable_len + SLING + LS * 0.5
	var w_acc := wind_dir * 0.00012 * wind_gust * wind_gust
	var damp := (tag_strength + 0.5) if tagging else _swing_damp()
	var steps := 2
	var h := delta / steps
	for i in steps:
		var a := -(G / L) * swing - trolley_acc + w_acc - damp * swing_v
		swing_v += a * h
		swing += swing_v * h
	# Low over the runway, the crew on the platform get hands on it and steady it
	if stage == "guide" and load != null:
		var lxz := trolley_xz + swing
		var to_ghost := Vector2(LAT_X, RUNWAY_Z) - lxz
		var low := _load_bottom() - gap_bottom()
		if low < 1.6 and to_ghost.length() < 1.2:
			swing += to_ghost * minf(1.0, delta * 1.2)
			swing_v *= maxf(0.0, 1.0 - delta * 2.0)
			spin_v -= (spin - roundf(spin / (PI * 0.5)) * PI * 0.5) * delta * 3.0
	var target_spin := roundf(spin / (PI * 0.5)) * PI * 0.5
	var twist := 0.25 * sin(_t * 0.7) * wind_gust / 30.0 - 0.2 * spin
	if tagging:
		twist += (target_spin - spin) * 2.0 - 2.5 * spin_v
	else:
		twist -= 0.05 * spin_v
	spin_v += twist * delta
	spin += spin_v * delta
	_place_load()
	_collide()

func _load_bottom() -> float:
	return CRANE_H - cable_len - SLING - LS

func _place_load() -> void:
	var xz := trolley_xz + swing
	load.position = Vector3(xz.x, _load_bottom(), xz.y)
	load.rotation.y = spin

func _knock(msg: String) -> void:
	if _knock_cd > 0.0:
		return
	# Hit hard enough and the section buckles and comes down
	var impact := swing_v.length() + trolley_v.length() * 0.5 + absf(hoist_v)
	if stage == "guide" and impact > WRECK_V:
		_wreck()
		return
	_knock_cd = 0.3
	knocks += 1
	if game.autotest:
		print("[autotest]   knock at %.1fs (%s), impact %.2f" % [stage_t, msg, impact])
	game.sfx.hit("clang")
	game.shake = maxf(game.shake, 0.35)
	game.hud.toast(msg, 1.4)

## Keeps the section out of the boom head, the tower and the slab, and decides
## whether it has seated on the runway. A light knock bounces it back off what
## it hit (and the crane driver eases off for a moment); it never sticks there
## grinding, and the knock is only counted and heard when it first touches.
func _collide() -> void:
	_touch_prev = _touching
	_touching = false
	var gb := gap_bottom()
	var hb := head_y()
	var c := Vector2(load.position.x, load.position.z)
	var r := (LW * 0.5) * (absf(cos(spin)) + absf(sin(spin)))
	var bottom := load.position.y
	var top := bottom + LS
	# Seating on the runway
	if bottom <= gb + 0.03 and absf(c.x - LAT_X) < 1.7 and absf(c.y - RUNWAY_Z) < 1.9:
		var err := (c - Vector2(LAT_X, RUNWAY_Z)).length()
		var spin_err := absf(spin - roundf(spin / (PI * 0.5)) * PI * 0.5)
		if err < LAND_TOL and spin_err < SPIN_TOL and swing_v.length() < 1.0:
			_land()
			return
		# Set down off the mark: it bumps and lifts a touch, swinging back
		cable_len = CRANE_H - SLING - LS - (gb + 0.12)
		hoist_v = minf(hoist_v, 0.0)
		swing_v *= -0.4
		_contact("Knock! Line it up before you set it down")
		return
	# The boom head and frame above the gap
	if top > hb and bottom < hb + 1.6 and absf(c.x - LAT_X) < 1.95 + r and absf(c.y) < 1.95 + r:
		_bounce_box(c, Vector2(LAT_X, 0.0), 1.95 + r, "Knock! Keep it clear of the boom head")
		return
	# The tower below the gap: off its side, or lifted if it's come down on top
	if bottom < gb and absf(c.x - LAT_X) < 1.3 + r and absf(c.y) < 1.3 + r:
		var pen_side: float = minf(1.3 + r - absf(c.x - LAT_X), 1.3 + r - absf(c.y))
		var pen_down: float = gb - bottom
		if pen_down < pen_side and pen_down < 0.4:
			cable_len = CRANE_H - SLING - LS - (gb + 0.08)
			hoist_v = minf(hoist_v, 0.0)
			_contact("Knock! It's hitting the tower")
		else:
			_bounce_box(c, Vector2(LAT_X, 0.0), 1.3 + r, "Knock! It's hitting the tower")
		return
	# The slab edge
	var edge_x: float = game.SC.x + game.BW * 0.5 + 0.4
	if bottom < game.work_y + 1.4 and c.x - r < edge_x and absf(c.y - game.SC.z) - r < game.BD * 0.5 + 0.6 and load_state == "":
		var push: float = edge_x - (c.x - r)
		swing.x += push + 0.05
		if swing_v.x < 0.45:
			swing_v.x = maxf(-swing_v.x * 0.5, 0.45)
		trolley_v.x = maxf(trolley_v.x, 0.0)
		_place_load()
		_contact("Knock! Mind the slab edge")

## Pushes the load out of a square obstacle along the shallower side, and
## sends it swinging gently back off it.
func _bounce_box(c: Vector2, centre: Vector2, half: float, msg: String) -> void:
	var d := c - centre
	var px := half - absf(d.x)
	var pz := half - absf(d.y)
	var n: Vector2
	var push: float
	if px < pz:
		n = Vector2(1.0 if d.x >= 0.0 else -1.0, 0.0)
		push = px
	else:
		n = Vector2(0.0, 1.0 if d.y >= 0.0 else -1.0)
		push = pz
	swing += n * (push + 0.05)
	var vn := swing_v.dot(n)
	swing_v += n * (maxf(-vn * 0.5, 0.45) - vn)
	var tn := trolley_v.dot(n)
	if tn < 0.0:
		trolley_v -= n * tn
	_place_load()
	_contact(msg)

## First touch of a contact: the knock (and the driver eases off a moment).
func _contact(msg: String) -> void:
	_touching = true
	if _touch_prev:
		return
	_flinch_t = 0.6
	_knock(msg)

## The section takes a hard hit: it buckles, drops off the slings, crumples
## where it lands, and the crane has to go and rig a whole new one.
func _wreck() -> void:
	knocks += 1
	_wreck_v = Vector3(swing_v.x + trolley_v.x, -absf(hoist_v) - 0.5, swing_v.y + trolley_v.y)
	_wreck_spin = Vector3(randf_range(-1.6, 1.6), randf_range(-0.8, 0.8), randf_range(-1.6, 1.6))
	_wreck_landed = -1.0
	for c in load.get_children():
		if c is Node3D:
			c.set_meta("rot0", c.rotation)
			c.set_meta("bend", Vector3(randf_range(-0.7, 0.7), randf_range(-0.4, 0.4), randf_range(-0.7, 0.7)))
	for sl in slings:
		sl.visible = false
	game.sfx.hit("bang")
	game.sfx.hit("clang")
	game.shake = 1.0
	var who = _dogman if _dogman != null else dog_bot
	game.score.award(who, -80, "Sections wrecked", load.position + Vector3(0, LS + 1.0, 0))
	game.hud.toast("CRASH! The section's buckled and fallen. The crane has to rig another one.", 3.2)
	_set_stage("wreck")

func _update_wreck(delta: float) -> void:
	if load == null:
		return
	var floor_y := 0.0
	if absf(load.position.x - game.SC.x) < game.BW * 0.5 + 0.6 and absf(load.position.z - game.SC.z) < game.BD * 0.5 + 0.6:
		floor_y = game.work_y
	if _wreck_landed < 0.0:
		_wreck_v.y -= G * delta
		load.position += _wreck_v * delta
		load.rotation += _wreck_spin * delta
		_bend(minf(1.0, stage_t / 0.8) * 0.5)
		if load.position.y <= floor_y:
			load.position.y = floor_y
			_wreck_landed = 0.0
			_bend(1.6)
			load.scale = Vector3(1.0, 0.75, 1.0)
			load.rotation.x = clampf(load.rotation.x, -0.6, 0.6) + (0.9 if load.rotation.x >= 0.0 else -0.9)
			game.sfx.hit("bang")
			game.shake = 0.8
			var dust := CPUParticles3D.new()
			dust.amount = 60
			dust.lifetime = 1.2
			dust.one_shot = true
			dust.explosiveness = 0.9
			dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			dust.emission_box_extents = Vector3(2.0, 0.1, 2.0)
			dust.direction = Vector3(0, 1, 0)
			dust.spread = 80.0
			dust.initial_velocity_min = 1.5
			dust.initial_velocity_max = 4.0
			dust.gravity = Vector3(0, -3, 0)
			var dm := SphereMesh.new()
			dm.radius = 0.16
			dm.height = 0.32
			dm.radial_segments = 6
			dm.rings = 3
			dm.material = F.color_mat(Color("c9c2b4"))
			dust.mesh = dm
			add_child(dust)
			dust.position = load.position
			dust.emitting = true
			get_tree().create_timer(2.5).timeout.connect(dust.queue_free)
	else:
		_wreck_landed += delta
		if _wreck_landed > 2.5:
			# Cut up and carted off
			load.position.y -= delta * 0.8
			load.scale *= 1.0 - delta * 0.6
		if _wreck_landed > 4.5:
			load.queue_free()
			load = null
			game.hud.toast("Crane's rigging a new section. That's cost you time.", 2.4)
			_set_stage("refetch")

func _bend(k: float) -> void:
	for c in load.get_children():
		if c is Node3D and c.has_meta("bend"):
			c.rotation = (c.get_meta("rot0") as Vector3) + (c.get_meta("bend") as Vector3) * k

func _push_out(c: Vector2, from: Vector2, dist: float) -> void:
	var n := (c - from)
	if n.length() < 0.01:
		n = Vector2(0, 1)
	n = n.normalized()
	var want := from + n * dist if dist > 0.0 else c + n * 0.3
	swing += want - c
	swing_v = swing_v - n * 1.4 * swing_v.dot(n)
	_place_load()

## The crane slews over the laydown and lowers its hook to the section's top,
## then waits there for the slinger.
func _hold_at_laydown(delta: float) -> void:
	var over := Vector2(LAYDOWN.x, LAYDOWN.z)
	trolley_xz = trolley_xz.move_toward(over, 7.0 * delta)
	trolley_v = Vector2.ZERO
	cable_len = move_toward(cable_len, CRANE_H - SLING - LS - LAYDOWN.y, 9.0 * delta)
	hoist_v = 0.0
	swing = Vector2.ZERO
	swing_v = Vector2.ZERO
	spin = 0.0
	spin_v = 0.0
	load.position = LAYDOWN
	load.rotation = Vector3.ZERO

## The pin sets: a steel tray of four pins, each with its R-clip already on
## through the tip, so pin and clip come up as one piece. It waits on the
## street under a gin wheel at the deck edge; the screeder hauls it up and
## carries it over to the rigger.
func _build_pin_haul() -> void:
	bundle = Node3D.new()
	bundle.add_child(F.box(Vector3(0.62, 0.16, 0.34), F.mat("navy", true), Vector3(0, 0.08, 0)))
	for i in 4:
		var x := -0.21 + i * 0.14
		var pin := F.cylinder(0.04, 0.42, F.mat("steel", true), Vector3(x, 0.3, 0.0), 8)
		bundle.add_child(pin)
		bundle.add_child(F.cylinder(0.065, 0.05, F.mat("navy", true), Vector3(x, 0.52, 0.0), 8))
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.05
		tm.outer_radius = 0.075
		tm.rings = 10
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = F.color_mat(Color("e5383b"), true)
		ring.rotation.x = PI * 0.5
		ring.position = Vector3(x, 0.18, 0.06)
		bundle.add_child(ring)
	# The rope handle the gin wheel hooks into
	bundle.add_child(F.beam(Vector3(-0.3, 0.16, 0), Vector3(0, 0.62, 0), 0.02, F.mat("rope")))
	bundle.add_child(F.beam(Vector3(0.3, 0.16, 0), Vector3(0, 0.62, 0), 0.02, F.mat("rope")))
	bundle.visible = false
	add_child(bundle)
	haul_rope = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	cm.height = 1.0
	cm.radial_segments = 5
	haul_rope.mesh = cm
	haul_rope.material_override = F.mat("rope")
	haul_rope.visible = false
	add_child(haul_rope)
	# A davit with its gin wheel on the deck edge
	laydown_mark = Node3D.new()
	laydown_mark.add_child(F.box(Vector3(0.1, 1.9, 0.1), F.mat("yellow_dark"), Vector3(0, 0.95, 0)))
	laydown_mark.add_child(F.box(Vector3(0.08, 0.08, 0.9), F.mat("yellow_dark"), Vector3(0, 1.88, 0.42)))
	laydown_mark.add_child(F.cylinder(0.14, 0.06, F.mat("steel", true), Vector3(0, 1.8, 0.82), 12))
	laydown_mark.visible = false
	add_child(laydown_mark)

func _gin_top() -> Vector3:
	return Vector3(_pin_haul().x, game.work_y + 1.8, _pin_haul().z + 0.82)

## Pin sets each frame: sitting on the street, coming up the rope, or up on
## the rigger's platform.
func _update_bundle(_delta: float) -> void:
	var on: bool = active and game.kit == "tower"
	laydown_mark.visible = false   # (pins come up the haul rope from the base now)
	if on:
		laydown_mark.position = Vector3(_pin_haul().x, game.work_y, _pin_haul().z - 0.9)
	haul_rope.visible = false
	if not on:
		bundle.visible = false
		return
	match bundle_state:
		"ground":
			bundle.visible = false
			return
			var top := _gin_top()
			var bottom := Vector3(top.x, 0.0, top.z)
			var at := bottom.lerp(Vector3(top.x, top.y - 0.75, top.z), ease(haul_prog, 0.8))
			if bundle.get_parent() != self:
				bundle.get_parent().remove_child(bundle)
				add_child(bundle)
			bundle.position = at
			bundle.rotation = Vector3(0, 0, 0.05 * sin(_t * 3.0) * haul_prog)
			_line(haul_rope, top, at + Vector3(0, 0.62, 0))
		"up":
			bundle.visible = pinsets > 0
			if bundle.get_parent() != self:
				bundle.get_parent().remove_child(bundle)
				add_child(bundle)
			bundle.position = platform_spot() + Vector3(-1.2, 0.0, -0.4)
			bundle.rotation = Vector3.ZERO
			# One pin goes from the tray each time the rigger takes a set
			for i in 4:
				(bundle.get_child(1 + i * 3) as Node3D).visible = i < pinsets
				(bundle.get_child(2 + i * 3) as Node3D).visible = i < pinsets
				(bundle.get_child(3 + i * 3) as Node3D).visible = i < pinsets

## Hauling: hold A at the gin wheel.
func haul(p, delta: float) -> void:
	haul_prog = minf(1.0, haul_prog + delta / HAUL_TIME)
	p.face(_gin_top())
	var k := sin(_t * 10.0)
	p.set_arms(-2.2 + 0.5 * k, -2.2 - 0.5 * k)
	if fmod(_t, 0.4) < delta:
		game.sfx.hit("tink")
	if haul_prog >= 1.0:
		bundle_state = "carried"
		for i in 4:
			for j in 3:
				(bundle.get_child(1 + i * 3 + j) as Node3D).visible = true
		bundle.get_parent().remove_child(bundle)
		p.hold_item(bundle, "pinsets")
		bundle.visible = true
		game.score.award(p, 10, "Pin sets up")
		p.bounce()

## Handing the pin sets over at the climbing frame.
func deliver(p) -> void:
	p.release_item()
	bundle_state = "up"
	pinsets = PINS
	add_child(bundle)
	game.score.award(p, 15, "Pin sets up")
	game.sfx.hit("clank")
	p.bounce()
	if _rigger != null:
		_rigger.bark("Ta!")
	game.hud.toast("Pin sets up on the frame", 1.4)

func needs_pins() -> bool:
	return active and game.kit == "tower" and bundle_state == "ground"

## A bag of pins is on its way up (in someone's hands or on the haul rope).
func pins_coming() -> bool:
	if game.line.hook["kind"] == "pins":
		return true
	for q in game.players:
		if q.held_kind == "pins":
			return true
	return false

## The bag of pins reached the frame on the haul rope.
func pins_arrived() -> void:
	bundle_state = "up"
	pinsets = PINS
	game.sfx.hit("clank")
	if _rigger != null:
		_rigger.bark("Ta!")
	game.hud.toast("Pins up on the frame", 1.4)

## Someone carried the bag of pins up themselves (the rigger often grabs it
## on the way): it counts the moment they're on the frame or beside it.
func _carried_pins() -> void:
	if not needs_pins():
		return
	if game.autotest and OS.get_cmdline_user_args().has("--carrypins") and game.line.hook["kind"] != "pins":
		# Test: the rigger turns up with the bag in hand
		for q in game.players:
			if q.busy == "rigger" and q.held == null:
				q.hold_item(game.line.make_item("pins"), "pins")
				print("[autotest]   rigger brought the pins up by hand")
	var st: Vector3 = (game.stations["rigger"]["node"] as Node3D).global_position
	for q in game.players:
		if q.held_kind != "pins":
			continue
		var close: bool = q.zone == "deck" and Vector2(q.position.x - st.x, q.position.z - st.z).length() < 3.0
		if q.busy == "rigger" or close:
			var it: Node3D = q.release_item()
			if it:
				it.queue_free()
			pins_arrived()
			if not q.bot:
				game.score.award(q, 10, "Brought the pins up")
			return

## The hook's down over the laydown and the section is waiting for its slings.
func needs_sling() -> bool:
	return active and load != null and load_state == "laydown"

func hook_ready() -> bool:
	return needs_sling() and trolley_xz.distance_to(Vector2(LAYDOWN.x, LAYDOWN.z)) < 0.2 and absf(cable_len - (CRANE_H - SLING - LS - LAYDOWN.y)) < 0.3

## Slinging: four legs onto the top lugs, then "take it up".
func sling(p, delta: float) -> void:
	sling_prog = minf(1.0, sling_prog + delta / SLING_TIME)
	p.face(LAYDOWN)
	p.set_arms(-2.6 + 0.3 * sin(_t * 9.0), -2.6 - 0.3 * sin(_t * 9.0))
	if sling_prog >= 1.0:
		load_state = "lift"
		game.score.award(p, 15, "Slinging")
		game.sfx.hit("whistle:hoist")
		game.haptic(p, "60")
		p.bark("Take it up!")
		p.bounce()

func _park_crane(delta: float) -> void:
	var park := Vector2(-2.0, 10.0)
	trolley_xz = trolley_xz.lerp(park, minf(1.0, delta * 0.25))
	cable_len = lerpf(cable_len, 12.0, minf(1.0, delta * 0.4))

func _draw_crane() -> void:
	var rel := trolley_xz - Vector2(MAST.x, MAST.z)
	crane_slew.rotation.y = atan2(-rel.y, rel.x)
	trolley.position.x = rel.length()
	var top := Vector3(trolley_xz.x, CRANE_H - 0.6, trolley_xz.y)
	var hook_pos := Vector3(trolley_xz.x, CRANE_H - cable_len, trolley_xz.y)
	if crane_busy() and load_state == "laydown":
		# Hook down over the laydown; the slings go on one leg at a time
		var legs := int(floor(sling_prog * 4.0 + 0.001))
		var corners0 := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
		for i in 4:
			if i < legs:
				var cpt0: Vector3 = load.global_transform * (corners0[i] * (LW * 0.5) + Vector3(0, LS, 0))
				_line(slings[i], hook_pos, cpt0)
			else:
				_line(slings[i], hook_pos, hook_pos + Vector3(0.12 * (corners0[i] as Vector3).x, -1.2, 0.12 * (corners0[i] as Vector3).z))
	elif crane_busy():
		hook_pos = Vector3(load.position.x, load.position.y + LS + SLING, load.position.z)
		var corners := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
		for i in 4:
			var cpt: Vector3 = load.global_transform * (corners[i] * (LW * 0.5) + Vector3(0, LS, 0))
			_line(slings[i], hook_pos, cpt)
	else:
		for s in slings:
			s.visible = false
	_line(cable, top, hook_pos + Vector3(0, 0.4, 0))
	hook.position = hook_pos + Vector3(0, 0.4, 0)

# ------------------------------------------------------------------ rigger

func _update_ram(delta: float) -> void:
	match ram_state:
		"push":
			var step := minf(delta / 0.5, 1.0 - ram)
			ram += step
			var rise := minf(STROKE * step, LS + CLEAR - lifted)
			lifted += rise
			game.head.position.y += rise
			if ram >= 1.0:
				ram_state = "return"
				game.sfx.hit("thunk")
		"return":
			ram = maxf(0.0, ram - delta / 0.4)
			if ram <= 0.0:
				ram_state = "ready"
				if _ram_queued:
					_pump()
		"stall":
			stall_t -= delta
			ram = maxf(0.0, ram - delta)
			if stall_t <= 0.0:
				ram_state = "ready"

func _pump() -> void:
	if ram_state != "ready":
		# Pressed early: the stroke goes as soon as the ram's back
		_ram_queued = true
		return
	_ram_queued = false
	if ram_state == "ready":
		ram_state = "push"
		game.sfx.hit("clank")
		if _rigger != null:
			game.score.award(_rigger, 2, "Rigging")
			game.haptic(_rigger, "40")
	elif ram_state != "stall":
		ram_state = "stall"
		stall_t = 1.2
		game.sfx.hit("hiss")
		game.hud.toast("Too quick: let the ram come back before the next stroke", 1.4)

## The joint between the new section and the one below: at each corner leg a
## lug plate on each section, with a hole, and a pin through both.
func _build_pin_props() -> void:
	var steel := F.mat("steel", true)
	for i in PINS:
		var l := {}
		l["lower"] = F.box(Vector3(0.46, 0.56, 0.07), F.mat("yellow_dark", true))
		l["upper"] = F.box(Vector3(0.46, 0.56, 0.07), steel)
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color("101418")
		hm.emission_enabled = true
		hm.emission = Color.BLACK
		l["hole_mat"] = hm
		for key in ["lower", "upper"]:
			var plate: Node3D = l[key]
			var hole := F.cylinder(0.09, 0.09, hm, Vector3(0, 0, 0), 12)
			hole.rotation.x = PI * 0.5
			plate.add_child(hole)
			plate.visible = false
			add_child(plate)
		# The pin: a steel shaft with a fat head, red-painted tip
		var pin := Node3D.new()
		var shaft := F.cylinder(0.07, 0.6, F.mat("steel", true), Vector3(0, 0, -0.3), 10)
		shaft.rotation.x = PI * 0.5
		pin.add_child(shaft)
		var headm := F.cylinder(0.13, 0.1, F.mat("navy", true), Vector3(0, 0, 0.05), 12)
		headm.rotation.x = PI * 0.5
		pin.add_child(headm)
		var tip := F.cylinder(0.072, 0.1, F.mat("red"), Vector3(0, 0, -0.58), 10)
		tip.rotation.x = PI * 0.5
		pin.add_child(tip)
		pin.visible = false
		add_child(pin)
		l["pin"] = pin
		# R-clip: a springy loop that snaps through the hole in the pin's tip
		var clip := Node3D.new()
		var loop := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.08
		tm.outer_radius = 0.11
		tm.rings = 12
		tm.ring_segments = 5
		loop.mesh = tm
		loop.material_override = F.color_mat(Color("e5383b"), true)
		loop.rotation.z = PI * 0.5
		loop.position = Vector3(0, -0.07, 0)
		clip.add_child(loop)
		clip.add_child(F.box(Vector3(0.02, 0.2, 0.02), F.color_mat(Color("e5383b")), Vector3(0, 0.0, 0)))
		clip.visible = false
		add_child(clip)
		l["clip"] = clip
		lugs.append(l)
	# Podger: a tapered steel spike for drawing the holes into line
	podger = Node3D.new()
	var pc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.0
	cm.height = 0.5
	pc.mesh = cm
	pc.material_override = F.mat("steel", true)
	pc.rotation.x = -PI * 0.5
	podger.add_child(pc)
	podger.visible = false
	add_child(podger)
	# Lump hammer: handle and a heavy head that glows when it's wound up right
	hammer = Node3D.new()
	# (a cartoon-big lump hammer, so the swing reads next to a chibi's head)
	hammer.add_child(F.box(Vector3(0.06, 0.62, 0.06), F.mat("trunk"), Vector3(0, -0.27, 0)))
	hammer_head_mat = StandardMaterial3D.new()
	hammer_head_mat.albedo_color = Color("3a4048")
	hammer_head_mat.emission_enabled = true
	hammer_head_mat.emission = Color.BLACK
	hammer.add_child(F.box(Vector3(0.36, 0.21, 0.21), hammer_head_mat, Vector3(0, -0.6, 0)))
	hammer.visible = false
	add_child(hammer)
	sparks = CPUParticles3D.new()
	sparks.amount = 40
	sparks.lifetime = 0.45
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = false
	sparks.spread = 70.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 5.0
	sparks.gravity = Vector3(0, -9, 0)
	var sm := BoxMesh.new()
	sm.size = Vector3(0.03, 0.03, 0.09)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color("ffd36b")
	sm.material = smat
	sparks.mesh = sm
	sparks.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	add_child(sparks)
	align_arrow = _arrow(Color("ffc72c"), 0.3)
	align_arrow.visible = false
	# A crew rigger shown when the test bot is pinning
	rig_npc = F.chibi(Color("ff7a1a"), Color("f4f7fa"))
	var hand := Node3D.new()
	hand.name = "HandR"
	hand.position = Vector3(0, -0.46, 0)
	rig_npc.get_node("ArmR").add_child(hand)
	rig_npc.visible = false
	add_child(rig_npc)

func _corner(i: int) -> Vector3:
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var cv: Vector2 = corners[i]
	return Vector3(cv.x, 0, cv.y).normalized()

func _start_pins() -> void:
	pin_i = 0
	hit_i = 0
	depth = 0.0
	power = 0.0
	winding = false
	hole_off = randf_range(0.05, 0.11) * (1.0 if randf() < 0.5 else -1.0)
	pin_sub = "wait"
	if pinsets > 0:
		_split_set()
	_show_pins()

## The rigger takes a pin set off the tray and pulls its R-clip out, ready to
## drive the pin and clip it back on.
func _split_set() -> void:
	if pinsets <= 0:
		pin_sub = "wait"
		return
	pinsets -= 1
	_pin_split_t = 0.0
	pin_sub = "align"
	game.sfx.hit("tink")
	# (the rigger pulls the clip off as they take the pin: no button for it)

## Up/down on the stick inches the frame's rams to bring the holes in line.
func _inch(v: float, delta: float) -> void:
	hole_off = clampf(hole_off + v * 0.07 * delta, -0.15, 0.15)

func _podger() -> void:
	if cool > 0.0:
		return
	if absf(hole_off) > PODGER_TOL:
		cool = 0.15
		pin_sub = "align"
		game.sfx.hit("tink")
		_podger_t = 0.0      # it bounces off the edge of the hole
		podger.set_meta("jam", true)
		return
	hole_off = 0.0
	podger.set_meta("jam", false)
	if _rigger != null:
		game.score.award(_rigger, 5, "Rigging")
		game.haptic(_rigger, "30")
	_podger_t = 0.0
	pin_sub = "drive"
	depth = 0.0
	hit_i = 0
	power = 0.0
	(lugs[pin_i]["pin"] as Node3D).visible = true
	_set_pin_depth(pin_i, 0.0)
	game.sfx.hit("clank")

func _swing_start() -> void:
	if cool > 0.0 or pin_sub != "drive":
		return
	winding = true
	power = 0.0

func _swing_release() -> void:
	if not winding:
		return
	winding = false
	var pw := power
	power = 0.0
	cool = 0.15
	_strike_t = 0.18
	# The blow lands a beat after you let go, when the hammer comes down onto
	# the pin: that's when the clang, the sparks and the pin moving happen
	get_tree().create_timer(0.08).timeout.connect(_land_blow.bind(pw, pin_i))

func _land_blow(pw: float, at_pin: int) -> void:
	if not active or stage != "pin" or at_pin != pin_i or pin_sub != "drive":
		return
	var l: Dictionary = lugs[pin_i]
	var head_at: Vector3 = (l["pin"] as Node3D).global_position + (l["dir"] as Vector3) * 0.08
	if pw >= SWEET and pw <= SWEET + SWEET_W:
		depth += 1.0 / HITS
		hit_i += 1
		game.pop("CLANG!", head_at + Vector3(0, 0.4, 0), Color("ffd36b"))
		game.sfx.hit("clang")
		if _rigger != null:
			game.score.award(_rigger, 5, "Rigging")
			game.haptic(_rigger, "90")
		game.shake = maxf(game.shake, 0.15)
		sparks.position = head_at
		sparks.direction = l["dir"]
		sparks.amount = 40
		sparks.restart()
		sparks.emitting = true
	elif pw > 0.3:
		depth += 1.0 / (HITS * 3.0)
		game.pop("tink", head_at, Color("b9c5d6"))
		game.sfx.hit("tink")
		sparks.position = head_at
		sparks.amount = 8
		sparks.restart()
		sparks.emitting = true
	else:
		return
	_set_pin_depth(pin_i, minf(depth, 1.0))
	if depth >= 0.99:
		pin_sub = "clip"

func _clip(with_clip: bool) -> void:
	var l: Dictionary = lugs[pin_i]
	if with_clip:
		if _rigger != null:
			game.score.award(_rigger, 10, "R-clips on")
		game.pop("R-clip on", (l["clip"] as Node3D).global_position + Vector3(0, 0.5, 0))
		(l["clip"] as Node3D).visible = true
		_clip_t = 0.35
		sparks.position = (l["clip"] as Node3D).global_position
		sparks.amount = 14
		sparks.restart()
		sparks.emitting = true
	else:
		unclipped += 1
		if _rigger != null:
			game.score.award(_rigger, -15, "Pins left without an R-clip")
	game.sfx.hit("tink")
	pin_i += 1
	depth = 0.0
	# The next corner's holes sit a little off too: draw them true again
	hole_off = randf_range(0.035, 0.07) * (1.0 if randf() < 0.5 else -1.0)
	if pin_i >= PINS:
		if unclipped > 0:
			game.hud.toast("Inspection: %d pin%s without an R-clip. That's a safety note." % [unclipped, "" if unclipped == 1 else "s"], 2.2)
		hammer.visible = false
		rig_npc.visible = false
		hole_off = 0.0
		_seat_from = game.head.position.y
		_set_stage("seat")
		return
	pin_sub = "wait"
	if pinsets > 0:
		_split_set()

func _show_pins() -> void:
	var gb := gap_bottom()
	for i in PINS:
		var l: Dictionary = lugs[i]
		var d := _corner(i)
		l["dir"] = d
		# Lugs stick out past the climbing frame's posts so they can be seen
		l["base"] = Vector3(LAT_X, gb, 0) + d * (LW * 0.5 * 1.414 + 0.5)
		for key in ["lower", "upper"]:
			var plate: Node3D = l[key]
			plate.visible = true
			plate.basis = Basis.looking_at(d, Vector3.UP)
		(l["pin"] as Node3D).visible = false
		(l["clip"] as Node3D).visible = false
	_update_pins(0.0)

## The pin sits out in the holes and is driven inward as depth goes 0 -> 1.
func _set_pin_depth(i: int, dep: float) -> void:
	var l: Dictionary = lugs[i]
	var d: Vector3 = l["dir"]
	var pin: Node3D = l["pin"]
	pin.basis = Basis.looking_at(-d, Vector3.UP)
	pin.position = (l["base"] as Vector3) + d * (0.2 + 0.36 * (1.0 - dep))
	var clip: Node3D = l["clip"]
	clip.position = (l["base"] as Vector3) - d * 0.12
	clip.basis = Basis.looking_at(-d, Vector3.UP)

## Plates, the podger stab, the hammer glow and the clip snap, every frame.
func _update_pins(delta: float) -> void:
	if stage != "pin" or lugs.is_empty():
		return
	for i in PINS:
		var l: Dictionary = lugs[i]
		var d: Vector3 = l["dir"]
		var base: Vector3 = l["base"]
		(l["lower"] as Node3D).position = base + d * 0.12
		# Until it's drifted true, the new section's plate sits off by the
		# hole offset (drawn a touch larger than life so you can see it)
		var off := hole_off * 2.5 if i == pin_i else 0.0
		(l["upper"] as Node3D).position = base + d * 0.19 + Vector3(0, off, 0)
		var hm: StandardMaterial3D = l["hole_mat"]
		var lined := absf(hole_off) <= PODGER_TOL
		if i == pin_i and pin_sub == "align":
			hm.emission = (Color(0.2, 0.9, 0.4) if lined else Color(1.0, 0.25, 0.15)) * (0.6 + 0.4 * sin(_t * 8.0))
		else:
			hm.emission = Color.BLACK
	# An arrow showing which way to move the stick to line the holes up
	if align_arrow != null:
		var show: bool = pin_sub == "align" and pin_i < PINS and absf(hole_off) > PODGER_TOL and _rigger != null and (not _rigger.bot or game.shot_dir != "")
		align_arrow.visible = show
		if show:
			var lb: Dictionary = lugs[pin_i]
			var dd: Vector3 = lb["dir"]
			var sd := dd.cross(Vector3.UP).normalized()
			align_arrow.position = (lb["base"] as Vector3) + dd * 0.2 + sd * 0.5 + Vector3(0, 0.3 * (1.0 if hole_off < 0.0 else -1.0) + 0.06 * sin(_t * 6.0), 0)
			_point(align_arrow, Vector3.UP if hole_off < 0.0 else Vector3.DOWN)
	if _pinning:
		_pinning.position.y = gap_bottom() + hole_off
	# Lining up: the podger's tip is in the holes and the rigger levers on it,
	# drifting the new section's plate up or down until the holes line up
	if pin_sub == "align" and _podger_t < 0.0 and pin_i < PINS:
		var la: Dictionary = lugs[pin_i]
		var da: Vector3 = la["dir"]
		var sa := da.cross(Vector3.UP).normalized()
		podger.visible = true
		podger.position = (la["base"] as Vector3) + da * 0.45 + Vector3(0, hole_off * 1.2, 0)
		podger.basis = Basis(sa, _lever * 0.45 + 0.04 * sin(_t * 9.0) * absf(_lever)) * Basis.looking_at(-da, Vector3.UP)
	elif pin_sub != "align" and _podger_t < 0.0:
		podger.visible = false
	# Podger: driven home (or bouncing off a misaligned hole)
	if _podger_t >= 0.0 and pin_i < PINS:
		_podger_t += delta
		var l2: Dictionary = lugs[pin_i]
		var d2: Vector3 = l2["dir"]
		var u := _podger_t / 0.45
		var jam: bool = podger.get_meta("jam", false)
		var depth_in := sin(clampf(u, 0.0, 1.0) * PI) * (0.08 if jam else 0.35)
		podger.visible = u < 1.0
		podger.position = (l2["base"] as Vector3) + d2 * (0.55 - depth_in)
		podger.basis = Basis.looking_at(-d2, Vector3.UP)
		if u >= 1.0:
			_podger_t = -1.0
	# Clip snap: it pops in with a little overshoot
	if _clip_t > 0.0 and pin_i > 0:
		_clip_t -= delta
		var c: Node3D = lugs[pin_i - 1]["clip"]
		var k := 1.0 + 0.6 * sin(clampf(_clip_t / 0.35, 0.0, 1.0) * PI)
		c.scale = Vector3.ONE * k
	# Hammer glow: yellow in the sweet spot, red once it's over-swung
	if winding and power >= SWEET and power <= SWEET + SWEET_W:
		hammer_head_mat.emission = Color(1.0, 0.8, 0.2) * 1.6
	elif winding and power > SWEET + SWEET_W:
		hammer_head_mat.emission = Color(1.0, 0.2, 0.1) * 1.4
	else:
		hammer_head_mat.emission = Color.BLACK
	_strike_t = maxf(0.0, _strike_t - delta)

## Stands the rigger (a player or the crew rigger) outside the pin being worked.
func _stand_at_pin(who) -> void:
	if pin_i >= PINS or lugs.is_empty():
		return
	var l: Dictionary = lugs[pin_i]
	var d: Vector3 = l["dir"]
	who.visible = true
	var side := d.cross(Vector3.UP).normalized()
	var spot: Vector3
	var m: Node3D = who.model if who is Node3D and who.get("model") != null else who
	if pin_sub == "drive":
		# Square on to the pin's head, hammer arm in line with it (the stance
		# is trimmed every frame in _pose_rigger so the swing lands true)
		var head: Vector3 = (l["pin"] as Node3D).global_position + d * 0.08
		spot = Vector3(head.x, (l["base"] as Vector3).y - PLATFORM_DROP, head.z) + d * 0.55 + _stand_adj
		m.rotation.y = atan2(-d.x, -d.z)
	else:
		_stand_adj = Vector3.ZERO
		spot = (l["base"] as Vector3) + d * 0.6 + side * 0.55 + Vector3(0, -PLATFORM_DROP, 0)
		var look: Vector3 = (l["base"] as Vector3) - spot
		m.rotation.y = atan2(look.x, look.z)
	var step: Vector3 = spot - who.position
	if step.length() > 0.02 and step.length() < 3.0:
		who._walk += minf(step.length(), 0.05) * 30.0
	who.position = who.position.lerp(spot, 0.25) if who.position.distance_to(spot) < 3.0 else spot
	var hand: Node3D = who.hand_r if who.get("hand_r") != null else who.get_node("ArmR/HandR")
	if hammer.get_parent() != hand:
		if hammer.get_parent():
			hammer.get_parent().remove_child(hammer)
		hand.add_child(hammer)
		hammer.position = Vector3.ZERO
		hammer.rotation = Vector3.ZERO
	hammer.visible = true

## Points an arm (its pivot is the shoulder, the arm hangs along -Y) so the
## hand, or whatever's in it, reaches toward `target`.
static func _aim_arm(arm: Node3D, target: Vector3) -> void:
	var dir := target - arm.global_position
	if dir.length() < 0.01:
		return
	var y := -dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	arm.global_basis = Basis(x, y, z)

## The rigger's arms, every frame: the left hand on the podger bar (levering
## the holes into line, then driving it home), the right swinging the lump
## hammer back and bringing its head down square on the pin.
func _pose_rigger(who) -> void:
	var m: Node3D = who.model if who.get("model") != null else who
	var al: Node3D = m.get_node("ArmL")
	var ar: Node3D = m.get_node("ArmR")
	if pin_i >= PINS or lugs.is_empty():
		al.rotation = Vector3(-0.3, 0, -0.25)
		ar.rotation = Vector3(-0.3, 0, 0.25)
		return
	var l: Dictionary = lugs[pin_i]
	var d: Vector3 = l["dir"]
	var base: Vector3 = l["base"]
	# Left hand: on the podger's handle end while it's in use, else on the plate
	if podger.visible:
		var handle: Vector3 = podger.global_transform * Vector3(0, 0, 0.27)
		_aim_arm(al, handle)
	else:
		_aim_arm(al, base + d * 0.35 + Vector3(0, 0.05, 0))
	var head: Vector3 = (l["pin"] as Node3D).global_position + d * 0.08
	hammer.basis = Basis()
	hammer.position = Vector3.ZERO
	match pin_sub:
		"drive":
			_swing(who, m, ar, head, d)
			return
		"clip":
			_aim_arm(ar, base - d * 0.12)
		_:
			# Hammer hanging ready by your side
			ar.rotation = Vector3(-0.35, 0, 0.3)

## The lump hammer in the right hand, swung in the upright plane through the
## pin: wound back up over the shoulder as A is held, then brought over and
## down so the head's face lands square on the end of the pin. The whole arm
## and hammer turn together about the shoulder, so the head always meets the
## pin exactly, and the rigger shuffles until the swing lines up with it.
func _swing(who, m: Node3D, ar: Node3D, head: Vector3, d: Vector3) -> void:
	var hand: Node3D = hammer.get_parent()
	var sc: Vector3 = hand.global_basis.get_scale()
	var arm_len: float = hand.global_position.distance_to(ar.global_position)
	var axis: Vector3 = Vector3.UP.cross(d).normalized()
	# At impact the handle leans back toward the rigger (a short chibi arm
	# couldn't reach it upright), with the head's face square to the pin
	var beta := -0.75
	var hit_c: Vector3 = head + d.rotated(axis, beta) * 0.18 * sc.x       # head's centre at impact
	var grip: Vector3 = hit_c - Vector3.UP.rotated(axis, beta) * 0.6 * sc.y  # hand at the end of the handle
	var pivot: Vector3 = ar.global_position
	var theta := 0.45
	if _strike_t > 0.0:
		var k: float = clampf((_strike_t / 0.18 - 0.55) / 0.45, 0.0, 1.0)
		theta = _strike_from * k * k
	elif winding:
		var shake := 0.08 * sin(_t * 40.0) * maxf(0.0, power - SWEET - SWEET_W) * 8.0
		theta = 0.45 + 2.5 * minf(power, 1.12) + shake
		_strike_from = theta
	_theta = theta if _strike_t > 0.0 else lerpf(_theta, theta, 0.5)
	theta = _theta
	# Out a touch to the side as it goes overhead, clear of the hard hat
	var out_side: Vector3 = _cam_side * 0.3 * sin(clampf(theta * 0.8, 0.0, PI))
	_aim_arm(ar, pivot + (grip - pivot).rotated(axis, theta) + out_side)
	var bx: Vector3 = d.rotated(axis, beta + theta)
	var by: Vector3 = -Vector3.UP.rotated(axis, beta + theta)
	var bz: Vector3 = bx.cross(by).normalized()
	var b := Basis(bx * sc.x, by * sc.y, bz * sc.z)
	var head_at: Vector3 = pivot + (hit_c - pivot).rotated(axis, theta) + out_side
	hammer.global_transform = Transform3D(b, head_at - b * Vector3(0, -0.6, 0))
	# Trim the stance: shoulder an arm's length back from the grip, in line
	var v: Vector3 = pivot - grip
	var side: Vector3 = d.cross(Vector3.UP).normalized()
	var lateral: float = v.dot(side)
	var along: float = v.dot(d)
	var want: float = sqrt(maxf(arm_len * arm_len - v.y * v.y, 0.02))
	_stand_adj += (side * -lateral + d * (want - along)) * 0.3
	_stand_adj.y = 0.0
	_stand_adj = _stand_adj.limit_length(0.8)
	# Which side the hammer arm is on, for the close-up camera
	var body: Vector3 = m.global_position
	var cs: Vector3 = (pivot - body)
	cs.y = 0.0
	cs = side * signf(cs.dot(side))
	if cs.length() > 0.5:
		_cam_side = cs

## Close-up camera eye for the pinning: side on to the swing, from the
## hammer-arm side, so the arm, hammer and pin are all in clear view.
func close_eye(target: Vector3) -> Vector3:
	if pin_i >= PINS or lugs.is_empty():
		return target + Vector3(0, 1, 2)
	var d: Vector3 = lugs[pin_i]["dir"]
	if pin_sub == "drive":
		return target + _cam_side * 2.3 + d * 0.5 + Vector3(0, 0.55, 0)
	var side := d.cross(Vector3.UP).normalized()
	# Lining up and clipping: from the far side of the rigger and above, looking
	# down onto the plates past their hard hat
	return target + d * 1.5 - side * 1.3 + Vector3(0, 1.0, 0)

## Where a close-up camera should look for this player's hands, or INF.
func work_focus(p) -> Vector3:
	# Slinging on the laydown: the street band moves in on it
	if p != null and p.zone == "ground" and needs_sling() and Vector2(p.position.x - LAYDOWN.x, p.position.z - LAYDOWN.z).length() < 3.2:
		return LAYDOWN + Vector3(0, 1.6, -0.6)
	if p != null and p.busy != "rigger":
		return Vector3.INF
	if stage == "pin" and pin_i < PINS and not lugs.is_empty():
		var dd: Vector3 = lugs[pin_i]["dir"]
		if pin_sub == "drive":
			# Between the pin's head and the top of the swing
			return (lugs[pin_i]["pin"] as Node3D).global_position + dd * 0.4 + Vector3(0, 0.3, 0)
		return (lugs[pin_i]["base"] as Vector3) + dd * 0.3
	if p != null and stage == "jack":
		return Vector3(LAT_X + 1.5, gap_bottom() + 0.5, 0)
	return Vector3.INF

# ------------------------------------------------------------------ players

## The tag line's there to take: the crane has the load up higher than the deck
## and near enough the tag spot, or near enough the scaffold edge, to run out to.
func tag_ready() -> bool:
	if load == null or not (stage in ["fly", "guide"]) or load_state != "" or not crane_busy():
		return false
	if _load_bottom() < game.work_y + 0.5:
		return false
	var c := _tag_corner()
	var spot: Vector3 = game.deck_pos("tag")
	if Vector2(c.x - spot.x, c.z - spot.z).length() < TAG_REACH:
		return true
	# ...or anywhere it's come in near enough the scaffold edge to reach out
	# for (the big slab: the load swings in a long way off the tag spot)
	if Vector2(c.x - spot.x, c.z - spot.z).length() > TAG_FAR:
		return false
	var mid: Vector3 = load.global_position
	return _deck_within(c, TAG_EDGE) or _deck_within(mid, TAG_EDGE + LW * 0.75)

## True if there's deck or scaffold walkway within `r` m (across) of `at`.
func _deck_within(at: Vector3, r: float) -> bool:
	for i in 17:
		var off := Vector3.ZERO
		if i > 0:
			var a := float(i - 1) / 8.0 * TAU
			off = Vector3(cos(a), 0, sin(a)) * (r if i <= 8 else r * 0.5)
		if game._walkable(Vector3(at.x, game.work_y, at.z) + off, "deck"):
			return true
	return false

func _tag_corner() -> Vector3:
	return load.global_transform * Vector3(LW * 0.5, 0.3, LW * 0.5)

func _drop_tag(p) -> void:
	p.busy = ""
	if tag_hand == p:
		tag_hand = null
	_tag_sub = ""

## Which station the climb needs someone on right now ("" if none).
func needed() -> Array:
	var out := []
	if not active:
		return out
	var has_rigger := false
	var has_dogman := false
	for p in game.players:
		if p.busy == "rigger":
			has_rigger = true
		if p.busy == "dogman":
			has_dogman = true
	if stage in ["jack", "roll", "pin"] and not has_rigger:
		out.append("rigger")
	if stage == "guide":
		if not has_dogman:
			out.append("dogman")
	if tag_ready() and tag_hand == null:
		out.append("tag")
	return out

## While the load's being dogged: the middle of the dogman, the load and the
## landing, and how far the camera has to stand back to keep all three in
## shot. [centre, radius]
func guide_frame() -> Array:
	var pts := [Vector3(LAT_X, gap_bottom() + LS * 0.5, RUNWAY_Z)]
	if load:
		pts.append(load.position + Vector3(0, LS * 0.5, 0))
	var dm = _dogman if _dogman != null else dog_bot
	if dm != null:
		pts.append(dm.global_position + Vector3(0, 1.5, 0))
	var lo: Vector3 = pts[0]
	var hi: Vector3 = pts[0]
	for q in pts:
		lo = lo.min(q)
		hi = hi.max(q)
	var c := (lo + hi) * 0.5
	return [c, (hi - lo).length() * 0.5]

## Where the camera should look during the climb.
func focus_point() -> Vector3:
	if load and stage == "guide":
		var target := Vector3(LAT_X, gap_bottom() + LS * 0.5, RUNWAY_Z)
		return (load.position + Vector3(0, LS * 0.5, 0)).lerp(target, 0.5)
	if load and stage == "fly":
		return load.position + Vector3(0, LS * 0.5, 0)
	return Vector3(LAT_X, gap_bottom() + 2.0, 0)

func platform_spot() -> Vector3:
	return Vector3(LAT_X, gap_bottom() - PLATFORM_DROP, -2.0)

## Handles a player at a climb station. Returns true if it took over this player.
func handle_player(p, delta: float, near: String, act: String, alt: String, leave: String) -> bool:
	if p.busy == "rigger":
		if not active or p.leave_pressed():
			p.busy = ""
			_rigger = null
			hammer.visible = false
			p.position = Vector3(13.4, game.work_y, -1.6)
			return true
		_rigger = p
		if stage != "pin":
			p.position = platform_spot()
		p.face(Vector3(LAT_X, gap_bottom() + 0.5, 0))
		match stage:
			"jack":
				p.set_arms(-1.0 - 0.8 * ram, -1.0 - 0.8 * ram)
				# Press (or just hold) A: each stroke goes when the ram's back
				if p.action_pressed() or (p.action_held() and ram_state == "ready"):
					_pump()
					p.bounce()
				if ram_state == "ready":
					p.cue("action", "pump ram", -1.0, true)
					p.gold(not p.bot)
				else:
					p.cue("action", "ram coming back…", 1.0 - ram if ram_state == "return" else ram, false)
			"roll":
				if p.action_held():
					roll = minf(1.0, roll + delta / 2.5)
					p.set_arms(-1.3, -1.3)
				p.cue("action", "roll in", roll)
			"pin":
				_stand_at_pin(p)
				match pin_sub:
					"wait":
						p.say("waiting on the pins")
						if pinsets > 0:
							_split_set()
					"split":
						p.cue("action", "pull the clip off", -1.0, true)
						if p.action_pressed():
							_split_set()
							p.bounce()
					"align":
						var v: Vector2 = p.move_input()
						if absf(v.y) > 0.3:
							_inch(-v.y, delta)
						_lever = move_toward(_lever, clampf(-v.y, -1.0, 1.0) if absf(v.y) > 0.3 else 0.0, delta * 5.0)
						var lined := absf(hole_off) <= PODGER_TOL
						if lined:
							p.cue("action", "podger in", -1.0, true)
							p.gold(not p.bot)
							p.say("holes lined up")
						else:
							p.say("stick %s to line up the holes" % ("up" if hole_off < 0.0 else "down"))
						if p.action_pressed():
							_podger()
							p.bounce()
					"podger":
						p.cue("action", "podger", -1.0, true)
						if p.action_pressed():
							_podger()
							p.bounce()
					"drive":
						if p.action_pressed():
							_swing_start()
						elif winding and not p.action_held():
							_swing_release()
							p.bounce()
						var in_zone: bool = winding and power >= SWEET and power <= SWEET + SWEET_W
						p.cue("action", "let go!" if in_zone else ("hold to swing" if not winding else "wait for gold…"), power if winding else 0.0, in_zone, Vector2(SWEET, SWEET + SWEET_W))
					"clip":
						# The R-clip takes a moment (hold A or X); Y skips it to
						# get the frame up sooner, and the inspector notes it
						_clip_hold = minf(1.0, _clip_hold + get_process_delta_time() / CLIP_T) if (p.action_held() or p.alt_held()) else maxf(0.0, _clip_hold - get_process_delta_time())
						p.cue("action", "R-clip on (hold)", _clip_hold, true)
						p.cue("slow", "skip the clip")
						if _clip_hold >= 1.0:
							_clip_hold = 0.0
							_clip(true)
							p.bounce()
						elif p.slow_pressed():
							_clip_hold = 0.0
							_clip(false)
				_pose_rigger(p)
			_:
				p.set_arms(-0.3, -0.3)
		return true

	if p.busy == "tag":
		# Let go of A and the line drops: they're back in charge wherever they stand
		if not active or load == null or not (stage in ["fly", "guide"]) or not p.action_held():
			_drop_tag(p)
			return false
		tag_hand = p
		var corner := _tag_corner()
		if _tag_sub == "fetch":
			p.run_to = Vector3(corner.x, p.position.y, corner.z)
			p.face(corner)
			p.cue("action", "running for the line", -1.0, true)
			var d := Vector2(corner.x - p.position.x, corner.z - p.position.z).length()
			if d < _tag_best - 0.05:
				_tag_best = d
				_tag_stuck = 0.0
			else:
				_tag_stuck += delta
			# Grab it, or as near as the deck edge lets them get
			if d < TAG_GRAB or _tag_stuck > 0.3:
				_tag_sub = "hold"
				p.bounce()
				game.sfx.hit("tink")
			return true
		# Holding the line, walking it back to the tag spot
		var spot: Vector3 = game.deck_pos("tag")
		var home := Vector2(spot.x - p.position.x, spot.z - p.position.z).length() < 0.3
		if not home:
			p.run_to = Vector3(spot.x, p.position.y, spot.z)
		else:
			p.face(load.global_position)
		tagging = true
		tag_strength = 1.1 if home else 0.8
		_tagger = p
		tag_from = p.global_position + Vector3(0, 0.9, 0)
		p.set_arms(-1.6, -1.6)
		p.cue("action", "hold the tag line", 1.0, true)
		p.gold(not p.bot and home)
		return true

	if p.busy == "dogman":
		# (stays on the job between sections: a climb's two lifts are one
		# dogman's, so nobody has to take signals again for the second)
		if not active or p.leave_pressed():
			p.busy = ""
			_dogman = null
			_stick = Vector2.ZERO
			_call = ""
			_vert = 0.0
			game.hud.set_signal("")
			return true
		if load:
			p.face(load.global_position)
		_dogman = p
		if stage == "guide":
			# One real call at a time: the stick picks whichever of the
			# crane's four moves (trolley out / in, slew left / right) points
			# nearest the way it's pushed on screen. Let go and that's STOP.
			var v: Vector2 = p.move_input()
			var key := pick_call(v) if v.length() > 0.4 else ""
			var vert := 0.0
			var dog_all: bool = p.action_held() and p.alt_held()
			if dog_all:
				key = ""
			elif p.action_held():
				vert = -1.0
				key = ""
			elif p.alt_held():
				vert = 1.0
				key = ""
			if p.slow_pressed():
				if _t - _last_slow_tap < 0.4:
					_emergency()
				_last_slow_tap = _t
			var slow: bool = p.slow_held()
			var dir: Vector2 = call_dirs().get(key, Vector2.ZERO)
			_call = key
			_stick = stick_of(dir)
			_vert = vert
			_command(dir, vert, slow, dog_all)
			_signal(p, dir, vert, delta, slow, dog_all)
			p.cue("action", "lower")
			# Gold: right over the ghost, so lowering now seats it
			if load and not p.bot:
				var lp := load.position
				p.gold((Vector2(lp.x, lp.z) - Vector2(LAT_X, RUNWAY_Z)).length() < LAND_TOL)
			p.cue("alt", "hoist")
		else:
			_call = ""
			_stick = Vector2.ZERO
			_vert = 0.0
			game.hud.set_signal("")
			p.say("crane coming…" if stage == "fly" else "next section's coming… (B: step off)")
		return true

	if not active:
		return false
	# Pin sets in hand: over to the rigger with them
	if p.held_kind == "pinsets":
		var at_frame: bool = near == "rigger" or Vector2(p.position.x - LAT_X, p.position.z).length() < 3.4
		if at_frame and p.zone == "deck":
			p.cue("action", "pin sets to the rigger", -1.0, true)
			if p.action_pressed():
				deliver(p)
			return true
		return false
	match near:
		"sling":
			if needs_sling():
				if hook_ready():
					p.cue("action", "sling it", sling_prog, true)
					p.gold(not p.bot and hook_ready())
					if p.action_held():
						sling(p, delta)
				else:
					p.say("hook's coming down…")
				return true
		"pinsets":
			if bundle_state == "ground" and p.held == null and p.tool == "":
				p.cue("action", "haul up the pin sets", haul_prog, true)
				if p.action_held():
					haul(p, delta)
				return true
		"rigger":
			p.cue("action", "climb frame", -1.0, stage in ["jack", "roll", "pin"])
			if p.action_pressed():
				p.busy = "rigger"
				p.bounce()
			return true
		"dogman":
			if stage in ["fly", "guide"]:
				p.cue("action", "take signals", -1.0, stage == "guide")
				if p.action_pressed():
					p.busy = "dogman"
					p.bounce()
			return true
		"tag":
			if stage in ["fly", "guide"] and load:
				if not tag_ready() or tag_hand != null:
					p.cue("action", "tag line", -1.0, false)
					p.say("wait till it's near the scaffold" if tag_hand == null else "%s has the line" % tag_hand.char_name)
				else:
					p.cue("action", "hold: grab the tag line", -1.0, true)
					p.gold(not p.bot)
					if p.action_held():
						p.busy = "tag"
						tag_hand = p
						_tag_sub = "fetch"
						_tag_best = INF
						_tag_stuck = 0.0
			return true
	return false

## The crane's four horizontal calls, each as a direction on the deck:
## trolley out / in along the jib, slew left / right across it.
func call_dirs() -> Dictionary:
	var radial := (trolley_xz - Vector2(MAST.x, MAST.z)).normalized()
	var tangent := Vector2(-radial.y, radial.x)
	return {"TROLLEY OUT": radial, "TROLLEY IN": -radial, "SLEW LEFT": tangent, "SLEW RIGHT": -tangent}

## A direction on the deck as the stick (or phone stick) would push it, the
## same mapping the players walk with.
func stick_of(world: Vector2) -> Vector2:
	var s := Vector3(world.x, 0, world.y).rotated(Vector3.UP, -game.cam_yaw)
	return Vector2(s.x, s.z)

## The call whose direction on screen is nearest the way the stick's pushed.
func pick_call(v: Vector2) -> String:
	var best := ""
	var best_d := -2.0
	var dirs := call_dirs()
	for k in dirs:
		var d: float = v.normalized().dot(stick_of(dirs[k]).normalized())
		if d > best_d:
			best_d = d
			best = k
	return best

## The dogman's help setting: 0 First Day, 1 On Site, 2 Ticketed.
func help() -> int:
	return int(Settings.value("dog_help"))

## Where the load settles if the dogman calls STOP right now: the driver
## hears it late, runs on a moment, then brakes, and the load comes to hang
## under the hook where it stopped. (Ignores the wind and any knock.)
func predict_stop() -> Vector3:
	var txz := trolley_xz
	var tv := trolley_v
	var hv := hoist_v
	var cl := cable_len
	var drive := _op_dir * _drive_speed()
	var vert := _op_vert * (0.2 if _op_slow else 0.45)
	# (the STOP takes the driver's reaction time to reach them)
	var lag := _op_delay() + _coast_max() * 0.5
	var dt := 1.0 / 30.0
	var t := 0.0
	while t < 3.0 and (t < lag or tv.length() > 0.005 or absf(hv) > 0.005):
		var on := t < lag
		tv += ((drive if on else Vector2.ZERO) - tv).limit_length(0.7 * dt)
		txz += tv * dt
		hv += clampf((vert if on else 0.0) - hv, -dt, dt)
		cl -= hv * dt
		t += dt
	cl = clampf(cl, 4.0, CRANE_H - SLING - LS - (game.work_y + 0.4))
	return Vector3(txz.x, CRANE_H - cl - SLING - LS, txz.y)

const CALL_INFO := {
	"STOP": "one short",
	"HOIST": "two short",
	"LOWER": "three short",
	"TROLLEY OUT": "four short",
	"TROLLEY IN": "four short",
	"SLEW LEFT": "four short",
	"SLEW RIGHT": "four short",
	"EMERGENCY STOP": "one long blast",
	"DOG EVERYTHING": "hands clasped",
}

## What the dogman says on the radio for each call.
const RADIO := {
	"STOP": "Stop.",
	"HOIST": "Hoist up…",
	"LOWER": "Lower down…",
	"TROLLEY OUT": "Trolley out…",
	"TROLLEY IN": "Trolley in…",
	"SLEW LEFT": "Slew left…",
	"SLEW RIGHT": "Slew right…",
	"EMERGENCY STOP": "ALL STOP!",
	"DOG EVERYTHING": "Dog everything.",
}

## Stops the crane dead (no reaction delay). The load will swing.
func _emergency() -> void:
	_cmds.clear()
	_op_dir = Vector2.ZERO
	_op_vert = 0.0
	trolley_v = Vector2.ZERO
	hoist_v = 0.0
	_estop_t = 1.2
	call_now = "EMERGENCY STOP"
	_pending = "EMERGENCY STOP"
	game.sfx.hit("whistle:emergency")
	_last_whistle = _t
	_ring_t = 0.0
	game.hud.toast("EMERGENCY STOP", 1.2)

func _signal(p, dir: Vector2, vert: float, delta: float, slow := false, dog_all := false) -> void:
	_slow = slow
	_dog_all = dog_all
	_estop_t = maxf(0.0, _estop_t - delta)
	var call_name := "STOP"
	var code := "stop"
	if _estop_t > 0.0:
		call_name = "EMERGENCY STOP"
		code = ""
	elif dog_all:
		call_name = "DOG EVERYTHING"
		code = ""
	elif vert < 0.0:
		call_name = "LOWER"
		code = "lower"
	elif vert > 0.0:
		call_name = "HOIST"
		code = "hoist"
	elif dir.length() > 0.3:
		var radial := (trolley_xz - Vector2(MAST.x, MAST.z)).normalized()
		var tangent := Vector2(-radial.y, radial.x)
		var cr := dir.dot(radial)
		var ct := dir.dot(tangent)
		if absf(cr) >= absf(ct):
			call_name = "TROLLEY OUT" if cr > 0.0 else "TROLLEY IN"
		else:
			call_name = "SLEW LEFT" if ct > 0.0 else "SLEW RIGHT"
		code = "horizontal"
	# Debounce: a call has to be held a moment before the whistle goes, and
	# whistles never stack, so quick corrections don't turn into a racket
	if call_name != _pending:
		_pending = call_name
		_pending_code = code
		_pending_t = 0.0
	_pending_t += delta
	if _pending != call_now and _pending_t >= 0.15 and _t - _last_whistle >= 0.35:
		var was_long := _t - _call_since >= 0.6
		call_now = _pending
		_call_since = _t
		if _pending_code != "" and (call_now != "STOP" or was_long):
			game.sfx.hit("whistle:" + _pending_code)
			_last_whistle = _t
			_ring_t = 0.0
	var col := Color("ffc72c") if call_now != "STOP" else Color.WHITE
	if call_now == "EMERGENCY STOP":
		col = Color("ff4d4d")
	var text := "%s   (%s)" % [call_now, CALL_INFO.get(call_now, "")]
	if call_now == "STOP" and p != null and not p.bot:
		# Nothing being signalled: say what to do next, not "stop"
		var lp := load.position if load else Vector3.ZERO
		var err := (Vector2(lp.x, lp.z) - Vector2(LAT_X, RUNWAY_Z)).length()
		if err < LAND_TOL:
			text = "Right over the green: hold A, \"lower down\""
			col = Color("7cd992")
		else:
			text = "Push the stick to a call (%.1f m to go). Let go to call STOP." % err
	if slow and call_now != "STOP":
		text += "  · EASY"
	# The stop ghost's on the mark: this is the moment to call STOP
	if call_now in ["TROLLEY OUT", "TROLLEY IN", "SLEW LEFT", "SLEW RIGHT"] and stop_ghost_at != Vector3.INF and p != null and not p.bot:
		if (Vector2(stop_ghost_at.x, stop_ghost_at.z) - Vector2(LAT_X, RUNWAY_Z)).length() < LAND_TOL:
			text = "LET GO NOW: \"stop\" lands it on the green"
			col = Color("ffd23f")
	if wind_gust >= WIND_STOP:
		game.hud.set_signal("%s  ·  gusting over the limit" % text, Color("ff4d4d"))
	else:
		game.hud.set_signal(text, col)
	_gesture(p, call_now, dir, slow)

## The dogman's hand signal for the current call, after the standard chart:
## hoist = forearm up, finger circling; lower = arm down, finger circling;
## stop = arm out, palm down, held rigid; emergency = arm out, waved side to
## side; slew = point the way; trolley = thumb the way with a jerk of the hand;
## slowly = other hand held still in front; dog everything = hands clasped.
func _gesture(p, call_name: String, dir: Vector2, slow: bool) -> void:
	var w := _t * 9.0
	var left := Vector3(0.0, 0, -0.25)
	var right := Vector3(0.0, 0, 0.25)
	var yaw := 0.0
	var use_left := false
	if dir.length() > 0.1:
		var local := Vector3(dir.x, 0, dir.y).rotated(Vector3.UP, -p.model.rotation.y)
		yaw = atan2(local.x, local.z)
		use_left = local.x < 0.0
	match call_name:
		"HOIST":
			right = Vector3(-2.95 + 0.12 * sin(w), 0, 0.2 + 0.14 * cos(w))
		"LOWER":
			right = Vector3(-0.35 + 0.12 * sin(w), 0, 0.15 + 0.14 * cos(w))
		"STOP":
			right = Vector3(0.0, 0, 1.55)
		"EMERGENCY STOP":
			right = Vector3(-1.5, 0.8 * sin(_t * 14.0), 0)
			left = Vector3(-1.5, -0.8 * sin(_t * 14.0), 0)
		"SLEW LEFT", "SLEW RIGHT":
			right = Vector3(-1.55, yaw, 0)
		"TROLLEY OUT", "TROLLEY IN":
			var jerk := 0.25 * maxf(0.0, sin(_t * 7.0))
			right = Vector3(-1.4, yaw + jerk * (1.0 if call_name == "TROLLEY OUT" else -1.0), 0)
		"DOG EVERYTHING":
			left = Vector3(-0.9, 0, 0.6)
			right = Vector3(-0.9, 0, -0.6)
	var sideways := call_name.begins_with("SLEW") or call_name.begins_with("TROLLEY")
	if use_left and sideways:
		# Point with the hand on that side; the other hand shows "slowly"
		left = right
		right = Vector3(-1.35, 0, -0.1) if slow else Vector3(0.0, 0, 0.25)
	elif slow and call_name != "STOP" and call_name != "DOG EVERYTHING":
		left = Vector3(-1.35, 0, 0.1)
	p.pose_arms(left, right)

## Arrows, target ghost, drop ring and whistle rings for the dogman.
func _update_guides(delta: float) -> void:
	var guiding := active and stage == "guide" and load != null
	var crane_on := active and crane_busy()
	var gb := gap_bottom()
	ghost.visible = crane_on
	ghost_label.visible = crane_on
	ghost.position = Vector3(LAT_X, gb + LS * 0.5, RUNWAY_Z)
	ghost_label.position = Vector3(LAT_X, gb + LS + 0.9, RUNWAY_Z)
	drop_ring.visible = guiding
	plumb.visible = guiding
	if guiding:
		var lp := load.position
		var err := (Vector2(lp.x, lp.z) - Vector2(LAT_X, RUNWAY_Z)).length()
		var spin_err := absf(spin - roundf(spin / (PI * 0.5)) * PI * 0.5)
		var good := err < LAND_TOL and spin_err < SPIN_TOL
		drop_mat.albedo_color = Color(0.49, 0.85, 0.57, 0.75) if good else Color(1.0, 0.6, 0.1, 0.6)
		drop_ring.position = Vector3(lp.x, gb + 0.03, lp.z)
		_line(plumb, Vector3(lp.x, lp.y, lp.z), Vector3(lp.x, gb + 0.03, lp.z))

	# The crane's four calls round the load, each arrow the way that call
	# takes it and named for it, plus hoist / lower
	var yaw: float = game.cam_yaw
	var cd := call_dirs()
	var keys := cd.keys()
	for i in 6:
		var a := guide_arrows[i]
		a.visible = guiding and _dogman != null
		if i < 4:
			call_labels[i].visible = a.visible
		if not a.visible:
			continue
		var lit := false
		var lc := load.position + Vector3(0, LS * 0.5, 0)
		if i < 4:
			var w: Vector2 = cd[keys[i]]
			var d := Vector3(w.x, 0, w.y)
			a.position = lc + d * 1.9
			_point(a, d)
			lit = _call == keys[i]
			var l := call_labels[i]
			l.text = keys[i]
			l.position = lc + d * 3.6 + Vector3(0, 0.5, 0)
			l.modulate = Color(1.0, 0.82, 0.25) if lit else Color(1, 1, 1, 0.8)
			l.outline_modulate = Color(0, 0, 0, 0.85)
		elif i == 4:
			a.position = load.position + Vector3(0, LS + 0.4, 0)
			_point(a, Vector3.UP)
			lit = _vert > 0.0
		else:
			a.position = load.position + Vector3(0, -0.4, 0)
			_point(a, Vector3.DOWN)
			lit = _vert < 0.0
		var m: StandardMaterial3D = a.get_meta("mat")
		m.albedo_color = Color(1.0, 0.78, 0.17, 1.0) if lit else Color(1, 1, 1, 0.45)
		a.scale = Vector3.ONE * (1.25 if lit else 1.0)

	# What the crane is actually doing right now (it lags the whistle)
	var moving := trolley_v.length() > 0.08 or absf(hoist_v) > 0.06
	motion_arrow.visible = guiding and moving
	if motion_arrow.visible:
		motion_arrow.position = hook.position + Vector3(0, 0.9, 0)
		if trolley_v.length() > 0.08:
			_point(motion_arrow, Vector3(trolley_v.x, 0, trolley_v.y).normalized())
		else:
			_point(motion_arrow, Vector3.UP if hoist_v > 0.0 else Vector3.DOWN)

	# The stop ghost: where the load settles if the call's STOP right now.
	# Gold when that's on the mark: let go now and it stops there.
	var ghost_on := guiding and help() < 2 and (_dogman != null) and (trolley_v.length() > 0.05 or absf(hoist_v) > 0.05 or _op_dir.length() > 0.1)
	stop_ghost.visible = ghost_on
	stop_ghost_at = Vector3.INF
	if ghost_on:
		var at := predict_stop()
		stop_ghost_at = at
		stop_ghost.position = at + Vector3(0, LS * 0.5, 0)
		var on_mark := (Vector2(at.x, at.z) - Vector2(LAT_X, RUNWAY_Z)).length() < LAND_TOL
		stop_ghost_mat.albedo_color = Color(1.0, 0.82, 0.25, 0.45) if on_mark else Color(1, 1, 1, 0.22)
	# The zoning ring, brighter (and red) as the hook nears it
	zone_ring.visible = guiding
	if guiding:
		zone_ring.position = Vector3(LAT_X, gb + 0.05, RUNWAY_Z)
		var edge := (trolley_xz - Vector2(LAT_X, RUNWAY_Z)).length() / ZONE_R
		var hot := clampf((edge - 0.75) / 0.25, 0.0, 1.0)
		zone_mat.albedo_color = Color(1, 0.82, 0.25, 0.18).lerp(Color(1, 0.23, 0.18, 0.8), hot)

	# The dogman's own call, above their head (the radio words), with
	# whistle rings
	var dm = _dogman
	var show_dog: bool = guiding and dm != null
	dog_arrow.visible = show_dog and call_now != "STOP" and call_now != "EMERGENCY STOP" and call_now != "DOG EVERYTHING"
	dog_stop.visible = show_dog
	if show_dog:
		var top: Vector3 = dm.global_position + Vector3(0, 3.0, 0)
		dog_arrow.position = top
		dog_stop.position = top + Vector3(0, 1.1, 0)
		dog_stop.text = "\"%s\"" % RADIO.get(call_now, call_now)
		dog_stop.modulate = Color("ff4d4d") if call_now in ["STOP", "EMERGENCY STOP"] else Color("ffc72c")
		if call_now == "LOWER":
			_point(dog_arrow, Vector3.DOWN)
		elif call_now == "HOIST":
			_point(dog_arrow, Vector3.UP)
		else:
			var d3: Vector3 = Vector3(_stick.x, 0, _stick.y).rotated(Vector3.UP, yaw)
			if d3.length() > 0.1:
				_point(dog_arrow, d3)
	_ring_t += delta
	for i in rings.size():
		var r := rings[i]
		var u := (_ring_t - i * 0.15) / 0.6
		r.visible = show_dog and u >= 0.0 and u <= 1.0
		if r.visible:
			r.position = dm.global_position + Vector3(0, 1.45, 0)
			r.rotation = Vector3(PI * 0.5, dm.model.rotation.y, 0)
			r.scale = Vector3.ONE * lerpf(0.4, 2.2, u)
			var rmat: StandardMaterial3D = r.material_override
			rmat.albedo_color = Color(1, 1, 1, 0.8 * (1.0 - u))

## HUD lines for the current stage: [title, sub, progress]
func hud_task() -> Array:
	match stage:
		"jack":
			var n := int(ceil((LS + CLEAR) / STROKE))
			var done := int(floor(lifted / STROKE + 0.001))
			return ["Climb · jack the frame  %d/%d" % [done, n], "", lifted / (LS + CLEAR)]
		"fly":
			return ["Climb · crane's flying it in", "", 0.0]
		"guide":
			var err := (Vector2(load.position.x, load.position.z) - Vector2(LAT_X, RUNWAY_Z)).length()
			var h := maxf(0.0, load.position.y - gap_bottom())
			return ["Climb · dog it onto the ghost  %.1f m off, %.1f m up" % [err, h], "", clampf(1.0 - err / 6.0, 0.0, 1.0)]
		"roll":
			return ["Climb · roll it in", "", roll]
		"pin":
			var what := {"wait": "pins coming up the haul rope", "split": "clip off the pin", "align": "line up the holes", "podger": "podger in", "drive": "drive the pin", "clip": "R-clip on"}
			return ["Climb · pin %d of %d: %s" % [mini(pin_i + 1, PINS), PINS, what.get(pin_sub, "")], "", (pin_i + minf(depth, 1.0)) / PINS]
		"seat":
			return ["Climb · boom settling", "", 1.0]
		"wreck":
			return ["Climb · section's down", "", 0.0]
		"refetch":
			return ["Climb · new section in %ds" % int(maxf(0.0, REFETCH_T - stage_t)), "", clampf(stage_t / REFETCH_T, 0.0, 1.0)]
	return ["", "", 0.0]

func hud_meter() -> void:
	# Pinning and jacking read off the props themselves now, not a bar
	game.hud.show_meter(false)

# ------------------------------------------------------------------ autotest bot

## A crew bot on the whistle: parks the trolley upwind of the stops by the
## wind's steady push, lets the tag line kill the swing, then lowers once it's
## settled. It signals with the bot chibi's own arms. (The rigger and tag line
## bots work through the normal buttons.)
var _test_wreck := OS.get_cmdline_user_args().has("--wreck")
var _collide_test := OS.get_cmdline_user_args().has("--collidetest")

## Test only (`--collidetest`): sets the load down against the side of the
## tower, drifting in slowly with the driver still pushing, and logs whether
## it bounces clear or sticks there knocking.
func _run_collide_test() -> void:
	if stage_t < 0.02:
		var gb := gap_bottom()
		var r := LW * 0.5
		trolley_xz = Vector2(LAT_X + 1.3 + r + 0.05, 0.6)
		swing = Vector2.ZERO
		swing_v = Vector2(-0.35, 0.0)
		trolley_v = Vector2(-0.2, 0.0)
		spin = 0.0
		spin_v = 0.0
		cable_len = CRANE_H - SLING - LS - (gb - 0.6)
		_cmds.clear()
	if fmod(stage_t, 0.5) < get_process_delta_time() and stage_t < 6.0:
		print("[autotest]   collide t=%.1f load=(%.2f, %.2f) touching=%s knocks=%d" % [stage_t, load.position.x - LAT_X, load.position.z, str(_touching), knocks])
	if stage_t < 4.0:
		_command(Vector2(-1, 0), 0.0)

func bot(delta: float) -> void:
	if _test_wreck and stage == "guide" and stage_t > 3.0 and load != null:
		_test_wreck = false
		_wreck()
		return
	if stage != "guide" or dog_bot == null or _dogman != null or load == null:
		return
	var L := cable_len + SLING + LS * 0.5
	var drift := wind_dir * 0.00012 * wind_gust * wind_gust * L / G
	var want := Vector2(LAT_X, RUNWAY_Z) - drift
	var dir := ((want - trolley_xz) * 0.5).limit_length(1.0)
	var load_xz := trolley_xz + swing
	var err := (Vector2(LAT_X, RUNWAY_Z) - load_xz).length()
	var vert := 0.0
	if err < 0.22 and swing_v.length() < 0.3 and wind_gust < WIND_STOP:
		vert = -1.0
	var slow := err < 1.2
	var dog := wind_gust >= WIND_STOP * 0.95
	if dog:
		dir = Vector2.ZERO
		vert = 0.0
	_command(dir, vert, slow, dog)
	# (the call it's nearest to, for the arrows and the radio)
	_call = pick_call(stick_of(dir)) if dir.length() >= 0.3 else ""
	_stick = stick_of(call_dirs().get(_call, Vector2.ZERO))
	_vert = vert
	if load:
		dog_bot.face(load.global_position)
	var keep = _dogman
	_dogman = dog_bot
	_signal(dog_bot, dir, vert, delta, slow, dog)
	_dogman = keep
