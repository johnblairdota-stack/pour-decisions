## Soak test for the street traffic (scripts/cars.gd): builds the
## surrounds, runs the drivers for a long while with no rendering, and
## reports anyone who's been sat still too long (a jam that never clears).
## With "block", a minute in it leaves a ute stopped in one car's lane
## (they should wait, then go round it) and one just off another's (on the
## verge or a roundabout's island: nobody should stop for it).
##   godot --headless --path . --script tools/traffic_soak.gd -- [minutes] [seed] [block]
extends SceneTree

const Surrounds := preload("res://scripts/surrounds.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var minutes := float(args[0]) if args.size() > 0 else 20.0
	var root := Node3D.new()
	get_root().add_child(root)
	Surrounds.build(root)
	var t: Node = root.find_child("Traffic", true, false)
	if t == null:
		print("[soak] no traffic")
		quit(1)
		return
	if args.size() > 1:
		t._rng.seed = int(args[1])
	var dt := 0.05
	var still := {}
	var worst := 0.0
	var jams := 0
	var steps := int(minutes * 60.0 / dt)
	var block := args.has("block")
	for k in steps:
		if block and k == int(60.0 / dt):
			var a: Dictionary = t._drivers[5]
			var b: Dictionary = t._drivers[7]
			var fa: Vector2 = a["fwd"]
			var fb: Vector2 = b["fwd"]
			t.blockers = [(a["p"] as Vector2) + fa * 14.0, (b["p"] as Vector2) + fb * 14.0 + Vector2(fb.y, -fb.x) * 3.6]
			print("[soak] utes left at %s (in the lane) and %s (off it)" % t.blockers)
		t._process(dt)
		for dv in t._drivers:
			var i: int = dv["i"]
			still[i] = float(still.get(i, 0.0)) + dt if float(dv["speed"]) < 0.2 else 0.0
			worst = maxf(worst, still[i])
		if k % int(60.0 / dt) == 0:
			var stuck: Array = t._drivers.filter(func(dv) -> bool: return float(still.get(dv["i"], 0.0)) > 45.0)
			if not stuck.is_empty():
				jams += 1
			print("[soak] %d min: %d stuck >45 s %s" % [k * dt / 60.0, stuck.size(),
				stuck.map(func(dv) -> String: return "%d@%s" % [dv["i"], (dv["p"] as Vector2).round()])])
	print("[soak] done: longest still %.0f s, minutes with a jam %d" % [worst, jams])
	quit(0 if worst < 45.0 else 2)
