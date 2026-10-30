## The concrete line, street to boom, run the way a pour day runs:
##   - Agitator trucks queue on the road. The truck hand waves one back to
##     the hopper, does a slump test (the chute keeps running on trust while
##     they test), adds the allowed water to a stiff load or rejects an old or
##     wet one, then lets it discharge.
##   - The pump operator watches the gauge: when the pressure spikes they kill
##     the pump (points for how fast), then restart it.
##   - The pump pushes concrete up a steel riser of 3 m pipe sections with a
##     quick-release clamp at every joint, bracketed to the tower. The truck
##     hand climbs the tower ladder to reach them.
##   - A worn clamp weeps grout and knocks on every stroke. Swap it before it
##     bursts: fetch a clamp kit from the spares bin, stop the pump, reverse the
##     pressure off, open the clamp, knock the old grout out of the groove, fit
##     the new gasket and clamp, close it, safety pin in. If it bursts, the pump
##     trips and nothing pumps until the joint is remade.
##   - Concrete left standing in the line goes off and blocks a section. Tap
##     along the riser (ring = clear, thud = packed), then replace that pipe
##     section: open the clamps at both ends, lower the plugged pipe, fit a new
##     3 m pipe from the rack, close and pin both clamps.
##   - Two trucks can stand at the pump: one discharging into the hopper and
##     the next backed in alongside, already tested, so the hopper never waits.
##   - Run the hopper dry on high and the pump sucks air; when it reaches the
##     hose, the hose whips.
##   - Parts can be carried by the line hand, handed over, dropped by the joint,
##     or sent up the tower on the haul rope while the line hand gets the joint
##     open, so a repair can run in parallel.
extends Node3D

signal whip

const F := preload("res://scripts/factory.gd")
const Settings := preload("res://scripts/settings.gd")

const PIPE := 3.0                        # standard 3 m pipe lengths: a clamp at every joint
const RISER := Vector3(12.0, 0, 1.45)
const LADDER := Vector3(13.35, 0, 0.7)   # where a climber hangs on the tower ladder
const PUMP_POS := Vector3(19.0, 0, 6.0)
const HOPPER := Vector3(22.3, 0, 6.0)
const BAY := Vector3(26.9, 0, 6.0)      # the truck pump's single truck
# Twin feed (tower kit): both trucks back in from the east side by side, rears
# just short of the hopper, each with a chute extension angled into it. That
# leaves the south side of the pump clear: truck bay, pump panel and the parts
# store at the tower's foot are all on one lane.
const BAY_A2 := Vector3(27.6, 0, 4.4)
const BAY_B := Vector3(27.6, 0, 7.6)
const EXIT_Z := 19.4                      # the far lane, for trucks heading back to the plant
const HAUL := Vector3(14.25, 0, 1.25)    # the haul rope hangs down beside the ladder
const SPARES := Vector3(13.9, 0, 4.9)    # spares bin: clamp kits (clamp + gasket)
const RACK := Vector3(10.4, 0, 5.4)      # pipe rack: spare 3 m sections
const PIN_CRATE := Vector3(12.2, 0, 5.0) # bags of tower pins for climb days
const QUEUE_X := 10.0
const ROAD_Z := 15.6
# The site road runs across the lot north of Riverlight (vacant in 2017) from
# MacArthur Avenue, where the trucks come in, to Angora Road, where they leave:
# out of the site road's mouth and left into Angora's southbound lane (keeping
# left, as in Brisbane), then off down it the way it runs
const MACARTHUR_X := -28.0
const ANGORA_DIR := Vector3(0.534, 0, -0.846)
const ANGORA_LANE := Vector3(49.35, 0, 15.25)   # the southbound lane's middle, level with the site road
const TURN_T := 2.6                             # s to swing out of the mouth into the lane
var _traffic: Node                              # the street traffic (scripts/cars.gd), to wait for a gap
var _traffic_looked := false
# Concrete supply rate. Volumes are game scale: Riverlight's east wing (about
# 3.4x the old 16 x 12 slab) takes the same truckloads in the same time,
# because each game m³ out of the hose covers pour.vol_k times more deck
# (pour.gd, worked out from the slab's area). To speed the whole pour up or
# slow it down, change these: load size, chute and pump output; truck spacing
# is `interval` in start_pour. On a big slab main._start_pour closes the
# trucks up (BIG_SLAB_TRUCKS), sends bigger loads (BIG_SLAB_LOAD, so fewer
# changeovers at the bay) and gives the concrete a longer open time.
const HOPPER_CAP := 5.0                  # m³ (game scale)
const TRUCK_LOAD := 8.0                  # m³, a typical agitator load
var load_m3 := TRUCK_LOAD                # this pour's loads (bigger on a big slab: main._start_pour)
const DISCHARGE := 1.8                   # m³/s out of the chute
const PUMP_Q := 1.15                     # m³/s at the hose on high
const LOW := 0.55                        # output on low, as a share of high
const WEAR_TIME := 18.0                  # s of pumping on high before a weeping clamp lets go
const SET_TIME := 40.0                   # s concrete can stand still in the line before it blocks
const CLIMB_SPEED := 4.5                 # m/s on the ladder
const MAX_AGE := 90.0                    # minutes from batching: the usual guideline
# The slump test (AS 1012.3.1) against the order (AS 1379): a 100 mm pump mix,
# ±20 mm for an order in the 80 to 110 mm band. The plant holds back some
# water, written on the docket, that may be added on site (then mix and test
# again).
const SPEC_SLUMP := 100.0
const SLUMP_TOL := 20.0
const WATER_HELD := 10.0                 # L/m³ the plant held back
const SLUMP_PER_L := 4.5                 # mm of slump each L/m³ of water adds
const SlumpScript := preload("res://scripts/slump.gd")
const WashDown := preload("res://scripts/wash_down.gd")
var wash: Node3D
# The truck hand's other jobs on each load: spotting the truck back onto the
# hopper (hold A to wave it on, let go on the mark), checking the docket of
# a load that isn't due a test against the order (now and then it's the
# wrong mix), and keeping the changeovers tight (a streak while the hopper
# never runs low between trucks)
const SPOT_LEN := 2.4                    # s of reversing, waved on the whole way
const SPOT_SLOW := 0.8                   # past this share of the way it creeps
const SPOT_BAND := Vector2(0.95, 1.035)  # let go in here: the chute's over the hopper
const SPOT_M := 8.0                      # m of the back-in the readout counts down (the last bit of it)
const SPOT_BUMP := 1.06                  # this far and it backs into the hopper
const DOCKET_T := 12.0                   # s the driver waits on a docket before starting anyway
const SPOT_WAIT := 5.0                   # s a spotted truck sits waiting before the driver backs in alone
const MIX_WRONG := 0.1                   # chance a load that isn't tested is the wrong mix
# Skipping a test (tower): the first load's always tested; after that the
# truck hand can wave a load on untested. Each skip in a row makes a bad one
# more likely, and a test puts it back to the start.
const SKIP_RISK := 0.1                   # chance the first skipped load is bad
const SKIP_RISK_MAX := 0.5
const ORDER := {"mpa": 40, "stone": 20, "site": "Riverlight"}
# Once the sample's taken the driver keeps the chute running on trust, slowly,
# while the test's done: the pour keeps moving. Only so much goes in before
# the call, and a bad load caught has put that much in already.
const TRUST_Q := 0.6                     # m³/s into the hopper while the test runs
const TRUST_M3 := 2.0                    # m³ at most before the driver holds the chute
var _backed_in := 0
var skips := 0                # loads waved on untested since the last test
var _skip_told := false       # the first choice of the night says what skipping costs
# Radio ahead: after the call the truck hand tells the pump and the boom what's
# coming (stick: up GOOD ONE, left BIT STIFF, right WET ONE, down NOT TESTED).
# A radio that's right pays both the truck hand and the pump operator.
const RADIO := {"up": "GOOD ONE", "left": "BIT STIFF", "right": "WET ONE", "down": "NOT TESTED"}
const RADIO_T := 5.0                     # s to radio before the moment's gone
const RADIO_PAY := 8
var _radio_t = null           # the load being radioed (the truck)
var _radio_left := 0.0
var _radio_ready := false     # the stick's come back to the middle since the call
var radio_label: Label3D
var last_radio := ""          # what was radioed about the load going in now
# Reading the creep: a stiff (or old) load in the line on high output pushes
# the pressure up for a few seconds before it packs solid. Dropping to LOW
# while it creeps lets it through: CAUGHT EARLY, worth more than a fast kill.
const CREEP_SEEN := 0.15                 # creep the gauge shows before a catch counts
const CREEP_PAY := 50
var _creep_caught := false
# Keep the hopper: on a person's pump the driver runs the chute to the pump
# operator's signals (hold Y at the panel, stick up faster, down slower), to
# keep the hopper between the two lines. Fast at the brim slops over. A bot
# pump operator (or nobody) leaves the driver to run it himself.
const CHUTE := [0.0, 0.5, 1.0, 1.55]     # x PUMP_Q: stop, slow, steady, fast
const CHUTE_NAME := ["STOP", "SLOW", "STEADY", "FAST"]
const HOP_BAND := Vector2(0.4, 0.85)     # the two lines, as a share of the hopper
const BAND_PAY_T := 8.0                  # s between the lines for each trickle of pay
var chute := 2
var _flick_ok := true
var _band_t := 0.0
var _spill_t := 0.0
var _spill_paid := false
var _chute_shown_at := -1.0
var slump: Node
const AGE_RATE := 0.75                   # docket minutes per game second
const SAFE_BAR := 6.0                    # below this the line can be opened
# Nobody gets stuck: a TV room can't sit watching a line that never comes back.
const FIND_AUTO := 30.0      # s a blockage hides before the line hand hears it
const JOB_MAX := 80.0        # s a repair can drag before the leading hand helps finish it
const CLAMP_R := 0.25
const PLANT := "res://assets/plant/plant.glb"
const PIN_T := 0.9           # s holding A to push a safety pin home
# Pressure spikes: the line starts to pack (a stone bridge, a dry patch) and
# the needle jumps. The pump operator kills the pump on the belt remote; the
# faster they react, the more it's worth. Too slow and it packs solid.
const SPIKE_LIMIT := 3.0     # s of pumping into a spike before it blocks
const SPIKE_BAR := 232.0     # where the needle goes
const SPIKE_WARN := 0.5      # s of warning: the gauge close-up pops up just before
const QUIET_WARN := 2.5      # the quiet level's one spike: the needle creeps up this long first
const RESTART_HOLD := 0.8    # s holding A at the panel to restart
const RESTART_AUTO := 16.0   # s tripped before the leading hand restarts it
## [reaction under s, points, label]
const SPIKE_PAY := [[0.5, 40, "Lightning stop"], [1.0, 25, "Quick stop"], [1.8, 15, "Pump stopped"], [99.0, 5, "Pump stopped, just"]]

const STEP_INFO := {
	"depress": "pressure off",
	"open": "open clamp",
	"clean": "clean groove",
	"kit": "fit new clamp",
	"close": "close clamp",
	"pin": "safety pin",
	"lower": "lower old pipe",
	"pipe": "fit new pipe",
}

var game
var kit := "tower"

# Pump and line state
var hopper := 0.0
var pressure := 0.0
var speed_high := true
var pumping := false
var reversing := false
var reversing_seen := false   # (dev: someone's used the belt remote, for a screenshot)
var idle_t := 0.0
var live := false            # concrete in the line (primed and not washed out)
var air := 0.0
var air_travel := -1.0
var _prime_t := 0.0
var bad_volume := 0.0        # m³ of a bad load still in the hopper
var bad_kind := ""
var _bad_pumped := 0.0
var wet_q := 0.0             # m³ of a wet load out of the hose this frame: a weak patch where it lands
var spike_on := false
var spike_t := 0.0           # s the current spike has run (while pumping)
var tripped := false         # killed on a spike: off until the pump operator restarts it
var _spike_in := 14.0        # s of pumping till the next spike
var _restart_t := 0.0
var _tripped_t := 0.0

# Joints (each a clamp) and the pipe sections between them
var clamps: Array = []       # {pos, node, ha, hb, pin, crust, gasket, label, mat, pinned, present, open, crust_amt}
var sections: Array = []     # {a, b, node, plug}
var riser_top := 0.0
var fail_i := -1             # weeping clamp
var wear := 0.0
var burst := false
var blocked := false
var block_s := -1            # blocked section (between joints s and s+1)
var block_found := false
var job_kind := ""           # "clamp", "burst" or "block"
var job_steps: Array = []    # [op, joint]
var fix_step := 0
var fix_i := -1              # joint the current step is at, -1 if no job
var fix_prog := 0.0
var _over_t := 0.0
var _knock_phase := 0.0

# Parts lying around
var items: Array = []        # {node, kind, zone}
var _junk: Array = []        # lowered plugged pipes: [node, age]

# Trucks
var trucks: Array = []
var bay_truck = null         # the truck discharging into the hopper (or backing in to)
var staged = null            # the next one, backed in alongside
var _arrive_t := 0.0
var interval := 8.0
var late_extra := 0.0
var ordered := 0.0           # m³ ordered for this pour
var needed_m3 := 48.0
var stats := {}

# Visuals
var ground_pipe: MeshInstance3D
var brackets: Array[MeshInstance3D] = []
var ladder_rails: Array[MeshInstance3D] = []
var ladder_rungs: MultiMeshInstance3D
var pump_unit: Node3D
var gauge_needle: Node3D
var gauge_label: Label3D      # the reading over the gauge, sized for the TV (main scales it)
var gauge_face: Node3D        # the dial, for the gauge close-up camera to look at
var spike_warn := false       # a spike's half a second off: the gauge close-up pops up
var _spike_cause := ""        # "clamp" or "block": what set this spike off ("" a random one)
var _pending_cause := ""      # a failure's spike, half a second away
var _kill_show_t := 0.0       # s the close-up stays up after a kill, to see it drop
var hopper_fill: MeshInstance3D
var hopper_label: Label3D
var spot_label: Label3D        # over a spotted truck's tail: how far to go, and when to stop
var _spot_shown := false
var spot_marks := {}           # slot -> {node, mat}: the painted stop line behind each bay
var drips: CPUParticles3D
var burst_fx: CPUParticles3D
var grout_spray: CPUParticles3D
var chunks: CPUParticles3D
var sparkle: CPUParticles3D
var beacon: Label3D
var tap_label: Label3D
var _tap_t := 0.0
var flying: Node3D
var _fly_v := Vector3.ZERO
var _fly_to = null           # a player the old clamp flies to
var chute_stream: MeshInstance3D
var slump_cone: Node3D
var npc_op: Node3D
var _npc_t := 0.0
var _spawning := false
var legs: Array[Node3D] = []
var _lowering = null         # {node, t, from}
var _hop_splash: CPUParticles3D = null
var hook := {"kind": "", "node": null, "y": 0.0, "to": 0.0, "state": "down"}
var hook_node: Node3D
var haul_rope: MeshInstance3D
var _worker = null           # whoever did the last repair step
var _step_t := 0.0           # how long the current repair step has waited
var _job_t := 0.0            # how long the current repair has run
var _blocked_t := 0.0        # how long the current blockage has gone unfound
var _block_burst := false    # this blockage has already blown a joint once
var _nagged := false
var _bled := false
var _reverser = null         # whoever's on the pump panel reversing

# ------------------------------------------------------------------ build

func build(owner_game, which_kit: String) -> void:
	game = owner_game
	kit = which_kit
	ground_pipe = MeshInstance3D.new()
	add_child(ground_pipe)
	for sx in [-0.28, 0.28]:
		var rail := F.box(Vector3(0.06, 1.0, 0.06), F.mat("yellow_dark"))
		add_child(rail)
		ladder_rails.append(rail)
	ladder_rungs = MultiMeshInstance3D.new()
	add_child(ladder_rungs)

	_build_pump()
	_build_stores()

	drips = _particles(40, 1.4, Vector3(0, -1, 0), 12.0, 0.2, 0.8, _blob(0.05, Color("8d9095")))
	grout_spray = _particles(120, 0.9, Vector3(1, 0.2, 0.6), 40.0, 3.0, 7.0, _blob(0.09, Color("9a9da1")))
	chunks = _particles(14, 1.0, Vector3(0.3, 1, 0.3), 50.0, 2.0, 4.0, _chunk_mesh())
	chunks.one_shot = true
	chunks.explosiveness = 1.0
	sparkle = _particles(30, 0.7, Vector3(0, 1, 0), 180.0, 1.5, 3.5, _star_mesh())
	sparkle.one_shot = true
	sparkle.explosiveness = 0.9
	sparkle.gravity = Vector3(0, -2, 0)
	burst_fx = _particles(240, 1.6, Vector3(0, 1, 0), 70.0, 5.0, 14.0, null)
	burst_fx.one_shot = true
	burst_fx.explosiveness = 0.95
	burst_fx.gravity = Vector3(0, -14, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.16, 0.16)
	bm.material = F.color_mat(Color("7c7f83"))
	burst_fx.mesh = bm

	beacon = F.label3d("!", 80, Color("ff4d4d"))
	beacon.layers = 2
	beacon.visible = false
	add_child(beacon)
	tap_label = F.label3d("", 52, Color.WHITE)
	tap_label.visible = false
	add_child(tap_label)

	npc_op = F.chibi(Color("ff7a1a"), Color("f4f7fa"))
	F.kit(npc_op, "pump")
	npc_op.position = Vector3(20.0, 0, 9.2)
	npc_op.visible = false
	add_child(npc_op)
	# Haul rope over a gin wheel at the top of the riser, for sending parts up
	hook_node = Node3D.new()
	hook_node.add_child(F.box(Vector3(0.12, 0.18, 0.05), F.mat("red", true), Vector3(0, 0.1, 0)))
	add_child(hook_node)
	haul_rope = MeshInstance3D.new()
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.018
	rope_mesh.bottom_radius = 0.018
	rope_mesh.height = 1.0
	rope_mesh.radial_segments = 5
	haul_rope.mesh = rope_mesh
	haul_rope.material_override = F.color_mat(Color("d9c27a"))
	add_child(haul_rope)
	var wheel := F.cylinder(0.16, 0.06, F.mat("steel", true), Vector3.ZERO, 12)
	wheel.name = "GinWheel"
	wheel.rotation.x = PI * 0.5
	hook_node.set_meta("wheel", wheel)
	add_child(wheel)
	hook_node.visible = kit == "tower"
	haul_rope.visible = kit == "tower"
	rebuild_riser()

func _particles(n: int, life: float, dir: Vector3, spread: float, v0: float, v1: float, mesh: Mesh) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.emitting = false
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = Vector3(0, -9, 0)
	if mesh:
		p.mesh = mesh
	add_child(p)
	return p

