import shutil
"""Builds the mega showcase page: index.html + img/*.jpg from a manifest (run with the Blender venv python for PIL).

    python build.py [refs_dir]     refs_dir = staged showcase_refs folder (credits.csv + <tower>/<theme>/...)
"""
import csv
import glob
import hashlib
import html
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(HERE, "img")
REPO = "/home/user/pour-decisions"
PF = "/mnt/project-files/visuals"
CM = "/mnt/user-data/uploads/PourDecisions-sites/data/cbd/commons"
SA = PF + "/sites/spire-area/round_16"
HS = PF + "/sites/hsw/showcase/round_19"
RV = REPO + "/docs/screenshots/pick/river"
CE = PF + "/sites/cbd-ext"
SH = PF + "/sites/research-16nov/sheets"
PH = PF + "/photos"

# (path, caption, kind)  kind: photo | render | game | aerial
T = [
 {"id": "riverlight", "name": "Riverlight", "where": "Hamilton Reach, Northshore Hamilton", "facts": "11 levels · Watpac for Frasers · 2016 to 2018", "status": "Playable",
  "area": [],
  "river": [(PH + "/commons_Gateway_Bridge_from_CityCat_Mianjin_Hamilton_Reach_Brisbane_River_P123_26.jpg", "Gateway Bridge from the CityCat, Hamilton Reach", "photo"),
            (PH + "/commons_CityCat_Tugulawa_II_gangplank_deployment_Northshore_Hamilton_Ferry_Ter_19.jpg", "Northshore Hamilton ferry terminal", "photo"),
            (PH + "/commons_Brisbane_River_Bulimba_left_Hamilton_right_Queensland_seen_from_the_ai_28.jpg", "Bulimba left, Hamilton right, from the air", "photo")],
  "top": [(REPO + "/assets/cards/roof_riverlight.jpg", "The view behind the Riverlight card today", "game"),
          (PH + "/commons_Brisbane_River_Bulimba_left_Hamilton_right_Queensland_seen_from_the_ai_29.jpg", "The reach from the air", "photo")],
  "parts": [("Tower", "Two offset wings, white slab edge every floor, charcoal columns, slatted screen up the taller wing", "Built floor by floor. East wing is the playable slab, west wing has its own crew", "built"),
            ("Edge screens", "Blue perimeter screens climbing with the deck (2017 aerial)", "Still to add", "add"),
            ("Tower crane", "One crane mid-building in the 2017 aerial", "Still to add during the build", "add"),
            ("Forecourt", "Wharf timber poles, pool, timber pergolas, Angora Rd driveway under the RIVERLIGHT wall", "Hidden until top-out, then revealed", "hide"),
            ("Street trees", "Council and LiDAR trees along MacArthur Ave and Angora Rd", "Kept clear of both wings and the truck path", "keep"),
            ("Kerb parking", "Parking lanes and No Stopping lines on MacArthur Ave", "Kept. Trucks come in off MacArthur Ave and leave by Angora Rd", "keep"),
            ("Site compound", "Sheds and truck access on the Angora Rd side (2017 aerial)", "Pump yard, slump spot and site kit. Cleared at top-out", "add")],
  "gaps": ["No area photos that show Riverlight itself yet. The four generic Northshore photos were removed; your own street photos are on the PC.", "No photo from the roof or a top-floor apartment to match the card view against."]},
 {"id": "spire", "name": "Spire Residences", "where": "550 Queen St, Petrie Bight", "facts": "40 levels · 2014 to 2017 · two KVM26 booms", "status": "Playable",
  "area": [(SA + "/ann_queen_corner_photo.jpg", "Ann St and Queen St corner", "photo"), (SA + "/ann_queen_corner_render.jpg", "Same corner", "render"),
           (SA + "/orient_front_photo.jpg", "Orient Hotel", "photo"), (SA + "/orient_front_render.jpg", "Orient Hotel", "render"),
           (SA + "/cathedral_forecourt_photo.jpg", "St John's Cathedral forecourt", "photo"), (SA + "/cathedral_forecourt_render.jpg", "Cathedral forecourt", "render"),
           (SA + "/queen_st_willahra_photo.jpg", "Queen St towards Willahra", "photo"), (SA + "/queen_st_willahra_render.jpg", "Queen St towards Willahra", "render"),
           (SA + "/hero_ann_st_streetscape.jpg", "Ann St streetscape", "render")],
  "river": [(RV + "/ref_01.jpg", "Petrie Bight from the river", "photo"), (RV + "/c12_p1.jpg", "The flight today, from the bridge", "game"),
            (RV + "/ref_03.jpg", "River front", "photo"), (RV + "/c12_p3.jpg", "Customs House in the flight", "game"),
            (RV + "/c12_p4.jpg", "Under the Story Bridge", "game"), (SA + "/hero_customs_house_river.jpg", "Customs House from the river", "render")],
  "top": [(RV + "/ref_pool.jpg", "Your photo over the pool edge", "photo"), (REPO + "/assets/cards/roof_spire.jpg", "The view behind the Spire card today", "game"),
          (SA + "/hero_roof.jpg", "Roof", "render")],
  "parts": [("Tower above podium", "Dark glass tower with white frames over a brick podium", "Built from Level 6 up, 34 pours. Jump form sits three levels above the deck", "built"),
            ("Podium brick", "Brick podium on Ann St and Queen St", "Climbs with the early floors", "built"),
            ("Kerb trees", "Street trees along the Ann St and Queen St kerbs", "Removed for the kerbside work zone", "remove"),
            ("Planters", "Footpath planters at the tower base", "Removed", "remove"),
            ("Awning", "Street awning along the frontage", "Removed. A Class B gantry stands in its place", "remove"),
            ("Ground signage", "Building and shop signs at street level", "Removed", "remove"),
            ("Kerbside lane", "One kerb lane on Ann St", "Becomes the truck work zone with barriers", "swap"),
            ("Cranes and booms", "Not there today", "Tower crane at the Clark Lane end, two booms on tube masts in the core", "add"),
            ("Neighbours", "Orient Hotel, Cathedral, Willahra, Admiralty Towers", "Kept. They go see-through for players on the street", "keep")],
  "gaps": ["The pool photo is only 382 x 510. A bigger copy would let the card view be matched properly."]},
 {"id": "hsw", "name": "Howard Smith Wharves", "where": "Under the Story Bridge", "facts": "Hotel and wharf sheds · 2017 to 2019", "status": "Area built in Blender",
  "area": [(HS + "/p10_drone_lawns_se_photo.jpg", "The lawns", "photo"), (HS + "/p10_drone_lawns_se_render.jpg", "The lawns", "render"),
           (HS + "/p09_pier_face_on_photo.jpg", "Pier, face on", "photo"), (HS + "/p09_pier_face_on_render.jpg", "Pier, face on", "render"),
           (HS + "/hero_main_lawn.jpg", "Main lawn", "render"), (HS + "/hero_riverwalk_under_bridge.jpg", "Riverwalk under the bridge", "render")],
  "river": [(HS + "/p12_river_felons_photo.jpg", "Felons from the river", "photo"), (HS + "/p12_river_felons_render.jpg", "Felons from the river", "render"),
            (HS + "/p07_drone_sw_citycat_photo.jpg", "CityCat passing", "photo"), (HS + "/p07_drone_sw_citycat_render.jpg", "CityCat passing", "render"),
            (HS + "/hero_citycat.jpg", "From the CityCat", "render")],
  "top": [(HS + "/p01_drone_se_photo.jpg", "From above, south east", "photo"), (HS + "/p01_drone_se_render.jpg", "From above, south east", "render"),
          (HS + "/hero_wilson_outlook.jpg", "From Wilson Outlook", "render")],
  "parts": [("Hotel", "Crystalbrook Vincent against the cliff", "The pour: built up from the wharf level", "built"),
            ("Wharf sheds", "Heritage sheds: Felons, Rivershed, Mr Percival's pavilion", "Kept as shells. Fit-out, signs and awnings off during the build", "keep"),
            ("Lawns and umbrellas", "Four lawns with outdoor seating and 12 umbrellas", "Become laydown and the pump yard", "swap"),
            ("Trees", "13 mapped trees plus the figs and the protected tree on the cliff", "Cliff trees protected. Lawn planting removed", "protect"),
            ("Street lamps and cameras", "13 lamps and 8 cameras along the riverwalk", "Removed, temporary site lighting instead", "remove"),
            ("Lifts and stairs", "East and West lifts and five stair runs down the cliff", "Not there yet in 2017. Site access is the Boundary St ramp", "hide"),
            ("Ferry terminal", "Opened after the build", "Hidden. Possible barge landing for the play", "hide"),
            ("Riverwalk", "New Farm Riverwalk and cycleway pass the site", "Kept open behind hoarding", "protect"),
            ("Story Bridge", "Overhead, with the Bradfield Hwy", "Kept. It limits crane height", "keep")],
  "gaps": ["No construction-stage photos (2017 to 2018) in the showcase yet."]},
 {"id": "william1", "name": "1 William St", "where": "William St and Alice St, by the Riverside Expressway", "facts": "46 levels · 267 m to the mast · Multiplex · 2013 to 2016", "status": "Data ready",
  "area": [(CM + "/william1/Entrance_to_1_William_Street__Brisbane_01.jpg", "Entrance canopy", "photo"), (CM + "/william1/1_William_Street_front_facade__Brisbane.jpg", "Front facade", "photo"),
           (CM + "/william1/1_William_Street_from_George_St_Brisbane_P1000696.jpg", "From George St", "photo"),
           (CM + "/william1/1_William_Street__Brisbane__under_construction_in_March_2015.jpg", "Under construction, March 2015", "photo"),
           (CM + "/william1/1_William_Street__Brisbane_in_July_2015__03.jpg", "July 2015", "photo"),
           (CM + "/william1/1_William_Street__Brisbane_in_10.2013_01.jpg", "Basement, October 2013", "photo"),
           (SH + "/william1_site_years.jpg", "The site from the air, year by year", "aerial")],
  "river": [(CM + "/william1/1_William_Street__Brisbane__Queensland___CityCat_01.jpg", "From the CityCat", "photo"),
            (CM + "/william1/Brisbane_River_and_1_William_Street_in_April_2019__Brisbane.jpg", "Across the river, April 2019", "photo"),
            ("/tmp/claude-0/cbdr/pairs_current/still_cbd_from_southbank.png", "From the South Bank side", "render"), ("/tmp/claude-0/cbdr/pairs_current/still_riverside_expressway.png", "Riverside Expressway at the tower", "render")],
  "top": [],
  "parts": [("Tower", "Rounded lozenge, blue-grey glass, bronze spandrels, sloped crown and mast", "Split core with two jump systems, three Favco luffers on the core", "built"),
            ("Entrance canopy", "Wide curved glass canopy on William St", "Removed until the end", "remove"),
            ("Ground floor shops", "Cafes, restaurants and a convenience store at the base", "Removed. Hoarding and gates", "remove"),
            ("Kerb parking and loading", "6 parking sign runs and 2 passenger loading zones on William St", "Become the truck bays", "swap"),
            ("Traffic signals and crossings", "4 signals, 4 crossings at William, Alice and Margaret", "Kept, with traffic control", "keep"),
            ("Expressway ramps", "Riverside Expressway and six ramps wrap the site", "Kept and protected. No trucks stop on them", "protect"),
            ("Retaining walls and steps", "5 retaining walls, 7 stair runs down to Queens Wharf Rd", "Kept. Site edge follows them", "keep"),
            ("Waterline Park", "Park and fitness station under the expressway", "Did not exist yet. Hidden", "hide"),
            ("Red perimeter screens", "Red and pink screens round the top floors in the 2015 photos", "Added, climbing with the deck", "add")],
  "gaps": ["Top views are from the upper floors (level 41), not the roof itself.", "Few street-level photos of William St itself."]},
 {"id": "skytower", "name": "Brisbane Skytower", "where": "222 Margaret St", "facts": "90 levels · about 270 m · Hutchinson · 2015 to 2019", "status": "Data ready",
  "area": [(CM + "/skytower/Brisbane_Skytower__Skyrise_entrance__October_2019__01.jpg", "Skyrise entrance", "photo"),
           (CM + "/skytower/Brisbane_Skytower_seen_from_Edward_Street_in_Brisbane__Australia.jpg", "From Edward St", "photo"),
           (CM + "/skytower/222_Margaret_Street__Brisbane_05.2013_209.jpg", "The empty pit, May 2013", "photo"),
           (CM + "/skytower/Brisbane_Skytower_under_construction_May_2016_in_Brisbane.jpg", "May 2016", "photo"),
           (CM + "/skytower/Brisbane_Skytower_under_construction_in_April_2017.jpg", "April 2017", "photo"),
           (CM + "/skytower/Brisbane_Skytower_under_construction_in_March_2018.jpg", "March 2018", "photo"),
           (CM + "/skytower/Liebherr_crane_300T_at_Mary_Street__Brisbane_01.jpg", "Mobile crane on Mary St", "photo"),
           (SH + "/skytower_site_years.jpg", "The site from the air, year by year", "aerial")],
  "river": [(CM + "/skytower/Brisbane_Skytower_seen_from_Kangaroo_Point__Queensland.jpg", "From Kangaroo Point", "photo"),
            ("/tmp/claude-0/cbdr/pairs_current/still_cbd_from_kangaroo_pt.png", "From the Kangaroo Point cliffs", "render"),
            (CM + "/skytower/Brisbane_Skytower_seen_from_the_City_Botanic_Gardens__Brisbane.jpg", "From the Botanic Gardens", "photo")],
  "top": [],
  "parts": [("Tower", "Rounded triangle, deep navy glass, fine horizontal bands", "Jump form on a 4 to 5 day cycle, luffer above it", "built"),
            ("Entrance canopy", "Curved timber-look canopy at the Skyrise entrance", "Removed until the end", "remove"),
            ("Kerb parking", "16 parking sign runs, 7 marked bays on Margaret St", "Become the truck bays", "swap"),
            ("Loading zones", "3 loading zones on Margaret St", "Taken over by the site", "swap"),
            ("Builder hoarding", "Teal and blue hoarding at street level in the build photos", "Added", "add"),
            ("Neighbours", "Westin, Four Points, Oaks on Margaret, River City Apartments", "Kept. 111 Mary St next door is its own site with two cranes", "keep"),
            ("Roof pool", "Pool at the east corner of the roof", "Last pour. It is the card view", "built")],
  "gaps": ["No view from the top.", "No street-level photos along Margaret St before the build."]},
 {"id": "queenswharf", "name": "Queen's Wharf", "where": "George St to the river", "facts": "Six towers · Multiplex · 2018 to 2024 · Sky Deck 100 m up", "status": "Data ready",
  "area": [(CM + "/queenswharf/Construction_of_Queen_s_Wharf__George_Street__Brisbane__Feb_2021__01.jpg", "George St, February 2021", "photo"),
           (CM + "/queenswharf/Construction_of_Queen_s_Wharf__Brisbane__November_2019.jpg", "November 2019", "photo"),
           (CM + "/queenswharf/Construction_of_Queen_s_Wharf__Brisbane_in_May_2020__01.jpg", "May 2020", "photo"),
           (CM + "/queenswharf/North_Quay_below__Queen_s_Wharf__Brisbane__2024__01.jpg", "North Quay below the podium, 2024", "photo"),
           (SH + "/queenswharf_site_years.jpg", "The site from the air, year by year", "aerial")],
  "river": [(CM + "/queenswharf/Neville_Bonner_Bridge__Brisbane_CBD_seen_from_South_Bank__2025.jpg", "From South Bank, 2025", "photo"),
            (CM + "/queenswharf/Neville_Bonner_Bridge__2026.jpg", "Neville Bonner Bridge, 2026", "photo"),
            (CM + "/queenswharf/Brisbane_Sign__Queen_s_Wharf__Brisbane__2024__01.jpg", "The Brisbane sign, 2024", "photo"),
            (CM + "/queenswharf/North_Quay_ferry_wharf__and_Queen_s_Wharf__Brisbane_under_construction__August_2020__01.jpg", "From the ferry wharf, August 2020", "photo"),
            ("/tmp/claude-0/cbdr/pairs_current/still_bridges_south_bank.png", "The reach and its bridges", "render")],
  "top": [],
  "parts": [("Towers", "Star Grand arcs in gold glass, round Dorsett, the Residences", "Hand-built in the model from 2024 and 2025 photos", "built"),
            ("Podium over the expressway", "7 levels spanning the Riverside Expressway", "A pour of its own, over live traffic", "built"),
            ("Heritage buildings", "Harris Terrace, The Mansions, Commissariat Store", "Protected. The site wraps round them", "protect"),
            ("Bus stops", "4 stops on George St and William St", "Relocated", "swap"),
            ("Kerb parking and loading", "38 parking sign runs, 27 marked bays, 7 loading zones", "Taken over by gates and truck bays", "swap"),
            ("Signals and crossings", "14 signals, 15 crossings", "Kept, with traffic control", "keep"),
            ("Bike racks", "4 racks", "Removed", "remove"),
            ("Neville Bonner Bridge", "Opened at the end of the job", "Built late in the play, from a barge", "add"),
            ("Cranes", "9 to 10 red and white luffers in 2020", "Added", "add")],
  "gaps": ["Queen's Wharf is hand-built from photos: the drum flare, fins and podium terraces are still rough.", "Construction photos are kept on the PC as build references, not shown here.", "Tower heights disagree between sources."]},
 {"id": "alcyone", "name": "Alcyone Hotel Residences", "where": "Portside Wharf, Hamilton", "facts": "16 storeys · Hutchinson · 2015 to 2017", "status": "Paused",
  "area": [(SH + "/alcyone_site_years.jpg", "The site from the air, year by year", "aerial")],
  "river": [], "top": [],
  "parts": [("Tower", "Apartments and hotel over retail", "One central tower crane in the 2016 aerial", "built"),
            ("Portside shops", "Portside Wharf retail, IGA, cafes next door", "Kept and open", "keep"),
            ("Kerb parking", "14 parking sign runs on Hercules St", "Truck bays", "swap"),
            ("Street lamps", "7 lamps", "Kept", "keep"),
            ("Crossings and signals", "16 crossings, 4 signals", "Kept, with traffic control", "keep")],
  "gaps": ["You paused this tower. Photos are being collected anyway so it is ready."]},
]
P2 = "/tmp/claude-0/cbdr/pairs_current"
C2 = CM
D2 = "/mnt/user-data/uploads/PourDecisions-sites/showcase_refs"
PAIRS = {
 "spire": [(f, P2 + "/sa_" + os.path.basename(f)[:-10] + ".png", os.path.basename(f)[:-10].replace("_", " ").capitalize()) for f in sorted(glob.glob(SA + "/*_photo.jpg"))],
 "hsw": [(f, P2 + "/hs_" + os.path.basename(f)[:-10] + ".png", os.path.basename(f)[4:-10].replace("_", " ").capitalize()) for f in sorted(glob.glob(HS + "/*_photo.jpg"))],
 "william1": [(C2 + "/william1/1_William_Street__Brisbane__September_2016.jpg", P2 + "/william1_river_2016.png", "From the river, September 2016"),
              (D2 + "/skytower/done/1_William_Street_and_Brisbane_Skytower__June_2019.jpg", P2 + "/william1_emporium_2019.png", "From a South Bank rooftop, June 2019"),
              (D2 + "/queenswharf/done/Queen_s_Wharf__Brisbane_CBD_seen_from_South_Bank__2025__06.jpg", P2 + "/william1_southbank_2025.png", "From South Bank, 2025"),
              (D2 + "/william1/done/Brisbane_CBD_Seen_from_South_Bank_Parklands_at_sunset_2017__01.jpg", P2 + "/william1_sunset_2017.png", "From South Bank Parklands, 2017"),
              (D2 + "/william1/done/Victoria_bridge_and_1_William_Street_in_April_2019__Brisbane.jpg", P2 + "/william1_victoria_2019.png", "Down the river past Victoria Bridge, April 2019")],
 "queenswharf": [(D2 + "/queenswharf/done/Queen_s_Wharf__Brisbane_CBD_seen_from_South_Bank__2025__05.jpg", P2 + "/queenswharf_river_2025.png", "From South Bank, 2025. First hand-built Queen's Wharf model."),
                 (D2 + "/queenswharf/done/Queen_s_Wharf__Brisbane__2025__01.jpg", P2 + "/queenswharf_kurilpa_2025.png", "From upriver, 2025"),
                 (D2 + "/queenswharf/done/Queens_Wharf_from_Abutment.jpg", P2 + "/queenswharf_abutment_2023.png", "From the South Bank abutment, 2023 (towers still going up in the photo)")],
 "skytower": [(C2 + "/skytower/Brisbane_Skytower_under_construction_in_January_2019__Brisbane_01.jpg", P2 + "/skytower_kp_jan2019.png", "From Kangaroo Point, January 2019"),
              (C2 + "/skytower/Brisbane_Skytower_in_June_2019__01.jpg", P2 + "/skytower_kp_2019.png", "From Kangaroo Point, June 2019"),
              (C2 + "/skytower/Brisbane_Skytower_under_construction_in_December_2018.jpg", P2 + "/skytower_kp_dec2018.png", "From Kangaroo Point, December 2018 (nearly topped out)"),
              (D2 + "/skytower/done/Brisbane_Skytower_seen_from_Brisbane_City_Botanic_Gardens__October_2019.jpg", P2 + "/skytower_gardens_oct2019.png", "From the Botanic Gardens, October 2019"),
              (D2 + "/skytower/done/Brisbane_Skytower_and_Skylines_of_Brisbane_CBD_from_Kangaroo_Point__Queensland_01.jpg", P2 + "/skytower_kp_apr2019.png", "Whole skyline from Kangaroo Point, 2019"),
              (D2 + "/skytower/done/Brisbane_CBD_seen_from_Kangaroo_Point__2024__02.jpg", P2 + "/skytower_kp_2024.png", "From the Kangaroo Point cliffs, 2024")],
}
if os.path.exists(os.path.join(HERE, "extra.json")):          # curated photos from the PC download: {"tower/theme": [[path, caption, kind]]}
    _seen = set()
    for key_, rows_ in json.load(open(os.path.join(HERE, "extra.json"))).items():
        tid_, th_ = key_.split("/")
        t_ = next(t for t in T if t["id"] == tid_)
        have_ = {os.path.basename(x[0]) for x in t_["area"] + t_["river"] + t_["top"]}
        t_[th_] = list(t_[th_]) + [tuple(r) for r in rows_ if os.path.basename(r[0]) not in have_]
