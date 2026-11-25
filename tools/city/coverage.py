#!/usr/bin/env python3
"""Coverage map of the Brisbane model: what each 1 km tile holds today, and what is next.

    python3 tools/city/coverage.py            # writes docs/city/coverage.{json,svg,md}
    python3 tools/city/coverage.py --check    # exit 1 if those files are out of date

Tiles are the 1 km squares of the MGA zone 56 grid (the same squares the LiDAR comes in), named by the
kilometre of their south-west corner, e.g. 503_6962. Needs only Python (no Blender, no numpy).

Grade of a tile (how real it is, not how busy it looks):
  0  nothing            outside every data set
  1  map only           aerial photo and map outlines, heights guessed
  2  measured           2019 LiDAR: real ground, real building heights, real tree tops
  3  hand-built heroes  measured, plus at least one landmark built by hand from references
Photo pairs (render matched to a real photo) are counted per tile on top of the grade.
"""
import csv
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender", "spire"))
import layout as L  # noqa: E402  (pure Python: the frame and the lat/lon maths)

REF = os.path.join(ROOT, "reference", "sites", "spire")
OUT = os.path.join(ROOT, "docs", "city")
E0, N0 = L.ORIGIN_MGA56
VIEW = (495, 6954, 511, 6968)          # km window drawn on the map: W, S, E, N
BRISBANE_KM2 = 1343                    # Brisbane City Council area, for scale


def tile_of(x, y):
    """Local Spire-frame metres -> (E_km, N_km) of the 1 km tile."""
    return int((x + E0) // 1000), int((y + N0) // 1000)


def ring_centre(ring):
    return sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring)