func _blob(r: float, c: Color) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = F.color_mat(c)
	return sm

func _chunk_mesh() -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.05, 0.06)
	bm.material = F.color_mat(Color("a9a497"))
	return bm

func _star_mesh() -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("fff3a0")
	m.emission_enabled = true
	m.emission = Color("ffe36b")
	bm.material = m
	return bm

## A quick-release pipe clamp: two hinged half rings around the pipe, a lever
## on the free end with a red safety pin through it, the old grout crust in
## the groove (seen when it's open) and the rubber gasket.
func _make_clamp(fresh := false) -> Dictionary:
	var root := Node3D.new()
	var m := F.color_mat(Color("c7d0da") if fresh else Color("8f9aa6"), true)
	(m.next_pass as ShaderMaterial).set_shader_parameter("thickness", F.PROP_OUTLINE * 1.5)
	var hinge := Vector3(CLAMP_R, 0, 0)
	var ha := Node3D.new()
	ha.position = hinge
	root.add_child(ha)
	var hb := Node3D.new()
	hb.position = hinge
	root.add_child(hb)
	# The two ribbed halves (tools/blender/props.py), each hung off the hinge
	ha.add_child(F.prop("ClampHalfA", {"clamp": m}))
	hb.add_child(F.prop("ClampHalfB", {"clamp": m}))
	# Hinge knuckle
	root.add_child(F.cylinder(0.05, 0.22, F.mat("navy"), hinge, 8))
	# Lever on the free end of half B, and its safety pin
	var lever := F.box(Vector3(0.3, 0.07, 0.07), F.mat("navy"), Vector3(-CLAMP_R * 2.0 - 0.12, 0.0, -0.06))
	hb.add_child(lever)
	var pin := F.cylinder(0.022, 0.3, F.mat("red"), Vector3(-CLAMP_R * 2.0 - 0.2, 0.0, -0.06), 6)
	hb.add_child(pin)
	var crust := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.15
	tm.outer_radius = 0.23
	tm.rings = 14
	tm.ring_segments = 6
	crust.mesh = tm
	crust.material_override = F.color_mat(Color("9b968a"))
	crust.visible = false
	root.add_child(crust)
	var gasket := MeshInstance3D.new()
	var gm := TorusMesh.new()
	gm.inner_radius = 0.16
	gm.outer_radius = 0.21
	gm.rings = 14
	gm.ring_segments = 6
	gasket.mesh = gm
	gasket.material_override = F.color_mat(Color("1d1f23"))
	gasket.visible = false
	root.add_child(gasket)
	return {"node": root, "ha": ha, "hb": hb, "pin": pin, "crust": crust, "gasket": gasket, "mat": m}

func _set_open(c: Dictionary, u: float) -> void:
	c["open"] = u
	(c["ha"] as Node3D).rotation.y = -u * 1.35
	(c["hb"] as Node3D).rotation.y = u * 1.35

## The gear a concreting crew leaves by its stores: shovel and rake leant on
## the spares bin, buckets, a barrow and the bull float by the pipe rack, and
## (climb days) the chain sling and a coiled tag line by the pin crate. Just
## to look at: nothing here is picked up.
func _build_tool_corner(bin: Node3D, rack: Node3D) -> void:
	var shovel := F.prop("Shovel")
	shovel.position = Vector3(0.82, 0, 0.18)
	shovel.rotation = Vector3(0, 0.3, 0.33)
	bin.add_child(shovel)
	var rake := F.prop("ConcreteRake")
	rake.position = Vector3(0.85, 0, -0.2)
	rake.rotation = Vector3(0, -0.2, 0.28)
	bin.add_child(rake)
	for i in 2:
		var b := F.prop("Bucket")
		b.position = Vector3(-0.9 - i * 0.4, 0, 0.15 - i * 0.12)
		bin.add_child(b)
	var mag := F.prop("MagFloat")
	mag.position = Vector3(-0.9, 0.36, 0.15)
	mag.rotation.y = 0.6
	bin.add_child(mag)
	var barrow := F.prop("Wheelbarrow")
	barrow.position = Vector3(2.2, 0, 0.3)
	barrow.rotation.y = 2.4
	rack.add_child(barrow)
	var bull := F.prop("BullFloat")
	bull.position = Vector3(0.2, 0, 0.75)
	bull.rotation.y = -1.45
	rack.add_child(bull)
	if kit == "tower":
		var gear := Node3D.new()
		gear.position = PIN_CRATE + Vector3(0.1, 0, 0.75)
		add_child(gear)
		gear.add_child(F.prop("ChainSling"))
		var coil := F.prop("TagLineCoil")
		coil.position = Vector3(0.75, 0, -0.1)
		gear.add_child(coil)
		var sh := F.prop("Shackle")
		sh.position = Vector3(0.35, 0.012, 0.3)
		sh.rotation = Vector3(PI * 0.5, 0.4, 0)
		gear.add_child(sh)

## The spares bin (clamp kits) and the pipe rack (3 m sections), at ground level.
func _build_stores() -> void:
	var bin := Node3D.new()
	bin.position = SPARES
	add_child(bin)
	bin.add_child(F.prop("SparesBin"))
	for i in 3:
		var c := _make_clamp(true)
		c["node"].position = Vector3(-0.35 + i * 0.35, 0.65, 0)
		c["node"].scale = Vector3.ONE * 0.7
		bin.add_child(c["node"])
	var rack := Node3D.new()
	rack.position = RACK
	add_child(rack)
	rack.add_child(F.prop("PipeRack"))
	for i in 3:
		var pp := F.prop("Pipe3m")
		pp.position = Vector3(0, 0.35 + i * 0.25, -0.2 + i * 0.2)
		rack.add_child(pp)
	_build_tool_corner(bin, rack)
	# (named by its station label, not lettering of its own)
	# The pin bags: a crate of sealed bags of four pins, for climb days
	var crate := Node3D.new()
	crate.position = PIN_CRATE
	add_child(crate)
	crate.add_child(F.box(Vector3(0.9, 0.5, 0.7), F.mat("orange", true), Vector3(0, 0.25, 0)))
	for i in 3:
		var b := make_item("pins")
		b.position = Vector3(-0.25 + i * 0.25, 0.62, 0)
		b.rotation.z = 0.2 * (i - 1)
		crate.add_child(b)
	crate.visible = kit == "tower"

## A part to carry: a clamp kit (new clamp with its gasket) or a 3 m pipe.
func make_item(kind: String) -> Node3D:
	var n := Node3D.new()
	if kind == "pipe":
		n.add_child(F.prop("Pipe3m"))
	elif kind == "pins":
		# Four tower pins, each with its R-clip, sealed in a clear bag
		for i in 4:
			var x := -0.18 + i * 0.12
			n.add_child(F.cylinder(0.035, 0.36, F.mat("steel", true), Vector3(x, 0.0, 0), 8))
			n.add_child(F.cylinder(0.055, 0.04, F.mat("navy", true), Vector3(x, 0.19, 0), 8))
			n.add_child(F.box(Vector3(0.02, 0.1, 0.08), F.color_mat(Color("e5383b")), Vector3(x, -0.12, 0.05)))
		var bag := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.62, 0.5, 0.2)
		bag.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.85, 0.92, 1.0, 0.32)
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bmat.roughness = 0.1
		bag.material_override = bmat
		n.add_child(bag)
	else:
		var c := _make_clamp(true)
		c["node"].scale = Vector3.ONE * 0.8
		(c["gasket"] as Node3D).visible = true
		n.add_child(c["node"])
	n.set_meta("kind", kind)
	return n

func _build_pump() -> void:
	pump_unit = Node3D.new()
	pump_unit.position = PUMP_POS
	add_child(pump_unit)
	# Stationary trailer pump, modelled (tools/blender/plant.py): drawbar and
	# jack legs, engine canopy, delivery cylinders to the hopper end
	pump_unit.add_child(F.prop("LinePump", {}, PLANT))
	var lbl := Label3D.new()
	lbl.text = Settings.brand("pumper")
	lbl.add_to_group("brand_pumper")
	lbl.font_size = 80
	lbl.pixel_size = 0.008
	lbl.modulate = Color("0f1b2d")
	lbl.outline_size = 0
	lbl.position = Vector3(0.85, 1.9, 1.02)   # (clear of the gauge)
	pump_unit.add_child(lbl)
	# Pressure gauge on the operator's side: a big white dial in a black rim,
	# a red band at the top of the scale and a red needle, with the reading
	# floating over it in TV-sized type
	gauge_face = Node3D.new()
	gauge_face.position = Vector3(-1.0, 1.75, 1.03)
	pump_unit.add_child(gauge_face)
	var rim := F.cylinder(0.5, 0.05, F.mat("navy"), Vector3.ZERO, 24)
	rim.rotation.x = PI * 0.5
	gauge_face.add_child(rim)
	var dial := F.cylinder(0.44, 0.05, F.mat("white"), Vector3(0, 0, 0.02), 24)
	dial.rotation.x = PI * 0.5
	gauge_face.add_child(dial)
	for i in 9:
		# Ticks round the scale, the last three in the red
		var a := 2.2 - 4.4 * float(i) / 8.0
		var tick := F.box(Vector3(0.035, 0.1 if i % 2 == 0 else 0.06, 0.02), F.mat("red") if i >= 6 else F.mat("navy"), Vector3(0, 0, 0.055))
		var arm := Node3D.new()
		arm.rotation.z = a
		arm.add_child(tick)
		tick.position = Vector3(0, 0.36, 0.055)
		gauge_face.add_child(arm)
	gauge_needle = Node3D.new()
	gauge_needle.position = Vector3(0, 0, 0.07)
	gauge_face.add_child(gauge_needle)
	gauge_needle.add_child(F.box(Vector3(0.045, 0.38, 0.02), F.mat("red"), Vector3(0, 0.17, 0)))
	gauge_needle.add_child(F.cylinder(0.06, 0.03, F.mat("navy"), Vector3(0, 0, 0.01), 10))
	(gauge_needle.get_child(1) as Node3D).rotation.x = PI * 0.5
	gauge_label = F.label3d("0 bar", 64, Color.WHITE)
	gauge_label.layers = 2   # (left out of the close-up cameras: the dial's right there)
	gauge_label.position = PUMP_POS + Vector3(-1.0, 3.3, 1.0)
	add_child(gauge_label)
	# Hopper: an open steel box at the rear with a grille
	var hop := Node3D.new()
	hop.position = HOPPER - PUMP_POS
	pump_unit.add_child(hop)
	hop.add_child(F.prop("PumpHopper", {}, PLANT))
	hopper_fill = F.box(Vector3(1.5, 0.05, 1.7), F.color_mat(Color("6c6f73")), Vector3(0, 0.95, 0))
	hop.add_child(hopper_fill)
	hopper_label = F.label3d("HOPPER", 34, Color.WHITE)
	hopper_label.layers = 2
	hopper_label.position = Vector3(0, 2.8, 0)
	hop.add_child(hopper_label)
	chute_stream = F.cylinder(0.14, 1.0, F.color_mat(Color("6c6f73")), Vector3.ZERO, 8)
	chute_stream.visible = false
	add_child(chute_stream)
	# Spotting a truck back: a stop line painted where its tail stops, and a
	# big readout over the tail while someone's waving it on
	spot_label = F.label3d("", 64, Color.WHITE)
	spot_label.layers = 2
	spot_label.outline_size = 14
	spot_label.visible = false
	add_child(spot_label)
	# The truck hand's radio wheel, over their head while they pick
	radio_label = F.label3d("", 40, Color.WHITE)
	radio_label.layers = 2
	radio_label.outline_size = 12
	radio_label.visible = false
	add_child(radio_label)
	# The truck hand's wash-down of the hopper, at washout
	wash = WashDown.new()
	add_child(wash)
	wash.setup(self)
	if kit == "tower":
		for sl in ["A", "B"]:
			var pose: Array = _slot_pose(sl)
			var xf := Transform3D(Basis(Vector3.UP, _yaw_for(pose[1])), pose[0])
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color("ffc72c")
			# (wheel stops behind the back tyres, with a line painted between)
			var bar := Node3D.new()
			bar.add_child(F.box(Vector3(0.14, 0.02, 3.0), mat, Vector3(0, 0.01, 0), false))
			for z in [-1.2, 1.2]:
				bar.add_child(F.box(Vector3(0.3, 0.22, 0.5), mat, Vector3(-0.1, 0.11, z)))
			bar.transform = xf * Transform3D(Basis(), Vector3(-3.5, 0.0, 0))
			add_child(bar)
			spot_marks[sl] = {"node": bar, "mat": mat}
	# The slump test at the bay: cone, rod, tape, barrow (slump.gd)
	slump = SlumpScript.new()
	add_child(slump)
	slump.setup(self, Vector3(25.7, 0, 10.7))
	slump_cone = slump.root

## (Re)builds the riser to the boom head: 3 m sections with a clamp at every
## joint and a bracket to the tower between. Called at the start and after
## every climb, as the line is extended with the tower.
func rebuild_riser() -> void:
	var pinned := []
	for c in clamps:
		pinned.append(c["pinned"])
		(c["node"] as Node).queue_free()
		(c["label"] as Node).queue_free()
	for s in sections:
		(s["node"] as Node).queue_free()
	clamps.clear()
	sections.clear()
	var top: float = game.head.position.y + 0.6 if kit == "tower" else 0.0
	riser_top = top
	for r in ladder_rails:
		r.visible = kit == "tower"
	ladder_rungs.visible = kit == "tower"
	if kit == "tower":
		for i in ladder_rails.size():
			var rr := ladder_rails[i]
			rr.position = Vector3(LADDER.x + 0.15, top * 0.5, LADDER.z + (-0.28 if i == 0 else 0.28))
			rr.scale.y = top
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.05, 0.56)
		bm.material = F.mat("yellow_dark")
		mm.mesh = bm
		var n := int(top / 0.35)
		mm.instance_count = n
		for i in n:
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(LADDER.x + 0.15, 0.3 + i * 0.35, LADDER.z)))
		ladder_rungs.multimesh = mm
	_line(ground_pipe, Vector3(PUMP_POS.x - 2.4, 0.6, PUMP_POS.z), Vector3(RISER.x, 0.6, RISER.z) if kit == "tower" else Vector3(PUMP_POS.x - 2.4, 0.6, PUMP_POS.z - 0.01), 0.16)

	# Joints: the bend at the base, then every 3 m up the riser. In the truck
	# kit the joints are along the truck's own deck pipe, reachable from the ground.
	var want: Array[Vector3] = []
	if kit == "tower":
		var y := 0.6
		while y < top - 0.8:
			want.append(Vector3(RISER.x, y, RISER.z))
			y += PIPE
	else:
		for off in [Vector3(-2.6, 1.0, -0.75), Vector3(-1.2, 1.0, -0.75), Vector3(0.2, 1.0, -0.75)]:
			want.append(PUMP_POS + off)
	for i in want.size():
		var c := _make_clamp()
		var node: Node3D = c["node"]
		node.position = want[i]
		if kit == "truck":
			node.rotation.z = PI * 0.5   # horizontal pipe
		add_child(node)
		var lab := F.label3d("C%d" % (i + 1), 30, Color("cfd8e3"))
		lab.position = want[i] + Vector3(0.0, 0.45, 0.45)
		lab.visible = false
		add_child(lab)
		c["pos"] = want[i]
		c["label"] = lab
		c["pinned"] = pinned[i] if i < pinned.size() else true
		c["present"] = true
		c["open"] = 0.0
		c["crust_amt"] = 1.0
		clamps.append(c)
	# Sections between joints, plus the last run up to the boom
	for i in want.size():
		var a := want[i]
		var b: Vector3
		if i + 1 < want.size():
			b = want[i + 1]
		elif kit == "tower":
			b = Vector3(RISER.x, top, RISER.z)
		else:
			b = PUMP_POS + Vector3(1.6, 1.0, -0.75)
		var sm := MeshInstance3D.new()
		add_child(sm)
		_line(sm, a + (b - a).normalized() * 0.08, b - (b - a).normalized() * 0.08, 0.16)
		sections.append({"a": a, "b": b, "node": sm})
	for b in brackets:
		b.queue_free()
	brackets.clear()
	if kit == "tower":
		var by := 2.1
		while by < top - 0.5:
			var br := F.box(Vector3(0.14, 0.12, 0.55), F.mat("yellow_dark"), Vector3(RISER.x, by, RISER.z - 0.38))
			add_child(br)
			brackets.append(br)
			by += PIPE

func _line(m: MeshInstance3D, a: Vector3, b: Vector3, r: float) -> void:
	if m.mesh == null:
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 1.0
		cm.radial_segments = 10
		m.mesh = cm
		m.material_override = F.mat("pipe")
	var d := b - a
	var ln := d.length()
	if ln < 0.05:
		m.visible = false
		return
	m.visible = true
	var dir := d / ln
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	m.transform = Transform3D(Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, -PI * 0.5), (a + b) * 0.5)
	m.scale = Vector3(1, ln, 1)

func _truck_mesh() -> Node3D:
	# The agitator, modelled (tools/blender/plant.py): cab-over cab, twin
	# drive axles, the drum on its pedestals, charging hopper and chute
	var t := Node3D.new()
	t.add_child(F.prop("Truck", {}, PLANT))
	var drum := Node3D.new()
	drum.name = "Drum"
	# (tipped up at the tail, the mouth to the charging hopper, as real
	# agitators sit)
	drum.position = Vector3(-0.6, 2.4, 0)
	drum.rotation.z = -0.2
	t.add_child(drum)
	drum.add_child(F.prop("TruckDrum", {}, PLANT))
	# A chute extension, swung out to reach the hopper when the truck's on it
	var ext := Node3D.new()
	ext.name = "ChuteExt"
	ext.position = Vector3(-4.55, 1.62, 0)
	ext.add_child(F.prop("ChuteExt", {}, PLANT))
	ext.visible = false
	t.add_child(ext)
	var lab := F.label3d("", 34, Color.WHITE)
	lab.name = "Docket"
	lab.position = Vector3(0, 4.3, 0)
	t.add_child(lab)
	return t


# ------------------------------------------------------------------ pour flow

## Called when a pour starts. `cfg` holds the level's outside factors.
var quiet := false           # level 1: good loads, one well-warned spike, nothing else

