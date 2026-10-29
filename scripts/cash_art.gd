## Site Cash: what the crew's money looks like (tools/blender/cash.py,
## assets/props/cash.glb). A made-up note, coloured by its denomination, with
## the amount printed in its middle panel; a wad of them; a leather wallet;
## and the same note and wallet as SVG for the phones' wallet screen.
extends RefCounted

const F := preload("res://scripts/factory.gd")
const UI := preload("res://scripts/ui.gd")
const LIB := "res://assets/props/cash.glb"

## The notes, smallest first, and their colours
const DENOM := {5: Color("e070b0"), 10: Color("3f86d6"), 20: Color("e0503a"), 50: Color("e8b830"), 100: Color("3f9a6a")}
const INK := Color("203046")
const PANEL := Color("f4efe0")
const COLORS := {
	"bill_panel": PANEL, "bill_window": Color("dcecf2"), "bill_ink": INK, "bill_foil": Color("e8c45a"),
	"band": Color("c8402e"), "leather": Color("6b4228"), "leather_dark": Color("4a2c1a"), "stitch": Color("e2c9a0"),
	"card_a": Color("2f6fd6"), "card_b": Color("e8a33a"), "card_c": Color("1d1f24"), "card_d": Color("3fb58a"),
	"lining": Color("2b2f36"),
}
## The note's size (m): it stands up facing +z
const SIZE := Vector2(0.30, 0.15)

static var _lib: Node
static var _meshes := {}
static var _mats := {}

## Which note an amount's paid in: the biggest that isn't more than it
static func denom_for(amount: int) -> int:
	var best := 5
	for d: int in DENOM:
		if amount >= d:
			best = d
	return best

static func color_for(amount: int) -> Color:
	return DENOM[denom_for(amount)]