_NEW = {f.replace("_photo", "_render"): r for k_ in ("spire", "hsw") for f, r, _c in PAIRS[k_]}   # galleries use the current render of a paired view too
for _n in ("ann_st_streetscape", "customs_house_river", "roof"):                 # standalone hero renders: current model too
    _NEW[SA + "/hero_" + _n + ".jpg"] = P2 + "/sah_" + _n + ".png"
for _n in ("main_lawn", "riverwalk_under_bridge", "wilson_outlook", "citycat"):
    _NEW[HS + "/hero_" + _n + ".jpg"] = P2 + "/hsh_" + _n + ".png"
for t_ in T:                                                # the game's high open picture, where its towers are
    if t_["id"] in ("william1", "queenswharf", "skytower", "spire") and os.path.exists(P2 + "/open_high.png"):
        t_["top"] = [(P2 + "/open_high.png", "The game's high open over Brisbane (the picture the game shows)", "render")] + list(t_["top"])
for t_ in T:
    for th_ in ("area", "river", "top"):
        t_[th_] = [(_NEW.get(x[0], x[0]),) + tuple(x[1:]) for x in t_[th_]]
HIDE = json.load(open(os.path.join(HERE, "hide.json"))) if os.path.exists(os.path.join(HERE, "hide.json")) else {}
TOPWEB = os.path.join(os.path.dirname(HERE), "topweb")       # listing and review photos of the view from the top, kept under their published names
CREDIT = {}
if os.path.exists(os.path.join(HERE, "top_web.json")):
    for r_ in json.load(open(os.path.join(HERE, "top_web.json"))):
        p_ = os.path.join(TOPWEB, r_["img"])
        next(t for t in T if t["id"] == r_["tower"])["top"] = list(next(t for t in T if t["id"] == r_["tower"])["top"]) + [(p_, r_["cap"], "photo")]
        CREDIT[p_] = r_["credit"]