func start_pour(need: float, cfg: Dictionary) -> void:
	needed_m3 = need
	quiet = bool(cfg.get("quiet", false))
	interval = 9.5 * float(cfg.get("traffic", 1.0))
	late_extra = float(cfg.get("late", 0.0))
	ordered = 0.0
	_backed_in = 0
	hopper = 0.0
	speed_high = true
	idle_t = 0.0
	live = false
	_prime_t = 0.0
	air = 0.0
	air_travel = -1.0
	bad_volume = 0.0
	bad_kind = ""
	_bad_pumped = 0.0
	spike_on = false
	spike_t = 0.0
	tripped = false
	_spike_in = _spike_gap(true)
	fail_i = -1
	wear = 0.0
	burst = false
	blocked = false
	block_found = false
	_clear_job()
	stats = {"bursts": 0, "whips": 0, "blocks": 0, "bad_loads": 0, "rejected": 0, "unpinned": 0, "jobs": 0, "spikes": 0, "spike_best": -1.0, "spike_missed": 0, "best_streak": 0, "wrong_mix_caught": 0, "skipped": 0, "skipped_bad": 0, "creep_caught": 0, "radio_right": 0, "hopper_spill": 0.0}
	skips = 0
	chute = 2
	_band_t = 0.0
	_spill_t = 0.0
	_creep_caught = false
	_radio_t = null
	last_radio = ""
	if wash:
		wash.reset()
	streak = 0
	for t in trucks:
		(t["node"] as Node).queue_free()
	trucks.clear()
	bay_truck = null
	staged = null
	# The first two trucks are already waiting when the pour starts, and the
	# first has backed onto the hopper during the pre-start, so the slump test
	# can happen straight away instead of everyone watching it reverse in
	_spawn_truck(true)
	_spawn_truck(true)
	if not trucks.is_empty():
		var first: Dictionary = trucks[0]
		first["slot"] = "A"
		var pose: Array = _slot_pose("A")
		(first["node"] as Node3D).position = pose[0]
		(first["node"] as Node3D).rotation.y = _yaw_for(pose[1])
		_set_truck(first, "bay")
		# (the first load of the pour gets a slump test: do it while the
		# line's being primed)
		_backed_in = 1
		first["why"] = "first load"
	_arrive_t = interval

func end_pour() -> void:
	pumping = false
	reversing = false
	spike_on = false
	tripped = false
	live = false
	fail_i = -1
	burst = false
	blocked = false
	_clear_job()
	beacon.visible = false
	drips.emitting = false
	grout_spray.emitting = false
	# The crew remakes anything left open between pours
	for c in clamps:
		c["present"] = true
		_set_open(c, 0.0)
		(c["node"] as Node3D).visible = true
		(c["crust"] as Node3D).visible = false
		(c["gasket"] as Node3D).visible = false
	for s in sections:
		(s["node"] as Node3D).visible = true
	for t in trucks:
		if t["state"] in ["queue", "arrive", "called"]:
			_set_truck(t, "road")

## True while the line can't pump: burst, or opened up for a repair.
## The line's down while a joint's burst or any repair is under way: nobody
## pumps with a line hand on a joint.
func line_down() -> bool:
	return burst or job_kind != ""

## Seconds of pumping between spikes, by the Incidents setting.
func _spike_gap(first := false) -> float:
	var lvl: int = game.incident_level() if game and game.has_method("incident_level") else 1
	var gap: Vector2 = [Vector2(40, 60), Vector2(22, 34), Vector2(16, 26), Vector2(11, 19)][clampi(lvl, 0, 3)]
	if game and game.tutorial:
		gap = Vector2(26, 34)
	if quiet:
		# (one, once the pumping's settled in, and that's it)
		return randf_range(30.0, 40.0) if first else INF
	return randf_range(gap.x, gap.y) * (0.6 if first else 1.0)

## Every frame of the pour: run the spike that's on, count down to one a
## failure has set off (a clamp letting go, a plug forming), and, while the
## line's pumping steadily, to the next random one.
func _spikes(delta: float) -> void:
	if spike_on:
		spike_t += delta
		if fmod(spike_t, 0.35) < delta:
			game.sfx.hit("knock")
		if spike_t > SPIKE_LIMIT:
			_missed_spike()
		return
	if _pending_cause != "":
		_spike_in -= delta
		spike_warn = true   # (the close-up's already up: something's going)
		if _spike_in <= 0.0:
			_start_spike(_pending_cause)
			_pending_cause = ""
		return
	# Random spikes only in steady pumping, with the line sound
	if not pumping or not live or tripped or blocked or fail_i >= 0 or hopper < 0.4 or (game.ops and game.ops.busy()):
		spike_warn = false
		return
	_spike_in -= delta
	# Half a second before, the gauge close-up pops up: eyes on the needle
	# (on the quiet level, longer, with the needle creeping up first)
	spike_warn = _spike_in <= (QUIET_WARN if quiet else SPIKE_WARN)
	if _spike_in <= 0.0:
		_start_spike("")

func _start_spike(cause: String) -> void:
	spike_on = true
	spike_warn = false
	spike_t = 0.0
	_spike_cause = cause
	stats["spikes"] += 1
	game.sfx.hit("hiss")
	# (said once: the gauge close-up with its A, the red A over the pump
	# operator and their phone. No banner, no ticket.)
	var op = game.crew.crew.get("pump") if game.crew else null
	if op != null:
		game.haptic(op, "80,40,80")

## Something's gone on the line (a clamp starts to let go, a plug forms): the
## needle jumps half a second later, and killing the pump is the first step
## of the repair. (Nothing to see if the pump's already off.)
func _herald(cause: String) -> void:
	if tripped or spike_on or _pending_cause != "" or game.phase != "pour":
		return
	_pending_cause = cause
	_spike_in = SPIKE_WARN

## Nobody killed it in time.
func _missed_spike() -> void:
	spike_on = false
	_kill_show_t = 0.9
	stats["spike_missed"] += 1
	_spike_in = _spike_gap()
	var cause := _spike_cause
	_spike_cause = ""
	match cause:
		"clamp":
			# Pumping on into a clamp that's letting go: it blows
			if fail_i >= 0 and not burst and job_kind == "" and not game.tutorial:
				game.hud.toast("Nobody killed the pump: the clamp's blown!", 2.4)
				_burst()
		"block":
			game.hud.toast("Nobody killed the pump: it's rammed the plug in hard!", 2.4)
			game.score.award(game.crew.crew.get("pump") if game.crew else null, -15, "Pumped into a blockage")
		_:
			# It either packs the line solid, or the hammer blows a joint's
			# gasket and that clamp starts weeping (no warning spike for
			# those: this was it)
			if stats["spike_missed"] % 2 == 1 and not blocked:
				game.hud.toast("Nobody killed the pump: the spike's packed the line!", 2.4)
				_block(false, true)
			elif fail_i < 0 and not blocked:
				game.hud.toast("Nobody killed the pump: the spike's cracked a joint!", 2.4)
				start_failure(true)
				wear = 0.4
			elif not blocked:
				_block(false, true)

## True while a repair is still owed: the pump can't be restarted into it.
func repair_pending() -> bool:
	return blocked or burst or fail_i >= 0 or job_kind != ""

## The pump operator kills the pump on a spike. Points for how fast.
func kill_pump(p) -> void:
	if not spike_on:
		return
	var react := spike_t
	spike_on = false
	_spike_cause = ""
	_spike_in = _spike_gap()
	_kill_show_t = 0.9
	tripped = true
	_tripped_t = 0.0
	_restart_t = 0.0
	if float(stats.get("spike_best", -1.0)) < 0.0 or react < float(stats["spike_best"]):
		stats["spike_best"] = react
	for row in SPIKE_PAY:
		if react < float(row[0]):
			var at: Vector3 = PUMP_POS + Vector3(0, 3.2, 0)
			game.score.award(p, int(row[1]), "Spikes killed", at)
			game.pop("%s · %.2f s" % [row[2], react], at + Vector3(0, 0.8, 0), Color("7cd992") if react < 1.0 else Color("ffc72c"))
			break
	game.sfx.hit("thunk")
	if react < float(SPIKE_PAY[0][0]):
		p.bark("%.1f s KILL" % react)
	p.bounce()

## Back on after a spike: a stroke in reverse eases it, then forward again.
func restart(p) -> void:
	if not tripped or repair_pending():
		return
	tripped = false
	_restart_t = 0.0
	_spike_in = _spike_gap()
	game.sfx.hit("thunk")
	if p != null:
		game.score.award(p, 5, "Pump restarted")
		p.bounce()

func _clear_job() -> void:
	job_kind = ""
	job_steps = []
	fix_step = 0
	fix_i = -1
	fix_prog = 0.0
	_step_t = 0.0
	_job_t = 0.0

## Runs the pump for one frame. `want` is the boom remote's pump button.
## Returns m³ delivered at the hose this frame.
func run(delta: float, want: bool) -> float:
	pumping = want and not line_down() and not reversing and not tripped
	wet_q = 0.0
	if tripped and not repair_pending():
		_tripped_t += delta
		if _tripped_t > RESTART_AUTO:
			game.hud.toast("The leading hand's restarted the pump", 1.8)
			restart(null)
	var q := 0.0
	if pumping:
		var rate := PUMP_Q * (1.0 if speed_high else LOW)
		if blocked:
			# (not while the spike it set off is still the pump operator's to
			# catch: they get their full chance before anything blows)
			_over_t += 0.0 if spike_on or _pending_cause != "" else delta
			if _over_t > 2.6 and _block_burst:
				# It's already blown a joint once: the pump's relief valve
				# cuts in at full pressure and it just stalls
				_over_t = 0.0
				game.hud.toast("Pump's maxed out against the blockage. Stop pumping!", 1.6)
			elif _over_t > 2.6:
				# Pumping into a blockage: the joint below the plug lets go
				_over_t = 0.0
				_block_burst = true
				fail_i = clampi(block_s, 0, clamps.size() - 1)
				_burst()
				return 0.0
		else:
			_over_t = 0.0
			q = minf(rate * delta, hopper)
			if hopper < 0.04:
				# Sucking air. On low the pump just stutters; on high it drags
				# air into the line, and that comes out at the hose as a whip
				air += delta * (1.0 if speed_high else 0.25)
			hopper -= q
			if q > 0.0:
				idle_t = 0.0
				if not live:
					live = true
					_prime_t = 0.0
					game.hud.toast("Priming the line with slurry", 1.4)
				_prime_t += delta
				if _prime_t < 1.0:
					q = 0.0
				if bad_volume > 0.0:
					var take := minf(bad_volume, rate * delta)
					bad_volume -= take
					if bad_kind in ["old", "stiff"] and not speed_high:
						# (gently on low: what had started to pack eases through)
						_bad_pumped = maxf(0.0, _bad_pumped - take * 0.8)
					else:
						_bad_pumped += take
					if bad_kind == "wet":
						wet_q = minf(take, q)
					if _bad_pumped > 1.4 and bad_kind in ["old", "stiff"] and not blocked:
						_block(true)
						_bad_pumped = 0.0
					if bad_volume <= 0.0:
						_bad_pumped = 0.0   # (that load's through)
						_creep_caught = false
				if air > 0.45 and air_travel < 0.0:
					air_travel = 0.0
					game.hud.toast("Hopper ran dry: air in the line!", 1.8)
				if air_travel >= 0.0:
					air_travel += delta
					if air_travel > 1.6:
						air_travel = -1.0
						air = 0.0
						stats["whips"] += 1
						game.score.award(null, -30, "Hose whip", game.hose_end.global_position)
						whip.emit()
		if fail_i >= 0 and not burst:
			# (a clamp left without its safety pin works loose faster)
			wear += delta / WEAR_TIME * (1.0 if speed_high else 0.45) * (1.0 if clamps[fail_i]["pinned"] else 1.6)
			if wear >= 1.0:
				_burst()
	else:
		_over_t = 0.0
		if live and not reversing:
			# While a joint's open for repair the crew keep the line moving by
			# hand where they can, so it goes off slower (but it still goes off)
			# (not while a joint's open: the crew wash the line through)
			if job_kind == "":
				idle_t += delta
			if idle_t > SET_TIME and not blocked:
				_block(false)
	return q

## A section between two joints packs solid.
func _block(from_bad: bool, heralded := false) -> void:
	if clamps.size() < 2:
		return
	if not heralded:
		_herald("block")
	blocked = true
	block_found = false
	_block_burst = false
	_blocked_t = 0.0
	var lo := 0
	if kit == "tower" and clamps.size() > 3:
		lo = clamps.size() / 3
	block_s = randi_range(lo, clamps.size() - 2)
	stats["blocks"] += 1
	stats["jobs"] += 1
	game.score.award(null, -20, "Line blocked", clamps[block_s]["pos"] + Vector3(0, 1.5, 0))
	if game.autotest:
		print("[autotest]   BLOCKED in the section above C%d" % (block_s + 1))
	if from_bad:
		# One blockage per bad load: the crew dump what's left of it out of
		# the hopper and send the truck back, so it can't pack pipe after pipe
		var dumped := minf(hopper, bad_volume)
		hopper -= dumped
		bad_volume = 0.0
		bad_kind = ""
		_bad_pumped = 0.0
		for t in trucks:
			if t.get("bad", "") != "" and t["state"] in ["pour", "ready"]:
				t["bad"] = ""
				ordered -= float(t["load"])
				_set_truck(t, "leave_wait")
				_arrive_t = minf(_arrive_t, 2.0)
		game.hud.toast("That load's packed in the line. Blockage! The rest of it's dumped and the truck's sent back.", 2.6)
	else:
		game.hud.toast("The line sat too long and went off. Blockage!", 2.2)
	game.sfx.hit("thunk")

func start_failure(heralded := false) -> void:
	if clamps.is_empty() or fail_i >= 0 or burst or blocked or job_kind != "":
		return
	if not heralded:
		_herald("clamp")
	# A clamp left without its safety pin goes first
	var pick := -1
	for i in clamps.size():
		if not clamps[i]["pinned"]:
			pick = i
	if pick < 0:
		var lo := 0
		var hi := clamps.size() - 1
		if kit == "tower" and clamps.size() > 2:
			lo = 1
		pick = randi_range(lo, hi)
		# Dev (`--midclamp`): the one halfway up, between the deck and the street
		if OS.get_cmdline_user_args().has("--midclamp"):
			pick = clamps.size() / 2
	fail_i = pick
	wear = 0.0
	stats["jobs"] += 1

func _burst() -> void:
	if game.autotest:
		print("[autotest]   BURST at C%d (%.0f m), pressure %.0f" % [fail_i + 1, clamps[fail_i]["pos"].y, pressure])
	burst = true
	pumping = false
	stats["bursts"] += 1
	game.score.award(null, -50, "Clamp burst", clamps[fail_i]["pos"] + Vector3(0, 1.0, 0))
	var c: Dictionary = clamps[fail_i]
	var at: Vector3 = c["pos"]
	burst_fx.position = at
	burst_fx.restart()
	burst_fx.emitting = true
	c["present"] = false
	(c["node"] as Node3D).visible = false
	(c["crust"] as Node3D).visible = true
	_fly_clamp(at, null)
	_fly_v = Vector3(randf_range(2.0, 5.0), 7.0, randf_range(1.0, 4.0))
	grout_spray.position = at
	grout_spray.emitting = true
	game.shake = 1.0
	game.sfx.hit("bang")
	game.hud.toast("C%d BURST!" % (fail_i + 1), 2.0)
	if job_kind == "block":
		_clear_job()
	_start_job("burst", fail_i)

func _fly_clamp(at: Vector3, to) -> void:
	if flying:
		flying.queue_free()
	var c := _make_clamp()
	flying = c["node"]
	flying.position = at
	add_child(flying)
	_fly_to = to

func _start_job(kind: String, j: int) -> void:
	job_kind = kind
	fix_step = 0
	fix_prog = 0.0
	_step_t = 0.0
	_job_t = 0.0
	_nagged = false
	_bled = false
	match kind:
		"burst":
			job_steps = [["clean", j], ["kit", j], ["close", j], ["pin", j]]
		"clamp":
			job_steps = [["open", j], ["clean", j], ["kit", j], ["close", j], ["pin", j]]
		"block":
			var u := j + 1
			job_steps = [["open", j], ["open", u], ["lower", u], ["pipe", u], ["close", u], ["pin", u], ["close", j], ["pin", j]]
	fix_i = j

## The operation the current repair step needs ("" if no job).
func _step_name() -> String:
	if job_steps.is_empty() or fix_step >= job_steps.size():
		return ""
	return job_steps[fix_step][0]

func _advance() -> void:
	fix_step += 1
	fix_prog = 0.0
	_step_t = 0.0
	if fix_step >= job_steps.size():
		_finish_job()
	else:
		fix_i = job_steps[fix_step][1]

func _finish_job() -> void:
	var j: int = job_steps[0][1]
	var bonus := {"clamp": [40, "Clamp swapped before it burst"], "burst": [20, "Burst joint remade"], "block": [40, "Blockage cleared"]}
	if _worker != null and bonus.has(job_kind):
		game.score.award(_worker, bonus[job_kind][0], bonus[job_kind][1], clamps[j]["pos"] + Vector3(0, 1.2, 0))
	if game.autotest:
		print("[autotest]   fixed C%d (%s), pinned %s" % [j + 1, job_kind, clamps[j]["pinned"]])
	match job_kind:
		"block":
			blocked = false
			block_found = false
			game.hud.toast("New pipe in. Line's clear.", 1.6)
		_:
			fail_i = -1
			wear = 0.0
			burst = false
			game.hud.toast("C%d remade%s" % [j + 1, "" if clamps[j]["pinned"] else " (no safety pin!)"], 1.6)
	grout_spray.emitting = false
	_celebrate(clamps[j]["pos"])
	_clear_job()
	idle_t = 0.0   # washed through while it was open
	# A burst caused by a blockage leaves the blockage to find
	if blocked and block_found:
		_start_job("block", block_s)

## Keeps a missed button from stalling the pour: the call goes out loud, then
## the crew get round it themselves (slower, and it costs points).
func _watchdog(delta: float) -> void:
	# Found but no repair under way (it was found mid another job): start it
	if blocked and block_found and job_kind == "" and block_s >= 0:
		_start_job("block", block_s)
	if blocked and not block_found and job_kind == "":
		_blocked_t += delta
		if _blocked_t > FIND_AUTO:
			block_found = true
			game.hud.toast("The pump operator heard the plug: above C%d" % (block_s + 1), 2.2)
			_start_job("block", block_s)
	if job_kind == "":
		return
	_step_t += delta
	_job_t += delta
	if _job_t > JOB_MAX:
		game.hud.toast("The leading hand jumps in to finish the joint", 2.2)
		_force_finish()

