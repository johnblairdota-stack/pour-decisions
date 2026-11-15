"""Site logistics at a stage: tower crane, hoist placeholder, truck gate, site sheds.
Nothing is built for the finished tower (stage None). Positions and evidence in layout.py."""
import math

import layout as L
import common as C


def build():
    st = L.spire_stage()
    if st is None:
        return {"module": "logistics", "objects": [], "note": "finished building: no site logistics"}
    col = C.collection("logistics")
    deck = L.level(st["deck_level"])["top_ahd"]
    objs = []
    # crane: mast top a set height over the core top at this stage
    cr = L.CRANE
    cx, cy = cr["mast_xy"]
    gz = L.ground_z(cx, cy)
    mast_top = L.core_top_ahd() + st["crane_over_core_m"]
    b, jib = C.MeshBuf(), C.MeshBuf()
    b.box(cx, cy, gz, cr["mast_size_m"], cr["mast_size_m"], mast_top - gz)
    h = math.radians(cr["jib_heading_deg"])
    jl, cl = cr["jib_length_m"], cr["counter_jib_m"]
    b.box(cx, cy, mast_top, 3.0, 3.0, 3.5, h)                                        # slewing unit + cab
    b.box(cx - math.cos(h) * cl / 2, cy - math.sin(h) * cl / 2, mast_top + 1.0, cl, 2.4, 1.2, h)   # counter jib
    b.box(cx - math.cos(h) * (cl - 2), cy - math.sin(h) * (cl - 2), mast_top - 1.5, 3.0, 2.6, 2.5, h)
    if cr.get("type") == "luffing":
        lf = math.radians(cr.get("luff_deg", 65.0))
        p0 = (cx, cy, mast_top + 3.0)
        p1 = (cx + math.cos(h) * math.cos(lf) * jl, cy + math.sin(h) * math.cos(lf) * jl, mast_top + 3.0 + math.sin(lf) * jl)
        jib.beam(p0, p1, 1.3)
        b.box(cx, cy, mast_top + 3.0, 1.0, 1.0, 7.0)                                 # A-frame
    else:
        b.box(cx + math.cos(h) * jl / 2, cy + math.sin(h) * jl / 2, mast_top, jl, 1.4, 1.6, h)
    ob = b.object("crane", col, "crane")
    ob.data.materials[0] = C.material_rgb("crane_blue", (0.12, 0.40, 0.78))
    objs.append(ob.name)
    if jib.v:
        oj = jib.object("crane_luffing_jib", col, "crane")
        oj.data.materials[0] = C.material_rgb("crane_red_white", (0.85, 0.25, 0.20))
        objs.append(oj.name)
    # hoist: placeholder (John doesn't know where it was)
    hx, hy = L.HOIST["mast_xy"]
    hz = L.ground_z(hx, hy)
    b = C.MeshBuf()
    b.box(hx, hy, hz, 0.8, 0.8, deck + 6 - hz)
    w, d = L.HOIST["car_size_m"]
    b.box(hx - 1.2, hy - 1.0, hz + 0.3, w, d, 2.6)
    ob = b.object("hoist_PLACEHOLDER", col, "hoist")
    ob["position_known"] = False
    objs.append(ob.name)
    # truck gate in the hoarding line
    g = L.TRUCK_GATE
    gx, gy = g["centre_xy"]
    gz = L.ground_z(gx, gy)
    ex, ey = g["along_xy"]
    b = C.MeshBuf()
    for s in (-1, 1):
        b.box(gx + ex * s * g["width_m"] / 2, gy + ey * s * g["width_m"] / 2, gz, 0.4, 0.4, st["hoarding_m"] + 0.6)
    b.box(gx, gy, gz, g["width_m"], 3.0, 0.05, math.atan2(ey, ex))
    objs.append(b.object("truck_gate", col, "gate").name)
    # sheds: on the Ann St gantry (2016), with a gap over the truck gate
    gt = st["gantry"]
    (ax, ay), (bx, by) = L.PODIUM["ann_st_corners"]
    (ux, uy), (nx, ny) = L.ann_st_frame()
    span = math.hypot(bx - ax, by - ay)
    hd = math.atan2(uy, ux)
    gate_t = ((gx - ax) * ux + (gy - ay) * uy) / span
    gap = (g["width_m"] / 2 + 0.5) / span
    deck_b, shed_b = C.MeshBuf(), C.MeshBuf()
    sw, sl = gt["shed_m"]
    for t0, t1 in ((gt["from_t"], gate_t - gap), (gate_t + gap, gt["to_t"])):
        if t1 <= t0:
            continue
        tm = (t0 + t1) / 2
        cx_, cy_ = ax + ux * span * tm + nx * gt["out_m"], ay + uy * span * tm + ny * gt["out_m"]
        gz_ = L.ground_z(cx_, cy_)
        length = (t1 - t0) * span
        deck_b.box(cx_, cy_, gz_ + gt["clear_m"], length, gt["width_m"], 0.4, hd)
        for k in (-0.5, 0.5):        # posts at the kerb side
            px = cx_ + ux * k * (length - 0.4) + nx * gt["width_m"] / 2
            py = cy_ + uy * k * (length - 0.4) + ny * gt["width_m"] / 2
            deck_b.box(px, py, gz_, 0.3, 0.3, gt["clear_m"])
        m = int(length // (sl + 0.4))
        for i in range(m):
            k = (i - (m - 1) / 2) * (sl + 0.4)
            shed_b.box(cx_ + ux * k, cy_ + uy * k, gz_ + gt["clear_m"] + 0.4, sl, sw, 2.7, hd)
    objs.append(deck_b.object("ann_st_gantry", col, "hoarding").name)
    objs.append(shed_b.object("site_sheds_on_gantry", col, "sheds").name)
    return {"module": "logistics", "objects": objs, "deck_ahd": round(deck, 2),
            "crane": {"mast_xy": cr["mast_xy"], "top_ahd": round(mast_top, 1), "confidence": cr["confidence"]},
            "hoist": {"mast_xy": L.HOIST["mast_xy"], "known": False},
            "truck_gate": {"centre_xy": g["centre_xy"], "street": g["street"], "confidence": g["confidence"]},
            "sheds": "on the Ann St footpath gantry (2016 aerial); the 2015 ground sheds are under the podium by now",
            "note": "Markers only. Evidence in layout.py."}
