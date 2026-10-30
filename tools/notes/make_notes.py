"""Draws the game's Australian banknotes ($5, $10, $20, $50, $100) in the
look of the real polymer notes: each note's colour, its clear top-to-bottom
window with that note's bird, its wattle, a portrait in the note's ink, the
big numerals and the tactile bumps on the edge. They are drawings, not
copies of the real artwork, and they follow the Reserve Bank's rules for
images of banknotes (banknotes.rba.gov.au/legal/reproducing-banknotes):

  * at 100% the image is under three-quarters of the real note's length and
    width at 72 dpi (so each PNG is narrower than 0.75 x length / 25.4 x 72
    pixels and shorter than 0.75 x 65 / 25.4 x 72 = 138 px),
  * the Reserve Bank's name isn't on it.

Run from the repo root (needs Node with Playwright and Chromium):

    python3 tools/notes/make_notes.py

It writes assets/props/notes/note_<value>.png.
"""
import json
import math
import os
import subprocess
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "props", "notes")
H_MM = 65.0
H_PX = 136          # (the rule's limit is 138)

# value: length mm, paper, ink, light tint, bird, wattle note
NOTES = {
    5: {"mm": 130, "paper": "#c9a3d6", "ink": "#6a3d7d", "tint": "#efe2f3", "deep": "#a45fb8", "bird": "spinebill",
        "word": "FIVE DOLLARS", "bumps": 1},
    10: {"mm": 137, "paper": "#8fc3ea", "ink": "#1f4f86", "tint": "#e1f0fb", "deep": "#3b86cc", "bird": "cockatoo",
         "word": "TEN DOLLARS", "bumps": 2},
    20: {"mm": 144, "paper": "#f2a27a", "ink": "#8a2a14", "tint": "#fde6da", "deep": "#e0582c", "bird": "kookaburra",
         "word": "TWENTY DOLLARS", "bumps": 3},
    50: {"mm": 151, "paper": "#f6d56a", "ink": "#7a5a07", "tint": "#fdf3cf", "deep": "#e3ae1c", "bird": "swan",
         "word": "FIFTY DOLLARS", "bumps": 4},
    100: {"mm": 158, "paper": "#9ed39a", "ink": "#1f5e2c", "tint": "#e4f4e2", "deep": "#3e9e4c", "bird": "owl",
          "word": "ONE HUNDRED DOLLARS", "bumps": 5},
}

# The window's bird, drawn in a 20 x 20 box, as a silhouette
BIRDS = {
    # small honeyeater in flight, long curved bill
    "spinebill": "M4 11 Q7 8 10 9 Q12 6 15 5 Q13 8 13 9 Q16 9 19 13 Q15 12 12 12 Q10 14 6 13 L1 15.5 Q3 13 4 11 Z"
                 "M10 9 Q8 7.5 5.5 5 Q8.5 7 10.5 8.4 Z",
    # crested cockatoo on a branch
    "cockatoo": "M7 18 Q5 12 8 8 Q9 5 12 5 Q11 2 13 1 Q13 3 15 2 Q14 4 15 5 Q17 6 17 8 Q16 9.5 15 9 Q15 13 12 17 Z"
                "M3 18.5 H18 V19.5 H3 Z",
    # kookaburra on a branch: big head, heavy bill
    "kookaburra": "M5 17 Q4 11 8 8 Q8 4 12 4 Q15 4 16 6 L19.5 7 L16 8 Q15 10 13 10 Q14 14 11 17 L9 18 L8 20 L7 18 Z"
                  "M2 18.5 H18 V19.5 H2 Z",
    # black swan on water, long neck
    "swan": "M3 15 Q4 11 9 11 Q12 11 13 12 Q12 8 12 6 Q12 3 14.5 3 Q16.5 3 17 5 L19 6 L16.5 6 Q14 6 14.5 9 "
            "Q15 13 13 15 Q9 17 3 15 Z M1 17 Q10 18.5 19 17 V18 Q10 19.5 1 18 Z",
    # masked owl: heart face
    "owl": "M5 18 Q3 12 5 7 Q6 3 10 3 Q14 3 15 7 Q17 12 15 18 Q10 19.5 5 18 Z",
}
OWL_FACE = "M7 7 Q10 5.5 13 7 Q13.5 10 10 12 Q6.5 10 7 7 Z"


