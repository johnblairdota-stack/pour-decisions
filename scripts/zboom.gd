## A four-arm Z-fold placing boom, as on Spire's square column: a Putzmeister MXR (the Tannery's was
## logged as an MXR 36-4 T; the nearest published four-arm Z boom of that reach is the MX 36/40Z, whose
## arm lengths and joint angles these are). Four box arms, each joint opening the opposite way to the
## one before it so the lot stacks like a folded rule; one ram a joint; the 125 mm line along the arms
## with a swivel at every knuckle; a 3 m end hose.
##
## It can't slew for ever: the hydraulic hoses and the power cable run up through the slewing ring, so
## a stop lets it turn SLEW each way from the middle of its swing and no further (540 degrees in all).
##
## It hangs off the boom's slewing head (main.yaw_node: +x out along the boom) and is posed in that
## vertical plane: pose(d, ty) puts the tip `d` out and `ty` up from the first arm's pivot.
extends Node3D

const F := preload("res://scripts/factory.gd")
const Settings := preload("res://scripts/settings.gd")

const L := [9.40, 8.41, 8.74, 8.56]                 # m, arm 1 to 4
const H := [0.56, 0.48, 0.42, 0.34]                 # each arm's box, deep
const W := [0.36, 0.32, 0.28, 0.24]                 # ...and wide
# What each joint can do, as turns DOWN from the arm before (arm 1: up from level). Real openings:
# 102 deg (arm 1, from 10 below level), 180, 245 and 233.
const LIM := [[-0.1745, 1.6057], [0.0, PI], [-PI, 1.1345], [-0.925, PI]]
# Folded: the arms stacked level over the pedestal, 1 on top
const STOWED := [0.0, PI, -PI, PI]
# Carried: a loose Z up in the air, where it goes before folding and comes to after unfolding
const CARRY := [1.22, 2.09, -1.75, 1.75]
# Working: how far joints 2, 3 and 4 are bent with the boom wound right in (they bend together, in
# these shares), and how far "right in" is: past it the tip starts going back out again.
const CURL := [2.007, 1.1345, 2.618]
const CURL_MAX := 0.87
# How fast each joint's ram can turn it, rad/s (arm 1's is the big slow one)
const SLEW := PI * 1.5        # rad either way from the middle before the stop
const RATE := [0.22, 0.30, 0.36, 0.45]

var arms: Array[Node3D] = []
var tip: Node3D
var hose_end: Node3D
var ang: Array = [1.0, 1.0, -0.5, 1.0]             # the joints as they stand
var _at: Array = [1.0, 1.0, -0.5, 1.0]             # ...less the shake
var _off: Array = [0.0, 0.0, 0.0, 0.0]             # each pivot's step off the arm before's centre line
var _rams: Array = []                              # [barrel, rod, node a, local a, node b, local b]

## The Tannery boom's paint for the modelled boom parts (turret, collar, tip, the other crew's arms):
## white where the stock ones are yellow or orange. Hand it to F.prop as `per`.
static func white_kit() -> Dictionary:
	return {"machine": F.color_mat(Color("e3e5e2"), true), "machine_dark": F.color_mat(Color("c3c7c6"), true),
		"orange": F.color_mat(Color("d3d6d4"), true)}

## Where a column `length` m tall is pinned together, m up from its foot. It's made of 11 m, 9 m and
## 2 m sections (John, 24 Nov): an 11 at the bottom, a 9 on that, then 2 m make-up pieces, with the
## foot's own pins just above the base as on unit 531.
static func joints(length: float, top_down := false) -> Array:
	if top_down:
		# (Spire's column in its penetration: the 9 m crow's nest section on top, an 11 m under it, a
		# short foot section making up the rest)
		var down: Array = []
		for d in [20.0, 9.0]:
			if length - d > 1.4:
				down.append(length - d)
		return down
	var out: Array = [0.9]
	var y := 0.0
	for sec in [11.0, 9.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0]:
		y += sec
		if y > length - 1.6:
			break
		out.append(y)
	return out

