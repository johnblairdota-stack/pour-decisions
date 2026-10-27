"""Shared helpers for the Blender asset scripts (run with Blender's Python, or
`pip install bpy` and plain python).

Everything is written in GODOT coordinates (x right, y up, z towards the
camera / the character's face) and turned into Blender's z-up on the way in,
so numbers here match the numbers in scripts/factory.gd. The glTF exporter
turns it back.

Materials are named by role (skin, vest, hat, tape ...): the game swaps each
one for its own toon material by that name (factory.gd), so colours here are
only for the preview renders.
"""
import math
import os

import bpy  # (first: bmesh comes with it)
import bmesh
from mathutils import Matrix, Vector


def G(x, y, z):
	"""A Godot point (y up, +z forward) as a Blender one (z up, -y forward)."""
	return Vector((x, -z, y))


# ---------------------------------------------------------------- scene

def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)


_mats = {}


def material(name, color="ff00ff"):
	"""One material per role name, with a preview colour."""
	if name in _mats:
		return _mats[name]
	m = bpy.data.materials.new(name)
	c = hex_rgb(color)
	m.diffuse_color = (*c, 1.0)
	m.use_nodes = True
	bsdf = m.node_tree.nodes.get("Principled BSDF")
	if bsdf:
		bsdf.inputs["Base Color"].default_value = (*c, 1.0)
		bsdf.inputs["Roughness"].default_value = 0.8
	_mats[name] = m
	return m


def hex_rgb(h):
	h = h.lstrip("#")
	srgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
	# Blender colours are linear
	return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


def empty(name, at=(0, 0, 0), parent=None):
	o = bpy.data.objects.new(name, None)
	o.empty_display_size = 0.1
	bpy.context.scene.collection.objects.link(o)
	if parent is not None:
		o.parent = parent
	o.location = G(*at)
	return o


# ---------------------------------------------------------------- pieces
# A piece is a bmesh in Godot coords plus a material name per face. Pieces
# get merged into one mesh object per moving part (fewer draw calls).

class Piece:
	def __init__(self, mat="white"):
		self.bm = bmesh.new()
		self.mat = mat
		self.face_mats = {}   # face index -> material name, where not `mat`

	def mats(self):
		return [self.face_mats.get(i, self.mat) for i in range(len(self.bm.faces))]

	def move(self, x=0, y=0, z=0):
		for v in self.bm.verts:
			v.co += Vector((x, y, z))
		return self

	def scale(self, sx=1, sy=1, sz=1):
		for v in self.bm.verts:
			v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
		return self

	def rot(self, axis, ang):
		m = Matrix.Rotation(ang, 3, axis.upper())
		for v in self.bm.verts:
			v.co = m @ v.co
		return self

	def warp(self, fn):
		for v in self.bm.verts:
			v.co = Vector(fn(v.co.copy()))
		return self

	def paint(self, mat, test):
		"""Faces whose centre passes `test(center)` get material `mat`."""
		self.bm.faces.ensure_lookup_table()
		for i, f in enumerate(self.bm.faces):
			if test(f.calc_center_median()):
				self.face_mats[i] = mat
		return self

	def cull(self, test):
		"""Deletes faces whose centre passes `test` (for shells: hair, beard)."""
		self.bm.faces.ensure_lookup_table()
		mats = self.mats()
		keep = [m for f, m in zip(self.bm.faces, mats) if not test(f.calc_center_median())]
		dead = [f for f in self.bm.faces if test(f.calc_center_median())]
		bmesh.ops.delete(self.bm, geom=dead, context="FACES")
		self.face_mats = {i: m for i, m in enumerate(keep) if m != self.mat}
		return self