## Finishes the repair under way in one go, everything left as a proper job.
func _force_finish() -> void:
	var j: int = job_steps[0][1]
	var c: Dictionary = clamps[j]
	if not c["present"]:
		var old: Node3D = c["node"]
		var fresh := _make_clamp(true)
		for key in ["node", "ha", "hb", "pin", "crust", "gasket", "mat"]:
			c[key] = fresh[key]
		old.queue_free()
		(c["node"] as Node3D).position = c["pos"]
		if kit == "truck":
			(c["node"] as Node3D).rotation.z = PI * 0.5
		add_child(c["node"])
		c["present"] = true
	for k in [j, j + 1]:
		if k < clamps.size():
			var ck: Dictionary = clamps[k]
			ck["crust_amt"] = 0.0
			(ck["crust"] as Node3D).visible = false
			(ck["gasket"] as Node3D).visible = false
			ck["pinned"] = true
			(ck["pin"] as Node3D).visible = true
			(ck["pin"] as Node3D).position.y = 0.0
			_set_open(ck, 0.0)
	if job_kind == "block" and block_s < sections.size():
		(sections[block_s]["node"] as Node3D).visible = true
	_worker = null
	_finish_job()

func _celebrate(at: Vector3) -> void:
	game.pop("Joint remade!", at + Vector3(0, 0.6, 0))
	sparkle.position = at
	sparkle.restart()
	sparkle.emitting = true
	game.sfx.hit("ding")

# ------------------------------------------------------------------ trucks

func _spawn_truck(waiting: bool, top_up := false) -> void:
	if ordered >= needed_m3 * 1.12 and not top_up:
		return
	var load := load_m3 if top_up else minf(load_m3, needed_m3 * 1.12 - ordered + 0.5)
	ordered += load
	var r := 1.0 if quiet else randf()
	var slump := randf_range(SPEC_SLUMP - 17.0, SPEC_SLUMP + 17.0)
	var age := randf_range(22.0, 45.0)
	if r < 0.09:
		slump = randf_range(52.0, 70.0)        # stiff: the water held back brings it up
	elif r < 0.14:
		slump = randf_range(70.0, 77.0)        # only just stiff: read the tape carefully
	elif r < 0.17:
		slump = randf_range(135.0, 180.0)      # too wet: send it back
	elif r < 0.21:
		slump = randf_range(123.0, 130.0)      # only just wet
	if late_extra > 0.0 and randf() < 0.4:
		age += late_extra                       # stuck in traffic
	var node := _truck_mesh()
	add_child(node)
	var t := {"node": node, "state": "arrive", "t": 0.0, "age": age, "slump": slump, "load": load, "checked": false, "verdict": "", "pos": Vector3(MACARTHUR_X if not waiting else _slot_x(_queue_count()), 0, ROAD_Z)}
	node.position = t["pos"]
	trucks.append(t)
	if waiting:
		_set_truck(t, "queue")

func _queue_count() -> int:
	var n := 0
	for t in trucks:
		if t["state"] in ["queue", "arrive"]:
			n += 1
	return n

## Queue slots run back along the road to the west of the site entrance.
func _slot_x(slot: int) -> float:
	return QUEUE_X - slot * 10.0

func _set_truck(t: Dictionary, s: String) -> void:
	var was: String = t.get("state", "")
	t["state"] = s
	t["t"] = 0.0
	if s == "back" and not game.sfx.has_loop("truck_beeper"):
		game.sfx.hit("beep")
	# The air brakes go on when it's backed in and off when it pulls out,
	# and the chute's swung down for a pour and stowed after
	if (was == "back" and s != "back") or s == "leave":
		game.sfx.hit("air_brake")
	if s in ["pour", "leave_wait"] and was != "ready":
		game.sfx.hit("chute_rattle")
	if s == "pour" and live:
		_changeover(t)

## A new load's chute opens: if the hopper was still fed, the changeover
## streak grows (and pays more each time); if it ran low first, it's over.
func _changeover(t: Dictionary) -> void:
	var at: Vector3 = (t["node"] as Node3D).position + Vector3(0, 4.6, 0)
	var who = game.crew.crew.get("line") if game.crew else null
	if hopper > HOPPER_CAP * 0.12:
		streak += 1
		stats["best_streak"] = maxi(int(stats.get("best_streak", 0)), streak)
		if streak >= 2:
			game.pop("Tight changeover x%d" % streak, at, Color("ffd23f"))
			if who != null:
				game.score.award(who, mini(3 * streak, 15), "Tight changeovers")
	else:
		if streak >= 2:
			game.pop("Hopper ran low: streak over", at, Color("ff9a3d"))
		streak = 0

func _verdict(t: Dictionary) -> String:
	if t.get("mix_wrong", "") != "":
		return "mix"
	if t["age"] > MAX_AGE:
		return "old"
	if t["slump"] > SPEC_SLUMP + SLUMP_TOL:
		return "wet"
	if t["slump"] < SPEC_SLUMP - SLUMP_TOL:
		return "stiff"
	return "ok"

## The order against what the driver's docket says came on the truck.
func _order_lines(t: Dictionary) -> String:
	var load := ORDER.duplicate()
	match t.get("mix_wrong", ""):
		"mpa": load["mpa"] = 32
		"stone": load["stone"] = 10
		"site": load["site"] = "Harbour St"
	return "ORDER   %d MPa · %d mm stone · %s\nDOCKET %d MPa · %d mm stone · %s · %d min" % [ORDER["mpa"], ORDER["stone"], ORDER["site"], load["mpa"], load["stone"], load["site"], int(t["age"])]

func docket_text(t: Dictionary) -> String:
	if t.get("eyeballed", false):
		var s0 := _order_lines(t)
		if assist() and t["state"] == "docket":
			s0 += "  ✗ wrong mix" if t.get("mix_wrong", "") != "" else "  ✓"
		return s0
	# (every load's tested on the tower: the docket's read at the call)
	var head := _order_lines(t) + "\n" if kit == "tower" else ""
	if not t["checked"]:
		var why: String = t.get("why", "")
		return head + ("Slump test: %s · " % why if why != "" else "") + "%d L/m³ water held back" % int(WATER_HELD)
	var s := head + "Slump %d mm" % int(t.get("measured", t["slump"]))
	if not assist():
		return s
	if t.get("mix_wrong", "") != "":
		return s + "  ✗ wrong mix"
	# (going on what was measured, as the operator would)
	match right_call(t):
		"use":
			s += "  ✓"
		"water":
			s += "  ! stiff: add the water"
		_:
			s += "  ✗ over 90 min" if t["age"] > MAX_AGE else "  ✗ send it back"
	return s

# Twin truck feed: one truck backs up to the hopper from the east (A) and the
# other from the south (B), each with its chute over the hopper, so the next
# load can go in the moment the last one's empty. Trucks only ever drive
# forwards or reverse along their own length, one manoeuvring at a time.
static func _bez(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: float) -> Vector3:
	var v := 1.0 - u
	return p0 * v * v * v + p1 * 3.0 * v * v * u + p2 * 3.0 * v * u * u + p3 * u * u * u

static func _bez_d(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: float) -> Vector3:
	var v := 1.0 - u
	return (p1 - p0) * 3.0 * v * v + (p2 - p1) * 6.0 * v * u + (p3 - p2) * 3.0 * u * u

static func _yaw_for(dir: Vector3) -> float:
	return -atan2(dir.z, dir.x)

func _slot_pose(slot: String) -> Array:
	if kit != "tower":
		return [BAY, Vector3(1, 0, 0)]
	return [BAY_A2, Vector3(1, 0, 0)] if slot == "A" else [BAY_B, Vector3(1, 0, 0)]

## Which way the chute extension angles to reach the hopper (local z).
func _chute_side(t: Dictionary) -> float:
	if kit != "tower":
		return 0.0
	return 1.0 if t.get("slot", "A") == "A" else -1.0

## The reverse in: from the road (truck facing east) back onto the hopper.
func _back_path(slot: String) -> Array:
	var to: Vector3 = _slot_pose(slot)[0]
	return [Vector3(40.0, 0, ROAD_Z), Vector3(33.0, 0, ROAD_Z), Vector3(35.5, 0, to.z), to]

## The drive out: forwards off the hopper and onto the far lane of the road.
func _leave_path(slot: String) -> Array:
	var at: Vector3 = _slot_pose(slot)[0]
	return [at, at + Vector3(7.0, 0, 0), Vector3(37.0, 0, EXIT_Z), Vector3(40.0, 0, EXIT_Z)]

## Whether a car in the street traffic is within `r` of `at` (game ground).
func _street_busy(at: Vector3, r: float) -> bool:
	if not _traffic_looked:
		_traffic_looked = true
		_traffic = get_tree().root.find_child("Traffic", true, false)
	if _traffic == null or not is_instance_valid(_traffic):
		return false
	for c in _traffic.get_children():
		if c is MeshInstance3D and (c as Node3D).global_position.distance_to(at) < r:
			return true
	return false

func _yard_busy(except = null) -> bool:
	for t in trucks:
		if t != except and t["state"] in ["approach", "back", "leave"]:
			return true
	return false

func _slot_free(slot: String) -> bool:
	if slot == "B" and kit != "tower":
		return false   # the truck pump's own outriggers take that side
	for t in trucks:
		if t.get("slot", "") == slot and not (t["state"] in ["leave", "road", "gone"]):
			return false
	return true

## True if this ground point is inside a truck on the site.
func truck_blocks(pt: Vector3) -> bool:
	for t in trucks:
		var n: Node3D = t["node"]
		if n.position.z > 13.5 and t["state"] in ["arrive", "queue", "road"]:
			continue
		var l: Vector3 = n.global_transform.affine_inverse() * Vector3(pt.x, 0.5, pt.z)
		if absf(l.x) < 4.1 and absf(l.z) < 1.4:
			return true
	return false

func _update_trucks(delta: float) -> void:
	_arrive_t -= delta
	if _spawning and (_arrive_t <= 0.0 and live or _arrive_t <= -6.0):
		_spawn_truck(false)
		_arrive_t = interval * randf_range(0.8, 1.25)
	var slot := 0
	var pouring = null
	for t in trucks:
		if t["state"] == "pour":
			pouring = t
	_trust_feed = null
	for t in trucks:
		var node: Node3D = t["node"]
		t["t"] += delta
		var st: String = t["state"]
		# (the first loads are timed for when the line's primed: they don't
		# count the setup and start-up against their 90 minutes)
		if st in ["arrive", "queue", "called", "approach", "back", "bay", "check", "water", "ready", "docket"] and game.ops.primed:
			t["age"] += AGE_RATE * delta
		var drum: Node3D = node.get_node("Drum")
		drum.rotate_object_local(Vector3.RIGHT, delta * (3.0 if st == "pour" else 1.0))
		var lab: Label3D = node.get_node("Docket")
		lab.text = ""
		var ext: Node3D = node.get_node("ChuteExt")
		var cside := _chute_side(t)
		ext.visible = cside != 0.0 and st in ["bay", "check", "water", "ready", "pour", "docket"]
		if ext.visible:
			ext.rotation = Vector3(0, cside * 1.07, -0.12)
			ext.scale = Vector3(1.12, 1, 1)
		var sl: String = t.get("slot", "A")
		match st:
			"arrive", "queue", "called":
				var want_x := _slot_x(slot)
				slot += 1
				node.position.x = move_toward(node.position.x, want_x, 14.0 * delta)
				node.position.z = ROAD_Z
				node.rotation.y = 0.0
				if st == "arrive" and absf(node.position.x - want_x) < 0.05:
					_set_truck(t, "queue")
				if st in ["queue", "called"]:
					# (queued trucks' ages only show to the truck hand nearby)
					var pop = game.crew.crew.get("line")
					if pop != null and pop.zone == "ground" and pop.position.distance_to(node.position) < 9.0:
						lab.text = "%d min" % int(t["age"])
					lab.modulate = Color("ff4d4d") if t["age"] > MAX_AGE else Color.WHITE
				if st == "called" and absf(node.position.x - want_x) < 0.1 and not _yard_busy():
					t["from_x"] = node.position.x
					_set_truck(t, "approach")
			"approach":
				# Drive forwards along the road past the entrance
				var path: Array = _back_path(sl)
				var to_x: float = (path[0] as Vector3).x
				var dist: float = absf(to_x - float(t["from_x"]))
				var dur := maxf(1.0, dist / 15.0)
				var u := clampf(t["t"] / dur, 0.0, 1.0)
				node.position = Vector3(lerpf(t["from_x"], to_x, smoothstep(0.0, 1.0, u)), 0, ROAD_Z)
				node.rotation.y = 0.0
				if u >= 1.0:
					_set_truck(t, "back")
			"back":
				# Reverse onto the hopper. Stop dead if anyone's behind it.
				var path2: Array = _back_path(sl)
				var rear: Vector3 = node.global_transform * Vector3(-5.6, 0, 0)
				var blocked := false
				for q in game.players:
					if q.zone == "ground" and Vector2(q.position.x - rear.x, q.position.z - rear.z).length() < 1.8:
						blocked = true
				if blocked:
					t["t"] -= delta
					if fmod(_knock_phase, 0.5) < delta and not game.sfx.has_loop("truck_beeper"):
						game.sfx.hit("beep")
				# A spotter waves it on: it only reverses while they hold A, and
				# stops where they let go. Nobody spotting (or they walk off):
				# the driver backs in on their mirrors.
				var spot = t.get("spotter")
				if spot != null and game.phase_t - float(t.get("spot_seen", -9.0)) > 1.5:
					t.erase("spotter")
					spot = null
				# (a spotter who waved it in and then stands there: the driver
				# gives up waiting and backs in on their own)
				if spot != null and float(t.get("spot_idle", 0.0)) > SPOT_WAIT:
					game.pop("Driver's backing in on their own", node.position + Vector3(0, 4.0, 0), Color("ffc72c"))
					t.erase("spotter")
					spot = null
				if fmod(t["t"], 0.6) < delta and not game.sfx.has_loop("truck_beeper"):
					game.sfx.hit("beep")
				if spot != null or t.has("su"):
					var su: float = t.get("su", 0.0)
					var moving: bool = not blocked and (spot == null or bool(t.get("spot_hold", false)))
					t["spot_idle"] = 0.0 if moving or blocked else float(t.get("spot_idle", 0.0)) + delta
					if moving:
						su += delta / SPOT_LEN * (1.0 if su < SPOT_SLOW else 0.45)
						if spot == null:
							su = minf(su, 1.0)
					t["su"] = su
					_back_pose(t, path2, su, false)
					if spot == null:
						if su >= 1.0:
							_park(t, sl)
					elif su >= SPOT_BUMP or (not moving and not blocked and su >= SPOT_BAND.x):
						_spot_rated(t, su)
						_park(t, sl)
				else:
					var u3 := clampf(t["t"] / SPOT_LEN, 0.0, 1.0)
					_back_pose(t, path2, u3, true)
					if u3 >= 1.0:
						_park(t, sl)
			"bay", "check", "water", "ready", "docket":
				if st == "docket" and game.phase_t - float(t.get("touched", game.phase_t - t["t"])) > DOCKET_T:
					t["tester"] = null
					if t.get("too_old", false):
						# Nobody's sent it back: the driver reads the age and goes
						game.pop("Driver took his old load back", node.position + Vector3(0, 3.5, 0), Color("ffc72c"))
						var who = game.crew.crew.get("line") if game.crew else null
						if who != null:
							game.score.award(who, -10, "Driver had to make the call")
						reject(t)
					else:
						# Nobody's checked it: the driver starts the chute anyway
						game.pop("Driver didn't wait for the docket check", node.position + Vector3(0, 3.5, 0), Color("ffc72c"))
						accept(t)
				if st in ["bay", "check"] and game.phase_t - float(t.get("touched", game.phase_t - t["t"])) > DRIVER_T:
					_driver_test(t)
				if st in ["bay", "check", "docket"] and pouring == null and _trust_feed == null:
					_on_trust(t, delta)
				if st == "check" and slump.step_of(t) == "fetch":
					# The tester's off to the chute with the tray for a sample
					var side := _chute_side(t)
					var chute: Vector3 = (t["node"] as Node3D).global_transform * (Vector3(-5.4, 0.0, 1.55 * side) if side != 0.0 else Vector3(-4.5, 0.0, 0))
					slump.fetch_tick(t, chute, delta)
				if st == "water" and t["t"] > 3.0:
					# The driver's added the water held back and mixed it in
					# (30 turns of the drum): now it gets tested again
					# (it doesn't always land on the order: a very stiff load can
					# stay stiff even with all of it in, so test it again)
					var need: float = clampf((SPEC_SLUMP - float(t["slump"])) / SLUMP_PER_L, 0.0, WATER_HELD)
					t["slump"] = float(t["slump"]) + need * SLUMP_PER_L * randf_range(0.6, 1.35)
					t["watered"] = true
					t["checked"] = false
					t.erase("measured")
					slump.restart(t)
					_set_truck(t, "bay")
				elif st == "ready":
					lab.text = "Tested · ready"
					lab.modulate = Color("7cd992")
					if pouring == null:
						_set_truck(t, "pour")
						pouring = t
				elif t["checked"]:
					lab.text = docket_text(t)
					var rc := right_call(t)
					lab.modulate = (Color("7cd992") if rc == "use" else (Color("ffc72c") if rc == "water" else Color("ff4d4d"))) if assist() else Color.WHITE
				else:
					# What the driver's docket says (the slump's yours to find)
					lab.text = docket_text(t)
					if t.get("choice", false) and slump.step_of(t) == "sample":
						lab.text += "\nSKIP RISK %d%%" % int(round(skip_risk() * 100.0))
					lab.modulate = Color.WHITE
			"pour":
				var flow := _chute_flow(t, delta)
				t["load"] -= flow
				hopper += flow
				if t.get("bad", "") != "":
					bad_volume += flow
				lab.text = "%.1f m³ left" % t["load"]
				lab.modulate = Color.WHITE
				if t["load"] <= 0.01:
					_set_truck(t, "leave_wait")
			"leave_wait":
				# Chute stowed, waiting for the yard to clear before pulling out
				if not _yard_busy(t):
					_set_truck(t, "leave")
			"leave":
				var lp: Array = _leave_path(sl)
				var u4 := clampf(t["t"] / 2.0, 0.0, 1.0)
				var e4 := u4 * u4 * (1.5 - 0.5 * u4) / 1.0
				e4 = clampf(e4, 0.0, 1.0)
				node.position = _bez(lp[0], lp[1], lp[2], lp[3], e4)
				node.rotation.y = _yaw_for(_bez_d(lp[0], lp[1], lp[2], lp[3], clampf(e4, 0.02, 0.98)))
				if u4 >= 1.0:
					_set_truck(t, "road")
			"road":
				# Out of the mouth, left into Angora Road and away down it to
				# the plant (waiting at the mouth for a gap in the traffic)
				var p0 := Vector3(40.0, 0, EXIT_Z)
				var p3 := ANGORA_LANE + ANGORA_DIR * 10.0
				if t["t"] < 0.5 and _street_busy(ANGORA_LANE, 18.0):
					t["t"] = 0.0
				if t["t"] < TURN_T:
					var k: float = t["t"] / TURN_T
					var u := smoothstep(0.0, 1.0, k) * 0.5 + k * 0.5
					var c1 := p0 + Vector3(7.0, 0, 0)
					var c2 := p3 - ANGORA_DIR * 7.0
					node.position = _bez(p0, c1, c2, p3, u)
					node.rotation.y = _yaw_for(_bez_d(p0, c1, c2, p3, clampf(u, 0.02, 0.98)))
				else:
					node.position = p3 + ANGORA_DIR * 9.0 * (t["t"] - TURN_T)
					node.rotation.y = _yaw_for(ANGORA_DIR)
				if node.position.z < -70.0:
					t["state"] = "gone"
	for t in trucks:
		if t["state"] == "gone":
			(t["node"] as Node).queue_free()
	trucks = trucks.filter(func(t): return t["state"] != "gone")
	# Which truck is feeding the hopper, and which is standing by
	bay_truck = null
	staged = null
	var at_pump: Array = []
	for t in trucks:
		if t["state"] in ["called", "approach", "back", "bay", "check", "water", "ready", "pour", "docket"]:
			at_pump.append(t)
	for t in at_pump:
		if t["state"] == "pour":
			bay_truck = t
	if bay_truck == null and not at_pump.is_empty():
		bay_truck = at_pump[0]
	for t in at_pump:
		if t != bay_truck:
			staged = t
	var feeding = _trust_feed
	for t in trucks:
		if t["state"] == "pour":
			feeding = t
	chute_stream.visible = feeding != null and hopper < HOPPER_CAP - 0.02
	if _hop_splash == null:
		_hop_splash = _particles(30, 0.5, Vector3(0, 1, 0), 60.0, 1.0, 2.2, _blob(0.06, Color("6f7276")))
		_hop_splash.position = HOPPER + Vector3(0.3, 1.0, 0)
	_hop_splash.emitting = chute_stream.visible
	if chute_stream.visible:
		var side := _chute_side(feeding)
		var mouth: Vector3 = (feeding["node"] as Node3D).global_transform * (Vector3(-5.4, 1.35, 1.55 * side) if side != 0.0 else Vector3(-4.5, 1.6, 0))
		_line(chute_stream, mouth, HOPPER + Vector3(0.0, 1.2, 0), 0.14)

