## Pour Decisions — vertical-slice prototype, Chapter 1: Riverlight, Hamilton Reach.
##
## Pick the kit, then per level: columns and core go up -> formwork deck ->
## (climb the boom every 3 levels with the tower kit; outriggers down with the
## truck boom) -> pre-pour briefing and the engineer's hold point -> pour the
## slab: trucks to the hopper, the pump up the line, the boom over the deck, the
## crew vibrating it, while the line hand keeps the riser sound -> screed, grade
## card, cure -> next level. Eleven levels, then top out.
##
## A crew of five (boom, line hand, pump, poker, screeder). One to four people
## each take a job; bots work the rest through the same controls a person
## uses. Run with `-- --autotest` to watch an all-bot crew play it through.
extends Node3D

const UI := preload("res://scripts/ui.gd")
const PauseScript := preload("res://scripts/pause.gd")
const CoachScript := preload("res://scripts/coach.gd")
const Icons := preload("res://scripts/icons.gd")
const Settings := preload("res://scripts/settings.gd")
const CueBadge := preload("res://scripts/cue_badge.gd")
const SlumpGuide := preload("res://scripts/slump_guide.gd")
const F := preload("res://scripts/factory.gd")
const PlayerScript := preload("res://scripts/player.gd")
const HudScript := preload("res://scripts/hud.gd")
const PourScript := preload("res://scripts/pour.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const ClimbScript := preload("res://scripts/climb.gd")
const LineScript := preload("res://scripts/line.gd")
const PokerScript := preload("res://scripts/poker.gd")
const PhonesScript := preload("res://scripts/phones.gd")
const SelectScript := preload("res://scripts/select.gd")
const CrewScript := preload("res://scripts/crew.gd")
const BotsScript := preload("res://scripts/bots.gd")
const ScoreScript := preload("res://scripts/score.gd")
const SignsScript := preload("res://scripts/signs.gd")
const ScreedScript := preload("res://scripts/screed.gd")
const OpsScript := preload("res://scripts/ops.gd")
const Surrounds := preload("res://scripts/surrounds.gd")

# Riverlight: 11 levels; 10 lattice sections reached a 41.4 m free-stand.
const FLOORS := 11
const FH := 3.0
# The slab this crew pours each level: Riverlight's east wing, 30 x 21.8 m
# (a second crew pours the west wing beside it). Its north-west corner (game
# +x, +z) is set 4 m short of the boom tower, which stands in the notch
# between the two wings, so the street and the tower sit where they always
# have and the wing reaches away from them. The water tower tutorial keeps
# the old 16 x 12 frame centred on the origin.
var BW := 30.0
var BD := 21.8
var SC := Vector3(8.0 - 15.0, 0, 2.0 - 10.9)   # the slab's centre
## Where the game's origin is in the real-world frame Riverlight's map data
## uses (Riverlight's centroid, x west, z north)
const REAL_ORIGIN := Vector3(-15.8, 0, 9.5)
const BIG_SLAB_TRUCKS := 1.35   # trucks come up to this much more often on a big slab
const BIG_SLAB_LOAD := 1.3      # ...carrying up to this much more each
const LS := 4.14
const LW := 2.0
const LAT_X := 12.0
const HEAD_MIN := 4.0
const HEAD_TARGET := 9.5
const SHOULDER := 1.7
const HOSE := 3.0
const COVERAGE_DONE := 0.985  # share of the slab at full depth that counts as poured
const DAY_LIMIT := 220.0      # s on the pour clock before you're past the noise curfew
const BOOM_WIND := 72.0       # km/h gust at which the placing boom has to be parked
const CLIMB_LEVELS := [3, 6, 9]   # climb before pouring levels 4, 7 and 10
const SECTIONS_PER_CLIMB := 2      # 4 starting + 3 climbs x 2 = Riverlight's 10 sections
const HOIST_X := -6.6
var HOIST_Z := 4.4
# The perimeter scaffold: a walkway right round the slab, off the concrete,
# that climbs with the deck. The boom operator works from it and never steps
# on the pad; everyone else can use it to get round without walking through
# fresh concrete.
const WALK_GAP := 0.15        # m between the slab edge and the walkway (the formwork)
const WALK_W := 1.4           # m wide
const WALK_MID := WALK_GAP + WALK_W * 0.5   # centreline, out from the slab edge
const NPC_POKER_R := 1.1

const DECK_STATIONS := {
	"boom": {"pos": Vector3(8.85, 0, 2.85), "label": "BOOM REMOTE", "color": Color("ffc72c")},
	"screed": {"pos": Vector3(-21.2, 0, -18.8), "label": "SCREED", "color": Color("f4f7fa")},
	"ladder": {"pos": Vector3(13.6, 0, 1.6), "label": "LADDER", "color": Color("7cd992")},
	"tag": {"pos": Vector3(8.85, 0, -1.8), "label": "TAG LINE", "color": Color("d9c27a")},
	"dogman": {"pos": Vector3(8.85, 0, 2.85), "label": "DOGMAN", "color": Color("4fa3ff")},
	"rigger": {"pos": Vector3(13.4, 0, -1.6), "label": "RIGGER", "color": Color("ff7a1a")},
	"poker": {"pos": Vector3(1.5, 0, 1.0), "label": "POKER", "color": Color("c49bff")},
	"hoist": {"pos": Vector3(HOIST_X + 1.5, 0, 2.85), "label": "HOIST", "color": Color("9fb3c8")},
	"pinsets": {"pos": Vector3(-3.0, 0, 1.1), "label": "PIN SETS", "color": Color("f4f7fa")},
	"bin": {"pos": Vector3(5.2, 0, 2.85), "label": "BIN", "color": Color("ffc72c")},
	"hose": {"pos": Vector3(0, 0, 0), "label": "END HOSE", "color": Color("2fd3e8")},
}
const GROUND_STATIONS := {
	"bay": {"pos": Vector3(24.6, 0, 10.0), "label": "TRUCK BAY", "color": Color("ffc72c")},
	"panel": {"pos": Vector3(18.6, 0, 8.6), "label": "PUMP PANEL", "color": Color("ff7a1a")},
	"ladder_g": {"pos": Vector3(14.0, 0, 1.9), "label": "LADDER", "color": Color("7cd992")},
	"hoist_g": {"pos": Vector3(HOIST_X + 1.6, 0, 5.8), "label": "HOIST", "color": Color("9fb3c8")},
	"spares": {"pos": Vector3(13.9, 0, 6.2), "label": "CLAMP KITS", "color": Color("4f8dff")},
	"haul": {"pos": Vector3(14.9, 0, 2.6), "label": "HAUL ROPE", "color": Color("d9c27a")},
	"rack": {"pos": Vector3(10.4, 0, 6.6), "label": "PIPES", "color": Color("dce1e6")},
	"rig0": {"pos": Vector3(15.6, 0, 3.6), "label": "OUTRIGGER", "color": Color("ff7a1a")},
	"rig1": {"pos": Vector3(15.6, 0, 8.4), "label": "OUTRIGGER", "color": Color("ff7a1a")},
	"rig2": {"pos": Vector3(21.4, 0, 3.6), "label": "OUTRIGGER", "color": Color("ff7a1a")},
	"rig3": {"pos": Vector3(21.4, 0, 8.4), "label": "OUTRIGGER", "color": Color("ff7a1a")},
	"pins": {"pos": Vector3(12.2, 0, 6.4), "label": "PIN BAGS", "color": Color("ff7a1a")},
	"sling": {"pos": Vector3(1.0, 0, 8.6), "label": "LAYDOWN", "color": Color("ff7a1a")},
	"valve": {"pos": Vector3(16.4, 0, 10.0), "label": "RELEASE VALVE", "color": Color("ff7a1a")},
}
const PLAYER_COLORS := UI.P_COLORS
const ACTION_NAMES := ["Space", "Enter", "A", "A"]
const ALT_NAMES := ["E", "R-Ctrl", "X", "X"]
const LEAVE_NAMES := ["Q", "R-Shift", "B", "B"]
const SLOW_NAMES := ["F", "R-Alt", "RB", "RB"]

var kit := ""
var phase := "roles"
var phase_t := 0.0
var k := 0
var cfg := {}
var autotest := false
var skyline := false
var _frames := 0
var shot_dir := ""          # dev only: `-- --autotest --shots=<dir>` saves screenshots
var _shots_taken := {}
var _shot_wait := 0

var building: Node3D
var podium: Node3D
var hoist_mast: Node3D
var floor_nodes: Array[Node3D] = []
var rig: Node3D
var ground_st: Node3D
var pour
var sfx
var climb
var line
var poker
var screed
var crew
var bots
var score
var signs
var urgent := {}                 # role -> how urgent its most pressing job is (0..2)
var phones
var hud
var selector
var pause_menu
var coach
var shake_on := true
var lattice: Node3D
var section_count := 0
var head: Node3D
var head_deco: Array[Node3D] = []
var yaw_node: Node3D
var arm1: Node3D
var arm2: Node3D
var tip: Node3D
var hose_end: Node3D
var stream: MeshInstance3D
var l1 := 12.0
var l2 := 12.0
var stations := {}
var players: Array = []
var npcs: Array[Node3D] = []      # concreters with pokers
var engineer: Node3D
var defect: Node3D
var defect_fixed := false
var _defect_prog := 0.0
var signed := false
var hoist_cage: Node3D
var rain: CPUParticles3D
var confetti: CPUParticles3D
var flag: Node3D
var camera: Camera3D
var insets: Array = []           # {box, view, cam, label}
var call_marker: Label3D
var _pops: Array[Label3D] = []
var call_t := 0.0
var outriggers := [0.0, 0.0, 0.0, 0.0]
var _rig_npc_t := 0.0

var tip_target := Vector3(3, 0, 0)
var tip_pos := Vector3(3, 0, 0)
var tip_kick := Vector3.ZERO
var pumping := false
var pour_clock := 0.0
var clamp_trigger := 0.5
var clamp_used := false
var shake := 0.0
var work_y := 0.0
var work_target := 0.0
var climb_notes := {"unclipped": 0, "wind": 0}

var cam_yaw := 0.55
var cam_pitch := 0.62
var cam_dist := 32.0
var cam_focus := Vector3(0, 4, 0)
var rmb := false
var _dog_view := false       # camera swung round side-on to the runway while dogging
var _yaw_before := 0.55
var _pitch_before := 0.62

# ------------------------------------------------------------------ setup

func _ready() -> void:
	UI.install_fonts()
	var args := OS.get_cmdline_user_args()
	autotest = args.has("--autotest")
	var want_kit := ""
	for arg in args:
		if arg.begins_with("--shots="):
			shot_dir = arg.substr(8)
		if arg.begins_with("--only="):
			_shot_only = Array(arg.substr(7).split(","))
		if arg.begins_with("--kit="):
			want_kit = arg.substr(6)
		if arg.begins_with("--camtest="):
			Settings.cam_test = clampi(int(arg.substr(10)), 0, Settings.CAM_TESTS.size() - 1)
		if arg == "--nosplit":
			Settings.data["split"] = false
		if arg.begins_with("--cam="):
			_cam_roles = Array(arg.substr(6).split(","))
		if arg.begins_with("--startlevel="):
			_start_level = int(arg.substr(13))
	randomize()
	# World labels get untangled just before each frame's drawn, when
	# everything's where it's going to be
	RenderingServer.frame_pre_draw.connect(_declutter_labels)
	if not autotest:
		Settings.apply_window()
	_setup_input()
	if tutorial or args.has("--oldslab"):
		# (dev `--oldslab`: the old 16 x 12 slab, to compare against)
		_use_tut_frame()
	_build_environment()
	_build_world()
	_build_site()
	hud = HudScript.new()
	add_child(hud)
	hud.visible = false   # (the front end comes first)
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.5      # (the default 5 cm loses the map's ground to the depth buffer this far out)
	camera.far = 16000.0   # the CBD 6.4 km up the river, Mt Coot-tha at 13 km
	add_child(camera)
	sfx = SfxScript.new()
	add_child(sfx)
	if not OS.get_cmdline_user_args().has("--noinset"):
		_build_insets()
	_build_band()
	score = ScoreScript.new()
	add_child(score)
	score.setup(self)
	signs = SignsScript.new()
	add_child(signs)
	signs.setup(self)
	crew = CrewScript.new()
	add_child(crew)
	crew.build(self)
	bots = BotsScript.new()
	add_child(bots)
	bots.setup(self)
	if autotest:
		print("[autotest] started")
		# `--human=<job>`: leave that job to an idle "person", to test the rest
		for arg in args:
			if arg.begins_with("--human="):
				crew.crew[arg.substr(8)].set_driver(crew.human_identity(1, true))
	else:
		crew.crew["boom"].set_driver(crew.human_identity(1, false))
	phones = PhonesScript.new()
	add_child(phones)
	if not args.has("--nophones"):
		phones.start(self)
	pause_menu = PauseScript.new()
	add_child(pause_menu)
	pause_menu.setup(self)
	coach = CoachScript.new()
	add_child(coach)
	coach.setup(self)
	if not autotest:
		PauseScript.apply_ui_scale(get_tree())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--uiscale="):
			# (dev: try the HUD at a given screen-text size)
			get_tree().root.content_scale_factor = a.substr(10).to_float()
	phones.process_mode = Node.PROCESS_MODE_ALWAYS
	selector = SelectScript.new()
	selector.game = self
	add_child(selector)
	selector.chosen.connect(_apply_kit)
	selector.roles_done.connect(func(): _set_phase("select"))
	selector.back_to_crew.connect(func(): _set_phase("roles"))
	if autotest:
		_auto_kit = want_kit if want_kit != "" else "tower"

var _auto_kit := ""
var _start_level := 0   # dev: `--startlevel=N` jumps to level N
var _shot_human := false
var _dbg := OS.get_cmdline_user_args().has("--dbg")
var let_burst := OS.get_cmdline_user_args().has("--letburst")

func _setup_input() -> void:
	var keys := {
		"p1_": {"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S], "action": [KEY_SPACE], "alt": [KEY_E], "slow": [KEY_F], "leave": [KEY_Q]},
		"p2_": {"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN], "action": [KEY_ENTER, KEY_KP_ENTER], "alt": [KEY_CTRL], "slow": [KEY_ALT, KEY_KP_0], "leave": [KEY_SHIFT, KEY_BACKSPACE]},
		"p3_": {"left": [], "right": [], "up": [], "down": [], "action": [], "alt": [], "slow": [], "leave": []},
		"p4_": {"left": [], "right": [], "up": [], "down": [], "action": [], "alt": [], "slow": [], "leave": []},
	}
	var axes := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0], "up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0]}
	var pad := {"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN, "action": JOY_BUTTON_A, "alt": JOY_BUTTON_X, "slow": JOY_BUTTON_RIGHT_SHOULDER, "leave": JOY_BUTTON_B}
	var device := 0
	for prefix in keys:
		var map: Dictionary = keys[prefix]
		for act in map:
			var act_name: String = prefix + act
			if InputMap.has_action(act_name):
				InputMap.erase_action(act_name)
			InputMap.add_action(act_name, 0.3)
			for code in map[act]:
				var ev := InputEventKey.new()
				ev.keycode = code
				InputMap.action_add_event(act_name, ev)
			if axes.has(act):
				var jm := InputEventJoypadMotion.new()
				jm.device = device
				jm.axis = axes[act][0]
				jm.axis_value = axes[act][1]
				InputMap.action_add_event(act_name, jm)
			var jb := InputEventJoypadButton.new()
			jb.device = device
			jb.button_index = pad[act]
			InputMap.action_add_event(act_name, jb)
		device += 1
	for pair in [["skyline", KEY_TAB], ["restart", KEY_R], ["dev_climb", KEY_F1], ["toggle_shake", KEY_F2], ["toggle_sound", KEY_F3]]:
		if InputMap.has_action(pair[0]):
			InputMap.erase_action(pair[0])
		InputMap.add_action(pair[0])
		var e := InputEventKey.new()
		e.keycode = pair[1]
		InputMap.action_add_event(pair[0], e)

var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky_mat = sm
	# A pour-day morning in Brisbane: clear sky, the haze over the river, a
	# high, hard sun from the north-east
	sm.sky_top_color = Color("3a78c9")
	sm.sky_horizon_color = Color("cfdfe8")
	sm.ground_horizon_color = Color("cfdfe8")
	sm.ground_bottom_color = Color("cfdfe8")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.fog_enabled = true
	env.fog_density = 0.00015   # (a light haze: the city 6 km off still shows)
	env.fog_light_color = Color("cfdfe8")
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("fff2df")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	sun.rotation_degrees = Vector3(-42, -24, 0)
	_day_q = sun.quaternion
	add_child(sun)

# ------------------------------------------------------------------ the dawn pour

## Big pours start before sunrise, so the trucks aren't stuck in the morning
## traffic and the slab's in before the heat. Level 8 is one: the first truck
## at 5:10 under the floodlights, the river still black, and the sun comes up
## over Bulimba (east-south-east, across the river) as the slab fills, so the
## sky's the pour clock. `--dawn` makes the start level a dawn pour.
const DAWN_LEVEL := 7
const DAWN_FROM := 5 * 60 + 10   # 5:10 am, in minutes
const DAWN_LEN := 55.0           # ...to 6:05, full morning, over the pour
const SUNRISE_U := 0.5           # 5:38
## [u, sky top, horizon, sun colour, sun energy, ambient, sun elevation (deg)]
const DAWN_KEYS := [
	[0.0, Color("070b1e"), Color("1a2140"), Color("ff8c50"), 0.0, 0.12, -6.0],
	[0.3, Color("162250"), Color("c97a62"), Color("ff8c50"), 0.15, 0.22, 0.0],
	[0.5, Color("2f4f8e"), Color("f0a868"), Color("ffb070"), 0.6, 0.35, 6.0],
	[0.75, Color("3568b0"), Color("e6cdb0"), Color("ffdcb0"), 0.95, 0.5, 20.0],
	[1.0, Color("3a78c9"), Color("cfdfe8"), Color("fff2df"), 1.2, 0.6, 42.0],
]
var _day_u := 1.0
var _day_shown := -1.0
var _day_q := Quaternion.IDENTITY   # the sun's usual morning angle
var _floods: Array = []             # {light, head, deck}
var _floods_on := false
var _dawn_flag := OS.get_cmdline_user_args().has("--dawn")

func is_dawn() -> bool:
	return bool(cfg.get("dawn", false))

## The clock on a dawn pour, as "5:38 AM".
func dawn_clock() -> String:
	var m := DAWN_FROM + int(_day_u * DAWN_LEN)
	return "%d:%02d AM" % [m / 60, m % 60]

func _build_floods() -> void:
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color("fff6dc")
	lamp.emission_enabled = true
	lamp.emission = Color("fff1d0")
	lamp.emission_energy_multiplier = 4.0
	var mast := F.mat("steel")
	# Two on the scaffold at the deck's corners (they climb with it), two on
	# towers over the truck bay and the pump
	var spots := [
		[Vector3(SC.x - BW * 0.5 - 1.2, 0, SC.z + BD * 0.5 + 1.2), true],
		[Vector3(SC.x + BW * 0.5 + 1.2, 0, SC.z - BD * 0.5 - 1.2), true],
		[Vector3(-22.0, 0, 18.0), false],
		[Vector3(12.0, 0, 18.0), false],
	]
	for sp in spots:
		var at: Vector3 = sp[0]
		var deck: bool = sp[1]
		var n := Node3D.new()
		n.position = at
		add_child(n)
		var h := 6.0 if deck else 10.0
		n.add_child(F.box(Vector3(0.18, h, 0.18), mast, Vector3(0, h * 0.5, 0)))
		var head := F.box(Vector3(1.4, 0.7, 0.3), lamp, Vector3(0, h, 0))
		n.add_child(head)
		var l := SpotLight3D.new()
		l.light_color = Color("fff1d6")
		l.light_energy = 7.0
		l.spot_range = 60.0
		l.spot_angle = 58.0
		l.shadow_enabled = false
		l.position = Vector3(0, h + 0.2, 0)
		n.add_child(l)
		var aim: Vector3 = (Vector3(SC.x, 0, SC.z) if deck else Vector3(-4.0, 0, 26.0)) - at
		l.look_at_from_position(l.global_position, l.global_position + Vector3(aim.x, -h * (0.9 if deck else 1.4), aim.z), Vector3.UP)
		head.look_at_from_position(head.global_position, head.global_position + Vector3(aim.x, -h, aim.z), Vector3.UP)
		n.visible = false
		_floods.append({"node": n, "light": l, "deck": deck})

## Lights the world for `u` of the way from 5:10 am (0) to full morning (1).
func _apply_daylight(u: float) -> void:
	if absf(u - _day_shown) < 0.002:
		return
	_day_shown = u
	var i := 0
	while i < DAWN_KEYS.size() - 2 and u > DAWN_KEYS[i + 1][0]:
		i += 1
	var a: Array = DAWN_KEYS[i]
	var b: Array = DAWN_KEYS[i + 1]
	var w := clampf((u - a[0]) / (b[0] - a[0]), 0.0, 1.0)
	var horizon: Color = (a[2] as Color).lerp(b[2], w)
	sky_mat.sky_top_color = (a[1] as Color).lerp(b[1], w)
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = horizon
	env.fog_light_color = horizon
	env.ambient_light_energy = lerpf(a[5], b[5], w)
	sun.light_color = (a[3] as Color).lerp(b[3], w)
	sun.light_energy = lerpf(a[4], b[4], w)
	var elev := deg_to_rad(lerpf(a[6], b[6], w))
	var east := Vector3(-1.0, 0.0, -0.45).normalized()
	var to_sun := east * cos(elev) + Vector3.UP * sin(elev)
	var q := Basis.looking_at(-to_sun, Vector3.UP).get_rotation_quaternion()
	# (from the low dawn sun round to the usual morning one over the last quarter)
	sun.quaternion = q.slerp(_day_q, clampf((u - 0.75) / 0.25, 0.0, 1.0))

func _update_daylight(delta: float) -> void:
	if not is_dawn():
		if _day_u < 1.0:
			_day_u = move_toward(_day_u, 1.0, delta * 0.5)
	else:
		match phase:
			"pour":
				_day_u = maxf(_day_u, minf(1.0, _filled_ratio()))
			"screed", "cure", "topout":
				_day_u = move_toward(_day_u, 1.0, delta * 0.25)
			_:
				_day_u = 0.0
	_apply_daylight(_day_u)
	if pour != null and pour.smat != null:
		pour.smat.set_shader_parameter("low_light", 1.0 - smoothstep(0.35, 0.8, _day_u))
	var want := is_dawn() and _day_u < SUNRISE_U and phase in ["columns", "deck", "inspect", "pour"]
	if want != _floods_on:
		if _floods.is_empty():
			_build_floods()
		_floods_on = want
		for f in _floods:
			(f["node"] as Node3D).visible = want
		if not want and phase == "pour":
			sfx.hit("thunk")
			hud.toast("%s · sun's up over Bulimba. Floodlights off." % dawn_clock(), 3.0)
	if _floods_on:
		for f in _floods:
			if f["deck"]:
				(f["node"] as Node3D).position.y = work_y

# ------------------------------------------------------------------ sign the slab

## The top slab's last wet corner, before it goes off: everyone signs it. A
## square each, one per job: people draw on their phone (or with the stick and
## A on a keyboard or pad, X when done), bots and anyone who doesn't draw leave
## a handprint, and each square gets its name pressed in under it. It stays in
## the roof for the fly-past and the skyline view.
const INK_PX := Vector2i(768, 512)
const INK_SIZE := Vector2(6.0, 4.0)        # m on the slab
const INK_TIME := 35.0                     # s at most
const INK_BOTS := 3.0                      # s for an all-bot crew
const INK_R := 7                           # px, the groove's radius
const INK_ADMIRE := 6.0                   # s on the finished signatures before the report
var _ink_rim: Image                        # the light edge each groove throws up
var _ink_cut: Image                        # the groove itself
var _ink_img: Image
var _ink_tex: ImageTexture
var _ink_node: Node3D
var _ink_dirty := false
var _ink_last := {}                        # player -> last point (cell 0..1), or absent
var _ink_drew := {}                        # player -> they've drawn something
var _ink_done := {}                        # player -> said they're finished
var _ink_cursor := {}                      # player -> cursor for stick drawing (cell 0..1)
var _ink_marks := {}                       # player -> MeshInstance3D, the stick cursor
var _ink_saved := []                       # [cam_pitch, cam_yaw] before the close-up
var _ink_signers: Array = []               # the people signing (never the bots), in square order
var _ink_sealed := -1.0                    # phase_t when it was pressed in, or -1

func ink_centre() -> Vector3:
	# (the front corner away from the boom tower, clear of the end hose
	# where the boom rests)
	return Vector3(SC.x - BW * 0.5 + INK_SIZE.x * 0.5 + 2.0, floors() * FH + 0.07, SC.z + BD * 0.5 - INK_SIZE.y * 0.5 - 1.0)

func ink_left() -> float:
	return maxf(0.0, (INK_BOTS if crew.humans().is_empty() else INK_TIME) - phase_t) if phase == "sign" and _ink_sealed < 0.0 else 0.0

## Each signer's square: up to three to a row, as big as fits, rows centred
## (one person gets one big square in the middle).
func _ink_cell(p) -> Rect2i:
	var i := _ink_signers.find(p)
	var n := maxi(1, _ink_signers.size())
	var cols := mini(n, 3)
	var rows := (n + 2) / 3
	var sz := mini(INK_PX.x / cols, INK_PX.y / rows)
	var in_row := cols if i / 3 < rows - 1 else n - (rows - 1) * 3
	var x0 := (INK_PX.x - sz * in_row) / 2
	var y0 := (INK_PX.y - sz * rows) / 2
	return Rect2i(x0 + (i % 3) * sz, y0 + (i / 3) * sz, sz, sz)

func _start_sign() -> void:
	# Only the people playing sign it. No one playing, no signing.
	_ink_signers = []
	for p in humans():
		if not p.bot:
			_ink_signers.append(p)
	if _ink_signers.is_empty() and autotest and shot_dir != "":
		_ink_signers = [crew.crew["boom"]]   # (dev: a stand-in, so a screenshot shows a drawing)
	if _ink_signers.is_empty():
		_finish_screed()
		return
	_ink_sealed = -1.0
	_ink_rim = Image.create(INK_PX.x, INK_PX.y, false, Image.FORMAT_RGBA8)
	_ink_cut = Image.create(INK_PX.x, INK_PX.y, false, Image.FORMAT_RGBA8)
	_ink_img = Image.create(INK_PX.x, INK_PX.y, false, Image.FORMAT_RGBA8)
	_ink_tex = ImageTexture.create_from_image(_ink_img)
	_ink_node = Node3D.new()
	_ink_node.position = ink_centre()
	building.add_child(_ink_node)
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = INK_SIZE
	q.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = _ink_tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	q.material_override = m
	_ink_node.add_child(q)
	# Each square's name, pressed in along its bottom edge
	for p in _ink_signers:
		var cell := _ink_cell(p)
		var lab := Label3D.new()
		lab.text = String(p.char_name).to_upper()
		lab.font_size = 64 if cell.size.x <= 256 else 96
		lab.pixel_size = 0.004
		lab.modulate = Color("5f5a52")
		lab.outline_size = 0
		lab.rotation_degrees = Vector3(-90, 0, 0)
		var cx := (cell.position.x + cell.size.x * 0.5) / float(INK_PX.x) - 0.5
		var cz := (cell.position.y + cell.size.y * 0.9) / float(INK_PX.y) - 0.5
		lab.position = Vector3(cx * INK_SIZE.x, 0.01, cz * INK_SIZE.y)
		_ink_node.add_child(lab)
	_ink_last = {}
	_ink_drew = {}
	_ink_done = {}
	_ink_cursor = {}
	for p in players:
		if p.bot:
			_ink_done[p] = true
	_ink_saved = [cam_pitch, cam_yaw]
	# (the slab report comes up once it's signed)
	hud.card_away = true
	hud.toast("Sign the slab! Draw on your phone (keyboard: stick and A, X when done)", 4.0)
	sfx.hit("chime")
	_set_phase("sign")

## A point of someone's drawing, 0..1 across their square (as the phone's
## square), into the part of it above the name.
func _ink_map(at: Vector2) -> Vector2:
	return Vector2(0.04 + clampf(at.x, 0.0, 1.0) * 0.92, 0.04 + clampf(at.y, 0.0, 1.0) * 0.8)

## A point of someone's drawing, `at` 0..1 across their square.
func ink_point(p, at: Vector2) -> void:
	if phase != "sign" or p == null or _ink_done.get(p, false) or not _ink_signers.has(p):
		return
	var cell := _ink_cell(p)
	at = _ink_map(at)
	var px := Vector2(cell.position) + at * Vector2(cell.size)
	var last = _ink_last.get(p)
	if last == null:
		_ink_stamp(px)
	else:
		var a: Vector2 = Vector2(cell.position) + (last as Vector2) * Vector2(cell.size)
		var n := maxi(1, int(a.distance_to(px) / 2.0))
		for i in n:
			_ink_stamp(a.lerp(px, float(i + 1) / n))
	_ink_last[p] = at
	_ink_drew[p] = true

func ink_up(p) -> void:
	_ink_last.erase(p)

func ink_clear(p) -> void:
	if phase != "sign" or p == null or _ink_done.get(p, false) or not _ink_signers.has(p):
		return
	var cell := _ink_cell(p)
	_ink_rim.fill_rect(cell, Color(0, 0, 0, 0))
	_ink_cut.fill_rect(cell, Color(0, 0, 0, 0))
	_ink_last.erase(p)
	_ink_drew.erase(p)
	_ink_dirty = true

func ink_done(p) -> void:
	if phase == "sign" and p != null:
		_ink_done[p] = true
		_ink_last.erase(p)

## One dab of the groove: a light rim thrown up down-right, the cut darker.
func _ink_stamp(c: Vector2) -> void:
	var r := INK_R
	for dy in range(-r - 2, r + 3):
		for dx in range(-r - 2, r + 3):
			var x := int(c.x) + dx
			var y := int(c.y) + dy
			if x < 0 or y < 0 or x >= INK_PX.x or y >= INK_PX.y:
				continue
			var d := Vector2(dx, dy).length()
			if d <= r - 1:
				_ink_cut.set_pixel(x, y, Color(0.36, 0.34, 0.31, 0.92))
			var dr := Vector2(dx - 2, dy - 2).length()
			if dr <= r:
				_ink_rim.set_pixel(x, y, Color(0.80, 0.78, 0.74, 0.85))
	_ink_dirty = true

## A handprint in the middle of someone's square.
func _ink_hand(p) -> void:
	var cell := _ink_cell(p)
	var c := Vector2(cell.position) + Vector2(cell.size) * Vector2(0.5, 0.5)
	var rot := randf_range(-0.4, 0.4)
	var parts := [[Vector2(0, 18), Vector2(34, 40)], [Vector2(-34, -38), Vector2(8, 22)], [Vector2(-13, -52), Vector2(8, 24)],
		[Vector2(10, -53), Vector2(8, 24)], [Vector2(31, -42), Vector2(7, 20)], [Vector2(48, 8), Vector2(7, 18)]]
	for part in parts:
		var at: Vector2 = c + (part[0] as Vector2).rotated(rot)
		var rr: Vector2 = part[1]
		var step := 6.0
		var y := -rr.y
		while y <= rr.y:
			var x := -rr.x
			while x <= rr.x:
				if (x * x) / (rr.x * rr.x) + (y * y) / (rr.y * rr.y) <= 1.0:
					_ink_stamp(at + Vector2(x, y).rotated(rot))
				x += step
			y += step

func _update_sign(delta: float) -> void:
	# Close in over the square, looking down on it
	cam_pitch = lerpf(cam_pitch, 1.05, minf(1.0, delta * 2.0))
	# Pressed in: a few seconds to take it in before the report comes back
	if _ink_sealed >= 0.0:
		var held := phase_t - _ink_sealed
		if held > (INK_ADMIRE if not crew.humans().is_empty() else 1.0) or (_human_a and held > 1.5):
			_end_sign()
		return
	if autotest and shot_dir != "":
		# (dev: the boom bot "draws" a star, so a screenshot shows a drawing
		# beside the handprints)
		var pb = crew.crew["boom"]
		var u := clampf(phase_t / 2.0, 0.0, 1.0)
		var pts: Array = []
		for i in 6:
			var a := -PI * 0.5 + i * TAU * 2.0 / 5.0
			pts.append(Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.42)
		var at: float = u * 5.0
		var seg := mini(4, int(at))
		_ink_done[pb] = false
		ink_point(pb, (pts[seg] as Vector2).lerp(pts[seg + 1], at - seg))
		_ink_done[pb] = true
	# Stick drawing for everyone not on a phone
	for p in humans():
		if p.remote_id >= 0 or _ink_done.get(p, false):
			if _ink_marks.has(p):
				(_ink_marks[p] as Node3D).visible = false
			continue
		var cur: Vector2 = _ink_cursor.get(p, Vector2(0.5, 0.5))
		var mv: Vector2 = p.move_input()
		cur = (cur + mv * delta * 0.6).clamp(Vector2.ZERO, Vector2.ONE)
		_ink_cursor[p] = cur
		if p.action_held():
			ink_point(p, cur)
		else:
			ink_up(p)
		if p.alt_pressed():
			ink_done(p)
		if not _ink_marks.has(p):
			var mk := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.09
			sm.height = 0.18
			mk.mesh = sm
			mk.material_override = F.color_mat(p.tag_color)
			_ink_node.add_child(mk)
			_ink_marks[p] = mk
		var cell := _ink_cell(p)
		var uv := (Vector2(cell.position) + _ink_map(cur) * Vector2(cell.size)) / Vector2(INK_PX)
		(_ink_marks[p] as Node3D).visible = true
		(_ink_marks[p] as Node3D).position = Vector3((uv.x - 0.5) * INK_SIZE.x, 0.08, (uv.y - 0.5) * INK_SIZE.y)
		p.cue("A", "Draw", -1.0, false)
		p.cue("X", "Done", -1.0, false)
	var all_done := true
	for p in humans():
		if not _ink_done.get(p, false):
			all_done = false
	if all_done and phase_t > (INK_BOTS if crew.humans().is_empty() else 1.0) or ink_left() <= 0.0:
		_seal_sign()
	if _ink_dirty:
		_ink_dirty = false
		_ink_img.copy_from(_ink_rim)
		_ink_img.blend_rect(_ink_cut, Rect2i(Vector2i.ZERO, INK_PX), Vector2i.ZERO)
		_ink_tex.update(_ink_img)

## Everyone's in (or time's up): a handprint for anyone who didn't draw,
## then it holds on the finished square for a moment.
func _seal_sign() -> void:
	for p in _ink_signers:
		if not _ink_drew.get(p, false):
			_ink_hand(p)
		_ink_done[p] = true
		_ink_last.erase(p)
	for p in _ink_marks:
		(_ink_marks[p] as Node3D).queue_free()
	_ink_marks = {}
	_ink_img.copy_from(_ink_rim)
	_ink_img.blend_rect(_ink_cut, Rect2i(Vector2i.ZERO, INK_PX), Vector2i.ZERO)
	_ink_tex.update(_ink_img)
	_ink_sealed = phase_t
	sfx.hit("chime")
	hud.toast("Signed. That's up there as long as Riverlight stands.", INK_ADMIRE - 0.5)

func _end_sign() -> void:
	if not _ink_saved.is_empty():
		cam_pitch = _ink_saved[0]
	hud.card_away = false
	sfx.hit("ding")
	_finish_screed()

## The screed's done: the slab goes off and the report comes up.
func _finish_screed() -> void:
	_lock_slab(k)
	pour.visible = false
	sfx.hit("ding")
	_set_phase("cure")

# ------------------------------------------------------------------ the fly-past

## Topped out: a CityCat comes down the river past Riverlight, the camera
## rides behind it, then lifts off the water, up the tower to the signed
## corner of the roof. Any A skips it.
const FLY_T := 24.0                        # (lands on the signatures at 18 s, then holds there)
## [s, camera (surroundings frame: from Riverlight's middle, x west, z north)]
## (the first two ride behind the boat and out on the river side, so it's
## in the shot, between the camera and the tower)
const FLY_BOAT := Vector3(420, 0, -400)    # where the boat starts, going downstream at 12 m/s
const FLY_KEYS := [[0.0, Vector3(445, 9, -422)], [6.0, Vector3(373, 9, -422)], [10.0, Vector3(170, 20, -300)],
	[14.0, Vector3(50, 42, -95)], [18.0, Vector3(0, 0, 0)]]
var _fly_on := false
var _fly_t := 0.0
var _fly_boat: Node3D
var _topout_text := ""

func _start_fly() -> void:
	_fly_on = true
	_fly_t = 0.0
	_fly_boat = Node3D.new()
	var navy := F.mat("citycat_blue")
	for z in [-2.6, 2.6]:
		_fly_boat.add_child(F.box(Vector3(25, 1.6, 1.8), navy, Vector3(0, 0.6, z)))
	_fly_boat.add_child(F.box(Vector3(24, 1.4, 7.0), F.mat("white"), Vector3(0, 1.9, 0)))
	_fly_boat.add_child(F.box(Vector3(18, 1.3, 6.4), F.color_mat(Color("2a3a48")), Vector3(-1.0, 3.2, 0)))
	_fly_boat.add_child(F.box(Vector3(19, 0.35, 6.8), F.mat("white"), Vector3(-1.0, 4.0, 0)))
	_fly_boat.add_child(F.box(Vector3(24.2, 0.4, 7.05), navy, Vector3(0, 2.3, 0)))
	# (heading downstream, east: -x)
	_fly_boat.rotation.y = PI
	add_child(_fly_boat)
	hud.toast("Topped out! Press A to skip", 3.0)

func _fly_point(t: float) -> Vector3:
	var keys: Array = FLY_KEYS.duplicate(true)
	keys[keys.size() - 1][1] = ink_centre() + REAL_ORIGIN + Vector3(-2.5, 10.0, 7.0)
	var i := 0
	while i < keys.size() - 2 and t > keys[i + 1][0]:
		i += 1
	var u := clampf((t - keys[i][0]) / (keys[i + 1][0] - keys[i][0]), 0.0, 1.0)
	var p0: Vector3 = keys[maxi(0, i - 1)][1]
	var p1: Vector3 = keys[i][1]
	var p2: Vector3 = keys[i + 1][1]
	var p3: Vector3 = keys[mini(keys.size() - 1, i + 2)][1]
	# (Catmull-Rom, so it never stops dead at a key)
	var u2 := u * u
	var u3 := u2 * u
	return -REAL_ORIGIN + 0.5 * (2.0 * p1 + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * u3)

func _update_fly(delta: float) -> void:
	_fly_t += delta
	if _fly_boat != null:
		_fly_boat.position = -REAL_ORIGIN + FLY_BOAT + Vector3(-12.0 * _fly_t, 0.0, 0.0)
	if _fly_t >= 17.5 and _fly_t - delta < 17.5 and not _ink_signers.is_empty() and _ink_node != null:
		var names: Array = []
		for p in _ink_signers:
			names.append(String(p.char_name))
		hud.toast("Signed by " + ", ".join(names), FLY_T - 17.5)
	if _fly_t >= FLY_T or (_human_a and _fly_t > 0.5):
		_end_fly()

func _fly_camera() -> void:
	camera.position = _fly_point(_fly_t)
	var tower := -REAL_ORIGIN + Vector3(0, floors() * FH * 0.7, 0)
	var look := tower.lerp(ink_centre(), smoothstep(12.0, 17.0, _fly_t))
	camera.look_at(look, Vector3.UP)

func _end_fly() -> void:
	_fly_on = false
	if _fly_boat != null:
		_fly_boat.queue_free()
		_fly_boat = null
	skyline = true
	hud.show_topout(_topout_text)

func _build_world() -> void:
	# The real place: the river, the park, the neighbours, Bulimba over the
	# water, the CBD and the Gateway Bridge (scripts/surrounds.gd)
	var world := Node3D.new()
	world.name = "Surrounds"
	world.position = -REAL_ORIGIN
	add_child(world)
	Surrounds.build(world)
	# Site hardstand around the pump and truck bay, north of the west wing,
	# and into the notch at the boom tower's foot
	var hard := F.color_mat(Color("8f908c"))
	add_child(F.box(Vector3(26.5, 0.06, 11.3), hard, Vector3(21.75, 0.03, 7.35), false))
	add_child(F.box(Vector3(5.9, 0.06, 2.9), hard, Vector3(11.35, 0.03, 0.25), false))
	# Wet slurry under the hopper and the chutes, a wash-out run to the
	# settling tank, tyre tracks down the truck lane and a kerb on the street
	var wet := F.color_mat(Color("6f7275"))
	for at in [Vector3(22.3, 0, 6.0), Vector3(25.6, 0, 4.4), Vector3(25.6, 0, 7.6)]:
		var patch := F.cylinder(1.6, 0.012, wet, at + Vector3(0, 0.079, 0), 16)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(patch)
	add_child(F.box(Vector3(5.0, 0.012, 0.7), wet, Vector3(17.0, 0.079, 7.6), false))
	var track := F.color_mat(Color("7c7e7b"))
	for z in [3.6, 5.2, 6.8, 8.4]:
		add_child(F.box(Vector3(11.0, 0.01, 0.45), track, Vector3(29.5, 0.065, z), false))
	add_child(F.box(Vector3(26.5, 0.15, 0.3), F.color_mat(Color("c8c4ba")), Vector3(21.75, 0.075, 13.05), false))

	rain = CPUParticles3D.new()
	rain.amount = 700
	rain.lifetime = 0.9
	rain.emitting = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(30, 0.5, 26)
	rain.direction = Vector3(0.15, -1, 0)
	rain.spread = 4.0
	rain.initial_velocity_min = 18.0
	rain.initial_velocity_max = 22.0
	rain.gravity = Vector3(0, -10, 0)
	var rm := BoxMesh.new()
	rm.size = Vector3(0.02, 0.5, 0.02)
	rm.material = F.flat_mat(Color(0.75, 0.82, 0.92, 0.6))
	rain.mesh = rm
	add_child(rain)

## The water tower tutorial: a short, guided job on a round concrete water
## tower instead of Riverlight. Its shaft has already been cast in lifts with
## jump forms; the crew pumps the tank floor at the top, climbs the boom one
## section, and pumps the roof slab over the tank walls.
var tutorial := OS.get_cmdline_user_args().has("--tutorial")
const TUT_FIRST := 2          # the shaft's first lifts are already up; this level's the cone and tank floor
const TUT_LAST := 3           # the tank wall and its roof slab
const TUT_R := 5.8            # radius of the tank floor and roof slabs
const SHAFT_R := 3.0
var _rect_rails: Array = []
var _tut_nodes: Array = []

## Deck stations sit a little further in on the round slab.
const TUT_DECK := {
	"boom": Vector3(4.57, 0, 4.84), "screed": Vector3(-4.0, 0, -3.4), "dogman": Vector3(4.57, 0, 4.84),
	"poker": Vector3(1.5, 0, 4.0), "hoist": Vector3(-5.9, 0, 4.6), "pinsets": Vector3(-2.6, 0, 4.6),
	"bin": Vector3(3.33, 0, -5.76), "tag": Vector3(8.85, 0, 4.0),
}
## ...and the hoist stands off the tank on the street.
const TUT_HOIST_Z := 8.4

func deck_pos(key: String) -> Vector3:
	if tutorial and TUT_DECK.has(key):
		return TUT_DECK[key]
	return DECK_STATIONS[key]["pos"]

func floors() -> int:
	return TUT_LAST + 1 if tutorial else FLOORS

func climb_levels() -> Array:
	return [TUT_LAST] if tutorial else CLIMB_LEVELS

func sections_per_climb() -> int:
	return 1 if tutorial else SECTIONS_PER_CLIMB

## The water tower keeps the old frame: a 16 x 12 grid round the origin, the
## hoist out on the street.
func _use_tut_frame() -> void:
	BW = 16.0
	BD = 12.0
	SC = Vector3.ZERO
	HOIST_Z = TUT_HOIST_Z
	if pour == null:
		return
	# (the site's already up for Riverlight: move it across)
	remove_child(pour)
	pour.queue_free()
	_make_pour()
	podium.position = Vector3(0, -0.49, 0)
	hoist_mast.position.z = HOIST_Z
	hoist_cage.position.z = HOIST_Z
	(stations["hoist_g"]["node"] as Node3D).position.z = HOIST_Z + 1.4

## Turns the site into the water tower: round rails, the walkway run in to
## the round deck, a round slab.
func _tut_site() -> void:
	for r in _rect_rails:
		r.visible = false
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color("ff7a1a")
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rr := TUT_R + WALK_GAP + WALK_W
	# The scaffold ring: grating round the slab, rails on its outside
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ri := TUT_R + WALK_GAP
	for k in 64:
		var a0 := TAU * k / 64.0
		var a1 := TAU * (k + 1) / 64.0
		var v := [Vector3(cos(a0) * ri, 0, sin(a0) * ri), Vector3(cos(a0) * rr, 0, sin(a0) * rr), Vector3(cos(a1) * rr, 0, sin(a1) * rr), Vector3(cos(a1) * ri, 0, sin(a1) * ri)]
		for q in [v[0], v[1], v[2], v[0], v[2], v[3]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(q)
	var deck_ring := MeshInstance3D.new()
	deck_ring.mesh = st.commit()
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("8d969e")
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	deck_ring.material_override = gm
	deck_ring.position.y = 0.005
	rig.add_child(deck_ring)
	for y in [0.55, 1.08]:
		var ring := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = rr
		rm.bottom_radius = rr
		rm.height = 0.08
		rm.radial_segments = 56
		rm.cap_top = false
		rm.cap_bottom = false
		ring.mesh = rm
		ring.material_override = ring_mat
		ring.position.y = y
		rig.add_child(ring)
	for a in 20:
		var ang := TAU * a / 20.0
		rig.add_child(F.box(Vector3(0.08, 1.1, 0.08), F.mat("orange"), Vector3(cos(ang) * rr, 0.55, sin(ang) * rr)))
		rig.add_child(F.box(Vector3(0.06, FH, 0.06), F.mat("steel"), Vector3(cos(ang) * rr, -FH * 0.5, sin(ang) * rr)))
	# The walkway out to the boom tower starts at the deck's edge
	rig.add_child(F.box(Vector3(1.8, 0.12, 2.2), F.mat("steel"), Vector3(6.6, -0.06, 0)))
	# A landing from the hoist onto the deck
	rig.add_child(F.box(Vector3(3.7, 0.12, 4.2), F.mat("steel"), Vector3(-5.25, -0.06, 5.5)))
	pour.set_round(TUT_R)
	screed.rack_local = Vector3(-4.0, 0, -3.4)

func _build_site() -> void:
	podium = F.box(Vector3(BW + 10, 1.0, BD + 10), F.mat("podium"), Vector3(SC.x, -0.49, SC.z))
	add_child(podium)
	building = Node3D.new()
	add_child(building)

	rig = Node3D.new()
	add_child(rig)
	_build_walkway()
	var grate := F.mat("steel")
	rig.add_child(F.box(Vector3(3.6, 0.12, 2.2), grate, Vector3(9.3, -0.06, 0)))
	rig.add_child(F.box(Vector3(3.7, 0.12, 4.8), grate, Vector3(12.45, -0.06, 0)))
	ground_st = Node3D.new()
	add_child(ground_st)
	for key in DECK_STATIONS:
		var def: Dictionary = DECK_STATIONS[key].duplicate()
		def["pos"] = deck_pos(key)
		_make_station(key, def, rig, "deck")
	for key in GROUND_STATIONS:
		_make_station(key, GROUND_STATIONS[key], ground_st, "ground")
	(stations["hoist_g"]["node"] as Node3D).position.z = HOIST_Z + 1.4

	# Formwork deck, rebar and the concrete heightfield
	_make_pour()

	lattice = Node3D.new()
	lattice.position = Vector3(LAT_X, 0, 0)
	add_child(lattice)

	head = Node3D.new()
	head.position.x = LAT_X
	add_child(head)
	head_deco.append(F.box(Vector3(3.8, 0.2, 3.8), F.mat("yellow_dark"), Vector3(0, 0.1, 0)))
	for rp in [[Vector3(0, 1.05, 1.85), Vector3(3.8, 0.08, 0.08)], [Vector3(0, 1.05, -1.85), Vector3(3.8, 0.08, 0.08)], [Vector3(1.85, 1.05, 0), Vector3(0.08, 0.08, 3.8)], [Vector3(-1.85, 1.05, 0), Vector3(0.08, 0.08, 3.8)]]:
		head_deco.append(F.box(rp[1], F.mat("orange"), rp[0]))
	for d in head_deco:
		head.add_child(d)
	yaw_node = Node3D.new()
	head.add_child(yaw_node)
	yaw_node.add_child(F.box(Vector3(2.2, 1.3, 2.2), F.mat("yellow", true), Vector3(0, 0.85, 0)))
	for side in [1.0, -1.0]:
		var scp := Label3D.new()
		scp.text = Settings.brand("pumper")
		scp.add_to_group("brand_pumper")
		scp.font_size = 96
		scp.pixel_size = 0.009
		scp.modulate = Color("0f1b2d")
		scp.outline_size = 0
		scp.position = Vector3(0, 0.85, 1.12 * side)
		if side < 0:
			scp.rotation.y = PI
		yaw_node.add_child(scp)

	stream = F.cylinder(0.2, 1.0, F.color_mat(Color("6c6f73")), Vector3.ZERO, 10)
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stream)

	# Concreters on the deck, each with a poker vibrator
	for i in 2:
		var n := F.chibi(Color("ff7a1a"), Color("f4f7fa"))
		var poker := Node3D.new()
		poker.add_child(F.beam(Vector3(0, 0, 0), Vector3(0, -0.6, 0.9), 0.05, F.mat("hose")))
		poker.add_child(F.cylinder(0.05, 0.5, F.mat("steel"), Vector3(0, -0.85, 1.0), 6))
		poker.position = Vector3(0.36, 0.55, 0.2)
		n.add_child(poker)
		n.scale = Vector3.ONE * 1.05
		n.set_meta("goal", Vector3.ZERO)
		add_child(n)
		npcs.append(n)
	engineer = F.chibi(Color("f4f7fa"), Color("4fa3ff"))
	engineer.add_child(F.box(Vector3(0.3, 0.4, 0.04), F.mat("navy"), Vector3(0.2, 0.75, 0.32)))
	engineer.visible = false
	add_child(engineer)
	defect = Node3D.new()
	var red := F.mat("red", true)
	var x1 := F.box(Vector3(1.2, 0.08, 0.16), red)
	x1.rotation.y = PI * 0.25
	var x2 := F.box(Vector3(1.2, 0.08, 0.16), red)
	x2.rotation.y = -PI * 0.25
	defect.add_child(x1)
	defect.add_child(x2)
	var dl := F.label3d("MISSING BAR CHAIR", 38, Color("ff4d4d"))
	dl.position.y = 1.2
	defect.add_child(dl)
	defect.visible = false
	add_child(defect)
	call_marker = F.label3d("▼ BOOM HERE", 44, Color("c49bff"))
	call_marker.visible = false
	add_child(call_marker)

	# Builder's hoist on the south face: the quick way between deck and ground
	# (built 1 m tall and stretched to just above the deck as the building
	# climbs: _update_see_through)
	hoist_mast = F.box(Vector3(0.5, 1.0, 0.5), F.mat("steel"), Vector3(HOIST_X - 1.0, 0.5, HOIST_Z))
	add_child(hoist_mast)
	hoist_cage = Node3D.new()
	hoist_cage.add_child(F.box(Vector3(1.6, 0.1, 1.6), F.mat("navy"), Vector3(0, 0.05, 0)))
	for cx in [-0.78, 0.78]:
		for cz in [-0.78, 0.78]:
			hoist_cage.add_child(F.box(Vector3(0.06, 2.3, 0.06), F.mat("yellow_dark"), Vector3(cx, 1.15, cz)))
	hoist_cage.add_child(F.box(Vector3(1.6, 0.1, 1.6), F.mat("navy"), Vector3(0, 2.3, 0)))
	hoist_cage.position = Vector3(HOIST_X, 0, HOIST_Z)
	add_child(hoist_cage)

	confetti = CPUParticles3D.new()
	confetti.emitting = false
	confetti.one_shot = true
	confetti.amount = 400
	confetti.lifetime = 5.0
	confetti.explosiveness = 0.85
	confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	confetti.emission_sphere_radius = 2.0
	confetti.direction = Vector3(0, 1, 0)
	confetti.spread = 55.0
	confetti.initial_velocity_min = 9.0
	confetti.initial_velocity_max = 17.0
	confetti.gravity = Vector3(0, -5, 0)
	var cmesh := BoxMesh.new()
	cmesh.size = Vector3(0.22, 0.04, 0.3)
	var cmat := StandardMaterial3D.new()
	cmat.vertex_color_use_as_albedo = true
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmesh.material = cmat
	confetti.mesh = cmesh
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	grad.colors = PackedColorArray([Color("ffc72c"), Color("ff7a1a"), Color("ffffff"), Color("4fa3ff")])
	confetti.color_initial_ramp = grad
	add_child(confetti)

	flag = Node3D.new()
	flag.add_child(F.cylinder(0.07, 4.5, F.mat("white"), Vector3(0, 2.25, 0), 8))
	flag.add_child(F.box(Vector3(0.05, 1.2, 2.0), F.mat("orange", true), Vector3(0, 3.9, 1.0)))
	flag.visible = false
	add_child(flag)

	# Starting tower: enough sections to clear level 1
	section_count = 0
	while section_count * LS < FH + HEAD_TARGET:
		_add_section()
	head.position.y = section_count * LS

	climb = ClimbScript.new()
	add_child(climb)
	climb.build(self)
	climb.finished.connect(_on_climb_done)

## Which job works at each station: its spot and name are in that job's colour.
const STATION_ROLE := {"boom": "boom", "dogman": "boom", "screed": "screed", "poker": "poker", "tag": "poker",
	"rigger": "pump", "ladder": "pump", "ladder_g": "pump", "pinsets": "line", "bay": "line", "panel": "pump",
	"spares": "pump", "haul": "line", "rack": "pump", "rig0": "pump", "rig1": "pump", "rig2": "pump",
	"rig3": "pump", "pins": "line", "sling": "line", "bin": "boom", "hose": "hose", "valve": "pump"}

func _make_station(key: String, def: Dictionary, parent: Node3D, zone: String) -> void:
	if STATION_ROLE.has(key):
		def = def.duplicate()
		def["color"] = UI.ROLE.get(STATION_ROLE[key], def["color"])
	var node := Node3D.new()
	node.position = def["pos"]
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.95
	cm.bottom_radius = 0.95
	cm.height = 0.04
	ring.mesh = cm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var dcol: Color = def["color"]
	rm.albedo_color = Color(dcol, 0.55)
	ring.material_override = rm
	# On the deck the spot sits just over the concrete, so the slab and the
	# rebar never hide it; on the street it's on the ground
	ring.position.y = 0.5 if zone == "deck" else 0.06
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.layers = 4   # (left out of the close-up cameras)
	node.add_child(ring)
	# ...and a faint copy that shows through whatever's in front of it (a
	# truck, a crowd), so it's never lost, while people still stand on it
	var xray := MeshInstance3D.new()
	xray.mesh = cm
	var xm := StandardMaterial3D.new()
	xm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	xm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	xm.no_depth_test = true
	xm.render_priority = -1
	xm.albedo_color = Color(dcol, 0.2)
	xray.material_override = xm
	xray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	xray.layers = 4
	ring.add_child(xray)
	var lbl := F.label3d(def["label"], 34, def["color"])
	lbl.position.y = 0.45
	lbl.layers = 2
	lbl.no_depth_test = true
	lbl.render_priority = 9
	node.add_child(lbl)
	if key == "bin":
		# The bin itself is the target: just a ring round its foot, the name above it
		ring.mesh = null
		var tm := TorusMesh.new()
		tm.inner_radius = 0.95
		tm.outer_radius = 1.1
		ring.mesh = tm
		xray.mesh = tm
		lbl.position.y = 1.7
	parent.add_child(node)
	stations[key] = {"node": node, "ring": ring, "mat": rm, "xmat": xm, "color": def["color"], "label": lbl, "zone": zone}

## The scaffold walkway round the square slab: grating, a handrail on the
## outside (open where the walkway to the boom and the hoist meet it), and
## standards down to the floor below. It's all on the rig, so it climbs.
func _build_walkway() -> void:
	var grate := F.mat("steel")
	var rail := F.mat("orange")
	var ox := BW * 0.5 + WALK_GAP + WALK_W     # outer edge
	var oz := BD * 0.5 + WALK_GAP + WALK_W
	var mx := BW * 0.5 + WALK_MID
	var mz := BD * 0.5 + WALK_MID
	var parts: Array = []
	# Grating
	parts.append(F.box(Vector3(ox * 2.0, 0.1, WALK_W), grate, Vector3(0, -0.05, -mz)))
	parts.append(F.box(Vector3(ox * 2.0, 0.1, WALK_W), grate, Vector3(0, -0.05, mz)))
	parts.append(F.box(Vector3(WALK_W, 0.1, (BD * 0.5 + WALK_GAP) * 2.0), grate, Vector3(-mx, -0.05, 0)))
	parts.append(F.box(Vector3(WALK_W, 0.1, (BD * 0.5 + WALK_GAP) * 2.0), grate, Vector3(mx, -0.05, 0)))
	# Toe boards on the outside edge, in safety yellow
	var toe := F.mat("yellow_dark")
	# Handrails: [from, to] along the outside, with gaps for the hoist and
	# the walkway out to the boom
	var runs := [
		[Vector3(-ox, 0, -oz), Vector3(ox, 0, -oz)],
		[Vector3(-ox, 0, oz), Vector3(HOIST_X - SC.x - 1.0, 0, oz)],
		[Vector3(HOIST_X - SC.x + 1.0, 0, oz), Vector3(ox, 0, oz)],
		[Vector3(-ox, 0, -oz), Vector3(-ox, 0, oz)],
		[Vector3(ox, 0, -oz), Vector3(ox, 0, -SC.z - 1.3)],
		[Vector3(ox, 0, -SC.z + 1.3), Vector3(ox, 0, oz)],
	]
	for r in runs:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var mid := (a + b) * 0.5
		var ln := a.distance_to(b)
		var along_x := absf(b.x - a.x) > absf(b.z - a.z)
		for y in [0.55, 1.08]:
			parts.append(F.box(Vector3(ln, 0.06, 0.06) if along_x else Vector3(0.06, 0.06, ln), rail, mid + Vector3(0, y, 0)))
		parts.append(F.box(Vector3(ln, 0.15, 0.03) if along_x else Vector3(0.03, 0.15, ln), toe, mid + Vector3(0, 0.075, 0)))
		var n := maxi(1, int(ln / 2.0))
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			parts.append(F.box(Vector3(0.07, 1.1, 0.07), rail, p + Vector3(0, 0.55, 0)))
			# Scaffold standards down to the floor below
			parts.append(F.box(Vector3(0.06, FH, 0.06), grate, p + Vector3(0, -FH * 0.5, 0)))
	for part in parts:
		# (built round the slab's centre)
		part.position += Vector3(SC.x, 0, SC.z)
		rig.add_child(part)
		_rect_rails.append(part)

## The walkway's centreline as a loop: a point `s` metres round it.
func walkway_point(s: float) -> Vector2:
	if tutorial:
		var r := TUT_R + WALK_MID
		var a := s / r
		return Vector2(cos(a), sin(a)) * r
	var A := BW * 0.5 + WALK_MID
	var B := BD * 0.5 + WALK_MID
	var per := 4.0 * (A + B)
	var c := Vector2(SC.x, SC.z)
	s = fposmod(s, per)
	if s < 2.0 * A:
		return c + Vector2(-A + s, -B)
	s -= 2.0 * A
	if s < 2.0 * B:
		return c + Vector2(A, -B + s)
	s -= 2.0 * B
	if s < 2.0 * A:
		return c + Vector2(A - s, B)
	s -= 2.0 * A
	return c + Vector2(-A, B - s)

func walkway_length() -> float:
	if tutorial:
		return TAU * (TUT_R + WALK_MID)
	return 4.0 * (BW * 0.5 + WALK_MID + BD * 0.5 + WALK_MID)

## How far round the walkway the point nearest `q` is.
func walkway_param(q: Vector2) -> float:
	if tutorial:
		var r := TUT_R + WALK_MID
		return fposmod(atan2(q.y, q.x), TAU) * r
	var A := BW * 0.5 + WALK_MID
	var B := BD * 0.5 + WALK_MID
	q -= Vector2(SC.x, SC.z)
	var sides := [[Vector2(-A, -B), Vector2(A, -B), 0.0], [Vector2(A, -B), Vector2(A, B), 2.0 * A],
		[Vector2(A, B), Vector2(-A, B), 2.0 * A + 2.0 * B], [Vector2(-A, B), Vector2(-A, -B), 4.0 * A + 2.0 * B]]
	var best := 1e9
	var out := 0.0
	for sd in sides:
		var a: Vector2 = sd[0]
		var b: Vector2 = sd[1]
		var ab := b - a
		var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := (a + ab * t).distance_to(q)
		if d < best:
			best = d
			out = float(sd[2]) + t * ab.length()
	return out

## Is this deck point on the slab itself (not the walkway or a landing)?
func on_pad(p: Vector3) -> bool:
	if tutorial:
		return Vector2(p.x, p.z).length() < TUT_R - 0.2
	return absf(p.x - SC.x) < BW * 0.5 - 0.2 and absf(p.z - SC.z) < BD * 0.5 - 0.2

## Builds the placing boom's two arms for the chosen kit.
func _build_boom(a: float, b: float) -> void:
	l1 = a
	l2 = b
	if arm1:
		arm1.queue_free()
	var boom_mat := F.mat("yellow", true)
	var joint_mat := F.mat("navy", true)
	arm1 = Node3D.new()
	arm1.position.y = SHOULDER
	yaw_node.add_child(arm1)
	arm1.add_child(F.box(Vector3(l1, 0.6, 0.6), boom_mat, Vector3(l1 * 0.5, 0, 0)))
	arm1.add_child(F.sphere(0.45, joint_mat))
	arm2 = Node3D.new()
	arm2.position.x = l1
	arm1.add_child(arm2)
	arm2.add_child(F.box(Vector3(l2, 0.48, 0.48), boom_mat, Vector3(l2 * 0.5, 0, 0)))
	arm2.add_child(F.sphere(0.38, joint_mat))
	tip = Node3D.new()
	tip.position.x = l2
	arm2.add_child(tip)
	tip.add_child(F.sphere(0.3, joint_mat))
	var hang := F.cylinder(0.17, HOSE, F.mat("hose"), Vector3(0, -HOSE * 0.5, 0), 8)
	hang.name = "Hose"
	tip.add_child(hang)
	hose_end = Node3D.new()
	hose_end.position.y = -HOSE
	tip.add_child(hose_end)

func _apply_kit(which: String) -> void:
	if which == "tutorial":
		tutorial = true
		_use_tut_frame()
		which = "tower"
	kit = which
	if is_instance_valid(selector) and not tutorial and _start_level <= 1:
		_start_level = selector.start_level
	line = LineScript.new()
	add_child(line)
	if kit == "truck":
		# The boom rides on the pump truck itself; no tower, no riser, no climbs
		lattice.visible = false
		for d in head_deco:
			d.visible = false
		climb.visible = false
		head.position = Vector3(17.6, 3.2, 6.0)
		_build_boom(19.0, 19.0)
		hud.toast("Truck boom it is. Mind the reach up top.", 2.4)
	elif tutorial:
		_build_boom(12.0, 12.0)
	else:
		# Long enough to reach the far corner of the east wing from the tower
		# in the notch (an MX42 reaches about 38 m; this is a shade more)
		_build_boom(20.0, 20.0)
		hud.toast(Settings.branded("Good call: that's the kit SCP ran on Riverlight."), 2.4)
	line.build(self, kit)
	line.whip.connect(_on_whip)
	poker = PokerScript.new()
	add_child(poker)
	poker.build(self)
	screed = ScreedScript.new()
	add_child(screed)
	screed.build(self)
	screed.rack_local = deck_pos("screed")
	ops = OpsScript.new()
	add_child(ops)
	ops.setup(self)
	if kit == "truck":
		line.add_truck_boom_body()
	crew.place_start()
	if is_instance_valid(selector):
		selector.queue_free()
	if tutorial:
		_tut_site()
		for key in DECK_STATIONS:
			(stations[key]["node"] as Node3D).position = deck_pos(key)
		ops.place()
		for p in players:
			if p.zone == "deck":
				p.position.x = clampf(p.position.x, -3.5, 3.5)
				p.position.z = clampf(p.position.z, -3.5, 3.5)
		_tut_prebuild()
		return
	_start_floor()

## One lift of the water tower: the shaft (cast with jump forms, so each lift
## shows its construction joint), then at the top the cone that flares out
## under the tank floor, and above that the tank's own wall.
func _tut_frame(frame: Node3D) -> void:
	var conc := F.mat("core")
	if k < TUT_FIRST:
		var sh := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = SHAFT_R
		cm.bottom_radius = SHAFT_R
		cm.height = FH
		cm.radial_segments = 40
		sh.mesh = cm
		sh.material_override = conc
		sh.position.y = FH * 0.5
		frame.add_child(sh)
		# The lift joint and the tie holes from the jump form
		var joint := MeshInstance3D.new()
		var jm := CylinderMesh.new()
		jm.top_radius = SHAFT_R + 0.02
		jm.bottom_radius = SHAFT_R + 0.02
		jm.height = 0.05
		jm.radial_segments = 40
		joint.mesh = jm
		joint.material_override = F.mat("column")
		joint.position.y = FH - 0.03
		frame.add_child(joint)
	elif k == TUT_FIRST:
		# The cone: from the shaft out to the tank floor's edge
		var cone := MeshInstance3D.new()
		var cn := CylinderMesh.new()
		cn.top_radius = TUT_R + 0.3
		cn.bottom_radius = SHAFT_R
		cn.height = FH - 0.42
		cn.radial_segments = 48
		cone.mesh = cn
		cone.material_override = conc
		cone.position.y = (FH - 0.42) * 0.5
		frame.add_child(cone)
	else:
		# The tank wall, up to the roof
		var wall := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = TUT_R + 0.3
		wm.bottom_radius = TUT_R + 0.3
		wm.height = FH - 0.3
		wm.radial_segments = 48
		wm.cap_top = false
		wm.cap_bottom = false
		wall.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color("b7bcc3")
		wmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		wall.material_override = wmat
		wall.position.y = (FH - 0.3) * 0.5
		frame.add_child(wall)
		# A painted band round the tank
		var band := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = TUT_R + 0.32
		bm.bottom_radius = TUT_R + 0.32
		bm.height = 0.5
		bm.radial_segments = 48
		bm.cap_top = false
		bm.cap_bottom = false
		band.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color("4fa3ff")
		bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		band.material_override = bmat
		band.position.y = FH * 0.55
		frame.add_child(band)

## The shaft's first lifts are already cast when the tutorial starts.
func _tut_prebuild() -> void:
	for i in TUT_FIRST:
		_start_floor()
		(floor_nodes[k].get_node("Frame") as Node3D).scale.y = 1.0
		k += 1
	_start_floor()
	line.rebuild_riser()
	work_y = k * FH
	work_target = k * FH
	for p in players:
		if p.zone == "deck":
			p.position.y = work_y
	coach.start()

## Which height a person is working at: "deck", "street" or "mid" (partway
## up the ladder, or riding the hoist).
func _height_group(p) -> String:
	match p.zone:
		"deck":
			return "deck"
		"ground":
			return "street"
		"ladder", "hoist":
			if p.position.y > work_y - 2.5:
				return "deck"
			if p.position.y < 2.0:
				return "street"
	return "mid"

## The street band: a wide strip along the bottom with its own camera on the
## truck bay and the pump, framed in the colour of whoever's working down
## there. It slides up as the split opens and away again when it closes.
const SPLIT_Y := 9.0          # deck height (m) above which the street gets its own band
const BAND_FRAC := 0.38       # share of the screen height the band takes
const SPLIT_DIST := 12.0      # m between the deck crew and the street crew before the screen splits
const DIST_MAX := 30.0        # m: the main camera never pulls back further than this (people's view)
const BAND_CUE_K := 1.3       # the street crew's button size in the band, against the deck view's
var _split := 0.0
var _band_h := 0.0
var _band_d := 20.0
var band_box: SubViewportContainer
var band_view: SubViewport
var band_cam: Camera3D
var band_edge: ColorRect
var band_chip: PanelContainer
var band_chip_label: Label
var band_focus := Vector3(20, 0, 6)
var _mid_marks: Array = []

func _build_band() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	band_box = SubViewportContainer.new()
	band_box.stretch = true
	band_box.anchor_left = 0.0
	band_box.anchor_right = 1.0
	band_box.anchor_top = 1.0
	band_box.anchor_bottom = 1.0
	band_box.offset_top = 0
	band_box.offset_bottom = 0
	band_box.visible = false
	layer.add_child(band_box)
	band_view = SubViewport.new()
	band_view.world_3d = get_viewport().world_3d
	band_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	band_box.add_child(band_view)
	band_cam = Camera3D.new()
	band_cam.fov = 34.0
	band_cam.far = 400.0
	band_view.add_child(band_cam)
	band_edge = ColorRect.new()
	band_edge.anchor_right = 1.0
	band_edge.offset_bottom = 4
	band_edge.color = UI.ROLE["pump"]
	band_box.add_child(band_edge)
	band_chip = PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = UI.ROLE["pump"]
	csb.corner_radius_top_left = 10
	csb.corner_radius_bottom_right = 12
	csb.content_margin_left = 10
	csb.content_margin_right = 12
	csb.content_margin_top = 4
	csb.content_margin_bottom = 4
	band_chip.add_theme_stylebox_override("panel", csb)
	band_chip.position = Vector2(0, 4)
	band_box.add_child(band_chip)
	band_chip_label = Label.new()
	band_chip_label.add_theme_font_size_override("font_size", 14)
	band_chip_label.add_theme_color_override("font_color", UI.INK)
	band_chip.add_child(band_chip_label)
	# Markers for anyone partway up the ladder, sitting on the line between
	for i in 4:
		var m := PanelContainer.new()
		var msb := StyleBoxFlat.new()
		msb.bg_color = Color.WHITE
		msb.set_corner_radius_all(10)
		msb.content_margin_left = 10
		msb.content_margin_right = 10
		msb.content_margin_top = 3
		msb.content_margin_bottom = 4
		m.add_theme_stylebox_override("panel", msb)
		var ml := Label.new()
		ml.add_theme_font_size_override("font_size", 15)
		ml.add_theme_color_override("font_color", UI.INK)
		m.add_child(ml)
		m.visible = false
		layer.add_child(m)
		_mid_marks.append({"panel": m, "label": ml, "style": msb})

func _update_band(delta: float, down: Array, mid: Array, split_e: float) -> void:
	if band_box == null:
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var h: float = vs.y * BAND_FRAC * split_e
	band_box.visible = h > 2.0
	band_box.offset_top = -h
	_band_h = h
	# (the bottom of the HUD sits above the band, not under it)
	hud.set_bottom_inset(h if band_box.visible else 0.0)
	if band_box.visible:
		var bw := int(vs.x)
		var bh := int(maxf(8.0, vs.y * BAND_FRAC))
		if band_view.size != Vector2i(bw, bh):
			band_view.size = Vector2i(bw, bh)
		# Frame whoever's down there, with the pump and the truck bay in view
		var target := Vector3(22.0, 0.0, 6.5)
		var spread := 0.0
		if not down.is_empty():
			var avg := Vector3.ZERO
			for p in down:
				avg += p.position
			avg /= down.size()
			for p in down:
				spread = maxf(spread, (p.position - avg).length())
			target = target.lerp(Vector3(avg.x, 0.0, avg.z), 0.9)
		var d := minf(12.0 + spread * 0.8, 18.0)
		# Hands-on work down there (a slump test): the band moves in on it
		for p in down:
			var wf: Vector3 = work_focus(p)
			if wf.x != INF and down.size() == 1:
				target = Vector3(wf.x, 0.0, wf.z)
				d = 11.0
		band_focus = band_focus.lerp(target + Vector3(0, 1.4, 0), minf(1.0, delta * 2.5))
		_band_d = lerpf(_band_d, d, minf(1.0, delta * 2.5))
		d = _band_d
		var pitch := 0.48
		var off := Vector3(sin(cam_yaw) * cos(pitch), sin(pitch), cos(cam_yaw) * cos(pitch)) * d
		band_cam.position = band_focus + off
		band_cam.look_at(band_focus, Vector3.UP)
		var col: Color = UI.ROLE.get(down[0].role, UI.ROLE["pump"]) if not down.is_empty() else UI.ROLE["pump"]
		band_edge.color = col
		(band_chip.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = col
		var names := []
		for p in down:
			names.append(_who(p))
		band_chip_label.text = "STREET  ·  " + ", ".join(names) if not names.is_empty() else "STREET"
	# Ladder markers on the dividing line (or the bottom edge when not split)
	var line_y: float = vs.y - h if band_box.visible else vs.y - 30.0
	for i in _mid_marks.size():
		var mk: Dictionary = _mid_marks[i]
		var panel: PanelContainer = mk["panel"]
		panel.visible = i < mid.size() and split_e > 0.5
		if not panel.visible:
			continue
		var p = mid[i]
		var sx: float = camera.unproject_position(p.global_position).x
		sx = clampf(sx, 80.0, vs.x - 260.0)
		var below: bool = p.global_position.y < work_y * 0.5
		(mk["label"] as Label).text = "%s %s  %d m" % ["▼" if below else "▲", _who(p), int(round(p.global_position.y))]
		(mk["style"] as StyleBoxFlat).bg_color = UI.ROLE.get(p.role, Color.WHITE)
		panel.position = Vector2(sx - panel.size.x * 0.5, line_y - panel.size.y * 0.5)

## Two picture-in-picture cameras, bottom right, each framed in the colour of
## the job it's watching, with a small name chip.
const INSET := Vector2(352, 198)
func _build_insets() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	for i in 2:
		var box := SubViewportContainer.new()
		box.stretch = true
		box.custom_minimum_size = Vector2(64, 40)   # (sized each frame to the screen)
		box.size = INSET
		box.anchor_left = 1.0
		box.anchor_right = 1.0
		box.anchor_top = 1.0
		box.anchor_bottom = 1.0
		box.offset_left = -16 - INSET.x - i * (INSET.x + 14)
		box.offset_right = -16 - i * (INSET.x + 14)
		box.offset_top = -16 - INSET.y
		box.offset_bottom = -16
		box.visible = false
		layer.add_child(box)
		var view := SubViewport.new()
		view.size = Vector2i(int(INSET.x), int(INSET.y))
		view.world_3d = get_viewport().world_3d
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		box.add_child(view)
		var cam := Camera3D.new()
		cam.fov = 55.0
		cam.far = 400.0
		view.add_child(cam)
		cam.cull_mask = 0xFFFFF
		# The frame, in the job's colour
		var frame := Panel.new()
		var fsb := StyleBoxFlat.new()
		fsb.draw_center = false
		fsb.set_border_width_all(4)
		fsb.border_color = Color.WHITE
		fsb.set_corner_radius_all(10)
		fsb.anti_aliasing = true
		frame.add_theme_stylebox_override("panel", fsb)
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(frame)
		# Name chip, top left, on a tab of the same colour
		var chip := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color.WHITE
		csb.corner_radius_top_left = 10
		csb.corner_radius_bottom_right = 12
		csb.content_margin_left = 10
		csb.content_margin_right = 12
		csb.content_margin_top = 3
		csb.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", csb)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.position = Vector2(0, 0)
		box.add_child(chip)
		var chip_row := HBoxContainer.new()
		chip_row.add_theme_constant_override("separation", 5)
		chip.add_child(chip_row)
		var chip_icon := TextureRect.new()
		chip_icon.custom_minimum_size = Vector2(18, 18)
		chip_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chip_icon.modulate = Color("0f1b2d")
		chip_row.add_child(chip_icon)
		var lab := Label.new()
		lab.add_theme_font_override("font", UI.font("head"))
		lab.add_theme_font_size_override("font_size", 16)
		lab.add_theme_color_override("font_color", Color("111111"))
		chip_row.add_child(lab)
		var badge := CueBadge.new()
		badge.position = Vector2(6, INSET.y - 76)
		badge.visible = false
		box.add_child(badge)
		# The slump test's step guide, just above its close-up
		var guide := SlumpGuide.new()
		guide.visible = false
		layer.add_child(guide)
		insets.append({"box": box, "view": view, "cam": cam, "label": lab, "badge": badge, "frame": fsb, "chip": csb, "icon": chip_icon, "chip_node": chip, "guide": guide})
	_build_gauge_pop(layer)

## The gauge close-up: a small camera on the pump's pressure gauge that pops
## up half a second before a spike, over the pump wherever it is on screen
## (kept inside its own half of a split screen and clear of the other pop-ups),
## with the A to kill it.
const GAUGE_POP := Vector2(250, 180)
var gauge_pop: SubViewportContainer
var _gauge_cam: Camera3D
var _gauge_badge
var _gauge_label: Label
var _gauge_frame: StyleBoxFlat

func _build_gauge_pop(layer: CanvasLayer) -> void:
	gauge_pop = SubViewportContainer.new()
	gauge_pop.stretch = true
	gauge_pop.size = GAUGE_POP
	gauge_pop.visible = false
	gauge_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(gauge_pop)
	var view := SubViewport.new()
	view.size = Vector2i(int(GAUGE_POP.x), int(GAUGE_POP.y))
	view.world_3d = get_viewport().world_3d
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	gauge_pop.add_child(view)
	_gauge_cam = Camera3D.new()
	_gauge_cam.fov = 34.0
	_gauge_cam.far = 60.0
	_gauge_cam.cull_mask = 1
	view.add_child(_gauge_cam)
	var frame := Panel.new()
	_gauge_frame = StyleBoxFlat.new()
	_gauge_frame.draw_center = false
	_gauge_frame.set_border_width_all(4)
	_gauge_frame.border_color = UI.ALARM
	_gauge_frame.set_corner_radius_all(10)
	_gauge_frame.anti_aliasing = true
	frame.add_theme_stylebox_override("panel", _gauge_frame)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge_pop.add_child(frame)
	var chip := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = UI.ROLE["pump"]
	csb.corner_radius_bottom_right = 8
	csb.content_margin_left = 8
	csb.content_margin_right = 10
	csb.content_margin_top = 2
	csb.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", csb)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge_pop.add_child(chip)
	_gauge_label = Label.new()
	_gauge_label.add_theme_font_override("font", UI.font("head"))
	_gauge_label.add_theme_font_size_override("font_size", 17)
	_gauge_label.add_theme_color_override("font_color", Color("111111"))
	chip.add_child(_gauge_label)
	_gauge_badge = CueBadge.new()
	_gauge_badge.position = Vector2(6, GAUGE_POP.y - 76)
	gauge_pop.add_child(_gauge_badge)

## Where a spot in the world is on the screen, and the view it's in: the
## street band when the screen's split and it's down on the street, else the
## deck view. {pt, region, seen}: seen is false when it's off the screen (pt
## is then pulled inside the region).
func _pop_spot(world: Vector3, street: bool) -> Dictionary:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var split_on: bool = band_box != null and band_box.visible and _band_h > 120.0
	var use_band := split_on and street
	var band_h := _band_h if band_box != null and band_box.visible else 0.0
	var region := Rect2(16, 96, vs.x - 32, vs.y - 112 - band_h)
	if use_band:
		region = Rect2(16, vs.y - _band_h + 10, vs.x - 32, _band_h - 20)
	var cam: Camera3D = band_cam if use_band else camera
	var pt := Vector2(region.get_center().x, region.end.y)
	var seen := false
	if cam != null and not cam.is_position_behind(world):
		pt = cam.unproject_position(world)
		if use_band:
			var bv := Vector2(band_view.size)
			pt = Vector2(pt.x * vs.x / maxf(1.0, bv.x), vs.y - _band_h + pt.y * _band_h / maxf(1.0, bv.y))
		seen = region.has_point(pt)
	pt = pt.clamp(region.position, region.end)
	return {"pt": pt, "region": region, "seen": seen}

## A box of `sz` near `pt` (above it, beside it, then below), inside `region`,
## picked to cover as little as it can of the spot itself and of `taken`.
func _place_pop(pt: Vector2, sz: Vector2, region: Rect2, taken: Array) -> Rect2:
	var gap := 28.0
	var tries := [Vector2(pt.x - sz.x * 0.5, pt.y - gap - sz.y), Vector2(pt.x + gap, pt.y - sz.y * 0.5),
			Vector2(pt.x - gap - sz.x, pt.y - sz.y * 0.5), Vector2(pt.x - sz.x * 0.5, pt.y + gap)]
	var at_pt := Rect2(pt - Vector2(30, 30), Vector2(60, 60))
	var best := Rect2(tries[0], sz)
	var best_cost := INF
	for i in tries.size():
		var c: Vector2 = tries[i]
		c.x = clampf(c.x, region.position.x, maxf(region.position.x, region.end.x - sz.x))
		c.y = clampf(c.y, region.position.y, maxf(region.position.y, region.end.y - sz.y))
		var r := Rect2(c, sz)
		var cost := float(i) * 50.0 + r.intersection(at_pt).get_area() * 4.0
		for o in taken:
			cost += r.intersection((o as Rect2).grow(10.0)).get_area()
		if cost < best_cost:
			best_cost = cost
			best = r
	return best

func _update_gauge_pop() -> void:
	if gauge_pop == null:
		return
	gauge_pop.visible = phase == "pour" and line != null and line.gauge_popup() and not skyline
	if not gauge_pop.visible:
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var target: Vector3 = line.gauge_target()
	_gauge_cam.position = line.gauge_eye()
	_gauge_cam.look_at(target, Vector3.UP)
	# Which view the pump's in: the street band when split, else the main one
	var split_on: bool = band_box != null and band_box.visible and _band_h > GAUGE_POP.y * 0.6
	var region := Rect2(16, 96, vs.x - 32, vs.y - 112 - _band_h) if not split_on else Rect2(16, vs.y - _band_h + 10, vs.x - 32, _band_h - 20)
	var cam: Camera3D = band_cam if split_on else camera
	var pt := Vector2(region.position.x + region.size.x * 0.5, region.end.y)
	if not cam.is_position_behind(target):
		pt = cam.unproject_position(target)
		if split_on:
			pt = Vector2(pt.x, vs.y - _band_h + pt.y * _band_h / maxf(1.0, float(band_view.size.y)))
	# (a short band: the close-up shrinks to fit inside it)
	var k := minf(1.0, region.size.y / GAUGE_POP.y)
	var sz := GAUGE_POP * k
	gauge_pop.size = sz
	gauge_pop.scale = Vector2.ONE
	# Over the pump: just above it if there's room, else just below
	var r := Rect2(Vector2(pt.x - sz.x * 0.5, pt.y - 40.0 - sz.y), sz)
	if r.position.y < region.position.y:
		r.position.y = pt.y + 40.0
	r.position.x = clampf(r.position.x, region.position.x, region.end.x - sz.x)
	r.position.y = clampf(r.position.y, region.position.y, region.end.y - sz.y)
	# Clear of the other pop-ups: slide sideways off any it would cover
	for inset in insets:
		var b: SubViewportContainer = inset["box"]
		if not b.visible:
			continue
		var other := b.get_global_rect().grow(10.0)
		var gd: Control = inset["guide"]
		if gd.visible:
			other = other.merge(gd.get_global_rect().grow(10.0))
		if r.intersects(other):
			var left_x := other.position.x - sz.x
			var right_x := other.end.x
			if left_x >= region.position.x and (absf(left_x - r.position.x) <= absf(right_x - r.position.x) or right_x + sz.x > region.end.x):
				r.position.x = left_x
			elif right_x + sz.x <= region.end.x:
				r.position.x = right_x
	gauge_pop.position = r.position
	var spike: bool = line.spike_on
	_gauge_frame.border_color = UI.ALARM if spike or line.spike_warn else UI.ROLE["pump"]
	_gauge_badge.dot_color = UI.ROLE["pump"]
	_gauge_label.text = "PRESSURE SPIKE!" if spike else ("PUMP GAUGE" if line.spike_warn else "PUMP OFF")
	var akey := "A"
	_gauge_badge.position = Vector2(6, sz.y - 76)
	_gauge_badge.show_cue([akey, "KILL THE PUMP", -1.0, true, Vector2(-1, -1), true, false] if spike else ([akey, "get ready", -1.0, true, Vector2(-1, -1), false, false] if line.spike_warn else []))

func _add_section() -> void:
	var s := F.lattice_section(LS, LW)
	s.position.y = section_count * LS
	lattice.add_child(s)
	section_count += 1
	if section_count % 3 == 0:
		var y := section_count * LS - 0.6
		add_child(F.beam(Vector3(SC.x + BW * 0.5 + 0.3, y, 0), Vector3(LAT_X - LW * 0.5, y, 0), 0.22, F.mat("steel")))

## The people playing (not bots), or the whole crew in an all-bot test.
func humans() -> Array:
	if not _cam_roles.is_empty():
		var out: Array = []
		for r in _cam_roles:
			out.append(crew.crew[r])
		return out
	var h: Array = crew.humans()
	# Camera test (pause menu): these bots count as people too
	for r in cam_test_roles():
		if crew.crew.has(r) and not h.has(crew.crew[r]):
			h.append(crew.crew[r])
	return h if not h.is_empty() else players

## The jobs the pause menu's camera test treats as people playing.
func cam_test_roles() -> Array:
	return Settings.CAM_TESTS[Settings.cam_test][1]

## Dev (`--cam=boom,pump`): the camera treats these bots as the people playing.
var _cam_roles: Array = []

## A buzz in a phone player's hand.
func haptic(p, pattern: String) -> void:
	if p != null and phones != null and not p.bot and p.remote_id >= 0:
		phones.vibrate(p, pattern)

# ------------------------------------------------------------------ geometry helpers

## The columns under the slab (slab-local x/z): the old four by two, or on
## Riverlight's wing a grid about 7 m each way.
func _column_xz() -> Array:
	var xs := [-BW * 0.5 + 0.6, -BW * 0.25, BW * 0.25, BW * 0.5 - 0.6]
	var zs := [-BD * 0.5 + 0.6, BD * 0.5 - 0.6]
	if BW > 20.0:
		xs = []
		for i in 5:
			xs.append(lerpf(-BW * 0.5 + 0.6, BW * 0.5 - 0.6, i / 4.0))
		zs = [-BD * 0.5 + 0.6, 0.0, BD * 0.5 - 0.6]
	var out := []
	for x in xs:
		for z in zs:
			out.append(Vector2(x, z))
	return out

## The lift core under the slab (slab-local), clear of the columns.
func _core_xz() -> Vector2:
	return Vector2(BW * 0.125, 0) if BW > 20.0 else Vector2(-2.0, 0)

func _make_pour() -> void:
	pour = PourScript.new()
	add_child(pour)
	pour.build(BW, BD, _column_xz())
	pour.walk_mid = WALK_MID
	pour.visible = false
	pour.position = Vector3(SC.x, 0, SC.z)

func pour_level() -> float:
	return (k + 1) * FH

func deck_top() -> float:
	return pour_level() - 0.3

func deck_open() -> bool:
	return phase != "select" and phase != "roles"

func _walkable(p: Vector3, zone: String, who = null) -> bool:
	if zone == "deck" and who != null and who.role == "boom" and on_pad(p):
		# The boom operator works off the scaffold, never on the pad
		return false
	if zone == "ground":
		var ok := (p.x >= 9.4 and p.x <= 33.5 and p.z >= -4.0 and p.z <= 12.5) or (p.x >= -9.5 and p.x <= 9.4 and p.z >= 6.9 and p.z <= 12.5)
		if not tutorial:
			# Riverlight's two wings come right up to the street: the west wing
			# east of x 14.3 and the east wing round the slab, with the boom
			# tower in the notch between them
			ok = (p.x >= 14.2 and p.x <= 33.5 and p.z >= 1.9 and p.z <= 12.5) or (p.x >= 8.4 and p.x <= 14.2 and p.z >= -1.2 and p.z <= 12.5) or (p.x >= -9.5 and p.x <= 8.4 and p.z >= 2.9 and p.z <= 12.5)
		if not ok:
			return false
		if kit == "tower" and absf(p.x - LAT_X) < 1.4 and absf(p.z) < 1.4:
			return false
		if p.x > 16.4 and p.x < 23.2 and absf(p.z - 6.0) < 1.2:
			return false
		if line and line.truck_blocks(p):
			return false
		return true
	if tutorial:
		# The round deck and its scaffold ring, the walkway in from its edge,
		# and the hoist landing
		if Vector2(p.x, p.z).length() <= TUT_R + WALK_GAP + WALK_W - 0.3:
			return true
		if p.x >= 5.0 and p.x <= 11.0 and absf(p.z) <= 1.0:
			return true
		if p.x >= -7.1 and p.x <= -3.4 and p.z >= 3.4 and p.z <= 7.6:
			return true
	elif absf(p.x - SC.x) <= BW * 0.5 + WALK_GAP + WALK_W - 0.3 and absf(p.z - SC.z) <= BD * 0.5 + WALK_GAP + WALK_W - 0.3:
		return true
	if p.x >= 7.0 and p.x <= 11.0 and absf(p.z) <= 1.0:
		return true
	if p.x >= 10.7 and p.x <= 14.2 and absf(p.z) <= 2.3:
		return true
	return false

## Nobody ever ends up inside a truck: a truck that pulls in or out over
## someone (or someone who's been pushed into one) is shuffled out to the
## nearest clear ground, so they can always get back to work.
func _clear_trucks_of_people() -> void:
	if line == null:
		return
	for p in players:
		if p.zone != "ground":
			continue
		if not line.truck_blocks(p.position):
			continue
		var best := Vector3.INF
		for ring in range(1, 12):
			var rad := 0.4 * ring
			for k2 in 16:
				var a := TAU * k2 / 16.0
				var q: Vector3 = p.position + Vector3(cos(a), 0, sin(a)) * rad
				if _walkable(q, "ground"):
					best = q
					break
			if best != Vector3.INF:
				break
		if best != Vector3.INF:
			p.position = Vector3(best.x, p.position.y, best.z)
			if autotest:
				print("[autotest]   moved %s out from inside a truck" % p.role)

## The box a level's walkable area sits in, for the bots' route search.
func walk_bounds(zone: String) -> Rect2:
	if zone == "deck":
		var x0 := SC.x - BW * 0.5 - 2.0
		return Rect2(x0, SC.z - BD * 0.5 - 2.0, LAT_X + 2.6 - x0, BD + 4.0)
	return Rect2(-9.6, -4.5, 43.6, 17.6)

func _needs_climb() -> bool:
	return head.position.y < pour_level() + HEAD_MIN

func _climb_done() -> bool:
	return head.position.y >= pour_level() + HEAD_TARGET

func _filled_ratio() -> float:
	if kit == "truck":
		return clampf(pour.reach_coverage() / COVERAGE_DONE, 0.0, 1.0)
	return clampf(pour.coverage() / COVERAGE_DONE, 0.0, 1.0)

func _pour_local(world: Vector3) -> Vector3:
	return world - pour.position

func _can_reach(local: Vector3) -> bool:
	var hp := head.global_position + Vector3(0, SHOULDER, 0)
	var t: Vector3 = pour.position + local + Vector3(0, 1.3 + HOSE, 0)
	return hp.distance_to(t) <= l1 + l2 - 0.15

# ------------------------------------------------------------------ level factors

## Outside factors for this level's pour, shown on the briefing card.
func _level_cfg(level: int) -> Dictionary:
	var c := {}
	var temp := randi_range(21, 35)
	if level == 0:
		temp = 24
	c["temp"] = temp
	c["open"] = 44.0 - (temp - 21) * 1.0
	c["rain"] = level >= 2 and randf() < 0.25
	c["rain_at"] = randf_range(10.0, 30.0)
	c["rain_len"] = 14.0
	c["traffic"] = 1.5 if level >= 1 and randf() < 0.3 else 1.0
	c["late"] = 26.0 if c["traffic"] > 1.0 else 0.0
	c["defect"] = level == 1 or (level >= 2 and randf() < 0.35)
	c["gusty"] = level >= 4 and randf() < 0.2
	c["gust_at"] = randf_range(12.0, 30.0)
	c["dawn"] = level == DAWN_LEVEL or (_dawn_flag and level == maxi(0, _start_level - 1))
	if c["dawn"]:
		# (the trucks run before the traffic, and it's cool before sunrise)
		c["traffic"] = 1.0
		c["late"] = 0.0
		c["temp"] = mini(temp, 22)
		c["open"] = 44.0 - (c["temp"] - 21) * 1.0
	if tutorial:
		# A mild, still day with nothing extra going on
		c["temp"] = 22
		c["open"] = 50.0
		c["rain"] = false
		c["traffic"] = 1.0
		c["late"] = 0.0
		c["defect"] = false
		c["gusty"] = false
		c["dawn"] = false
	return c

## The toolbox talk before a pour: the day's conditions as chips, the pour
## plan, and each job's first move.
func _toolbox(wait: bool) -> Dictionary:
	var chips: Array = []
	var notes: Array = []
	var t: int = cfg["temp"]
	if is_dawn():
		chips.append(["DAWN POUR · 5:10 AM", "warn"])
		notes.append("Big pour, so it starts in the dark under the floodlights. The sun comes up over Bulimba as the slab fills: by full light it should be in.")
	if t >= 31:
		chips.append(["HOT · %d°C" % t, "hot"])
		notes.append("Concrete goes off fast: about %ds to keep an edge wet. Started at first light." % int(cfg["open"]))
	else:
		chips.append(["%d°C" % t, ""])
	chips.append(["EDGE WET ~%ds" % int(cfg["open"]), ""])
	if cfg["rain"]:
		chips.append(["SHOWER DUE", "warn"])
		notes.append("Shower mid-pour: stop pumping while it's heavy, or the surface gets marked.")
	if cfg["traffic"] > 1.0:
		chips.append(["TRAFFIC", "warn"])
		notes.append("Kingsford Smith Drive's jammed: trucks spaced out, some running old. Check every docket.")
	if cfg["gusty"]:
		chips.append(["GUSTY", "warn"])
		notes.append("The boom parks over %d km/h until it eases." % int(BOOM_WIND))
	if k in climb_levels():
		chips.append(["CLIMBED TODAY", ""])
	var moves: Array = []
	for role in ["boom", "line", "pump", "hose", "poker", "screed"]:
		var p = crew.crew[role]
		var st: Array = UI.how(role, "pour")
		if st.is_empty():
			continue
		moves.append({"role": role, "btn": st[0][0], "text": st[0][1], "p": p.index, "bot": p.bot})
	return {"title": ("WATER TOWER" if tutorial else "LEVEL %d" % (k + 1)) + " · TOOLBOX TALK",
		"plan": "%d bays, far end first, back toward the boom. Keep the edge wet." % pour.BAYS,
		"chips": chips, "notes": notes, "moves": moves, "wait": wait}

# ------------------------------------------------------------------ phases

func _set_phase(p: String) -> void:
	if autotest and phase != "":
		print("[autotest]   (%s took %.1fs)" % [phase, phase_t])
	phase = p
	phase_t = 0.0
	if autotest or _dbg:
		print("[autotest] level %d: %s (head %.1f m, sections %d)" % [k + 1, p, head.position.y, section_count])

func _start_floor() -> void:
	var f := Node3D.new()
	f.position.y = k * FH
	var frame := Node3D.new()
	frame.name = "Frame"
	f.add_child(frame)
	var col := F.mat("column")
	if tutorial:
		_tut_frame(frame)
	else:
		for c in _column_xz():
			frame.add_child(F.box(Vector3(0.6, FH - 0.3, 0.6), col, Vector3(SC.x + c.x, (FH - 0.3) * 0.5, SC.z + c.y)))
		var core := _core_xz()
		frame.add_child(F.box(Vector3(4.0, FH - 0.3, 4.0), F.mat("core"), Vector3(SC.x + core.x, (FH - 0.3) * 0.5, SC.z + core.y)))
	frame.scale.y = 0.01
	building.add_child(f)
	floor_nodes.append(f)
	pour.visible = false
	work_target = k * FH
	cfg = _level_cfg(k)
	_set_phase("columns")

func _start_inspect() -> void:
	signed = false
	defect_fixed = not cfg["defect"]
	_defect_prog = 0.0
	climb.wind_mean = 36.0 if cfg["gusty"] else randf_range(14.0, 26.0)
	if cfg["defect"]:
		var dx := randf_range(-BW * 0.5 + 1.5, BW * 0.25)
		var dz := randf_range(-BD * 0.5 + 1.5, BD * 0.5 - 1.5)
		defect.position = SC + Vector3(dx, deck_top() + 0.5, dz)
		defect.visible = true
	engineer.visible = true
	engineer.position = SC + Vector3(-6.0, work_y, -4.0)
	# A crew with people in it reads the brief and says when they're ready
	_brief_ok = crew.humans().is_empty() or autotest
	_brief_hold = 0.0
	hud.show_toolbox(_toolbox(not _brief_ok or (autotest and not _cam_roles.is_empty())))
	_set_phase("inspect")

var _incidents: Array = []   # [{at: fill fraction, kind: "clamp"/"block"}]
var _brief_ok := true        # someone's held A on the toolbox talk (or it ran out)
var _brief_hold := 0.0       # how long A's been held on it
const BRIEF_HOLD := 0.8      # s of A to start
const BRIEF_AUTO := 20.0     # s till it starts itself
const REPORT_AUTO := 15.0    # s the slab report waits for an A before moving on
var _human_a := false        # a person pressed A this frame (for the brief and the slab report)

func incident_level() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--incidents="):
			return int(arg.substr(12))
	if autotest:
		return 1
	return int(Settings.value("incidents"))

func _plan_incidents() -> Array:
	var lvl := incident_level()
	var out: Array = []
	if tutorial:
		# The tutorial's first pour goes smoothly; the second has one weeping
		# clamp, to show the line hand's job
		if k == TUT_LAST and lvl > 0:
			out.append({"at": 0.4, "kind": "clamp"})
		return out
	match lvl:
		0:
			pass
		1:
			out.append({"at": randf_range(0.2, 0.55), "kind": "clamp"})
		2, 3:
			var per_bay: bool = lvl == 3 or k >= 2
			if per_bay:
				for b in pour.BAYS:
					var kind := "block" if randf() < (0.3 if lvl == 3 else 0.15) else "clamp"
					out.append({"at": (b + randf_range(0.15, 0.7)) / float(pour.BAYS), "kind": kind})
			else:
				out.append({"at": randf_range(0.2, 0.55), "kind": "clamp"})
	return out

func _start_pour() -> void:
	pour.reset()
	# (a big slab's face is longer, so each strip takes longer to come back
	# to: the concrete stays workable for longer to match, in game time)
	pour.open_time = cfg["open"] * sqrt(pour.vol_k)
	if kit == "truck":
		pour.set_reach(Callable(self, "_can_reach"))
	else:
		pour.reach_all()
	pour_clock = 0.0
	score.start_level()
	clamp_used = false
	clamp_trigger = randf_range(0.2, 0.55)
	_incidents = _plan_incidents()
	# (and the trucks come closer together and carry more, so the pump
	# isn't kept waiting on changeovers)
	line.load_m3 = line.TRUCK_LOAD * minf(BIG_SLAB_LOAD, sqrt(pour.vol_k))
	line.start_pour(pour.needed(), cfg)
	line.interval /= minf(BIG_SLAB_TRUCKS, sqrt(pour.vol_k))
	line._arrive_t = line.interval
	ops.start_pour()
	hud.show_brief(false)
	if is_dawn():
		hud.toast("%s · first truck, under the floodlights" % dawn_clock(), 3.0)
	engineer.visible = false
	defect.visible = false
	_set_phase("pour")
	if kit == "truck" and not pour.reach_full():
		hud.toast("Some of this slab is out of the truck boom's reach", 2.4)

func _finish_pour() -> void:
	pumping = false
	ops.end_pour()
	drop_hose()
	pour.set_splash(false, Vector3.ZERO)
	pour.show_bays(false)
	if kit == "truck":
		pour.hand_place()
	line.end_pour()
	rain.emitting = false
	pour.raining = false
	call_marker.visible = false
	# Whoever's on a poker (crew or players) finishes off behind the last load
	var pokers := 0
	for n in npcs:
		if n.visible:
			pokers += 1
	for p in players:
		if p.tool == "poker":
			pokers += 1
	pour.finish_vibration(minf(1.0, 0.4 * pokers))
	poker.clear()
	screed.clear()
	for p in players:
		if p.busy == "boom":
			p.busy = ""
	_grade()
	_set_phase("screed")

## The end-of-slab report: what an engineer, the builder and the safety
## officer would pick up on, as a quality score out of 100 that pays a bonus
## on top of the points the crew earned doing the work.
func _grade() -> void:
	var d: Dictionary = pour.defects()
	var st: Dictionary = line.stats
	var ratio: float = pour.poured / pour.needed()
	var rows := []
	var acc := {"score": 100.0}
	var pen := func(label: String, pts: float) -> void:
		if pts > 0.5:
			acc["score"] -= pts
			rows.append("%s   -%d%%" % [label, int(round(pts))])
	pen.call("Cold joints: %.1f%% of the slab" % (d["cold"] * 100.0), minf(30.0, d["cold"] * 300.0))
	pen.call("Not vibrated (honeycomb): %d%%" % int(d["voids"] * 100.0), minf(20.0, maxf(0.0, d["voids"] * 100.0 - 10.0) * 0.8))
	if d["bleed"] > 0.0:
		pen.call("Bleed water (over-vibrated or a wet load): %.1f%%" % (d["bleed"] * 100.0), minf(10.0, d["bleed"] * 200.0))
	var rough: float = pour.rough_share()
	pen.call("Went off before it was screeded: %d%%" % int(rough * 100.0), minf(15.0, maxf(0.0, rough * 100.0 - 10.0) * 0.5))
	pen.call("Concrete used: %.2fx the slab" % ratio, minf(25.0, maxf(0.0, ratio - 1.4) * 60.0))
	pen.call("Line: %d burst, %d hose whip, %d blockage" % [st["bursts"], st["whips"], st["blocks"]], st["bursts"] * 15.0 + st["whips"] * 8.0 + st["blocks"] * 6.0)
	pen.call("%d bad load accepted" % st["bad_loads"], st["bad_loads"] * 10.0)
	if pour.out_of_seq > 0.5:
		pen.call("Poured out of sequence: %.0f m³" % pour.out_of_seq, minf(15.0, maxf(0.0, pour.out_of_seq - 4.0) * 1.5))
	if cfg["rain"]:
		pen.call("Poured in heavy rain: %.0f m³" % pour.rain_m3, minf(20.0, pour.rain_m3 * 1.5))
	var safety := []
	var spts := 0.0
	if st["unpinned"] > 0:
		safety.append("%d clamp without safety pin" % st["unpinned"])
		spts += st["unpinned"] * 10.0
	if climb_notes["unclipped"] > 0:
		safety.append("%d tower pin without R-clip" % climb_notes["unclipped"])
		spts += climb_notes["unclipped"] * 8.0
	if climb_notes["wind"] > 0:
		safety.append("no dog-everything call in the wind")
		spts += climb_notes["wind"] * 8.0
	climb_notes = {"unclipped": 0, "wind": 0}
	if safety.size() > 0:
		pen.call("Safety: " + ", ".join(safety), spts)
	if pour.hand_placed > 0:
		var m2: float = pour.hand_placed * pour.dx * pour.dx
		pen.call("Placed by hand beyond the boom's reach: %.0f m²" % m2, minf(45.0, m2 * 0.8))
	if pour_clock > DAY_LIMIT:
		pen.call("Ran past the noise curfew", 15.0)
	var quality: float = clampf(acc["score"], 0.0, 100.0)
	var bonus := int(round(quality * 6.0))
	score.award(null, bonus, "Slab quality bonus (%d%%)" % int(quality))
	# A quick, clean pour earns a little extra
	if pour_clock < DAY_LIMIT * 0.6:
		score.award(null, int((DAY_LIMIT * 0.6 - pour_clock) * 2.0), "Finished early")
	var body := []
	body.append_array(score.report_rows())
	if rows.size() > 0:
		body.append("")
		body.append("Quality knocked back by:")
		body.append_array(rows)
	var verdict := "Engineer's happy." if quality >= 85.0 else ("Passable." if quality >= 60.0 else "The builder's not impressed.")
	var was_tier: int = score.bot_tier
	var kit_key := "tutorial" if tutorial else ("truck" if kit == "truck" else "tower")
	var medal: int = score.finish_slab(kit_key, k, crew.humans().size(), quality, pour_clock)
	var tg: Vector2 = score.targets(kit_key, k, crew.humans().size())
	var note := "poured in %s  ·  silver: %d%% in %s  ·  gold: %d%% in %s" % [_mmss(pour_clock), int(score.SILVER_Q), _mmss(tg.x), int(score.GOLD_Q), _mmss(tg.y)]
	if score.bot_tier != was_tier:
		note += "\nThe bots are working at %s pace now" % score.MEDALS[score.bot_tier].to_lower()
	hud.show_slab(_slab_report(quality, verdict, medal, note, rows), -1.0 if not crew.humans().is_empty() and not autotest or "report" in _shot_only or "lastreport" in _shot_only else 6.0)
	_save_medal(medal)
	if autotest:
			print("[autotest]   level %d: +%d pts (total %d, %s), quality %.0f, medal %s in %.1fs (bots %s) | %s | %s" % [k + 1, score.level, score.total, score.rank_name(), quality, score.MEDALS[medal], pour_clock, score.MEDALS[was_tier], " | ".join(score.report_rows()), " | ".join(rows)])

## The slab report's contents: the medal, each hard hat's points and what
## earned them most, the crew star (the person with the most), and what's next.
func _slab_report(quality: float, verdict: String, medal: int, note: String, losses: Array) -> Dictionary:
	var crew_rows: Array = []
	var star := ""
	var star_pts := 0
	for role in ["boom", "line", "pump", "hose", "poker", "screed"]:
		var p = crew.crew[role]
		var pts := int(score.by_role.get(role, 0))
		var why: String = score.top_reason(role)
		crew_rows.append({"role": role, "p": p.index, "bot": p.bot, "name": p.char_name, "pts": pts, "why": why if why != "" else "Kept out of trouble"})
		if (not p.bot or _cam_roles.has(role)) and pts > star_pts:
			star_pts = pts
			star = role
	var nxt := ""
	if k + 1 >= floors():
		nxt = "Top out"
	elif tutorial:
		nxt = "The roof slab"
	else:
		nxt = "Level %d" % (k + 2) + (" · climb day first" if (k + 1) in climb_levels() else "")
	return {"title": ("WATER TOWER" if tutorial else "LEVEL %d" % (k + 1)) + " · SLAB REPORT", "points": score.level,
		"quality": quality, "verdict": verdict, "medal": medal, "medal_note": note, "crew": crew_rows,
		"star": star, "losses": losses, "next": nxt, "last": k + 1 >= floors()}

## Keeps the best medal for each of the building's floors, for the site page.
func _save_medal(medal: int) -> void:
	if tutorial or autotest:
		return
	var m = Settings.value("medals")
	var arr: Array = (m as Array).duplicate() if m is Array else []
	while arr.size() <= k:
		arr.append(-1)
	arr[k] = maxi(int(arr[k]), medal)
	Settings.put("medals", arr)

func _mmss(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]

func _lock_slab(level: int, instant := false) -> void:
	if tutorial:
		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = TUT_R + 0.3
		dm.bottom_radius = TUT_R + 0.3
		dm.height = 0.3
		dm.radial_segments = 48
		disc.mesh = dm
		disc.material_override = F.color_mat(Color("b5b6b3"))
		disc.position.y = FH - 0.15
		floor_nodes[level].add_child(disc)
		return
	var slab := F.box(Vector3(BW + 0.6, 0.3, BD + 0.6), F.color_mat(Color("b5b6b3")), Vector3(SC.x, FH - 0.15, SC.z))
	floor_nodes[level].add_child(slab)
	_other_crew_floor(level, instant)
	# The storeys under the deck are open frame (dark, no skin yet); the
	# cladding and glass follow a few floors behind, like on the real job
	floor_nodes[level].add_child(F.box(Vector3(BW - 3.0, FH - 0.3, BD - 3.0), F.color_mat(Color("3a3f45")), Vector3(SC.x, (FH - 0.3) * 0.5, SC.z)))
	if level >= FACADE_LAG:
		_glaze(level - FACADE_LAG, instant)

## Riverlight's floor plan east of this slab (game x/z, from the map data's
## footprint): the narrow link the boom tower stands against, and the west
## wing out to its rounded end. Another crew pours it, a level at a time,
## alongside ours.
const FACADE_LAG := 3   # storeys of open frame under the deck before the skin
var _other_stacks: Node3D
const OTHER_WING := [Vector2(8.3, -12.1), Vector2(10.7, -12.1), Vector2(10.6, -19.7), Vector2(59.0, -20.0),
	Vector2(55.0, -10.1), Vector2(49.6, -10.2), Vector2(47.1, -3.5), Vector2(47.7, 1.6), Vector2(14.3, 1.8),
	Vector2(14.3, -1.15), Vector2(8.3, -1.15)]

## The other crew's slab for `level`, and the storey of facade under it.
func _other_crew_floor(level: int, instant: bool) -> void:
	if tutorial:
		return
	var plan := PackedVector2Array(OTHER_WING)
	var plate := F.prism(plan, FH - 0.3, 0.3, F.color_mat(Color("b5b6b3")))
	floor_nodes[level].add_child(plate)
	var core: Array = Geometry2D.offset_polygon(plan, -1.5)
	if not core.is_empty():
		floor_nodes[level].add_child(F.prism(core[0], 0.0, FH - 0.3, F.color_mat(Color("3a3f45")), false))
	# Their deck's always mid-job: ply and bar bundles, props and a couple of
	# formwork crates, up on whichever level they're on
	if _other_stacks == null:
		_other_stacks = Node3D.new()
		building.add_child(_other_stacks)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var kinds := [[Vector3(2.4, 0.5, 1.2), "c48d55"], [Vector3(6.0, 0.3, 0.8), "6b4a32"], [Vector3(1.2, 1.1, 1.2), "8a929c"], [Vector3(3.0, 0.8, 1.4), "d9b03a"]]
		for i in 9:
			var at := Vector2(rng.randf_range(16.0, 52.0), rng.randf_range(-17.5, -1.0))
			if not Geometry2D.is_point_in_polygon(at, plan):
				continue
			var kd: Array = kinds[i % kinds.size()]
			var sz: Vector3 = kd[0]
			var st := F.box(sz, F.color_mat(Color(kd[1])), Vector3(at.x, sz.y * 0.5, at.y))
			st.rotation.y = rng.randf_range(-0.3, 0.3)
			_other_stacks.add_child(st)
	_other_stacks.position.y = (level + 1) * FH
	_other_stacks.visible = phase != "topout"

## Clad storey `level` of both wings, a few floors behind the deck, with
## the dark recessed slot where the two wings meet
func _glaze(level: int, instant: bool) -> void:
	if tutorial or level < 0 or level >= floor_nodes.size() or floor_nodes[level].has_node("Facade"):
		return
	var fac := F.box(Vector3(BW - 0.4, FH - 0.3, BD - 0.4), F.riverlight_mat(), Vector3(SC.x, (FH - 0.3) * 0.5, SC.z))
	fac.name = "Facade"
	fac.scale.y = 1.0 if instant else 0.01
	floor_nodes[level].add_child(fac)
	# (the other wing's skin starts past the link, which stays a dark slot)
	var wall := PackedVector2Array(OTHER_WING).slice(1)
	wall.append(Vector2(10.7, -1.15))
	var inset: Array = Geometry2D.offset_polygon(wall, -0.2)
	if not inset.is_empty():
		var ofac := F.prism(inset[0], 0.0, FH - 0.3, F.riverlight_mat(), false)
		ofac.name = "OtherFacade"
		ofac.scale.y = 1.0 if instant else 0.01
		floor_nodes[level].add_child(ofac)
	var slot := F.box(Vector3(3.0, FH - 0.3, 8.0), F.color_mat(Color("2f3538")), Vector3(9.25, (FH - 0.3) * 0.5, -6.6))
	floor_nodes[level].add_child(slot)

func _top_out() -> void:
	_set_phase("topout")
	hud.card.visible = false
	hud._card_t = 0.0
	skyline = true
	flag.visible = true
	flag.position = SC + Vector3(-BW * 0.5 + 2.0, floors() * FH, -BD * 0.5 + 2.0)
	confetti.position = SC + Vector3(0, floors() * FH + 2.0, 0)
	confetti.restart()
	confetti.emitting = true
	if not tutorial:
		for i in floor_nodes.size():
			_glaze(i, true)
		if _other_stacks != null:
			_other_stacks.visible = false
		_build_roof()
	var tally := [0, 0, 0]
	for m in score.medals:
		tally[m] += 1
	var medal_line := "Medals: %d gold · %d silver · %d bronze\n" % [tally[2], tally[1], tally[0]]
	if tutorial:
		flag.position = Vector3(0, floors() * FH, 0)
		hud.show_topout(
			"Water tower · tutorial done\n" +
			"Shafts like this are cast in lifts a couple of metres high with jump forms (or slipformed day and night).\n" +
			"On top, the tank floor and the roof are pumped onto forms, and the boom climbs to keep up.\n\n" +
			"Your crew: %s points · %s\n%s%s" % [hud._thousands(score.total), score.rank_name(), medal_line, _people_line()] +
			Settings.branded("Press R to start again, and pick Riverlight for the real job"))
		return
	var kit_line := Settings.branded("SCP kit: Putzmeister MX42 placing boom on a free-standing lattice tower, 10 sections to a 41.4 m free-stand, with SCP's self-climbing frame")
	if kit == "truck":
		kit_line = Settings.branded("You ran a truck boom. SCP actually used a Putzmeister MX42 placing boom on a 41.4 m free-standing lattice tower here.")
	_topout_text = (
		Settings.branded("Riverlight, Hamilton Reach Stage 7 · completed 2018\n") +
		"11 levels · 10,000 m³ pumped · 57 m vertical pumping\n" +
		kit_line + "\n" +
		Settings.branded("Main contractor: Watpac Construction\n\n") +
		"Your crew: %s points · %s\n%s%s" % [hud._thousands(score.total), score.rank_name(), medal_line, _people_line()] +
		"Press R to pour it again · Tab to toggle the skyline view")
	if _ink_node != null:
		# (the signed square's bare concrete, left clear of the membrane)
		_ink_node.add_child(F.box(Vector3(INK_SIZE.x + 0.3, 0.012, INK_SIZE.y + 0.3), F.color_mat(Color("a8a49b")), Vector3(0, -0.008, 0), false))
	skyline = false
	_start_fly()

## The finished roof of both wings: grey membrane, a white parapet, plant
## rooms, the lift overrun and rows of solar panels
func _build_roof() -> void:
	var top := floors() * FH
	var roof := Node3D.new()
	roof.position.y = top
	building.add_child(roof)
	var membrane := F.color_mat(Color("a9adb1"))
	var white := F.color_mat(Color("ecebe8"))
	var plant := F.color_mat(Color("c4c9cc"))
	var solar := F.color_mat(Color("2c3e5c"))
	roof.add_child(F.box(Vector3(BW, 0.06, BD), membrane, Vector3(SC.x, 0.03, SC.z), false))
	roof.add_child(F.prism(PackedVector2Array(OTHER_WING), 0.0, 0.06, membrane))
	for side in [-1.0, 1.0]:
		roof.add_child(F.box(Vector3(BW + 0.6, 1.1, 0.25), white, Vector3(SC.x, 0.55, SC.z + side * (BD * 0.5 + 0.2))))
		roof.add_child(F.box(Vector3(0.25, 1.1, BD + 0.6), white, Vector3(SC.x + side * (BW * 0.5 + 0.2), 0.55, SC.z)))
	roof.add_child(F.prism(PackedVector2Array(OTHER_WING), 0.0, 1.1, white, false))
	var core := _core_xz()
	roof.add_child(F.box(Vector3(3.0, 3.5, 3.0), plant, Vector3(SC.x + core.x, 1.75, SC.z + core.y)))
	# (the first sits back from the front corner, clear of the signatures)
	for at in [Vector3(SC.x - 8.0, 0, SC.z - 4.0), Vector3(31.0, 0, -9.0), Vector3(44.0, 0, -13.0)]:
		roof.add_child(F.box(Vector3(6.0, 2.5, 4.0), plant, at + Vector3(0, 1.25, 0)))
	for row in 3:
		for x0 in [SC.x + 2.0, 20.0]:
			for i in 8:
				var p := F.box(Vector3(1.0, 0.05, 1.7), solar, Vector3(x0 + i * 1.1, 0.45, (SC.z - 8.0 if x0 < 15.0 else -15.0) + row * 2.4), false)
				p.rotation.x = deg_to_rad(10.0)
				roof.add_child(p)

func _people_line() -> String:
	var parts := []
	for key in score.by_person:
		parts.append("%s %s" % [key, hud._thousands(score.by_person[key])])
	return ("Earned by you: " + " · ".join(parts) + "\n") if parts.size() > 0 else ""

# ------------------------------------------------------------------ main loop

func _process(delta: float) -> void:
	_frames += 1
	var now_us := Time.get_ticks_usec()
	if _frame_us > 0:
		_frame_ms = lerpf(_frame_ms, (now_us - _frame_us) / 1000.0, 0.05)
	_frame_us = now_us
	phase_t += delta
	work_y = lerpf(work_y, work_target, minf(1.0, delta * 3.0))
	rig.position.y = work_y
	if Input.is_action_just_pressed("skyline"):
		skyline = not skyline
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("dev_climb") and kit == "tower":
		_dev_skip(CLIMB_LEVELS[0])
	if Input.is_action_just_pressed("toggle_shake"):
		shake_on = not shake_on
		hud.toast("Screen shake %s" % ("on" if shake_on else "off"), 1.2)
	if Input.is_action_just_pressed("toggle_sound"):
		sfx.toggle_mute()
		hud.toast("Sound %s" % ("off" if sfx.muted else "on"), 1.2)
	_join_players()
	_swap_keys()
	if phase == "select" or phase == "roles":
		if is_instance_valid(selector):
			selector.set_join(_join_text(), phones.url() if phones.running else "")
		for p in players:
			p.begin_cues()
			p.animate(delta)
			p.end_frame()
		score.update(delta)
		if phase == "roles" and autotest:
			if shot_dir != "" and not _shots_taken.has("roles"):
				var pk = crew.crew["poker"]
				if pk.bot:
					pk.set_driver(crew.human_identity(1, false, "priya"))
					_shot_human = true
				_maybe_shot()
			else:
				if _shot_human:
					crew.crew["poker"].set_driver(crew.bot_identity("gus"))
					_shot_human = false
				selector.go_site()
		elif phase == "select" and _auto_kit != "" and phase_t > 0.3:
			if shot_dir != "" and not _shots_taken.has("select"):
				_maybe_shot()
			else:
				selector.pick(2 if tutorial else (0 if _auto_kit == "tower" else 1))
				_auto_kit = ""
		_update_camera(delta)
		_update_see_through(delta)
		return

	pumping = false
	_human_a = false
	for p in players:
		if p.zone == "deck" and p.busy != "rigger":
			p.position.y = work_y
		elif p.zone == "ground":
			p.position.y = 0.0
		p.begin_cues()
		# Smoko is a concept for now (docs/smoko.md): the worn-out look only
		# shows with the `--weary` dev flag
		var tired: float = 0.75 if _weary_all else 0.0
		p.weary = move_toward(p.weary, tired, delta * 0.6)
		p.speed = 6.0 * screed.speed_k(p) * poker.speed_k(p) * (HOSE_WALK_K if p.busy == "hose" else 1.0)
		if phase != "sign":
			p.walk(delta, Callable(self, "_walkable").bind(p), cam_yaw)
		if tutorial and p.zone == "deck" and p.busy == "" and not _walkable(p.position, "deck"):
			# Never left standing off the edge of the round deck
			var flat := Vector2(p.position.x, p.position.z)
			var lim := TUT_R + WALK_GAP + WALK_W - 0.35
			if flat.length() > lim and not (p.position.x >= 5.0 and absf(p.position.z) <= 1.0) and not (p.position.x <= -3.4 and p.position.z >= 3.4):
				flat = flat.limit_length(lim)
				p.position.x = flat.x
				p.position.z = flat.y
		if p.role == "boom" and p.zone == "deck" and p.busy == "" and on_pad(p.position):
			# Off the pad, onto the scaffold
			var wq := walkway_point(walkway_param(Vector2(p.position.x, p.position.z)))
			p.position.x = wq.x
			p.position.z = wq.y
		_footprints(p)
		_cover(p, delta)
		if not p.bot and not p.covering and p.action_pressed():
			_human_a = true
		if phase != "sign":
			_handle_player(p, delta)
		p.end_frame()
	if autotest and phase == "columns" and k == 0 and OS.get_cmdline_user_args().has("--skip") and kit == "tower":
		_dev_skip(CLIMB_LEVELS[0])
	# (`--startlevel=N`, or a later floor picked on the site page)
	if phase == "columns" and k == 0 and _start_level > 1:
		_dev_skip(_start_level - 1)
	_clear_trucks_of_people()
	bots.tick(delta)
	if climb.active:
		climb.bot(delta)
	climb.update(delta)
	line.update(delta, phase == "pour")
	poker.update(delta)
	screed.update(delta)
	_update_site_band(delta)
	var see_p := false
	var see_s := false
	for h in humans():
		if h.tool == "poker":
			see_p = true
		if h.tool == "screed":
			see_s = true
	pour.set_views(see_p and phase == "pour", see_s and phase == "pour", delta)
	var bop = _boom_operator()
	pour.set_edge_view(1.0 if bop != null and humans().has(bop) else 0.45)
	score.update(delta)
	var cam_right := camera.global_transform.basis.x
	var street_view: bool = band_box != null and band_box.visible
	for p in players:
		p.show_bot_cues = _cam_roles.has(p.role) or cam_test_roles().has(p.role)
		if street_view and _height_group(p) == "street":
			# (the street crew's buttons sized for the band's own camera,
			# which is far closer to them than the deck view's)
			p.show_cues(cam_right, phase_t, band_cam.global_position, BAND_CUE_K)
		else:
			p.show_cues(cam_right, phase_t, camera.global_position)
	_scale_world_labels()
	if shot_dir != "":
		_maybe_shot()

	match phase:
		"columns":
			var u := clampf(phase_t / 1.8, 0.0, 1.0)
			var frame: Node3D = floor_nodes[k].get_node("Frame")
			frame.scale.y = maxf(0.01, ease(u, 0.4))
			if u >= 1.0:
				pour.visible = true
				pour.position.y = deck_top()
				pour.reset()
				work_target = deck_top()
				_set_phase("deck")
		"deck":
			if phase_t > 1.0:
				if kit == "tower" and k in climb_levels():
					_set_phase("climb")
					climb.start(sections_per_climb())
				elif kit == "truck":
					outriggers = [0.0, 0.0, 0.0, 0.0]
					_set_phase("setup")
				else:
					_start_inspect()
		"setup":
			_update_setup(delta)
		"climb":
			pass
		"inspect":
			_update_inspect(delta)
		"pour":
			_update_pour(delta)
		"screed":
			var u := clampf(phase_t / 1.6, 0.0, 1.0)
			if u < 1.0:
				pour.screed(u, delta)
			else:
				pour.screed(1.0, delta)
				pour.set_cured(clampf((phase_t - 1.6) / 0.7, 0.0, 1.0))
			if phase_t > 2.4:
				if k == floors() - 1 and not tutorial:
					_start_sign()
				else:
					_finish_screed()
		"sign":
			_update_sign(delta)
		"cure":
			if k >= FACADE_LAG:
				for fname in ["Facade", "OtherFacade"]:
					var fac := floor_nodes[k - FACADE_LAG].get_node_or_null(fname) as Node3D
					if fac:
						fac.scale.y = maxf(0.01, clampf(phase_t / 0.8, 0.0, 1.0))
			# The slab report stays up till someone presses A
			if hud.card_waiting():
				hud.set_report_left(1.0 - hud.card_age() / REPORT_AUTO, REPORT_AUTO - hud.card_age())
				var swap_by := -1
				for p in players:
					if not p.bot and p.slow_pressed():
						swap_by = p.index
				if swap_by > 0 and hud.card_age() > 1.0 and k + 1 < floors():
					pause_menu.open_on("swap", swap_by)
				elif (_human_a and hud.card_age() > 1.0) or hud.card_age() > REPORT_AUTO:
					hud.dismiss_card()
			if phase_t > 1.4 and not hud.card_waiting():
				k += 1
				if k >= floors():
					_top_out()
				else:
					_start_floor()
		"topout":
			if _fly_on:
				_update_fly(delta)
			# (the vista shots wait for 1.5s, so hang on for them)
			var vistas: bool = "vista" in _shot_only or "vista2" in _shot_only or _next_ext() != ""
			var fly_shots: bool = "fly1" in _shot_only or "fly2" in _shot_only or "fly3" in _shot_only
			if autotest and not (_fly_on and fly_shots) and phase_t > (2.5 + 0.3 * EXT_SHOTS.size() if vistas else 1.0):
				print("[autotest] TOPPED OUT with %d points (%s) in %d frames (kit %s)" % [score.total, score.rank_name(), _frames, kit])
				get_tree().quit(0)

	# Rest the boom when it is not pouring
	if phase != "pour":
		tip_target = tip_target.lerp(Vector3(5.0, 0, 0), minf(1.0, delta * 0.8))
	tip_pos = tip_pos.lerp(tip_target, minf(1.0, delta * 4.0))
	tip_kick = tip_kick.lerp(Vector3.ZERO, minf(1.0, delta * 3.0))
	_update_whip(delta)
	_update_boom()
	_update_stream()
	_update_hoist(delta)
	_update_pops(delta)
	_update_npcs(delta)
	_update_stations()
	_update_signs(delta)
	_update_hud()
	_update_daylight(delta)
	coach.update(delta)
	_update_camera(delta)
	_update_see_through(delta)
	shake = maxf(0.0, shake - delta * 1.6)
	# A hang shows up as one phase that never ends; the whole run's budget is
	# only a backstop (a full tower runs 30 to 40 minutes, give or take the
	# trucks)
	if autotest and phase_t > 8.0 * 60.0:
		push_error("[autotest] stuck in phase %s at level %d (%.0fs)" % [phase, k + 1, phase_t])
		get_tree().quit(1)
	if autotest and _frames > 60 * 60 * 60:
		push_error("[autotest] timed out in phase %s at level %d" % [phase, k + 1])
		get_tree().quit(1)

## A phone wants to play. The first one takes over P1 if nobody's touched the
## keyboard; after that each new phone takes the most useful job a bot is
## doing (up to six people, P1-P6).
func join_phone():
	if autotest:
		return null
	var p1 = crew.human(1)
	if p1 != null and not p1.touched and p1.remote_id < 0:
		p1.set_driver(crew.human_identity(1, true))
		return p1
	if crew.humans().size() >= crew.MAX_PEOPLE:
		return null
	var p = crew.join(true)
	if p != null:
		hud.toast("P%d joined: %s, %s" % [p.index, p.char_name, UI.ROLE_NAME[p.role].to_lower()], 2.0)
	return p

func _join_text() -> String:
	var t := ""
	if phones.running and crew.humans().size() < crew.MAX_PEOPLE:
		t = "Scan to join on your phone\n(same Wi-Fi)\n%s" % phones.url()
		# (a page that won't load is usually the firewall, or the wrong
		# network adapter: say so, and give the other addresses to try)
		var others: Array = phones.other_urls()
		if not others.is_empty():
			t += "\nNot loading? Try %s" % " or ".join(others)
		t += "\nWindows: allow Godot through the firewall"
	elif not phones.running and crew.humans().size() < crew.MAX_PEOPLE:
		t = "Phones can't join: the network ports are busy"
	return t

func _join_players() -> void:
	for i in range(2, 5):
		if crew.human(i) == null and InputMap.has_action("p%d_action" % i) and Input.is_action_just_pressed("p%d_action" % i) and not autotest:
			var p = crew.join(false, i)
			if p != null:
				hud.toast("P%d joined: %s, %s" % [i, p.char_name, UI.ROLE_NAME[p.role].to_lower()], 2.0)
	hud.show_join(false)
	var open_slots: bool = crew.humans().size() < crew.MAX_PEOPLE and not autotest
	hud.set_join(_join_text() if phase != "topout" and phase != "select" and phase != "roles" else "", phones.url() if phones.running and open_slots and phase != "topout" else "")

## P1's number keys swap jobs on the fly (1 boom, 2 line, 3 pump, 4 poker, 5 screed, 6 pipe guy).
func _swap_keys() -> void:
	if autotest:
		return
	for i in crew.ROLES.size():
		if Input.is_physical_key_pressed(KEY_1 + i) and not _swap_held.get(i, false):
			_swap_held[i] = true
			var role: String = crew.ROLES[i]
			if crew.assign(1, role):
				hud.toast("P1 is on the %s job" % UI.ROLE_NAME[role].to_lower(), 1.4)
		elif not Input.is_physical_key_pressed(KEY_1 + i):
			_swap_held[i] = false

var _swap_held := {}

func _update_setup(delta: float) -> void:
	if autotest and _dbg and fmod(phase_t, 3.0) < delta:
		print("[dbg] setup t=%.0f rig=%s" % [phase_t, str(outriggers)])
	# Truck boom: each outrigger out and on its pad before the boom unfolds
	var human: bool = line.human_on_ground()
	_rig_npc_t -= delta
	if not human and _rig_npc_t <= 0.0:
		for i in 4:
			if outriggers[i] < 1.0:
				outriggers[i] = minf(1.0, outriggers[i] + 0.5)
				_rig_npc_t = 1.2
				break
	line.set_outriggers(outriggers)
	var done := true
	for v in outriggers:
		if v < 1.0:
			done = false
	if done and phase_t > 0.5:
		hud.toast("Outriggers down, on pads, truck level. Boom up.", 1.8)
		_start_inspect()

func _update_inspect(delta: float) -> void:
	# The engineer walks the deck checking steel, chairs and cover
	var t := phase_t
	engineer.position = SC + Vector3(-BW * 0.375 + BW * 0.56 * (0.5 - 0.5 * cos(t * 0.9)), work_y, -BD * 0.33 + BD * 0.66 * (0.5 - 0.5 * cos(t * 0.6)))
	engineer.rotation.y = t * 0.8
	engineer.get_node("LegL").rotation.x = sin(t * 8.0) * 0.5
	engineer.get_node("LegR").rotation.x = -sin(t * 8.0) * 0.5
	if not defect_fixed:
		defect.rotation.y += delta
	if not _brief_ok:
		var holding := false
		for p in players:
			if not p.bot and p.action_held():
				holding = true
		_brief_hold = (_brief_hold + delta) if holding and phase_t > 0.5 else maxf(0.0, _brief_hold - delta * 2.0)
		hud.set_toolbox(_brief_hold / BRIEF_HOLD, 1.0 - phase_t / BRIEF_AUTO, maxf(0.0, BRIEF_AUTO - phase_t))
		if _brief_hold >= BRIEF_HOLD or phase_t > BRIEF_AUTO:
			_brief_ok = true
			sfx.hit("ding")
			hud.show_brief(false)
	elif hud.brief.visible and phase_t > 2.5:
		# (an all-bot crew reads it for a moment, then gets on with it)
		hud.show_brief(false)
	if defect_fixed and phase_t > 3.0 and _brief_ok and not signed:
		signed = true
		sfx.hit("ding")
		hud.toast("Engineer's signed off the steel. Pour away.", 1.8)
		_start_pour()

func _update_pour(delta: float) -> void:
	# (the pour clock starts once the line's primed and the concrete's on)
	if ops.primed:
		pour_clock += delta
	ops.update(delta)
	_draw_hose()
	if autotest and fmod(phase_t, 15.0) < delta:
		# (progress, and how long a frame takes, for long pours)
		print("[autotest]   pour t=%.0f clock=%.0f fill=%.2f poured=%.1f/%.1f bay=%d/%d edge=%.0f risk=%.2f wall=%ds step=%.1fms frame=%.1fms" % [phase_t, pour_clock, _filled_ratio(), pour.poured, pour.needed(), pour.cur_bay + 1, pour.BAYS, pour.edge_left, pour.at_risk, Time.get_ticks_msec() / 1000, _step_ms, _frame_ms])
		var dv: Vector2 = pour.debug_volume()
		print("[autotest]     on slab %.1f, spilled %.1f, p90 depth %.2f m, boom held off %s, pumping %.0fs" % [dv.x, pour.spilled, dv.y, str(bots.stop_t), _pump_t])
		if OS.get_cmdline_user_args().has("--dbg"):
			var dl := _pour_local(discharge())
			print("[autotest]     goal %s tip %s disch %s under %.2f strip %s hoser %s" % [str(bots._boom_goal), str(_pour_local(tip_target)), str(dl), pour.height_at(dl), str(pour.leading_strip(pour.cur_bay)), str(hose_holder.position) if hose_holder != null else "-"])
		bots.stop_t = {}
		_pump_t = 0.0
	if autotest and _dbg and fmod(pour_clock, 5.0) < delta and ops.primed:
		var ts := []
		for t in line.trucks:
			ts.append("%s(%.0f)" % [t["state"], t["load"]])
		if _filled_ratio() >= 1.0:
			print("[dbg] left vib=%.3f scr=%.3f" % [_left.x, _left.y])
		var pk = crew.crew["poker"]
		var sc = crew.crew["screed"]
		print("[dbg] poker zone=%s pos=%s tool=%s busy=%s mv=%s act=%s st=%s | screed zone=%s pos=%s tool=%s mv=%s act=%s mode=%s" % [pk.zone, str(pk.position), pk.tool, pk.busy, str(pk.ai_move), pk.ai_action, poker._state(pk)["state"], sc.zone, str(sc.position), sc.tool, str(sc.ai_move), sc.ai_action, bots._scr["mode"]])
		var lh = crew.crew["pump"]
		var pp = crew.crew["line"]
		var hh = crew.crew["hose"]
		print("[dbg] pumpop=%s mv=%s act=%s ops=%s primed=%s step_t=%.1f hose=%s busy=%s pos=%s disch=%s tip=%s want_boom=%s" % [str(lh.position), str(lh.ai_move), lh.ai_action, ops.stage, ops.primed, ops.step_t, hh.char_name, hh.busy, str(hh.position), str(discharge()), str(tip_target), str(_boom_operator() != null)])
		print("[dbg] t=%.0f cov=%.2f bay%d hopper=%.1f p=%.0f high=%s line=%s/%s y=%.1f held=%s pump=%s held=%s fail=%d fix=%d/%s blk=%s idle=%.0f hook=%s trucks=%s scr=%.2f" % [pour_clock, _filled_ratio(), pour.cur_bay, line.hopper, line.pressure, line.speed_high, lh.zone, lh.busy, lh.position.y, lh.held_kind, str(pp.position), pp.held_kind, line.fail_i, line.fix_i, line._step_name(), line.blocked, line.idle_t, line.hook["state"], ",".join(ts), pour.screed_share()])
	# The incident director: what goes wrong this pour, and when (the
	# Incidents setting in the pause menu). One at a time: the next waits
	# till the line's sound again.
	if not _incidents.is_empty() and _filled_ratio() >= float(_incidents[0]["at"]) and line.fail_i < 0 and line.fix_i < 0 and not line.blocked and not line.burst:
		var inc: Dictionary = _incidents.pop_front()
		clamp_used = true
		if inc["kind"] == "block" or (autotest and OS.get_cmdline_user_args().has("--blocktest")):
			line._block(false)
		else:
			line.start_failure()
	# Weather from the briefing
	var raining: bool = cfg["rain"] and pour_clock > cfg["rain_at"] and pour_clock < cfg["rain_at"] + cfg["rain_len"]
	pour.raining = raining
	rain.emitting = raining
	rain.position = Vector3(SC.x + 8.0, work_y + 18.0, SC.z + 6.0)
	if cfg["gusty"] and pour_clock > cfg["gust_at"] and climb._spike_t < 0.0 and not cfg.get("gusted", false):
		cfg["gusted"] = true
		climb._spike_t = 0.0
	var wind_park: bool = climb.wind_gust >= BOOM_WIND

	var op = _boom_operator()
	# The pipe guy calls the concrete on and off (holding A on the end hose):
	# the boom operator just keeps the boom over them. The boom's own A only
	# pumps with nobody on the hose, for the slurry and the washout into the
	# bin, or once a pipe guy's gone quiet (so nobody stands waiting)
	var person_hose: bool = hose_holder != null and not hose_holder.bot and not hose_holder.covering
	# (walking the hose to the next spot isn't being quiet)
	if person_hose and not hose_call and hose_holder.move_input().length() < 0.2:
		_hose_quiet_t += delta
	else:
		_hose_quiet_t = 0.0
	var want := false
	if pipe_calls():
		want = hose_call
	elif op != null:
		want = op.action_held()
	if wind_park or not (_filled_ratio() < 1.0 or ops.wants_bin()):
		want = false
	if _filled_ratio() >= 1.0 and ops.stage == "pour":
		ops.start_washout()
	# High or low output is the boom operator's call (X on the remote). With
	# nobody on the remote the pump runs itself between them.
	if op == null:
		var feeding := false
		for t in line.trucks:
			if t["state"] == "pour":
				feeding = true
		line.speed_high = feeding or line.hopper > line.HOPPER_CAP * (0.35 if line.speed_high else 0.55)
	speed_advice = _speed_advice()
	var q := 0.0
	if ops.primed and not ops.busy():
		q = line.run(delta, want)
	else:
		# Start-up and washout: the slurry, the last of the concrete and the
		# water, into the bin
		line.run(delta, false)
		var bq: float = ops.pump(delta, want, discharge())
		pumping = bq > 0.0
		q = 0.0
	if ops.primed and not ops.busy():
		pumping = q > 0.0
	var hose_local := _pour_local(discharge())
	if q > 0.0 and _whip > 0.2:
		# The hose whipping about: some of it's flung off in lumps, metres away
		var fling := q * 0.6 * _whip
		q -= fling
		_lump_t += delta
		var a := randf() * TAU
		var lump := hose_local + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 3.5) * _whip
		pour.deposit(lump, fling)
		if _lump_t > 0.25:
			_lump_t = 0.0
			sfx.hit("plop")
	if q > 0.0:
		pour.deposit(hose_local, q)
		# A wet load bleeds where it lands: a weak, watery patch in the slab
		if line.wet_q > 0.0:
			pour.mark_bleed(hose_local, 0.9)
		# Points for concrete placed where the pour plan wants it
		if pour.bay_of_x(hose_local.x) <= pour.cur_bay and absf(hose_local.x) < BW * 0.5 and absf(hose_local.z) < BD * 0.5:
			score.trickle(op, q * 5.0, "Concrete placed")
			if hose_holder != null:
				score.trickle(hose_holder, q * 3.0, "On the end hose")
	pour.set_splash(pumping and not (ops.wants_bin() and ops.over_bin(discharge())), hose_local)
	if line.pumping:
		_pump_t += delta
	var t0 := Time.get_ticks_usec()
	pour.step(delta)
	_step_ms = lerpf(_step_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.05)
	pour.show_bays(true)


	# Not enough coming to finish? Ring the plant for another truck.
	line.top_up(pour.needed() * (1.0 - _filled_ratio()) * 1.15 + 1.0)

	# The slab's only done when it's full AND vibrated AND screeded
	if _filled_ratio() >= 1.0:
		if _full_at < 0.0:
			_full_at = pour_clock
			_fin_best = 9.0
			_fin_t = 0.0
		_left = pour.work_left()
		if _dbg and fmod(phase_t, 3.0) < delta:
			var sc0 = crew.crew["screed"]
			print("[left] %s | scr bot pos=%s mode=%s" % [pour.debug_left(), str(sc0.position - pour.position), str(bots._scr)])
		line.live = false   # last of it's in: the line gets washed out
		# Never stuck finishing: if the last of it stops getting smaller, the
		# concreters finish it off by hand (it costs a little)
		var left_sum := _left.x + _left.y
		if left_sum < _fin_best - 0.002:
			_fin_best = left_sum
			_fin_t = 0.0
		else:
			_fin_t += delta
		# (a person on the screed gets to finish the last of it themselves:
		# longer before the crew steps in, and every last bit counts)
		var sc_p = crew.crew.get("screed") if crew else null
		var person_scr: bool = sc_p != null and not sc_p.bot and not sc_p.covering
		var stall: float = FINISH_STALL_PERSON if person_scr else FINISH_STALL
		var most: float = FINISH_MAX_PERSON if person_scr else FINISH_MAX
		if (_fin_t > stall or pour_clock - _full_at > most) and left_sum > 0.0:
			var n: int = pour.finish_by_hand()
			if n > 0:
				hud.toast("The concreters finish the last bits by hand", 2.2)
				score.award(null, -mini(60, n), "Finished by hand")
				if autotest:
					print("[autotest]   finished %d cells by hand after %.1fs" % [n, pour_clock - _full_at])
			_left = pour.work_left()
		if _left.x <= 0.01 and _left.y <= (0.0 if person_scr else 0.02) and ops.washed:
			if autotest:
				print("[autotest]   finishing (vibrate + screed after the last load) took %.1fs" % (pour_clock - _full_at))
			_full_at = -1.0
			_fin_best = 9.0
			_fin_t = 0.0
			_finish_pour()
	else:
		_left = Vector2.ONE

var _left := Vector2.ONE
var _step_ms := 0.0
var _pump_t := 0.0
var _frame_ms := 0.0
var _frame_us := 0
var _weary_all := OS.get_cmdline_user_args().has("--weary")
var _bot_badges := OS.get_cmdline_user_args().has("--botcues")   # dev: show bots' cues in the close-ups

## The Site Band (sfx.gd): each job's part plays while that job's working,
## and keeps going a moment after, so a short pause doesn't stutter.
const BAND_HOLD := 2.5
var _band_hold := {}
var _band_tip := Vector3.ZERO

func _update_site_band(delta: float) -> void:
	sfx.band_on = bool(Settings.value("band"))
	sfx.band_live = phase == "pour" and ops != null and ops.primed
	# (the stroke's thump and a worn clamp's rattle)
	sfx.pumping = line != null and line.pumping and phase == "pour"
	sfx.rattle = line.wear if line != null and line.fail_i >= 0 and line.pumping else 0.0
	var tip_v := (tip_pos - _band_tip).length() / maxf(delta, 0.001)
	_band_tip = tip_pos
	var th = crew.crew.get("line")
	var truck_busy := false
	for t in line.trucks:
		if t["state"] in ["back", "check", "water"]:
			truck_busy = true
	var working := {
		"pump": line.pumping,
		"hose": hose_holder != null and hose_call,
		"poker": sfx.rumble > 0.05,
		"screed": screed._working,
		"line": truck_busy or (th != null and (th._moving or th.busy != "")),
		"boom": tip_v > 0.25,
	}
	for lane in working:
		var hold: float = _band_hold.get(lane, 0.0)
		hold = BAND_HOLD if working[lane] else maxf(0.0, hold - delta)
		_band_hold[lane] = hold
		sfx.band[lane] = 1.0 if hold > 0.0 else 0.0
	if hud != null:
		hud.set_band(sfx, sfx.band_on and phase == "pour")

func _on_whip() -> void:
	# Air in the line lets go at the hose: the end hose thrashes and sprays
	tip_kick = Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	shake = maxf(shake, 0.6)
	sfx.hit("whip")
	hud.toast("HOSE WHIP! Air in the line. Keep the hopper topped up.", 2.2)
	for i in 6:
		pour.deposit(Vector3(randf_range(-BW * 0.5, BW * 0.5), 0, randf_range(-BD * 0.5, BD * 0.5)), 0.12)

## Dev shortcut (F1): finish levels instantly up to `target` so the climb
## roles (dogman and rigger) can be tried straight away.
func _dev_skip(target: int) -> void:
	if target <= k or not (phase in ["columns", "deck", "inspect", "pour"]):
		return
	for p in players:
		p.busy = ""
		p.tool = ""
	if phase == "pour":
		line.end_pour()
	hud.show_brief(false)
	engineer.visible = false
	defect.visible = false
	while k < target:
		var frame: Node3D = floor_nodes[k].get_node("Frame")
		frame.scale.y = 1.0
		if k in CLIMB_LEVELS:
			for i in SECTIONS_PER_CLIMB:
				_add_section()
			head.position.y = section_count * LS
		_lock_slab(k, true)
		k += 1
		_start_floor()
	line.rebuild_riser()
	work_y = k * FH
	work_target = k * FH
	for p in players:
		if p.zone == "deck":
			p.position.y = work_y
	hud.toast("Level %d: the floors below are poured" % (k + 1), 2.0)

func _on_climb_done() -> void:
	climb_notes["unclipped"] += climb.unclipped
	climb_notes["wind"] += climb.wind_misses
	line.rebuild_riser()
	hud.toast("Boom's up %d section%s. Riser extended." % [sections_per_climb(), "" if sections_per_climb() == 1 else "s"], 2.0)
	_start_inspect()

# ------------------------------------------------------------------ players and stations

func _station_visible(key: String) -> bool:
	match key:
		"tag":
			return climb.active and climb.stage in ["fly", "guide"]
		"boom":
			return not climb.active   # (the same spot's the dogman's on a climb day)
		"dogman":
			return kit == "tower" and climb.active
		"rigger":
			return kit == "tower"
		"ladder", "ladder_g":
			return kit == "tower"
		"rig0", "rig1", "rig2", "rig3":
			return phase == "setup" and outriggers[int(key.substr(3))] < 1.0
		"poker":
			return phase == "pour"
		"screed":
			return false   # (the screeder always has the board)
		"haul":
			return kit == "tower" and (phase == "pour" or climb.active)
		"sling", "pins":
			return kit == "tower" and climb.active
		"pinsets":
			return false
		"hose":
			return phase == "pour" and hose_holder == null
		"bin":
			return phase == "pour" and ops.wants_bin()
		"valve":
			return phase == "pour" and ops.stage == "valve"
	return true

func _station_near(p) -> String:
	var best := ""
	var best_d := 1.25
	for key in stations:
		var st: Dictionary = stations[key]
		if st["zone"] != p.zone or not _station_visible(key):
			continue
		var n: Node3D = st["node"]
		var d := Vector3(p.position.x, 0, p.position.z).distance_to(Vector3(n.global_position.x, 0, n.global_position.z))
		if d < best_d:
			best_d = d
			best = key
	return best

func _boom_operator():
	for p in players:
		if p.busy == "boom":
			return p
	return null

## Whether the boom operator should switch the pump's output, and how badly:
## {want: "high"/"low"/"", level: 0 worth it, 1 should, 2 now, why}.
## Low stretches the hopper between trucks, eases a weeping clamp and tops up
## the last of the slab gently. High keeps up when a truck's feeding and the
## wet edge is getting old.
var speed_advice := {"want": "", "level": 0, "why": ""}

func _speed_advice() -> Dictionary:
	var none := {"want": "", "level": 0, "why": ""}
	if phase != "pour" or line.line_down() or line.blocked:
		return none
	var feeding := false
	for t in line.trucks:
		if t["state"] == "pour":
			feeding = true
	var hop: float = line.hopper / line.HOPPER_CAP
	var fill := _filled_ratio()
	if line.speed_high:
		if not line.pumping:
			return none   # (only while it's actually pumping)
		if hop < 0.12 and not feeding:
			return {"want": "low", "level": 2, "why": "hopper emptying"}
		if hop < 0.3 and not feeding:
			return {"want": "low", "level": 1, "why": "hopper low"}
		if line.fail_i >= 0:
			return {"want": "low", "level": 1, "why": "clamp weeping"}
		if fill > 0.93:
			return {"want": "low", "level": 0, "why": "topping up"}
		return none
	if line.fail_i >= 0 or fill > 0.93:
		return none
	if feeding and hop > 0.35 or hop > 0.6:
		if pour.poured > 2.0 and pour.edge_left < pour.open_time * 0.35:
			return {"want": "high", "level": 1, "why": "wet edge"}
		if hop > 0.6:
			return {"want": "high", "level": 1, "why": "truck's feeding" if feeding else "hopper's full"}
		return {"want": "high", "level": 0, "why": ""}
	return none

## Name tags and station labels grow with the camera's distance, so they stay
## readable on a TV across the room when the camera pulls back for a big crew,
## times the "Names & labels" setting. Street labels go by the street band's
## camera while the screen is split.
func _scale_world_labels() -> void:
	var wt := float(Settings.value("world_text"))
	for p in players:
		if p.tag:
			p.tag.scale = Vector3.ONE * _label_k(p.tag.global_position) * wt
	for key in stations:
		var l: Label3D = stations[key]["label"]
		if l and l.is_inside_tree():
			l.scale = Vector3.ONE * _label_k(l.global_position) * wt
	if ops and ops.tank_label:
		ops.tank_label.scale = Vector3.ONE * _label_k(ops.tank_label.global_position) * wt
	# The pressure reading over the pump's gauge: by the street band's camera
	# while the screen is split, a touch bigger than a station name
	if line and line.gauge_label:
		var gc: Camera3D = band_cam if _split > 0.5 and band_cam else camera
		line.gauge_label.scale = Vector3.ONE * clampf(gc.global_position.distance_to(line.gauge_label.global_position) / 20.0, 1.0, 2.8) * wt

func _label_k(at: Vector3) -> float:
	var cam: Camera3D = camera
	if _split > 0.5 and at.y < 2.5 and band_cam:
		cam = band_cam
	return clampf(cam.global_position.distance_to(at) / 24.0, 1.0, 2.2)

## A word that pops up where something just got done, rises and fades.
func pop(text: String, at: Vector3, col := Color("7cd992")) -> void:
	var l: Label3D = null
	for c in _pops:
		if not c.visible:
			l = c
			break
	if l == null:
		l = F.label3d("", 48, Color.WHITE)
		l.layers = 2
		add_child(l)
		_pops.append(l)
	l.text = text
	l.modulate = col
	l.position = at + Vector3(0, 0.6, 0)
	l.visible = true
	l.scale = Vector3.ONE * 0.3
	l.set_meta("t", 0.0)

func _update_pops(delta: float) -> void:
	for l in _pops:
		if not l.visible:
			continue
		var t: float = l.get_meta("t") + delta
		l.set_meta("t", t)
		l.position.y += delta * 0.9
		var k := clampf(camera.global_position.distance_to(l.global_position) / 15.0, 0.9, 3.0)
		l.scale = Vector3.ONE * k * (0.3 + 0.9 * minf(1.0, t * 6.0) - 0.2 * minf(1.0, t * 3.0))
		l.modulate.a = clampf(1.6 - t, 0.0, 1.0)
		if t > 1.6:
			l.visible = false

## A concreter's signal: "boom over here".
func call_boom(at: Vector3) -> void:
	call_marker.position = at + Vector3(0, 2.4, 0)
	call_marker.visible = true
	call_t = 6.0
	sfx.hit("whistle:stop")

func _handle_player(p, delta: float) -> void:
	if p.zone == "hoist":
		return

	if p.busy == "hose":
		_hose_work(p, delta)
		return
	# The pipe guy's radio works from anywhere
	if p.role == "hose" and ops.role() == "hose" and ops.radio(p):
		return

	if p.busy == "boom":
		if phase != "pour" or p.leave_pressed():
			p.busy = ""
			return
		# Fine control: a dead zone, then a curve so a small push is a slow
		# creep, slower still while it's pumping, and the aim never runs far
		# ahead of the hose, so it stops where you let go
		var v: Vector2 = p.move_input()
		if p.bot or p.covering:
			# (the bots steer it the way they always have)
			tip_target += Vector3(v.x, 0, v.y).rotated(Vector3.UP, cam_yaw) * 7.0 * delta * p.pace
			v = Vector2.ZERO
		var mag := clampf((v.length() - BOOM_DEAD) / (1.0 - BOOM_DEAD), 0.0, 1.0)
		var dir := _pad_dir(v) if mag > 0.0 else Vector3.ZERO
		# Held hard over for a while, it winds up: faster and faster, until
		# the hose starts to whip
		_boom_hold_t = _boom_hold_t + delta if mag > 0.85 and not (p.bot or p.covering) else 0.0
		var wind_up := 1.0 + (BOOM_RUSH_K - 1.0) * clampf((_boom_hold_t - BOOM_RUSH_AFTER) / BOOM_RUSH_T, 0.0, 1.0)
		var spd := BOOM_SPEED * mag * mag * (BOOM_POUR_K if line.pumping else 1.0) * wind_up
		tip_target += dir * spd * delta * p.pace
		var lead := tip_target - tip_pos
		lead.y = 0.0
		var lead_max := BOOM_LEAD * wind_up * wind_up
		if lead.length() > lead_max and not (p.bot or p.covering):
			tip_target = tip_pos + lead.normalized() * lead_max + Vector3(0, tip_target.y - tip_pos.y, 0)
		if mag == 0.0 and not (p.bot or p.covering):
			# Let go: it settles where the hose is, no drifting on
			tip_target = tip_target.lerp(Vector3(tip_pos.x, tip_target.y, tip_pos.z), minf(1.0, delta * 6.0))
		# Over the slab (and out over the scaffold to the bin when it's wanted)
		var out_k := 1.4 if ops.wants_bin() else -0.6
		tip_target.x = clampf(tip_target.x, SC.x - BW * 0.5 - out_k, SC.x + BW * 0.5 + out_k)
		tip_target.z = clampf(tip_target.z, SC.z - BD * 0.5 - out_k, SC.z + BD * 0.5 + out_k)
		if tutorial:
			# The hose stays over the round slab
			var flat := Vector2(tip_target.x, tip_target.z).limit_length(TUT_R + (1.4 if ops.wants_bin() else -0.7))
			tip_target.x = flat.x
			tip_target.z = flat.y
		_walk_boom_op(p, delta)
		p.face(hose_end.global_position)
		# Radio remote on its belly strap, thumbs on the sticks
		p.pose_arms(Vector3(-1.05 + 0.04 * sin(phase_t * 7.0), 0, 0.42), Vector3(-1.05 - 0.04 * sin(phase_t * 6.0), 0, -0.42))
		var blocked_now: bool = climb.wind_gust >= BOOM_WIND or line.line_down() or line.tripped
		# A clamp weeping or a pipe blocked: the button itself tells you to stop
		var trouble: bool = line.fail_i >= 0 or line.blocked or line.line_down()
		if ops.wants_bin():
			# The slurry, or the washout, into the bin, not the slab
			var ob: bool = ops.over_bin(discharge())
			p.cue("action", "pump into the bin" if ob else "hose over the BIN", 1.0 if pumping else -1.0, true)
			p.gold(not p.bot and ob)
		elif not ops.primed or ops.busy():
			p.say("start-up…" if not ops.primed else "washout…")
		elif pipe_calls():
			pass   # (the pipe guy calls the concrete: you keep the boom over them)
		elif trouble:
			p.cue("action", "STOP pumping!", -1.0, true, Vector2(-1, -1), true)
		else:
			p.cue("action", "pump", 1.0 if line.pumping else -1.0, not blocked_now and line.hopper > 0.3 and not line.pumping)
			# Gold: the boom's over the leading strip, where the concrete's
			# wanted (from the boom tip itself: a bot on the hose works
			# around it, but where you aim is what counts)
			if not p.bot and not blocked_now and line.hopper > 0.1:
				p.gold(pour.good_pour_spot(_pour_local(hose_end.global_position)))
		# X: high or low output. The button only shows when it's worth
		# switching, and flashes red when it's urgent (the hopper emptying).
		var adv: Dictionary = speed_advice
		if adv["want"] != "":
			var lv: int = adv["level"]
			p.cue("alt", ("go " + adv["want"]) if lv == 0 else ("go %s: %s" % [adv["want"].to_upper(), adv["why"]]), -1.0, lv >= 1, Vector2(-1, -1), lv >= 2)
		if adv["want"] != "" and adv["level"] >= 1:
			_advice_t += delta
		else:
			_advice_t = 0.0
		if p.alt_pressed():
			line.speed_high = not line.speed_high
			# One payout per piece of advice that had been showing: no farming
			# it by tapping X back and forth
			if adv["want"] == ("high" if line.speed_high else "low") and adv["level"] >= 1 and _advice_t >= 0.5 and pour_clock - _output_paid_at > 10.0:
				_output_paid_at = pour_clock
				score.award(p, 10, "Good call on the output")
			if not p.bot:
				hud.toast("Pump on %s" % ("HIGH" if line.speed_high else "LOW"), 1.2)
		if climb.wind_gust >= BOOM_WIND:
			p.say("too windy")
		elif line.line_down():
			p.say("line down!")
		elif line.hopper < 0.05:
			p.say("hopper empty")
		return

	# Carrying a part: B puts it down
	if p.held != null and p.busy == "" and p.zone in ["deck", "ground"] and p.leave_pressed() and p.held_kind != "pinsets":
		line.drop_item(p)
		return

	var near := _station_near(p)
	if poker.handle_player(p, delta):
		return
	if screed.handle_player(p, delta, near):
		return

	if p.zone in ["deck", "ground"] and climb.handle_player(p, delta, near, "", "", ""):
		return
	if line.handle_player(p, delta, near if near != "ladder_g" else "ladder"):
		return
	match near:
		"hose":
			if p.role == "hose" and p.held == null and p.tool == "" and hose_holder == null:
				p.cue("action", "take the end hose", -1.0, true)
				if p.action_pressed():
					take_hose(p)
				return
		"valve":
			if p.role == "pump" and ops.valve(p, delta):
				return

	# Hand a part straight to whoever needs it
	if p.held != null and p.busy == "" and p.held_kind != "pinsets":
		for q in players:
			var reach_zone: bool = q.zone == p.zone or (p.zone == "ground" and q.zone == "ladder" and q.position.y < 2.4)
			if q != p and reach_zone and q.held == null and q.tool in ["", "screed"] and q.role == "pump" and Vector2(q.position.x - p.position.x, q.position.z - p.position.z).length() < 1.5:
				p.cue("action", "pass " + p.held_kind, -1.0, true)
				if p.action_pressed():
					var kind: String = p.held_kind
					q.hold_item(p.release_item(), kind)
					sfx.hit("tink")
					score.award(p, 10, "Parts run to the line")
					q.bark("Ta!")
					p.bounce()
				return

	# A part lying within reach
	if p.held == null and p.tool in ["", "screed"]:
		var it: Dictionary = line.item_near(p)
		if not it.is_empty():
			p.cue("action", "pick up")
			if p.action_pressed():
				line.pick_up(p, it)
			return
	if p.held != null:
		p.cue("leave", "put down")

	# Inspection defect on the deck
	if phase == "inspect" and not defect_fixed and p.zone == "deck":
		var dd := Vector2(p.position.x - defect.position.x, p.position.z - defect.position.z).length()
		if dd < 1.3:
			p.cue("action", "fit chair", _defect_prog, true)
			if p.action_held():
				_defect_prog += delta / 1.2
				p.pose_arms(Vector3(-0.6, 0, -0.2), Vector3(-0.6 + 0.3 * sin(phase_t * 20.0), 0, 0.2))
				if _defect_prog >= 1.0:
					defect_fixed = true
					defect.visible = false
					pop("Bar chair in!", defect.position + Vector3(0, 0.6, 0))
					score.award(p, 30, "Defects fixed")
					sfx.hit("ding")
					p.bounce()
					hud.toast("Bar chair in. Engineer's happy.", 1.4)
			return

	match near:
		"boom":
			if phase == "pour" and _boom_operator() == null and p.held == null:
				p.cue("action", "boom remote", -1.0, true)
				if p.action_pressed():
					p.busy = "boom"
					p.bounce()
		"poker":
			if phase == "pour" and p.held == null and p.tool == "":
				p.cue("action", "take poker", -1.0, pour.at_risk > 0.01)
				if p.action_pressed():
					poker.pick_up(p)
		"screed":
			if phase == "pour" and p.held == null and p.tool == "" and screed.holder == null:
				p.cue("action", "take screed board")
				if p.action_pressed():
					screed.pick_up(p)
		"hoist", "hoist_g":
			p.cue("action", "hoist " + ("down" if near == "hoist" else "up"))
			if p.action_pressed():
				p.zone = "hoist"
				p.set_meta("hoist_to", 0.0 if near == "hoist" else -1.0)
				p.position = Vector3(HOIST_X, p.position.y, HOIST_Z)
				# The cage gate: only for people (bots ride a lot, and quietly)
				if not p.bot:
					sfx.hit("clank")
				if _dbg:
					print("[hoist] t=%.1f %s %s rides %s (phase %s)" % [phase_t, p.role, "bot" if p.bot else "P%d" % p.index, near, phase])
		"rig0", "rig1", "rig2", "rig3":
			var idx := int(near.substr(3))
			p.cue("action", "outrigger", outriggers[idx], true)
			if p.action_held():
				outriggers[idx] = minf(1.0, outriggers[idx] + delta / 1.0)
				p.pose_arms(Vector3(-0.8, 0, -0.2), Vector3(-0.8 + 0.3 * sin(phase_t * 18.0), 0, 0.2))
				if outriggers[idx] >= 1.0:
					sfx.hit("thunk")
					score.award(p, 10, "Outriggers down")
					haptic(p, "80")
					p.bounce()

func _update_hoist(delta: float) -> void:
	var rider = null
	for p in players:
		if p.zone == "hoist":
			rider = p
	if rider == null:
		hoist_cage.position.y = move_toward(hoist_cage.position.y, work_y, 7.0 * delta)
		return
	var to: float = rider.get_meta("hoist_to")
	if to < 0.0:
		to = work_y
	rider.position = Vector3(HOIST_X, move_toward(rider.position.y, to, 7.0 * delta), HOIST_Z)
	hoist_cage.position.y = rider.position.y
	rider.say("%d m" % int(rider.position.y))
	if absf(rider.position.y - to) < 0.01:
		if to <= 0.01:
			rider.zone = "ground"
			rider.position = Vector3(HOIST_X, 0, HOIST_Z + 1.4)
		else:
			rider.zone = "deck"
			rider.position = Vector3(HOIST_X, work_y, HOIST_Z - 1.55)
		if not rider.bot:
			sfx.hit("clank")

## The boom operator walks the deck with the radio remote: a few metres back
## from the hose end and off to the side, out from under the boom, where they
## can see the concrete landing.
func _walk_boom_op(p, delta: float) -> void:
	if not tutorial:
		# Down the front of the slab, the walkway nearest the camera, keeping
		# in line with the pipe guy so they can see the concrete land
		var fz: float = SC.z + BD * 0.5 + WALK_MID
		var fx: float = BW * 0.5 + WALK_MID
		var want_x: float = discharge().x
		if ops.wants_bin():
			# (stand back from the bin, not on it: the pipe guy needs the room)
			want_x = ops.bin_world().x - 2.4
		want_x = clampf(want_x, SC.x - fx, SC.x + fx)
		if absf(p.position.z - fz) > 0.05:
			# Round the scaffold onto the front walkway first: along to the
			# nearest end, then down the side (never across the pad)
			var side_x: float = SC.x + (fx if p.position.x >= SC.x else -fx)
			if p.position.z < fz - 1.0 and absf(p.position.x - side_x) > 0.05:
				p.position.x = move_toward(p.position.x, side_x, 3.2 * delta)
			else:
				p.position.z = move_toward(p.position.z, fz, 3.2 * delta)
			p._walk += delta * 10.0
		elif absf(want_x - p.position.x) > 0.6:
			p.position.x = move_toward(p.position.x, want_x, minf(absf(want_x - p.position.x) - 0.5, 3.2 * delta))
			p._walk += delta * 10.0
		p.position.x = clampf(p.position.x, SC.x - fx, SC.x + fx)
		return
	# Round the scaffold, keeping level with the hose (and the pipe guy on it)
	# so they can see the concrete landing, but never on the pad
	var dz := discharge()
	var hx := Vector2(dz.x, dz.z)
	var per := walkway_length()
	var here := Vector2(p.position.x, p.position.z)
	var s_now: float = p.get_meta("wk_s") if p.has_meta("wk_s") else walkway_param(here)
	if walkway_point(s_now).distance_to(here) > 1.0:
		s_now = walkway_param(here)
	var s_to := walkway_param(hx)
	if ops.wants_bin():
		# (stand back from the bin, not on it: the pipe guy needs the room)
		s_to -= 2.4
	var ds := fposmod(s_to - s_now + per * 0.5, per) - per * 0.5
	if absf(ds) > 0.6:
		s_now += signf(ds) * minf(absf(ds) - 0.5, 3.2 * delta)
		p._walk += delta * 10.0
	s_now = fposmod(s_now, per)
	p.set_meta("wk_s", s_now)
	var w := walkway_point(s_now)
	p.position.x = w.x
	p.position.z = w.y

## Every job that needs a worker right now, for the hand signs and the bots:
## {key, pos, level 0..2, role}.
func _jobs() -> Array:
	var out: Array = []
	var up := Vector3(0, 2.3, 0)
	var add := func(key: String, pos: Vector3, level: int, role: String, text := "") -> void:
		var j := {"key": key, "pos": pos, "level": level, "role": role}
		if text != "":
			j["text"] = text
		out.append(j)
	var st_pos := func(key: String) -> Vector3:
		return (stations[key]["node"] as Node3D).global_position
	if phase == "inspect" and not defect_fixed:
		add.call("defect", defect.position + Vector3(0, 1.4, 0), 1, "screed")
	if phase == "setup":
		for i in 4:
			if outriggers[i] < 1.0:
				add.call("rig%d" % i, st_pos.call("rig%d" % i) + up, 0, "pump")
	if climb.active:
		var has := {}
		for q in players:
			has[q.busy] = true
		if climb.stage in ["fly", "guide"] and not has.has("dogman") and climb.dog_bot == null:
			add.call("dogman", st_pos.call("dogman") + up, 1 if climb.stage == "guide" else 0, "boom")
		if climb.tag_ready() and climb.tag_hand == null:
			add.call("tag", st_pos.call("tag") + up, 0, "poker")
		if climb.stage in ["jack", "roll", "pin"] and not has.has("rigger"):
			add.call("rigger", st_pos.call("rigger") + up, 1, "pump")
		if climb.needs_sling() and climb.sling_prog <= 0.0:
			add.call("sling", st_pos.call("sling") + up + Vector3(0, 1.0, 0), 1 if climb.hook_ready() else 0, "line", "SLING IT")
		if climb.needs_pins() and not climb.pins_coming():
			add.call("pins", st_pos.call("pins") + up, 2 if climb.pin_sub == "wait" and climb.stage == "pin" else (1 if climb.stage in ["roll", "pin"] else 0), "line", "PIN BAG")
		elif climb.needs_pins() and crew.crew["line"].held_kind == "pins":
			add.call("haul", st_pos.call("haul") + up, 1, "line", "SEND IT UP")
	if phase != "pour":
		return out
	var oj: Array = ops.job()
	if not oj.is_empty():
		add.call(oj[0], oj[1], oj[2], oj[3], oj[4])
	# The end hose, waiting for the pipe guy
	if hose_holder == null and not crew.crew["hose"].bot:
		add.call("hose", hose_anchor() + Vector3(0, 1.6, 0), 1 if ops.primed else 0, "hose", "END HOSE")
	# The boom remote
	if _boom_operator() == null:
		add.call("boom", st_pos.call("boom") + up, 1 if line.hopper > 1.0 else 0, "boom")
	# Concrete going off unvibrated
	var poker_held := false
	for q in players:
		if q.tool == "poker":
			poker_held = true
	var risk_lv := 2 if pour.at_risk > 0.03 else (1 if pour.at_risk > 0.008 else 0)
	if not poker_held and pour.poured > 1.5:
		add.call("poker", rig.position + poker.unit_local + Vector3(0, 1.9, 0), risk_lv, "poker")
	# A sign right over each patch that's getting close to going off raw
	var k_spot := 0
	for spot in pour.raw_spots(3, 3.5):
		var urg: float = spot[1]
		if urg < 0.45:
			continue
		var lv3 := 2 if urg > 0.75 else (1 if urg > 0.6 else 0)
		add.call("raw%d" % k_spot, pour.position + (spot[0] as Vector3) + Vector3(0, 1.3, 0), lv3, "poker", "VIBRATE HERE")
		k_spot += 1
	# Screeding
	if screed.holder == null and pour.poured > 6.0:
		var lv := 1 if pour.edge_left < pour.open_time * 0.35 else 0
		add.call("screed", rig.position + screed.rack_local + Vector3(0, 2.0, 0), lv, "screed")
	# The bay and the pump panel
	var t = line.needs_check()
	var hop: float = line.hopper / line.HOPPER_CAP
	if t != null:
		var tl := 2 if t["age"] > 80.0 or (t == line.bay_truck and hop < 0.2) else 1
		add.call("bay", (t["node"] as Node3D).position + Vector3(-2.0, 4.2, 0), tl, "line", "TOO OLD: SEND IT BACK" if t.get("too_old", false) else "CHECK THE DOCKET" if t["state"] == "docket" else ("SLUMP TEST" if not t["checked"] else "MAKE THE CALL"))
	elif line.can_wave_in() and (line.bay_truck == null or line.staged == null and hop < 0.6):
		add.call("bay", st_pos.call("bay") + up, 1 if hop < 0.3 else 0, "line", "WAVE TRUCK IN")
	var pop = crew.crew["pump"]
	var akey := ""
	if not pop.bot and not pop.ai and pop.KEYS.has(pop.prefix) and bool(on_keys.get(pop.prefix, pop.prefix == "p1_")):
		akey = " [%s]" % pop.KEYS[pop.prefix]["A"]
	if line.spike_on:
		# A pressure spike: the pump operator kills it from anywhere
		add.call("panel", pop.global_position + up + Vector3(0, 0.6, 0), 2, "pump", "A%s: KILL THE PUMP" % akey)
	elif line.tripped and not line.repair_pending():
		add.call("panel", st_pos.call("panel") + up, 1, "pump", "RESTART THE PUMP")
	elif line.live and line.idle_t > line.SET_TIME * 0.5 and not line.line_down():
		add.call("panel", st_pos.call("panel") + up, 2 if line.idle_t > line.SET_TIME * 0.75 else 1, "pump", "STROKE THE PUMP")
	# The line
	var lh = crew.crew["pump"]   # (the pump operator climbs up and fixes the line)
	if line.fail_i >= 0 or line.fix_i >= 0:
		var j: int = line.fix_i if line.fix_i >= 0 else line.fail_i
		var lv2 := 2 if line.burst or line.wear > 0.7 else (1 if line.wear > 0.35 or line.job_kind != "" else 0)
		var at_joint: bool = line.joint_near(lh) == j
		if not at_joint or lv2 == 2:
			add.call("joint", line.clamps[j]["pos"] + Vector3(0.9, 0.9, 0.9), lv2, "pump", "C%d %s" % [j + 1, "BURST" if line.burst else ("BLOCKED PIPE" if line.job_kind == "block" else "CLAMP")])
	if line.blocked and not line.block_found:
		add.call("block", Vector3(line.RISER.x + 0.9, maxf(2.0, line.riser_top * 0.5), line.RISER.z + 0.9), 2, "pump")
	var part: String = bots.part_needed()
	if part != "" and lh.held_kind != part and not line.part_coming(part, lh):
		var key := "spares" if part == "clamp" else "rack"
		add.call(key, st_pos.call(key) + up, 1, "pump")
	if line.hook["state"] == "up":
		add.call("hook", line.hook_node.global_position + Vector3(0.5, 0.6, 0.0), 0, "pump")
	return out

## Boots in wet concrete leave prints. Walking back over the screeded finish
## spoils it (points, and the screed has to come back), so the scaffold
## walkway round the slab is the way to get about. Once the concrete's gone
## off it doesn't matter. (The bots step lightly: prints are for people.)
const STRIDE := 0.4
var _foot_toast_t := 0.0

func _footprints(p) -> void:
	_foot_toast_t = maxf(0.0, _foot_toast_t - get_process_delta_time())
	# (the pipe guy goes where the hose takes them: the boom drags them about)
	# (nor the screeder with the board down: it takes their prints out behind them)
	var screeding: bool = p.tool == "screed" and p.action_held()
	if p.bot or phase != "pour" or p.zone != "deck" or p.busy in ["boom", "rigger", "dogman", "hose"] or screeding:
		p.set_meta("foot_at", p.position)
		return
	var last: Vector3 = p.get_meta("foot_at") if p.has_meta("foot_at") else p.position
	var step := Vector2(p.position.x - last.x, p.position.z - last.z)
	if step.length() < STRIDE:
		return
	p.set_meta("foot_at", p.position)
	var left: bool = not bool(p.get_meta("foot_l", false))
	p.set_meta("foot_l", left)
	var dir := step.normalized()
	var side := Vector2(-dir.y, dir.x) * (0.09 if left else -0.09)
	var at := _pour_local(Vector3(p.position.x + side.x, p.position.y, p.position.z + side.y))
	if pour.footprint(at, atan2(dir.x, dir.y)) == 2:
		score.award(p, -3, "Footprints in the finish")
		if _foot_toast_t <= 0.0:
			_foot_toast_t = 8.0
			hud.toast("Footprints in the finish! Use the scaffold walkway round the slab", 2.4)

## Nobody holds up the room. When the game's waiting on someone:
##   at once      their button cue, their hat glows gold on the crew bar and
##                their phone's edge glows
##   NUDGE_CALL s a crewmate calls out to them by name; a ghost thumb on
##                their phone shows the button
##   COVER_AFTER s the leading hand (the bot brain for that job) does just
##                that one step for them; they keep the job, and pressing
##                anything takes it straight back
const NUDGE_CALL := 8.0
const COVER_AFTER := 20.0
const CALL_OUTS := {"boom": "Bay's waiting on the boom!", "line": "Truck's waiting!", "pump": "Pump needs you!",
	"hose": "Grab the hose!", "poker": "Get the poker in!", "screed": "Screed's waiting!"}

## Is the game waiting on this person right now (their job's flagged, and
## they've a button to press)?
func waiting_on(p) -> bool:
	return not p.bot and int(urgent.get(p.role, 0)) >= 1 and phase in ["inspect", "pour", "climb"] and not p.cues.is_empty()

## 0 nothing, 1 it's their turn, 2 a crewmate's called out, 3 the leading
## hand's doing this step for them.
func nudge_level(p) -> int:
	if p.bot:
		return 0
	if p.covering:
		return 3
	if not waiting_on(p):
		return 0
	return 2 if p.idle_in >= NUDGE_CALL else 1

func _cover(p, delta: float) -> void:
	if p.bot:
		return
	if p.raw_active():
		p.idle_in = 0.0
		p.set_meta("called", false)
		if p.covering:
			p.uncover()
			hud.toast("P%d's back on the %s" % [p.index, UI.ROLE_NAME[p.role].to_lower()], 1.4)
		return
	p.idle_in += delta
	var waiting: bool = waiting_on(p) or (p.covering and int(urgent.get(p.role, 0)) >= 1)
	if p.covering and not waiting:
		# That step's done: the job's theirs again
		p.uncover()
		p.set_meta("called", false)
		hud.toast("The leading hand's done that one. P%d's still on the %s." % [p.index, UI.ROLE_NAME[p.role].to_lower()], 2.0)
		return
	if not waiting:
		p.set_meta("called", false)
		p.idle_in = minf(p.idle_in, 2.0)
		return
	if p.idle_in > NUDGE_CALL and not bool(p.get_meta("called", false)) and not autotest_human(p):
		p.set_meta("called", true)
		_call_out(p)
	if not p.covering and p.idle_in > COVER_AFTER and not autotest_human(p):
		p.covering = true
		hud.toast("P%d's job is waiting: the leading hand's doing this step. Press anything to take it back." % p.index, 3.0)

## A crewmate shouts across to someone the job's waiting on, by name.
func _call_out(p) -> void:
	var best = null
	var best_d := INF
	for q in players:
		if q == p or not q.bot:
			continue
		var d: float = q.global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = q
	var line_text := "%s! %s" % [p.char_name, CALL_OUTS.get(p.role, "You're up!")]
	if best != null:
		best.bark(line_text, 2.4)
	hud.toast(line_text, 2.0)
	haptic(p, UI.BUZZ["turn"])

## `--human=<job>` with `--nocover` keeps a test's idle person idle.
func autotest_human(_p) -> bool:
	return autotest and OS.get_cmdline_user_args().has("--nocover")

const BOOM_SPEED := 4.5     # m/s at full stick (it was 7 with a lag: too quick to aim)
const BOOM_DEAD := 0.14     # stick dead zone
const BOOM_POUR_K := 0.7    # slower while pumping, for placing
const BOOM_LEAD := 1.15     # m the aim can run ahead of the hose (it follows at 4/s)
const BOOM_RUSH_AFTER := 1.0  # s of full stick before the boom starts to wind up
const BOOM_RUSH_T := 1.5      # s more to reach full rush
const BOOM_RUSH_K := 2.0      # full rush: twice the speed
const WHIP_FROM := 5.2        # m/s of the boom tip where the hose starts to whip
const WHIP_FULL := 3.0        # m/s more to a full whip
var _boom_hold_t := 0.0
var _whip := 0.0              # 0..1: how hard the end hose is whipping about
var _whip_prev := Vector3.ZERO
var _lump_t := 0.0

## The boom stick, mapped onto the slab: left and right run along the slab's
## edge that reads left to right on screen, up and down from its far edge to
## its near one, whichever way the camera's turned.
func _pad_dir(v: Vector2) -> Vector3:
	var r := Vector3(1, 0, 0).rotated(Vector3.UP, cam_yaw)    # screen right, on the ground
	var d := Vector3(0, 0, 1).rotated(Vector3.UP, cam_yaw)    # screen down
	var right := Vector3(signf(r.x), 0, 0) if absf(r.x) >= absf(r.z) else Vector3(0, 0, signf(r.z))
	var down := Vector3(0, 0, signf(d.z)) if absf(r.x) >= absf(r.z) else Vector3(signf(d.x), 0, 0)
	return (right * v.x + down * v.y).normalized()

## The end hose whipping about when the boom's flung round too fast: lumps of
## concrete fly off it across the slab, and whoever's on the end gets swung
## off their feet (they hang on).
func _update_whip(delta: float) -> void:
	var v := tip_pos - _whip_prev
	v.y = 0.0
	_whip_prev = tip_pos
	var spd := v.length() / maxf(delta, 0.0001)
	# (only a person flings it round like that: the bots keep it steady)
	var person := false
	for q in players:
		if q.busy == "boom" and not q.bot and not q.covering:
			person = true
	var want := clampf((spd - WHIP_FROM) / WHIP_FULL, 0.0, 1.0) if phase == "pour" and person else 0.0
	_whip = move_toward(_whip, want, delta * (3.0 if want > _whip else 1.2))
	var h = hose_holder
	if h != null and is_instance_valid(h) and h.busy == "hose" and _whip > 0.02:
		# A pendulum off the end of the hose, legs and arms going everywhere
		var sw := sin(phase_t * 5.5)
		h.model.position.y = 1.3 * _whip * absf(sw)
		h.model.rotation.z = 0.8 * _whip * sw
		var fl := sin(phase_t * 17.0) * _whip
		h.pose_arms(Vector3(-2.6 + 0.8 * fl, 0, -0.6 - 0.5 * fl), Vector3(-2.6 - 0.8 * fl, 0, 0.6 - 0.5 * fl))
		h.model.get_node("LegL").rotation.x = 1.1 * fl
		h.model.get_node("LegR").rotation.x = -1.1 * fl
		if _whip > 0.6 and fmod(phase_t, 1.6) < delta:
			h.bark(["Whoa!", "Easy!", "Aaagh!"][randi() % 3], 0.8)
	elif h != null and is_instance_valid(h):
		h.model.position.y = move_toward(h.model.position.y, 0.0, delta * 4.0)
		h.model.rotation.z = move_toward(h.model.rotation.z, 0.0, delta * 4.0)

var ops                         # the start-up and the washout (ops.gd)
var hose_holder = null          # the pipe guy on the end hose, if anyone
var hose_call := false          # the pipe guy's calling for concrete (holding A)
var _hose_segs: Array = []      # the end hose drawn to the pipe guy's hands
const HOSE_REACH := 2.0         # m the end hose reaches from under the boom tip
const HOSE_QUIET := 6.0         # s without a call before a bot boom carries on regardless
var _hose_quiet_t := 0.0
# The pipe guy shouts "Pump it!" / "Stop!" only for a real start or stop: a
# quick dab to top up a gap stays quiet, and they don't shout twice in a row
const HOSE_BARK_GAP := 4.0      # s between shouts
const HOSE_BARK_RUN := 1.5      # s on (or off) before a change is worth a shout
var _hose_bark_t := 0.0         # time since the last shout
var _hose_state_t := 0.0        # time the call's been in its current state
const HOSE_WALK_K := 0.55       # walking with the hose: slow and steady

## Where the concrete comes out: the pipe guy's hands on the end hose, or the
## hose hanging off the boom tip when nobody's on it.
func discharge() -> Vector3:
	if hose_holder != null and is_instance_valid(hose_holder) and hose_holder.busy == "hose":
		var f := Vector3(sin(hose_holder.model.rotation.y), 0, cos(hose_holder.model.rotation.y))
		return hose_holder.global_position + f * 0.55 + Vector3(0, 0.75, 0)
	return hose_end.global_position

## The point on the deck right under the boom tip (where the end hose hangs).
func hose_anchor() -> Vector3:
	var h := hose_end.global_position
	return Vector3(h.x, work_y, h.z)

func take_hose(p) -> void:
	hose_holder = p
	p.busy = "hose"
	p.bounce()
	sfx.hit("tink")
	(tip.get_node("Hose") as Node3D).visible = false

func drop_hose() -> void:
	if hose_holder != null and is_instance_valid(hose_holder):
		hose_holder.model.position.y = 0.0
		hose_holder.model.rotation.z = 0.0
	if hose_holder != null and is_instance_valid(hose_holder) and hose_holder.busy == "hose":
		hose_holder.busy = ""
	hose_holder = null
	hose_call = false
	if tip and tip.get_node_or_null("Hose"):
		(tip.get_node("Hose") as Node3D).visible = true
	for s in _hose_segs:
		(s as Node3D).visible = false

## True when the pipe guy on the end hose is the one turning the pump on and off.
func pipe_calls() -> bool:
	if hose_holder == null or not ops.primed or ops.busy():
		return false
	var person: bool = not hose_holder.bot and not hose_holder.covering
	return not (person and _hose_quiet_t >= HOSE_QUIET)

## The pipe guy on the end hose: walk it where it's wanted (slowly, on a
## leash from the boom tip), hold A to call the pump on, B to let go.
func _hose_work(p, delta: float) -> void:
	if phase != "pour" or p.leave_pressed():
		drop_hose()
		return
	# The end hose only reaches so far from under the boom tip: past that,
	# the boom drags you along
	var a := hose_anchor()
	var off := Vector2(p.position.x - a.x, p.position.z - a.z)
	if off.length() > HOSE_REACH:
		off = off.normalized() * HOSE_REACH
		p.position.x = a.x + off.x
		p.position.z = a.z + off.y
	p.pose_arms(Vector3(-1.1, 0, -0.35), Vector3(-0.9, 0, 0.35))
	if ops.radio(p):
		hose_call = false
		return
	if ops.role() == "hose":
		hose_call = false
		return
	if not ops.primed or ops.busy():
		hose_call = false
		p.say("")
		return
	var was := hose_call
	hose_call = p.action_held()
	# A clamp weeping or a pipe blocked: the button itself tells you to stop
	if line.fail_i >= 0 or line.blocked or line.line_down():
		p.cue("action", "STOP: let go!" if hose_call else "line trouble: hold off", -1.0, hose_call, Vector2(-1, -1), hose_call)
	else:
		p.cue("action", "hold: pump on" if not hose_call else "pumping · let go: off", 1.0 if hose_call else -1.0, _hose_quiet_t > HOSE_QUIET * 0.5)
		# Gold: you're on the spot where the concrete's wanted
		p.gold(not p.bot and pour.good_pour_spot(_pour_local(discharge())))
	_hose_bark_t += delta
	if hose_call != was:
		var held := _hose_state_t
		_hose_state_t = 0.0
		if held >= HOSE_BARK_RUN and _hose_bark_t >= HOSE_BARK_GAP:
			_hose_bark_t = 0.0
			p.bark("Pump it!" if hose_call else "Stop!", 0.9 if hose_call else 0.7)
	else:
		_hose_state_t += delta

## The end hose drawn as a sagging run from the boom tip to the pipe guy's hands.
func _draw_hose() -> void:
	if hose_holder == null:
		return
	if _hose_segs.is_empty():
		for i in 8:
			var seg := F.cylinder(0.16, 1.0, F.mat("hose"), Vector3.ZERO, 8)
			add_child(seg)
			_hose_segs.append(seg)
	var a: Vector3 = tip.global_position
	var b := discharge()
	var mid := (a + b) * 0.5 + Vector3(0, -0.8, 0)
	# (whipping: the belly of the hose thrashes about)
	mid += Vector3(sin(phase_t * 9.0), 0.4 * cos(phase_t * 7.0), cos(phase_t * 8.0)) * 1.3 * _whip
	var prev := a
	for i in _hose_segs.size():
		var u := float(i + 1) / _hose_segs.size()
		var q := a.lerp(mid, u).lerp(mid.lerp(b, u), u)
		var seg: MeshInstance3D = _hose_segs[i]
		seg.visible = true
		var d := q - prev
		var ln := d.length()
		if ln > 0.01:
			var dir := d / ln
			var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
			seg.transform = Transform3D(Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, -PI * 0.5), (prev + q) * 0.5)
			seg.scale = Vector3(1, ln + 0.05, 1)
		prev = q

var _advice_t := 0.0             # how long the output advice has been showing
var _output_paid_at := -99.0     # pour clock at the last "good call" payout

## Screen-space tidy-up of the floating labels, so nothing prints over
## anything else: the hand signs win, people's name tags step up out of each
## other's way, and station and truck labels give way (they come back when
## there's room).
func _declutter_labels() -> void:
	if camera == null or not is_inside_tree():
		return
	var items: Array = []   # [Label3D, priority, "fixed"/"nudge"/"hide"]
	if signs:
		for k in signs._signs:
			var e: Dictionary = signs._signs[k]
			if (e["root"] as Node3D).visible:
				items.append([e["cap"], 100, "fixed"])
	for p in players:
		if p.tag and p.tag.visible:
			p.tag.offset.y = 0.0
			items.append([p.tag, 80 if not p.bot else 70, "nudge"])
		if p.prompt:
			p.prompt.visible = true   # (back again whenever there's room)
			if p.prompt.text != "":
				items.append([p.prompt, 60, "hide"])
	for key in stations:
		var l: Label3D = stations[key]["label"]
		if l.visible and l.is_inside_tree() and (stations[key]["node"] as Node3D).visible:
			items.append([l, 50, "hide"])
	if line:
		for t in line.trucks:
			var dl: Label3D = (t["node"] as Node3D).get_node_or_null("Docket")
			if dl:
				dl.visible = true
				if dl.text != "":
					items.append([dl, 40, "hide"])
	items.sort_custom(func(a, b): return a[1] > b[1])
	var placed: Array = []
	for it in items:
		var l: Label3D = it[0]
		if camera.is_position_behind(l.global_position):
			continue
		var r := _label_rect(l)
		if r.size.x <= 0.0:
			continue
		if it[2] == "fixed":
			# (a hand sign is its caption plus the hand and icon above it)
			r = Rect2(r.position.x, r.position.y - r.size.y * 2.8, r.size.x, r.size.y * 3.8)
		if _hits(r, placed):
			if it[2] == "hide":
				l.visible = false
			elif it[2] == "nudge":
				# Step a name tag up a line or two (or down, if up would put it
				# behind the HUD along the top), whichever's clear first
				var r0 := r
				var done := false
				for dir in [1.0, -1.0]:
					for k in range(1, 3):
						var rr := Rect2(r0.position - Vector2(0, r0.size.y * 1.05 * k * dir), r0.size)
						if rr.position.y < 110.0 or _hits(rr, placed):
							continue
						l.offset.y = l.font_size * 1.05 * k * dir
						r = rr
						done = true
						break
					if done:
						break
		if l.visible:
			placed.append(r)

func _hits(r: Rect2, placed: Array) -> bool:
	for q in placed:
		if r.intersects(q):
			return true
	return false

## Roughly where a floating label lands on screen (in the street band, when
## it's open and the label's down on the street).
func _label_rect(l: Label3D) -> Rect2:
	var at := l.global_position
	var cam: Camera3D = camera
	var dy := 0.0
	if _split > 0.5 and band_cam and at.y < work_y * 0.5 + 1.0:
		cam = band_cam
		dy = get_viewport().get_visible_rect().size.y - _band_h
	if cam.is_position_behind(at):
		return Rect2()
	var c := cam.unproject_position(at) + Vector2(0, dy)
	var hw := l.font_size * l.pixel_size * l.global_transform.basis.get_scale().y
	var up := cam.global_transform.basis.y * hw
	var h := absf(cam.unproject_position(at + up).y + dy - c.y)
	if h < 1.0:
		return Rect2()
	var w := h * 0.56 * float(maxi(1, l.text.length()))
	c.y -= l.offset.y / maxf(l.font_size, 1.0) * h
	return Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)

var _sign_count := 0
var _full_at := -1.0   # pour clock when the last of the concrete went in
var _fin_best := 9.0   # least work left seen while finishing
var _fin_t := 0.0      # how long it's gone without getting smaller
const FINISH_STALL := 12.0   # s with no progress before the concreters finish it by hand
const FINISH_MAX := 45.0     # s after the last load, at the very most
const FINISH_STALL_PERSON := 25.0   # (a person screeding: more time to get to the last bits)
const FINISH_MAX_PERSON := 150.0
var _signed_keys := {}
var _sign_red := false
var _sign_focus := Vector3.ZERO

func _update_signs(delta: float) -> void:
	var jobs := _jobs()
	urgent = {}
	_sign_count = jobs.size()
	_sign_red = false
	for j in jobs:
		urgent[j["role"]] = maxi(int(urgent.get(j["role"], 0)), int(j["level"]))
		if int(j["level"]) >= 1:
			if not _sign_red:
				_sign_focus = j["pos"]
			_sign_red = true
	signs.show_jobs(jobs if not skyline else [], delta)
	_signed_keys = {}
	for j in jobs:
		_signed_keys[j["key"]] = true

func _update_stations() -> void:
	var needed: Array = climb.needed()
	if phase == "pour":
		if _boom_operator() == null:
			needed.append("boom")
		if line.fail_i >= 0 or line.fix_i >= 0 or line.blocked:
			needed.append("ladder")
			needed.append("ladder_g")
		var step: String = line._step_name()
		if step == "kit" or (line.fail_i >= 0 and line.job_kind == ""):
			needed.append("spares")
		if step == "pipe" or (line.blocked and line.block_found and step in ["", "open", "lower"]):
			needed.append("rack")
		if line.bay_truck == null and line._next_queued() != null or line.bay_truck != null and line.bay_truck["state"] in ["bay", "check", "docket"]:
			needed.append("bay")
		if pour.at_risk > 0.01:
			needed.append("poker")
	if phase == "setup":
		for i in 4:
			needed.append("rig%d" % i)
	if climb.needs_sling():
		needed.append("sling")
	if climb.needs_pins():
		needed.append("pins" if not climb.pins_coming() else "haul")
	# The poker pick-up spot follows its drive unit around the deck
	(stations["poker"]["node"] as Node3D).position = poker.station_local() + Vector3(0, 0, 0)
	(stations["screed"]["node"] as Node3D).position = screed.station_local()
	# The end hose hangs under the boom tip, wherever it is
	var ha := hose_anchor() - rig.position
	(stations["hose"]["node"] as Node3D).position = Vector3(ha.x, 0, ha.z)
	if ops.wants_bin():
		needed.append("bin")
	if ops.stage == "valve":
		needed.append("valve")
	if phase == "pour" and hose_holder == null:
		needed.append("hose")
	var pulse := 1.0 + 0.18 * sin(phase_t * 6.0)
	for key in stations:
		var st: Dictionary = stations[key]
		var n: Node3D = st["node"]
		n.visible = _station_visible(key)
		var ring: MeshInstance3D = st["ring"]
		var m: StandardMaterial3D = st["mat"]
		var col: Color = st["color"]
		if key.begins_with("ladder") and (line.fail_i >= 0 or line.burst):
			col = Color("ff4d4d")
		var on: bool = key in needed
		# The station's name only shows when it's wanted or someone's close
		# by: the hand signs say where the work is, so the site stays clean
		var near := false
		for h in humans():
			if h.zone == st["zone"] and Vector2(h.global_position.x - n.global_position.x, h.global_position.z - n.global_position.z).length() < 5.0:
				near = true
		# (a hand sign over the station already names it)
		# (a hand sign over the station already names it; so does the
		# start-up's sign over the bin)
		(st["label"] as Node3D).visible = (on or near) and not _signed_keys.has(key) and not (key == "bin" and ops.wants_bin())
		ring.scale = Vector3.ONE * (pulse if on else 1.0)
		# A spot right under the camera (the deck view zooms in on the bin for
		# the start-up, with the poker's spot beside it) fades out rather than
		# filling the screen; and the poker's spot is off till there's
		# concrete to vibrate
		var fade := clampf((camera.global_position.distance_to(ring.global_position) - 4.0) / 6.0, 0.0, 1.0)
		if key == "poker" and phase == "pour" and ops.busy():
			fade = 0.0
		ring.visible = fade > 0.01
		m.albedo_color = Color(col, (0.9 if on else 0.4) * fade)
		(st["xmat"] as StandardMaterial3D).albedo_color = Color(col, (0.35 if on else 0.15) * fade)

func _update_npcs(delta: float) -> void:
	var on := phase == "pour"
	# The crew's own concreters stand by between pours; on the pour the poker
	# hand does all the vibrating
	var helpers := 0   # (the poker hand does all of it now, person or bot)
	for i in npcs.size():
		var n := npcs[i]
		n.visible = (on and i < helpers) or phase in ["columns", "deck", "inspect", "screed"]
		if not n.visible:
			poker.npc_idle(n)
			continue
		if not on:
			n.position = Vector3(-4.0 + i * 3.0, work_y, 3.5)
			poker.npc_idle(n)
			continue
		var goal: Vector3 = n.get_meta("goal")
		var local := _pour_local(n.position)
		local.y = 0.0
		var working: bool = n.get_meta("working", false)
		if not working and (goal.x == INF or local.distance_to(goal) < 0.3 or fmod(phase_t + i, 1.0) < delta):
			var g: Vector3 = pour.needs_vibrating(local + Vector3(i * 2.0 - 1.0, 0, 0))
			if g.x != INF:
				goal = g
				n.set_meta("goal", goal)
		var target: Vector3 = pour.position + goal
		target.y = work_y
		if goal.x == INF:
			target = Vector3(-6.0 + i * 2.0, work_y, -5.0)
		var d := target - n.position
		d.y = 0.0
		var moving: bool = d.length() > 0.35 and not working
		if moving:
			n.position += d.normalized() * minf(d.length(), 3.0 * delta)
			n.rotation.y = atan2(d.x, d.z)
		n.position.y = work_y
		n.get_node("LegL").rotation.x = sin(phase_t * 8.0 + i) * (0.5 if moving else 0.0)
		n.get_node("LegR").rotation.x = -sin(phase_t * 8.0 + i) * (0.5 if moving else 0.0)
		if _dbg and fmod(phase_t, 3.0) < delta:
			print("[dbg] npc%d pos=%s goal=%s moving=%s working=%s st=%s raw=%d h=%.2f" % [i, str(local), str(goal), moving, working, poker._state(n)["state"], pour.raw_count(local, 1.2), pour.height_at(local)])
		if not moving and goal.x != INF:
			var busy_now: bool = poker.npc_work(n, local, delta)
			n.set_meta("working", busy_now)
		else:
			n.set_meta("working", false)
	if call_t > 0.0:
		call_t -= delta
		call_marker.visible = call_t > 0.0 and phase == "pour"
		if Vector2(tip_pos.x - call_marker.position.x, tip_pos.z - call_marker.position.z).length() < 1.2:
			call_t = 0.0
			call_marker.visible = false

## Where a close-up view should look for this player's hands, or INF.
## Dev: which slump test screenshot this moment makes, if any.
func _slump_shot(st: Dictionary) -> String:
	for k in ["slump", "slumplift", "slumptape"]:
		if _shots_taken.has(k) or (not _shot_only.is_empty() and not (k in _shot_only)):
			continue
		if k == "slump" and st.get("draw", "") == "rod" and int(st["layer"]) == 1 and float(st["rods"]) > 12.0:
			return k
		if k == "slumplift" and st["step"] == "lift" and float(st["lift"]) > 0.6:
			return k
		if k == "slumptape" and st["step"] == "measure" and float(st["tape"]) > 0.07:
			return k
	return ""

## The truck this person's slump-testing (or deciding on), or null.
func _slump_of(p):
	if p == null or line == null or phase != "pour":
		return null
	var t = line.needs_check()
	if t != null and t.get("tester") == p and line.work_focus(p).x != INF:
		return t
	return null

func work_focus(p) -> Vector3:
	if line == null:
		return Vector3.INF
	var f: Vector3 = line.work_focus(p)
	if f.x != INF:
		return f
	return climb.work_focus(p)

# ------------------------------------------------------------------ boom

func _update_boom() -> void:
	if arm1 == null:
		return
	var hp := head.global_position + Vector3(0, SHOULDER, 0)
	var tp := tip_pos + tip_kick
	var t := Vector3(tp.x, deck_top() + 1.3 + HOSE, tp.z)
	var h := Vector2(t.x - hp.x, t.z - hp.z)
	yaw_node.rotation.y = atan2(-h.y, h.x)
	var d := h.length()
	var ty := t.y - hp.y
	var dist := clampf(sqrt(d * d + ty * ty), 1.0, l1 + l2 - 0.05)
	var phi := atan2(ty, d)
	var a := acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	var b := acos(clampf((l1 * l1 + l2 * l2 - dist * dist) / (2.0 * l1 * l2), -1.0, 1.0))
	var jit := 0.0
	if line and line.fail_i >= 0 and line.pumping:
		jit = 0.015 * line.wear * line.wear
	arm1.rotation.z = phi + a + sin(phase_t * 11.0) * jit * 0.15
	arm2.rotation.z = -(PI - b) + sin(phase_t * 12.7 + 1.0) * jit * 0.3
	tip.rotation.z = -(arm1.rotation.z + arm2.rotation.z)

var _stream_mats := {}

func _update_stream() -> void:
	# (the first spurt of concrete through, for the pipe guy to call)
	var on: bool = phase == "pour" and (pumping or (ops.stage == "concrete" and ops.showing_sign()))
	stream.visible = on
	if not on:
		return
	var top := discharge()
	var floor_y: float = pour.position.y + pour.height_at(_pour_local(top))
	if ops.wants_bin() and ops.over_bin(top):
		floor_y = ops.bin_world().y - 0.5
	# Slurry's sandy, concrete's grey, washout water's blue
	var c = ops.stream_color()
	var want_col: Color = c if c != null else Color("6c6f73")
	if not _stream_mats.has(want_col.to_html()):
		_stream_mats[want_col.to_html()] = F.color_mat(want_col)
	stream.material_override = _stream_mats[want_col.to_html()]
	var drop := maxf(0.1, top.y - floor_y)
	stream.scale = Vector3(1.0 + sin(phase_t * 25.0) * 0.1, drop, 1.0 + cos(phase_t * 21.0) * 0.1)
	stream.position = Vector3(top.x, floor_y + drop * 0.5, top.z)

# ------------------------------------------------------------------ HUD and camera

## The job tickets: everything that's ticking right now, most urgent first.
func _tickets() -> Array:
	var out: Array = []
	if phase == "inspect" and not defect_fixed:
		out.append({"icon": "!", "text": "Fit the missing bar chair", "frac": 1.0, "color": UI.ROLE["screed"], "role": "screed", "urgent": true})
	if phase != "pour":
		return out
	# The start-up or washout step under way
	var ot: Array = ops.ticket()
	if not ot.is_empty():
		var orole: String = ot[2]
		out.append({"icon": "!", "text": "%s · %s" % [ot[0], ot[1]], "frac": clampf(float(ot[3]), 0.0, 1.0), "color": UI.ROLE.get(orole, Color("9fb3c8")), "role": orole, "urgent": ops.step_t > ops.NAG_T})
	# The line
	if line.burst:
		out.append({"icon": "!", "text": "C%d burst · line down" % (line.fail_i + 1), "frac": 1.0 - float(line.fix_step) / maxf(1.0, line.job_steps.size()), "color": Color("ff5a5f"), "urgent": true})
	elif line.job_kind != "":
		var what := "Swap pipe section" if line.job_kind == "block" else "Swap clamp C%d" % (line.job_steps[0][1] + 1)
		out.append({"icon": "C", "text": "%s · %s" % [what, line.STEP_INFO.get(line._step_name(), "")], "frac": 1.0 - float(line.fix_step) / maxf(1.0, line.job_steps.size()), "color": UI.ROLE["pump"], "role": "pump", "urgent": line._step_name() in ["kit", "pipe"]})
	elif line.fail_i >= 0:
		out.append({"icon": "C", "text": "C%d weeping · %d m up" % [line.fail_i + 1, int(line.clamps[line.fail_i]["pos"].y)], "frac": 1.0 - line.wear, "color": UI.ROLE["pump"], "role": "pump", "urgent": line.wear > 0.5})
	if line.blocked and not line.block_found:
		out.append({"icon": "?", "text": "Blocked: tap the riser", "frac": 0.2, "color": Color("ff5a5f"), "urgent": true})
	# The wet edge
	# The boom's progress: the bay being poured filling up, coloured by how
	# fresh the wet edge at the front is (green fresh, amber ageing, red going off)
	if _filled_ratio() < 1.0:
		var left: float = clampf(pour.edge_left / pour.open_time, 0.0, 1.0) if pour.poured > 2.0 else 1.0
		var b: int = pour.cur_bay
		var cov: float = clampf(pour.bay_cov[b], 0.0, 1.0)
		var state := "edge fresh" if left >= 0.55 else ("edge ageing" if left >= 0.3 else "EDGE GOING OFF")
		var bar := UI.GREEN if left >= 0.55 else (UI.YELLOW if left >= 0.3 else UI.RED)
		out.append({"icon": "E", "text": "Bay %d of %d · %d%% · %s" % [b + 1, pour.BAYS, int(cov * 100.0), state], "frac": cov, "bar": bar, "color": UI.ROLE["boom"], "role": "boom", "urgent": left < 0.3})
	if pour.at_risk > 0.01:
		out.append({"icon": "V", "text": "Going off unvibrated", "frac": 1.0 - minf(1.0, pour.at_risk * 8.0), "color": UI.ROLE["poker"], "role": "poker", "urgent": true})
	# Pump and trucks
	if line.hopper < line.HOPPER_CAP * 0.1 and line.live:
		out.append({"icon": "H", "text": "Hopper running dry", "frac": line.hopper / line.HOPPER_CAP, "color": UI.ROLE["pump"], "role": "pump", "urgent": true})
	if line.spike_on:
		out.append({"icon": "P", "text": "PRESSURE SPIKE · kill the pump!", "frac": 1.0 - line.spike_t / line.SPIKE_LIMIT, "color": Color("ff5a5f"), "role": "pump", "urgent": true})
	elif line.tripped:
		out.append({"icon": "P", "text": "Pump off · fix the line, then restart" if line.repair_pending() else "Pump off · restart at the panel", "frac": 0.5, "color": UI.ROLE["pump"], "role": "pump", "urgent": false})
	if line.live and line.idle_t > line.SET_TIME * 0.4:
		out.append({"icon": "P", "text": "Line standing still", "frac": 1.0 - line.idle_t / line.SET_TIME, "color": UI.ROLE["pump"], "role": "pump", "urgent": true})
	var chk = line.needs_check()
	if chk != null:
		var what := "Too old: send it back" if chk.get("too_old", false) else "Check the docket against the order" if chk["state"] == "docket" else ("Slump test the truck" if not chk["checked"] else "Make the call: use, water or send back?")
		out.append({"icon": "T", "text": what, "frac": 1.0 - float(chk["age"]) / line.MAX_AGE, "color": UI.ROLE["line"], "role": "line", "urgent": true})
	elif line.can_wave_in():
		var nq = line._next_queued()
		var standby: bool = line.bay_truck != null   # one's already discharging: not urgent
		out.append({"icon": "T", "text": "Wave the next truck in", "frac": 1.0 - float(nq["age"]) / line.MAX_AGE, "color": UI.ROLE["line"], "role": "line", "urgent": not standby})
	for t in line.trucks:
		if t["state"] == "queue" and t != line._next_queued():
			out.append({"icon": "T", "text": "Truck queued · %d min old" % int(t["age"]), "frac": 1.0 - float(t["age"]) / line.MAX_AGE, "color": UI.ROLE["line"], "role": "line", "urgent": t["age"] > 75.0})
	if pour.raining:
		out.append({"icon": "R", "text": "Heavy rain: hold the pump", "frac": 0.5, "color": Color("4fa3ff"), "urgent": true})
	if climb.wind_gust >= BOOM_WIND:
		out.append({"icon": "W", "text": "Boom parked in the wind", "frac": 0.3, "color": Color("9fb3c8"), "urgent": true})
	# Most urgent first
	out.sort_custom(func(a, b): return (1 if a.get("urgent", false) else 0) > (1 if b.get("urgent", false) else 0))
	return out

func _update_hud() -> void:
	hud.visible = phase != "roles" and phase != "select" and not EXT_SHOTS.has(_shot_key_now)
	hud.set_tickets(_tickets(), phase_t)
	# (no docket card: the slump test and its reading are in the close-up)
	hud.show_docket({})
	if tutorial:
		hud.level_label.text = "WATER TOWER · " + ("TANK FLOOR" if k <= TUT_FIRST else "ROOF")
	else:
		hud.set_floor(k if phase != "topout" else floors() - 1, floors())
	hud.set_score(score.total, score.rank_name(), score.next_rank(), score.rank_frac(), score.bump)
	var crew_rows: Array = []
	for p in players:
		crew_rows.append({"role": p.role, "p": p.index, "name": p.char_name, "bot": p.bot, "nudge": nudge_level(p)})
	hud.set_crew(crew_rows, phase in ["columns", "deck", "setup", "climb", "inspect", "pour", "screed"] and not hud.brief.visible)
	match phase:
		"columns":
			hud.set_task("Build · columns and core")
			hud.set_progress(phase_t / 1.8)
		"deck":
			hud.set_task("Build · formwork deck")
			hud.set_progress(1.0)
		"setup":
			var n := 0
			for v in outriggers:
				if v >= 1.0:
					n += 1
			hud.set_task("Set up · outriggers %d of 4" % n)
			hud.set_progress(n / 4.0)
		"climb":
			var t: Array = climb.hud_task()
			hud.set_task(t[0], t[1])
			hud.set_progress(t[2])
		"inspect":
			hud.set_task("Hold point · engineer's inspection")
			hud.set_progress(clampf(phase_t / 3.0, 0.0, 1.0) if defect_fixed else 0.0)
		"pour":
			var sub := ""
			if _boom_operator() == null:
				sub = "Nobody's on the boom remote"
			if _filled_ratio() >= 1.0:
				var parts := []
				if _left.x > 0.01:
					parts.append("vibrate %d%%" % int(ceil(_left.x * 100.0)))
				if _left.y > 0.02:
					parts.append("screed %d%%" % int(ceil(_left.y * 100.0)))
				var tk: Array = ops.ticket()
				if not tk.is_empty():
					parts.append("washout")
				hud.set_task(("Finish · " + " and ".join(parts) + " to go") if not parts.is_empty() else "Finish", "" if tk.is_empty() else "%s · %s" % [tk[0], tk[1]])
				hud.set_progress(1.0 - clampf(maxf(_left.x * 4.0, _left.y * 4.0), 0.0, 1.0))
			elif not ops.primed:
				var tk2: Array = ops.ticket()
				hud.set_task("Start-up · prime the line", ("%s · %s" % [tk2[0], tk2[1]]) if not tk2.is_empty() else "")
				hud.set_progress(float(tk2[3]) if not tk2.is_empty() else 0.0)
			else:
				hud.set_task(("%s · " % dawn_clock() if is_dawn() else "") + "Pour · bay %d of %d" % [pour.cur_bay + 1, pour.BAYS], sub)
				hud.set_progress(_filled_ratio())
		"screed", "cure":
			hud.set_task("")   # (the slab report's up)
		"sign":
			var left := 0
			for p in humans():
				if not _ink_done.get(p, false):
					left += 1
			if _ink_sealed >= 0.0:
				hud.set_task("Signed", "")
			else:
				hud.set_task("Sign the slab · %ds" % int(ceil(ink_left())), "Draw on your phone. Keyboard or pad: stick and A to draw, X when done." if left > 0 else "Pressing it in...")
			hud.set_progress(1.0 - ink_left() / INK_TIME)
		"topout":
			hud.set_task("Topped out")
			hud.set_progress(1.0)
	var in_pour := phase == "pour"
	hud.set_pump(in_pour, line.hud_info() if in_pour else {})
	if in_pour:
		hud.set_gauge(line.spike_on, line.tripped)
	if in_pour:
		hud.set_stats("%d:%02d" % [int(pour_clock) / 60, int(pour_clock) % 60], line.pressure, line.fail_i >= 0 or line.blocked)
	else:
		hud.set_stats("", line.pressure if line else 0.0, false)
	var alert := ""
	if climb.active and climb.wind_gust >= climb.WIND_STOP and climb.stage in ["fly", "guide"]:
		alert = "Over the crane's wind limit: dog everything and wait"
	hud.set_alert(alert)
	climb.hud_meter()
	if not (climb.active and climb.stage == "guide"):
		hud.set_signal("")
	hud.set_wind(climb.wind_gust, climb.wind_gust / 1.25, climb.WIND_STOP, climb.active or (in_pour and climb.wind_gust >= BOOM_WIND * 0.8))

## Which keyboard players are on the keys (not a pad on the same slot), so
## their cues can show the key as well as the button: "Y [F]".
var on_keys := {}

func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		for pre in ["p1_", "p2_"]:
			for what in ["action", "alt", "slow", "leave", "up", "down", "left", "right"]:
				if InputMap.has_action(pre + what) and InputMap.event_is_action(event, pre + what):
					on_keys[pre] = event is InputEventKey
					return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			rmb = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(14.0, cam_dist * 0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(90.0, cam_dist * 1.1)
	elif event is InputEventMouseMotion and rmb:
		var mm := event as InputEventMouseMotion
		_dog_view = false
		cam_yaw -= mm.relative.x * 0.006
		cam_pitch = clampf(cam_pitch + mm.relative.y * 0.004, 0.15, 1.25)

var _shot_only: Array = []
var _shot_key_now := ""   # (the HUD hides for a shot of the building)
# Dev shots of the whole building from round about (yaw, pitch, focus height,
# distance); game +z is north, +x is west
const EXT_SHOTS := {
	"ext_n": [0.0, -0.05, 12.0, 70.0], "ext_w": [PI * 0.5, -0.05, 12.0, 80.0],
	"ext_s": [PI, -0.05, 12.0, 75.0], "ext_e": [-PI * 0.5, -0.05, 12.0, 80.0],
	"ext_sw": [PI * 0.75, 0.05, 14.0, 85.0], "ext_ne": [-PI * 0.25, 0.05, 14.0, 85.0],
	"aerial": [PI * 0.9, 1.25, 0.0, 130.0],
	# Looking out from the roof (target x, z; the camera stands on the roof)
	"sky_city": [Vector2(4928, -4050)], "sky_gate": [Vector2(-1984, 14)],
	"sky_north": [Vector2(-300, 3000)], "sky_south": [Vector2(1200, -2400)],
}
func _next_ext() -> String:
	for k in EXT_SHOTS:
		if k in _shot_only and not _shots_taken.has(k):
			return k
	return ""
var _shot_cam: Array = []

func _who(p) -> String:
	return (("P%d " % p.index) if not p.bot else "") + p.char_name.to_upper()

## The hoist and the boom tower (with its riser, ladder and the boom's first
## arm) stand on the street side of the deck, right where the camera looks in. Where one's
## between the camera and someone at work, a soft-edged circle round the work
## is cut out of it (shaders/cutaway.gdshaderinc), clear in the middle and
## fading back to solid at the rim; the rest of it stays as it is.
const CUT_R := 4.0            # m, the see-through circle round each bit of work
const CUT_R_CLOSE := 1.1      # ...and round what a close-up's on
var _close_targets: Array = []   # what the close-ups looked at this frame
const TOON_CUT := preload("res://shaders/toon_cut.gdshader")
const OUTLINE_CUT := preload("res://shaders/outline_cut.gdshader")
var _cut_mats := {}           # a part's own material -> its cut-away copy
var _cut_t := 0.0

func _update_see_through(delta: float) -> void:
	if hoist_mast == null:
		return
	# A real hoist mast is extended a section at a time as the building goes
	# up, a little past the deck, not to the full height from day one
	var mast_h := maxf(4.0, work_y + 3.5)
	hoist_mast.scale.y = mast_h
	hoist_mast.position.y = mast_h * 0.5
	# (the tower grows a section a level, the riser's rebuilt after a climb:
	# every so often, give any new parts the cut-away material)
	_cut_t -= delta
	if _cut_t <= 0.0:
		_cut_t = 0.5
		var roots: Array = [hoist_mast, hoist_cage, lattice, yaw_node.get_child(0)] + head_deco
		if climb != null:
			roots.append(climb.platform)
		if line != null:
			roots += line.ladder_rails + line.brackets + [line.ladder_rungs]
			for sec in line.sections:
				roots.append(sec["node"])
			for c in line.clamps:
				roots.append(c["node"])
		for r in roots:
			if r != null and is_instance_valid(r):
				_give_cut(r)
		# (and the boom's first arm and the ball at its foot; the outer arm
		# stays solid, it's what's being steered)
		if arm1 != null and is_instance_valid(arm1):
			for ch in arm1.get_children():
				if ch is GeometryInstance3D:
					_give_cut(ch)
	# The work: whatever the close-ups are on (a small circle: they're right
	# up close), then anyone on the deck and where the concrete's going in
	# (those not on a climb day, when the climbing frame and riser are the work)
	var ps: Array = []
	for q in _close_targets:
		if ps.size() < 2:
			ps.append(Vector4(q.x, q.y, q.z, CUT_R_CLOSE))
	_close_targets.clear()
	if not climb.active:
		for p in humans():
			if p.zone == "deck" and ps.size() < 5:
				ps.append(Vector4(p.position.x, p.position.y + 1.0, p.position.z, CUT_R))
		if phase == "pour":
			var d := discharge()
			ps.append(Vector4(d.x, d.y, d.z, CUT_R))
	var n := ps.size()
	while ps.size() < 6:
		ps.append(Vector4.ZERO)
	for m in _cut_mats.values():
		(m as ShaderMaterial).set_shader_parameter("cut_n", n)
		(m as ShaderMaterial).set_shader_parameter("cut_p", ps)

## Dev: whether the work's showing through `at` (on the hoist or tower) on screen.
func _cut_showing(at: Vector3) -> bool:
	var d := discharge()
	if camera.is_position_behind(at) or camera.is_position_behind(d):
		return false
	var near: bool = camera.global_position.distance_to(at) < camera.global_position.distance_to(d) - 3.0
	return near and camera.unproject_position(at).distance_to(camera.unproject_position(d)) < 60.0

## Swaps the cut-away copy of its own material onto `n` and everything under it.
func _give_cut(n: Node) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		var src: Material = gi.material_override
		if src == null:
			var mesh: Mesh = null
			if gi is MeshInstance3D:
				mesh = (gi as MeshInstance3D).mesh
			elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
				mesh = (gi as MultiMeshInstance3D).multimesh.mesh
			if mesh != null and mesh.get_surface_count() > 0:
				src = mesh.surface_get_material(0)
		var cut := _cut_of(src)
		if cut != null:
			gi.material_override = cut
	for ch in n.get_children():
		_give_cut(ch)

func _cut_of(src: Material) -> Material:
	if src == null:
		return null
	if _cut_mats.values().has(src):
		return src
	if _cut_mats.has(src):
		return _cut_mats[src]
	if not (src is ShaderMaterial and (src as ShaderMaterial).shader == F.TOON):
		return null
	var m := ShaderMaterial.new()
	m.shader = TOON_CUT
	for k in ["albedo", "emission_color", "rim_amount"]:
		var v = (src as ShaderMaterial).get_shader_parameter(k)
		if v != null:
			m.set_shader_parameter(k, v)
	var nxt := src.next_pass
	if nxt is ShaderMaterial and (nxt as ShaderMaterial).shader == F.OUTLINE:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE_CUT
		for k in ["color", "thickness"]:
			var v = (nxt as ShaderMaterial).get_shader_parameter(k)
			if v != null:
				o.set_shader_parameter(k, v)
		m.next_pass = o
		_cut_mats[nxt] = o
	_cut_mats[src] = m
	return m

func _update_camera(delta: float) -> void:
	# Who's up top and who's down on the street. While the deck's low, one
	# camera takes in everyone. Once it's up past SPLIT_Y with people at both
	# heights, the screen splits: the deck on top, a street band along the
	# bottom. Anyone partway up the ladder gets a marker on the line between
	# the two, and their own close-up while they work.
	var up: Array = []
	var down: Array = []
	var mid: Array = []
	for p in humans():
		match _height_group(p):
			"deck": up.append(p)
			"street": down.append(p)
			_: mid.append(p)
	# Split when the deck and the street are far apart, by height (up the
	# building) or by distance (the truck bay's 20 m from the deck even on
	# level 1): one camera over both shrinks everyone to specks
	var apart := false
	if not up.is_empty() and not down.is_empty():
		var ua := Vector3.ZERO
		for p in up:
			ua += p.position
		ua /= up.size()
		var da := Vector3.ZERO
		for p in down:
			da += p.position
		da /= down.size()
		apart = work_y >= SPLIT_Y or ua.distance_to(da) > SPLIT_DIST
	# (and not while the slab report's up: it needs the whole screen)
	var split_on: bool = Settings.value("split")
	var want_split := split_on and apart and not skyline and not (phase in ["roles", "select", "topout", "screed", "sign", "cure"])
	_split = move_toward(_split, 1.0 if want_split else 0.0, delta * 1.4)
	var split_e := ease(_split, -1.8)
	var main_follow: Array = []
	var away: Array = []
	if want_split or _split > 0.5:
		main_follow = up
		away = mid
	else:
		# One camera for all: everyone in frame while it's low enough
		# (with the split turned off, one camera pulls back over everyone)
		main_follow = up + down if (not apart or not split_on) else up
		for p in humans():
			if not main_follow.has(p):
				away.append(p)
		if main_follow.is_empty() and not away.is_empty():
			main_follow = [away[0]]
			away.remove_at(0)
	var focus := Vector3(SC.x * 0.5, work_y + 3.0, SC.z * 0.5)
	var spread := 0.0
	# What the deck view has to keep in: the people up there, and the bin
	# while the boom's putting slurry or washout in it
	var pts: Array = []
	for p in main_follow:
		pts.append(p.position)
	if phase == "pour" and ops != null and ops.wants_bin() and not main_follow.is_empty() and main_follow[0].zone == "deck":
		pts.append(ops.bin_world())
	if pts.size() > 0:
		var avg := Vector3.ZERO
		for q in pts:
			avg += q
		avg /= pts.size()
		for q in pts:
			spread = maxf(spread, (q - avg).length())
		focus = focus.lerp(avg + Vector3(0, 2.5, 0), 0.72 if main_follow[0].zone == "deck" else 1.0)
	# Closer in on the people playing: one person gets a tighter shot, a few
	# get pulled back just enough to keep them all in
	var dist := maxf(cam_dist * 0.82, spread * 1.6 + 10.0) if pts.size() > 1 else cam_dist * 0.82
	# (split, the deck view's only the top two-thirds of the screen: back off
	# a little so its near edge isn't lost behind the street band)
	dist *= 1.0 + 0.22 * ease(_split, -1.8)
	# (never so far out that the crew are specks on a TV)
	dist = minf(dist, maxf(DIST_MAX if split_on else 70.0, cam_dist * 0.82))   # (the mouse wheel can still pull back)
	if climb.active:
		focus = focus.lerp(climb.focus_point(), 0.65)
		dist = minf(cam_dist, 27.0)
	var guiding: bool = climb.active and climb.stage == "guide"
	if guiding and not _dog_view and climb.stage_t < 0.1:
		_dog_view = true
		_yaw_before = cam_yaw
		_pitch_before = cam_pitch
	if _dog_view:
		if guiding:
			# From the south-south-east: the load, the tower and the dogman
			# (and their hand signals) side by side, nothing in front of them
			cam_yaw = lerp_angle(cam_yaw, 0.3, minf(1.0, delta * 2.0))
			cam_pitch = lerpf(cam_pitch, 0.5, minf(1.0, delta * 2.0))
			dist = minf(dist, 23.0)
			var dog = climb._dogman if climb._dogman != null else climb.dog_bot
			if dog != null:
				focus = focus.lerp(dog.global_position + Vector3(0, 2.0, 0), 0.2)
		else:
			cam_yaw = _yaw_before
			cam_pitch = _pitch_before
			_dog_view = false
	if phase == "select" or phase == "roles":
		focus = Vector3(4, 10, 0) + (Vector3(SC.x, 0, SC.z) if not tutorial else Vector3.ZERO) * 0.5
		dist = 60.0 if tutorial else 72.0
	if phase == "sign":
		# (straight down onto the wet square they're signing)
		focus = ink_centre()
		dist = 9.0
	if skyline:
		var top := maxf(head.position.y, (k + 1) * FH)
		# (the whole of Riverlight, both wings)
		focus = (Vector3.ZERO if tutorial else -REAL_ORIGIN) + Vector3(0, top * 0.45, -8.0)
		dist = maxf(110.0, top * 2.4)
	cam_focus = cam_focus.lerp(focus, minf(1.0, delta * 2.5))
	var off := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch)) * dist
	var want := cam_focus + off
	camera.position = camera.position.lerp(want, minf(1.0, delta * 3.0)) if _frames > 2 else want
	if not _shot_cam.is_empty():
		cam_focus = _shot_cam[0]
		camera.position = cam_focus + off.normalized() * float(_shot_cam[1])
	camera.look_at(cam_focus, Vector3.UP)
	if _fly_on and _shot_cam.is_empty():
		_fly_camera()
	# The deck view shifts up into the top part of the screen as the band opens
	camera.v_offset = -0.34 * split_e * camera.position.distance_to(cam_focus) * tan(deg_to_rad(camera.fov * 0.5))
	_update_band(delta, down, mid, split_e)
	# Shake is a smooth low wobble, capped, and can be turned off with F2
	var w: float = line.wear if line and line.fail_i >= 0 and line.pumping else 0.0
	var s_amt := minf(0.22, shake * 0.22 + w * w * 0.05) if shake_on else 0.0
	if s_amt > 0.0:
		var t := phase_t
		camera.position += Vector3(sin(t * 9.1 + 0.3) + 0.5 * sin(t * 17.3), sin(t * 8.3 + 1.7) + 0.5 * sin(t * 15.1 + 0.4), sin(t * 7.7 + 2.9)) * s_amt * 0.6

	# Picture-in-picture: close-ups of hands at work first (a clamp being
	# remade, a pin being driven, a slump test), then anyone off the deck
	var views: Array = []
	for p in humans():
		var f: Vector3 = work_focus(p)
		# (the street band already has the street close: no pop-up needed)
		if f.x != INF and not (_split > 0.5 and _height_group(p) == "street" and _slump_of(p) == null):
			views.append({"p": p, "focus": f, "close": true})
	# A failing clamp or a blocked pipe halfway up the tower gets its own view,
	# when it's a person who has to go and fix it (a bot's work gets none)
	var pump_op = crew.crew.get("pump")
	if phase == "pour" and line != null and pump_op != null and not pump_op.bot:
		var j: int = line.fix_i if line.fix_i >= 0 else line.fail_i
		var spot := Vector3.INF
		var what := ""
		if j >= 0:
			spot = line.clamps[j]["pos"]
			what = "C%d %s" % [j + 1, "BURST" if line.burst else ("BLOCKED PIPE" if line.job_kind == "block" else ("WEEPING" if line.job_kind == "" else "BEING SWAPPED"))]
		elif line.blocked and line.block_found and line.block_s >= 0:
			spot = line.clamps[line.block_s]["pos"]
			what = "BLOCKED PIPE above C%d" % (line.block_s + 1)
		if spot.x != INF:
			var seen := false
			for v in views:
				if (v["focus"] as Vector3).distance_to(spot) < 1.0:
					seen = true
			if not seen:
				views.push_front({"p": null, "focus": spot, "close": true, "label": "%s · %d m up" % [what, int(spot.y)]})
	if autotest and crew.humans().is_empty():
		away.clear()
	for p in away:
		var already := false
		for v in views:
			if v["p"] == p:
				already = true
		if not already:
			views.append({"p": p, "focus": p.position + Vector3(0, 1.2, 0), "close": false})
	# Each close-up is a zoom-in that pops up over the spot where the work is,
	# in whichever view shows it (the deck view, or the street band when
	# split), sized to the screen, kept inside that view and clear of the
	# others and of the pump. Anyone off the screen gets a small view in the
	# deck view's bottom right corner instead.
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var ph := clampf(vs.y * 0.2, 120.0, 230.0)
	var taken: Array = []
	var pump_spot := _pop_spot(line.PUMP_POS + Vector3(0, 1.5, 0), true) if line != null else {}
	if not pump_spot.is_empty() and pump_spot["seen"]:
		taken.append(Rect2(pump_spot["pt"] - Vector2(110, 90), Vector2(220, 170)))
	var corner_x := vs.x - 16.0
	for i in insets.size():
		var inset: Dictionary = insets[i]
		var box: SubViewportContainer = inset["box"]
		box.visible = i < views.size() and not skyline and phase != "roles" and phase != "select"
		var guide = inset["guide"]
		guide.visible = false
		if not box.visible:
			inset["key"] = null
			continue
		var v: Dictionary = views[i]
		var slump_view: bool = v["close"] and _slump_of(v["p"]) != null
		var sz := Vector2(ph * 1.6, ph) * (1.2 if slump_view else 1.0)
		var r := Rect2()
		if v["close"]:
			var street: bool = (v["focus"] as Vector3).y < 2.5 if v["p"] == null else _height_group(v["p"]) == "street"
			var spot := _pop_spot(v["focus"], street)
			var region: Rect2 = spot["region"]
			var gh := 0.0
			if slump_view:
				var sl = _slump_of(v["p"])
				guide.steps = line.slump.GUIDE.map(func(g): return g[1])
				guide.at = line.slump.guide_index(sl)
				guide.text = line.slump.guide_text(sl)
				guide.accent = UI.ROLE.get(v["p"].role, Color.WHITE)
			# (a short view: the zoom-in shrinks to fit inside it)
			for pass_i in 2:
				gh = guide.fit(sz.x) if slump_view else 0.0
				var k := minf(1.0, minf(region.size.y / (sz.y + gh), region.size.x / sz.x))
				if k >= 0.999:
					break
				sz *= k
			var whole := _place_pop(spot["pt"], Vector2(sz.x, sz.y + gh), region, taken)
			taken.append(whole)
			r = Rect2(whole.position + Vector2(0, gh), sz)
			if slump_view:
				guide.position = whole.position
				guide.visible = true
		else:
			sz = Vector2(ph * 1.3, ph * 0.8)
			var bottom := vs.y - 16.0 - _band_h
			r = Rect2(Vector2(corner_x - sz.x, bottom - sz.y), sz)
			corner_x -= sz.x + 14.0
			taken.append(r)
		box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		box.position = r.position
		box.size = r.size
		(inset["badge"] as Control).position = Vector2(6, sz.y - 76)
		inset["badge"].max_w = sz.x - 12.0
		var p = v["p"]
		var cam: Camera3D = inset["cam"]
		var target: Vector3 = v["focus"]
		var eye: Vector3
		var lab: Label = inset["label"]
		# Close-ups leave out the floating labels and glyphs (layer 2); the
		# small views of someone off screen keep the name tags but not the
		# button glyphs (layer 4), which are sized for the main camera and
		# would fill the view: the badge in the corner shows the button
		cam.cull_mask = 1 if v["close"] else (0xFFFFF & ~8)
		cam.fov = 42.0 if v["close"] else 55.0
		if v["close"]:
			# Look at the work from outside, a couple of metres off
			var out := Vector3(target.x - LAT_X, 0, target.z)
			if out.length() < 0.3:
				out = Vector3(0.3, 0, 1.0)
			eye = target + out.normalized() * 2.4 + Vector3(0, 0.9, 0)
			var sl = _slump_of(p)
			if sl != null:
				# The slump test: low and side on, cone, tape and all
				eye = line.slump.eye(sl)
			elif climb.active and climb.stage == "pin":
				# Side on to the hammer swing, from the hammer-arm side
				eye = climb.close_eye(target)
			elif p != null and p.zone == "ladder":
				eye = target + Vector3(-0.5, 0.45, 1.6)
			elif p != null and p.zone == "ground":
				eye = target + Vector3(-0.3, 1.1, 1.9)
			lab.text = v.get("label", _who(p) if p != null else "")
			if sl != null:
				lab.text = line.slump.caption(sl)
		else:
			eye = target + Vector3(-4.0, 8.5, -9.0)
			if p.zone == "hoist":
				eye = target + Vector3(6.0, 3.0, 7.0)
			if p.zone == "ladder":
				eye = target + Vector3(6.5, 1.0, 5.5)
			var where := {"ladder": "  ·  %d m up" % int(p.position.y), "hoist": "  ·  %d m" % int(p.position.y)}
			lab.text = _who(p) + where.get(p.zone, "")
		# The name chip wraps rather than running off the side of the box
		var cap_w := sz.x - 44.0
		var cap_font: Font = lab.get_theme_font("font")
		if cap_font.get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > cap_w:
			lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lab.custom_minimum_size.x = cap_w
		else:
			lab.autowrap_mode = TextServer.AUTOWRAP_OFF
			lab.custom_minimum_size.x = 0.0
		(inset["chip_node"] as Control).reset_size()
		# (the slump test's guide strip on top says it all: no name chip)
		(inset["chip_node"] as Control).visible = not slump_view
		# Framed in the colour of the job it's watching (the pump operator's colour, who fixes it, for a
		# failing clamp or pipe)
		var role_col: Color = UI.ROLE.get(p.role, Color.WHITE) if p != null else UI.ROLE["pump"]
		(inset["frame"] as StyleBoxFlat).border_color = role_col
		(inset["chip"] as StyleBoxFlat).bg_color = role_col
		(inset["icon"] as TextureRect).texture = Icons.texture(p.role if p != null else "pump", 64)
		# The player's own button cue, for timing what they see in here
		var badge = inset["badge"]
		badge.dot_color = role_col
		var cue: Array = (p.cues[0] as Array).duplicate() if p != null and (not p.bot or _bot_badges) and not p.cues.is_empty() else []
		if slump_view and not cue.is_empty():
			cue[1] = ""   # (just the button: the guide strip says the step)
		badge.show_cue(cue)
		var key := str(v["close"]) + str(p)
		if climb.active and climb.stage == "pin" and v["close"]:
			key += climb.pin_sub   # cut to the new angle when the job changes
		if v["close"] and _slump_of(p) != null:
			key += "slump" + str(line.slump.step_of(_slump_of(p)) in ["measure", "done"])
		if inset.get("key") != key or cam.position.distance_to(eye) > 20.0:
			cam.position = eye
		else:
			cam.position = cam.position.lerp(eye, minf(1.0, delta * 4.0))
		inset["key"] = key
		cam.look_at(target, Vector3.UP)
		# Close-ups clip away only what's right at the lens (a hard hat going
		# past); the tower, the riser or the hoist in front of the work get the
		# soft see-through circle round it instead (_update_see_through)
		cam.near = clampf(cam.position.distance_to(target) - 1.2, 0.05, 1.4) if v["close"] else 0.05
		if v["close"] and _slump_of(p) != null:
			cam.near = 0.3   # (nothing in the way: the whole plate's in shot)
		if v["close"]:
			_close_targets.append(target)
	_update_gauge_pop()

