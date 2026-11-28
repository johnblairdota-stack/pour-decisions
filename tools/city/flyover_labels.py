#!/usr/bin/env python3
"""Pop-up name tags on the fly-over frames: game towers in gold, Brisbane places in white (no Blender).

    python3 tools/city/flyover_labels.py heights <data>          fill in each place's roof height from the LiDAR
    python3 tools/city/flyover_labels.py draw <frames.json> <frames_dir> <out_dir> <fonts_dir> [only=f00380]

Places are in tools/city/flyover_places.json. Each one is pinned to its real spot in the model: the frame's
camera (flyover.py plan) projects the roof point into the picture, so the tag stays on the place as the camera
moves. A place plays through five states (design board "Fly-over location pop-ups", look A, site tag):
far (a dot and a small name), lock on (a ring lands on the roof and a line climbs), pop (the tag squashes in,
gold sparks for game towers), hold, and pass (it shrinks and fades near the frame edge). At most MAX_OPEN tags
are open at once: game towers first, then the nearest. fonts_dir holds BarlowCondensed-ExtraBold.ttf (OFL).
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
PLACES = os.path.join(HERE, "flyover_places.json")
ORIGIN = (503046.57, 6962279.05)        # layout.ORIGIN_MGA56
OPEN_M = 3000.0                         # a tag opens when the camera is this close
FAR_M = 9000.0                          # further than this a place is not named at all
MAX_OPEN = 4
SS = 2                                  # drawn at twice the size, then shrunk: smooth edges
GOLD, DARK, WHITE = (255, 210, 63), (26, 29, 36), (255, 255, 255)


def local(lat, lon):
    sys.path.insert(0, os.path.join(ROOT, "tools", "blender", "spire"))
    import layout as L
    return L.to_local(lat, lon)


def heights(data):
    """z for every place: the high roof within 25 m of its spot in the 1 m LiDAR surface (95th percentile)."""
    import numpy as np
    d = json.load(open(PLACES))
    gdir = os.path.join(data, "cbd", "elvis", "grid2019")
    for p in d["places"]:
        if p.get("z_fixed"):
            continue
        x, y = local(p["lat"], p["lon"])
        E, N = x + ORIGIN[0], y + ORIGIN[1]
        t = os.path.join(gdir, "%d_%d" % (E // 1000 * 1000, N // 1000 * 1000))
        if not os.path.isdir(t):
            p["z"] = p.get("z", 20.0)
            continue
        g = json.load(open(os.path.join(t, "grid.json")))
        a = np.fromfile(os.path.join(t, "dsm.f32"), "<f4").reshape(g["H"], g["W"])
        r, c = int(g["Y1"] - N), int(E - g["X0"])
        win = a[max(0, r - 25):r + 25, max(0, c - 25):c + 25]
        win = win[~np.isnan(win)]
        p["z"] = round(float(np.percentile(win, 95)), 1) if win.size else p.get("z", 5.0)
        print("%-26s z %.1f" % (p["name"], p["z"]))
    json.dump(d, open(PLACES, "w"), indent=1)


def project(f, x, y, z):
    """Model point to pixel (and its distance) for one frame of flyover.py."""
    px, py, pz = f["pos"][0], f["pos"][1], f["z"]
    fw = (f["target"][0] - px, f["target"][1] - py, f["target"][2] - pz)
    n = math.sqrt(sum(c * c for c in fw))
    fw = [c / n for c in fw]
    rn = math.hypot(fw[0], fw[1])
    r = (fw[1] / rn, -fw[0] / rn, 0.0)
    u = (r[1] * fw[2] - r[2] * fw[1], r[2] * fw[0] - r[0] * fw[2], r[0] * fw[1] - r[1] * fw[0])
    d = (x - px, y - py, z - pz)
    zc = sum(a * b for a, b in zip(d, fw))
    if zc < 30:
        return None
    w, h = f["size"]
    fx = f["f35"] / 36.0 * w
    return (w * f["at"][0] + fx * sum(a * b for a, b in zip(d, r)) / zc,
            h * f["at"][1] - fx * sum(a * b for a, b in zip(d, u)) / zc, math.sqrt(sum(c * c for c in d)))


def ease_out_back(t):
    t = min(max(t, 0.0), 1.0) - 1.0
    return 1.0 + 2.2 * t * t * t + 1.2 * t * t


def hard_hat(dr, cx, cy, s, col):
    dr.pieslice([cx - s, cy - s * 0.9, cx + s, cy + s * 1.1], 180, 360, fill=col)
    dr.rounded_rectangle([cx - s * 1.3, cy + s * 0.05, cx + s * 1.3, cy + s * 0.45], s * 0.15, fill=col)
    dr.rectangle([cx - s * 0.12, cy - s * 1.15, cx + s * 0.12, cy - s * 0.5], fill=col)


def pin(dr, cx, cy, s, col, hole):
    dr.ellipse([cx - s * 0.7, cy - s, cx + s * 0.7, cy + s * 0.4], fill=col)
    dr.polygon([(cx - s * 0.55, cy + s * 0.1), (cx + s * 0.55, cy + s * 0.1), (cx, cy + s * 1.1)], fill=col)
    dr.ellipse([cx - s * 0.25, cy - s * 0.55, cx + s * 0.25, cy - s * 0.05], fill=hole)


def star(dr, cx, cy, s, col):
    k = s * 0.28
    dr.polygon([(cx, cy - s), (cx + k, cy - k), (cx + s, cy), (cx + k, cy + k), (cx, cy + s), (cx - k, cy + k),
                (cx - s, cy), (cx - k, cy - k)], fill=col)


def draw(frames_json, frames_dir, out_dir, fonts_dir, only=None):
    from PIL import Image, ImageDraw, ImageFont
    frames = [f for f in json.load(open(frames_json)) if os.path.exists(os.path.join(frames_dir, f["id"] + ".png"))]
    places = json.load(open(PLACES))["places"]
    for p in places:
        p["x"], p["y"] = local(p["lat"], p["lon"])
        p["z"] = p.get("z", 20.0) + 4.0
    step = (int(frames[1]["id"][1:]) - int(frames[0]["id"][1:])) if len(frames) > 1 else 1
    fps = 24.0                                             # the frames that exist are played at 24 a second
    big = ImageFont.truetype(os.path.join(fonts_dir, "BarlowCondensed-ExtraBold.ttf"), 23 * SS)
    kick = ImageFont.truetype(os.path.join(fonts_dir, "BarlowCondensed-ExtraBold.ttf"), 12 * SS)
    mid = ImageFont.truetype(os.path.join(fonts_dir, "BarlowCondensed-ExtraBold.ttf"), 19 * SS)
    small = ImageFont.truetype(os.path.join(fonts_dir, "BarlowCondensed-ExtraBold.ttf"), 14 * SS)
    os.makedirs(out_dir, exist_ok=True)
    opened, lift = {}, {}                                  # place -> frame count when it opened; its smoothed tag lift
    for n, f in enumerate(frames):
        W, H = f["size"]
        seen = []
        for i, p in enumerate(places):
            q = project(f, p["x"], p["y"], p["z"])
            if q and -40 < q[0] < W + 40 and 20 < q[1] < H + 40 and q[2] < FAR_M:
                seen.append((i, q))
        want = sorted((s for s in seen if s[1][2] < OPEN_M and 70 < s[1][0] < W - 70 and s[1][1] > 90),
                      key=lambda s: (places[s[0]]["kind"] != "game", s[1][2]))
        keep = {i for i in opened if any(s[0] == i for s in want)}          # an open tag stays open while it can
        for s in want:
            if len(keep) >= MAX_OPEN:
                break
            keep.add(s[0])
        for i in list(opened):
            if i not in keep:
                del opened[i]
        for i in keep:
            opened.setdefault(i, n)
        if only and f["id"] != only:
            for i in keep:                                  # still settle the lifts so a single frame looks like the film
                lift.setdefault(i, 0.0)
            continue
        im = Image.open(os.path.join(frames_dir, f["id"] + ".png")).convert("RGBA")
        ov = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        dr = ImageDraw.Draw(ov)
        boxes = []
        for i, q in sorted(seen, key=lambda s: -s[1][2]):                   # far ones first, near ones on top
            p = places[i]
            game = p["kind"] == "game"
            col = GOLD if game else WHITE
            x, y = q[0] * SS, q[1] * SS
            edge = min(q[0] - 40, W - 40 - q[0], q[1] - 60) / 90.0          # 0 at the frame edge, 1 well inside
            fade = min(max(edge, 0.0), 1.0)
            if i not in opened:
                a = int(255 * fade * min(1.0, (FAR_M - q[2]) / 1500.0))
                if a <= 8:
                    continue
                r = 5 * SS
                dr.ellipse([x - r, y - r, x + r, y + r], fill=col + (a,), outline=DARK + (a,), width=2 * SS)
                name = p["name"].upper()
                tw = dr.textlength(name, font=small)
                dr.text((x - tw / 2, y - 26 * SS), name, font=small, fill=col + (a,), stroke_width=2 * SS, stroke_fill=DARK + (a,))
                continue
            t = (n - opened[i]) / fps                       # seconds since it opened
            a = int(255 * fade)
            ring = min(t / 0.3, 1.0)
            rx = (26 if game else 22) * SS * (0.4 + 0.6 * ring) * (1.0 + 0.04 * math.sin(t * 2.6))
            ry = rx * 0.32
            dr.ellipse([x - rx, y - ry, x + rx, y + ry], outline=col + (a,), width=3 * SS)
            if t < 0.6:                                     # the ripple
                k = t / 0.6
                dr.ellipse([x - rx * (1 + k), y - ry * (1 + k), x + rx * (1 + k), y + ry * (1 + k)],
                           outline=col + (int(a * (1 - k) * 0.7),), width=2 * SS)
            name = p["name"].upper()
            pad, disc = 8 * SS, 34 * SS
            if game:
                tw = max(dr.textlength(name, font=big), dr.textlength("POUR SITE", font=kick) + 6 * SS)
                bw, bh = disc + tw + pad * 3.4, 48 * SS
            else:
                tw = dr.textlength(name, font=mid)
                bw, bh = 18 * SS + tw + pad * 3.2, 32 * SS
            base = 46 * SS
            cur = lift.get(i, 0.0)
            want_lift = 0.0
            while any(abs((x) - bx) < (bw + bw2) / 2 + 6 * SS and abs((y - base - want_lift - bh / 2) - by) < (bh + bh2) / 2 + 6 * SS
                      for bx, by, bw2, bh2 in boxes) and want_lift < 400 * SS:
                want_lift += 14 * SS
            cur += (want_lift - cur) * (1.0 if i not in lift else 0.18)
            lift[i] = cur
            line = min(max((t - 0.1) / 0.25, 0.0), 1.0)
            top = y - (base + cur) * line
            dr.line([x, y - ry, x, top], fill=col + (a,), width=3 * SS)
            cy = y - base - cur - bh / 2
            boxes.append((x, cy, bw, bh))
            sc = ease_out_back((t - 0.3) / 0.22) if t >= 0.3 else 0.0
            sc *= 0.75 + 0.25 * fade
            if sc <= 0.01:
                continue
            tag = Image.new("RGBA", (int(bw + 8 * SS), int(bh + 12 * SS)), (0, 0, 0, 0))
            td = ImageDraw.Draw(tag)
            if game:
                td.rounded_rectangle([2 * SS, 6 * SS, bw + 2 * SS, bh + 6 * SS], bh / 2, fill=(0, 0, 0, 90))
                td.rounded_rectangle([2 * SS, 2 * SS, bw + 2 * SS, bh + 2 * SS], bh / 2, fill=DARK + (255,), outline=GOLD + (255,), width=2 * SS)
                dx, dy = 2 * SS + bh / 2, 2 * SS + bh / 2
                td.ellipse([dx - disc / 2, dy - disc / 2, dx + disc / 2, dy + disc / 2], fill=GOLD + (255,))
                hard_hat(td, dx, dy + 1 * SS, 8.5 * SS, DARK + (255,))
                tx = dx + disc / 2 + pad
                td.text((tx, 2 * SS + 6 * SS), "POUR SITE", font=kick, fill=GOLD + (255,), spacing=0, features=None)
                td.text((tx, 2 * SS + 18 * SS), name, font=big, fill=WHITE + (255,))
            else:
                td.rounded_rectangle([2 * SS, 5 * SS, bw + 2 * SS, bh + 5 * SS], 6 * SS, fill=(0, 0, 0, 90))
                td.rounded_rectangle([2 * SS, 2 * SS, bw + 2 * SS, bh + 2 * SS], 6 * SS, fill=WHITE + (255,))
                pin(td, 2 * SS + pad + 7 * SS, 2 * SS + bh / 2 - 1 * SS, 8 * SS, DARK + (255,), WHITE + (255,))
                td.text((2 * SS + pad + 18 * SS + 4 * SS, 2 * SS + 4 * SS), name, font=mid, fill=DARK + (255,))
            squash = 1.0 + 0.12 * max(0.0, 1.0 - abs((t - 0.4) / 0.1)) if t < 0.5 else 1.0
            tw2, th2 = max(1, int(tag.width * sc * squash)), max(1, int(tag.height * sc / squash))
            tag = tag.resize((tw2, th2), Image.LANCZOS)
            if a < 255:
                tag.putalpha(tag.getchannel("A").point(lambda v: v * a // 255))
            ov.alpha_composite(tag, (int(x - tw2 / 2), int(cy - th2 / 2)))
            dr = ImageDraw.Draw(ov)
            if game and 0.3 <= t < 1.0:                     # gold sparks fly out and fade
                k = (t - 0.3) / 0.7
                for j in range(10):
                    ang = j * 0.628 + i
                    rad = (bw * 0.5 + 14 * SS) * (0.5 + 0.8 * k)
                    star(dr, x + math.cos(ang) * rad, cy + math.sin(ang) * rad * 0.55, (3 + (j % 3)) * SS * (1 - k) + 1,
                         GOLD + (int(a * (1 - k)),))
        im.alpha_composite(ov.resize((W, H), Image.LANCZOS))
        im.convert("RGB").save(os.path.join(out_dir, f["id"] + ".png"))
    print("labelled %d frames (every %d) into %s" % (1 if only else len(frames), step, out_dir))


if __name__ == "__main__":
    a = sys.argv[1:]
    opt = {k: v for k, v in (x.split("=", 1) for x in a if "=" in x)}
    pos = [x for x in a if "=" not in x]
    if pos and pos[0] == "heights":
        heights(pos[1])
    elif pos and pos[0] == "draw":
        draw(pos[1], pos[2], pos[3], pos[4], opt.get("only"))
    else:
        print(__doc__)
