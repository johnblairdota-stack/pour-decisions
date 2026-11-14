"""Small bpy helpers shared by the Spire builders. Geometry numbers come from layout.py only."""
import math

import bpy

import layout as L

# Clay palette (viewport/Workbench colours). "look" previews use these; "clay" previews use one grey.
COLOURS = {
    "ground": (0.46, 0.46, 0.44, 1),
    "water": (0.26, 0.27, 0.20, 1),          # Brisbane River: muddy brown-green
    "road": (0.045, 0.046, 0.05, 1),       # step 7d: bitumen #3a3b3d (linear)
    "footpath": (0.62, 0.61, 0.58, 1),
    "footway": (0.55, 0.53, 0.50, 1),
    "building": (0.80, 0.80, 0.78, 1),
    "building_guess": (0.70, 0.72, 0.78, 1),   # height not tagged in OSM
    "spire": (0.93, 0.74, 0.52, 1),
    "slab": (0.90, 0.88, 0.84, 1),         # pour A
    "slab_b": (0.80, 0.84, 0.90, 1),       # pour B (slightly blue so the joint reads)
    "transfer": (0.95, 0.55, 0.35, 1),
    "transfer_b": (0.90, 0.50, 0.45, 1),
    "core": (0.55, 0.52, 0.50, 1),
    "brick": (0.78, 0.62, 0.45, 1),
    "formwork": (0.82, 0.55, 0.30, 1),     # ply deck
    "reo": (0.30, 0.22, 0.18, 1),          # reinforcement mat waiting for concrete
    "prop": (0.85, 0.85, 0.20, 1),
    "column": (0.70, 0.70, 0.68, 1),
    "screen": (0.20, 0.45, 0.80, 1),       # edge screens
    "jumpform": (0.25, 0.60, 0.35, 1),
    "boom": (0.95, 0.45, 0.10, 1),
    "pump": (0.95, 0.85, 0.15, 1),
    "pipe": (0.15, 0.15, 0.15, 1),
    "hoarding": (0.15, 0.35, 0.65, 1),
    "truck": (0.92, 0.92, 0.92, 1),
    "tree": (0.35, 0.55, 0.30, 1),
    "tree_dark": (0.22, 0.40, 0.22, 1),
    "palm": (0.45, 0.60, 0.30, 1),
    "bark": (0.45, 0.38, 0.30, 1),
    "fam_heritage": (0.82, 0.72, 0.56, 1),   # sandstone / porphyry stand-in
    "fam_brick": (0.72, 0.50, 0.40, 1),
    "fam_concrete": (0.80, 0.79, 0.75, 1),
    "fam_glass": (0.50, 0.60, 0.70, 1),
    "roof": (0.62, 0.63, 0.64, 1),
    "band": (0.92, 0.92, 0.90, 1),
    "steel": (0.42, 0.50, 0.56, 1),          # Story Bridge grey
    "pier": (0.70, 0.68, 0.64, 1),
    "deck": (0.30, 0.30, 0.31, 1),
    "rock": (0.52, 0.47, 0.42, 1),           # Kangaroo Point tuff: grey-brown
    "timber": (0.60, 0.48, 0.35, 1),
    "corten": (0.62, 0.32, 0.18, 1),
    "spire_glass": (0.07, 0.075, 0.085, 1),    # dark glass (#2a2d31 in sRGB; linear here) / recessed balconies (photo sheet)
    "spire_frame": (0.91, 0.90, 0.88, 1),
    "spire_soffit": (0.20, 0.19, 0.17, 1),     # recessed balcony soffits / walls, read dark-warm at distance      # #e8e6e0 white frame lattice and slab edges
    "spire_balustrade": (0.20, 0.22, 0.25, 1),
    "balustrade": (0.70, 0.80, 0.85, 1),
    "line": (0.89, 0.89, 0.86, 1),          # #f2f2ee          # road markings
    "line_yellow": (0.95, 0.80, 0.20, 1),
    "pole": (0.55, 0.57, 0.58, 1),
    "shotcrete": (0.66, 0.64, 0.60, 1),
    "anchor": (0.25, 0.25, 0.27, 1),
    "bridge": (0.35, 0.45, 0.55, 1),
    "crane": (0.95, 0.70, 0.10, 1),
    "hoist": (0.20, 0.55, 0.85, 1),
    "gate": (0.90, 0.20, 0.20, 1),
    "sheds": (0.85, 0.85, 0.90, 1),
}


def collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def material(key):
    name = "clay_" + key
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.diffuse_color = COLOURS[key]
        m.roughness = 0.9
    return m


