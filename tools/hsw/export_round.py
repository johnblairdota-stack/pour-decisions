"""Export one HSW render round (run with Blender's Python + Pillow in PourDecisions-sites/pylib):

    <blender python> -I tools/hsw/export_round.py <sites_dir> <render_dir> <round> pair_ids hero_ids

-> <sites>/hsw_showcase/round_NN/<id>_photo.jpg, <id>_render.jpg (1600 px long side, q82), hero_<name>.jpg,
   pairs.json; and render-only copies in docs/hsw/renders/round_NN/ (photos never go in git)."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sites, rdir, rnd, pair_ids, hero_ids = sys.argv[1:6]
sys.path.insert(0, os.path.join(sites, "pylib"))
from PIL import Image  # noqa: E402

out = os.path.join(sites, "hsw_showcase", "round_%02d" % int(rnd))
git_out = os.path.join(REPO, "docs", "hsw", "renders", "round_%02d" % int(rnd))
os.makedirs(out, exist_ok=True)
os.makedirs(git_out, exist_ok=True)
refs = os.path.join(sites, "refs", "hsw")
state = json.load(open(os.path.join(refs, "download_state.json")))
cams = {c["id"]: c for c in json.load(open(os.path.join(HERE, "hsw_cams.json")))["cams"]}
marks = {p["id"]: p for p in json.load(open(os.path.join(HERE, "hsw_marks.json")))["photos"]}


def save(src, dst, size=None):
    im = Image.open(src).convert("RGB")
    if size:
        im = im.resize(size, Image.LANCZOS)
    k = 1600 / max(im.size)
    if k < 1:
        im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    im.save(dst, quality=82, optimize=True)
    return im.size


pairs = []
for pid in pair_ids.split(","):
    c, m = cams[pid], marks[pid]
    st = state.get(os.path.basename(m["file"]), {})
    rs = save(os.path.join(rdir, pid + "_render.png"), os.path.join(out, pid + "_render.jpg"))
    save(os.path.join(refs, m["file"]), os.path.join(out, pid + "_photo.jpg"), rs)
    save(os.path.join(rdir, pid + "_render.png"), os.path.join(git_out, pid + "_render.jpg"))
    pairs.append({"id": pid, "title": m.get("title", ""), "photo_file": pid + "_photo.jpg",
                  "render_file": pid + "_render.jpg",
                  "photo_source_url": st.get("source_page") if str(st.get("source_page", "")).startswith("http")
                  else st.get("image_url", ""),
                  "photo_credit": st.get("credit", "") + ((" (" + st["licence"] + ")") if st.get("licence") else ""),
                  "camera": {"pos_local_m": c["pos"], "eye_above_ground_m": c["eye_above_ground_m"],
                             "heading_deg": c["heading_deg"], "pitch_deg": c["pitch_deg"], "focal_35mm": c["focal_35mm"]},
                  "notes": (m.get("note", "") + " Solved from %d hand marks; rendered in day light." % c["marks"]).strip(),
                  "fit_px": {"rms": c["fit_rms_px"], "max": c["fit_max_px"], "holdout_rms": c["holdout_rms_px"],
                             "photo_size": c["size"]}})
heroes = []
for h in hero_ids.split(","):
    save(os.path.join(rdir, "hero_%s.png" % h), os.path.join(out, "hero_%s.jpg" % h))
    save(os.path.join(rdir, "hero_%s.png" % h), os.path.join(git_out, "hero_%s.jpg" % h))
    heroes.append("hero_%s.jpg" % h)
json.dump(pairs, open(os.path.join(out, "pairs.json"), "w", encoding="utf-8"), indent=1)
json.dump({"pairs": [{k: v for k, v in p.items() if k != "photo_file"} for p in pairs], "heroes": heroes},
          open(os.path.join(git_out, "renders.json"), "w", encoding="utf-8"), indent=1)
print("exported", len(pairs), "pairs,", len(heroes), "heroes ->", out)