## The X base ("crucifix") a free-standing column stands on, from John's photo of unit 531 and
## Putzmeister's "compact cruciform base with tie-rod basket": a white box hub under the column's flange,
## four short box arms out on the diagonals (two round holes in each side, a red lifting lug on top).
## Built from the slab (y 0) up; the column's foot sits down in the hub. ARM_R: the arms' ends from the
## middle. (Sizes read off the photo against the 1 m column: not published.)
const XB_R := 1.62
const XB_H := 0.42
static func xbase() -> Node3D:
	var n := Node3D.new()
	n.name = "XBase"
	var white := F.color_mat(Color("eceeed"))
	var red := F.color_mat(Color("d3202f"))
	var dark := F.color_mat(Color("1d1f22"))
	var bolt := F.color_mat(Color("8d9196"))
	n.add_child(F.box(Vector3(1.34, XB_H, 1.34), white, Vector3(0, XB_H * 0.5, 0)))
	n.add_child(F.box(Vector3(1.5, 0.05, 1.5), white, Vector3(0, XB_H + 0.025, 0)))
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		var arm := Node3D.new()
		arm.rotation.y = -a
		n.add_child(arm)
		# (along the arm's own +x)
		arm.add_child(F.box(Vector3(XB_R - 0.5, XB_H, 0.4), white, Vector3((XB_R + 0.5) * 0.5, XB_H * 0.5, 0)))
		for hx in [0.95, 1.3]:
			for sz in [-0.205, 0.205]:
				var hole := F.cylinder(0.075, 0.01, dark, Vector3(hx, XB_H * 0.5, sz), 10)
				hole.rotation.x = PI * 0.5
				arm.add_child(hole)
		arm.add_child(F.box(Vector3(0.16, 0.14, 0.04), red, Vector3(1.0, XB_H + 0.07, 0)))
	# (the ring of M30 bolts through the column's flange)
	for i in 16:
		var a := i * TAU / 16.0
		var q := Vector3(cos(a), 0, sin(a)) * 0.68
		q.x = clampf(q.x * 1.3, -0.62, 0.62)
		q.z = clampf(q.z * 1.3, -0.62, 0.62)
		n.add_child(F.cylinder(0.025, 0.05, bolt, Vector3(q.x, XB_H + 0.07, q.z), 6))
	return n

## What holds the X base down: two threaded rods cast in the slab either side of each arm's end, on timber
## packers (`rods`), and the rusty clamp plate across each arm on them, nutted down (`clamps` of them on).
static func xbase_hold(clamps := 4) -> Node3D:
	var n := Node3D.new()
	n.name = "XBaseHold"
	var rust := F.color_mat(Color("7a4a2c"))
	var rod := F.color_mat(Color("6d5a4a"))
	var timber := F.color_mat(Color("b08a55"))
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		var arm := Node3D.new()
		arm.rotation.y = -a
		n.add_child(arm)
		for sz in [-0.3, 0.3]:
			arm.add_child(F.cylinder(0.018, XB_H + 0.3, rod, Vector3(XB_R - 0.22, (XB_H + 0.3) * 0.5, sz), 6))
			arm.add_child(F.box(Vector3(0.2, 0.05, 0.12), timber, Vector3(XB_R - 0.22, 0.025, sz)))
		if i < clamps:
			arm.add_child(F.box(Vector3(0.14, 0.04, 0.78), rust, Vector3(XB_R - 0.22, XB_H + 0.04, 0)))
			for sz in [-0.3, 0.3]:
				arm.add_child(F.cylinder(0.04, 0.05, rust, Vector3(XB_R - 0.22, XB_H + 0.085, sz), 6))
	return n

