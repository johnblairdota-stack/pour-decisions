"""Construction logistics markers: tower crane, hoist, truck gate, site sheds (positions in layout.py)."""
import math

import layout as L
import common as C


def build():
    col = C.collection("logistics")
    top = L.spire_levels()[-1]["top_ahd"]
    objs = []
    # crane
    cr = L.CRANE
    cx, cy = cr["mast_xy"]
    gz = L.ground_z(cx, cy)
    mast_top = top + cr["height_over_roof_m"]
    b = C.MeshBuf()
    b.box(cx, cy, gz, cr["mast_size_m"], cr["mast_size_m"], mast_top - gz)
    h = math.radians(cr["jib_heading_deg"])
    jl, cl = cr["jib_length_m"], cr["counter_jib_m"]
    b.box(cx + math.cos(h) * jl / 2, cy + math.sin(h) * jl / 2, mast_top, jl, 1.4, 1.6, h)
    b.box(cx - math.cos(h) * cl / 2, cy - math.sin(h) * cl / 2, mast_top, cl, 2.2, 1.2, h)
    b.box(cx - math.cos(h) * (cl - 2), cy - math.sin(h) * (cl - 2), mast_top - 2.5, 3.0, 2.4, 2.5, h)  # counterweight
    b.box(cx, cy, mast_top + 1.6, 1.2, 1.2, 9.0)   # A-frame / tower head
    objs.append(b.object("crane", col, "crane").name)
    # hoist
    hx, hy = L.HOIST["mast_xy"]
    hz = L.ground_z(hx, hy)
    b = C.MeshBuf()
    b.box(hx, hy, hz, 0.8, 0.8, top + 6 - hz)
    w, d = L.HOIST["car_size_m"]
    b.box(hx - 1.2, hy - 1.0, hz + 40.0, w, d, 2.6)
    objs.append(b.object("hoist", col, "hoist").name)
    # truck gate: two posts + a header, so the gap reads from above and from the street
    g = L.TRUCK_GATE
    gx, gy = g["centre_xy"]
    gz = L.ground_z(gx, gy)
    ex, ey = g["along_xy"]
    b = C.MeshBuf()
    for s in (-1, 1):
        b.box(gx + ex * s * g["width_m"] / 2, gy + ey * s * g["width_m"] / 2, gz, 0.6, 0.6, 5.0)
    b.box(gx, gy, gz + 4.6, g["width_m"] + 0.6, 0.6, 0.6, math.atan2(ey, ex))
    b.box(gx, gy, gz, g["width_m"], 3.0, 0.3, math.atan2(ey, ex))   # red pad in the opening
    objs.append(b.object("truck_gate", col, "gate").name)
    # sheds
    sx, sy = L.SITE_SHEDS["xy"]
    b = C.MeshBuf()
    ax, ay = L.SITE_SHEDS["along_xy"]
    hd = math.atan2(ay, ax)
    w, ln = L.SITE_SHEDS["size_m"]
    n = L.SITE_SHEDS["count"]
    for i in range(n):
        k = (i - (n - 1) / 2) * (w + 0.6)
        b.box(sx + ax * k, sy + ay * k, L.ground_z(sx, sy), w, ln, 2.8, hd)
    objs.append(b.object("site_sheds", col, "sheds").name)
    return {"module": "logistics", "objects": objs, "roof_ahd": round(top, 1),
            "crane": {"mast_xy": cr["mast_xy"], "top_ahd": round(mast_top, 1), "confidence": cr["confidence"]},
            "hoist": {"mast_xy": L.HOIST["mast_xy"], "confidence": L.HOIST["confidence"]},
            "truck_gate": {"centre_xy": g["centre_xy"], "street": g["street"], "confidence": g["confidence"]},
            "note": "Markers only (not models). See layout.py CRANE/HOIST/TRUCK_GATE for the evidence."}