def guilloche(w, h, col, n, amp, phase):
    out = []
    for i in range(n):
        y0 = h * (i + 0.5) / n
        pts = []
        for k in range(0, 61):
            x = w * k / 60.0
            y = y0 + amp * math.sin(k / 60.0 * math.tau * 3 + phase + i * 0.7)
            pts.append("%.2f,%.2f" % (x, y))
        out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="0.25" opacity="0.55"/>' % (" ".join(pts), col))
    return "".join(out)


def wattle(x, y, s, col):
    out = ['<path d="M%.1f %.1f q%.1f %.1f %.1f %.1f" stroke="#5b7a2e" stroke-width="0.6" fill="none"/>'
           % (x, y, 4 * s, -3 * s, 9 * s, -2 * s)]
    for i, (dx, dy) in enumerate([(1, -1.2), (2.8, -2), (4.6, -2.5), (6.3, -2.6), (8, -2.3), (2, 0.4), (5, -0.6), (7.4, -0.8)]):
        r = 1.0 * s if i % 2 == 0 else 0.8 * s
        out.append('<circle cx="%.1f" cy="%.1f" r="%.2f" fill="%s"/>' % (x + dx * s, y + dy * s, r, col))
    return "".join(out)


def note_svg(value):
    n = NOTES[value]
    w, h = float(n["mm"]), H_MM
    ink, deep = n["ink"], n["deep"]
    s = []
    s.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %g %g" width="%d" height="%d">'
             % (w, h, round(H_PX * w / h), H_PX))
    s.append('<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
             '<stop offset="0" stop-color="%s"/><stop offset="0.55" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>'
             '<radialGradient id="p" cx="0.5" cy="0.45" r="0.6"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></radialGradient>'
             '</defs>' % (n["tint"], n["paper"], deep, n["tint"], n["paper"]))
    # the paper and its fine line work
    s.append('<rect width="%g" height="%g" rx="2.2" fill="url(#g)"/>' % (w, h))
    s.append(guilloche(w, h, ink, 9, 1.6, value * 0.3))
    # the clear top-to-bottom window, a third of the way in
    wx, ww = w * 0.2, w * 0.13
    s.append('<rect x="%.1f" y="0" width="%.1f" height="%g" fill="#eef6f8" opacity="0.92"/>' % (wx, ww, h))
    s.append('<rect x="%.1f" y="0" width="%.1f" height="%g" fill="none" stroke="%s" stroke-width="0.5" opacity="0.5"/>' % (wx, ww, h, ink))
    bird = BIRDS[n["bird"]]
    bs = ww / 20.0 * 0.95
    s.append('<g transform="translate(%.2f %.2f) scale(%.3f)"><path d="%s" fill="%s" fill-rule="evenodd"/>%s</g>'
             % (wx + ww * 0.025, h * 0.12, bs, bird, ink,
                ('<path d="%s" fill="#f4eee4"/><circle cx="8.8" cy="8" r="0.9" fill="%s"/><circle cx="11.2" cy="8" r="0.9" fill="%s"/>'
                 % (OWL_FACE, ink, ink)) if n["bird"] == "owl" else ""))
    # the value in the window, like the embossed numeral
    s.append('<text x="%.1f" y="%.1f" text-anchor="middle" font-family="Head" font-size="15" fill="none" stroke="%s" stroke-width="0.6">%d</text>'
             % (wx + ww / 2, h * 0.86, ink, value))
    # a sprig of the note's wattle across the window's edge
    s.append(wattle(wx + ww * 0.6, h * 0.64, 1.15, "#f2c624"))
    # the portrait: a head and shoulders in the note's ink, in an oval
    px, py = w * 0.62, h * 0.5
    s.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="url(#p)" stroke="%s" stroke-width="0.4" opacity="0.95"/>'
             % (px, py, h * 0.3, h * 0.4, ink))
    s.append('<g fill="%s" opacity="0.85"><circle cx="%.1f" cy="%.1f" r="%.1f"/>'
             '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z"/></g>'
             % (deep, px, py - h * 0.1, h * 0.12,
                px - h * 0.27, py + h * 0.36, px - h * 0.25, py + h * 0.04, px, py + h * 0.04,
                px + h * 0.25, py + h * 0.04, px + h * 0.27, py + h * 0.36))
    s.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="%s" stroke-width="0.3" stroke-dasharray="0.6 0.5"/>'
             % (px, py, h * 0.33, h * 0.43, ink))
    # numerals: big at the top corner, small at the bottom left
    s.append('<text x="%.1f" y="%.1f" text-anchor="end" font-family="Head" font-size="22" fill="%s">%d</text>'
             % (w - 3.5, 19.5, ink, value))
    s.append('<text x="%.1f" y="%.1f" font-family="Head" font-size="11" fill="%s">%d</text>' % (3.5, h - 4, ink, value))
    s.append('<text x="%.1f" y="%.1f" font-family="Head" font-size="6.2" letter-spacing="0.8" fill="%s">AUSTRALIA</text>'
             % (wx + ww + 3, 8.5, ink))
    s.append('<text x="%.1f" y="%.1f" text-anchor="end" font-family="Body" font-size="3.6" letter-spacing="0.4" fill="%s">%s</text>'
             % (w - 3.5, h - 4, ink, n["word"]))
    # the tactile bumps along the long edge
    for i in range(n["bumps"]):
        s.append('<circle cx="%.1f" cy="%.1f" r="0.9" fill="%s" opacity="0.6"/>' % (w * 0.42 + i * 3.2, h - 2.2, ink))
    s.append('<rect x="0.3" y="0.3" width="%g" height="%g" rx="2" fill="none" stroke="%s" stroke-width="0.6" opacity="0.6"/>'
             % (w - 0.6, h - 0.6, ink))
    s.append("</svg>")
    return "".join(s)