## One column section on its own, `length` long, for the crane to stand up: hung from its top (the
## origin), the red delivery pipe in its face and the galvanised ladder over it, as it comes off the truck.
static func section(length: float, h: float) -> Node3D:
	var n := Node3D.new()
	var white := F.color_mat(Color("eceeed"))
	var red := F.color_mat(Color("d3202f"))
	var galv := F.color_mat(Color("b4bcc1"))
	var dark := F.color_mat(Color("1d1f22"))
	n.add_child(F.box(Vector3(h * 2.0, length, h * 2.0), white, Vector3(0, -length * 0.5, 0)))
	n.add_child(F.cylinder(0.08, length, red, Vector3(h + 0.02, -length * 0.5, 0.12), 8))
	for sz in [-0.28, 0.28]:
		n.add_child(F.box(Vector3(0.05, length, 0.05), galv, Vector3(h + 0.27, -length * 0.5, 0.12 + sz)))
	var y := 0.3
	while y < length:
		n.add_child(F.box(Vector3(0.05, 0.05, 0.56), galv, Vector3(h + 0.27, -y, 0.12)))
		y += 0.7
	for ey in [0.25, length - 0.25]:
		for sx in [-0.3, 0.3]:
			for f in [-1.0, 1.0]:
				n.add_child(F.box(Vector3(0.12, 0.12, 0.01), dark, Vector3(sx, -ey, f * (h + 0.005))))
	for sx in [-0.16, 0.16]:
		n.add_child(F.box(Vector3(0.05, 0.3, 0.22), red, Vector3(sx, 0.15, 0)))
	return n

## The paint and fittings an SCP column carries, from John's photos of unit 531: the four black pin
## holes each side of every section joint (joints()), the upright
## name between two red bars and the unit number on the face looking `face` (+1/-1 along z), the red
## rail the delivery line clamps to on the side `side` (+1/-1 along x), and the hose and cable bundle
## coiled on the platform (`plat_y`). `col`: the column, built along +y from 0, `h` half its width.
static func dress_column(col: Node3D, length: float, h: float, face: float, side: float, unit: String, plat_y: float, line_z := 0.12, top_down := false, logo := true) -> void:
	var red := F.color_mat(Color("d3202f"))
	var black := F.color_mat(Color("1d2126"))
	var seam := F.color_mat(Color("aeb3b3"))
	for y in joints(length, top_down):
		col.add_child(F.box(Vector3(h * 2.0 + 0.012, 0.025, h * 2.0 + 0.012), seam, Vector3(0, y, 0)))
		for dy in [-0.2, 0.2]:
			for a in [-0.3, 0.3]:
				for f in [-1.0, 1.0]:
					col.add_child(F.box(Vector3(0.1, 0.1, 0.02), black, Vector3(a, y + dy, f * (h + 0.006))))
					col.add_child(F.box(Vector3(0.02, 0.1, 0.1), black, Vector3(f * (h + 0.006), y + dy, a)))
	# The name, read down the column
	# (only the crow's nest section carries it: John, 25 Nov)
	var name_y := length - 4.2
	if name_y > 3.0 and logo:
		var txt := "\n".join(Settings.brand("pumper").split(""))
		var lab := Label3D.new()
		lab.text = txt
		lab.add_to_group("brand_pumper_upright")
		lab.font_size = 150
		lab.pixel_size = 0.0042
		lab.line_spacing = -18.0
		lab.outline_size = 0
		lab.modulate = Color("2a2f36")
		lab.position = Vector3(0, name_y, face * (h + 0.012))
		lab.rotation.y = 0.0 if face > 0.0 else PI
		col.add_child(lab)
		var half := 0.33 * float(maxi(1, Settings.brand("pumper").length()))
		for e in [-1.0, 1.0]:
			col.add_child(F.box(Vector3(0.42, 0.09, 0.012), red, Vector3(0, name_y + e * (half + 0.12), face * (h + 0.008))))
		var un := Label3D.new()
		un.text = "UNIT No\n" + unit
		un.font_size = 40
		un.pixel_size = 0.0036
		un.outline_size = 0
		un.modulate = Color("2a2f36")
		un.position = Vector3(0, name_y - half - 0.42, face * (h + 0.012))
		un.rotation.y = 0.0 if face > 0.0 else PI
		col.add_child(un)
	# The V recess the line sits in, down the line's side (a shade darker: it's in shadow)
	col.add_child(F.box(Vector3(0.012, length - 0.3, 0.5), seam, Vector3(side * (h + 0.006), length * 0.5, line_z)))
	# The bundle on the platform
	var coil := F.cylinder(0.3, 0.22, black, Vector3(-side * 0.75, plat_y + 0.16, face * 0.8), 10)
	col.add_child(coil)

