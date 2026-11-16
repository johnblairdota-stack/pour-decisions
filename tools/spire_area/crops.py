"""Before / after crops for a round (critic boxes are x, y, w, h on the full-size renders).

    <blender python> -I tools/spire_area/crops.py <sites_dir> <before_dir> <after_dir> <round> crops.json

Writes <sites>/spire_area_work/crops_rNN/<name>_before.jpg / _after.jpg and render-only copies to
docs/spire_area/renders/round_NN/crops/ (renders only, no photos). Prints the list for NOTES.md."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sites, before, after, rnd, spec = sys.argv[1:6]
sys.path.insert(0, os.path.join(sites, "pylib"))
from PIL import Image  # noqa: E402

out = os.path.join(sites, "spire_area_work", "crops_r%02d" % int(rnd))
git_out = os.path.join(REPO, "docs", "spire_area", "renders", "round_%02d" % int(rnd), "crops")
os.makedirs(out, exist_ok=True)
os.makedirs(git_out, exist_ok=True)
for c in json.load(open(spec, encoding="utf-8")):
    x, y, w, h = c["box"]
    for tag, d in (("before", before), ("after", after)):
        p = os.path.join(d, c["file"])
        if not os.path.exists(p):
            print("missing", p)
            continue
        im = Image.open(p).convert("RGB").crop((x, y, x + w, y + h))
        if max(im.size) < 500:
            k = 500 / max(im.size)
            im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
        name = "%s_%s.jpg" % (c["name"], tag)
        im.save(os.path.join(out, name), quality=88)
        im.save(os.path.join(git_out, name), quality=85)
    print("- %s (%s, box %s): crops/%s_before.jpg -> crops/%s_after.jpg" % (c["name"], c["file"], c["box"], c["name"], c["name"]))