def lathe(profile, segs=24, mat="white", depth=1.0, cap_top=True, cap_bottom=True, arc=None, loop=False):
	"""Turns a profile [(radius, y), ...] (bottom to top) round the y axis.
	`depth` squashes it front to back (a torso isn't round). `arc` = (a0, a1)
	in radians makes an open strip instead of a full turn (0 = +z, the front)."""
	p = Piece(mat)
	bm = p.bm
	full = arc is None
	n = segs if full else segs + 1
	rings = []
	for r, y in profile:
		ring = []
		for i in range(n):
			a = (2 * math.pi * i / segs) if full else (arc[0] + (arc[1] - arc[0]) * i / segs)
			ring.append(bm.verts.new((math.sin(a) * r, y, math.cos(a) * r * depth)))
		rings.append(ring)
	if loop:
		# A closed cross-section (a ring's profile): join the last point to
		# the first, and close the ends of an open arc with the profile itself
		rings.append(rings[0])
		profile = list(profile) + [profile[0]]
		if not full:
			bm.faces.new([r[0] for r in rings[:-1]])
			bm.faces.new([r[-1] for r in reversed(rings[:-1])])
	for k in range(len(rings) - 1):
		a, b = rings[k], rings[k + 1]
		for i in range(segs):
			j = (i + 1) % n
			if r_zero(profile[k]) and r_zero(profile[k + 1]):
				continue
			bm.faces.new((a[i], a[j], b[j], b[i]))
	if full and not loop:
		if cap_bottom and profile[0][0] > 1e-5:
			c = bm.verts.new((0, profile[0][1], 0))
			for i in range(segs):
				bm.faces.new((rings[0][(i + 1) % n], rings[0][i], c))
		if cap_top and profile[-1][0] > 1e-5:
			c = bm.verts.new((0, profile[-1][1], 0))
			for i in range(segs):
				bm.faces.new((rings[-1][i], rings[-1][(i + 1) % n], c))
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
	return p


def r_zero(pr):
	return pr[0] < 1e-6


def sphere(r, mat="white", segs=20, rings=12, at=(0, 0, 0), s=(1, 1, 1)):
	prof = []
	for k in range(rings + 1):
		t = -math.pi / 2 + math.pi * k / rings
		prof.append((max(0.0, math.cos(t) * r), math.sin(t) * r))
	p = lathe(prof, segs, mat, cap_top=False, cap_bottom=False)
	p.scale(*s)
	p.move(*at)
	return p


def rounded_profile(r, y0, y1, bevel, steps=3):
	"""A cylinder's profile with rounded top and bottom edges."""
	out = [(0.0, y0)]
	for k in range(steps + 1):
		t = math.pi / 2 * k / steps
		out.append((r - bevel + math.sin(t) * bevel, y0 + bevel - math.cos(t) * bevel))
	for k in range(steps + 1):
		t = math.pi / 2 * k / steps
		out.append((r - bevel + math.cos(t) * bevel, y1 - bevel + math.sin(t) * bevel))
	out.append((0.0, y1))
	return out


def cylinder(r, h, mat="white", segs=16, bevel=0.0, at=(0, 0, 0)):
	"""Upright, bottom at y=0 (then moved to `at`)."""
	if bevel > 0:
		p = lathe(rounded_profile(r, 0, h, bevel), segs, mat)
	else:
		p = lathe([(r, 0), (r, h)], segs, mat)
	return p.move(*at)


def extrude(poly, x0, x1, mat="white", caps=True):
	"""A cross-section `poly` [(z, y), ...] run along x from x0 to x1: beams,
	boards, rails."""
	p = Piece(mat)
	bm = p.bm
	a = [bm.verts.new((x0, y, z)) for z, y in poly]
	b = [bm.verts.new((x1, y, z)) for z, y in poly]
	n = len(poly)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((a[i], a[j], b[j], b[i]))
	if caps:
		bm.faces.new(list(reversed(a)))
		bm.faces.new(b)
	return p


def rounded_rect(w, h, r, steps=3, cx=0.0, cy=0.0):
	"""A rounded rectangle's outline [(u, v), ...], w wide and h tall."""
	out = []
	for k, (sx, sy) in enumerate(((1, 1), (-1, 1), (-1, -1), (1, -1))):
		ox, oy = cx + sx * (w / 2 - r), cy + sy * (h / 2 - r)
		a0 = k * math.pi / 2
		for i in range(steps + 1):
			a = a0 + math.pi / 2 * i / steps
			out.append((ox + math.cos(a) * r, oy + math.sin(a) * r))
	return out