## A note with "$<amount>" printed on both sides, coloured for the amount.
## Stands up facing +z, its middle at the origin.
static func bill(amount: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Bill"
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("cash_bill", denom_for(amount))
	root.add_child(mi)
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = "$%d" % amount
		l.font = UI.font("head")
		l.font_size = 96
		l.pixel_size = 0.0009 if amount < 1000 else 0.0007
		l.modulate = INK
		l.outline_size = 0
		l.double_sided = false
		l.position = Vector3(0.005, 0.0, 0.0027 * side)
		if side < 0.0:
			l.rotation.y = PI
			l.position.x = -0.005
		root.add_child(l)
	return root

## A wad of notes lying flat with a band round it (about 0.30 x 0.15 x 0.03 m)
static func stack(amount := 100) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("cash_stack", denom_for(amount))
	return mi

## A leather wallet, standing up facing +z (0.115 x 0.092 m): `open`, or
## closed and fatter the more there's in it (`fat` 0 to 1)
static func wallet(fat := 0.0, open := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("wallet_open" if open else "wallet_closed", 100)
	if not open:
		mi.scale.z = 1.0 + clampf(fat, 0.0, 1.0) * 2.5
	return mi

static func _mesh(name: String, denom: int) -> Mesh:
	var key := "%s/%d" % [name, denom]
	if _meshes.has(key):
		return _meshes[key]
	if _lib == null:
		if not ResourceLoader.exists(LIB):
			return null
		_lib = (load(LIB) as PackedScene).instantiate()
	var src := _lib.get_node_or_null(name) as MeshInstance3D
	if src == null:
		return null
	# (a copy per denomination, its paper painted that colour)
	var m := src.mesh.duplicate() as Mesh
	for i in m.get_surface_count():
		var sm := m.surface_get_material(i)
		var role := sm.resource_name if sm != null else ""
		m.surface_set_material(i, _mat(role, denom))
	_meshes[key] = m
	return m

static func _mat(role: String, denom: int) -> Material:
	var key := role if role != "bill" else "bill/%d" % denom
	if _mats.has(key):
		return _mats[key]
	var c: Color = DENOM[denom] if role == "bill" else COLORS.get(role, Color.MAGENTA)
	var m := F.color_mat(c, false, c * 0.25 if role == "bill_foil" else Color.BLACK)
	_mats[key] = m
	return m

# ------------------------------------------------------------------ phone art

static func _hex(c: Color) -> String:
	return "#" + c.to_html(false)

## The note as an SVG (300 x 150), the amount in its middle panel
static func bill_svg(amount: int) -> String:
	var paper := _hex(color_for(amount))
	var ink := _hex(INK)
	var waves := ""
	for k in 5:
		var y := 30 + k * 22
		waves += "<path d='M196 %d q8 -6 16 0 t16 0 t16 0 t16 0' fill='none' stroke='%s' stroke-width='1.2' opacity='.7'/>" % [y, ink]
	return ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 300 150' width='300' height='150'>"
		+ "<rect x='1' y='1' width='298' height='148' rx='7' fill='%s' stroke='%s' stroke-width='2'/>" % [paper, ink]
		+ "<rect x='8' y='8' width='284' height='134' rx='3' fill='none' stroke='%s' stroke-width='3'/>" % ink
		+ "<rect x='14' y='14' width='272' height='122' rx='2' fill='none' stroke='%s' stroke-width='1.2'/>" % ink
		+ "<rect x='17' y='40' width='42' height='70' rx='10' fill='#dcecf2'/>"
		+ "<path d='M25 80 a13 13 0 0 1 26 0 z M19 80 h38 v4 h-38 z' fill='#e8c45a'/>"
		+ waves
		+ "<g fill='%s'><rect x='265' y='45' width='6' height='80'/><rect x='238' y='42' width='46' height='4'/>" % ink
		+ "<rect x='266' y='34' width='4' height='10'/><rect x='245' y='46' width='1.5' height='30'/>"
		+ "<rect x='240' y='76' width='11' height='8'/></g>"
		+ "<circle cx='272' cy='20' r='5.5' fill='#e8c45a'/><circle cx='272' cy='130' r='5.5' fill='#e8c45a'/>"
		+ "<rect x='80' y='31' width='150' height='88' rx='12' fill='%s'/>" % _hex(PANEL)
		+ "<text x='155' y='92' text-anchor='middle' font-family='Barlow Condensed, Arial Narrow, sans-serif' "
		+ "font-weight='800' font-size='54' fill='%s'>$%d</text>" % [ink, amount]
		+ "</svg>")

## A closed leather wallet as an SVG (220 x 200): the fatter (`fat` 0 to
## 1), the more notes poke out of the top and the thicker its edge
static func wallet_svg(fat := 0.0) -> String:
	var f := clampf(fat, 0.0, 1.0)
	var notes := 1 + int(round(f * 5.0))
	var edge := 6 + int(round(f * 26.0))
	var top := 46
	var body := ""
	# the notes poking out, fanned a little, biggest at the back
	var cols := [100, 50, 20, 10, 5, 100]
	for i in notes:
		var c := _hex(color_for(cols[i % cols.size()]))
		var dx := -14 + i * 6
		var rot := -6 + i * 2.5
		body += "<rect x='%d' y='%d' width='150' height='70' rx='5' fill='%s' stroke='#203046' stroke-width='1.5' transform='rotate(%.1f 110 %d)'/>" % [
			35 + dx, top - 26 - i * 3, c, rot, top]
	# the wallet: its thick edge (seen at the bottom and the side), then the face
	var w := 180
	var h := 120
	var x0 := 20
	var y0 := top + 10
	body += "<rect x='%d' y='%d' width='%d' height='%d' rx='12' fill='#4a2c1a'/>" % [x0 + int(edge * 0.35), y0 + int(edge * 0.5), w, h]
	body += "<rect x='%d' y='%d' width='%d' height='%d' rx='12' fill='#6b4228' stroke='#4a2c1a' stroke-width='2'/>" % [x0, y0, w, h]
	body += "<rect x='%d' y='%d' width='%d' height='%d' rx='8' fill='none' stroke='#e2c9a0' stroke-width='1.6' stroke-dasharray='5 4'/>" % [
		x0 + 7, y0 + 7, w - 14, h - 14]
	body += "<rect x='%d' y='%d' width='8' height='%d' rx='3' fill='#4a2c1a'/>" % [x0 + 2, y0 + 6, h - 12]
	return ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 230 %d' width='230' height='%d'>" % [y0 + h + 40, y0 + h + 40]
		+ body + "</svg>")
