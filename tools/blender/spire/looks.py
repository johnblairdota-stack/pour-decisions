"""Facade recipes (step 7a). Named buildings follow docs/spire/materials_from_photos.md (the cloud side's
photo research) and my own Google image look-ups the same day; everything is read-off values (colours,
patterns, bands, frames). No image is downloaded or copied: every texture is procedural.

A recipe:
  shader   brick | ashlar (mottled stone) | render | glass  - base material
  wall     base colour (hex or rgb);  glass  window/vision glass colour
  pattern  curtain | strip | punched | balcony | fins | none  - window grid on the facade UVs
  band     colour of slab-edge / balcony bands (geometry), balcony: white_solid | glass | None
  accent   vertical strip colour;  roof  parapet / roof colour;  extras: dome, spike, crown,
           ground (ground-floor band colour), pilasters, cornice, awning, verandah
"""
import hashlib


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) / 255 for i in (0, 2, 4))


SHEET = "docs/spire/materials_from_photos.md"

LOOKS = {
    # ---------------------------------------------------------------- cathedral precinct (heritage)
    186247884: {"name": "Webber House", "src": SHEET, "shader": "brick", "wall": hx("a5563b"), "roof": hx("6a6e74"),
                "glass": hx("2c3038"), "pattern": "punched", "cornice": True},
    106225770: {"name": "The Deanery", "src": SHEET, "shader": "ashlar", "wall": hx("a98a6a"), "roof": hx("b8bcbe"),
                "glass": hx("2c3038"), "pattern": "punched", "verandah": hx("efe9dc")},
    106225768: {"name": "Church House", "src": SHEET, "shader": "brick", "wall": hx("9b4a36"), "roof": hx("d8cfb8"),
                "glass": hx("2c3038"), "pattern": "punched", "ground": hx("e2d8c0"), "cornice": True},
    # ---------------------------------------------------------------- Ann St
    189779542: {"name": "The Manhattan", "src": SHEET, "shader": "render", "wall": hx("d9cba8"), "roof": hx("cfc2a0"),
                "glass": hx("30353a"), "pattern": "punched", "pilasters": True, "cornice": True},
    189779622: {"name": "Metropolis", "src": SHEET, "shader": "render", "wall": hx("f0efea"), "roof": hx("e0dfda"),
                "glass": hx("3a4650"), "pattern": "balcony", "band": hx("f4f3ee"), "balcony": "white_solid"},
    189779640: {"name": "The New Yorker", "src": SHEET, "shader": "brick", "wall": hx("8a4532"), "roof": hx("9a9a96"),
                "glass": hx("2a2e33"), "pattern": "punched", "cornice": True},
    186586595: {"name": "Orient Hotel (560 Queen St)", "src": "Google: Orient Hotel Ann Street Queen Street Brisbane",
                "shader": "render", "wall": hx("e3d1a2"), "roof": hx("6b8585"), "glass": hx("2c3038"),
                "pattern": "punched", "verandah": hx("efe9dc")},
    # ---------------------------------------------------------------- Queen St towers
    26253098: {"name": "Willahra Tower", "src": SHEET, "shader": "glass", "wall": hx("f2f1ec"), "glass": hx("6f8496"),
               "roof": hx("e6e5e0"), "pattern": "balcony", "band": hx("f4f3ee"), "balcony": "white_solid",
               "accent": hx("b8402e")},
    568836537: {"name": "Mantra on Queen", "src": SHEET, "shader": "render", "wall": hx("d8ccb4"), "glass": hx("3f5f62"),
                "roof": hx("cfc3ab"), "pattern": "balcony", "band": hx("f0ede4"), "balcony": "glass",
                "accent": hx("2f8a86"), "spike": True},
    189779738: {"name": "Mantra on Queen podium", "src": SHEET, "shader": "render", "wall": hx("d8ccb4"),
                "glass": hx("3f6f90"), "roof": hx("cfc3ab"), "pattern": "strip", "ground": hx("a8553f")},
    26253094: {"name": "Brisbane Marriott", "src": SHEET, "shader": "render", "wall": hx("e2dccb"), "glass": hx("6fa59a"),
               "roof": hx("d6cfbd"), "pattern": "strip", "dome": hx("7fa898")},
    26386571: {"name": "Admiralty Towers I", "src": SHEET, "shader": "render", "wall": hx("e0d4bc"), "glass": hx("6fa59a"),
               "roof": hx("d6cab0"), "pattern": "balcony", "band": hx("efe8d8"), "balcony": "white_solid",
               "ground": hx("c9a67c")},
    26386543: {"name": "Admiralty Towers II", "src": SHEET, "shader": "render", "wall": hx("e0d4bc"), "glass": hx("6fa59a"),
               "roof": hx("d6cab0"), "pattern": "balcony", "band": hx("efe8d8"), "balcony": "white_solid",
               "ground": hx("c9a67c"), "dome": hx("a9c9b6")},
    224320345: {"name": "Macrossan Residences", "src": SHEET, "shader": "render", "wall": hx("c8a678"), "glass": hx("9a8a5a"),
                "roof": hx("bfa070"), "pattern": "strip", "band": hx("d8bf86")},
    236155564: {"name": "Skyline", "src": SHEET, "shader": "glass", "wall": hx("f2f2f0"), "glass": hx("4e6478"),
                "roof": hx("3a3d42"), "pattern": "curtain", "band": hx("f2f2f0"), "balcony": "glass",
                "accent": hx("3a3d42"), "crown": True},
    44173034: {"name": "Aurora Tower", "src": SHEET, "shader": "glass", "wall": hx("f0f0ee"), "glass": hx("34404e"),
               "roof": hx("3a3f46"), "pattern": "curtain", "band": hx("f0f0ee"), "balcony": "glass",
               "accent": hx("c06a3a"), "crown": True},
    26387267: {"name": "480 Queen", "src": SHEET, "shader": "glass", "wall": hx("f2f2f2"), "glass": hx("3c6ea8"),
               "roof": hx("c9b48c"), "pattern": "curtain", "band": hx("f2f2f2"), "ground": hx("c9b48c"),
               "under_construction_2016": True},
    26253545: {"name": "Customs House", "src": SHEET, "shader": "ashlar", "wall": hx("cdb48a"), "roof": hx("b9a47c"),
               "glass": hx("2c3038"), "pattern": "punched", "dome": hx("6f9b86"), "cornice": True, "pilasters": True,
               "stone_palette": [hx("cdb48a"), hx("c4aa80"), hx("d6bf96")]},
    # ---------------------------------------------------------------- my own look-ups (not in the sheet)
    219610201: {"name": "Bellagio (455 Adelaide St)", "src": "Google: Bellagio 455 Adelaide Street Brisbane",
                "shader": "render", "wall": hx("3d3d42"), "glass": hx("8c9aa2"), "roof": hx("4a4a50"),
                "pattern": "balcony", "band": hx("3d3d42"), "balcony": "glass"},
    26325937: {"name": "Republic Apartments", "src": "Google: Republic Apartments 363 Turbot Street Brisbane",
               "shader": "render", "wall": hx("e4e4e0"), "glass": hx("3a4a56"), "roof": hx("b8b8b4"),
               "pattern": "balcony", "band": hx("f0f0ec"), "balcony": "glass", "accent": hx("db7333")},
    219606223: {"name": "545 Queen St", "src": "Google: 545 Queen Street Brisbane building", "shader": "glass",
                "wall": hx("dfe3e3"), "glass": hx("4d8589"), "roof": hx("a8acac"), "pattern": "strip", "band": hx("e8ecec")},
    224320346: {"name": "Soleil", "src": "Google: Soleil Brisbane 485 Queen Street tower", "shader": "glass",
                "wall": hx("ededed"), "glass": hx("2b3038"), "roof": hx("40424a"), "pattern": "fins", "accent": hx("c42828")},
    26253030: {"name": "Oracle (340 Adelaide St)", "src": "Google: Oracle apartments Brisbane Adelaide Street towers",
               "shader": "glass", "wall": hx("c7d1d6"), "glass": hx("478ca8"), "roof": hx("9aa0a6"), "pattern": "curtain"},
}
for dup, orig in ((236155562, 236155564), (186248014, 26253030), (186424546, 44173034)):
    LOOKS[dup] = LOOKS[orig]

