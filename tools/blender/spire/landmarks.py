"""Story Bridge, clean and parametric. Step 5 truss + HSW round 1 (hero quality):
- grey-green painted steel (layout.STORY_BRIDGE_PIERS["steel"]), K-panels where the truss is deep (towers,
  anchor arms), Warren panels in the shallow suspended span; heavier chords; lattice portal bracing between
  the trusses at the main-pier towers; top lateral bracing.
- deck underside: deep floor beams at every panel point, six stringers, lateral X bracing (seen from HSW).
- main piers in cream render, one shaft under each truss, each pierced E-W by a round-headed arch, plinth
  and cornice (photos refs/hsw overview_aerial/gg_4202cd18, hotel/gg_4681e729); anchor and approach piers.
The 2019 LiDAR points were used only to measure it (layout.STORY_BRIDGE). St John's Cathedral is built by
buildings.py from its clean footprint and LiDAR-measured tiers/spires."""
import math

import layout as L
import common as C


def interp(prof, t):
    for (t0, z0), (t1, z1) in zip(prof[:-1], prof[1:]):
        if t0 <= t <= t1:
            return z0 + (z1 - z0) * (t - t0) / (t1 - t0)
    return prof[0][1] if t < prof[0][0] else prof[-1][1]


def arch_profile(L_, top, g, aw, spring, nseg=12):
    """Pier side profile in (u along axis, z): rectangle with a round-headed arch notch at the bottom."""
    a = aw / 2
    pts = [(-L_ / 2, g), (-a, g), (-a, g + spring)]
    for k in range(1, nseg):
        th = math.pi - math.pi * k / nseg
        pts.append((a * math.cos(th), g + spring + a * math.sin(th)))
    pts += [(a, g + spring), (a, g), (L_ / 2, g), (L_ / 2, top), (-L_ / 2, top)]
    return pts


def extrude_profile(buf, prof, P, t, n0, n1):
    """Profile (u, z) placed at axis position t + u, extruded across from n0 to n1."""
    k = len(prof)
    verts = [P(t + u, n0, z) for u, z in prof] + [P(t + u, n1, z) for u, z in prof]
    faces = [list(range(k - 1, -1, -1)), list(range(k, 2 * k))]
    faces += [[i, (i + 1) % k, k + (i + 1) % k, k + i] for i in range(k)]
    buf.add(verts, faces)