def torus(R, r, mat="white", segs=12, rsegs=6, at=(0, 0, 0)):
	"""A ring lying flat (round the y axis)."""
	prof = [(R + math.cos(2 * math.pi * k / rsegs) * r, math.sin(2 * math.pi * k / rsegs) * r)
		for k in range(rsegs)]
	return lathe(prof, segs, mat, loop=True).move(*at)


def box(sx, sy, sz, mat="white", bevel=0.0, at=(0, 0, 0)):
	"""A box centred on `at`, with rounded edges when `bevel` > 0 (a rounded
	box keeps the outline unbroken)."""
	p = Piece(mat)
	bmesh.ops.create_cube(p.bm, size=1.0)
	if bevel > 0:
		bmesh.ops.bevel(p.bm, geom=list(p.bm.edges), offset=bevel / max(min(sx, sy, sz), 1e-4), segments=2,
			affect="EDGES", profile=0.5, clamp_overlap=True)
	p.scale(sx, sy, sz)
	return p.move(*at)


def tube(points, r, mat="white", segs=8, closed=False, cap=True):
	"""A round tube along a polyline of Godot points: straps, cables, hoses.
	`r` is a radius, or a function of how far along (0 to 1) for a taper."""
	p = Piece(mat)
	bm = p.bm
	pts = [Vector(q) for q in points]
	n = len(pts)
	rings = []
	prev_side = None
	for i, c in enumerate(pts):
		if closed:
			d = pts[(i + 1) % n] - pts[i - 1]
		else:
			d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
		d.normalize()
		ref = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
		side = d.cross(ref).normalized() if prev_side is None else (prev_side - d * prev_side.dot(d)).normalized()
		up = side.cross(d).normalized()
		prev_side = side
		ring = []
		rr = r(i / max(1, n - 1)) if callable(r) else r
		for k in range(segs):
			a = 2 * math.pi * k / segs
			ring.append(bm.verts.new(c + (side * math.cos(a) + up * math.sin(a)) * rr))
		rings.append(ring)
	last = n if closed else n - 1
	for i in range(last):
		a, b = rings[i], rings[(i + 1) % n]
		for k in range(segs):
			bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
	if cap and not closed:
		bm.faces.new(list(reversed(rings[0])))
		bm.faces.new(rings[-1])
	return p


def arc_points(center, radius, a0, a1, steps=12, plane="xz", y=0.0):
	"""Points round an arc. plane xz: angle 0 = +z; plane xy: angle 0 = +y."""
	out = []
	for k in range(steps + 1):
		a = a0 + (a1 - a0) * k / steps
		if plane == "xz":
			out.append((center[0] + math.sin(a) * radius, center[1], center[2] + math.cos(a) * radius))
		elif plane == "xy":
			out.append((center[0] + math.sin(a) * radius, center[1] + math.cos(a) * radius, center[2]))
		else:  # yz
			out.append((center[0], center[1] + math.cos(a) * radius, center[2] + math.sin(a) * radius))
	return out


# ---------------------------------------------------------------- objects

def build(name, pieces, palette, parent=None, at=(0, 0, 0), smooth=True, subsurf=0, hidden=False):
	"""Merges pieces (Godot coords, relative to `at`) into one mesh object with
	a material slot per material name."""
	me = bpy.data.meshes.new(name)
	bm = bmesh.new()
	names = []
	for pc in pieces:
		mats = pc.mats()
		vmap = {}
		for v in pc.bm.verts:
			vmap[v] = bm.verts.new(G(*v.co))
		for f, mn in zip(pc.bm.faces, mats):
			try:
				nf = bm.faces.new([vmap[v] for v in f.verts])
			except ValueError:
				continue
			if mn not in names:
				names.append(mn)
			nf.material_index = names.index(mn)
			nf.smooth = smooth
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(o)
	for mn in names:
		me.materials.append(material(mn, palette.get(mn, "ff00ff")))
	if parent is not None:
		o.parent = parent
	o.location = G(*at)
	if subsurf:
		m = o.modifiers.new("Subsurf", "SUBSURF")
		m.levels = subsurf
		m.render_levels = subsurf
	if hidden:
		o["hidden"] = 1
	return o