def load():
    wide = json.load(open(os.path.join(REF, "wide", "wide.json")))
    river = json.load(open(os.path.join(REF, "river", "river.json")))
    tiles = {}

    def t(key):
        return tiles.setdefault(key, {"lidar": False, "aerial": False, "buildings": 0, "measured": 0,
                                      "trees": 0, "heroes": [], "pairs": 0, "wanted": [], "order": None})

    for x0, y0, x1, y1 in wide["lidar_boxes"]:
        for e in range(round((x0 + E0) / 1000), round((x1 + E0) / 1000)):
            for n in range(round((y0 + N0) / 1000), round((y1 + N0) / 1000)):
                t((e, n))["lidar"] = True
    x0, y0, x1, y1 = river["box_local"]                       # the wide aerial + traced river
    for e in range(int((x0 + E0) // 1000), int((x1 + E0) // 1000) + 1):
        for n in range(int((y0 + N0) // 1000), int((y1 + N0) // 1000) + 1):
            t((e, n))["aerial"] = True
    for path in ("wide/buildings_wide.json", "lidar/buildings_clean.json", "ext/buildings_ext.json"):
        for b in json.load(open(os.path.join(REF, path)))["buildings"]:
            k = t(tile_of(*ring_centre(b["tiers"][0]["ring"])))
            k["buildings"] += 1
            if b.get("height_src", "lidar 2019").startswith("lidar"):
                k["measured"] += 1
    for path in ("wide/tree_points_wide.csv", "lidar/tree_points.csv", "ext/tree_points_ext.csv"):
        rows = csv.reader(open(os.path.join(REF, path)))
        next(rows)
        for r in rows:
            t(tile_of(float(r[0]), float(r[1])))["trees"] += 1
    marks = json.load(open(os.path.join(HERE, "landmarks.json")))["landmarks"]
    for m in marks:
        m["x"], m["y"] = L.to_local(m["lat"], m["lon"])
        m["tile"] = tile_of(m["x"], m["y"])
        k = t(m["tile"])
        m["inside"] = k["lidar"]
        if m["status"] == "hero":
            k["heroes"].append(m["name"])
        else:
            k["wanted"].append(m["name"])
    pairs_dir = os.path.join(HERE, "showcase")
    n_pairs = 0
    if os.path.isdir(pairs_dir):
        for f in sorted(os.listdir(pairs_dir)):
            if not (f.startswith("pairs") and f.endswith(".json")):
                continue
            d = json.load(open(os.path.join(pairs_dir, f)))
            if not isinstance(d, list):
                continue
            for p in d:
                if "target" in p:
                    t(tile_of(p["target"][0], p["target"][1]))["pairs"] += 1
                    n_pairs += 1
    plan = json.load(open(os.path.join(HERE, "tiles_plan.json")))
    for o in plan["orders"]:
        for bx in o["boxes"]:
            for e in range(bx[0], bx[2]):
                for n in range(bx[1], bx[3]):
                    k = t((e, n))
                    if not k["lidar"]:
                        k["order"] = o["id"]
    for k in tiles.values():
        k["grade"] = (3 if k["heroes"] else 2) if k["lidar"] else (1 if k["aerial"] else 0)
    return tiles, marks, plan, n_pairs, wide


def summary(tiles, marks, plan, n_pairs, wide):
    lid = [k for k in tiles.values() if k["lidar"]]
    fam = wide.get("families", {})
    return {
        "tiles_measured": len(lid),
        "km2_measured": len(lid),
        "share_of_brisbane_pct": round(100.0 * len(lid) / BRISBANE_KM2, 1),
        "tiles_with_heroes": sum(1 for k in lid if k["heroes"]),
        "tiles_map_only": sum(1 for k in tiles.values() if k["grade"] == 1),
        "buildings": sum(k["buildings"] for k in tiles.values()),
        "buildings_measured": sum(k["measured"] for k in tiles.values()),
        "trees": sum(k["trees"] for k in tiles.values()),
        "photo_pairs": n_pairs,
        "wide_buildings_one_recipe_pct": round(100.0 * max(fam.values()) / max(1, sum(fam.values()))) if fam else None,
        "landmarks_hand_built": sum(1 for m in marks if m["status"] == "hero"),
        "landmarks_waiting_inside": [m["name"] for m in marks if m["status"] != "hero" and m["inside"]],
        "landmarks_outside": [m["name"] for m in marks if not m["inside"]],
        "tiles_to_order": {o["id"]: sum(1 for k in tiles.values() if k["order"] == o["id"]) for o in plan["orders"]},
    }


def svg(tiles, marks, cell=44):
    w0, s0, e1, n1 = VIEW
    W, H = (e1 - w0) * cell, (n1 - s0) * cell
    pad_l, pad_t = 46, 14
    out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" role="img" '
           'aria-label="Coverage map of the Brisbane model in 1 km tiles" font-family="system-ui, sans-serif">'
           % (W + pad_l + 12, H + pad_t + 150),
           '<style>.bg{fill:#f5f7f8}.g0{fill:#e6eaec}.g1{fill:#cfd6da}.g2{fill:#8fb2c9}.g3{fill:#2f6f9a}'
           '.ord1{fill:none;stroke:#c2541b;stroke-width:2.5;stroke-dasharray:6 4}'
           '.ord2{fill:none;stroke:#7a4fb0;stroke-width:2.5;stroke-dasharray:2 4}'
           '.grid{stroke:#fff;stroke-width:1}.t{fill:#1d2327;font-size:11px}.s{fill:#4a5257;font-size:10px}'
           '.n{fill:#fff;font-size:10px;font-weight:600}.n2{fill:#1d2327;font-size:10px;font-weight:600}'
           '.dot{fill:#1d2327;stroke:#fff;stroke-width:1.5}.dotw{fill:#fff;stroke:#1d2327;stroke-width:1.5}'
           '.dn{fill:#fff;font-size:9px;font-weight:700}.dnw{fill:#1d2327;font-size:9px;font-weight:700}</style>',
           '<rect class="bg" width="100%" height="100%"/>']

    def xy(e, n):                       # top-left pixel of tile (e, n)
        return pad_l + (e - w0) * cell, pad_t + (n1 - 1 - n) * cell

    for e in range(w0, e1):
        for n in range(s0, n1):
            k = tiles.get((e, n), {"grade": 0, "buildings": 0, "order": None})
            x, y = xy(e, n)
            out.append('<rect class="g%d grid" x="%d" y="%d" width="%d" height="%d"/>' % (k["grade"], x, y, cell, cell))
            if k["grade"] >= 2:
                b = k["buildings"]
                out.append('<text class="%s" x="%d" y="%d" text-anchor="end">%s</text>'
                           % ("n" if k["grade"] == 3 else "n2", x + cell - 4, y + cell - 5,
                              ("%.1fk" % (b / 1000.0)) if b >= 1000 else str(b)))
    for e in range(w0, e1):
        for n in range(s0, n1):
            k = tiles.get((e, n))
            if k and k["order"]:
                x, y = xy(e, n)
                out.append('<rect class="%s" x="%d" y="%d" width="%d" height="%d"/>'
                           % ("ord1" if k["order"].startswith("1") else "ord2", x + 3, y + 3, cell - 6, cell - 6))
    for e in range(w0, e1 + 1, 2):
        out.append('<text class="s" x="%d" y="%d" text-anchor="middle">E%d</text>' % (pad_l + (e - w0) * cell, pad_t + H + 13, e))
    for n in range(s0, n1 + 1, 2):
        out.append('<text class="s" x="%d" y="%d" text-anchor="end">N%d</text>' % (pad_l - 4, pad_t + (n1 - n) * cell + 4, n))
    num = 0
    legend = []
    for m in marks:
        e, n = (m["x"] + E0) / 1000.0, (m["y"] + N0) / 1000.0
        if not (w0 <= e < e1 and s0 <= n < n1):
            continue
        num += 1
        px, py = pad_l + (e - w0) * cell, pad_t + (n1 - n) * cell
        out.append('<circle class="%s" cx="%.1f" cy="%.1f" r="7.5"/>' % ("dot" if m["status"] == "hero" else "dotw", px, py))
        out.append('<text class="%s" x="%.1f" y="%.1f" text-anchor="middle">%d</text>'
                   % ("dn" if m["status"] == "hero" else "dnw", px, py + 3.2, num))
        legend.append((num, m))
    ly = pad_t + H + 34
    cols = 3
    per = -(-len(legend) // cols)
    colw = (W + pad_l) / cols
    for i, (nn, m) in enumerate(legend):
        cx, cy = 8 + (i // per) * colw, ly + (i % per) * 13.5
        out.append('<text class="t" x="%.0f" y="%.1f"><tspan font-weight="700">%d</tspan> %s%s</text>'
                   % (cx, cy, nn, m["name"].replace("&", "and"), "" if m["status"] == "hero" else " (not built yet)"))
    out.append("</svg>")
    return "\n".join(out)


def markdown(s, tiles):
    rows = sorted((k for k in tiles.items() if k[1]["lidar"]), key=lambda kv: (-kv[0][1], kv[0][0]))
    md = ["# Brisbane model: coverage", "",
          "Made by `python3 tools/city/coverage.py`. Don't edit by hand. Rules and the detail ladder are in",
          "[METHOD.md](METHOD.md).", "",
          "![Coverage map](coverage.svg)", "",
          "Dark blue: measured tile with hand-built landmarks. Light blue: measured tile (2019 LiDAR). Grey: map and",
          "aerial photo only. Dashed orange and dotted purple: the next two LiDAR orders. Numbers in the tiles are",
          "building counts. Black dots are landmarks built by hand, white dots are landmarks still waiting.", "",
          "| Measure | Now |", "| --- | --- |",
          "| Measured tiles (1 km each) | %d |" % s["tiles_measured"],
          "| Share of Brisbane City (%d km2) | %s %% |" % (BRISBANE_KM2, s["share_of_brisbane_pct"]),
          "| Buildings | %d (%d with a measured height) |" % (s["buildings"], s["buildings_measured"]),
          "| Trees | %d |" % s["trees"],
          "| Tiles with a hand-built landmark | %d |" % s["tiles_with_heroes"],
          "| Hand-built landmarks | %d |" % s["landmarks_hand_built"],
          "| Photo pairs (render matched to a photo) | %d |" % s["photo_pairs"],
          "| City-wide buildings sharing one facade recipe | %s %% |" % s["wide_buildings_one_recipe_pct"],
          "| Landmarks inside the model but still plain blocks | %s |" % ", ".join(s["landmarks_waiting_inside"]),
          "| Landmarks outside the measured model | %s |" % ", ".join(s["landmarks_outside"]),
          "| Tiles in the next LiDAR orders | %s |" % ", ".join("%s: %d" % kv for kv in s["tiles_to_order"].items()),
          "", "## Measured tiles", "",
          "| Tile | Grade | Buildings | Trees | Photo pairs | Hand-built | Waiting |", "| --- | --- | --- | --- | --- | --- | --- |"]
    for (e, n), k in rows:
        md.append("| %d_%d | %d | %d | %d | %d | %s | %s |" % (e, n, k["grade"], k["buildings"], k["trees"], k["pairs"],
                                                           ", ".join(k["heroes"]), ", ".join(k["wanted"])))
    return "\n".join(md) + "\n"


def main():
    tiles, marks, plan, n_pairs, wide = load()
    s = summary(tiles, marks, plan, n_pairs, wide)
    files = {
        "coverage.json": json.dumps({"summary": s, "tiles": {"%d_%d" % k: v for k, v in sorted(tiles.items()) if v["grade"] or v["order"]}}, indent=1) + "\n",
        "coverage.svg": svg(tiles, marks) + "\n",
        "coverage.md": markdown(s, tiles),
    }
    if "--check" in sys.argv:
        stale = [f for f, body in files.items()
                 if not os.path.exists(os.path.join(OUT, f)) or open(os.path.join(OUT, f)).read() != body]
        if stale:
            print("coverage is out of date (%s): run python3 tools/city/coverage.py" % ", ".join(stale))
            return 1
        print("coverage is up to date")
        return 0
    os.makedirs(OUT, exist_ok=True)
    for f, body in files.items():
        open(os.path.join(OUT, f), "w").write(body)
    print(json.dumps(s, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