## The crow's nest's work platform round the column's top, at `py` up it: its U (chequer plate and rails
## on three sides, the -x side open: the flat side the section lies on), and with `whole` the last side too.
static func nest_parts(py: float, whole: bool) -> Array:
	var out: Array = []
	var grate := F.color_mat(Color("e3e5e2"))
	var kick := F.color_mat(Color("c3c7c6"))
	var x0 := -1.0 if whole else -0.5
	var x1 := 1.5
	var w := 2.5
	out.append(F.box(Vector3(x1 - x0, 0.08, w), grate, Vector3((x0 + x1) * 0.5, py, 0)))
	for sz in [-1.0, 1.0]:
		for hy in [0.55, 1.1]:
			out.append(F.box(Vector3(x1 - x0, 0.06, 0.06), grate, Vector3((x0 + x1) * 0.5, py + hy, sz * w * 0.5)))
		out.append(F.box(Vector3(x1 - x0, 0.15, 0.06), kick, Vector3((x0 + x1) * 0.5, py + 0.08, sz * w * 0.5)))
		for px in [x0, x1]:
			out.append(F.box(Vector3(0.06, 1.1, 0.06), grate, Vector3(px, py + 0.55, sz * w * 0.5)))
	for px in ([x1, x0] if whole else [x1]):
		for hy in [0.55, 1.1]:
			out.append(F.box(Vector3(0.06, 0.06, w), grate, Vector3(px, py + hy, 0)))
		out.append(F.box(Vector3(0.06, 0.15, w), kick, Vector3(px, py + 0.08, 0)))
	return out

static func reach() -> float:
	return L[0] + L[1] + L[2] + L[3]

func build(shoulder: float, hose: float) -> void:
	# (the Tannery's, from John's photo of it on the hook: light grey arms, red line and rams)
	var body := F.color_mat(Color("e3e5e2"))
	var dark := F.color_mat(Color("4a5058"))
	var pipe := F.color_mat(Color("c4281c"))
	var chrome := F.color_mat(Color("d5dade"))
	var barrel := F.color_mat(Color("c4281c"))
	var parent: Node3D = self
	for i in 4:
		var a := Node3D.new()
		a.name = "Arm%d" % (i + 1)
		if i == 0:
			a.position = Vector3(0, shoulder, 0)
		else:
			# (each knuckle steps the next arm off to the far side from the one before: that's what lets
			# them stack)
			_off[i] = (H[i - 1] + H[i]) * 0.5 + 0.06
			if i % 2 == 1:
				_off[i] = -_off[i]
			a.position = Vector3(L[i - 1], _off[i], 0)
		parent.add_child(a)
		arms.append(a)
		parent = a
		var ln: float = L[i]
		# The box section, its knuckle plates and pin, and the line along its side
		a.add_child(F.box(Vector3(ln, H[i], W[i]), body, Vector3(ln * 0.5, 0, 0)))
		for side in [-1.0, 1.0]:
			a.add_child(F.box(Vector3(0.7, H[i] + 0.22, 0.04), dark, Vector3(0.2, 0, side * (W[i] * 0.5 + 0.03))))
			if i < 3:
				var nxt: float = _next_off(i)
				a.add_child(F.box(Vector3(0.6, absf(nxt) + H[i] * 0.5 + 0.2, 0.04), dark,
					Vector3(ln - 0.05, nxt * 0.5, side * (W[i] * 0.5 + 0.03))))
		var pin := F.cylinder(0.09, W[i] + 0.5, dark, Vector3.ZERO, 8)
		pin.rotation.x = PI * 0.5
		a.add_child(pin)
		var pz: float = W[i] * 0.5 + 0.13
		var run := F.cylinder(0.07, ln - 0.5, pipe, Vector3(ln * 0.5, 0, pz), 8)
		run.rotation.z = PI * 0.5
		a.add_child(run)
		for bx in [0.25, ln - 0.25]:
			a.add_child(F.box(Vector3(0.16, 0.16, 0.16), pipe, Vector3(bx, 0, pz)))
		for cl in int(ln / 2.4):
			a.add_child(F.box(Vector3(0.06, 0.2, 0.2), dark, Vector3(1.4 + cl * 2.4, 0, pz)))
	tip = Node3D.new()
	tip.position.x = L[3]
	arms[3].add_child(tip)
	tip.add_child(F.prop("BoomTip", white_kit(), F.TOWERS))
	var hang := F.cylinder(0.17, hose, F.mat("hose"), Vector3(0, -hose * 0.5, 0), 8)
	hang.name = "Hose"
	tip.add_child(hang)
	hose_end = Node3D.new()
	hose_end.position.y = -hose
	tip.add_child(hose_end)
	# The slewing head's work platform, behind arm 1's pivot: a checker-plate deck with a handrail
	# round it. It rides on the boom when the crane lifts the lot.
	var deck_y := shoulder + H[0] * 0.5 + 0.04
	add_child(F.box(Vector3(1.9, 0.06, 1.3), dark, Vector3(-0.85, deck_y, 0)))
	for px in [-1.78, -0.85, 0.08]:
		for pz in [-0.63, 0.63]:
			add_child(F.box(Vector3(0.05, 1.0, 0.05), body, Vector3(px, deck_y + 0.5, pz)))
	for ry in [0.5, 1.0]:
		for pz in [-0.63, 0.63]:
			add_child(F.box(Vector3(1.9, 0.04, 0.04), body, Vector3(-0.85, deck_y + ry, pz)))
		add_child(F.box(Vector3(0.04, 0.04, 1.3), body, Vector3(-1.78, deck_y + ry, 0)))
	# The rams: one a joint. Arm 1's stands on the pedestal under it; the others lie along the outside
	# of their knuckle, so they close up as the joint folds.
	_ram(barrel, chrome, 0.11, 2.1, self, Vector3(1.25, shoulder - 0.95, 0), arms[0], Vector3(3.4, -H[0] * 0.5 - 0.06, 0))
	for i in range(1, 4):
		var s := -signf(_off[i])
		_ram(barrel, chrome, 0.1 - 0.012 * i, 1.4, arms[i - 1], Vector3(L[i - 1] - 2.0, s * (H[i - 1] * 0.5 + 0.12), 0),
			arms[i], Vector3(1.3, s * (H[i] * 0.5 + 0.12), 0))
	_apply()

