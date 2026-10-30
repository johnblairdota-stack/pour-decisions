"""Turns the Reserve Bank's own pictures of the note fronts into the game's
notes (assets/props/notes/note_<value>.png), inside the Bank's rules for
images of banknotes (banknotes.rba.gov.au/legal/reproducing-banknotes):

  * Electronic images: at 100% the image is under three-quarters of the real
    note's length and width at 72 dpi. All the notes are 65 mm high, so
    under 0.75 x 65 / 25.4 x 72 = 138 px; they're 136 px, and each width is
    under 0.75 x its length in mm / 25.4 x 72 (the $5 276, $10 291, $20 306,
    $50 321, $100 335 px). This script refuses anything bigger.
  * The Bank's name isn't used: the front's signature block (legal tender
    line, both signatures and their titles, which name the Bank) is painted
    out. The Bank's own "SPECIMEN" stamps stay on.
  * The full-size downloads are deleted after use; only the small ones are
    ever kept (in the game folder's .notes_src, then here).
  * Front only: the game shows the front on both faces, never the back's art.

Run:  python3 tools/notes/clean_notes.py SMALL_FRONTS_DIR
where SMALL_FRONTS_DIR holds note_5.png ... note_100.png, each the Bank's
front image already shrunk to 136 px high. Needs opencv-python and numpy.

(tools/notes/make_notes.py draws the older look-alike notes instead.)
"""
import os
import sys

import cv2
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "props", "notes")
MM = {5: 130, 10: 137, 20: 144, 50: 151, 100: 158}
H_MM = 65.0
# The signature block on every front, as fractions of width and height
BLOCK = (0.02, 0.575, 0.29, 0.855)
CORNER = 4  # px: the notes' rounded corners


def limit(mm):
    return 0.75 * mm / 25.4 * 72


def clean(path, value):
    im = cv2.imread(path, cv2.IMREAD_UNCHANGED)
    h, w = im.shape[:2]
    if h >= limit(H_MM) or w >= limit(MM[value]):
        sys.exit("note_%d.png is %dx%d: over the Reserve Bank's size limit" % (value, w, h))
    bgr = im[:, :, :3].copy()
    mask = np.zeros((h, w), np.uint8)
    x0, y0, x1, y1 = BLOCK
    mask[int(y0 * h):int(y1 * h), int(x0 * w):int(x1 * w)] = 255
    out = cv2.inpaint(bgr, mask, 5, cv2.INPAINT_TELEA)
    # (soften the patch so it reads as plain polymer, not smears)
    blur = cv2.GaussianBlur(out, (0, 0), 3)
    m = cv2.GaussianBlur(mask.astype(np.float32) / 255, (0, 0), 1.5)[..., None]
    out = (out * (1 - m) + blur * m).astype(np.uint8)
    # rounded corners
    alpha = np.full((h, w), 255, np.uint8)
    for cx, cy in ((CORNER, CORNER), (w - 1 - CORNER, CORNER), (CORNER, h - 1 - CORNER), (w - 1 - CORNER, h - 1 - CORNER)):
        for y in range(h):
            for x in range(w):
                if (x < CORNER or x > w - 1 - CORNER) and (y < CORNER or y > h - 1 - CORNER):
                    if (x - cx) ** 2 + (y - cy) ** 2 > CORNER * CORNER and abs(x - cx) <= CORNER and abs(y - cy) <= CORNER:
                        alpha[y, x] = 0
    return np.dstack([out, alpha])


def main():
    src = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    for v in MM:
        img = clean(os.path.join(src, "note_%d.png" % v), v)
        dst = os.path.join(OUT, "note_%d.png" % v)
        cv2.imwrite(dst, img)
        print("wrote", dst, img.shape[1], "x", img.shape[0])


if __name__ == "__main__":
    main()