def export_glb(path, objects=None):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	for o in bpy.context.scene.objects:
		o.select_set(objects is None or o in objects)
	bpy.ops.export_scene.gltf(
		filepath=path,
		export_format="GLB",
		use_selection=objects is not None,
		export_apply=True,
		export_yup=True,
		export_extras=True,
		export_materials="EXPORT",
		export_normals=True,
		export_texcoords=False,
		export_animations=False,
	)


def tri_count(objs):
	dg = bpy.context.evaluated_depsgraph_get()
	n = 0
	for o in objs:
		if o.type != "MESH":
			continue
		me = o.evaluated_get(dg).to_mesh()
		me.calc_loop_triangles()
		n += len(me.loop_triangles)
		o.evaluated_get(dg).to_mesh_clear()
	return n


# ---------------------------------------------------------------- previews

def preview(path, views, size=(1600, 900), show=lambda o: "hidden" not in o, target=(0, 0.9, 0), dist=4.2,
		samples=24, lens=50):
	"""Renders a strip of turntable views (Cycles on the CPU, Freestyle lines
	for the outline) into one PNG per view: `views` is a list of
	(name, yaw_degrees, pitch_degrees). Only for looking at: the game's own
	toon shader is what counts."""
	import bpy
	sc = bpy.context.scene
	sc.render.engine = "CYCLES"
	sc.cycles.device = "CPU"
	sc.cycles.samples = samples
	sc.cycles.use_denoising = False
	sc.render.resolution_x, sc.render.resolution_y = size
	sc.render.film_transparent = False
	sc.view_settings.view_transform = "Standard"
	sc.render.use_freestyle = True
	sc.render.line_thickness_mode = "ABSOLUTE"
	sc.render.line_thickness = 1.6
	vl = sc.view_layers[0]
	vl.use_freestyle = True
	if not vl.freestyle_settings.linesets:
		ls = vl.freestyle_settings.linesets.new("Outline")
		ls.select_by_visibility = True
		ls.select_silhouette = True
		ls.select_border = True
		ls.select_crease = False
		ls.linestyle.color = hex_rgb("0f1424")
	if sc.world is None:
		sc.world = bpy.data.worlds.new("World")
	sc.world.use_nodes = True
	bg = sc.world.node_tree.nodes.get("Background")
	bg.inputs["Color"].default_value = (*hex_rgb("cfe3f2"), 1)
	bg.inputs["Strength"].default_value = 0.9
	for o in sc.objects:
		hide = not show(o)
		o.hide_render = hide
	if "PreviewSun" not in bpy.data.objects:
		sun = bpy.data.lights.new("PreviewSun", "SUN")
		sun.energy = 3.2
		so = bpy.data.objects.new("PreviewSun", sun)
		sc.collection.objects.link(so)
		so.rotation_euler = (math.radians(50), 0, math.radians(35))
		cam = bpy.data.cameras.new("PreviewCam")
		co = bpy.data.objects.new("PreviewCam", cam)
		sc.collection.objects.link(co)
		sc.camera = co
	co = bpy.data.objects["PreviewCam"]
	co.data.lens = lens
	t = G(*target)
	out = []
	for name, yaw, pitch in views:
		y, p = math.radians(yaw), math.radians(pitch)
		# yaw 0 = looking at the face (from Godot +z)
		eye = G(target[0] + math.sin(y) * math.cos(p) * dist, target[1] + math.sin(p) * dist,
			target[2] + math.cos(y) * math.cos(p) * dist)
		co.location = eye
		d = (t - eye)
		co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
		f = path.replace(".png", "_%s.png" % name)
		sc.render.filepath = f
		bpy.ops.render.render(write_still=True)
		out.append(f)
	return out
