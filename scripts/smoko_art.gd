## Smoko on climb days (tools/blender/smoko.py, assets/props/smoko.glb): the
## coffee van at the Angora Rd gate and the screeder's run back up with a
## tray of coffees, a pie and a sausage roll. The van's outlined like the
## other plant; the food's small, so it's painted without outlines (they'd
## swallow a cup).
extends RefCounted

const F := preload("res://scripts/factory.gd")
const LIB := "res://assets/props/smoko.glb"
const FOOD := ["cup", "sleeve", "lid", "pulp", "foil", "pastry", "pastry_dark", "sauce", "sausage", "paper", "grip"]
## Where the cups sit in the tray (tray space; the tray's 0.23 m square)
const SLOTS := [Vector3(-0.055, 0.0, -0.055), Vector3(0.055, 0.0, -0.055), Vector3(-0.055, 0.0, 0.055),
	Vector3(0.055, 0.0, 0.055)]

static var _per := {}

## The van, front to +z, hatch on its left (+x); origin on the road under it
static func van() -> Node3D:
	return F.prop("CoffeeVan", {}, LIB)

## One of "CoffeeCup", "Pie", "SausageRoll", "CardboardTray"
static func food(name: String) -> Node3D:
	if _per.is_empty():
		for k: String in FOOD:
			_per[k] = F.color_mat(F.PROP_COLORS.get(k, F.CREW_COLORS.get(k, Color.MAGENTA)), false)
	return F.prop(name, _per, LIB)

## The pulp tray with `cups` coffees in it (0 to 4)
static func tray(cups := 4) -> Node3D:
	var t := food("CardboardTray")
	for i in clampi(cups, 0, SLOTS.size()):
		var c := food("CoffeeCup")
		c.position = SLOTS[i]
		t.add_child(c)
	return t