# ------------------------------------------------------------------ autotest

func _maybe_shot() -> void:
	# Dev only. Rendering is switched off between shots so a software
	# renderer can fast-forward through the level.
	var key := ""
	var p2 = crew.crew["line"]
	var pp = crew.crew["pump"]
	var p3 = crew.crew["poker"]
	var sc = crew.crew["screed"]
	if "every" in _shot_only and phase in ["pour", "climb"] and not _shots_taken.has("every_%s_%03d" % [phase, int(phase_t / 6.0)]):
		key = "every_%s_%03d" % [phase, int(phase_t / 6.0)]
	elif "trans1" in _shot_only and _split > 0.2 and _split < 0.5 and not _shots_taken.has("trans1"):
		key = "trans1"
	elif "trans2" in _shot_only and _split > 0.45 and _split < 0.75 and not _shots_taken.has("trans2"):
		key = "trans2"
	elif "trans3" in _shot_only and _split > 0.75 and _split < 0.98 and not _shots_taken.has("trans3"):
		key = "trans3"
	elif "split" in _shot_only and phase == "pour" and _split >= 1.0 and _filled_ratio() > 0.3 and not _shots_taken.has("split"):
		key = "split"
	elif "docket" in _shot_only and phase == "pour" and line != null and line.needs_check() != null and line.needs_check()["checked"] and line.needs_check()["state"] == "bay" and line.right_call(line.needs_check()) != "use" and not _shots_taken.has("docket"):
		key = "docket"
	elif "tutorial" in _shot_only and tutorial and phase == "pour" and _filled_ratio() > 0.45 and not _shots_taken.has("tutorial"):
		key = "tutorial"
	elif "sling" in _shot_only and climb.needs_sling() and climb.sling_prog > 0.5 and not _shots_taken.has("sling"):
		key = "sling"
	elif "layout" in _shot_only and phase == "pour" and line != null and line.bay_truck != null and line.staged != null and _filled_ratio() > 0.2 and not _shots_taken.has("layout"):
		key = "layout"
	elif "startup" in _shot_only and ops != null and ops.stage == "slurry_out" and ops.left < ops.SLURRY * 0.6 and not _shots_taken.has("startup"):
		key = "startup"
	elif "washout" in _shot_only and ops != null and ops.stage == "push" and ops.left < ops.WATER * 0.8 and not _shots_taken.has("washout"):
		key = "washout"
	elif "tank" in _shot_only and ops != null and ops.stage == "valve" and ops.hold > 0.4 and not _shots_taken.has("tank"):
		key = "tank"
	elif "hose" in _shot_only and phase == "pour" and hose_holder != null and line.pumping and _filled_ratio() > 0.3 and not _shots_taken.has("hose"):
		key = "hose"
	elif "pinbag" in _shot_only and line != null and line.hook["kind"] == "pins" and line.hook["y"] > 4.0 and not _shots_taken.has("pinbag"):
		key = "pinbag"
	elif "staff" in _shot_only and screed != null and screed._spin_t > 1.0 and phase in ["pour", "climb", "inspect"] and not _shots_taken.has("staff"):
		key = "staff"
	elif "remote" in _shot_only and phase == "pour" and line != null and line.fix_i >= 0 and line._step_name() == "depress" and line.reversing_seen and not _shots_taken.has("remote"):
		key = "remote"
	elif "highlow" in _shot_only and phase == "pour" and speed_advice["want"] != "" and speed_advice["level"] >= 1 and _filled_ratio() > 0.2 and not _shots_taken.has("highlow"):
		key = "highlow"
	elif "cut" in _shot_only and phase == "pour" and _cut_showing(Vector3(head.position.x, head.position.y - 2.0, head.position.z)) and not _shots_taken.has("cut"):
		key = "cut"
	elif "cuthoist" in _shot_only and phase == "pour" and _cut_showing(Vector3(hoist_mast.position.x, work_y, hoist_mast.position.z)) and not _shots_taken.has("cuthoist"):
		key = "cuthoist"
	elif phase == "select":
		key = "select"
	elif phase == "roles":
		key = "roles"
	elif climb.active and climb.stage == "wreck" and climb.stage_t > 0.25:
		key = "wreck"
	elif phase == "pour" and line.hook["state"] == "rising" and line.hook["y"] > 3.0 and not _shots_taken.has("haul"):
		key = "haul"
	elif phase == "pour" and k == 1 and _filled_ratio() > 0.6 and "pause" in _shot_only and not _shots_taken.has("pause"):
		key = "pause"
	elif phase == "pour" and k == 1 and _filled_ratio() > 0.45:
		key = "pour"
	elif phase == "pour" and line.fail_i >= 0 and line.wear > 0.2 and not _shots_taken.has("clamp"):
		key = "clamp"
	elif phase == "pour" and p2 != null and p2.zone == "ladder" and line.fix_i >= 0 and line._step_name() == "depress" and line.joint_near(p2) == line.fix_i and "depress" in _shot_only:
		key = "depress"
	elif phase == "pour" and p2 != null and p2.zone == "ladder" and line.job_kind != "" and line._step_name() in ["clean", "kit", "close"]:
		key = "ladder"
	elif phase == "pour" and p3.tool == "poker" and poker._state(p3)["state"] == "in" and poker._state(p3)["t"] > 0.5 and k >= 2 and _filled_ratio() > 0.35:
		key = "poker"
	elif phase == "pour" and line.needs_check() != null and line.needs_check()["state"] == "check" and line.needs_check().has("sl") and _slump_shot(line.needs_check()["sl"]) != "":
		key = _slump_shot(line.needs_check()["sl"])
	elif phase == "pour" and line.bay_truck != null and line.bay_truck["state"] == "pour" and line.staged != null and k >= 2:
		key = "trucks"
	elif phase == "pour" and sc.tool == "screed" and sc.action_held() and k >= 1 and _filled_ratio() > 0.5:
		key = "screed"
	elif phase == "pour" and k >= 1 and _sign_count >= 3 and _sign_red:
		key = "signs"
	elif phase == "screed" and k == 2 and phase_t > 0.9:
		key = "grade"
	elif phase == "inspect" and k == 1 and phase_t > 1.0:
		key = "inspect"
	elif phase == "cure" and k == 1 and phase_t > 0.5 and "report" in _shot_only:
		key = "report"
	elif climb.active and climb.stage == "guide" and k == 3 and climb.stage_t > 4.0:
		key = "guide"
	elif climb.active and climb.stage == "pin" and k == 3 and climb.pin_i == 1 and climb.pin_sub == "drive" and climb.winding and climb.power > 0.45:
		key = "pin"
	elif climb.active and climb.stage == "pin" and k == 3 and climb.pin_i == 2 and climb.pin_sub == "drive" and climb._strike_t > 0.0:
		key = "strike"
	elif climb.active and climb.stage == "pin" and k >= 3 and climb.pin_i >= 1 and climb.pin_sub == "align" and climb.podger.visible and absf(climb._lever) > 0.3:
		key = "align"
	elif climb.active and climb.stage == "jack" and k == 9 and climb.lifted > 2.0:
		key = "jack"
	elif "dawn1" in _shot_only and phase == "pour" and is_dawn() and _filled_ratio() > 0.06 and not _shots_taken.has("dawn1"):
		key = "dawn1"
	elif "dawn2" in _shot_only and phase == "pour" and is_dawn() and _filled_ratio() > 0.5 and not _shots_taken.has("dawn2"):
		key = "dawn2"
	elif "dawn3" in _shot_only and phase == "pour" and is_dawn() and _filled_ratio() > 0.93 and not _shots_taken.has("dawn3"):
		key = "dawn3"
	elif "sign" in _shot_only and phase == "sign" and phase_t > 2.5 and not _shots_taken.has("sign"):
		key = "sign"
	elif "signed" in _shot_only and phase == "sign" and _ink_sealed >= 0.0 and phase_t - _ink_sealed > 0.6 and not _shots_taken.has("signed"):
		key = "signed"
	elif "lastreport" in _shot_only and phase == "cure" and k == floors() - 1 and phase_t > 0.5 and not _shots_taken.has("lastreport"):
		key = "lastreport"
	elif _fly_on and "fly1" in _shot_only and _fly_t > 3.5 and not _shots_taken.has("fly1"):
		key = "fly1"
	elif _fly_on and "fly2" in _shot_only and _fly_t > 10.0 and not _shots_taken.has("fly2"):
		key = "fly2"
	elif _fly_on and "fly3" in _shot_only and _fly_t > 20.0 and not _shots_taken.has("fly3"):
		key = "fly3"
	elif phase == "topout" and phase_t > 1.5 and "vista" in _shot_only and not _shots_taken.has("vista"):
		key = "vista"
	elif phase == "topout" and phase_t > 1.5 and "vista2" in _shot_only and not _shots_taken.has("vista2"):
		key = "vista2"
	elif phase in ["pour", "topout"] and (phase == "topout" and phase_t > 1.5 or phase == "pour" and _filled_ratio() > 0.4 and not "ext_at_end" in _shot_only) and _next_ext() != "":
		key = _next_ext()
	elif phase == "topout" and phase_t > 0.6:
		key = "topout"
	if key != "" and not _shot_only.is_empty() and not (key in _shot_only) and not key.begins_with("every"):
		_shots_taken[key] = true
	var want := key != "" and not _shots_taken.has(key)
	if not want:
		_shot_wait = 0
		_shot_cam = []
		RenderingServer.render_loop_enabled = false
		return
	RenderingServer.render_loop_enabled = true
	# Frame the shot on whoever's doing the thing, the way one person playing
	# that job would see it
	var subject = null
	match key:
		"poker": subject = p3
		"screed": subject = sc
		"trucks", "remote": subject = pp
		"slump", "slumplift", "slumptape": subject = null   # (the game's own view, close-up and all)
		"staff": subject = sc
		"haul": subject = line.hook_node
		"ladder", "clamp": subject = p2
		"signs": subject = crew.crew["boom"]
	_shot_cam = []
	if subject != null and _cam_roles.is_empty():   # (with --cam, shoot the game's own camera)
		var dist := 15.0 if key in ["poker", "screed"] else 19.0
		_shot_cam = [subject.global_position + Vector3(0, 1.2, 0), dist]
	if key == "layout":
		_shot_cam = [Vector3(19.5, 0.0, 7.0), 24.0]
	if key in ["startup", "washout"] and _cam_roles.is_empty():
		_shot_cam = [ops.bin_world() + Vector3(-1.5, -0.5, 1.0), 12.0]
	if key == "hose":
		_shot_cam = [hose_holder.global_position + Vector3(0, 1.0, 0), 11.0]
	if key == "wreck" and climb.load != null:
		_shot_cam = [climb.load.global_position + Vector3(0, 2.0, 0), 24.0]
	if key == "signs":
		_shot_cam = [_sign_focus + Vector3(0, -1.0, 0), 17.0]
	if _weary_all and key == "poker":
		_shot_cam = [crew.crew["poker"].global_position + Vector3(0, 1.0, 0), 6.0]
	if key in ["pin", "strike", "align"] and climb._rigger != null and OS.get_cmdline_user_args().has("--closeshots"):
		_shot_cam = [climb._rigger.global_position + Vector3(0, 0.9, 0), 5.0]
	if key in ["vista", "vista2"]:
		# Out over the river from the top: downstream to the Gateway Bridge,
		# then upstream to the city
		cam_yaw = 1.4 if key == "vista" else -0.99
		cam_pitch = 0.08
		_shot_cam = [-REAL_ORIGIN + Vector3(0, 30, 0), 60.0]
	if EXT_SHOTS.has(key) and EXT_SHOTS[key].size() == 1:
		var t: Vector2 = EXT_SHOTS[key][0]
		var roof := floors() * FH + 8.0
		cam_yaw = atan2(-t.x, -t.y)
		cam_pitch = -0.02
		_shot_cam = [-REAL_ORIGIN + Vector3(t.x, roof + t.length() * 0.02, t.y), t.length()]
		_shot_key_now = key
		hud.visible = false
	elif EXT_SHOTS.has(key):
		var e: Array = EXT_SHOTS[key]
		cam_yaw = e[0]
		cam_pitch = e[1]
		_shot_cam = [-REAL_ORIGIN + Vector3(0, e[2], 0), e[3]]
		_shot_key_now = key
		hud.visible = false
	if key == "pause":
		pause_menu.visible = true
		pause_menu._build_page("main")
	_shot_wait += 1
	if _shot_wait < (8 if key == "align" else (7 if key == "strike" else (2 if key.begins_with("trans") else 4))):
		return
	_shots_taken[key] = true
	_shot_wait = 0
	var img := get_viewport().get_texture().get_image()
	if pause_menu.visible:
		pause_menu.visible = false
	_shot_key_now = ""
	img.save_png(shot_dir.path_join(key + ".png"))
	print("[autotest] saved screenshot ", key)