func _next_off(i: int) -> float:
	var o: float = (H[i] + H[i + 1]) * 0.5 + 0.06
	return -o if (i + 1) % 2 == 1 else o

func _ram(barrel: Material, rod: Material, r: float, body: float, na: Node3D, la: Vector3, nb: Node3D, lb: Vector3) -> void:
	var b := F.cylinder(r, 1.0, barrel, Vector3.ZERO, 8)
	var rd := F.cylinder(r * 0.55, 1.0, rod, Vector3.ZERO, 6)
	add_child(b)
	add_child(rd)
	_rams.append([b, rd, na, la, nb, lb, body])

## Where the tip ends up for joint turns `q` (in the boom's plane, from arm 1's pivot).
func _tip_of(q: Array) -> Vector2:
	var p := Vector2.ZERO
	var dir := 0.0
	for i in 4:
		dir = q[0] if i == 0 else dir - float(q[i])
		if i > 0:
			p += Vector2(-sin(dir), cos(dir)) * float(_off[i])
		p += Vector2(cos(dir), sin(dir)) * float(L[i])
	return p

## How far out the tip is, and how far its line sits off arm 1's, with the boom curled `c` (0 dead
## straight .. CURL_MAX wound right in).
func _curl(c: float) -> Vector2:
	var p := Vector2.ZERO
	var dir := 0.0
	for i in 4:
		if i > 0:
			dir -= c * float(CURL[i - 1])
		p += Vector2(cos(dir), sin(dir)) * float(L[i])
	return Vector2(p.length(), atan2(p.y, p.x))

