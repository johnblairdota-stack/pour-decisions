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


def flat_quad(buf, pts, z_lift=0.06):
    buf.add([(x, y, L.ground_z(x, y) + z_lift) for x, y in pts], [[0, 1, 2, 3]])


def build():
    if L.spire_stage() is not None or L.hsw_stage() is not None:
        pass   # street clutter is the same in every stage (blockout)
    c = cat()
    col = C.collection("streetscape")
    o = L.osm()
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
        if sig:
            for side in (1, -1):
                px, py = x + nx * side * (wd / 2 + 0.8), y + ny * side * (wd / 2 + 0.8)
                g = L.ground_z(px, py) + L.KERB_HEIGHT
                poles.box(px, py, g, 0.18, 0.18, 5.0)
                heads.box(px, py, g + 3.0, 0.35, 0.3, 1.1, ang)
                if side == 1 and wd > 9:                                   # mast arm over the road
                    poles.beam((px, py, g + 5.6), (px - nx * wd * 0.6, py - ny * wd * 0.6, g + 5.6), 0.15)
                    heads.box(px - nx * wd * 0.45, py - ny * wd * 0.45, g + 4.8, 0.35, 0.3, 1.0, ang)
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
    counts["signals"] = nsig
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
        red.add([(x, y, L.ground_z(x, y) + 0.055) for x, y in a] + [(x, y, L.ground_z(x, y) + 0.055) for x, y in b],
                [[i, m + i, m + i + 1, i + 1] for i in range(m - 1)])
        nb += 1
    counts["bus_lane_ways"] = nb
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
        hedge.prism(ring, z, z + 0.2)
        inner = [(sum(p[0] for p in ring) / 4 + (p[0] - sum(q[0] for q in ring) / 4) * 0.85,
                  sum(p[1] for p in ring) / 4 + (p[1] - sum(q[1] for q in ring) / 4) * 0.85) for p in ring]
        plant.prism(inner, z + 0.2, z + 0.2 + isl["hedge_m"])
        for px, py in isl["palms"]:
            poles.box(px, py, z, 0.35, 0.35, 8.0)
            for k in range(7):
                a = 2 * math.pi * k / 7
                plant.beam((px, py, z + 7.8), (px + 3.0 * math.cos(a), py + 3.0 * math.sin(a), z + 6.6), 0.45, 0.12)
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
    for name, buf in (("poles", poles), ("heads", heads), ("banners_b", banners_b), ("banners_p", banners_p),
                      ("signs", signs), ("sign_faces", sign_faces), ("boards", boards), ("art1", art1), ("art2", art2),
                      ("red", red), ("white", white), ("hedge", hedge), ("plant", plant)):
        ob = buf.object("street_" + name, col, "roof")
        if ob:
            ob.data.materials[0] = C.material_rgb("street_" + name, mats[name])
            objs.append(ob.name)
    return {"module": "streetscape", "objects": objs, "counts": counts,
            "note": "From street_catalogue.json (photos) + OSM nodes; billboard art is placeholder colour, not real ads."}
