"""Street clutter (step 7c) from street_catalogue.json (read off John's photos) + OSM + BCC practice:
street lights with banners, heritage lamps, traffic signals with stop lines and crossings, signs,
billboards (our own placeholder art), the red Ann St bus lane, turn arrows, planted islands, planters."""
import json
import math
import os

import layout as L
import common as C

CAT = os.path.join(L.HERE, "street_catalogue.json")
CAR = {"primary", "secondary", "tertiary", "secondary_link", "tertiary_link", "unclassified", "residential"}


def cat():
    return json.load(open(CAT, encoding="utf-8"))


def road_width(t):
    lanes = L.tag_float(t, "lanes")
    return max(lanes * L.LANE_WIDTH, 3.0) if lanes else L.ROAD_WIDTH.get(t.get("highway"), 6.0)


def heading_to(a, b):
    return math.atan2(b[1] - a[1], b[0] - a[0])


ROAD = {}   # set per node: centre point, across-direction and width, so marks follow the road crown


def flat_quad(buf, pts, z_lift=0.06):
    def z(x, y):
        if ROAD:
            cx, cy, nx, ny, wd = ROAD["c"]
            v = abs((x - cx) * nx + (y - cy) * ny)
            return L.ground_z(x, y) + 0.046 + 0.025 * max(0.0, wd / 2 - v) + 0.008
        return L.ground_z(x, y) + z_lift
    buf.add([(x, y, z(x, y)) for x, y in pts], [[0, 1, 2, 3]])


def lantern(lant, board, lit_r, lit_g, x, y, z, ang, green):
    """Brisbane 3-aspect lantern: black housing on a yellow target board, one aspect lit."""
    board.box(x, y, z - 0.15, 0.75, 0.04, 1.35, ang)
    nx, ny = math.cos(ang - math.pi / 2), math.sin(ang - math.pi / 2)
    lant.box(x + nx * 0.06, y + ny * 0.06, z, 0.36, 0.25, 1.05, ang)
    for k, zz in enumerate((z + 0.87, z + 0.52, z + 0.17)):             # red, amber, green top to bottom
        lit = (k == 0 and not green) or (k == 2 and green)
        cx, cy = x + nx * 0.2, y + ny * 0.2
        disc(lit_r if (lit and k == 0) else lit_g if lit else unlit, cx, cy, zz, nx, ny, 0.11)
        visor = [(cx + math.cos(ang) * 0.13 * math.cos(a), cy + math.sin(ang) * 0.13 * math.cos(a), zz + 0.13 * math.sin(a))
                 for a in [math.pi * i / 6 for i in range(7)]]
        n = len(visor)
        lant.add([(vx, vy, vz) for vx, vy, vz in visor] + [(vx + nx * 0.16, vy + ny * 0.16, vz) for vx, vy, vz in visor],
                 [[i, i + 1, n + i + 1, n + i] for i in range(n - 1)])


def disc(buf, cx, cy, cz, nx, ny, r, k=12):
    """Round lens facing (nx, ny)."""
    ux, uy = -ny, nx
    pts = [(cx + ux * r * math.cos(2 * math.pi * i / k), cy + uy * r * math.cos(2 * math.pi * i / k), cz + r * math.sin(2 * math.pi * i / k))
           for i in range(k)]
    buf.add(pts, [list(range(k))[::-1]])


