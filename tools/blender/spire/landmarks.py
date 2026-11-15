"""Story Bridge, clean and parametric (step 5): the steel cantilever truss with anchor arms, cantilever
arms and the suspended span, top and bottom chords, verticals, diagonals, top bracing, main and anchor
piers, approach spans on piers, deck, footways, railings and lights. The 2019 LiDAR points were used
only to measure it (layout.STORY_BRIDGE). St John's Cathedral is built by buildings.py from its clean
footprint and LiDAR-measured tiers/spires."""
import math

import layout as L
import common as C


def interp(prof, t):
    for (t0, z0), (t1, z1) in zip(prof[:-1], prof[1:]):
        if t0 <= t <= t1:
            return z0 + (z1 - z0) * (t - t0) / (t1 - t0)
    return prof[0][1] if t < prof[0][0] else prof[-1][1]


def build():
    B = L.STORY_BRIDGE
    col = C.collection("landmarks")
    (cx, cy), (ax, ay) = B["centre_xy"], B["axis"]
    nx, ny = -ay, ax
    def P(t, n, z):
        return (cx + ax * t + nx * n, cy + ay * t + ny * n, z)
    deck = lambda t: interp(B["deck_profile"], t)
    topc = lambda t: interp(B["top_chord_profile"], t)
    nc, hw = B["truss_centre_n"], B["truss_half_m"]
    t0, t1 = B["truss_t"]
    steel, conc, dk, misc = C.MeshBuf(), C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    # ---------------------------------------------------------------- truss
    k = int(round((t1 - t0) / B["panel_m"]))
    ts = [t0 + (t1 - t0) * i / k for i in range(k + 1)]
    for side in (-1, 1):
        n = nc + side * hw
        bot = [P(t, n, deck(t) - 0.6) for t in ts]
        top = [P(t, n, max(topc(t), deck(t) + 6.0)) for t in ts]
        for i in range(k):
            steel.beam(bot[i], bot[i + 1], 1.2)                          # bottom chord
            steel.beam(top[i], top[i + 1], 1.1)                          # top chord
            steel.beam(bot[i], top[i + 1] if (i % 2 == 0) else top[i], 0.6)   # diagonals (Warren)
            steel.beam(top[i] if (i % 2 == 0) else bot[i], top[i + 1] if (i % 2 == 1) else bot[i + 1], 0.6)
        for i in range(k + 1):
            steel.beam(bot[i], top[i], 0.8)                              # verticals
    for i, t in enumerate(ts):                                           # top lateral bracing + portals
        zt = max(topc(t), deck(t) + 6.0)
        if zt - deck(t) > 8.5:
            steel.beam(P(t, nc - hw, zt), P(t, nc + hw, zt), 0.5)
            if i < k:
                tn = ts[i + 1]
                ztn = max(topc(tn), deck(tn) + 6.0)
                if ztn - deck(tn) > 8.5:
                    steel.beam(P(t, nc - hw, zt), P(tn, nc + hw, ztn), 0.35)
                    steel.beam(P(t, nc + hw, zt), P(tn, nc - hw, ztn), 0.35)
        steel.beam(P(t, nc - hw, deck(t) - 0.9), P(t, nc + hw, deck(t) - 0.9), 0.7)   # floor beams
    # ---------------------------------------------------------------- piers
    def pier(t, w, d, cap=True):
        for side in (-1, 1):
            x, y, _ = P(t, nc + side * hw, 0)
            g = min(L.ground_z(x, y), 1.0) - 1.0
            conc.box(x, y, g, w, d, deck(t) - 1.2 - g, math.atan2(ay, ax))
        if cap:
            x, y, _ = P(t, nc, 0)
            conc.box(x, y, deck(t) - 3.2, 2.5, 2 * hw + 4, 2.0, math.atan2(ay, ax))
    for t in B["main_piers_t"]:
        pier(t, 8.0, 6.0)
    for t in (t0, t1):
        pier(t, 4.0, 4.0)
    ta, tb = B["deck_t"]
    t = ta
    while t <= tb:
        if not (t0 - 5 < t < t1 + 5):
            x, y, _ = P(t, nc, 0)
            if deck(t) - L.ground_z(x, y) > 4.0:
                pier(t, 2.0, 2.5)
        t += B["approach_span_m"]
    # ---------------------------------------------------------------- deck, footways, railings, lights
    step = 6.0
    t = ta
    while t < tb:
        tn = min(t + step, tb)
        for n0, n1, z_off, key in ((nc - hw + 0.8, nc + hw - 0.8, 0.0, "deck"),
                                   (nc - hw - 3.2, nc - hw - 0.6, 0.25, "pier"),
                                   (nc + hw + 0.6, nc + hw + 3.2, 0.25, "pier")):
            buf = dk if key == "deck" else conc
            a, b = (n0, n1)
            verts = [P(t, a, deck(t) + z_off), P(tn, a, deck(tn) + z_off), P(tn, b, deck(tn) + z_off), P(t, b, deck(t) + z_off),
                     P(t, a, deck(t) - 0.6), P(tn, a, deck(tn) - 0.6), P(tn, b, deck(tn) - 0.6), P(t, b, deck(t) - 0.6)]
            buf.add(verts, [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]])
        for n in (nc - hw - 3.2, nc + hw + 3.2):
            misc.beam(P(t, n, deck(t) + 1.35), P(tn, n, deck(tn) + 1.35), 0.12)
        t = tn
    t = ta + 15
    while t < tb:
        for n in (nc - hw - 3.0, nc + hw + 3.0):
            misc.beam(P(t, n, deck(t) + 0.25), P(t, n, deck(t) + 8.0), 0.2)
        t += B["light_spacing_m"]
    objs = [steel.object("story_bridge_truss", col, "steel").name, conc.object("story_bridge_piers_footways", col, "pier").name,
            dk.object("story_bridge_deck", col, "deck").name, misc.object("story_bridge_rails_lights", col, "steel").name]
    return {"module": "landmarks", "objects": objs, "panels": k, "main_span_m": abs(B["main_piers_t"][1] - B["main_piers_t"][0]),
            "measured": B["measured_from"], "note": "Member sizes and panel layout are simplified; heights, piers, "
            "alignment and the deck profile are measured from the 2019 LiDAR points."}
