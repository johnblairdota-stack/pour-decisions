"""Solve camera poses for the HSW reference photos (HSW round 1). No bpy.

    <blender python> -I tools/hsw/hsw_fit.py [ids]

Input tools/hsw/hsw_marks.json: per photo the hand-read pixel position of landmarks (photo size = the
1600 px copy in PourDecisions-sites/refs/hsw). Output tools/hsw/hsw_cams.json (same format as the Spire
photo_cams.json, read by render_hsw.py). Uses photo_fit.solve (pinhole, no roll, LM with weak priors)."""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "blender", "spire"))
import numpy as np  # noqa: E402

import layout as L  # noqa: E402
import photo_fit as F  # noqa: E402


def hsw_landmarks():
    B = L.STORY_BRIDGE
    (cx, cy), (ax, ay) = B["centre_xy"], B["axis"]
    nx, ny = -ay, ax
    P = lambda t, n, z: (cx + ax * t + nx * n, cy + ay * t + ny * n, z)
    def interp(prof, t):            # same as landmarks.interp (that module needs bpy)
        for (a0, z0), (a1, z1) in zip(prof[:-1], prof[1:]):
            if a0 <= t <= a1:
                return z0 + (z1 - z0) * (t - a0) / (a1 - a0)
        return prof[0][1] if t < prof[0][0] else prof[-1][1]
    deck = lambda t: interp(B["deck_profile"], t)
    tn, ts = B["main_piers_t"]
    nc, hw = B["truss_centre_n"], B["truss_half_m"]
    t0, t1 = B["truss_t"]
    pts = {}
    for name, t in (("n", tn), ("s", ts)):
        for sname, side in (("w", -1), ("e", 1)):
            x, y, _ = P(t, nc + side * hw, 0)
            g = min(L.ground_z(x, y), 1.5) - 0.5
            pts["pier_%s_%s_top" % (name, sname)] = P(t, nc + side * hw, deck(t) - 1.2)
            pts["pier_%s_%s_base" % (name, sname)] = P(t, nc + side * hw, max(g, L.RIVER_LEVEL_AHD))
        BP = L.STORY_BRIDGE_PIERS                       # portal pier: corners of its faces, arch crown
        W2, D2 = BP["main_across_m"] / 2, BP["main_thick_m"] / 2
        g = min(min(L.ground_z(*P(t, nc + s * hw, 0)[:2]) for s in (-1, 0, 1)), 1.5) - 0.5
        hA = BP["arch_w_m"] / 2                         # same arch as landmarks.py (round 2: crown from photo p09)
        cb = L.HSW.get("pier_arch_crown_below_top_m")
        spring = max(BP["arch_spring_m"], deck(t) - 1.2 - cb - g - hA) if cb else BP["arch_spring_m"]
        for fname, d in (("s", D2), ("n", -D2)):
            pts["pier_%s_top_%sw" % (name, fname)] = P(t + d, nc - W2, deck(t) - 1.2)
            pts["pier_%s_top_%se" % (name, fname)] = P(t + d, nc + W2, deck(t) - 1.2)
            pts["pier_%s_crown_%s" % (name, fname)] = P(t + d, nc, g + spring + hA)
            pts["pier_%s_spring_%sw" % (name, fname)] = P(t + d, nc - hA, g + spring)
            pts["pier_%s_spring_%se" % (name, fname)] = P(t + d, nc + hA, g + spring)
        pts["peak_%s_w" % name] = P(t, nc - hw, 80.0)
        pts["peak_%s_e" % name] = P(t, nc + hw, 80.0)
    pts["anchor_n_deck"] = P(t0, nc, deck(t0))
    pts["anchor_s_deck"] = P(t1, nc, deck(t1))
    pts["midspan_top"] = P((tn + ts) / 2, nc, 49.5)
    H = L.HSW
    T = H["lift_tower"]
    pts["lift_top"] = (T["xy"][0], T["xy"][1], T["top_ahd"])
    pts["lift_base"] = (T["xy"][0], T["xy"][1], L.ground_z(*T["xy"]))
    pc = H["percivals"]
    pts["percivals_top"] = (pc["centre_xy"][0], pc["centre_xy"][1], pc["roof_top_ahd"])
    recs = {b["osm"]: b for b in json.load(open(L.ref("lidar/buildings_clean.json")))["buildings"]}
    for key, osm in (("felons", 58693374), ("hswshed", 58693380), ("rivershed", 679146329), ("greenhouse", 1085817540)):
        g = recs[osm]["gable"]
        ends = sorted([(g["cx"] + sgn * g["length"] / 2 * math.cos(g["angle"]),
                        g["cy"] + sgn * g["length"] / 2 * math.sin(g["angle"]), g["ridge_ahd"]) for sgn in (-1, 1)])
        pts["%s_ridge_w" % key], pts["%s_ridge_e" % key] = ends          # west (smaller x) end, east end
    for key, osm in (("hotel", 679146305), ("riverplace", 26386614), ("bowen_tower", 223642351),
                     ("bowen_tower2", 223642353), ("barrel_hall", 679146315)):
        b = recs.get(osm)
        if b is None:
            continue
        t = max(b["tiers"], key=lambda t: t["top_ahd"])
        pts[key + "_top"] = {"ring": [tuple(p) for p in t["ring"]], "z": t["top_ahd"]}
    pts["bowen_spire_top"] = (741.28, 66.86, 65.22)
    return pts