## The chute running on trust while the slump test's done (from the moment
## the sample's in the barrow until the call, up to TRUST_M3).
var _trust_feed = null
var streak := 0               # changeovers in a row with the hopper still fed
func _on_trust(t: Dictionary, delta: float) -> void:
	# (a docket being read: the driver's already started the chute)
	if t["state"] != "docket" and (t["checked"] or not t.has("sl") or slump.step_of(t) == "sample"):
		return
	var room := TRUST_M3 - float(t.get("trust_m3", 0.0))
	var flow := minf(TRUST_Q * delta, minf(minf(t["load"], room), HOPPER_CAP - hopper))
	if flow <= 0.0:
		return
	_trust_feed = t
	t["load"] -= flow
	t["trust_m3"] = float(t.get("trust_m3", 0.0)) + flow
	hopper += flow
	# A wet load bleeds where it lands (half the harm, mixed with good concrete
	# in the hopper). A stiff or old one caught in time is diluted enough not
	# to pack the line: it costs points at the call instead (reject).
	if _verdict(t) in ["wet", "mix"]:
		bad_volume += flow * 0.5
		bad_kind = "wet"

## Concrete on its way: in the hopper, at the bay and on the road.
func coming() -> float:
	var v := hopper
	for t in trucks:
		if not (t["state"] in ["leave", "leave_wait", "road"]):
			v += t["load"]
	return v

## Called by the game with what the slab still needs: order another truck if
## what's coming won't finish it (the plant batches it on the phone call).
func top_up(remaining: float) -> void:
	if coming() < remaining and _queue_count() == 0:
		_spawn_truck(false, true)

func _next_queued() -> Variant:
	for t in trucks:
		if t["state"] == "queue":
			return t
	return null

## A truck at the pump waiting on its docket and slump test, or a decision.
## Which loads get a slump test, the way a site runs it: the first load of
## the pour, then a sample through it (every third load here), and any load
## that looks wrong at the chute or whose docket says it's old.
func _wants_test(t: Dictionary) -> bool:
	# (sampling goes by volume: the truck pump's smaller slabs only need the
	# first; and its one spot at the hopper can't spare the time)
	if _backed_in == 1:
		t["why"] = "first load"
		return true
	if kit == "tower":
		# (every load, as routine, unless the truck hand chooses to skip it)
		t["choice"] = true
		return true
	match _verdict(t):
		"stiff", "wet":
			# (the driver can see it's off, not which way: that's the test)
			t["why"] = "looks off at the chute"
			return true
		"old":
			t["why"] = "docket says it's old"
			return true
	return false

## Nobody's come to test or call this load: the driver does it (agitator
## drivers often do the slump test), and makes the call by the book. It
## costs the crew: the truck hand's job went undone.
const DRIVER_T := 20.0
func _driver_test(t: Dictionary) -> void:
	t["touched"] = game.phase_t
	if not t["checked"]:
		t["checked"] = true
		t["measured"] = roundf(float(t["slump"]) / 5.0) * 5.0
		t["state"] = "bay"
		game.pop("Driver did the slump test", (t["node"] as Node3D).position + Vector3(0, 3.5, 0), Color("ffc72c"))
		return
	var who = game.crew.crew.get("line") if game.crew else null
	if who != null:
		game.score.award(who, -10, "Driver had to make the call")
	t["tester"] = null
	match right_call(t):
		"use":
			accept(t)
		"water":
			_set_truck(t, "water")
		_:
			reject(t)

## How likely the next load waved on untested is a bad one.
func skip_risk() -> float:
	return clampf(SKIP_RISK * (skips + 1), SKIP_RISK, SKIP_RISK_MAX)

## The truck hand skips the test: the load goes straight in on trust. Whether
## it's any good is rolled now, at the risk the truck hand was shown.
func skip_test(p, t: Dictionary) -> void:
	var bad := randf() < skip_risk()
	skips += 1
	stats["skipped"] += 1
	t.erase("choice")
	t["checked"] = true
	t["eyeballed"] = true
	t["skipped"] = true
	if bad:
		stats["skipped_bad"] += 1
		var r := randf()
		if r < 0.5:
			t["slump"] = randf_range(52.0, 72.0)
		elif r < 0.8:
			t["slump"] = randf_range(135.0, 175.0)
		else:
			t["slump"] = randf_range(SPEC_SLUMP - 12.0, SPEC_SLUMP + 12.0)
			t["mix_wrong"] = ["mpa", "stone"][randi() % 2]
	elif t.get("mix_wrong", "") == "":
		t["slump"] = randf_range(SPEC_SLUMP - 15.0, SPEC_SLUMP + 15.0)
	game.pop("Waved on: not tested", (t["node"] as Node3D).position + Vector3(0, 3.5, 0), Color("ffc23d"))
	accept(t)

## How far a stiff load has packed into the line on high (0 to 1, where it
## blocks). Nothing while the line's already blocked.
func creep() -> float:
	if bad_volume <= 0.0 or not bad_kind in ["old", "stiff"] or blocked:
		return 0.0
	return clampf(_bad_pumped / 1.4, 0.0, 1.0)

## High or low output: the pump operator's call, on the belt remote (X).
## Dropping to low while a stiff load creeps is CAUGHT EARLY.
func set_output(p, high: bool) -> void:
	if high == speed_high:
		return
	speed_high = high
	if not high and creep() > CREEP_SEEN and not _creep_caught and p != null:
		_creep_caught = true
		stats["creep_caught"] += 1
		var at: Vector3 = PUMP_POS + Vector3(0, 3.2, 0)
		game.score.award(p, CREEP_PAY, "Caught the creep early", at)
		game.pop("CAUGHT EARLY", at + Vector3(0, 0.8, 0), Color("7cd992"))
		game.sfx.hit("thunk")

## True when the driver runs the chute to the pump operator's signals: a
## person on the pump. A bot (or someone covered) leaves it to the driver.
func chute_signalled() -> bool:
	var op = game.crew.crew.get("pump") if game.crew else null
	return op != null and is_instance_valid(op) and not op.bot and not op.covering and not game.tutorial

## m³ out of the chute this frame. The driver tops the hopper up himself,
## unless a person's on the pump: then he runs it at their signal, easing off
## at the brim, except on FAST, where it slops over.
func _chute_flow(t: Dictionary, delta: float) -> float:
	var room := maxf(0.0, HOPPER_CAP - hopper)
	if not chute_signalled():
		return minf(DISCHARGE * delta, minf(t["load"], room))
	var flow := minf(PUMP_Q * CHUTE[chute] * delta, t["load"])
	var fill := hopper / HOPPER_CAP
	var op = game.crew.crew.get("pump")
	if fill >= HOP_BAND.x and fill <= HOP_BAND.y and pumping:
		_band_t += delta
		if _band_t >= BAND_PAY_T:
			_band_t = 0.0
			game.score.award(op, 2, "Kept the hopper between the lines")
	if flow > room:
		if chute == CHUTE.size() - 1:
			# Over the brim: it spills down the side of the pump
			var lost := flow - room
			stats["hopper_spill"] += lost
			t["load"] -= lost
			_spill_t += delta
			if not _spill_paid:
				_spill_paid = true
				game.pop("Hopper's spilling over!", PUMP_POS + Vector3(0, 3.0, 0), Color("ff4d4d"))
				game.score.award(op, -8, "Hopper spilled over")
				game.sfx.hit("plop")
			if _spill_t > 2.0:
				# The driver eases it back himself
				chute = 2
				game.hud.toast("Driver's eased the chute back", 1.4)
		flow = room
	else:
		_spill_t = 0.0
		if fill < HOP_BAND.y - 0.1:
			_spill_paid = false
	return flow

func _pouring_truck() -> bool:
	for t in trucks:
		if t["state"] == "pour":
			return true
	return false

## Holding Y at the panel: signalling the driver. The stick flicks the chute
## up (faster) or down (slower), one step a flick.
func _chute_signal(p, delta: float) -> bool:
	if p.bot or p.covering or not chute_signalled() or not _pouring_truck():
		if p.busy == "chute":
			_end_chute(p)
		return false
	var fill := hopper / HOPPER_CAP
	if p.slow_held():
		p.busy = "chute"   # (stands still: the stick's the signal now)
		var v: Vector2 = p.move_input()
		if _flick_ok and v.y < -0.6:
			chute = mini(CHUTE.size() - 1, chute + 1)
			_flick_ok = false
			game.sfx.hit("tink")
		elif _flick_ok and v.y > 0.6:
			chute = maxi(0, chute - 1)
			_flick_ok = false
			game.sfx.hit("tink")
		elif absf(v.y) < 0.3:
			_flick_ok = true
		var right := fill >= HOP_BAND.x and fill <= HOP_BAND.y
		p.cue("slow", "chute %s · stick up faster, down slower" % CHUTE_NAME[chute].to_lower(), -1.0, not right)
		p.gold(not p.bot and right)
		game.hud.show_meter(true, "HOPPER · CHUTE %s" % CHUTE_NAME[chute], "", HOP_BAND.x, HOP_BAND.y - HOP_BAND.x, fill, "Y")
		_chute_shown_at = game.phase_t
		# Arm up and rolling for faster, flat hand patting down for slower
		var up := chute >= 2
		p.pose_arms(Vector3(-2.6 if up else -1.2, 0, -0.2), Vector3(-0.3, 0, 0.2 + (0.15 * sin(game.phase_t * 9.0) if up else 0.0)))
		p.say("%d%%" % int(fill * 100.0))
		return true
	if p.busy == "chute":
		_end_chute(p)
	var off := fill < HOP_BAND.x or fill > HOP_BAND.y
	p.cue("slow", "signal the chute", -1.0, off)
	return false

func _end_chute(p) -> void:
	p.busy = ""
	_chute_shown_at = -1.0
	game.hud.show_meter(false)

## The call's made: the truck hand radios the pump and the boom what's coming.
## A bot (or the docket) radios on its own, straight away.
func _start_radio(t: Dictionary) -> void:
	var who = t.get("tester")
	if who != null and is_instance_valid(who) and not who.bot and not who.covering and not game.tutorial:
		_radio_t = t
		_radio_left = RADIO_T
		_radio_ready = false
		who.busy = "radio"
		return
	var honest := "NOT TESTED" if t.get("skipped", false) or not t.get("checked", false) else _true_radio(t)
	_send_radio(null, t, honest)

## What a tested load really is, as a radio call.
func _true_radio(t: Dictionary) -> String:
	match _verdict(t):
		"ok": return RADIO["up"]
		"stiff", "old": return RADIO["left"]
	return RADIO["right"]

func _radio(p, _delta: float) -> void:
	var t: Dictionary = _radio_t if _radio_t != null else {}
	if t.is_empty():
		p.busy = ""
		return
	radio_label.visible = true
	radio_label.position = p.global_position + Vector3(0, 3.1, 0)
	radio_label.text = "▲ GOOD ONE\n◀ BIT STIFF      WET ONE ▶\n▼ NOT TESTED"
	# (the wheel's over their head; the stick picks, B lets it go)
	p.cue("leave", "flick the stick to radio · B: no radio", _radio_left / RADIO_T)
	p.pose_arms(Vector3(-2.4, 0, -0.5), Vector3(-0.3, 0, 0.2))
	var v: Vector2 = p.move_input()
	var pick := ""
	if v.length() < 0.3:
		_radio_ready = true
	elif _radio_ready and v.length() > 0.6:
		if absf(v.x) > absf(v.y):
			pick = RADIO["right"] if v.x > 0.0 else RADIO["left"]
		else:
			pick = RADIO["down"] if v.y > 0.0 else RADIO["up"]
	if pick != "":
		_send_radio(p, t, pick)
	if pick != "" or p.leave_pressed():
		p.busy = ""
		_radio_t = null
		radio_label.visible = false

## The radio goes out: a pill over the pump operator and the boom operator,
## and a buzz on the pump operator's phone. Right pays both.
func _send_radio(p, t: Dictionary, said: String) -> void:
	last_radio = said
	var col := Color("7cd992") if said == RADIO["up"] else (Color("ffc23d") if said in [RADIO["left"], RADIO["down"]] else Color("6cc6ff"))
	var crew = game.crew.crew if game.crew else {}
	var shown := false
	for role in ["pump", "boom"]:
		var q = crew.get(role)
		if q != null and is_instance_valid(q) and q != p:
			game.pop("RADIO: " + said, q.global_position + Vector3(0, 2.6, 0), col)
			shown = true
	if not shown:
		game.pop("RADIO: " + said, PUMP_POS + Vector3(0, 3.6, 0), col)
	var op = crew.get("pump")
	game.haptic(op, "40,60,40")
	if p == null:
		return
	var right := (said == RADIO["down"]) if t.get("skipped", false) else (said == _true_radio(t))
	if right:
		stats["radio_right"] += 1
		game.score.award(p, RADIO_PAY, "Radioed it right")
		if op != null and op != p:
			game.score.award(op, RADIO_PAY, "Radioed it right")

func needs_check() -> Variant:
	for t in [bay_truck, staged]:
		if t != null and t["state"] in ["bay", "check", "docket"]:
			return t
	return null

## True if there's a truck on the road and a free side of the hopper for it.
func can_wave_in() -> bool:
	var nq = _next_queued()
	if nq == null:
		return false
	return _slot_free("A") or _slot_free("B")

## Bay actions shared by a person and the bots: call the next truck in. It
## pulls up and reverses onto whichever side of the hopper is free.
func wave_in(spotter = null) -> bool:
	if not can_wave_in():
		return false
	var t = _next_queued()
	t["slot"] = "A" if _slot_free("A") else "B"
	if spotter != null:
		# A person waving it on: they spot it all the way back (_bay)
		t["spotter"] = spotter
		t["spot_seen"] = game.phase_t
	_set_truck(t, "called")
	return true

## The truck's on the hopper: it's due a slump test, or the truck hand checks
## its docket against the order (now and then it's the wrong mix).
func _park(t: Dictionary, sl: String) -> void:
	var node: Node3D = t["node"]
	var pose: Array = _slot_pose(sl)
	node.position = pose[0]
	node.rotation.y = _yaw_for(pose[1])
	t.erase("spotter")
	_set_truck(t, "bay")
	if float(t["age"]) > MAX_AGE:
		# Over the age on the docket: no slump test, it just goes back
		t["checked"] = true
		t["eyeballed"] = true
		t["too_old"] = true
		t["why"] = "docket says it's old"
		_set_truck(t, "docket")
		return
	_backed_in += 1
	if _wants_test(t):
		# (now and then the plant's sent the wrong mix: it's on the docket,
		# and it goes back whatever the slump reads)
		if kit == "tower" and _backed_in > 1 and not quiet and randf() < MIX_WRONG:
			t["mix_wrong"] = ["mpa", "stone", "site"][randi() % 3]
		return
	t["checked"] = true
	t["eyeballed"] = true
	if _backed_in > 1 and not quiet and randf() < MIX_WRONG:
		t["mix_wrong"] = ["mpa", "stone", "site"][randi() % 3]
		t["why"] = "wrong mix"
	_set_truck(t, "docket")

## Where a reversing truck is, `u` of the way back (past 1: into the hopper).
func _back_pose(t: Dictionary, path: Array, u: float, eased: bool) -> void:
	var node: Node3D = t["node"]
	var e := smoothstep(0.0, 1.0, u) if eased else minf(u, 1.0)
	node.position = _bez(path[0], path[1], path[2], path[3], e)
	if u > 1.0:
		var back: Vector3 = ((path[3] as Vector3) - _bez(path[0], path[1], path[2], path[3], 0.97)).normalized()
		node.position += back * (u - 1.0) * 12.0
	var tan := _bez_d(path[0], path[1], path[2], path[3], clampf(e, 0.02, 0.98))
	node.rotation.y = _yaw_for(-tan)