PATTERNS = {   # window grid per pattern (facade UVs, metres): bay, window width, sill/head (fractions of a floor)
    "curtain": {"bay": 1.5, "win": 1.38, "sill": 0.30, "head": 0.97, "rough": 0.06, "floor": 3.7},
    "strip":   {"bay": 1.5, "win": 1.45, "sill": 0.35, "head": 0.85, "rough": 0.08, "floor": 3.1},
    "punched": {"bay": 3.0, "win": 1.1, "sill": 0.30, "head": 0.78, "rough": 0.15, "floor": 3.6},
    "balcony": {"bay": 3.0, "win": 2.6, "sill": 0.02, "head": 0.86, "rough": 0.08, "floor": 3.1},
    "fins":    {"bay": 1.2, "win": 1.05, "sill": 0.02, "head": 0.99, "rough": 0.06, "floor": 3.1},
    "none":    None,
}

# generic recipes for unnamed buildings, by OSM use + measured height (end of the sheet)
GENERIC = {
    "lowrise_brick":  {"shader": "brick", "wall": hx("94503a"), "roof": hx("8c8c88"), "glass": hx("2c3038"),
                       "pattern": "punched", "cornice": True, "awning": True},
    "lowrise_render": {"shader": "render", "wall": hx("e2d6bc"), "roof": hx("a8a8a2"), "glass": hx("2c3038"),
                       "pattern": "punched", "cornice": True, "awning": True},
    "house":          {"shader": "render", "wall": hx("f0ece2"), "roof": hx("9aa0a4"), "glass": hx("2c3038"),
                       "pattern": "punched"},
    "precast_80s":    {"shader": "render", "wall": hx("ddd3bf"), "roof": hx("cfc6b2"), "glass": hx("5f8f8a"),
                       "pattern": "strip", "band": hx("e9e2d2")},
    "modern_res":     {"shader": "glass", "wall": hx("f0f0ee"), "roof": hx("5a5e64"), "glass": hx("3f5566"),
                       "pattern": "balcony", "band": hx("f2f2f0"), "balcony": "glass"},
    "office":         {"shader": "glass", "wall": hx("b9c2c8"), "roof": hx("8a9096"), "glass": hx("3d6078"),
                       "pattern": "curtain", "spandrel": hx("2a3a48")},
    "church":         {"shader": "ashlar", "wall": hx("b8a07e"), "roof": hx("6a6e74"), "glass": hx("2c3038"),
                       "pattern": "none"},
}