if os.path.exists(os.path.join(HERE, "pairs_extra.json")):
    for tid_, rows_ in json.load(open(os.path.join(HERE, "pairs_extra.json"))).items():
        PAIRS.setdefault(tid_, []).extend(tuple(r) for r in rows_)
ACT = {"built": "Built in play", "remove": "Removed", "swap": "Swapped", "add": "Added", "keep": "Kept", "protect": "Protected", "hide": "Hidden"}
THEMES = [("area", "The area", "Streets and ground level round the site."), ("river", "From the river", "What the fly-over passes."),
          ("top", "From the top", "The view behind the tower card.")]
N = [0]


def put(src, tid):
    if not os.path.exists(src):
        return None
    name = "%s_%s.jpg" % (tid, hashlib.md5((src + str(os.path.getmtime(src))).encode()).hexdigest()[:10])
    if src.startswith(TOPWEB):
        name = os.path.basename(src)
        shutil.copy(src, os.path.join(IMG, name))
        im = Image.open(src)
        return "img/" + name, im.width, im.height
    dst = os.path.join(IMG, name)
    im = Image.open(src).convert("RGB")
    if im.width > 1280:
        im = im.resize((1280, round(im.height * 1280 / im.width)), Image.LANCZOS)
    im.save(dst, quality=76, optimize=True)
    return "img/" + name, im.width, im.height