## How well the spotter stopped it.
func _spot_rated(t: Dictionary, u: float) -> void:
	var p = t.get("spotter")
	var at: Vector3 = (t["node"] as Node3D).position + Vector3(0, 4.0, 0)
	if u >= SPOT_BUMP:
		game.pop("Whoa! Backed into the hopper", at, Color("ff4d4d"))
		game.sfx.hit("clank")
		if p != null:
			game.score.award(p, -10, "Trucks spotted in")
		return
	var err := absf(u - 1.0)
	if err < 0.015:
		game.pop("Spot on!", at, Color("ffd23f"))
		if p != null:
			game.score.award(p, 15, "Trucks spotted in")
	elif err < 0.035:
		game.pop("Good stop", at, Color("7cd992"))
		if p != null:
			game.score.award(p, 8, "Trucks spotted in")
	else:
		game.pop("Close enough", at, Color("ffffff"))
		if p != null:
			game.score.award(p, 3, "Trucks spotted in")

func accept(t: Dictionary) -> void:
	var v := _verdict(t)
	var at: Vector3 = (t["node"] as Node3D).position + Vector3(0, 3.5, 0)
	game.pop("Good load" if v == "ok" else ("Wrong mix going in!" if v == "mix" else "Bad load!"), at, Color("7cd992") if v == "ok" else Color("ff4d4d"))
	var who = t.get("tester")
	if who != null:
		game.score.award(who, 15 if v == "ok" else -25, "Good loads in" if v == "ok" else "Bad load accepted")
	if v != "ok":
		# (a weaker mix in the slab: a weak patch where it lands, like a wet one)
		t["bad"] = "wet" if v == "mix" else v
		bad_kind = t["bad"]
		stats["bad_loads"] += 1
		game.hud.toast("Bad load going in the pump...", 1.6)
	t["accepted"] = true
	_start_radio(t)
	var other_pouring := false
	for o in trucks:
		if o != t and o["state"] == "pour":
			other_pouring = true
	_set_truck(t, "ready" if other_pouring else "pour")

func reject(t: Dictionary) -> void:
	if game.autotest:
		print("[autotest]   rejected: slump %.0f measured %s age %.0f why %s watered %s" % [float(t["slump"]), str(t.get("measured", "-")), float(t["age"]), str(t.get("why", _verdict(t))), str(t.get("watered", false))])
	game.pop("Rejected", (t["node"] as Node3D).position + Vector3(0, 3.5, 0), Color("ffc23d"))
	var who = t.get("tester")
	if who != null:
		game.score.award(who, 15 if _verdict(t) != "ok" else -20, "Bad loads turned away" if _verdict(t) != "ok" else "Good load rejected")
	stats["rejected"] += 1
	if _verdict(t) == "mix":
		stats["wrong_mix_caught"] += 1
	var in_already: float = t.get("trust_m3", 0.0)
	if in_already > 0.3 and _verdict(t) != "ok":
		if who != null:
			game.score.award(who, -int(roundf(in_already * 4.0)), "Bad concrete in before the call")
		game.hud.toast("Chute stopped. %.1f m³ went in before the call. Truck sent back." % in_already, 2.0)
	else:
		game.hud.toast("Load rejected. Truck sent back to the plant.", 1.6)
	ordered -= t["load"]
	_set_truck(t, "leave_wait")
	# Order a replacement straight away
	_arrive_t = minf(_arrive_t, 2.0)

# ------------------------------------------------------------------ per frame


# ------------------------------------------------------------------ per frame

func update(delta: float, in_pour: bool) -> void:
	_knock_phase += delta
	_spawning = in_pour
	_update_trucks(delta)
	if in_pour:
		_watchdog(delta)
		_spikes(delta)
	elif spike_on or spike_warn or _pending_cause != "":
		spike_on = false
		spike_warn = false
		_pending_cause = ""
	var static_p := 12.0 + riser_top * 0.3
	var target := pressure
	if burst:
		target = 0.0
	elif reversing:
		# (reversing bleeds it off even with the pump tripped, so a repair
		# never waits on a restart)
		target = 0.0
	elif tripped or job_kind != "":
		# Killed (or a joint's being worked on): the line bleeds off to nothing
		target = 0.0
	elif spike_on:
		target = SPIKE_BAR
	elif pumping and blocked:
		target = 240.0
	elif pumping:
		target = (55.0 + riser_top * 1.1) * (1.0 if speed_high else 0.72)
		target += 85.0 * creep()
		if fail_i >= 0:
			target += 55.0 * wear
		if quiet and spike_warn and _pending_cause == "":
			target += 90.0 * clampf(1.0 - _spike_in / QUIET_WARN, 0.0, 1.0)
	elif live:
		target = minf(pressure, static_p + 8.0)
	else:
		target = 0.0
	pressure = lerpf(pressure, target, minf(1.0, delta * (7.0 if spike_on else (3.0 if reversing or pumping or tripped else 1.2))))
	if reversing and pressure > SAFE_BAR and fmod(_knock_phase, 0.5) < delta:
		game.sfx.hit("hiss")
	reversing = false   # held each frame by whoever is on the panel
	gauge_needle.rotation.z = 2.2 - 4.4 * clampf(pressure / 250.0, 0.0, 1.0)
	_kill_show_t = maxf(0.0, _kill_show_t - delta)
	if gauge_label:
		if spike_on:
			gauge_label.text = "%d bar" % int(pressure)
			gauge_label.modulate = Color("ff5a5f") if fmod(_knock_phase, 0.3) < 0.18 else Color.WHITE
		elif tripped:
			gauge_label.text = "PUMP OFF  %d bar" % int(pressure)
			gauge_label.modulate = Color("ffc23d")
		elif creep() > CREEP_SEEN:
			# A stiff load packing in: the needle climbs, and keeps climbing
			gauge_label.text = "%d bar ▲" % int(pressure)
			gauge_label.modulate = Color("ffc23d")
		else:
			gauge_label.text = "%d bar" % int(pressure)
			gauge_label.modulate = Color("ff5a5f") if pressure > 180.0 else Color.WHITE

	if not reversing:
		_reverser = null
	if wash:
		wash.update(delta)
	# The chute signals' close-up only shows while someone's holding Y
	if _chute_shown_at >= 0.0 and game.phase_t - _chute_shown_at > 0.15:
		_chute_shown_at = -1.0
		game.hud.show_meter(false)
		for q in game.players:
			if q.busy == "chute":
				q.busy = ""
	if _radio_t != null:
		_radio_left -= delta
		var who = _radio_t.get("tester")
		if _radio_left <= 0.0 or who == null or not is_instance_valid(who) or who.busy != "radio" or not in_pour:
			if who != null and is_instance_valid(who) and who.busy == "radio":
				who.busy = ""
			_radio_t = null
			radio_label.visible = false

	# The slump cone only stands out while a load is being tested
	if (needs_check() == null or not in_pour) and not _fetching():
		slump_cone.visible = false
	# The spotting readout only shows while someone's waving a truck back
	if not _spot_shown:
		spot_label.visible = false
		for k in spot_marks:
			(spot_marks[k]["mat"] as StandardMaterial3D).albedo_color = Color("ffc72c")
	_spot_shown = false

	# Hopper visual
	var fill := clampf(hopper / HOPPER_CAP, 0.0, 1.0)
	hopper_fill.position.y = 0.95 + fill * 0.8
	hopper_fill.visible = hopper > 0.02
	# The level's on the HUD; over the hopper it only speaks up when it's low
	# (not in the start-up: an empty hopper's normal before the first load)
	hopper_label.text = "LOW" if fill < 0.2 and in_pour and game.ops != null and game.ops.primed else ""
	hopper_label.modulate = Color("ff4d4d")
	# Pump body thumps with each stroke
	var stroke_u := absf(sin(_knock_phase * PI / 0.8)) if pumping else 0.0
	pump_unit.position = PUMP_POS + Vector3(0, stroke_u * 0.03, 0)

	# Clamps: the weeping one drips, knocks each stroke and glows
	beacon.visible = false
	drips.emitting = false
	for i in clamps.size():
		var c: Dictionary = clamps[i]
		var m: ShaderMaterial = c["mat"]
		var node: Node3D = c["node"]
		var lab: Label3D = c["label"]
		var hot := i == fail_i and not burst and fix_step <= 1
		var w := wear if hot else 0.0
		var base: Vector3 = c["pos"]
		if hot:
			var pulse := 0.5 + 0.5 * sin(_knock_phase * (5.0 + 16.0 * w))
			m.set_shader_parameter("albedo", Color("8f9aa6").lerp(Color("ff4d4d"), minf(1.0, 0.3 + w)))
			m.set_shader_parameter("emission_color", Color(1.0, 0.25, 0.15) * (0.4 + 1.6 * w) * pulse)
			var shake_amt := 0.03 * w * (1.0 if pumping else 0.2)
			node.position = base + Vector3(sin(_knock_phase * 31.0), 0, cos(_knock_phase * 27.0)) * shake_amt
			drips.position = base
			drips.emitting = true
			if pumping and fmod(_knock_phase, 0.8) < delta:
				game.sfx.hit("knock")
		elif i == fix_i and job_kind != "":
			# The joint being worked on glows softly so it reads in a close-up
			m.set_shader_parameter("emission_color", Color(1.0, 0.85, 0.3) * (0.25 + 0.2 * sin(_knock_phase * 6.0)))
			node.position = base
		else:
			m.set_shader_parameter("emission_color", Color.BLACK)
			node.position = base
		(c["pin"] as Node3D).visible = c["pinned"] or c["open"] > 0.0
		var show_label := false
		for p in game.players:
			if p.zone == "ladder" and absf(p.position.y + 1.0 - base.y) < 4.0:
				show_label = true
		lab.visible = show_label and i != fail_i and i != fix_i
	var mark := fix_i if fix_i >= 0 else fail_i
	if mark >= 0 and in_pour:
		var mp: Vector3 = clamps[mark]["pos"]
		beacon.visible = true
		beacon.position = mp + Vector3(0.6, 0.9 + 0.15 * sin(_knock_phase * 8.0), 0.6)
		beacon.text = "! C%d" % (mark + 1)
	elif blocked and not block_found and in_pour and kit == "tower":
		beacon.visible = true
		beacon.position = Vector3(RISER.x + 0.8, riser_top * 0.5, RISER.z + 0.6)
		beacon.text = "? tap"

	# The old clamp: flies off in a burst, or into the line hand's hand on a swap
	if flying and flying.visible:
		if _fly_to != null:
			var hp: Vector3 = _fly_to.global_position + Vector3(0, 1.0, 0)
			flying.position = flying.position.lerp(hp, minf(1.0, delta * 6.0))
			flying.scale = flying.scale.lerp(Vector3.ONE * 0.2, minf(1.0, delta * 4.0))
			if flying.position.distance_to(hp) < 0.15:
				flying.visible = false
		else:
			_fly_v.y -= 14.0 * delta
			flying.position += _fly_v * delta
			flying.rotation += Vector3(9, 5, 7) * delta
			if flying.position.y < 0.0:
				flying.visible = false
	# A plugged pipe being lowered on a rope to the ground
	if _lowering != null:
		var lw: Dictionary = _lowering
		lw["t"] += delta
		var node: Node3D = lw["node"]
		var u := clampf(lw["t"] / 1.6, 0.0, 1.0)
		var from: Vector3 = lw["from"]
		node.position = from.lerp(Vector3(from.x + 1.2, 0.2, from.z + 1.0), ease(u, 0.6))
		node.rotation.z = lerpf(0.0, PI * 0.5, u)
		if u >= 1.0:
			_junk.append([node, 0.0])
			_lowering = null
			game.sfx.hit("thunk")
	for jk in _junk:
		jk[1] += delta
		if jk[1] > 8.0:
			(jk[0] as Node3D).position.y -= delta * 0.3
	for jk in _junk:
		if jk[1] > 10.0:
			(jk[0] as Node).queue_free()
	_junk = _junk.filter(func(jk): return jk[1] <= 10.0)
	if _tap_t > 0.0:
		_tap_t -= delta
		tap_label.modulate.a = clampf(_tap_t, 0.0, 1.0)
		tap_label.position.y += delta * 0.4
		tap_label.visible = _tap_t > 0.0

	if not burst:
		grout_spray.emitting = false
	_update_hook(delta)
	_update_npc(delta, in_pour)

# ------------------------------------------------------------------ players

func human_on_ground() -> bool:
	for p in game.players:
		if p.zone == "ground":
			return true
	return false

## Joint within reach of this player, or -1.
func joint_near(p) -> int:
	var best := -1
	var best_d := 1.1
	for i in clamps.size():
		var cp: Vector3 = clamps[i]["pos"]
		var d := 99.0
		if p.zone == "ladder":
			d = absf(p.position.y + 1.0 - cp.y) * 0.75
		elif p.zone == "ground" and cp.y < 3.0:
			d = Vector2(p.position.x - cp.x, p.position.z - cp.z).length() - 0.8
		if d < best_d:
			best_d = d
			best = i
	return best

## Where to point a close-up camera for this player's hands, or INF.
func work_focus(p) -> Vector3:
	if game.phase != "pour":
		return Vector3.INF
	if fix_i >= 0 and joint_near(p) == fix_i and fix_step > 0:
		return clamps[fix_i]["pos"]
	var bay_at: Vector3 = game.GROUND_STATIONS["bay"]["pos"]
	var t = needs_check()
	if p.zone == "ground" and t != null and t.get("tester") == p and Vector2(p.position.x - bay_at.x, p.position.z - bay_at.z).length() < 1.6:
		return slump.focus(t)
	return Vector3.INF

## Ground stations, parts, the ladder and on-ladder work. Returns true if handled.
func handle_player(p, delta: float, near: String) -> bool:
	# A pressure spike: the pump operator kills it on the belt remote (A),
	# wherever they are, street, deck or halfway up the riser. Every tenth
	# of a second counts.
	if p.role == "pump" and spike_on and p.busy in ["", "rigger", "chute"]:
		if p.busy == "chute":
			_end_chute(p)
		p.cue("action", "KILL THE PUMP", -1.0, true, Vector2(-1, -1), true)
		if p.action_pressed():
			kill_pump(p)
		return true
	if p.busy == "radio":
		_radio(p, delta)
		return true
	if p.zone == "ladder":
		_ladder(p, delta)
		return true
	# Joints reachable from where they stand (the base bend, or the truck's deck pipe)
	if p.zone == "ground" and p.busy == "":
		var j := joint_near(p)
		if j >= 0 and _joint_work(p, j, delta):
			return true
		if j >= 0 and blocked and not block_found:
			p.cue("action", "tap")
			p.gold(not p.bot and (j == block_s or j == block_s + 1))
			if p.action_pressed():
				_worker = p
				_tap(clamps[j]["pos"].y, j)
				p.bounce()
			return true
	match near:
		"ladder":
			if kit != "tower":
				return false
			p.cue("action", "climb")
			if p.action_pressed():
				p.zone = "ladder"
				p.position = Vector3(LADDER.x + 0.45, p.position.y, LADDER.z)
				p.face(Vector3(RISER.x, p.position.y, RISER.z))
			return true
		"pins":
			if kit == "tower" and game.climb.needs_pins() and p.held == null and p.tool in ["", "screed"]:
				p.cue("action", "take a pin bag", -1.0, true)
				if p.action_pressed():
					p.hold_item(make_item("pins"), "pins")
					game.sfx.hit("tink")
				return true
			return false
		"spares", "rack":
			var want := "clamp" if near == "spares" else "pipe"
			if p.held == null and p.tool in ["", "screed"]:
				p.cue("action", "take " + ("clamp kit" if want == "clamp" else "pipe"))
				if p.action_pressed():
					p.hold_item(make_item(want), want)
					game.sfx.hit("clank")
				return true
			return false
		"haul":
			if kit != "tower":
				return false
			if p.held != null and p.held_kind in ["clamp", "pipe", "pins"] and hook["kind"] == "" and hook["state"] == "down":
				p.cue("action", "send it up", -1.0, true)
				if p.action_pressed():
					send_up(p)
				return true
			return false
		"bay":
			_bay(p, delta)
			return true
		"panel":
			_panel(p, delta)
			return true
	return false

## Clips the part someone's carrying onto the haul rope and hauls it up to the
## joint being worked (or the line hand, wherever they are on the ladder).
func send_up(p) -> void:
	var it: Node3D = p.release_item()
	if it == null:
		return
	hook["kind"] = it.get_meta("kind")
	hook["node"] = it
	add_child(it)
	hook["y"] = 1.0
	if hook["kind"] == "pins":
		# Up to the climbing frame's walkway, for the rigger
		hook["to"] = clampf(game.climb.platform_spot().y + 1.0, 1.0, riser_top - 0.3)
		hook["state"] = "rising"
		game.sfx.hit("clank")
		game.score.award(p, 10, "Pins sent up", HAUL + Vector3(0, 2.0, 0))
		p.pose_arms(Vector3(-2.7, 0, -0.2), Vector3(-2.2, 0, 0.2))
		p.bounce()
		return
	var j := fix_i if fix_i >= 0 else fail_i
	var to := riser_top * 0.5
	if j >= 0:
		to = float(clamps[j]["pos"].y) - 0.2
	else:
		for q in game.players:
			if q.zone == "ladder":
				to = q.position.y + 1.0
	hook["to"] = clampf(to, 1.0, riser_top - 0.8)
	hook["state"] = "rising"
	game.sfx.hit("clank")
	game.score.award(p, 10, "Parts run to the line", HAUL + Vector3(0, 2.0, 0))
	p.pose_arms(Vector3(-2.7, 0, -0.2), Vector3(-2.2, 0, 0.2))
	p.bounce()

func _take_hook(p) -> void:
	var it: Node3D = hook["node"]
	if it == null:
		return
	if it.get_parent():
		it.get_parent().remove_child(it)
	p.hold_item(it, hook["kind"])
	hook["kind"] = ""
	hook["node"] = null
	hook["state"] = "lowering"
	game.sfx.hit("tink")

## The part someone needs, sent up the rope or lying by the joint: take it.
func _take_nearby_part(p, want: String, at: Vector3) -> bool:
	if hook["kind"] == want and hook["state"] == "up" and p.zone == "ladder" and absf(hook["y"] - (p.position.y + 1.0)) < 1.8:
		p.cue("action", "take " + want, -1.0, true)
		if p.action_pressed():
			_take_hook(p)
		return true
	for e in items:
		if e["kind"] == want and e["zone"] == p.zone:
			var n: Node3D = e["node"]
			if Vector2(n.global_position.x - at.x, n.global_position.z - at.z).length() < 2.2 and Vector2(n.global_position.x - p.position.x, n.global_position.z - p.position.z).length() < 2.4:
				var op := _step_name()
				if op in ["kit", "pipe"]:
					p.cue("action", "take " + want, -1.0, true)
					if p.action_pressed():
						pick_up(p, e)
					return true
	return false