def build():
    if L.spire_stage() is not None or L.hsw_stage() is not None:
        pass   # street clutter is the same in every stage (blockout)
    c = cat()
    col = C.collection("streetscape")
    o = L.osm()
    lant, board, lit_r, lit_g, blade, yellow = (C.MeshBuf() for _ in range(6))
    global unlit
    unlit = C.MeshBuf()
    bins, bollards, cars = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    nblade = 0
    poles, heads, banners_b, banners_p, signs, sign_faces, boards, art1, art2, red, white, hedge, plant = (C.MeshBuf() for _ in range(13))
    counts = {}
    # ---------------------------------------------------------------- street lights along named streets
    sl = c["street_lights"]
    n = 0
    for w in o["ways"].values():
        t = w.get("tags", {})
        if t.get("name") not in sl["streets"] or t.get("highway") not in CAR | {"service"}:
            continue
        pts = o["line"](w)
        if len(pts) < 2:
            continue
        wd = road_width(t)
        acc = sl["spacing_m"] / 2
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            ln = math.dist((ax, ay), (bx, by))
            ang = math.atan2(by - ay, bx - ax)
            nx, ny = -math.sin(ang), math.cos(ang)
            d = acc
            while d < ln:
                x, y = ax + (bx - ax) * d / ln, ay + (by - ay) * d / ln
                if math.hypot(x, y) < sl["radius_m"]:
                    for side in ((1,) if t.get("oneway") == "yes" else (1, -1)):
                        px, py = x + nx * side * (wd / 2 + 0.6), y + ny * side * (wd / 2 + 0.6)
                        g = L.ground_z(px, py) + L.KERB_HEIGHT
                        poles.box(px, py, g, 0.2, 0.2, 9.0)
                        ex, ey = px - nx * side * 1.8, py - ny * side * 1.8
                        poles.beam((px, py, g + 8.8), (ex, ey, g + 9.0), 0.1)
                        heads.box(ex, ey, g + 8.75, 0.7, 0.3, 0.25, ang)
                        for b in c["banners"]:
                            if t.get("name") == b["street"] and min(b["from"][0], b["to"][0]) <= px <= max(b["from"][0], b["to"][0]):
                                (banners_b if b["colour"] == "blue" else banners_p).box(
                                    px + math.cos(ang) * 0.45, py + math.sin(ang) * 0.45, g + 4.5, 0.8, 0.03, 2.2, ang)
                        n += 1
                d += sl["spacing_m"]
            acc = d - ln
    counts["street_lights"] = n
    for lp in c["heritage_lamps"]:
        x, y = lp["xy"]
        g = L.ground_z(x, y)
        poles.box(x, y, g, 0.25, 0.25, 4.0)
        for s in (-1, 1):
            heads.box(x + s * 0.45, y, g + 4.0, 0.45, 0.45, 0.45)
    counts["heritage_lamps"] = len(c["heritage_lamps"])
    # ---------------------------------------------------------------- traffic signals, stop lines, crossings
    raw = json.load(__import__("gzip").open(L.ref("osm_spire_800m.json.gz"), "rt", encoding="utf-8"))
    nodes = [e for e in raw["elements"] if e["type"] == "node" and e.get("tags")]
    ways_of = {}
    for w in o["ways"].values():
        if w.get("tags", {}).get("highway") in CAR:
            for nid in w["nodes"]:
                ways_of.setdefault(nid, []).append(w)
    nsig = ncross = 0
    for e in nodes:
        x, y = L.to_local(e["lat"], e["lon"])
        if math.hypot(x, y) > 300:
            continue
        t = e["tags"]
        sig = t.get("highway") == "traffic_signals"
        cross = t.get("highway") == "crossing" and t.get("crossing") in ("traffic_signals", "marked", "zebra", "uncontrolled")
        if not (sig or cross) or e["id"] not in ways_of:
            continue
        w = ways_of[e["id"]][0]
        P = o["line"](w)
        i = w["nodes"].index(e["id"])
        j = i + 1 if i + 1 < len(P) else i - 1
        ang = heading_to(P[i], P[j]) if j >= 0 else 0.0
        wd = road_width(w["tags"])
        ux, uy = math.cos(ang), math.sin(ang)
        nx, ny = -uy, ux
        ROAD["c"] = (x, y, nx, ny, wd)
        if sig:
            names = sorted({ww["tags"].get("name") for ww in ways_of[e["id"]] if ww["tags"].get("name")})
            for k, side in enumerate((1, -1)):
                for fb in (1, -1):                                         # a pole at each corner
                    px = x + nx * side * (wd / 2 + 0.8) + ux * fb * 3.0
                    py = y + ny * side * (wd / 2 + 0.8) + uy * fb * 3.0
                    g = L.ground_z(px, py) + L.KERB_HEIGHT
                    poles.box(px, py, g, 0.18, 0.18, 5.2)
                    face = ang + (0 if fb > 0 else math.pi)                # lantern faces oncoming traffic
                    fx, fy = math.cos(face), math.sin(face)
                    lantern(lant, board, lit_r, lit_g, px + fx * 0.25, py + fy * 0.25, g + 2.6, face + math.pi / 2,
                            green=(k + (fb > 0)) % 2 == 0)
                    lant.box(px - fx * 0.2, py - fy * 0.2, g + 2.2, 0.25, 0.2, 0.45, face)        # ped lantern
                    disc(lit_r if (k + (fb > 0)) % 2 else lit_g, px - fx * 0.31, py - fy * 0.31, g + 2.42, -fx, -fy, 0.08)
                    poles.box(px - fx * 0.12, py - fy * 0.12, g + 1.0, 0.12, 0.08, 0.18, face)       # push button
                    if names and fb > 0:                                   # BCC blue blade, white name
                        nm = names[(k) % len(names)]
                        bang = ang if k == 0 else ang + math.pi / 2
                        blade.box(px, py, g + 5.2, 2.2, 0.04, 0.42, bang)
                        poles.box(px, py, g + 5.0, 0.1, 0.1, 0.6)
                        for s2 in (1, -1):
                            C.text_obj(col, "streetname", nm.upper().replace("STREET", "ST").replace("TERRACE", "TCE"),
                                       (px - math.sin(bang) * 0.03 * s2, py + math.cos(bang) * 0.03 * s2, g + 5.41),
                                       (math.radians(90), 0, bang + (0 if s2 > 0 else math.pi)), 0.26, (0.95, 0.95, 0.95))
                        nblade += 1
                if side == 1 and wd > 9:                                   # mast arm over the road
                    px, py = x + nx * (wd / 2 + 0.8) - ux * 3.0, y + ny * (wd / 2 + 0.8) - uy * 3.0
                    g = L.ground_z(px, py) + L.KERB_HEIGHT
                    poles.box(px, py, g, 0.3, 0.3, 6.4)
                    poles.beam((px, py, g + 6.2), (px - nx * wd * 0.7, py - ny * wd * 0.7, g + 6.2), 0.18)
                    for f in (0.35, 0.6):
                        lantern(lant, board, lit_r, lit_g, px - nx * wd * f, py - ny * wd * f, g + 5.0, ang + math.pi / 2, green=True)
            for oo in (1, -1):                                             # yellow no-stopping lines 20 m back
                kx, ky = x + nx * oo * (wd / 2 - 0.15), y + ny * oo * (wd / 2 - 0.15)
                flat_quad(yellow, [(kx, ky), (kx - ux * 20, ky - uy * 20), (kx - ux * 20 + nx * 0.1, ky - uy * 20 + ny * 0.1),
                                   (kx + nx * 0.1, ky + ny * 0.1)], 0.07)
            sx, sy = x - ux * 2.0, y - uy * 2.0                            # stop line
            flat_quad(white, [(sx + nx * wd / 2, sy + ny * wd / 2), (sx - nx * wd / 2, sy - ny * wd / 2),
                              (sx - nx * wd / 2 - ux * 0.4, sy - ny * wd / 2 - uy * 0.4), (sx + nx * wd / 2 - ux * 0.4, sy + ny * wd / 2 - uy * 0.4)])
            nsig += 1
        if cross or sig:
            k = int(wd / 1.0)
            for s in range(k):                                             # zebra stripes across the road
                v = -wd / 2 + (s + 0.25) * wd / k
                cx, cy = x + ux * 3.5 + nx * v, y + uy * 3.5 + ny * v
                flat_quad(white, [(cx - ux * 1.5, cy - uy * 1.5), (cx + ux * 1.5, cy + uy * 1.5),
                                  (cx + ux * 1.5 + nx * 0.5, cy + uy * 1.5 + ny * 0.5), (cx - ux * 1.5 + nx * 0.5, cy - uy * 1.5 + ny * 0.5)])
            ncross += 1
    ROAD.clear()
    counts["signals"] = nsig
    counts["street_name_blades"] = nblade
    counts["crossings"] = ncross
    # ---------------------------------------------------------------- signs
    for s in c["signs"]:
        x, y = s["xy"]
        g = L.ground_z(x, y) + L.KERB_HEIGHT
        poles.box(x, y, g, 0.08, 0.08, 3.0)
        w_, h_ = s.get("size", [0.6, 0.8] if s["kind"] != "street_name" else [1.2, 0.25])
        ang = heading_to((x, y), s["face_to"]) + math.pi / 2 if "face_to" in s else 0.0
        (sign_faces if s["kind"] in ("directional_green", "street_name") else signs).box(x, y, g + 3.0 - h_, w_, 0.05, h_, ang)
    counts["signs"] = len(c["signs"])
    # ---------------------------------------------------------------- billboards (placeholder art)
    for bb in c["billboards"]:
        x, y = bb["xy"]
        g = bb.get("base_ahd", L.ground_z(x, y) + bb.get("base_above_ground", 0.0))
        w_, h_ = bb["size"]
        ang = heading_to((x, y), bb["face_to"]) + math.pi / 2
        boards.box(x, y, g, w_ + 0.4, 0.4, h_ + 0.4, ang)                  # frame
        fx, fy = math.cos(ang - math.pi / 2) * 0.22, math.sin(ang - math.pi / 2) * 0.22
        (art1 if bb["art"] == "sky_beach" else art2).box(x + fx, y + fy, g + 0.2, w_, 0.05, h_, ang)
        for s in (-1, 1):
            boards.box(x + math.cos(ang) * s * w_ * 0.3, y + math.sin(ang) * s * w_ * 0.3, g - 2.0, 0.25, 0.25, 2.2)
    counts["billboards"] = len(c["billboards"])
    # ---------------------------------------------------------------- lane markings: Ann St red bus lane, turn arrows
    bl = c["lane_markings"]["bus_lane"]
    nb = 0
    for w in o["ways"].values():
        t = w.get("tags", {})
        if t.get("name") != bl["street"] or t.get("highway") not in CAR:
            continue
        pts = C.densify(o["line"](w), 3.0)
        if not any(math.hypot(*p) < 350 for p in pts) or len(pts) < 2:
            continue
        wd = road_width(t)
        a, b = C.offset_line(pts, wd / 2 - 0.15), C.offset_line(pts, wd / 2 - 0.15 - bl["width_m"])
        m = len(pts)
        za = 0.046 + 0.025 * 0.15 + 0.05
        zb = 0.046 + 0.025 * (0.15 + bl["width_m"]) + 0.05
        li = C.offset_line(pts, wd / 2 - 0.15 - bl["width_m"] - 0.06)
        li2 = C.offset_line(pts, wd / 2 - 0.15 - bl["width_m"] + 0.06)
        white.add([(x, y, L.ground_z(x, y) + zb + 0.004) for x, y in li] + [(x, y, L.ground_z(x, y) + zb + 0.004) for x, y in li2],
                  [[i, m + i, m + i + 1, i + 1] for i in range(m - 1)])               # bus lane line
        red.add([(x, y, L.ground_z(x, y) + za) for x, y in a] + [(x, y, L.ground_z(x, y) + zb) for x, y in b],
                [[i, m + i, m + i + 1, i + 1] for i in range(m - 1)])
        nb += 1
    counts["bus_lane_ways"] = nb
    for w in o["ways"].values():                                           # BUS ONLY words every ~60 m
        t2 = w.get("tags", {})
        if t2.get("name") != bl["street"] or t2.get("highway") not in CAR:
            continue
        pts = C.densify(o["line"](w), 60.0)
        wd = road_width(t2)
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            if math.hypot(ax, ay) > 300:
                continue
            a2 = math.atan2(by - ay, bx - ax)
            cx = ax - math.sin(a2) * (wd / 2 - 1.8)
            cy = ay + math.cos(a2) * (wd / 2 - 1.8)
            ob_t = C.text_obj(col, "busonly", "BUS ONLY", (cx, cy, L.ground_z(cx, cy) + 0.046 + 0.025 * 1.8 + 0.06), (0, 0, a2 - math.pi / 2), 0.55, (0.9, 0.9, 0.86))
            ob_t.scale = (1.0, 3.0, 1.0)                                    # stretched along the lane
    for ar in c["lane_markings"]["turn_arrows"]:
        x, y = ar["xy"]
        h = math.radians(90 - ar["heading"])
        ux, uy = math.cos(h), math.sin(h)
        nx, ny = -uy, ux
        shaft = [(x - ux * 3 - nx * 0.15, y - uy * 3 - ny * 0.15), (x - nx * 0.15, y - ny * 0.15),
                 (x + nx * 0.15, y + ny * 0.15), (x - ux * 3 + nx * 0.15, y - uy * 3 + ny * 0.15)]
        flat_quad(white, shaft, 0.065)
        tip = [(x - nx * 0.15, y - ny * 0.15), (x + nx * 1.2, y + ny * 1.2), (x + nx * 1.2 + ux * 0.3, y + ny * 1.2 + uy * 0.3),
               (x - nx * 0.15 + ux * 0.3, y - ny * 0.15 + uy * 0.3)]
        flat_quad(white, tip, 0.065)
    # ---------------------------------------------------------------- greenery: islands, planters
    for isl in c["greenery"]["islands"]:
        ring = [tuple(p) for p in isl["poly"]]
        z = min(L.ground_z(*p) for p in ring)
        hedge.prism(ring, z, z + 0.15)                                    # kerbed island, mulch top
        cx_ = sum(p[0] for p in ring) / 4
        cy_ = sum(p[1] for p in ring) / 4
        for i in range(14):                                               # low hedge + shrubs
            a, rr = i * 2.4, 0.15 + 0.6 * ((i * 37) % 10) / 10
            plant.box(cx_ + math.cos(a) * rr * 7, cy_ + math.sin(a) * rr * 9, z + 0.15, 1.2, 1.2, 0.45 + 0.25 * (i % 3), a)
        for px, py in isl["palms"]:
            poles.box(px, py, z, 0.35, 0.35, 8.0)
            for k in range(7):
                a = 2 * math.pi * k / 7
                plant.beam((px, py, z + 7.8), (px + 3.0 * math.cos(a), py + 3.0 * math.sin(a), z + 6.6), 0.45, 0.12)
    for it in c.get("furniture", []):
        x, y = it["xy"]
        g = L.ground_z(x, y) + L.KERB_HEIGHT
        ang = math.radians(it.get("heading", 0))
        if it["kind"] == "bin":
            bins.box(x, y, g, 0.6, 0.6, 1.0, ang)
        elif it["kind"] == "bollards":
            for k in range(it.get("n", 4)):
                bollards.box(x + math.cos(ang) * 1.4 * k, y + math.sin(ang) * 1.4 * k, g, 0.18, 0.18, 0.95)
        elif it["kind"] == "cars":
            for k in range(it.get("n", 3)):
                cx2, cy2 = x + math.cos(ang) * 6.0 * k, y + math.sin(ang) * 6.0 * k
                gz = L.ground_z(cx2, cy2) + 0.05
                cars.box(cx2, cy2, gz + 0.3, 4.5, 1.8, 0.75, ang)
                cars.box(cx2 - math.cos(ang) * 0.3, cy2 - math.sin(ang) * 0.3, gz + 1.05, 2.4, 1.6, 0.55, ang)
    for pl in c["greenery"]["planters"]:
        x, y = pl["xy"]
        sx, sy, sz = pl["size"]
        g = L.ground_z(x, y) + L.KERB_HEIGHT
        boards.box(x, y, g, sx, sy, sz)
        plant.box(x, y, g + sz, sx * 0.9, sy * 0.8, 0.6)
    objs = []
    mats = {"poles": (0.55, 0.57, 0.58), "heads": (0.20, 0.21, 0.22), "banners_b": (0.10, 0.35, 0.75),
            "banners_p": (0.85, 0.25, 0.55), "signs": (0.92, 0.92, 0.90), "sign_faces": (0.10, 0.45, 0.25),
            "boards": (0.15, 0.15, 0.16), "art1": (0.25, 0.65, 0.80), "art2": (0.80, 0.42, 0.12),
            "red": (0.55, 0.16, 0.12), "white": (0.93, 0.93, 0.90), "hedge": (0.42, 0.36, 0.28), "plant": (0.22, 0.42, 0.18)}
    for name, buf, rgb, emit in (("lanterns", lant, (0.03, 0.03, 0.035), 0), ("target_boards", board, (0.85, 0.65, 0.05), 0),
                                 ("lit_red", lit_r, (1.0, 0.045, 0.028), 4.0), ("lit_green", lit_g, (0.045, 1.0, 0.14), 4.0),
                                 ("lenses_unlit", unlit, (0.06, 0.05, 0.03), 0), ("bins", bins, (0.12, 0.30, 0.16), 0),
                                 ("bollards", bollards, (0.55, 0.56, 0.57), 0), ("parked_cars", cars, (0.55, 0.57, 0.60), 0),
                                 ("name_blades", blade, (0.04, 0.16, 0.50), 0), ("no_stopping_yellow", yellow, (0.92, 0.75, 0.10), 0)):
        ob = buf.object("street_" + name, col, "roof")
        if ob:
            m = C.material_rgb("street_" + name, rgb)
            if emit:
                m["emit"] = emit
            ob.data.materials[0] = m
            objs.append(ob.name)
    for name, buf in (("poles", poles), ("heads", heads), ("banners_b", banners_b), ("banners_p", banners_p),
                      ("signs", signs), ("sign_faces", sign_faces), ("boards", boards), ("art1", art1), ("art2", art2),
                      ("red", red), ("white", white), ("hedge", hedge), ("plant", plant)):
        ob = buf.object("street_" + name, col, "roof")
        if ob:
            ob.data.materials[0] = C.material_rgb("street_" + name, mats[name])
            objs.append(ob.name)
    return {"module": "streetscape", "objects": objs, "counts": counts,
            "note": "From street_catalogue.json (photos) + OSM nodes; billboard art is placeholder colour, not real ads."}