def build():
    B = L.STORY_BRIDGE
    BP = L.STORY_BRIDGE_PIERS
    col = C.collection("landmarks")
    (cx, cy), (ax, ay) = B["centre_xy"], B["axis"]
    nx, ny = -ay, ax
    def P(t, n, z):
        return (cx + ax * t + nx * n, cy + ay * t + ny * n, z)
    deck = lambda t: interp(B["deck_profile"], t)
    topc = lambda t: interp(B["top_chord_profile"], t)
    nc, hw = B["truss_centre_n"], B["truss_half_m"]
    t0, t1 = B["truss_t"]
    tn_, ts_ = B["main_piers_t"]
    steel, under, conc, dk, misc = C.MeshBuf(), C.MeshBuf(), C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    ang0 = math.atan2(ay, ax)
    shade_ = C.MeshBuf()
    ztop = lambda t: max(topc(t), deck(t) + 6.0)
    # ---------------------------------------------------------------- truss
    k = int(round((t1 - t0) / B["panel_m"]))
    ts = [t0 + (t1 - t0) * i / k for i in range(k + 1)]
    kpanels = 0
    for side in (-1, 1):
        n = nc + side * hw
        bot = [P(t, n, deck(t) - 0.6) for t in ts]
        top = [P(t, n, ztop(t)) for t in ts]
        mid = [P(t, n, (deck(t) - 0.6 + ztop(t)) / 2) for t in ts]
        for i in range(k):
            steel.beam(bot[i], bot[i + 1], 2.1, 2.6)                     # bottom chord (HSW r4: 1.5x, deeper girder)
            steel.beam(top[i], top[i + 1], 2.0, 2.3)                     # top chord
            depth = min(ztop(ts[i]), ztop(ts[i + 1])) - deck(ts[i])
            if depth > 13.0:                                              # K panel: diagonals meet mid-vertical
                tower = tn_ if abs(ts[i] - tn_) < abs(ts[i] - ts_) else ts_
                near, far = (i, i + 1) if abs(ts[i] - tower) < abs(ts[i + 1] - tower) else (i + 1, i)
                steel.beam(mid[far], top[near], 1.1)
                steel.beam(mid[far], bot[near], 1.1)
                kpanels += 1
            else:                                                         # Warren
                steel.beam(bot[i], top[i + 1] if (i % 2 == 0) else top[i], 1.05)
                steel.beam(top[i] if (i % 2 == 0) else bot[i], top[i + 1] if (i % 2 == 1) else bot[i + 1], 1.05)
        for i in range(k):                                                # HSW r3: lattice lacing in every panel (p13)
            if ztop(ts[i]) - deck(ts[i]) > 9.0:
                steel.beam(bot[i], mid[i + 1], 0.2)
                steel.beam(mid[i], bot[i + 1], 0.2)
                steel.beam(mid[i], top[i + 1], 0.2)
                steel.beam(top[i], mid[i + 1], 0.2)
        for i in range(k + 1):
            heavy = min(abs(ts[i] - tn_), abs(ts[i] - ts_)) < 1.0
            steel.beam(bot[i], top[i], 2.4 if heavy else 1.35)            # verticals (tower posts heavier)
            steel.box(bot[i][0], bot[i][1], bot[i][2] - 1.6, 3.2, 3.2, 3.2, ang0)   # r4: gusset plates at the joints
            steel.box(top[i][0], top[i][1], top[i][2] - 1.6, 3.0, 3.0, 3.2, ang0)
            if ztop(ts[i]) - deck(ts[i]) > 13.0:
                steel.beam(mid[i], mid[min(i + 1, k)], 0.35)              # sub-strut at mid height
    for i, t in enumerate(ts):                                            # top lateral bracing + portals
        zt = ztop(t)
        if zt - deck(t) > 8.5:
            steel.beam(P(t, nc - hw, zt), P(t, nc + hw, zt), 0.7)
            if i < k:
                tn = ts[i + 1]
                if ztop(tn) - deck(tn) > 8.5:
                    steel.beam(P(t, nc - hw, zt), P(tn, nc + hw, ztop(tn)), 0.4)
                    steel.beam(P(t, nc + hw, zt), P(tn, nc - hw, ztop(tn)), 0.4)
    for tt in (tn_, ts_):                                                 # lattice portal bracing at the towers
        z = deck(tt) + 7.5
        zt = ztop(tt) - 1.0
        step = (zt - z) / 6
        for j in range(6):
            za, zb = z + j * step, z + (j + 1) * step
            steel.beam(P(tt, nc - hw, za), P(tt, nc + hw, zb), 0.5)
            steel.beam(P(tt, nc + hw, za), P(tt, nc - hw, zb), 0.5)
            steel.beam(P(tt, nc - hw, zb), P(tt, nc + hw, zb), 0.45)
    # ---------------------------------------------------------------- deck underside steel
    ta, tb = B["deck_t"]
    for i, t in enumerate(ts):                                            # r5: cross-girders every half panel,
        under.beam(P(t, nc - hw, deck(t) - 1.6), P(t, nc + hw, deck(t) - 1.6), 0.45, 1.8)   # thinner and even
        if i < k:
            tm = (t + ts[i + 1]) / 2
            under.beam(P(tm, nc - hw, deck(tm) - 1.4), P(tm, nc + hw, deck(tm) - 1.4), 0.35, 1.3)
    for i in range(k):                                                    # HSW r2: secondary hangers + sway braces
        tm = (ts[i] + ts[i + 1]) / 2
        for side in (-1, 1):
            n = nc + side * hw
            if ztop(tm) - deck(tm) > 9.0:
                steel.beam(P(tm, n, deck(tm) - 0.6), P(tm, n, ztop(tm)), 0.4)
        under.beam(P(ts[i], nc - hw, deck(ts[i]) - 2.6), P(ts[i + 1], nc, deck(ts[i + 1]) - 2.6), 0.22)
        under.beam(P(ts[i], nc + hw, deck(ts[i]) - 2.6), P(ts[i + 1], nc, deck(ts[i + 1]) - 2.6), 0.22)
    sl = [nc - hw + 2.0 + j * (2 * hw - 4.0) / 5 for j in range(6)]
    t = ta
    while t < tb:
        tn = min(t + 7.0, tb)
        under.add([P(t, nc - hw - 0.2, deck(t) - 0.62), P(tn, nc - hw - 0.2, deck(tn) - 0.62),
                   P(tn, nc + hw + 0.2, deck(tn) - 0.62), P(t, nc + hw + 0.2, deck(t) - 0.62)], [[3, 2, 1, 0]])   # dark soffit
        for n in sl:                                                      # stringers
            under.beam(P(t, n, deck(t) - 1.1), P(tn, n, deck(tn) - 1.1), 0.45, 0.9)
        if t0 <= t <= t1:
            under.beam(P(t, nc - hw, deck(t) - 2.0), P(tn, nc + hw, deck(tn) - 2.0), 0.25)
            under.beam(P(t, nc + hw, deck(t) - 2.0), P(tn, nc - hw, deck(tn) - 2.0), 0.25)
        else:                                                             # approach girders (plate girders)
            for n in (nc - hw + 1.0, nc + hw - 1.0):
                under.beam(P(t, n, deck(t) - 1.9), P(tn, n, deck(tn) - 1.9), 0.6, 2.6)
            if int(t) % 14 < 7:
                under.beam(P(t, nc - hw + 1, deck(t) - 1.6), P(t, nc + hw - 1, deck(t) - 1.6), 0.4, 1.0)
        t = tn
    # ---------------------------------------------------------------- piers (cream render)
    ang = math.atan2(ay, ax)
    def across(prof, tt, d0, d1):                                         # profile (n, z) extruded along t
        k_ = len(prof)
        verts = [P(tt + d0, nc + u, z) for u, z in prof] + [P(tt + d1, nc + u, z) for u, z in prof]
        faces = [list(range(k_)), list(range(2 * k_ - 1, k_ - 1, -1))]
        faces += [[(i + 1) % k_, i, k_ + i, k_ + (i + 1) % k_] for i in range(k_)]
        conc.add(verts, faces)
    for tt in (tn_, ts_):                                                 # r5: bearings on the pier tops
        for side in (-1, 1):
            xb_, yb_, _ = P(tt, nc + side * hw, 0)
            misc.box(xb_, yb_, deck(tt) - 3.0, 2.6, 2.0, 1.6, math.atan2(ay, ax))
    for tt in (tn_, ts_):         # main piers: one portal across the bridge, round-headed arch under the road
        x, y, _ = P(tt, nc, 0)
        g = min(min(L.ground_z(*P(tt, nc + s * hw, 0)[:2]) for s in (-1, 0, 1)), 1.5) - 0.5
        topz = deck(tt) - 1.2
        W2, D2 = BP["main_across_m"] / 2, BP["main_thick_m"] / 2
        zc = topz - BP["cornice_m"]
        hA = BP["arch_w_m"] / 2
        cb = L.HSW.get("pier_arch_crown_below_top_m")                       # HSW r2: taller arch (photo p09)
        spring = max(BP["arch_spring_m"], topz - cb - g - hA) if cb else BP["arch_spring_m"]
        across(arch_profile(2 * W2, zc, g, BP["arch_w_m"], spring), tt, -D2, D2)
        ap = [(-hA + 0.05, g)] + [(hA * math.cos(math.pi - math.pi * j / 16) * 0.99, g + spring + hA * math.sin(math.pi - math.pi * j / 16) * 0.99)
                                  for j in range(17)] + [(hA - 0.05, g)]
        for d in (-D2 + 0.6,):                                            # HSW r3: one mid-dark back wall in the arch
            k_ = len(ap)
            vs = [P(tt + d, nc + u, z) for u, z in ap] + [P(tt + d + 0.2, nc + u, z) for u, z in ap]
            shade_.add(vs, [list(range(k_)), list(range(2 * k_ - 1, k_ - 1, -1))])
        for u in (-hA * 0.55, hA * 0.55):                                 # r4: things seen through the arch (p09)
            x3, y3, _ = P(tt - D2 * 0.3, nc + u, 0)
            misc.box(x3, y3, g, 0.4, 0.4, spring + hA * 0.4, ang)
        x3, y3, _ = P(tt - D2 * 0.3, nc, 0)
        misc.box(x3, y3, g + spring * 0.55, 0.5, 2 * hA * 0.9, 0.6, ang)
        conc.box(x3, y3, g, 2.0, 2 * hA * 0.9, 1.2, ang)
        across([(-W2 - 1.5, zc - 0.3), (W2 + 1.5, zc - 0.3), (W2 + 1.5, topz), (-W2 - 1.5, topz)], tt, -D2 - 1.5, D2 + 1.5)   # cornice (r3: bolder)
        across([(-W2 - 0.5, zc - 1.6), (W2 + 0.5, zc - 1.6), (W2 + 0.5, zc - 0.9), (-W2 - 0.5, zc - 0.9)], tt, -D2 - 0.5, D2 + 0.5)
        for u0, u1 in ((-W2 - 0.8, -hA), (hA, W2 + 0.8)):                 # plinth under both legs
            across([(u0, g), (u1, g), (u1, g + 3.0), (u0, g + 3.0)], tt, -D2 - 0.8, D2 + 0.8)
        crown = g + spring + hA
        across([(-hA - 0.9, crown - 0.2), (hA + 0.9, crown - 0.2), (hA + 0.9, crown + 1.2), (-hA - 0.9, crown + 1.2)],
               tt, -D2 - 0.3, D2 + 0.3)                                   # keystone band over the arch
        for u in (-W2 + 0.9, -hA - 0.9, hA + 0.9, W2 - 0.9):              # pilasters on both faces
            for d in (-D2 - 0.3, D2 + 0.3):
                x2, y2, _ = P(tt + d, nc + u, 0)
                conc.box(x2, y2, g + 3.0, 0.6, 1.4, zc - 1.6 - g - 3.0, ang)
        for u0, u1 in ((-W2 - 0.3, -W2 + 5.5), (W2 - 5.5, W2 + 0.3)):     # HSW r2: broad corner pilasters (p09)
            across([(u0, g + 3.0), (u1, g + 3.0), (u1, zc - 1.6), (u0, zc - 1.6)], tt, -D2 - 1.0, D2 + 1.0)
    def pier(t, w, d, cap=True):
        for side in (-1, 1):
            x, y, _ = P(t, nc + side * hw, 0)
            g = min(L.ground_z(x, y), 1.0) - 1.0
            conc.box(x, y, g, w, d, deck(t) - 2.6 - g, ang)
            conc.box(x, y, deck(t) - 3.6, w + 0.8, d + 0.8, 1.0, ang)
        if cap:
            x, y, _ = P(t, nc, 0)
            conc.box(x, y, deck(t) - 3.2, 2.5, 2 * hw + 4, 2.0, ang)
    for t in (t0, t1):
        pier(t, 9.0, 7.0)                                                 # anchor piers
    t = ta
    while t <= tb:
        if not (t0 - 5 < t < t1 + 5):
            x, y, _ = P(t, nc, 0)
            if deck(t) - L.ground_z(x, y) > 4.0:
                pier(t, 3.0, 3.0)
        t += B["approach_span_m"]
    # ---------------------------------------------------------------- deck, footways, railings, lights
    step = 6.0
    t = ta
    while t < tb:
        tn = min(t + step, tb)
        for n0, n1, z_off, key in ((nc - hw + 0.8, nc + hw - 0.8, 0.0, "deck"),
                                   (nc - hw - 3.2, nc - hw - 0.6, 0.25, "pier"),
                                   (nc + hw + 0.6, nc + hw + 3.2, 0.25, "pier")):
            buf = dk if key == "deck" else under                         # r4: no pale cream strip at the deck edge
            a, b = (n0, n1)
            verts = [P(t, a, deck(t) + z_off), P(tn, a, deck(tn) + z_off), P(tn, b, deck(tn) + z_off), P(t, b, deck(t) + z_off),
                     P(t, a, deck(t) - 0.6), P(tn, a, deck(tn) - 0.6), P(tn, b, deck(tn) - 0.6), P(t, b, deck(t) - 0.6)]
            buf.add(verts, [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]])
        for n in (nc - hw - 3.2, nc + hw + 3.2):
            misc.beam(P(t, n, deck(t) + 1.35), P(tn, n, deck(tn) + 1.35), 0.12)
            misc.beam(P(t, n, deck(t) + 0.7), P(tn, n, deck(tn) + 0.7), 0.06)
        for n in (nc - hw - 3.2, nc + hw + 3.2):                          # rail posts
            misc.beam(P(t, n, deck(t) + 0.25), P(t, n, deck(t) + 1.35), 0.08)
        t = tn
    t = ta + 15
    while t < tb:
        for n in (nc - hw - 3.0, nc + hw + 3.0):
            misc.beam(P(t, n, deck(t) + 0.25), P(t, n, deck(t) + 8.0), 0.2)
            misc.beam(P(t, n, deck(t) + 8.0), P(t, n + (1.2 if n > nc else -1.2) * -1, deck(t) + 8.0), 0.15)
        t += B["light_spacing_m"]
    sm = C.material_rgb("story_bridge_steel", L.HSW.get("bridge_steel", BP["steel"]))     # r3: dark charcoal (p13)
    rm = C.material_rgb("story_bridge_render", L.HSW.get("pier_render", BP["render"]))
    objs = []
    um = C.material_rgb("story_bridge_underside", (0.03, 0.034, 0.034))   # HSW r2: near-black in shade (p09)
    am = C.material_rgb("story_bridge_arch_dark", L.HSW.get("pier_arch_back", (0.012, 0.012, 0.013)))
    for buf, name, mat in ((steel, "story_bridge_truss", sm), (under, "story_bridge_deck_steel", um),
                           (conc, "story_bridge_piers_footways", rm), (dk, "story_bridge_deck", None),
                           (misc, "story_bridge_rails_lights", sm), (shade_, "story_bridge_arch_shadow", am)):
        ob = buf.object(name, col, "deck" if mat is None else "steel")
        if mat is not None:
            ob.data.materials[0] = mat
        objs.append(ob.name)
    return {"module": "landmarks", "objects": objs, "panels": k, "k_panels": kpanels,
            "main_span_m": abs(B["main_piers_t"][1] - B["main_piers_t"][0]),
            "measured": B["measured_from"], "note": "Member sizes and panel layout are simplified; heights, piers, "
            "alignment and the deck profile are measured from the 2019 LiDAR points; pier arches and colours "
            "from photos (layout.STORY_BRIDGE_PIERS)."}
