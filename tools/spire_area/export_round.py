"""Export one Spire-area render round (Blender's Python + Pillow in PourDecisions-sites/pylib), like
tools/hsw/export_round.py:

    <blender python> -I tools/spire_area/export_round.py <sites_dir> <render_dir> <round>

-> <sites>/spire_area_showcase/round_NN/<id>_photo.jpg + <id>_render.jpg (1600 px long side, q82), hero_<id>.jpg,
   pairs.json in the showcase format {"pairs": [{id, photo, render, caption, date, fit_px, stage}]}
-> docs/spire_area/renders/round_NN/: render-only jpgs + renders.json (photos never go in git)."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SPIRE = os.path.join(REPO, "tools", "blender", "spire")
sites, rdir, rnd = sys.argv[1:4]
sys.path.insert(0, os.path.join(sites, "pylib"))
from PIL import Image  # noqa: E402

out = os.path.join(sites, "spire_area_showcase", "round_%02d" % int(rnd))
git_out = os.path.join(REPO, "docs", "spire_area", "renders", "round_%02d" % int(rnd))
os.makedirs(out, exist_ok=True)
os.makedirs(git_out, exist_ok=True)
A = json.load(open(os.path.join(HERE, "area_cams.json"), encoding="utf-8"))
cams = {c["id"]: c for c in json.load(open(os.path.join(SPIRE, "photo_cams.json")))["cams"]}
CAPTIONS = {   # same captions as the showcase page
    "aerial_ne_dusk": "Aerial over Spring Hill towards the river at dusk",
    "cathedral_forecourt": "Spire and the cathedral from the cathedral forecourt",
    "crane_from_nw": "2017 top-out from the north-west, crane up",
    "ann_st_far": "Spire down Ann St from the north-east",
    "fly_by_east": "Petrie Bight towers from the east",
    "crane_from_south": "2017 top-out from the south, crane up",
    "queen_st_willahra": "Willahra and Spire from Queen St",
    "orient_front": "Orient Hotel and Spire from the junction",
    "ann_queen_corner": "Spire from the Ann/Queen St corner",
}
STAGE = {"as_built": "as-built", "2017_top": "2017 top-out"}


def save(src, dst, size=None):
    im = Image.open(src).convert("RGB")
    if size:
        im = im.resize(size, Image.LANCZOS)
    k = 1600 / max(im.size)
    if k < 1:
        im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    im.save(dst, quality=82, optimize=True)
    return im.size


pairs, heroes, renders = [], [], []
for pid in A["pairs"]:
    src = os.path.join(rdir, pid + "_render.png")
    if not os.path.exists(src):
        continue
    c = cams[pid]
    rs = save(src, os.path.join(out, pid + "_render.jpg"))
    save(src, os.path.join(git_out, pid + "_render.jpg"))
    photo = os.path.join(sites, "my_photos", "spire", c["file"])
    if os.path.exists(photo):
        save(photo, os.path.join(out, pid + "_photo.jpg"), rs)
    pairs.append({"id": pid, "photo": pid + "_photo.jpg", "render": pid + "_render.jpg",
                  "caption": CAPTIONS.get(pid, pid), "date": c.get("date", ""),
                  "fit_px": c.get("holdout_px_at_1600", c.get("fit_rms_px")), "stage": STAGE.get(c["stage"], c["stage"])})
    renders.append({"id": pid, "render_file": pid + "_render.jpg", "kind": "photo pair (photo is John's, not in git)",
                    "camera": {"pos": c["pos"], "heading_deg": c["heading_deg"], "pitch_deg": c["pitch_deg"],
                               "focal_35mm": c["focal_35mm"]}, "fit_rms_px": c["fit_rms_px"]})
for pid in A.get("commons_pairs", []):
    src = os.path.join(rdir, pid + "_render.png")
    if os.path.exists(src):
        save(src, os.path.join(out, pid + "_render.jpg"))
        save(src, os.path.join(git_out, pid + "_render.jpg"))
        renders.append({"id": pid, "render_file": pid + "_render.jpg", "kind": "Commons photo pair (showcase_cams.json)"})
caps = {h["id"]: h.get("caption", "") for h in A["heroes"] + A["showcase"]}
for f in sorted(os.listdir(rdir)):
    if f.startswith("hero_") and f.endswith(".png"):
        hid = f[5:-4]
        save(os.path.join(rdir, f), os.path.join(out, "hero_%s.jpg" % hid))
        save(os.path.join(rdir, f), os.path.join(git_out, "hero_%s.jpg" % hid))
        heroes.append({"file": "hero_%s.jpg" % hid, "caption": caps.get(hid, hid)})
json.dump({"pairs": pairs}, open(os.path.join(out, "pairs.json"), "w", encoding="utf-8"), indent=1)
json.dump({"round": int(rnd), "pairs": renders, "heroes": heroes},
          open(os.path.join(git_out, "renders.json"), "w", encoding="utf-8"), indent=1)
print("exported", len(pairs), "pairs,", len(heroes), "heroes ->", out, "and", git_out)
