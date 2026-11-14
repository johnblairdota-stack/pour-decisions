"""Solve a camera pose for each of John's Spire photos from landmark marks (step 7b). No bpy.

    <blender python> -I tools/blender/spire/photo_fit.py

Input: photo_marks.json (hand-read pixel positions of landmarks in each photo; file names only - the
photos stay in PourDecisions-sites/my_photos/spire and never go in git).
Output: photo_cams.json - per photo: position (local m), height, heading (deg from north, clockwise),
pitch, roll 0, focal (35 mm equivalent and Blender lens/shift), fit error in px, confidence.

Model: pinhole, no roll. mode "tilt" = pitch free, no shift (phones, drones); mode "shift" = pitch 0,
vertical lens shift free (architectural photos with straight verticals). Least squares by
Levenberg-Marquardt with weak priors on height and focal (marks are few)."""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layout as L  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def bridge_points():
    B = L.STORY_BRIDGE
    (cx, cy), (ax, ay) = B["centre_xy"], B["axis"]
    nx, ny = -ay, ax
    P = lambda t, n, z: (cx + ax * t + nx * n, cy + ay * t + ny * n, z)
    tn, ts = B["main_piers_t"]
    nc, hw = B["truss_centre_n"], B["truss_half_m"]
    return {"bridge_peak_n": P(tn, nc, 80.0), "bridge_peak_s": P(ts, nc, 80.0),
            "bridge_pier_n_deck": P(tn, nc, 34.5), "bridge_pier_s_deck": P(ts, nc, 34.5),
            "bridge_anchor_s_deck": P(B["truss_t"][1], nc, 33.0),
            "bridge_portal_n_w": P(tn, nc - hw, 80.0), "bridge_portal_n_e": P(tn, nc + hw, 80.0)}


def landmarks():
    """Named 3D points (local x, y, z AHD) measured from the model data (LiDAR/OSM)."""
    d = {b["osm"]: b for b in json.load(open(L.ref("lidar/buildings_clean.json")))["buildings"]}

    def top(osm, dz=0.0):
        """Tower top as an outline: the mark is the top of the silhouette (see project_mark)."""
        b = d[osm]
        t = max(b["tiers"], key=lambda t: t["top_ahd"])
        return {"ring": [tuple(p) for p in t["ring"]], "z": t["top_ahd"] + dz}

    lv = L.spire_levels()
    px, py = L.TOWER_PLAN["centre_xy"]
    pts = {
        "spire_top": {"ring": [tuple(p) for p in L.tower_outline()], "z": lv[-1]["top_ahd"] + 1.2},   # parapet outline
        "spire_plant": (px, py, L.SPIRE.get("top_ahd_lidar", 147.7)),
        "spire_tower_base": (px, py, L.level(6)["top_ahd"]),      # where the tower meets the podium roof
        "mantra_top": top(568836537),
        "willahra_top": top(26253098),
        "marriott_top": top(26253094, 4.0),                       # dome crown above the LiDAR roof
        "admiralty2_top": top(26386543),
        "admiralty1_top": top(26386571),
        "soleil_top": top(224320346),
        "aurora_top": top(44173034),
        "macrossan_top": top(224320345),
        "orient_top": top(186586595),
        "webber_top": top(186247884),
        "cath_spire_n": (-93.3, -74.3, 75.9),
        "cath_spire_s": (-104.2, -83.9, 75.9),
        "ann_queen_corner": (31.0, 38.0, L.ground_z(31.0, 38.0)),  # kerb point at the Ann/Queen split
        "customs_dome": (31.0, -263.0, 38.0),
        **bridge_points(),
    }
    return {k: (p if isinstance(p, dict) else tuple(float(v) for v in p)) for k, p in pts.items()}


def centre(lm):
    if isinstance(lm, dict):
        r = lm["ring"]
        return (sum(p[0] for p in r) / len(r), sum(p[1] for p in r) / len(r), lm["z"])
    return lm


def project_marks(pose, lms, W, H):
    """Image position of each landmark: a point projects normally; an outline (tower top) gives the
    middle of its projected x span and its highest projected point (the silhouette top)."""
    out, dzs = [], []
    for lm in lms:
        if isinstance(lm, dict):
            P = np.array([(x, y, lm["z"]) for x, y in lm["ring"]])
            q, dz = project(pose, P, W, H)
            out.append(((q[:, 0].min() + q[:, 0].max()) / 2, q[:, 1].min()))
            dzs.append(dz.min())
        else:
            q, dz = project(pose, np.array([lm]), W, H)
            out.append(tuple(q[0]))
            dzs.append(dz[0])
    return np.array(out), np.array(dzs)


def project(pose, P, W, H):
    x, y, z, yaw, pitch, f, shift = pose
    yw, pt = math.radians(yaw), math.radians(pitch)
    d = np.array([math.sin(yw) * math.cos(pt), math.cos(yw) * math.cos(pt), math.sin(pt)])
    r = np.array([math.cos(yw), -math.sin(yw), 0.0])
    u = np.cross(r, d)
    v = np.asarray(P) - np.array([x, y, z])
    dz = v @ d
    return np.stack([W / 2 + f * (v @ r) / dz, H / 2 - f * (v @ u) / dz - shift], -1), dz


