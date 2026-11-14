"""Lift/stair core: its own element (not in any slab pour), square and plumb so the lifts run.
Finished: walls up to the lift overrun. At a stage: walls up to `lead_levels` above the working deck,
with the jump-form rig on top. Box from the typical floor plan (layout.TOWER_PLAN core_px)."""
import layout as L
import common as C


def wall(buf, ua, va, ub, vb, t, z0, z1):
    """Straight wall on the centre line (ua, va) -> (ub, vb) in the plan frame, thickness t."""
    du, dv = ub - ua, vb - va
    ln = (du * du + dv * dv) ** 0.5
    nu, nv = -dv / ln * t / 2, du / ln * t / 2
    ring = [L.uv_to_local(ua - nu, va - nv), L.uv_to_local(ub - nu, vb - nv),
            L.uv_to_local(ub + nu, vb + nv), L.uv_to_local(ua + nu, va + nv)]
    buf.prism(ring, z0, z1)


def frame(buf, u0, u1, v0, v1, w, z0, z1):
    """Rectangular ring (outside u0..u1, v0..v1, width w) - a jump-form deck or screen."""
    wall(buf, u0 - w / 2, v0 - w, u0 - w / 2, v1 + w, w, z0, z1)
    wall(buf, u1 + w / 2, v0 - w, u1 + w / 2, v1 + w, w, z0, z1)
    wall(buf, u0, v0 - w / 2, u1, v0 - w / 2, w, z0, z1)
    wall(buf, u0, v1 + w / 2, u1, v1 + w / 2, w, z0, z1)


def build():
    st = L.stage()
    col = C.collection("core")
    levels = L.spire_levels()
    by_n = {lv["n"]: lv for lv in levels}
    u0, u1, v0, v1 = L.core_uv()
    t = L.CORE["wall_m"]
    jf = L.CORE["jump_form"]
    z0 = min(L.ground_z(*L.uv_to_local(u, v)) for u in (u0, u1) for v in (v0, v1)) - 0.5
    if st is None:
        z1 = levels[-1]["top_ahd"] + L.CORE["overrun_m"]
        lead_to = levels[-1]["name"]
    else:
        n_top = min(st["deck_level"] + jf["lead_levels"], levels[-1]["n"])
        z1 = by_n[n_top]["top_ahd"]
        lead_to = by_n[n_top]["name"]
    w = C.MeshBuf()
    # outer walls (centre lines half a wall in from the plan box), square and plumb
    a0, a1, b0, b1 = u0 + t / 2, u1 - t / 2, v0 + t / 2, v1 - t / 2
    wall(w, a0, b0, a1, b0, t, z0, z1)
    wall(w, a1, b0, a1, b1, t, z0, z1)
    wall(w, a1, b1, a0, b1, t, z0, z1)
    wall(w, a0, b1, a0, b0, t, z0, z1)
    # lifts along the south (low v) side, stair/lobby to the north: one cross wall + dividers
    vm = v0 + (v1 - v0) * 0.45
    wall(w, a0, vm, a1, vm, t, z0, z1)
    n = L.CORE["lifts"]
    for k in range(1, n):
        uk = a0 + (a1 - a0) * k / n
        wall(w, uk, b0, uk, vm, t * 0.7, z0, z1)
    objs = [w.object("CORE_walls", col, "core").name]
    rig = None
    if st is not None:
        ftf = by_n[st["deck_level"] + 1]["top_ahd"] - by_n[st["deck_level"]]["top_ahd"]
        r = C.MeshBuf()
        out = jf["rig_out_m"]
        bottom = z1 - jf["rig_levels"] * ftf
        for k in range(jf["rig_levels"] + 1):          # working decks
            zk = bottom + k * ftf
            frame(r, u0, u1, v0, v1, out, zk - 0.15, zk)
        frame(r, u0 - out, u1 + out, v0 - out, v1 + out, 0.1, bottom - 1.0, z1 + 2.0)   # screens round the rig
        objs.append(r.object("CORE_jump_form", col, "jumpform").name)
        rig = {"decks": jf["rig_levels"] + 1, "bottom_ahd": round(bottom, 2), "top_ahd": round(z1 + 2.0, 2)}
    return {"module": "core", "objects": objs, "walls_to": lead_to, "top_ahd": round(z1, 2),
            "box_m": [round(u1 - u0, 2), round(v1 - v0, 2)], "wall_m": t, "lifts": L.CORE["lifts"],
            "jump_form": jf["type"], "lead_levels": jf["lead_levels"] if st else None, "rig": rig,
            "note": L.CORE["source"]}