def main():
    os.makedirs(OUT, exist_ok=True)
    fonts = os.path.join(ROOT, "fonts")
    css = ("@font-face{font-family:Head;src:url('file://%s/BarlowCondensed-ExtraBold.ttf')}"
           "@font-face{font-family:Body;src:url('file://%s/Barlow-SemiBold.ttf')}"
           "body{margin:0;background:transparent}svg{display:block;margin-bottom:4px}" % (fonts, fonts))
    jobs = []
    tmp = tempfile.mkdtemp()
    for v in NOTES:
        w_px = round(H_PX * NOTES[v]["mm"] / H_MM)
        limit = 0.75 * NOTES[v]["mm"] / 25.4 * 72
        assert w_px < limit and H_PX < 0.75 * H_MM / 25.4 * 72, v
        page = os.path.join(tmp, "note_%d.html" % v)
        with open(page, "w") as f:
            f.write("<html><head><style>%s</style></head><body>%s</body></html>" % (css, note_svg(v)))
        jobs.append({"page": page, "out": os.path.join(OUT, "note_%d.png" % v), "w": w_px, "h": H_PX})
    js = """
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  for (const j of %s) {
    const p = await b.newPage({ viewport: { width: j.w, height: j.h }, deviceScaleFactor: 1 });
    await p.goto('file://' + j.page);
    await p.evaluate(() => document.fonts.ready);
    await p.locator('svg').screenshot({ path: j.out, omitBackground: true });
    await p.close();
  }
  await b.close();
})();
""" % json.dumps(jobs)
    script = os.path.join(tmp, "render.js")
    with open(script, "w") as f:
        f.write(js)
    subprocess.run(["node", script], check=True, cwd=tmp)
    for j in jobs:
        print(j["out"])


if __name__ == "__main__":
    main()