def solve(photo, LM):
    W, H = photo["size"]
    names = [m[0] for m in photo["marks"]]
    P = [LM[n] for n in names]
    obs = np.array([m[1:] for m in photo["marks"]], float)
    g = photo["guess"]
    gz = L.ground_z(g["x"], g["y"]) + g.get("eye", 1.6)
    f0 = g.get("f35", 26.0) / 43.27 * math.hypot(W, H)
    pose = np.array([g["x"], g["y"], g.get("z", gz), g["heading"], g.get("pitch", 0.0), f0, 0.0])
    mode = photo.get("mode", "tilt")
    free = [0, 1, 2, 3, 5] + ([4] if mode == "tilt" else [6])
    zprior = g.get("z", gz)
    wz, wf = g.get("z_weight", 5.0 if "z" not in g else 0.05), 0.002   # street cams: eye height held near 1.6 m

    def resid(p):
        q, dz = project_marks(p, P, W, H)
        res = (q - obs).ravel()
        res = np.where(np.repeat(dz, 2) > 0, res, 1e4)
        return np.concatenate([res, [(p[2] - zprior) * wz * 10, (p[5] - f0) * wf * 10]])

    lam = 1e-2
    for _ in range(200):
        r0 = resid(pose)
        J = np.zeros((len(r0), len(free)))
        for j, k in enumerate(free):
            dp = np.zeros(7)
            dp[k] = 1e-3 * max(1.0, abs(pose[k]) * 1e-3) if k != 5 else 0.5
            J[:, j] = (resid(pose + dp) - r0) / dp[k]
        A = J.T @ J
        step = np.linalg.solve(A + lam * np.diag(np.diag(A) + 1e-9), -J.T @ r0)
        new = pose.copy()
        new[free] += step
        if (resid(new) ** 2).sum() < (r0 ** 2).sum():
            pose, lam = new, lam * 0.4
        else:
            lam *= 5
        if np.abs(step).max() < 1e-4:
            break
    q, _ = project_marks(pose, P, W, H)
    err = np.hypot(*(q - obs).T)
    return pose, err, q


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "photo_marks.json")
    dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "photo_cams.json")
    marks = json.load(open(src))
    LM = landmarks()
    out = []
    for ph in marks["photos"]:
        if ph.get("skip"):
            out.append({k: ph[k] for k in ("id", "file", "date", "stage", "skip")})
            continue
        pose, err, q = solve(ph, LM)
        if "z" not in ph["guess"]:          # street cam: hold the eye 1.6 m over the ground where it ended up
            ph2 = dict(ph, guess=dict(ph["guess"], x=float(pose[0]), y=float(pose[1]), heading=float(pose[3])))
            pose, err, q = solve(ph2, LM)
        W, H = ph["size"]
        x, y, z, yaw, pitch, f, shift = pose
        long_side = max(W, H)
        rms = float(np.sqrt((err ** 2).mean()))
        rel = rms / math.hypot(W, H)
        conf = "high" if rel < 0.006 and len(err) >= 5 else ("medium" if rel < 0.015 and len(err) >= 4 else "low")
        rec = {"id": ph["id"], "file": ph["file"], "src_dir": ph.get("src_dir", ""), "credit": ph.get("credit", {}), "date": ph.get("date", ""), "stage": ph.get("stage", "as_built"),
               "size": [W, H], "mode": ph.get("mode", "tilt"),
               "pos": [round(x, 1), round(y, 1), round(z, 1)], "eye_above_ground_m": round(z - L.ground_z(x, y), 1),
               "heading_deg": round(yaw % 360, 1), "pitch_deg": round(pitch, 2), "roll_deg": 0.0,
               "focal_35mm": round(f * 43.27 / math.hypot(W, H), 1),
               "blender": {"lens_mm": round(f * 36.0 / long_side, 2), "sensor_mm": 36.0,
                           "shift_y": round(-shift / long_side, 4)},
               "marks": len(err), "fit_rms_px": round(rms, 1), "fit_max_px": round(float(err.max()), 1),
               "per_mark_px": {m[0]: round(float(e), 1) for m, e in zip(ph["marks"], err)},
               "confidence": conf, "note": ph.get("note", "")}
        out.append(rec)
        print("%-24s pos %s heading %5.1f pitch %5.1f f35 %5.1f rms %5.1f px (%s)" % (
            ph["id"], rec["pos"], rec["heading_deg"], rec["pitch_deg"], rec["focal_35mm"], rms, conf))
    json.dump({"note": "Camera poses solved from hand-marked landmarks (photo_fit.py). Photos are John's and "
                       "are not in git; only file names are listed.", "landmarks": {k: [round(v, 2) for v in centre(p)] for k, p in LM.items()},
               "cams": out}, open(dst, "w"), indent=1)


if __name__ == "__main__":
    main()