## Is a part of this kind on its way to the line hand (by someone other than
## `asker`): on the rope, in someone's hands, or lying by the joint?
func part_coming(kind: String, asker) -> bool:
	if hook["kind"] == kind:
		return true
	for q in game.players:
		if q != asker and q.held_kind == kind:
			return true
	var j := fix_i if fix_i >= 0 else fail_i
	if j >= 0:
		var at: Vector3 = clamps[j]["pos"]
		for e in items:
			var n: Node3D = e["node"]
			if e["kind"] == kind and Vector2(n.global_position.x - at.x, n.global_position.z - at.z).length() < 2.2:
				return true
	return false

func _update_hook(delta: float) -> void:
	if kit != "tower":
		return
	# Whoever's on the ground keeps the part at the line hand's hands
	if hook["kind"] == "pins" and hook["state"] == "up":
		# The rigger reaches over and takes the bag off the hook
		var bag = hook["node"]
		if bag != null:
			(bag as Node).queue_free()
		hook["node"] = null
		hook["kind"] = ""
		hook["state"] = "lowering"
		game.climb.pins_arrived()
	if hook["state"] in ["rising", "up"] and hook["kind"] != "pins":
		for q in game.players:
			if q.zone == "ladder":
				hook["to"] = clampf(q.position.y + 0.9, 1.0, riser_top - 0.8)
				# Up already: it just follows them along the ladder, quietly
				if hook["state"] == "up":
					hook["y"] = move_toward(hook["y"], hook["to"], 4.0 * delta)
	# A part left hanging that nobody needs gets lowered back down
	if hook["state"] == "up":
		hook["idle"] = float(hook.get("idle", 0.0)) + delta
		var need := ""
		if job_kind in ["clamp", "burst"] or (job_kind == "" and fail_i >= 0):
			need = "clamp"
		elif job_kind == "block":
			need = "pipe"
		if hook["kind"] != need and hook["idle"] > 4.0:
			var it2 = hook["node"]
			if it2 != null:
				(it2 as Node).queue_free()
			hook["node"] = null
			hook["kind"] = ""
			hook["state"] = "lowering"
	else:
		hook["idle"] = 0.0
	match hook["state"]:
		"rising":
			hook["y"] = move_toward(hook["y"], hook["to"], 4.0 * delta)
			# The gin wheel ticking over, only while it's hauling up
			if fmod(_knock_phase, 0.4) < delta and hook["to"] - hook["y"] > 0.5:
				game.sfx.hit("tink")
			if absf(hook["y"] - hook["to"]) < 0.01:
				hook["state"] = "up"
		"lowering":
			hook["y"] = move_toward(hook["y"], 0.3, 6.0 * delta)
			if hook["y"] <= 0.31:
				hook["state"] = "down"
		"down":
			hook["y"] = 0.3
	var sway := 0.06 * sin(_knock_phase * 2.3) if hook["state"] != "down" else 0.0
	hook_node.position = HAUL + Vector3(sway, hook["y"], 0)
	var it = hook["node"]
	if it != null:
		(it as Node3D).position = hook_node.position + Vector3(0, -0.35, 0.0)
		(it as Node3D).rotation = Vector3(0, 0, PI * 0.5) if hook["kind"] == "pipe" else Vector3(0, _knock_phase, 0)
	var top := Vector3(HAUL.x, riser_top + 0.6, HAUL.z)
	_line(haul_rope, top, hook_node.position + Vector3(0, 0.2, 0), 0.015)
	var wheel: Node3D = hook_node.get_meta("wheel")
	wheel.position = top + Vector3(0, 0.12, 0)
	if hook["state"] in ["rising", "lowering"]:
		wheel.rotate_object_local(Vector3.UP, delta * 12.0)

## Drops whatever the player is carrying at their feet.
func drop_item(p) -> void:
	var it: Node3D = p.release_item()
	if it == null:
		return
	var kind: String = it.get_meta("kind")
	var parent: Node3D = game.rig if p.zone == "deck" else self
	parent.add_child(it)
	it.position = p.position - parent.position + Vector3(0, 0.25, 0)
	it.rotation = Vector3(0, 0, PI * 0.5) if kind == "pipe" else Vector3.ZERO
	items.append({"node": it, "kind": kind, "zone": p.zone})
	game.sfx.hit("thunk")

## A part lying within reach of this player, or {}.
func item_near(p) -> Dictionary:
	for e in items:
		if e["zone"] != p.zone:
			continue
		var n: Node3D = e["node"]
		var d := Vector2(n.global_position.x - p.position.x, n.global_position.z - p.position.z).length()
		if d < 1.3:
			return e
	return {}

func pick_up(p, e: Dictionary) -> void:
	items.erase(e)
	p.hold_item(e["node"], e["kind"])
	game.sfx.hit("tink")

const LADDER_OFF_T := 1.2   # s holding down at the foot of the ladder before you're stepped off

func _ladder(p, delta: float) -> void:
	var v: Vector2 = p.move_input()
	var top := maxf(0.0, riser_top - 1.6)
	var work: float = game.work_y
	if kit == "tower" and game.deck_open():
		top = maxf(top, work)   # the ladder always reaches the deck
	var sp := CLIMB_SPEED * (0.6 if p.held_kind == "pipe" else 1.0)
	var climbing := absf(v.y) > 0.3
	# Magnetic stops: the joint being worked (or about to be), the deck and
	# the ground. Let go of the stick anywhere near one and you're pulled to
	# the exact working height; climb past one and you catch there for a
	# moment, so you never have to fiddle about lining up.
	var stops: Array = [0.0]
	if kit == "tower" and game.deck_open():
		stops.append(work)
	var jt := fix_i if fix_i >= 0 else fail_i
	if jt >= 0:
		stops.append(clampf(float(clamps[jt]["pos"].y) - 1.0, 0.0, top))
	if blocked and block_found and block_s >= 0:
		stops.append(clampf(float(clamps[block_s]["pos"].y) - 1.0, 0.0, top))
	var detent: float = p.get_meta("ladder_detent", 0.0)
	if p.ai:
		stops = []   # bots climb to the exact height anyway
	if climbing:
		var y0: float = p.position.y
		var y1: float = clampf(y0 - signf(v.y) * sp * delta, 0.0, top)
		if detent > 0.0:
			p.set_meta("ladder_detent", detent - delta)
			y1 = y0
		else:
			for st in stops:
				if st > 0.01 and (y0 - st) * (y1 - st) < 0.0 and absf(y0 - st) > 0.001:
					y1 = st   # caught at the stop
					p.set_meta("ladder_detent", 0.3)
					game.sfx.hit("clank")
					break
		p.position.y = y1
	else:
		p.set_meta("ladder_detent", 0.0)
		var best := INF
		for st in stops:
			if absf(st - p.position.y) < 1.8 and absf(st - p.position.y) < absf(best - p.position.y):
				best = st
		if best != INF:
			p.position.y = move_toward(p.position.y, best, 3.0 * delta)
	var ph: float = p.position.y * 3.0
	if climbing:
		p.pose_arms(Vector3(-2.6 + 0.5 * sin(ph), 0, -0.3), Vector3(-2.6 - 0.5 * sin(ph), 0, 0.3))
		p.model.get_node("LegL").rotation.x = 0.5 * sin(ph)
		p.model.get_node("LegR").rotation.x = -0.5 * sin(ph)
	else:
		p.pose_arms(Vector3(-2.5, 0, -0.3), Vector3(-1.4, 0, 0.4))
	p.position.x = LADDER.x + 0.45
	p.position.z = LADDER.z
	p.model.rotation.y = -PI * 0.5
	var at_deck: bool = absf(p.position.y - work) < 0.5 and kit == "tower" and game.deck_open()
	var at_ground: bool = p.position.y < 0.5
	# Still pushing down at the foot of the ladder: you're stepped off it
	var down_t: float = p.get_meta("ladder_down", 0.0)
	down_t = down_t + delta if at_ground and p.position.y < 0.05 and v.y > 0.3 else 0.0
	p.set_meta("ladder_down", down_t)
	if down_t >= LADDER_OFF_T:
		p.set_meta("ladder_down", 0.0)
		p.zone = "ground"
		p.position = Vector3(LADDER.x + 0.6, 0.0, LADDER.z + 1.3)
		return
	p.say("%d m" % int(round(p.position.y)))
	var j := joint_near(p)
	var at_job: bool = j >= 0 and job_kind != "" and j == fix_i
	if not climbing and not at_job and p.held == null and hook["kind"] != "" and hook["state"] == "up" and absf(hook["y"] - (p.position.y + 1.0)) < 1.6:
		p.cue("action", "take " + ("clamp" if hook["kind"] == "clamp" else "pipe"), -1.0, true)
		if p.action_pressed():
			_take_hook(p)
		return
	if not climbing and j >= 0 and _joint_work(p, j, delta):
		return
	if blocked and not block_found and not climbing:
		p.cue("action", "tap pipe")
		if not p.bot and block_s >= 0 and block_s + 1 < clamps.size():
			var ty: float = p.position.y + 1.0
			p.gold(ty > float(clamps[block_s]["pos"].y) - 0.2 and ty < float(clamps[block_s + 1]["pos"].y) + 0.2)
		if p.action_pressed():
			_worker = p
			_tap(p.position.y + 1.0)
			p.pose_arms(Vector3(-2.5, 0, -0.3), Vector3(-1.9, 0, 0.9))
			p.bounce()
	if at_deck:
		p.cue("leave", "step off")
	elif at_ground:
		p.cue("leave", "step off")
	if p.leave_pressed():
		if at_deck:
			p.zone = "deck"
			p.position = Vector3(13.6, work, 1.6)
		elif at_ground:
			p.zone = "ground"
			# (onto the street side of the ladder, clear of the west wing)
			p.position = Vector3(LADDER.x + 0.6, 0.0, LADDER.z + 1.3)

## Tap the pipe: a clear pipe rings, a packed one thuds.
func _tap(y: float, j := -1) -> void:
	var near_block := false
	if blocked and block_s >= 0 and block_s + 1 < clamps.size():
		if j < 0:
			var y0: float = clamps[block_s]["pos"].y
			var y1: float = clamps[block_s + 1]["pos"].y
			near_block = y > y0 - 0.2 and y < y1 + 0.2
		else:
			near_block = j == block_s or j == block_s + 1
	var at: Vector3 = Vector3(RISER.x - 0.4, y, RISER.z + 0.7) if j < 0 else clamps[j]["pos"] + Vector3(0, 0.6, -0.5)
	tap_label.position = at
	_tap_t = 1.4
	tap_label.visible = true
	if near_block:
		game.sfx.hit("thud")
		tap_label.text = "THUD"
		tap_label.modulate = Color("ff4d4d")
		block_found = true
		if _worker != null:
			game.score.award(_worker, 25, "Blockage found by tap test", at + Vector3(0, 0.5, 0))
		if game.autotest:
			print("[autotest]   tap test found the plug above C%d" % (block_s + 1))
		if job_kind == "":
			_start_job("block", block_s)
	else:
		game.sfx.hit("ring")
		tap_label.text = "ring"
		tap_label.modulate = Color("7cd992")

## Work on joint `j` if it needs work. Returns true if it took the controls.
func _joint_work(p, j: int, delta: float) -> bool:
	# A weeping clamp can be swapped before it goes
	if j == fail_i and job_kind == "" and not burst:
		p.cue("action", "swap clamp", -1.0, true)
		p.gold(not p.bot)
		if p.action_pressed():
			_start_job("clamp", j)
			_worker = p
			p.bounce()
		return true
	if job_kind == "" or j != fix_i:
		return false
	var c: Dictionary = clamps[j]
	p.face(c["pos"])
	var op := _step_name()
	_worker = p
	var want := "pipe" if job_kind == "block" else "clamp"
	# Carrying the wrong part up here? It goes back in the pouch / down the rope
	if p.held != null and p.held_kind != want and op in ["depress", "kit", "pipe", "clean"]:
		var spare: Node3D = p.release_item()
		if spare:
			spare.queue_free()
	# A part sent up on the haul rope, or left by the joint, can be taken here
	if p.held == null and op in ["depress", "kit", "pipe"]:
		if _take_nearby_part(p, want, c["pos"]):
			return true
	match op:
		"depress":
			# Still under pressure: the clamp can't come off yet. The button goes
			# red and shakes, and trying it anyway gets a spit of grout back
			p.cue("action", "%d bar · wait" % int(pressure), -1.0, true, Vector2(-1, -1), true)
			p.pose_arms(Vector3(-0.4, 0, -0.3), Vector3(-0.4, 0, 0.3))
			if p.action_pressed():
				grout_spray.position = c["pos"]
				grout_spray.amount = 10
				grout_spray.restart()
				grout_spray.emitting = true
				game.sfx.hit("hiss")
				game.haptic(p, "40")
				game.shake = maxf(game.shake, 0.12)
				p.bark("Still under pressure!", 1.2)
		"open", "close":
			var go_open := op == "open"
			p.cue("action", "open" if go_open else "close", fix_prog)
			if p.action_held():
				fix_prog = minf(1.0, fix_prog + delta / 0.7)
				p.pose_arms(Vector3(-1.7, 0, -0.2), Vector3(-1.7 + 0.5 * fix_prog, 0, 0.2))
				_set_open(c, fix_prog if go_open else 1.0 - fix_prog)
				if fix_prog >= 1.0:
					game.sfx.hit("clank")
					p.bounce()
					game.score.award(p, 5, "Line repairs", c["pos"] + Vector3(0, 0.8, 0))
					game.haptic(p, "60")
					if go_open:
						if job_kind == "clamp":
							# The old clamp comes off into the line hand's pouch
							c["present"] = false
							(c["node"] as Node3D).visible = false
							(c["crust"] as Node3D).visible = true
							_fly_clamp(c["pos"], p)
						grout_spray.position = c["pos"]
						grout_spray.amount = 120
						grout_spray.restart()
						grout_spray.emitting = true
					_advance()
			else:
				fix_prog = maxf(0.0, fix_prog - delta)
				_set_open(c, fix_prog if go_open else 1.0 - fix_prog)
		"clean":
			p.cue("action", "knock grout", 1.0 - float(c["crust_amt"]), true)
			if p.action_pressed():
				c["crust_amt"] = maxf(0.0, c["crust_amt"] - 0.25)
				var cr: Node3D = c["crust"]
				cr.scale = Vector3(1.0, maxf(0.05, c["crust_amt"]), 1.0)
				cr.position = c["pos"]
				chunks.position = c["pos"]
				chunks.restart()
				chunks.emitting = true
				game.sfx.hit("tink")
				game.haptic(p, "25")
				p.pose_arms(Vector3(-1.4, 0, -0.2), Vector3(-2.3, 0, 0.3))
				p.bounce()
				if c["crust_amt"] <= 0.0:
					game.score.award(p, 5, "Line repairs", c["pos"] + Vector3(0, 0.8, 0))
					cr.visible = false
					_advance()
			else:
				p.pose_arms(Vector3(-1.4, 0, -0.2), Vector3(-1.6, 0, 0.3))
		"kit":
			if p.held_kind != "clamp":
				p.cue("!", "need clamp kit", -1.0, true)
				p.say("waiting on a clamp…" if part_coming("clamp", p) else "spares bin ↓")
			else:
				p.cue("action", "fit clamp")
				if p.action_pressed():
					var it: Node3D = p.release_item()
					it.queue_free()
					# Fresh clamp and gasket go on, open, ready to close
					var old: Node3D = c["node"]
					var fresh := _make_clamp(true)
					for key in ["node", "ha", "hb", "pin", "crust", "gasket", "mat"]:
						c[key] = fresh[key]
					old.queue_free()
					(c["node"] as Node3D).position = c["pos"]
					if kit == "truck":
						(c["node"] as Node3D).rotation.z = PI * 0.5
					add_child(c["node"])
					(c["gasket"] as Node3D).visible = true
					c["present"] = true
					c["pinned"] = false
					c["crust_amt"] = 1.0
					_set_open(c, 1.0)
					game.sfx.hit("clank")
					game.haptic(p, "50,30,50")
					game.score.award(p, 10, "Line repairs", c["pos"] + Vector3(0, 0.8, 0))
					p.bounce()
					_advance()
		"lower":
			p.cue("action", "lower old pipe", fix_prog)
			if p.action_held():
				fix_prog = minf(1.0, fix_prog + delta / 0.8)
				p.pose_arms(Vector3(-2.0, 0, -0.3), Vector3(-2.0, 0, 0.3))
				if fix_prog >= 1.0:
					var sec: Dictionary = sections[block_s]
					(sec["node"] as Node3D).visible = false
					var old := make_item("pipe")
					var plug := F.cylinder(0.14, 0.4, F.color_mat(Color("8f949b")), Vector3(1.35, 0, 0), 8)
					plug.rotation.z = PI * 0.5
					old.add_child(plug)
					old.rotation.z = PI * 0.5
					add_child(old)
					var mid: Vector3 = (sec["a"] + sec["b"]) * 0.5
					old.position = mid
					_lowering = {"node": old, "t": 0.0, "from": mid}
					game.sfx.hit("clank")
					game.score.award(p, 10, "Line repairs", mid)
					p.bounce()
					_advance()
		"pipe":
			if p.held_kind != "pipe":
				p.cue("!", "need new pipe", -1.0, true)
				p.say("waiting on a pipe…" if part_coming("pipe", p) else "pipe rack ↓")
			else:
				p.cue("action", "fit pipe")
				if p.action_pressed():
					var it2: Node3D = p.release_item()
					it2.queue_free()
					(sections[block_s]["node"] as Node3D).visible = true
					game.sfx.hit("clank")
					game.haptic(p, "50,30,50")
					game.score.award(p, 15, "Line repairs", c["pos"] + Vector3(0, 0.8, 0))
					p.bounce()
					_advance()
		"pin":
			# The safety pin takes a moment (hold A or X). B skips it to get the
			# line back sooner: that clamp's the next to let go, and it's a
			# safety mark on the report.
			var pin: Node3D = c["pin"]
			var pin_held: bool = p.action_held() or p.alt_held()
			fix_prog = minf(1.0, fix_prog + delta / PIN_T) if pin_held else maxf(0.0, fix_prog - delta)
			p.cue("action", "safety pin in (hold)", fix_prog, true)
			p.cue("leave", "skip the pin")
			if fix_prog >= 1.0:
				c["pinned"] = true
				pin.visible = true
				pin.position.y = 0.0
				game.sfx.hit("tink")
				game.score.award(p, 10, "Safety pins in", c["pos"] + Vector3(0, 0.8, 0))
				p.bounce()
				(c["gasket"] as Node3D).visible = false
				_advance()
			elif p.leave_pressed():
				c["pinned"] = false
				stats["unpinned"] += 1
				game.pop("No safety pin!", c["pos"] + Vector3(0, 0.8, 0), Color("ff4d4d"))
				(c["gasket"] as Node3D).visible = false
				_advance()

	return true

