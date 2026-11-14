"""Concrete plant at a stage: two Schwing KVM 26 placing booms on the deck, the Putzmeister BSA 2109 HD
line pump inside the Ann St gate, the delivery line (pump -> riser -> booms), an agitator at the kerb,
and the hoarding round the lot. Blockout shapes; positions in layout.PLANT / TRUCK_GATE."""
import math

import layout as L
import common as C
import spire


def boom(buf, x, y, deck, reach, slew_deg, ftf):
    """Pedestal through the deck + turret + 4-section boom, unfolded over its pour area."""
    buf.box(x, y, deck - ftf, 1.0, 1.0, ftf + 4.0)            # climbing pedestal through one level
    buf.box(x, y, deck + 4.0, 1.6, 1.6, 1.2)                  # turret
    a = math.radians(slew_deg)
    secs = [(0.30 * reach, 60.0), (0.27 * reach, 20.0), (0.25 * reach, -5.0), (0.18 * reach, -75.0)]   # ~18 m out
    p = (x, y, deck + 5.2)
    for ln, pitch in secs:
        pr = math.radians(pitch)
        q = (p[0] + math.cos(a) * math.cos(pr) * ln, p[1] + math.sin(a) * math.cos(pr) * ln, p[2] + math.sin(pr) * ln)
        buf.beam(p, q, 0.45)
        p = q
    buf.beam(p, (p[0], p[1], p[2] - 3.0), 0.2)               # end hose
    buf.box(x - math.cos(a) * 1.8, y - math.sin(a) * 1.8, deck + 4.0, 1.4, 1.4, 1.4)   # counterweight
    return p


def build():
    st = L.stage()
    if st is None:
        return {"module": "site_plant", "objects": [], "note": "finished building: no site plant"}
    col = C.collection("site")
    deck_lv = L.level(st["deck_level"])
    deck = deck_lv["top_ahd"]
    ftf = deck - L.level(st["deck_level"] - 1)["top_ahd"]
    objs, out = [], {}
    # booms
    bb = C.MeshBuf()
    pedestals = []
    for bm in L.PLANT["booms"]:
        x, y = L.plan_to_local(*bm["plan_px"])
        tip = boom(bb, x, y, deck, bm["reach_m"], bm["slew_deg"], ftf)
        pedestals.append((x, y))
        out[bm["id"]] = {"model": bm["model"], "pour_area": bm["pour"], "xy": [round(x, 2), round(y, 2)],
                         "tip": [round(v, 2) for v in tip], "note": bm["note"]}
    objs.append(bb.object("placing_booms_KVM26", col, "boom").name)
    # line pump inside the gate, agitator at the kerb
    g = L.TRUCK_GATE
    gx, gy = g["centre_xy"]
    (ux, uy), (nx, ny) = L.ann_st_frame()
    hd = math.atan2(uy, ux)
    L_, W_, H_ = L.PLANT["line_pump"]["size_m"]
    px, py = gx - nx * 4.0, gy - ny * 4.0
    pz = L.ground_z(px, py)
    pb = C.MeshBuf()
    pb.box(px, py, pz + 0.5, W_, L_, H_ - 0.5, hd)             # body, long axis across the boundary
    pb.box(px + nx * (L_ / 2 + 0.6), py + ny * (L_ / 2 + 0.6), pz + 0.6, 1.8, 1.2, 0.9, hd)   # hopper to the kerb
    for s in (-1, 1):
        pb.box(px + ux * s * 0.8, py + uy * s * 0.8, pz, 0.5, 0.9, 0.6, hd)                    # wheels
    objs.append(pb.object("line_pump_BSA2109HD", col, "pump").name)
    tx, ty = gx + nx * 7.0, gy + ny * 7.0
    tz = L.ground_z(tx, ty)
    tb = C.MeshBuf()
    tb.box(tx + ux * 3.0, ty + uy * 3.0, tz + 0.3, 2.4, 2.5, 2.8, hd)       # cab
    tb.box(tx - ux * 1.5, ty - uy * 1.5, tz + 1.0, 5.5, 2.4, 2.6, hd)       # drum (box stand-in)
    tb.box(tx, ty, tz, 9.0, 2.4, 1.0, hd)                                   # chassis
    objs.append(tb.object("agitator_truck", col, "truck").name)
    # delivery line: pump -> riser just inside the plate edge -> deck -> each boom pedestal
    pr = L.PLANT["pipe_m"]
    rx, ry = px - nx * 5.0, py - ny * 5.0
    lb = C.MeshBuf()
    lb.beam((px - nx * L_ / 2, py - ny * L_ / 2, pz + 0.8), (rx, ry, pz + 0.8), pr)
    lb.beam((rx, ry, pz + 0.8), (rx, ry, deck + 0.4), pr)
    for x, y in pedestals:
        lb.beam((rx, ry, deck + 0.4), (rx, y if abs(x - rx) > abs(y - ry) else ry, deck + 0.4), pr)
        lb.beam((rx, y if abs(x - rx) > abs(y - ry) else ry, deck + 0.4), (x, y, deck + 0.4), pr)
    objs.append(lb.object("delivery_line", col, "pipe").name)
    # hoarding round the lot, gap at the gate
    lot = spire.lot_outline()
    ring = spire.inset(lot, -0.3)
    hb = C.MeshBuf()
    n = len(ring)
    for i in range(n):
        a, b = ring[i], ring[(i + 1) % n]
        seg_len = math.dist(a, b)
        ex, ey = (b[0] - a[0]) / seg_len, (b[1] - a[1]) / seg_len
        tg = (gx - a[0]) * ex + (gy - a[1]) * ey
        dist = abs((gx - a[0]) * -ey + (gy - a[1]) * ex)
        pieces = [(0.0, seg_len)]
        if dist < 3.0 and -1 < tg < seg_len + 1:
            pieces = [(0.0, tg - g["width_m"] / 2), (tg + g["width_m"] / 2, seg_len)]
        for t0, t1 in pieces:
            if t1 - t0 < 0.2:
                continue
            p0 = (a[0] + ex * t0, a[1] + ey * t0)
            p1 = (a[0] + ex * t1, a[1] + ey * t1)
            mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
            z = min(L.ground_z(*p0), L.ground_z(*p1))
            hb.box(mx, my, z, t1 - t0, 0.12, st["hoarding_m"] + abs(L.ground_z(*p0) - L.ground_z(*p1)),
                   math.atan2(ey, ex))
    objs.append(hb.object("hoarding", col, "hoarding").name)
    out["line_pump"] = {"model": L.PLANT["line_pump"]["model"], "xy": [round(px, 2), round(py, 2)],
                        "note": L.PLANT["line_pump"]["note"]}
    return {"module": "site_plant", "objects": objs, "deck": deck_lv["name"], "deck_ahd": round(deck, 2),
            "plant": out, "riser_xy": [round(rx, 2), round(ry, 2)],
            "note": "Boom and pump positions are assumptions placed for a sensible layout; no photo shows them."}
