"""The Spire fly-in as a film: one camera flight through the Brisbane model, frame by frame, from high
in the cloud in the cloud down to the floor pick's own view, where the game takes over standing still.

    python tools/blender/spire/render_film.py <out_dir> [from=0] [to=N] [w=1280] [fps=24] [--cams]

The camera swings round the tower as it comes down (so the city really moves past: near things faster
than far ones), always looking at the tower, and closes on it at a steady rate: every second takes
the same share off the distance left. Frames already in <out_dir> are skipped, so a run can be done
in pieces. <out_dir>/cams.json holds every frame's camera (the model's metres, z AHD): the game flies
its own camera down the same line while the film hands over. --cams writes only that.
Rendered in strips (the whole frame with denoising runs the cloud machine out of memory)."""
import json
import math
import os
import sys

S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, S)

T = (0.0, 0.0, 80.0)              # what it looks at on the way in: the tower's middle
HDIR = (-0.682, 0.731)            # from the tower towards where it ends up (over Ann St: the game's own side)
S0, S1 = 2800.0, 270.0            # m from the tower, start and end of the long run in
DUR = 5.6                         # s: the long run in
AZ0, EL0, EL1 = 32.0, 36.0, 24.0  # degrees: round from the end line at the start, up at the start and end
SWING = 0.8                       # of the time: the swing round and down is over by then
LENS = 21.7                       # the game's own 50 degree lens
# The last leg: on down to the floor pick's own view, so the game takes over standing still.
# END is the game's floor pick camera for the first deck (L06) and what it looks at, in the model's
# metres (the game prints them: --pickplay=spire --pickfloor=0 --arrivedbg, "FILMDBG", turned back
# through SpireSite.g). It stays over the towers across Ann St (they reach 127 m AHD) until it is
# OVER_OUT m off the face, and comes down the face from there.
END = ((-21.673, 23.822, 43.978), (-7.386, 8.502, 42.51))
OVER_OUT, OVER_Z = 28.0, 154.0
LEG = (2.1, 1.9)                  # s: to the point over the street, and down the face
TOTAL = DUR + LEG[0] + LEG[1]
CUT_Z = float(os.environ.get("CUT_Z", "42.35"))   # AHD: the tower's cut off here (the game's first deck: it isn't built yet)


def smooth(a, b, x):
    u = min(1.0, max(0.0, (x - a) / (b - a)))
    return u * u * (3.0 - 2.0 * u)


def run_in(t):
    s = S0 * math.exp(-math.log(S0 / S1) * t / DUR)
    f = smooth(0.0, SWING * DUR, t)
    az = math.radians(AZ0 * (1.0 - f))
    el = math.radians(EL0 + (EL1 - EL0) * f)
    hx = HDIR[0] * math.cos(az) - HDIR[1] * math.sin(az)
    hy = HDIR[0] * math.sin(az) + HDIR[1] * math.cos(az)
    return (T[0] + hx * s * math.cos(el), T[1] + hy * s * math.cos(el), T[2] + s * math.sin(el))


def _herm(p0, m0, p1, m1, u, d):
    h00, h10 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u
    h01, h11 = -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
    return tuple(h00 * p0[i] + h10 * d * m0[i] + h01 * p1[i] + h11 * d * m1[i] for i in range(3))


def _over():
    e, f = END
    n = (e[0] - f[0], e[1] - f[1])
    k = OVER_OUT / math.hypot(*n)
    return (f[0] + n[0] * k, f[1] + n[1] * k, OVER_Z)


def cam_at(t):
    """The camera t s in: (place, what it looks at)."""
    if t <= DUR:
        return run_in(t), T
    p0, k, e = run_in(DUR), _over(), END[0]
    a = run_in(DUR - 0.01)
    v0 = tuple((p0[i] - a[i]) / 0.01 for i in range(3))             # (it leaves the run in at the run in's own speed)
    vk = tuple((e[i] - k[i]) / LEG[1] * (1.4 if i == 2 else 1.0) + (0.0 if i == 2 else (k[i] - p0[i]) * 0.12) for i in range(3))   # (turning down at the point over the street)
    x = t - DUR
    if x <= LEG[0]:
        p = _herm(p0, v0, k, vk, x / LEG[0], LEG[0])
    else:
        p = _herm(k, vk, e, (0.0, 0.0, 0.0), min(1.0, (x - LEG[0]) / LEG[1]), LEG[1])
    f = smooth(0.0, 0.85, x / (LEG[0] + LEG[1]))
    return p, tuple(T[i] + (END[1][i] - T[i]) * f for i in range(3))