## Someone's off at a chute with the slump tray (the rig stays shown: the
## tray's in their hands).
func _fetching() -> bool:
	var t = needs_check()
	return t != null and slump.step_of(t) == "fetch"

## The readout over a spotted truck's tail while it backs in: the gap to the
## stop line in big type, white, then amber as it creeps, then a flashing
## green STOP when the chute's over the hopper (and red past it). The stop
## line on the ground lights the same.
func _spot_show(t: Dictionary, su: float, in_band: bool, past: bool) -> void:
	var node: Node3D = t["node"]
	var gap := maxf(0.0, (SPOT_BAND.x - su) * SPOT_M)
	var flash := 0.5 + 0.5 * sin(game.phase_t * 18.0)
	var col := Color.WHITE
	if past:
		spot_label.text = "WHOA!"
		col = Color("ff4d4d")
	elif in_band:
		spot_label.text = "STOP!"
		col = Color("4dff88").lerp(Color.WHITE, flash * 0.5)
	elif su >= SPOT_SLOW:
		spot_label.text = "slow… %.1f m" % gap
		col = Color("ffc72c")
	else:
		spot_label.text = "back %.1f m" % gap
	spot_label.modulate = col
	spot_label.scale = Vector3.ONE * (1.25 + 0.1 * flash if in_band else 1.0)
	spot_label.global_position = node.global_transform * Vector3(-5.4, 3.6, 0)
	spot_label.visible = true
	_spot_shown = true
	var m = spot_marks.get(t.get("slot", "A"))
	if m != null:
		(m["mat"] as StandardMaterial3D).albedo_color = col if (in_band or past) else Color("ffc72c")

## The truck bay: wave the next truck back, check the docket, slump test,
## water or reject. With a truck already discharging, the next one backs in
## alongside and gets tested there, ready to go the moment the first is empty.
func _bay(p, delta: float) -> void:
	if not _fetching():
		slump_cone.visible = false
	# Spotting a truck back: hold A to wave it on, let go on the mark
	for tr in trucks:
		if tr.get("spotter") == p and tr["state"] in ["called", "approach"]:
			tr["spot_seen"] = game.phase_t   # (still here, waiting for it to come round)
		if tr["state"] == "back" and tr.get("spotter") == p:
			tr["spot_seen"] = game.phase_t
			tr["spot_hold"] = p.action_held()
			var su: float = tr.get("su", 0.0)
			p.face((tr["node"] as Node3D).position)
			var in_band: bool = su >= SPOT_BAND.x and su <= SPOT_BAND.y
			var past: bool = su > SPOT_BAND.y
			p.cue("action", "LET GO: STOP IT!" if in_band else ("too far!" if past else "hold: wave it back"), su / SPOT_BUMP, true, Vector2(SPOT_BAND.x, SPOT_BAND.y) / SPOT_BUMP, past)
			if not p.bot:
				_spot_show(tr, su, in_band, past)
				if in_band and not bool(tr.get("spot_rang", false)):
					tr["spot_rang"] = true
					game.sfx.hit("ding")
					game.haptic(p, "40")
			if tr["spot_hold"]:
				var w := sin(tr["t"] * 8.0)
				p.pose_arms(Vector3(-2.6 + 0.4 * w, 0, -0.3), Vector3(-2.6 - 0.4 * w, 0, 0.3))
			else:
				p.pose_arms(Vector3(-3.0, 0, -0.9), Vector3(-3.0, 0, 0.9))
			return
	var t = needs_check()
	if t == null:
		if can_wave_in():
			p.cue("action", "wave truck in", -1.0, bay_truck == null or bay_truck["load"] < load_m3 * 0.6)
			# Gold: now's the time, so the next one's on before the hopper runs low
			p.gold(not p.bot and (bay_truck == null or bay_truck["load"] < load_m3 * 0.6))
			if p.action_pressed():
				wave_in(p)
				p.pose_arms(Vector3(-2.8, 0, -0.3), Vector3(-2.8, 0, 0.3))
				p.bounce()
				game.score.award(p, 5, "Trucks waved in")
		elif bay_truck != null and bay_truck["state"] == "back":
			p.face((bay_truck["node"] as Node3D).position)
			p.pose_arms(Vector3(-2.6 + 0.4 * sin(bay_truck["t"] * 8.0), 0, -0.3), Vector3(-2.6 - 0.4 * sin(bay_truck["t"] * 8.0), 0, 0.3))
		elif bay_truck != null and bay_truck["state"] == "pour":
			pass   # (the truck's own label shows what's left)
		return
	p.face((t["node"] as Node3D).position)
	t["tester"] = p
	t["touched"] = game.phase_t
	if t.get("too_old", false):
		# Too old on the docket: the one thing to do is send it back
		p.cue("leave", "too old: send it back", -1.0, true)
		p.gold(true)
		if p.leave_pressed() and p.held == null:
			decide(p, t, "reject")
		return
	if t["state"] == "docket":
		# Not due a test: check the docket against the order (it's on the
		# truck). A pours it, B sends a wrong mix back.
		var ok: bool = right_call(t) == "use"
		p.cue("action", "docket's right: pour it", -1.0, ok)
		p.gold(ok)
		if p.cues.size() < 3:
			p.cues.append(["B", "wrong mix: send it back", -1.0, not ok, Vector2(-1, -1), not ok, false])
		if p.action_pressed():
			decide(p, t, "use")
		elif p.leave_pressed() and p.held == null:
			decide(p, t, "reject")
		return
	if t.get("choice", false) and not t["checked"]:
		if p.bot or p.covering or slump.step_of(t) != "sample" or t.has("trust_m3"):
			t.erase("choice")   # (a bot, or a test already under way: test it)
		else:
			# Test it, or skip the test and take the risk (shown, and it climbs
			# with every load skipped in a row)
			var pct := int(round(skip_risk() * 100.0))
			p.cue("action", "slump test it", -1.0, true)
			p.cue("slow", "skip test · %d%% risk" % pct, -1.0, false, Vector2(-1, -1), pct >= int(SKIP_RISK_MAX * 100.0))
			if not _skip_told:
				_skip_told = true
				game.hud.toast("Test it (A) or skip the test (Y). Every load you skip makes a bad one more likely.", 3.0)
			if p.slow_pressed():
				skip_test(p, t)
				p.bounce()
				return
			if not p.action_pressed():
				return
			t.erase("choice")
	if not t["checked"]:
		# The slump test, by hand, in its own close-up (slump.gd)
		t["state"] = "check"
		var done: bool = slump.work(p, t, delta)
		# A wave to the next driver doesn't stop the test (X): they back in
		# on the free side while you work
		if can_wave_in():
			var hungry: bool = bay_truck == null or bay_truck == t or float(bay_truck["load"]) < load_m3 * 0.85
			p.cue("alt", "wave the next truck in", -1.0, hungry)
			p.gold(not p.bot and hungry)
			if (p.alt_pressed() and not p.bot) or ((p.bot or p.covering) and hungry):
				wave_in()
				game.score.award(p, 5, "Trucks waved in")
		if done:
			t["checked"] = true
			t["state"] = "bay"
			skips = 0
			game.score.award(p, 10, "Slump tests")
			# A bot just uses a good load; a person makes the call
			if p.bot and right_call(t) == "use":
				accept(t)
		return
	slump._show(t)
	if t["state"] != "bay":
		return
	# The call: A uses the load, X adds the water held back, B sends it back.
	# Your reading points the way: in spec, A glows gold; stiff, X runs blue
	# with water; wet or old, B flashes red. (Read the tape wrong and it points
	# the wrong way: it goes on the reading, not the truth.)
	var right := right_call(t)
	p.cue("action", "use it", -1.0, right == "use")
	p.gold(right == "use")
	p.cue("alt", "add water", -1.0, right == "water")
	if right == "water" and slump.says_call(t):
		p.tint(Color("3fa9ff"))
	if p.cues.size() < 3:
		p.cues.append(["B", "send it back", -1.0, right == "reject", Vector2(-1, -1), right == "reject", false])
	if p.action_pressed():
		decide(p, t, "use")
	elif p.alt_pressed():
		decide(p, t, "water")
	elif p.leave_pressed() and p.held == null:
		decide(p, t, "reject")

## Docket help (a setting): the right call on a docket glows, and the docket
## says what's wrong with a load. Always on in the tutorial.
func assist() -> bool:
	return game.tutorial or bool(Settings.value("docket_help"))

## What a good pump operator does with this load.
func right_call(t: Dictionary) -> String:
	# (on what was measured: read the tape wrong and the "right" call is wrong)
	if t.get("mix_wrong", "") != "":
		return "reject"
	if t["age"] > MAX_AGE:
		return "reject"
	var m: float = t.get("measured", t["slump"])
	if m > SPEC_SLUMP + SLUMP_TOL:
		return "reject"
	if m < SPEC_SLUMP - SLUMP_TOL:
		return "reject" if t.get("watered", false) else "water"
	return "use"

## The pump operator's call on a tested load, right or wrong. A wrong call
## plays out later: a weak patch in the slab, a blockage, or a short pour.
func decide(p, t: Dictionary, call: String) -> void:
	var v := _verdict(t)
	var at: Vector3 = (t["node"] as Node3D).position + Vector3(0, 3.5, 0)
	p.bounce()
	match call:
		"use":
			accept(t)
		"reject":
			reject(t)
		"water":
			if t.get("watered", false):
				# The plant only held back so much, and it's all in
				game.pop("That's all the water they held back", at, Color("ff4d4d"))
				game.score.award(p, -5, "Water added past the docket")
				return
			match v:
				"stiff":
					# Within the docket's allowance: the driver adds it and mixes
					_set_truck(t, "water")
					game.score.award(p, 10, "Good loads in")
				"ok":
					# A good load watered down is a wet load now
					t["slump"] = randf_range(160.0, 180.0)
					game.pop("Too much water!", at, Color("ff4d4d"))
					game.score.award(p, -10, "Water added to a good load")
				"wet":
					t["slump"] = minf(230.0, float(t["slump"]) + 20.0)
					game.pop("Even wetter", at, Color("ff4d4d"))
					game.score.award(p, -10, "Water added to a wet load")
				"old":
					game.pop("Water won't save an old load", at, Color("ff4d4d"))
					game.score.award(p, -5, "Water added to an old load")
			game.sfx.hit("plop")

func _panel(p, delta: float) -> void:
	p.face(PUMP_POS)
	# Starting the pump, the slurry and the washout water come first
	if p.role == "pump" and game.ops.panel(p, delta):
		return
	if tripped and repair_pending():
		# Killed on a spike that something on the line set off: fix it first
		p.cue("action", "fix the line first", -1.0, false)
		p.say("%d bar" % int(pressure))
		return
	if tripped:
		# Killed on a spike: hold A to ease it back and start it again
		_restart_t = _restart_t + delta if p.action_held() else maxf(0.0, _restart_t - delta * 2.0)
		p.cue("action", "restart the pump", _restart_t / RESTART_HOLD, true)
		p.gold(not p.bot)
		p.say("%d bar" % int(pressure))
		if _restart_t >= RESTART_HOLD:
			restart(p)
		return
	if _chute_signal(p, delta):
		return
	var want_stroke: bool = live and idle_t > SET_TIME * 0.4 and not line_down()
	if want_stroke:
		# Nothing to drop the pressure for: A strokes the pump instead
		p.cue("action", "stroke", -1.0, true)
		p.gold(not p.bot and idle_t > SET_TIME * 0.6)
		if p.action_pressed():
			game.score.award(p, 5, "Strokes to keep the line moving")
			stroke()
			p.bounce()
		p.say("%d bar" % int(pressure))
		return
	p.say("%d bar" % int(pressure))

## A couple of strokes to keep the concrete in the line moving during a wait.
func stroke() -> void:
	if burst or (fix_i >= 0 and fix_step > 0):
		return
	if hopper < 0.1:
		game.hud.toast("Nothing in the hopper to stroke", 1.2)
		return
	hopper -= 0.1
	idle_t = 0.0
	game.sfx.hit("thunk")

# ------------------------------------------------------------------ NPC pump operator

func human_at_panel() -> bool:
	for p in game.players:
		if p.zone == "ground" and Vector2(p.position.x - 18.6, p.position.z - 8.6).length() < 1.4:
			return true
	return false

func _update_npc(delta: float, in_pour: bool) -> void:
	# The pump operator is always crew now (a person or a bot)
	npc_op.visible = false
	if npc_op != null:
		return
	# The crew's pump operator runs the bay when no player is on the ground,
	# and always steps in to drop the pressure if nobody's at the panel
	var needs_reverse := fix_i >= 0 and _step_name() == "depress" and pressure > SAFE_BAR and not human_at_panel()
	var active := in_pour and (not human_on_ground() or needs_reverse)
	npc_op.visible = active
	if not active:
		return
	_npc_t -= delta
	var goal := Vector3(20.0, 0, 9.2)
	# Drop the pressure for a line hand who needs it
	if needs_reverse:
		goal = Vector3(19.0, 0, 8.8)
		if _npc_t <= 0.0:
			reversing = true
	elif bay_truck == null and _next_queued() != null:
		goal = Vector3(25.2, 0, 9.4)
		if _npc_t <= 0.0:
			wave_in()
			_npc_t = 1.4
	elif bay_truck != null and bay_truck["state"] in ["bay", "check", "docket"]:
		goal = Vector3(25.2, 0, 9.4)
		var t: Dictionary = bay_truck
		if _npc_t <= 0.0:
			if t["state"] == "docket":
				if right_call(t) == "use":
					accept(t)
				else:
					reject(t)
				_npc_t = 1.2
			elif not t["checked"]:
				t["checked"] = true
				_npc_t = 1.6
			else:
				match _verdict(t):
					"ok":
						accept(t)
					"stiff":
						_set_truck(t, "water")
					_:
						reject(t)
				_npc_t = 1.0
	elif bay_truck != null and bay_truck["state"] == "water" and bay_truck["t"] > 2.4:
		bay_truck["slump"] = randf_range(90.0, 110.0)
		if _verdict(bay_truck) == "ok":
			accept(bay_truck)
		else:
			reject(bay_truck)
	elif live and idle_t > SET_TIME * 0.55 and not line_down():
		goal = Vector3(19.0, 0, 8.8)
		if _npc_t <= 0.0:
			stroke()
			_npc_t = 2.0
	else:
		if _npc_t < -0.5:
			_npc_t = 0.0
	npc_op.position = npc_op.position.move_toward(goal, 4.0 * delta)
	var d := goal - npc_op.position
	if d.length() > 0.1:
		npc_op.rotation.y = atan2(d.x, d.z)

## Truck kit: the boom rides on the pump truck, which has a cab and four
## outriggers that have to go out onto pads before the boom unfolds.
func add_truck_boom_body() -> void:
	pump_unit.add_child(F.box(Vector3(2.0, 2.0, 2.3), F.mat("white", true), Vector3(-3.4, 1.9, 0)))
	pump_unit.add_child(F.box(Vector3(0.08, 0.8, 2.0), F.color_mat(Color("5b7fa8")), Vector3(-4.42, 2.4, 0)))
	pump_unit.add_child(F.box(Vector3(9.0, 0.5, 2.3), F.mat("navy"), Vector3(-0.2, 0.75, 0)))
	for c in [Vector3(-3.4, 0, -1), Vector3(-3.4, 0, 1), Vector3(2.4, 0, -1), Vector3(2.4, 0, 1)]:
		var leg := Node3D.new()
		leg.position = Vector3(c.x, 0.9, c.z * 1.0)
		var beam := F.box(Vector3(0.3, 0.3, 1.0), F.mat("yellow_dark"), Vector3(0, 0, 0.5 * c.z))
		beam.name = "Beam"
		leg.add_child(beam)
		var foot := F.box(Vector3(0.25, 0.9, 0.25), F.mat("yellow_dark"), Vector3(0, -0.45, c.z))
		foot.name = "Foot"
		leg.add_child(foot)
		var pad := F.box(Vector3(0.8, 0.08, 0.8), F.color_mat(Color("6b4a2b")), Vector3(0, -0.86, c.z))
		pad.name = "Pad"
		leg.add_child(pad)
		leg.set_meta("side", c.z)
		pump_unit.add_child(leg)
		legs.append(leg)
	set_outriggers([0.0, 0.0, 0.0, 0.0])

func set_outriggers(v: Array) -> void:
	for i in legs.size():
		var u: float = clampf(v[i], 0.0, 1.0)
		var side: float = legs[i].get_meta("side")
		var beam: Node3D = legs[i].get_node("Beam")
		beam.scale.z = 1.0 + 1.6 * u
		beam.position.z = 0.5 * side * beam.scale.z
		var foot: Node3D = legs[i].get_node("Foot")
		foot.position.z = side * (0.6 + 1.6 * u)
		foot.visible = u > 0.5
		var pad: Node3D = legs[i].get_node("Pad")
		pad.position.z = foot.position.z
		pad.visible = u >= 1.0


## What the HUD needs to show about the pump and trucks.
func hud_info() -> Dictionary:
	var q := 0
	var ages: Array = []
	for t in trucks:
		if t["state"] in ["queue", "arrive"]:
			q += 1
			ages.append(t["age"])
	var names := {"called": "pulling up", "approach": "pulling up", "back": "backing in", "bay": "needs a slump test", "check": "slump test, feeding", "water": "adding water", "pour": "discharging", "leave_wait": "pulling out", "leave": "pulling out", "ready": "tested, ready"}
	var bay := ""
	if bay_truck != null:
		bay = names.get(bay_truck["state"], "")
		if bay_truck["state"] == "bay" and bay_truck["checked"]:
			bay = "waiting on a call"
	var stand := ""
	if staged != null:
		stand = names.get(staged["state"], "")
		if staged["state"] == "bay" and staged["checked"]:
			stand = "waiting on a call"
	return {"hopper": hopper / HOPPER_CAP, "startup": game.ops != null and not game.ops.primed, "high": speed_high, "queue": q, "bay": bay, "standby": stand, "next": maxf(0.0, _arrive_t), "ages": ages}

## The gauge close-up wants to be on screen: just before a spike, through it,
## and a moment after (to see the needle drop).
func gauge_popup() -> bool:
	return spike_warn or spike_on or _kill_show_t > 0.0

## Where the gauge close-up camera looks, and from where.
func gauge_target() -> Vector3:
	return gauge_face.global_position

func gauge_eye() -> Vector3:
	return gauge_face.global_position + Vector3(0.15, 0.25, 1.9)