def main():
    marks = json.load(open(os.path.join(HERE, "hsw_marks.json")))
    LM = {**F.landmarks(), **hsw_landmarks()}
    only = sys.argv[1].split(",") if len(sys.argv) > 1 else None
    dst = os.path.join(HERE, "hsw_cams.json")
    old = {c["id"]: c for c in json.load(open(dst))["cams"]} if os.path.exists(dst) else {}
    out = []
    for ph in marks["photos"]:
        if only and ph["id"] not in only:
            if ph["id"] in old:
                out.append(old[ph["id"]])
            continue
        best = None                                  # multi-start: the LM solve finds local minima easily
        g0 = ph["guess"]
        for dh in (-12, 0, 12):
            for zk in (0.7, 1.0, 1.4):
                for f35 in (20, 28, 40):
                    for dxy in ((0, 0), (40, 0), (-40, 0), (0, 40), (0, -40)):
                        if dxy != (0, 0) and ((dh, zk, f35) != (0, 1.0, 28) or g0.get("xy_weight", 0) >= 1.0):
                            continue                         # r6: a strong position prior is not shifted
                        g = dict(g0, heading=g0["heading"] + dh, f35=f35 if "f35_fixed" not in g0 else g0["f35"],
                                 x=g0["x"] + dxy[0], y=g0["y"] + dxy[1])
                        if "z" in g0 and g0.get("z_weight", 0) < 1:
                            g["z"] = L.ground_z(g0["x"], g0["y"]) + (g0["z"] - L.ground_z(g0["x"], g0["y"])) * zk
                        try:
                            pose, err, q = F.solve(dict(ph, guess=g), LM)
                        except Exception:
                            continue
                        s = float(np.sqrt((err ** 2).mean()))
                        if best is None or s < best[0]:
                            best = (s, pose, err, q, g)
        _, pose, err, q, gbest = best
        ph = dict(ph, guess=gbest)
        W, Hh = ph["size"]
        x, y, z, yaw, pitch, f, shift = pose
        long_side = max(W, Hh)
        held = []
        if len(ph["marks"]) >= 5:
            for i in range(len(ph["marks"])):
                rest = dict(ph, marks=[m for j, m in enumerate(ph["marks"]) if j != i],
                            guess=dict(ph["guess"], x=float(x), y=float(y), z=float(z), heading=float(yaw), pitch=float(pitch)))
                p_i, _, _ = F.solve(rest, LM)
                q_i, _ = F.project_marks(p_i, [LM[ph["marks"][i][0]]], W, Hh)
                held.append(float(np.hypot(*(q_i[0] - np.array(ph["marks"][i][1:], float)))))
        rms = float(np.sqrt((err ** 2).mean()))
        rec = {"id": ph["id"], "file": ph["file"], "title": ph.get("title", ""), "date": ph.get("date", ""),
               "time_h": ph.get("time_h"), "size": [W, Hh], "mode": ph.get("mode", "tilt"),
               "pos": [round(x, 1), round(y, 1), round(z, 1)], "eye_above_ground_m": round(z - L.ground_z(x, y), 1),
               "heading_deg": round(yaw % 360, 1), "pitch_deg": round(pitch, 2), "roll_deg": 0.0,
               "focal_35mm": round(f * 43.27 / math.hypot(W, Hh), 1),
               "blender": {"lens_mm": round(f * 36.0 / long_side, 2), "sensor_mm": 36.0, "shift_y": round(-shift / long_side, 4)},
               "marks": len(err), "fit_rms_px": round(rms, 1), "fit_max_px": round(float(err.max()), 1),
               "per_mark_px": {m[0]: round(float(e), 1) for m, e in zip(ph["marks"], err)},
               "projected": {m[0]: [round(float(v), 1) for v in qq] for m, qq in zip(ph["marks"], q)},
               "holdout_rms_px": round(float(np.sqrt(np.mean(np.square(held)))), 1) if held else None,
               "note": ph.get("note", "")}
        out.append(rec)
        print("%-22s pos %s eye %5.1f hdg %5.1f pitch %5.1f f35 %5.1f rms %5.1f px max %5.1f holdout %s" % (
            ph["id"], rec["pos"], rec["eye_above_ground_m"], rec["heading_deg"], rec["pitch_deg"], rec["focal_35mm"],
            rms, rec["fit_max_px"], rec["holdout_rms_px"]))
    json.dump({"note": "HSW photo cameras solved from hand marks (hsw_fit.py). Photos are not in git.",
               "landmarks": {k: [round(v, 2) for v in F.centre(p)] for k, p in LM.items()}, "cams": out},
              open(dst, "w"), indent=1)


if __name__ == "__main__":
    main()