def stable(osm, k=100):
    return int(hashlib.md5(str(osm).encode()).hexdigest(), 16) % k


def look_for(osm, tags, height_m, family):
    """Named recipe if researched, else a generic one from use + height. Returns (key, recipe)."""
    if osm in LOOKS:
        return "look_%d" % osm, LOOKS[osm]
    b = tags.get("building", "yes")
    if b in ("church", "cathedral", "chapel") or family == "heritage":
        return "gen_church" if b in ("church", "cathedral", "chapel") else "gen_lowrise_render", \
            GENERIC["church"] if b in ("church", "cathedral", "chapel") else GENERIC["lowrise_render"]
    if b in ("house", "detached", "semidetached_house", "terrace", "bungalow"):
        return "gen_house", GENERIC["house"]
    if height_m <= 16:
        k = "lowrise_brick" if stable(osm) < 55 else "lowrise_render"
        return "gen_" + k, GENERIC[k]
    if b in ("office", "commercial", "government", "public") or (height_m > 45 and b == "yes" and stable(osm) < 60):
        return "gen_office", GENERIC["office"]
    if height_m > 45:
        return "gen_modern_res", GENERIC["modern_res"]
    return "gen_precast_80s", GENERIC["precast_80s"]


CATHEDRAL = {"src": SHEET,
             "ashlar": [hx("b48c84"), hx("c8ad8a"), hx("9a8d8f"), hx("a98a6a"), hx("7a6260")],
             "dressing": hx("d8c39c"), "tile": hx("b5553a"), "tile_dark": hx("8f4430"),
             "slate": hx("4a4a50"), "spire_slate": hx("3d3f46"), "leadlight": hx("2c3038")}

SPIRE_LOOK = {"src": SHEET, "dark": hx("2a2d31"), "frame": hx("e8e6e0"), "podium_brick": hx("7d5a45"),
              "battens": hx("a0703f"), "planted": hx("4f7a3a"), "shopfront": hx("3a4a52")}
