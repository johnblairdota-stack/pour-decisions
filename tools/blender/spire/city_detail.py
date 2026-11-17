"""The small things that make the city_wide area read as Brisbane (17 Nov 2026). Built after city_wide and
far_roads, outside LIDAR_BOX (the Spire square has its own detail modules).

On the buildings (best guesses from size, height and use; the LiDAR and aerial can't resolve them):
- flat roofs over 9 m: lift overrun / plant room, rows of AC condensers, cooling towers and a louvre screen
  on the bigger towers, a comms mast on some tall ones
- big low roofs (sheds, shops): ridge vents, and flat solar arrays on about a quarter
- houses: solar panels on the north-facing slope of about a third

On the ground (OSM areas in reference/sites/spire/wide/features.json):
- swimming pools: water and coping (on the roof or podium when the pool is mapped over a building)
- car parks: stall lines in double rows along the long side (the layout is a guess; the outline is OSM)
- pitches: line marking by sport, tennis nets, goals, rugby posts, basketball hoops, cricket strips
- playgrounds: a shade sail on four posts
- roads: speed signs along the main roads (left of travel, every ~240 m)
"""
import json
import math
import os
import random

import layout as L
import common as C
import shapes as S

WIDE = os.path.join(L.REF, "wide")
MATS = {"plant": (0.55, 0.56, 0.56), "ac": (0.78, 0.78, 0.75), "louvre": (0.36, 0.38, 0.40), "mast": (0.6, 0.6, 0.6),
        "solar": (0.015, 0.02, 0.045), "vent": (0.62, 0.63, 0.63), "pool": (0.05, 0.42, 0.55), "coping": (0.72, 0.70, 0.64),
        "line": (0.9, 0.9, 0.87), "net": (0.05, 0.05, 0.05), "post": (0.88, 0.88, 0.86), "strip": (0.62, 0.52, 0.36),
        "sail_a": (0.08, 0.22, 0.45), "sail_b": (0.72, 0.62, 0.42), "sail_c": (0.12, 0.34, 0.2),
        "sign_white": (0.92, 0.92, 0.9), "sign_red": (0.6, 0.03, 0.03), "sign_post": (0.5, 0.51, 0.52)}


def in_box(x, y):
    b = L.LIDAR_BOX
    return b[0] <= x <= b[2] and b[1] <= y <= b[3]