def text_obj(col, name, body, loc, rot, size, rgb, emit=0.0):
    """A Blender text object (street signs, road words)."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = 0.005
    ob = bpy.data.objects.new(name, cu)
    ob.location = loc
    ob.rotation_euler = rot
    m = material_rgb("text_%s" % ("%.2f_%.2f_%.2f" % tuple(rgb)), rgb)
    if emit:
        m["emit"] = emit
    cu.materials.append(m)
    col.objects.link(ob)
    return ob


def material_rgb(name, rgb, window=None, shader="render", palette=None):
    """A material with an explicit colour. The morning look (preview.setup_morning) turns the props into a
    procedural shader: shader = render | brick | ashlar | glass, palette = ashlar block colours,
    window = facade grid (bay, win, sill, head, floor, glass, rough)."""
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.roughness = 0.85
    m["shader"] = shader
    if palette:
        m["palette"] = [c for col in palette for c in col]
    if window:
        for k, v in window.items():
            m["win_" + k] = list(v) if isinstance(v, tuple) else v
    return m


def mesh_object(name, verts, faces, col, mat_key, uvs=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    if uvs is not None:
        # facade UVs: u = metres round the footprint, v = metres AHD (windows line up with floors)
        lay = me.uv_layers.new(name="facade")
        flat = [c for face in uvs for uv in face for c in uv]
        lay.data.foreach_set("uv", flat)
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(material(mat_key))
    col.objects.link(ob)
    return ob


def mesh_fast(name, verts, faces, col, mat_key):
    """Big meshes from numpy: verts (N, 3) float, faces (M, k) int, all faces the same size k."""
    import numpy as np
    verts = np.asarray(verts, "f4")
    faces = np.asarray(faces, "i4")
    k = faces.shape[1]
    me = bpy.data.meshes.new(name)
    me.vertices.add(len(verts))
    me.vertices.foreach_set("co", verts.ravel())
    me.loops.add(faces.size)
    me.loops.foreach_set("vertex_index", faces.ravel())
    me.polygons.add(len(faces))
    me.polygons.foreach_set("loop_start", np.arange(0, faces.size, k, dtype="i4"))
    me.polygons.foreach_set("loop_total", np.full(len(faces), k, "i4"))
    me.update(calc_edges=True)
    me.validate()
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(material(mat_key))
    col.objects.link(ob)
    return ob


class MeshBuf:
    """Collect many small pieces, then make one object (fast for hundreds of buildings)."""

    def __init__(self):
        self.v, self.f, self.uv = [], [], []

    def add(self, verts, faces, uvs=None):
        o = len(self.v)
        self.v += verts
        self.f += [[i + o for i in face] for face in faces]
        self.uv += uvs if uvs is not None else [[(verts[i][0] * 0.1, verts[i][1] * 0.1) for i in face] for face in faces]

    def prism(self, ring, z0, z1):
        """Closed extrusion of a 2D ring (list of (x, y), no repeat of the first point)."""
        n = len(ring)
        if n < 3:
            return
        if signed_area(ring) < 0:
            ring = ring[::-1]
        verts = [(x, y, z0) for x, y in ring] + [(x, y, z1) for x, y in ring]
        faces = [list(range(n - 1, -1, -1)), list(range(n, 2 * n))]
        faces += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
        per = [0.0]
        for i in range(n):
            per.append(per[-1] + math.dist(ring[i], ring[(i + 1) % n]))
        uvs = [[(verts[i][0] * 0.1, verts[i][1] * 0.1) for i in faces[0]], [(verts[i][0] * 0.1, verts[i][1] * 0.1) for i in faces[1]]]
        uvs += [[(per[i], z0), (per[i + 1], z0), (per[i + 1], z1), (per[i], z1)] for i in range(n)]
        self.add(verts, faces, uvs)

    def loft(self, ring0, z0, ring1, z1):
        """Closed solid between two rings with the same vertex count (e.g. a leaning wall)."""
        n = len(ring0)
        if signed_area(ring0) < 0:
            ring0, ring1 = ring0[::-1], ring1[::-1]
        verts = [(x, y, z0) for x, y in ring0] + [(x, y, z1) for x, y in ring1]
        faces = [list(range(n - 1, -1, -1)), list(range(n, 2 * n))]
        faces += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
        self.add(verts, faces)

    def beam(self, p, q, w, h=None):
        """Square-section bar from point p to point q (3D), width w."""
        h = h or w
        d = [q[i] - p[i] for i in range(3)]
        ln = math.sqrt(sum(c * c for c in d))
        if ln < 1e-3:
            return
        d = [c / ln for c in d]
        up = (0, 0, 1) if abs(d[2]) < 0.95 else (1, 0, 0)
        s = [d[1] * up[2] - d[2] * up[1], d[2] * up[0] - d[0] * up[2], d[0] * up[1] - d[1] * up[0]]
        sl = math.sqrt(sum(c * c for c in s))
        s = [c / sl for c in s]
        t = [s[1] * d[2] - s[2] * d[1], s[2] * d[0] - s[0] * d[2], s[0] * d[1] - s[1] * d[0]]
        corners = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
        verts = []
        for base in (p, q):
            for a, b in corners:
                verts.append(tuple(base[i] + s[i] * a + t[i] * b for i in range(3)))
        faces = [[3, 2, 1, 0], [4, 5, 6, 7]] + [[i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i] for i in range(4)]
        self.add(verts, faces)

    def box(self, cx, cy, z0, sx, sy, sz, heading=0.0):
        c, s = math.cos(heading), math.sin(heading)
        ring = []
        for dx, dy in ((-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2)):
            ring.append((cx + dx * c - dy * s, cy + dx * s + dy * c))
        self.prism(ring, z0, z0 + sz)

    def object(self, name, col, mat_key):
        if not self.v:
            return None
        return mesh_object(name, self.v, self.f, col, mat_key, self.uv)


def signed_area(ring):
    return 0.5 * sum(ring[i][0] * ring[(i + 1) % len(ring)][1] - ring[(i + 1) % len(ring)][0] * ring[i][1]
                     for i in range(len(ring)))


def clean_ring(pts):
    ring = [tuple(p) for p in pts]
    if len(ring) > 1 and ring[0] == ring[-1]:
        ring = ring[:-1]
    out = []
    for p in ring:
        if not out or math.hypot(p[0] - out[-1][0], p[1] - out[-1][1]) > 0.05:
            out.append(p)
    return out


def point_in_ring(x, y, ring):
    inside = False
    n = len(ring)
    for i in range(n):
        x1, y1 = ring[i]
        x2, y2 = ring[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            inside = not inside
    return inside


def offset_line(pts, d):
    """Offset an open polyline sideways by d (left = +). Mitred, capped at 3x d."""
    n = len(pts)
    out = []
    for i in range(n):
        if i == 0:
            tx, ty = pts[1][0] - pts[0][0], pts[1][1] - pts[0][1]
        elif i == n - 1:
            tx, ty = pts[-1][0] - pts[-2][0], pts[-1][1] - pts[-2][1]
        else:
            ax, ay = pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]
            bx, by = pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]
            la, lb = math.hypot(ax, ay) or 1, math.hypot(bx, by) or 1
            tx, ty = ax / la + bx / lb, ay / la + by / lb
        lt = math.hypot(tx, ty) or 1
        nx, ny = -ty / lt, tx / lt
        k = 1.0
        if 0 < i < n - 1:
            ax, ay = pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]
            la = math.hypot(ax, ay) or 1
            cosh = (nx * (-ay / la) + ny * (ax / la))
            k = min(3.0, 1.0 / max(cosh, 0.33))
        out.append((pts[i][0] + nx * d * k, pts[i][1] + ny * d * k))
    return out


def trim_line(pts, start, end):
    """Cut `start` metres off the front and `end` metres off the back of a polyline."""
    def cut(p, dist):
        acc = 0.0
        for i in range(1, len(p)):
            seg = math.hypot(p[i][0] - p[i - 1][0], p[i][1] - p[i - 1][1])
            if acc + seg >= dist:
                t = (dist - acc) / seg if seg else 0
                q = (p[i - 1][0] + (p[i][0] - p[i - 1][0]) * t, p[i - 1][1] + (p[i][1] - p[i - 1][1]) * t)
                return [q] + p[i:]
            acc += seg
        return []
    p = list(pts)
    if start > 0:
        p = cut(p, start)
    if end > 0 and len(p) > 1:
        p = cut(p[::-1], end)[::-1]
    return p


def densify(pts, step=2.0):
    """Extra points every `step` metres so draped strips follow the DEM between OSM nodes."""
    out = [pts[0]]
    for i in range(1, len(pts)):
        (x0, y0), (x1, y1) = pts[i - 1], pts[i]
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) // step))
        out += [(x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n) for k in range(1, n + 1)]
    return out


def line_length(pts):
    return sum(math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]) for i in range(1, len(pts)))


def in_lidar(x, y, pad=0.0):
    x0, y0, x1, y1 = L.LIDAR_BOX
    return x0 - pad <= x <= x1 + pad and y0 - pad <= y <= y1 + pad


def in_model(x, y, pad=0.0):
    return abs(x) <= L.MODEL_HALF + pad and abs(y) <= L.MODEL_HALF + pad
