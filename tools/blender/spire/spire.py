"""Spire itself: podium on the whole lot, tower plate from the typical floor plan, lift core, and every
slab as its own object split into its pours (SLAB_L07_A / SLAB_L07_B). Numbers from layout.py."""
import layout as L
import common as C


def ring_ccw(ring):
    return ring if C.signed_area(ring) > 0 else ring[::-1]


def inset(ring, d):
    """Move a closed CCW ring inwards by d (vertex-normal offset; fine for this smooth plate)."""
    ring = ring_ccw(ring)
    closed = ring + ring[:2]
    off = C.offset_line([ring[-1]] + closed, d)[1:len(ring) + 1]
    return off


def clip(ring, a, b, keep_left=True):
    """Sutherland-Hodgman: keep the part of `ring` left (or right) of the line a -> b."""
    def side(p):
        s = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
        return s if keep_left else -s
    out = []
    n = len(ring)
    for i in range(n):
        p, q = ring[i], ring[(i + 1) % n]
        sp, sq = side(p), side(q)
        if sp >= 0:
            out.append(p)
        if (sp >= 0) != (sq >= 0):
            t = sp / (sp - sq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def lot_outline():
    o = L.osm()
    return C.clean_ring(o["line"](o["ways"][L.SPIRE["osm_way"]]))


def build():
    col = C.collection("spire")
    levels = L.spire_levels()
    lot = ring_ccw(lot_outline())
    plate = ring_ccw(L.tower_outline())
    a, b = L.pour_split_line()
    ground_min = min(L.ground_z(x, y) for x, y in lot)
    objs, slabs = [], []

    def outline_for(lv):
        return lot if lv["kind"] in ("ground", "podium") else plate

    # slabs, one object per pour
    for lv in levels:
        ring = outline_for(lv)
        z1 = lv["top_ahd"]
        z0 = z1 - lv["slab_m"] if lv["kind"] != "ground" else ground_min - 0.5
        key = "transfer" if lv["kind"] == "transfer" else "slab"
        parts = [("A", clip(ring, a, b, True)), ("B", clip(ring, a, b, False))] if lv["pours"] == 2 else [("", ring)]
        for tag, part in parts:
            if len(part) < 3:
                continue
            buf = C.MeshBuf()
            buf.prism(part, z0, z1)
            name = "SLAB_%s%s" % (lv["name"], "_" + tag if tag else "")
            ob = buf.object(name, col, key if tag != "B" else key + "_b")
            ob["level"] = lv["name"]
            ob["pour"] = tag or "1"
            ob["top_ahd"] = z1
            ob["slab_m"] = lv["slab_m"]
            slabs.append(ob.name)
    # storeys (glass line 0.6 m in from the slab edge), one object for the whole tower
    st = C.MeshBuf()
    for lo, hi in zip(levels[:-1], levels[1:]):
        ring = outline_for(lo)
        ring = inset(ring, 0.6) if ring is plate else ring
        st.prism(ring, lo["top_ahd"], hi["top_ahd"] - hi["slab_m"])
    objs.append(st.object("SPIRE_storeys", col, "spire").name)
    # parapet ring on the roof and the lift core
    top = levels[-1]["top_ahd"]
    pb = C.MeshBuf()
    pb.prism(inset(plate, 0.3), top, top + L.LEVELS["parapet_m"])
    objs.append(pb.object("SPIRE_parapet", col, "spire").name)
    cb = C.MeshBuf()
    cb.prism(L.core_outline(), ground_min - 0.5, top + 3.5)
    objs.append(cb.object("SPIRE_core", col, "core").name)
    typ = levels[-1]["typical_ftf_solved_m"]
    return {"module": "spire", "objects": objs, "slab_objects": len(slabs), "levels": len(levels),
            "base_ahd": levels[0]["top_ahd"], "roof_ahd": top, "typical_ftf_m": typ,
            "transfer": next(lv for lv in levels if lv["kind"] == "transfer"),
            "plate_area_m2": round(C.signed_area(plate), 1), "lot_area_m2": round(C.signed_area(lot), 1),
            "pour_split": [[round(v, 2) for v in a], [round(v, 2) for v in b]],
            "note": "Plate from the typical floor plan, placed by aerial overlay. Floor heights are solved from "
                    "the OSM height (typical %.2f m floor to floor is low: check against drawings)." % typ}
