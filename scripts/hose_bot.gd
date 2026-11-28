extends RefCounted
## How a good line hand works the end hose, for the bot (bots.gd _hose) to show anyone watching.
##
## The method: fill one spot to level, then step to the nearest spot that still wants it, so the
## concrete goes down as a face working back across the bay, not in hops. What only the hose can get
## to comes first: the strip under the jump form's edge, where the boom's tip can't follow. The hose
## never stands pumping onto concrete that's already up to level. And when a person's on the boom,
## the bot works whatever's in reach of where they've put the tip, and whistles them over to the
## next low spot when there's nothing left under it.

const RINGS := [0.0, 0.3, 0.55, 0.8, 0.97]   # of the hose's reach from under the tip
const SPOKES := 12
const FULL := 0.95           # of the slab's depth: a spot's done, move on
const OVER := 1.12           # ...and never pump onto more than this
const CALL_EVERY := 7.0      # s between "boom over here" calls to a person on the boom

var goal := Vector3.INF      # world, on the deck
var _call_t := 2.0
var _idle_t := 0.0           # s with nothing wanted in reach
const GIVE_UP := 4.0         # s held off over full concrete before it pumps where it stands
var _held_t := 0.0
var _give_at := Vector3.INF  # pour-local: where it gave up waiting

## Where the nozzle should be now. `anchor`: the deck under the boom tip. `nozzle`: where it is.
func spot(g, anchor: Vector3, nozzle: Vector3, delta: float) -> Vector3:
	var pour = g.pour
	var reach: float = g.HOSE_REACH
	# (the spot being filled stays the goal until it's up to level or the boom's dragged it out of reach)
	if goal.x != INF:
		var gl: Vector3 = g._pour_local(goal)
		var flat := Vector2(goal.x - anchor.x, goal.z - anchor.z).length()
		if flat <= reach * 0.99 and _wanted(g, gl) and pour.height_at(gl) < pour.SLAB * FULL:
			_idle_t = 0.0
			return goal
	var best := -INF
	var out := Vector3.INF
	for ri in RINGS.size():
		for si in (1 if ri == 0 else SPOKES):
			var a := TAU * float(si) / SPOKES + ri * 0.26
			var q: Vector3 = anchor + Vector3(cos(a), 0, sin(a)) * reach * float(RINGS[ri])
			var loc: Vector3 = g._pour_local(q)
			if not _wanted(g, loc):
				continue
			var need: float = clampf(1.0 - pour.height_at(loc) / pour.SLAB, 0.0, 1.0)
			var score := need
			# (only the hose gets in under the form: that's first)
			if _hose_only(g, q):
				score += 0.8
			# (the next spot along, not the far side of the circle)
			score -= 0.18 * Vector2(q.x - nozzle.x, q.z - nozzle.z).length()
			if score > best:
				best = score
				out = q
	goal = out
	if out.x != INF:
		_idle_t = 0.0
		return out
	# Nothing wanted in reach: wait under the tip, inside the bay, for the boom to move on
	_idle_t += delta
	var al: Vector3 = g._pour_local(anchor)
	var bxx: Vector2 = pour.bay_x(pour.cur_bay)
	return anchor + Vector3(clampf(al.x, bxx.x - bxx.y * 0.5 + 0.4, bxx.x + bxx.y * 0.5 - 0.6) - al.x, 0, 0)

## May the pump run with the nozzle at `dl` (pour-local)? Not onto concrete that's already over level,
## unless there's still a hollow in the splash to fill.
func may_pump(g, dl: Vector3, delta := 0.0) -> bool:
	var pour = g.pour
	if pour.height_at(dl) <= pour.SLAB * OVER:
		_held_t = 0.0
		return true
	# (held off a good while with a goal it never gets the nozzle to, the boom's leash stopping it
	# short, say: the pump sat idle on a full hopper for good. Pump where it stands till it's moved on)
	_held_t += delta
	if _held_t > GIVE_UP:
		_held_t = 0.0
		_give_at = dl
	if _give_at.x != INF:
		if Vector2(dl.x - _give_at.x, dl.z - _give_at.z).length() < 1.0:
			return true
		_give_at = Vector3.INF
	# (nothing it can find to fill, and the boom hasn't moved on either: pump where the boom's put
	# it, as the hose always did, before a full hopper sits waiting on a hollow the hose can't see)
	if _idle_t > 2.0:
		return true
	return pour.fill_need(dl, pour.splash_r) > 0.3

## A person's on the boom and there's been nothing wanted under it for a bit: whistle them over to
## the next low spot (the same "BOOM HERE" call a concreter makes). True when it called.
func call_boom(g, p, delta: float) -> bool:
	_call_t -= delta
	if _idle_t < 1.5 or _call_t > 0.0 or g.call_t > 0.0:
		return false
	var pour = g.pour
	var next: Vector3 = pour.next_face_point(pour.cur_bay, g._pour_local(g.discharge()))
	if next.x == INF or not pour.on_slab(next) or pour.height_at(next) >= pour.SLAB * 0.8:
		return false
	_call_t = CALL_EVERY
	var at: Vector3 = pour.position + Vector3(next.x, 0, next.z)
	at.y = g.work_y
	g.call_boom(at)
	p.say("Boom, over here!")
	return true

## Concrete's wanted at `loc` (pour-local) now: the plan's own leading strip, or a low spot left
## behind in this bay or an earlier one.
func _wanted(g, loc: Vector3) -> bool:
	var pour = g.pour
	if pour.good_pour_spot(loc):
		return true
	return pour.on_slab(loc) and pour.height_at(loc) < pour.SLAB * 0.8 and pour.bay_of_x(loc.x) <= pour.cur_bay \
		and pour.bay_of_x(loc.x + 0.9) <= pour.cur_bay

## Can only the end hose get there (Spire: the tip's kept off the jump form)?
func _hose_only(g, q: Vector3) -> bool:
	if not g.spire or g.head == null:
		return false
	return bool(g.rig_clear(Vector3(q.x, g.tip_target.y, q.z), g.head.global_position, g.l1, g.l2)[1])