def refs(refs_dir):
    out = {}
    fp = os.path.join(refs_dir or "", "credits.csv")
    if not refs_dir or not os.path.exists(fp):
        return out
    for r in csv.DictReader(open(fp, encoding="utf-8")):
        p = os.path.join(refs_dir, r["file"].replace("/", os.sep))
        cap = r["title"].split(":", 1)[-1].rsplit(".", 1)[0].replace("_", " ")[:80]
        credit = " · ".join(x for x in (r["author"][:40], r["licence"]) if x)
        out.setdefault((r["tower"], r["theme"]), []).append((p, cap, "photo", credit))
    return out


def main():
    os.makedirs(IMG, exist_ok=True)
    for f in os.listdir(IMG):
        os.remove(os.path.join(IMG, f))
    extra = refs(sys.argv[1] if len(sys.argv) > 1 else None)
    counts = {}
    body = []
    for t in T:
        tid = t["id"]
        sec = ['<section class="tower" id="%s"><header class="th"><div><h2>%s</h2><p class="where">%s</p></div>'
               '<p class="facts"><span class="status s-%s">%s</span>%s</p></header>'
               % (tid, html.escape(t["name"]), html.escape(t["where"]), t["status"].split()[0].lower(), t["status"], html.escape(t["facts"]))]
        cmps = []
        for ph, rn, cap in PAIRS.get(tid, []):
            a, b = put(ph, tid), put(rn, tid)
            if not a or not b:
                continue
            counts[(tid, "pair")] = counts.get((tid, "pair"), 0) + 1
            cid = "cmp-%s-%d" % (tid, len(cmps))
            cmps.append('<figure class="cmpf"><div class="cmp" style="aspect-ratio:%d/%d"><img loading="lazy" src="%s" alt="Render: %s"><img loading="lazy" class="top" src="%s" alt="Photo: %s">'
                        '<span class="lab l">Photo</span><span class="lab r">Render</span><input type="range" id="%s" min="0" max="100" value="50" aria-label="Slide between photo and render"></div>'
                        '<figcaption>%s</figcaption></figure>' % (a[1], a[2], b[0], html.escape(cap, True), a[0], html.escape(cap, True), cid, html.escape(cap)))
        sec.append('<div class="theme"><h3>Photo against render <span class="n">%d</span></h3><p class="sub">Same viewpoint. Drag the bar: photo on the left, render on the right.</p>%s</div>'
                   % (len(cmps), ('<div class="cmps">%s</div>' % "".join(cmps)) if cmps else '<p class="empty">No matched viewpoint yet.</p>'))
        for key, title, sub in THEMES:
            items = [(p, c, k, CREDIT.get(p, "")) for p, c, k in t[key]] + extra.get((tid, key), [])
            if key == "area":
                items += extra.get((tid, "build"), [])
            figs = []
            for p, cap, kind, credit in items:
                if any(cap.startswith(x) for x in HIDE.get(tid, [])):      # John 18 Nov: photos taken out of the showcase
                    continue
                if any(p in (x[0], x[1]) for x in PAIRS.get(tid, [])):
                    continue
                r = put(p, tid)
                if not r:
                    continue
                counts[(tid, kind)] = counts.get((tid, kind), 0) + 1
                figs.append('<figure class="k-%s"><button type="button" data-full="%s" aria-label="Open %s"><img loading="lazy" src="%s" width="%d" height="%d" alt="%s"></button>'
                            '<figcaption><span class="tag">%s</span>%s%s</figcaption></figure>'
                            % (kind, r[0], html.escape(cap, True), r[0], r[1], r[2], html.escape(cap, True), kind, html.escape(cap),
                               ('<span class="credit">%s</span>' % html.escape(credit)) if credit else ""))
            sec.append('<div class="theme"><h3>%s <span class="n">%d</span></h3><p class="sub">%s</p>%s</div>'
                       % (title, len(figs), sub, ('<div class="strip">%s</div>' % "".join(figs)) if figs else '<p class="empty">Nothing collected yet.</p>'))
        rows = "".join('<tr><th scope="row">%s</th><td>%s</td><td><span class="act a-%s">%s</span>%s</td></tr>'
                       % (html.escape(a), html.escape(b), d, ACT[d], html.escape(c)) for a, b, c, d in t["parts"])
        sec.append('<div class="theme"><h3>Broken down for the build</h3><p class="sub">Each part of the finished place, and what happens to it while the tower goes up.</p>'
                   '<div class="tablewrap"><table><thead><tr><th>Part</th><th>What is there</th><th>During the build</th></tr></thead><tbody>%s</tbody></table></div></div>' % rows)
        sec.append('<div class="gaps"><h4>Still missing</h4><ul>%s</ul></div></section>' % "".join("<li>%s</li>" % html.escape(g) for g in t["gaps"]))
        body.append("".join(sec))
    nav = "".join('<a href="#%s">%s</a>' % (t["id"], html.escape(t["name"])) for t in T)
    tot = {k: sum(v for (_, kk), v in counts.items() if kk == k) for k in ("photo", "render", "game", "aerial", "pair")}
    page = open(os.path.join(HERE, "head.html"), encoding="utf-8").read()
    page = page.replace("{{NAV}}", nav).replace("{{BODY}}", "\n".join(body)).replace("{{TOWERS}}", str(len(T)))
    for k, v in tot.items():
        page = page.replace("{{N_%s}}" % k.upper(), str(v))
    open(os.path.join(HERE, "index.html"), "w", encoding="utf-8").write(page)
    files = {"img/" + f: "img/" + f for f in sorted(os.listdir(IMG))}
    json.dump(files, open(os.path.join(HERE, "files.json"), "w"))
    print(tot, len(files), "images", sum(os.path.getsize(os.path.join(IMG, f)) for f in os.listdir(IMG)) // 1024, "KB")


if __name__ == "__main__":
    main()