def cut_tower(_meta):
    """The tower's not built yet in the game: cut it (and its core) off level at the first deck."""
    import bmesh
    import bpy
    from mathutils import Vector
    for ob in bpy.data.objects:
        if ob.type != "MESH" or not ob.name.startswith(("SPIRE_", "CORE_", "SLAB_")):
            continue
        inv = ob.matrix_world.inverted()
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        if not bm.verts or max((ob.matrix_world @ v.co).z for v in bm.verts) <= CUT_Z:
            bm.free()
            continue
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=inv @ Vector((0, 0, CUT_Z)),
                                   plane_no=inv.to_3x3() @ Vector((0, 0, 1)),
                                   clear_outer=True)
        bm.to_mesh(ob.data)
        bm.free()
        if not ob.data.polygons:
            ob.hide_render = True
    # (what the cut lays bare: the first deck is formwork ply, as the game shows it, and the plate under
    # the tower's foot is plain concrete, not the black it has when the tower hides it)
    for pre, nm, col in (("SLAB_L06", "film_deck_ply", (0.72, 0.36, 0.13)), (("SPIRE_base_fill", "SPIRE_storeys"), "film_base", (0.9, 0.88, 0.84))):
        m = bpy.data.materials.new(nm)
        m.diffuse_color = col + (1.0,)
        m.use_nodes = True
        b = m.node_tree.nodes.get("Principled BSDF")
        b.inputs["Base Color"].default_value = col + (1.0,)
        b.inputs["Roughness"].default_value = 0.85
        for ob in bpy.data.objects:
            if ob.type == "MESH" and ob.name.startswith(pre):
                ob.data.materials.clear()
                ob.data.materials.append(m)


def main():
    argv = sys.argv[1:]
    out = os.path.abspath(argv[0])
    os.makedirs(out, exist_ok=True)
    num = lambda k, d: type(d)(next((a[len(k) + 1:] for a in argv if a.startswith(k + "=")), d))
    fps, w = num("fps", 24), num("w", 1280)
    n = int(round(TOTAL * fps)) + 1
    f0, f1 = num("from", 0), min(n, num("to", n))
    h = w * 9 // 16
    json.dump({"fps": fps, "frames": n, "dur": TOTAL, "run_in": DUR, "target": T, "lens": LENS,
               "cams": [[round(v, 2) for v in cam_at(i / fps)[0]] for i in range(n)],
               "looks": [[round(v, 2) for v in cam_at(i / fps)[1]] for i in range(n)]}, open(os.path.join(out, "cams.json"), "w"))
    if "--cams" in argv:
        return
    import bpy
    import build_all
    import preview as P
    import render_cbd as R
    from PIL import Image
    cut_tower(build_all.build_all(None, write_meta=False))
    P.setup_morning()
    P.apply_light(78.0, 12.0)
    R.setup_cycles(int(os.environ.get("CYC_SAMPLES", "40")))
    sc = bpy.context.scene
    sc.render.use_border, sc.render.use_crop_to_border = True, True
    sc.render.use_persistent_data = os.environ.get("PERSIST", "1") == "1"
    strips = num("strips", 3)
    for i in range(f0, f1):
        dst = os.path.join(out, "film_%04d.png" % i)
        if os.path.exists(dst):
            continue
        parts = []
        for k in range(strips):
            sc.render.border_min_x, sc.render.border_max_x = 0.0, 1.0
            sc.render.border_min_y, sc.render.border_max_y = k / strips, (k + 1) / strips
            R.shoot({"id": "f%04d_s%d" % (i, k), "pos": cam_at(i / fps)[0], "look_at": cam_at(i / fps)[1], "lens": LENS, "size": (w, h)}, out, 1.0)
            parts.append(os.path.join(out, "f%04d_s%d.png" % (i, k)))
        im = Image.new("RGB", (w, h))
        y = h
        for p in parts:
            st = Image.open(p).convert("RGB")
            y -= st.height
            im.paste(st, (0, y))
            os.remove(p)
        im.save(dst)
        print("FRAME", i, flush=True)
    print("ALLDONE", flush=True)


if __name__ == "__main__":
    main()
