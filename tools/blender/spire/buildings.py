"""Building footprints from OSM, extruded to their tagged heights. Spire gets its own object."""
from collections import Counter

import layout as L
import common as C


def footprints():
    """Yield (id, tags, ring) for every OSM building / building part in the model square."""
    o = L.osm()
    for wid, w in o["ways"].items():
        t = w.get("tags", {})
        if "building" in t or "building:part" in t:
            yield wid, t, C.clean_ring(o["line"](w))
    for r in o["rels"]:
        t = r.get("tags", {})
        if t.get("type") == "multipolygon" and ("building" in t or "building:part" in t):
            for m in r["members"]:
                if m.get("role") == "outer" and m["ref"] in o["ways"]:
                    yield r["id"], t, C.clean_ring(o["line"](o["ways"][m["ref"]]))


def build():
    col = C.collection("buildings")
    parts, whole = [], []
    for oid, t, ring in footprints():
        if len(ring) < 3:
            continue
        cx = sum(p[0] for p in ring) / len(ring)
        cy = sum(p[1] for p in ring) / len(ring)
        if not C.in_model(cx, cy):
            continue
        (parts if "building:part" in t and "building" not in t else whole).append((oid, t, ring, cx, cy))
    tagged, guessed, spire = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    src_count = Counter()
    skipped = 0
    for is_part, (oid, t, ring, cx, cy) in [(False, w) for w in whole] + [(True, p) for p in parts]:
        if not is_part and any(C.point_in_ring(px, py, ring) for _, _, _, px, py in parts):
            skipped += 1          # drawn by its parts instead
            continue
        h, src = L.building_height(t)
        minh = L.tag_float(t, "min_height") or 0.0
        z0 = min(L.ground_z(x, y) for x, y in ring)
        buf = spire if oid == L.SPIRE["osm_way"] else (guessed if src.startswith("default") else tagged)
        buf.prism(ring, z0 - (0.5 if minh == 0 else -minh), z0 + h)
        src_count[src.split(" x ")[0]] += 1
    objs = []
    for buf, name, key in ((tagged, "buildings_tagged", "building"), (guessed, "buildings_height_guess", "building_guess"),
                           (spire, "SPIRE", "spire")):
        ob = buf.object(name, col, key)
        if ob:
            objs.append(ob.name)
    sp_ring = next(r for i, t, r in footprints() if i == L.SPIRE["osm_way"])
    return {"module": "buildings", "objects": objs, "footprints": len(whole) + len(parts) - skipped,
            "parents_replaced_by_parts": skipped, "height_source": dict(src_count),
            "spire": {"ground_ahd": round(min(L.ground_z(x, y) for x, y in sp_ring), 2),
                      "height_m": L.SPIRE["height_m"], "footprint_pts": len(sp_ring),
                      "footprint_area_m2": round(abs(C.signed_area(sp_ring)), 1)},
            "note": "Untagged buildings are %.0f m (blue-grey); levels-only ones use %.1f m a level."
                    % (L.DEFAULT_HEIGHT, L.LEVEL_HEIGHT)}
