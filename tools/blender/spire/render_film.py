"""The Spire fly-in as a film: one camera flight through the Brisbane model, frame by frame, from high
in the cloud in the cloud down to the floor pick's own view, where the game takes over standing still.

    python tools/blender/spire/render_film.py <out_dir> [tower=spire] [from=0] [to=N] [w=1280] [fps=24] [tiles=<dir>] [--cams]

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
# A tower with decks to pick (FLOORS: how many, m apart, film frames a deck) ends another way: END is
# the first deck's view, and every deck above it has the same view FLOORS[1] m higher. The film comes
# in to the TOP deck's view and then runs straight down the face at a steady rate, standing on each
# deck's own view for exactly one frame, down to the first. The game stops the film on the frame of
# the deck the crew is up to (cams.json "floors": deck -> frame), so it never flies past them.
FLOORS = None
FPS = 24
# From the end of the run in, those frames are WIDE: a fisheye picture (the angle off its middle is
# the distance from the picture's middle, WIDE_PPD pixels a degree), looking the floor pick's way but
# WIDE_PITCH degrees down, that takes in everything from the floor pick's level view to nearly
# straight down. The game cuts its own view out of it (shaders/fly_wide.gdshader), so its camera can
# look down onto whichever deck it is going to stop at and level out as it gets there.
WIDE_PITCH, WIDE_PPD, WIDE_SIZE = -33.0, 14.0, (1280, 1568)
WIDE_FOV = 140.0                  # degrees across the whole fisheye: its corners are needed, so it is rendered bigger and cut down to WIDE_SIZE
IN_T = 2.0                        # s, about: from the run in to the top deck's view (rounded so that lands on a frame)
CUT_Z = float(os.environ.get("CUT_Z", "42.35"))   # AHD: the tower's cut off here (the game's first deck: it isn't built yet)


# Every tower's flight is this one, with its own numbers. `end` is the game's floor pick camera where
# the tower has one. The others are PROVISIONAL (a view of the tower's lower floors from `hdir`, set
# only so the flight can be judged): they get the game's real view, the cut at the first deck and a
# full render once their level exists. None of this says anything about equipment or how a tower's
# poured. Places are in the model's metres (x east, y north of Spire, z AHD).
TOWERS = {
    "spire": {"t": T, "hdir": HDIR, "end": END, "over": (OVER_OUT, OVER_Z), "cut": CUT_Z, "floors": (34, 2.9, 2)},
    # Howard Smith Wharves: low, on the river bank under the Story Bridge (deck about 80 m AHD overhead):
    # in from over the river, well over the bridge until it's close.
    "hsw": {"t": (621.0, 25.0, 12.0), "hdir": (0.26, -0.966), "s": (2800.0, 320.0), "el": (36.0, 26.0),
            "end_at": (95.0, 22.0, 10.0), "over": (140.0, 118.0)},
    # 1 William St: 267 m, the river and the expressway on its south-west side: in from over the river.
    "william1": {"t": (-494.0, -1345.0, 120.0), "hdir": (-0.707, -0.707), "s": (3000.0, 420.0), "el": (36.0, 22.0),
                 "end_at": (150.0, 60.0, 55.0), "over": (190.0, 200.0)},
    # Queen's Wharf: beside it, the same bank: in from over the river and the Neville Bonner Bridge.
    "queenswharf": {"t": (-533.0, -1168.0, 70.0), "hdir": (-0.80, -0.60), "s": (3000.0, 380.0), "el": (36.0, 22.0),
                    "end_at": (170.0, 55.0, 45.0), "over": (200.0, 170.0)},
    # Brisbane Skytower: 277 m, the City Botanic Gardens to its south-east: in from over the gardens.
    "skytower": {"t": (-207.0, -978.0, 125.0), "hdir": (0.50, -0.866), "s": (3000.0, 430.0), "el": (36.0, 22.0),
                 "end_at": (160.0, 65.0, 60.0), "over": (200.0, 215.0)},
}
TOWER = "spire"


def use(tower):
    """Fly this tower's flight from here on."""
    global TOWER, T, HDIR, S0, S1, EL0, EL1, END, OVER_OUT, OVER_Z, CUT_Z, FLOORS, TOTAL
    c = TOWERS[tower]
    TOWER, T, HDIR = tower, c["t"], c["hdir"]
    S0, S1 = c.get("s", (2800.0, 270.0))
    EL0, EL1 = c.get("el", (36.0, 24.0))
    OVER_OUT, OVER_Z = c["over"]
    CUT_Z = c.get("cut")
    if "end" in c:
        END = c["end"]
    else:
        out, z, look_z = c["end_at"]         # (m out along hdir, the camera's height, the height it looks at)
        END = ((T[0] + HDIR[0] * out, T[1] + HDIR[1] * out, z), (T[0], T[1], look_z))
    FLOORS = c.get("floors")
    TOTAL = floor_frame(0) / FPS if FLOORS else DUR + LEG[0] + LEG[1]


def top_frame():
    """The frame that stands on the top deck's view."""
    return int(math.ceil((DUR + IN_T) * FPS))


def floor_frame(i):
    """The frame that stands on deck i's view (0 = the first deck, the film's last frame)."""
    return top_frame() + (FLOORS[0] - 1 - i) * FLOORS[2]


def wide_from():
    """The first wide frame (none: -1)."""
    return int(math.floor(DUR * FPS)) + 1 if FLOORS else -1