## The joint turns that put the tip `d` out and `ty` up, the way a Z boom's worked: every joint
## bends the same way, so it's one arch from the pedestal over to the hose. Stretched out the arch is
## shallow; drawn in, arm 1 stands up and the others curl over and down under it.
func _solve(d: float, ty: float) -> Array:
	var dist := clampf(sqrt(d * d + ty * ty), _curl(CURL_MAX).x, reach() - 0.05)
	var phi := atan2(ty, d)
	var lo := 0.0
	var hi := CURL_MAX
	for it in 20:
		var m := (lo + hi) * 0.5
		if _curl(m).x > dist:
			lo = m
		else:
			hi = m
	var q := [phi - _curl(lo).y, lo * float(CURL[0]), lo * float(CURL[1]), lo * float(CURL[2])]
	for i in 4:
		q[i] = clampf(q[i], LIM[i][0], LIM[i][1])
	return q

## With the tip `d` out and `ty` up, do all four arms pass clear of something standing from `r0` to
## `r` m out and `top` high (from arm 1's pivot)? The jump form, for main.rig_arms_clear: a Z boom
## arches over it and comes down steeply behind, which two straight halves can't.
func clears(d: float, ty: float, r0: float, r: float, top: float) -> bool:
	var q := _solve(d, ty)
	var p := Vector2.ZERO
	var dir := 0.0
	for i in 4:
		dir = float(q[0]) if i == 0 else dir - float(q[i])
		var e := p + Vector2(cos(dir), sin(dir)) * float(L[i])
		for n in 9:
			var pt := p.lerp(e, n / 8.0)
			if pt.x > r0 and pt.x < r and pt.y < top:
				return false
		p = e
	return true

## Poses the boom: the tip `d` out and `ty` up from arm 1's pivot, less however far it's folded away
## (`fold` 0 working .. 1 stowed: up to the carry first, then arms 4, 3, 2 fold in turn and arm 1
## comes down last; unfolding is the same backwards). `shake` is added to the joints (pump strokes, wind).
## With `dt` the joints move there at their rams' pace; without, they're put there.
func pose(d: float, ty: float, fold := 0.0, shake := 0.0, dt := 0.0) -> void:
	var want := Vector2(d, ty)
	var q := _solve(d, ty)
	# (the knuckles' steps put the tip a little off: aim off by the miss, twice)
	for it in 2:
		var miss := want - _tip_of(q)
		if miss.length() < 0.03:
			break
		var aim := Vector2(d, ty) + miss
		d = aim.x
		ty = aim.y
		q = _solve(d, ty)
	if fold > 0.0:
		var up := smoothstep(0.0, 0.22, fold)
		for i in 4:
			q[i] = lerpf(q[i], CARRY[i], up)
		# (4, then 3, then 2, then arm 1 down)
		for n in 4:
			var i := 3 - n
			var f := smoothstep(0.22 + 0.195 * n, 0.22 + 0.195 * (n + 1), fold)
			q[i] = lerpf(q[i], STOWED[i], f)
	# (rams only move so fast: each joint follows at its own rate, so a big move plays out as the
	# real thing does rather than snapping)
	if dt > 0.0:
		# (folding's paced by `fold` itself, so there the joints just keep up)
		var k := lerpf(1.0, 14.0, smoothstep(0.0, 0.08, fold))
		for i in 4:
			_at[i] = move_toward(_at[i], q[i], float(RATE[i]) * k * dt)
	else:
		_at = q.duplicate()
	# (folded for a lift, its end hose is off)
	(tip.get_node("Hose") as Node3D).visible = fold < 0.5
	ang = _at.duplicate()
	ang[0] += shake
	ang[1] -= shake * 0.6
	_apply()

func _apply() -> void:
	arms[0].rotation.z = ang[0]
	var sum: float = ang[0]
	for i in range(1, 4):
		arms[i].rotation.z = -float(ang[i])
		sum -= float(ang[i])
	tip.rotation.z = -sum
	for r in _rams:
		var a: Vector3 = _rel(r[2]) * (r[3] as Vector3)
		var b: Vector3 = _rel(r[4]) * (r[5] as Vector3)
		F.stretch(r[1], a, b)
		# (the barrel's a fixed length from its own end; the rod shows past it as the joint opens)
		var ln := a.distance_to(b)
		var bl := minf(ln, float(r[6]))
		F.stretch(r[0], a, a + (b - a).normalized() * bl if ln > 0.01 else b)

## `n`'s place in the boom's own frame (it's the boom itself or one of its arms).
func _rel(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != self and n != null:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t