class Index:
    """Which building footprint is this point in (50 m cells)."""

    def __init__(self, recs):
        self.cells = {}
        for b in recs:
            r = b["tiers"][0]["ring"]
            xs, ys = [p[0] for p in r], [p[1] for p in r]
            for i in range(int(min(xs) // 50), int(max(xs) // 50) + 1):
                for j in range(int(min(ys) // 50), int(max(ys) // 50) + 1):
                    self.cells.setdefault((i, j), []).append(b)

    def at(self, x, y):
        for b in self.cells.get((int(x // 50), int(y // 50)), ()):
            if S.point_in(x, y, b["tiers"][0]["ring"]):
                return b
        return None


def rect(cx, cy, sx, sy, ang):
    c, s = math.cos(ang), math.sin(ang)
    return [(cx + dx * c - dy * s, cy + dx * s + dy * c) for dx, dy in ((-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2))]


def fits(ring, cx, cy, sx, sy, ang):
    return all(S.point_in(x, y, ring) for x, y in rect(cx, cy, sx + 1.6, sy + 1.6, ang))


def roof_plant(bufs, b, n):
    import buildings as B
    tiers = b["tiers"]
    t = tiers[-1]
    h = t["top_ahd"] - b["base_ahd"]
    ring = S.ccw([tuple(p) for p in t["ring"]])
    area = abs(S.area(ring))
    use = b.get("tags", {}).get("building", "yes")
    if b["gable"] and len(tiers) == 1:
        return
    cx, cy, ln, wd, ang = S.min_rect(ring)
    c, s = math.cos(ang), math.sin(ang)
    rnd = random.Random(int(b["osm"]) if str(b["osm"]).isdigit() else 7)
    z = t["top_ahd"] + (0.9 if h > 8 else 0.0)

    def at(u, v):
        return cx + u * c - v * s, cy + u * s + v * c

    if h < 14 and area > 900:                               # big low roof: vents down the middle, maybe solar
        k = int(ln // 12)
        for i in range(k):
            x, y = at(-ln / 2 + (i + 0.5) * ln / k, 0.0)
            if fits(ring, x, y, 1.2, 1.2, ang):
                bufs["vent"].box(x, y, z, 1.2, 1.2, 0.55, ang)
                n["vents"] += 1
        if rnd.random() < 0.25:
            for v in (-0.27 * wd, 0.27 * wd):
                u = -ln * 0.38
                while u < ln * 0.38:
                    x, y = at(u, v)
                    if fits(ring, x, y, 5.0, 3.4, ang):
                        bufs["solar"].box(x, y, z + 0.12, 5.0, 3.4, 0.06, ang)
                        n["solar_arrays"] += 1
                    u += 6.2
        return
    if h < 9 or area < 120 or use in ("roof", "carport", "shed", "garage"):
        return
    n["roofs_dressed"] += 1
    if h > 12:                                              # lift overrun / plant room
        for _ in range(6):
            x, y = at(rnd.uniform(-0.22, 0.22) * ln, rnd.uniform(-0.18, 0.18) * wd)
            sx, sy = (5.5, 4.0) if area > 500 else (3.6, 3.0)
            if fits(ring, x, y, sx, sy, ang):
                bufs["plant"].box(x, y, z, sx, sy, 3.0 if h > 25 else 2.5, ang)
                break
    k = max(1, min(12, int(area / 130)))                    # AC condensers in a row near one long side
    v = (0.30 if rnd.random() < 0.5 else -0.30) * wd
    for i in range(k):
        x, y = at((i - (k - 1) / 2) * 2.6 + rnd.uniform(-0.3, 0.3), v)
        if fits(ring, x, y, 1.8, 1.1, ang):
            bufs["ac"].box(x, y, z, 1.8, 1.1, 1.3, ang)
            n["ac_units"] += 1
    if area > 500 and h > 20:                               # cooling towers
        for i in (-1, 1):
            x, y = at(0.28 * ln, -v * 0.6 + i * 2.2)
            if fits(ring, x, y, 3.4, 3.4, ang):
                bufs["plant"].prism([(x + 1.6 * math.cos(a * math.pi / 4), y + 1.6 * math.sin(a * math.pi / 4)) for a in range(8)], z, z + 3.2)
                n["cooling_towers"] += 1
    if area > 400 and h > 30:                               # louvre screen round the plant
        if fits(ring, cx, cy, 0.5 * ln, 0.5 * wd, ang):
            B.loop_wall(bufs["louvre"], rect(cx, cy, 0.5 * ln, 0.5 * wd, ang), z, z + 3.2)
    if h > 40 and rnd.random() < 0.4:                       # comms mast
        x, y = at(-0.3 * ln, 0.0)
        if fits(ring, x, y, 1.0, 1.0, ang):
            hm = rnd.uniform(6.0, 11.0)
            bufs["mast"].beam((x, y, z), (x, y, z + hm), 0.22)
            for dz in (0.55, 0.8):
                bufs["mast"].box(x, y, z + hm * dz, 0.9, 0.25, 1.4, rnd.uniform(0, 3.1))
            n["masts"] += 1


def house_solar(bufs, b, n):
    g = b["gable"]
    if not g or len(b["tiers"]) != 1 or g["width"] < 6 or g["length"] < 7:
        return
    rnd = random.Random(int(b["osm"]) * 3 + 1 if str(b["osm"]).isdigit() else 3)
    if rnd.random() > 0.33:
        return
    c, s = math.cos(g["angle"]), math.sin(g["angle"])
    hw = g["width"] / 2 + 0.3
    side = 1.0 if c > 0 else -1.0                           # the slope whose fall faces more north
    if abs(c) < 0.3:                                        # ridge runs north-south: either slope (east or west)
        side = 1.0 if rnd.random() < 0.5 else -1.0
    half = min(g["length"] * 0.32, rnd.choice((2.6, 3.5, 4.4)))
    u0 = rnd.uniform(-1, 1) * (g["length"] / 2 - half - 0.6)
    e, r = g["eave_ahd"], g["ridge_ahd"]

    def P(u, v):
        return (g["cx"] + u * c - v * s, g["cy"] + u * s + v * c, r - (r - e) * abs(v) / hw + 0.09)

    v0, v1 = side * 0.22 * hw, side * 0.82 * hw
    q = [P(u0 - half, v0), P(u0 + half, v0), P(u0 + half, v1), P(u0 - half, v1)]
    bufs["solar"].add(q, [[0, 1, 2, 3] if side > 0 else [3, 2, 1, 0]])
    n["house_solar"] += 1


def line(buf, G, a, b, w=0.1, lift=0.2, top=None):
    """Painted line from a to b on the ground (or flat at z = top), in pieces of 4 m or less."""
    d = math.dist(a, b)
    if d < 0.05:
        return
    k = max(1, int(math.ceil(d / 4.0)))
    nx, ny = -(b[1] - a[1]) / d * w / 2, (b[0] - a[0]) / d * w / 2
    pts = [(a[0] + (b[0] - a[0]) * i / k, a[1] + (b[1] - a[1]) * i / k) for i in range(k + 1)]
    zs = [top] * (k + 1) if top is not None else [float(v) + lift for v in G.z([p[0] for p in pts], [p[1] for p in pts])]
    verts = [(p[0] + nx, p[1] + ny, z) for p, z in zip(pts, zs)] + [(p[0] - nx, p[1] - ny, z) for p, z in zip(pts, zs)]
    buf.add(verts, [[k + 1 + i, k + 2 + i, i + 1, i] for i in range(k)])


def circle(buf, G, x, y, r, w=0.1, n=20):
    pts = [(x + r * math.cos(2 * math.pi * i / n), y + r * math.sin(2 * math.pi * i / n)) for i in range(n + 1)]
    for a, b in zip(pts[:-1], pts[1:]):
        line(buf, G, a, b, w)


def pools(bufs, G, areas, idx, n):
    for a in areas:
        if a["kind"] != "swimming_pool" or len(a["ring"]) < 3:
            continue
        ring = S.ccw([tuple(p) for p in a["ring"]])
        cx, cy = sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring)
        if in_box(cx, cy) or abs(S.area(ring)) < 6:
            continue
        b = idx.at(cx, cy)
        if b:                                               # roof or podium pool: on the tier under it
            tops = [t["top_ahd"] for t in b["tiers"] if S.point_in(cx, cy, t["ring"])]
            z = max(tops) + (0.95 if max(tops) - b["base_ahd"] > 8 else 0.05)
            n["pools_on_roofs"] += 1
        else:
            z = float(max(G.z([p[0] for p in ring], [p[1] for p in ring]))) + 0.12
        import buildings as B
        bufs["coping"].prism(B.offset(ring, 0.45), z - 0.5, z + 0.04)
        bufs["pool"].prism(ring, z - 0.3, z + 0.08)
        n["pools"] += 1


def car_parks(bufs, G, areas, idx, n):
    for a in areas:
        if a["kind"] != "parking" or len(a["ring"]) < 3:
            continue
        ring = [tuple(p) for p in a["ring"]]
        cx, cy, ln, wd, ang = S.min_rect(ring)
        if in_box(cx, cy) or wd < 11 or ln < 12 or idx.at(cx, cy):
            continue
        c, s = math.cos(ang), math.sin(ang)
        rows = max(1, int(wd // 17.0))                      # double row: 5.4 m stalls each side of a spine, 6.2 m aisles
        m = 0
        for r in range(rows):
            v = (r - (rows - 1) / 2) * 17.0
            u = -ln / 2 + 1.0
            spine = []
            while u <= ln / 2 - 1.0:
                p = [(cx + u * c - vv * s, cy + u * s + vv * c) for vv in (v - 5.4, v, v + 5.4)]
                ok = [S.point_in(q[0], q[1], ring) and not idx.at(q[0], q[1]) for q in p]
                if ok[0] and ok[1]:
                    line(bufs["line"], G, p[0], p[1])
                    m += 1
                if ok[1] and ok[2]:
                    line(bufs["line"], G, p[1], p[2])
                    m += 1
                spine.append(p[1] if ok[1] else None)
                u += 2.6
            for p, q in zip(spine[:-1], spine[1:]):
                if p and q:
                    line(bufs["line"], G, p, q)
        if m:
            n["car_parks"] += 1
            n["stall_lines"] += m


def pitches(bufs, G, areas, n):
    for a in areas:
        if a["kind"] != "pitch" or len(a["ring"]) < 3:
            continue
        ring = [tuple(p) for p in a["ring"]]
        cx, cy, ln, wd, ang = S.min_rect(ring)
        if in_box(cx, cy):
            continue
        c, s = math.cos(ang), math.sin(ang)
        sport = a.get("sport", "")
        zc = float(G.z([cx], [cy])[0])

        def P(u, v, ox=cx, oy=cy):
            return ox + u * c - v * s, oy + u * s + v * c

        def box_lines(hl, hw, ox=cx, oy=cy, w=0.1):
            q = [P(-hl, -hw, ox, oy), P(hl, -hw, ox, oy), P(hl, hw, ox, oy), P(-hl, hw, ox, oy)]
            for i in range(4):
                line(bufs["line"], G, q[i], q[(i + 1) % 4], w)

        if "tennis" in sport or "pickleball" in sport:
            k = max(1, int(round(wd / 18.0))) if ln >= 22 else 0
            for i in range(k):
                ox, oy = P(0, (i - (k - 1) / 2) * (wd / k))
                box_lines(11.885, 5.485, ox, oy, 0.06)
                for v in (-4.115, 4.115):
                    line(bufs["line"], G, P(-11.885, v, ox, oy), P(11.885, v, ox, oy), 0.06)
                for u in (-6.4, 6.4):
                    line(bufs["line"], G, P(u, -4.115, ox, oy), P(u, 4.115, ox, oy), 0.06)
                line(bufs["line"], G, P(-6.4, 0, ox, oy), P(6.4, 0, ox, oy), 0.06)
                z = float(G.z([ox], [oy])[0])
                bufs["net"].box(ox, oy, z + 0.15, 0.05, 12.8, 0.95, ang)
                for v in (-6.4, 6.4):
                    x, y = P(0, v, ox, oy)
                    bufs["post"].beam((x, y, z), (x, y, z + 1.25), 0.09)
                n["tennis_courts"] += 1
        elif any(k in sport for k in ("soccer", "rugby", "football", "multi")) and ln > 40:
            hl, hw = ln / 2 - 2.0, wd / 2 - 2.0
            box_lines(hl, hw)
            line(bufs["line"], G, P(0, -hw), P(0, hw))
            rugby = "rugby" in sport or "football" in sport
            if not rugby or "soccer" in sport:
                circle(bufs["line"], G, cx, cy, min(9.15, hw * 0.3))
                bw, bd = min(20.15, hw * 0.6), min(16.5, hl * 0.3)
                for e in (-1, 1):
                    q = [P(e * hl, -bw), P(e * (hl - bd), -bw), P(e * (hl - bd), bw), P(e * hl, bw)]
                    for i in range(3):
                        line(bufs["line"], G, q[i], q[i + 1])
                    g0, g1 = P(e * hl, -3.66), P(e * hl, 3.66)
                    z = float(G.z([g0[0]], [g0[1]])[0])
                    bufs["post"].beam((*g0, z), (*g0, z + 2.44), 0.12)
                    bufs["post"].beam((*g1, z), (*g1, z + 2.44), 0.12)
                    bufs["post"].beam((*g0, z + 2.44), (*g1, z + 2.44), 0.12)
            if rugby:
                for e in (-1, 1):
                    for d in (6.0, 28.0):
                        if hl - d > 5:
                            line(bufs["line"], G, P(e * (hl - d), -hw), P(e * (hl - d), hw))
                    g0, g1 = P(e * (hl - 6.0), -2.8), P(e * (hl - 6.0), 2.8)
                    z = float(G.z([g0[0]], [g0[1]])[0])
                    bufs["post"].beam((*g0, z), (*g0, z + 13.0), 0.16)
                    bufs["post"].beam((*g1, z), (*g1, z + 13.0), 0.16)
                    bufs["post"].beam((*g0, z + 3.0), (*g1, z + 3.0), 0.14)
            n["fields"] += 1
        elif any(k in sport for k in ("basketball", "netball", "futsal")):
            hl, hw = min(ln / 2 - 0.5, 14.0), min(wd / 2 - 0.5, 7.5)
            if hl < 5 or hw < 3:
                continue
            box_lines(hl, hw, w=0.06)
            line(bufs["line"], G, P(0, -hw), P(0, hw), 0.06)
            circle(bufs["line"], G, cx, cy, 1.8, 0.06, 12)
            for e in (-1, 1):
                x, y = P(e * (hl + 0.6), 0)
                bufs["post"].beam((x, y, zc), (x, y, zc + 3.05), 0.14)
                bx, by = P(e * (hl - 0.6), 0)
                bufs["post"].beam((x, y, zc + 3.0), (bx, by, zc + 3.2), 0.1)
                bufs["post"].box(bx, by, zc + 2.9, 0.06, 1.8, 1.05, ang)
            n["courts"] += 1
        elif "cricket" in sport and ln > 40:
            bufs["strip"].prism(rect(cx, cy, 22.0, 3.05, ang), zc - 0.2, zc + 0.22)
            n["cricket_strips"] += 1
        elif sport in ("bowls", "croquet"):
            box_lines(ln / 2 - 0.5, wd / 2 - 0.5, w=0.2)
            n["greens"] += 1


def playgrounds(bufs, G, areas, n):
    for a in areas:
        if a["kind"] != "playground" or len(a["ring"]) < 3:
            continue
        cx, cy, ln, wd, ang = S.min_rect([tuple(p) for p in a["ring"]])
        if in_box(cx, cy) or wd < 4:
            continue
        q = rect(cx, cy, min(ln * 0.7, 12.0), min(wd * 0.7, 9.0), ang)
        zs = [float(v) for v in G.z([p[0] for p in q], [p[1] for p in q])]
        hs = (4.6, 3.0, 4.6, 3.0)
        top = [(q[i][0], q[i][1], max(zs) + hs[i]) for i in range(4)]
        for i in range(4):
            bufs["sign_post"].beam((q[i][0], q[i][1], zs[i] - 0.3), top[i], 0.16)
        k = "sail_" + "abc"[int(abs(cx * 3 + cy)) % 3]
        bufs[k].add(top, [[0, 1, 2], [0, 2, 3], [2, 1, 0], [3, 2, 0]])
        n["shade_sails"] += 1


def speed_signs(bufs, n):
    import far_roads as FR
    G = FR.GROUND
    if not os.path.exists(FR.ROADS):
        return
    for w in json.load(open(FR.ROADS))["ways"]:
        if w["kind"] != "road" or w["bridge"] or w["cls"] not in ("primary", "secondary", "tertiary", "trunk"):
            continue
        pts = w["pts"]
        for i in range(20 + w["id"] % 40, len(pts) - 2, 60):
            x, y = pts[i]
            if in_box(x, y):
                continue
            tx, ty, nx, ny = FR.frame([tuple(p) for p in pts], i)
            for sd in ((1,) if w["oneway"] else (1, -1)):   # left of travel, face to the oncoming driver
                o = w["width"] / 2 + 1.1
                px, py = x + nx * o * sd, y + ny * o * sd
                if sd < 0:
                    px, py = px + tx * 30, py + ty * 30
                z = float(G.z([px], [py])[0])
                fx, fy = -tx * sd, -ty * sd
                ang = math.atan2(fy, fx)
                bufs["sign_post"].beam((px, py, z - 0.3), (px, py, z + 2.9), 0.07)
                bufs["sign_white"].box(px + fx * 0.05, py + fy * 0.05, z + 2.05, 0.03, 0.6, 0.8, ang)
                for mat, r, d in (("sign_red", 0.24, 0.075), ("sign_white", 0.17, 0.085)):
                    ring = [(r * math.cos(a * math.pi / 6), r * math.sin(a * math.pi / 6)) for a in range(12)]
                    cxp, cyp = px + fx * d, py + fy * d
                    verts = [(cxp - fy * u, cyp + fx * u, z + 2.5 + v) for u, v in ring]
                    bufs[mat].add(verts, [list(range(12))])
                n["speed_signs"] += 1


def build():
    import bpy  # noqa: F401
    import city_wide as CW
    import far_roads as FR
    if L.GAME_EXPORT or getattr(L, "ACTIVE_STAGE", None) or CW.RECS is None or FR.GROUND is None:
        return {"module": "city_detail", "objects": [], "note": "skipped (game export, stage build or no city_wide)"}
    recs = CW.RECS
    G = FR.GROUND
    bufs = {k: C.MeshBuf() for k in MATS}
    n = {k: 0 for k in ("roofs_dressed", "ac_units", "cooling_towers", "masts", "vents", "solar_arrays", "house_solar", "pools",
                        "pools_on_roofs", "car_parks", "stall_lines", "tennis_courts", "fields", "courts", "cricket_strips",
                        "greens", "shade_sails", "speed_signs")}
    for b in recs:
        cx, cy = b["tiers"][0]["ring"][0]
        if in_box(cx, cy):
            continue
        roof_plant(bufs, b, n)
        house_solar(bufs, b, n)
    fp = os.path.join(WIDE, "features.json")
    areas = json.load(open(fp))["areas"] if os.path.exists(fp) else []
    idx = Index(recs)
    pools(bufs, G, areas, idx, n)
    car_parks(bufs, G, areas, idx, n)
    pitches(bufs, G, areas, n)
    playgrounds(bufs, G, areas, n)
    speed_signs(bufs, n)
    col = C.collection("city_detail")
    objs = []
    for k, buf in bufs.items():
        ob = buf.object("city_detail_" + k, col, "roof")
        if ob:
            m = C.material_rgb("city_detail_" + k, MATS[k])
            if k in ("pool", "solar"):
                m.roughness = 0.08
            ob.data.materials[0] = m
            objs.append(ob.name)
    return {"module": "city_detail", "objects": objs, "counts": n,
            "source": "best guesses from use, size and height (roofs); OSM areas in wide/features.json (ground)",
            "note": "Roof plant, solar, stall layouts and sign positions are inferred, not surveyed."}