def wide_dir():
    """Where the middle of a wide frame looks (a unit vector, the model's metres)."""
    e, f = END
    n = math.hypot(f[0] - e[0], f[1] - e[1])
    c, s_ = math.cos(math.radians(WIDE_PITCH)), math.sin(math.radians(WIDE_PITCH))
    return ((f[0] - e[0]) / n * c, (f[1] - e[1]) / n * c, s_)


def shoot_wide(i, dst, y0=0.0, y1=1.0):
    """Frame i as a wide frame (y0..y1 of its height, from the bottom)."""
    import bpy
    import preview as P
    from mathutils import Vector
    cam = P.camera("cam_cbd")
    cam.data.type = "PANO"
    cam.data.panorama_type = "FISHEYE_EQUIDISTANT"
    w, h = WIDE_SIZE
    cam.data.fisheye_fov = math.radians(WIDE_FOV)
    full = int(round(WIDE_FOV * WIDE_PPD))            # (the whole square fisheye, of which WIDE_SIZE is the middle)
    cam.data.sensor_fit = "AUTO"
    cam.data.clip_start, cam.data.clip_end = 1.0, 8000
    cam.location = Vector(cam_at(i / FPS)[0])
    cam.rotation_euler = Vector(wide_dir()).to_track_quat("-Z", "Y").to_euler()
    sc = bpy.context.scene
    sc.render.border_min_x, sc.render.border_max_x = (full - w) / 2.0 / full, (full + w) / 2.0 / full
    sc.render.border_min_y, sc.render.border_max_y = ((full - h) / 2.0 + y0 * h) / full, ((full - h) / 2.0 + y1 * h) / full
    P.hide(["logistics"], True)
    P.render(dst, full, full)


def _down(t):
    """In to the top deck's view, then straight down the face."""
    e, f = END
    n, dz, per = FLOORS
    rise = (n - 1) * dz
    t_top = top_frame() / FPS
    v = dz * FPS / per                                   # (m/s down the face)
    top = (e[0], e[1], e[2] + rise)
    if t >= t_top:
        z = max(e[2], top[2] - v * (t - t_top))
        return (e[0], e[1], z), (f[0], f[1], f[2] + z - e[2])
    p0, a = run_in(DUR), run_in(DUR - 0.01)
    v0 = tuple((p0[i] - a[i]) / 0.01 for i in range(3))
    d = t_top - DUR
    p = _herm(p0, v0, top, (0.0, 0.0, -v), (t - DUR) / d, d)   # (already going down at the face's rate as it gets there)
    k = smooth(0.0, 0.9, (t - DUR) / d)
    look = (f[0], f[1], f[2] + rise)
    return p, tuple(T[i] + (look[i] - T[i]) * k for i in range(3))


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
    if FLOORS:
        return _down(t)
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
    if CUT_Z is None:          # (a provisional flight: the finished tower)
        return
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
    global FPS
    fps, w = num("fps", 24), num("w", 1280)
    FPS = fps
    use(next((a[6:] for a in argv if a.startswith("tower=")), "spire"))
    n = int(round(TOTAL * fps)) + 1
    f0, f1 = num("from", 0), min(n, num("to", n))
    h = w * 9 // 16
    json.dump({"tower": TOWER, "provisional": "end" not in TOWERS[TOWER], "fps": fps, "frames": n, "dur": TOTAL, "run_in": DUR, "target": T, "lens": LENS,
               "floors": [floor_frame(i) for i in range(FLOORS[0])] if FLOORS else [],
               "wide": {"from": wide_from(), "dir": [round(v, 5) for v in wide_dir()], "ppd": WIDE_PPD, "size": list(WIDE_SIZE)} if FLOORS else {},
               "cams": [[round(v, 2) for v in cam_at(i / fps)[0]] for i in range(n)],
               "looks": [[round(v, 2) for v in cam_at(i / fps)[1]] for i in range(n)]}, open(os.path.join(out, "cams.json"), "w"))
    if "--cams" in argv:
        return
    import bpy
    import build_all
    import preview as P
    import render_cbd as R
    from PIL import Image
    tiles_dir = next((a[6:] for a in argv if a.startswith("tiles=")), None)
    if tiles_dir:
        # (the whole city no longer builds in one go: load only the 1 km tiles these frames can see,
        # from tools/city/tiles.py bake. Run a few dozen frames a process (from= to=) so the high
        # frames' many tiles are not held for the low ones.)
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "city"))
        import tiles as TL
        index = json.load(open(os.path.join(tiles_dir, "index.json")))
        half = math.pi if 0 <= wide_from() <= f1 - 1 else math.atan(18.0 / LENS)
        cams = []
        for i in range(f0, f1):
            (x, y, _z), look = cam_at(i / fps)
            cams.append((x, y, math.atan2(look[1] - y, look[0] - x), half))
        st = TL.load(tiles_dir, TL.tiles_for(index, cams))
        st.pop("ground")
        print("tiles loaded:", json.dumps(st), flush=True)
        cut_tower(None)
    else:
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
        if 0 <= wide_from() <= i:
            for k in range(strips):
                shoot_wide(i, os.path.join(out, "f%04d_s%d.png" % (i, k)), k / strips, (k + 1) / strips)
                parts.append(os.path.join(out, "f%04d_s%d.png" % (i, k)))
            w, h = WIDE_SIZE
        for k in range(0 if parts else strips):
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
