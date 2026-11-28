"""Ground footpaths, walkways, bikeways, steps, crossings and paved squares from OSM over the river box (no bpy).

    python3 tools/sites/paths_wide.py <PourDecisions-sites>/data

Input: <data>/<every area in roads_wide.OSM_AREAS>/osm/osm_all.json.gz (the same extracts roads_wide.py reads). Writes
reference/sites/spire/roads/paths.json.gz:

    ways   [{id, cls, name, width, pts: [[x, y], ...] (local, every <= 4 m)}]
    areas  [{id, cls, name, ring: [[x, y], ...]}]   paved squares and malls (area=yes)

cls: sidewalk (footway=sidewalk), crossing, island (footway=traffic_island), footway (park and link paths),
cycleway, pedestrian (malls and promenades), steps. Bridges are roads.json.gz's (roads_wide.py); tunnels, arcades
and upper levels are left out. far_paths.py builds them outside the Spire LiDAR box (streets.py covers inside).
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender", "spire"))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402
from roads_wide import densify, load_osm  # noqa: E402

OUT = os.path.join(L.REF, "roads")
WIDTH = {"sidewalk": 3.2, "crossing": 3.0, "island": 2.0, "footway": 2.4, "cycleway": 3.0, "pedestrian": 6.0,
         "steps": 2.6, "path": 1.8}


def main():
    data = sys.argv[1]
    rv = json.load(open(os.path.join(L.REF, "river", "river.json")))
    bx0, by0, bx1, by1 = rv["box_local"]
    raw = load_osm(data)
    nodes = {el["id"]: (el["lat"], el["lon"]) for el in raw["elements"] if el["type"] == "node"}
    ways, areas, counts = [], [], {}
    for w in raw["elements"]:
        if w["type"] != "way":
            continue
        t = w.get("tags", {})
        hw = t.get("highway")
        if hw not in ("footway", "cycleway", "pedestrian", "path", "steps"):
            continue
        if t.get("bridge", "no") != "no" or t.get("tunnel", "no") != "no" or t.get("covered") == "yes" \
                or t.get("indoor") == "yes" or "level" in t or (L.tag_float(t, "layer") or 0) != 0:
            continue
        if not all(n in nodes for n in w["nodes"]):
            continue
        pts = [L.to_local(*nodes[n]) for n in w["nodes"]]
        if not any(bx0 < x < bx1 and by0 < y < by1 for x, y in pts):
            continue
        fw = t.get("footway", "")
        cls = hw if hw != "footway" else {"sidewalk": "sidewalk", "crossing": "crossing",
                                          "traffic_island": "island"}.get(fw, "footway")
        if hw == "cycleway" and t.get("cycleway") == "crossing":
            cls = "crossing"
        if hw == "path":
            cls = "footway"
        counts[cls] = counts.get(cls, 0) + 1
        if t.get("area") == "yes" and len(pts) > 3 and w["nodes"][0] == w["nodes"][-1]:
            areas.append({"id": w["id"], "cls": cls, "name": t.get("name", ""),
                          "ring": [[round(x, 2), round(y, 2)] for x, y in pts[:-1]]})
            continue
        wd = L.tag_float(t, "width")
        if not wd or not 0.8 < wd < 20:
            wd = WIDTH[cls]
        ways.append({"id": w["id"], "cls": cls, "name": t.get("name", ""), "width": round(wd, 1),
                     "pts": [[round(x, 2), round(y, 2)] for x, y in densify(pts)]})
    os.makedirs(OUT, exist_ok=True)
    with L.wopen(os.path.join(OUT, "paths.json.gz")) as f:
        json.dump({"note": "tools/sites/paths_wide.py: OSM ground paths over the river box", "box_local": rv["box_local"],
                   "ways": ways, "areas": areas}, f, separators=(",", ":"))
    print(counts, "ways", len(ways), "areas", len(areas), "points", sum(len(w["pts"]) for w in ways))


if __name__ == "__main__":
    main()
