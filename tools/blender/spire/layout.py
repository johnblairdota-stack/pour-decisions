"""Spire master layout. Every other Spire script imports this file.

Frame (all numbers in metres):
  origin  = centre of Spire's footprint (mean of OSM way 186586603's corners)
  +x      = east, +y = north (MGA zone 56 grid; grid north is within 0.02 deg of true north here)
  z       = metres AHD (Australian Height Datum, about mean sea level)

Real data lives in reference/sites/spire/ (made by prep_data.py). This file only
holds the frame, the loaders and the few things a person placed by hand
(crane, hoist, truck gate, camera spots), each with a note saying why.

Pure Python + numpy. No bpy here, so it also runs outside Blender.
"""
import gzip
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
REF = os.path.join(REPO, "reference", "sites", "spire")
DOCS = os.path.join(REPO, "docs", "spire")

# ---------------------------------------------------------------- frame
ORIGIN_MGA56 = (503046.57, 6962279.05)        # easting, northing of the origin
ORIGIN_LATLON = (-27.4630417, 153.0308272)    # same point, GDA94/WGS84 (Nominatim for the OSM way)
DATA_HALF = 400.0     # reference data covers x, y in [-400, 400] (an 800 m square)
MODEL_HALF = 400.0    # the blockout covers the same square
# 2019 LiDAR products cover a wider box (local metres x0, y0, x1, y1) so the Story Bridge, Howard Smith
# Wharves and the Kangaroo Point cliffs are in: see prep_lidar.py and reference/sites/spire/lidar/.
LIDAR_BOX = (-600, -900, 1000, 500)

# ---------------------------------------------------------------- Spire itself
SPIRE = {
    "osm_way": 186586603,
    "name": "Spire Residences",
    "address": "550 Queen Street, Brisbane City",
    "height_m": 131.1,          # OSM height tag = plant top (147.7 AHD, LiDAR) minus lowest ground (16.3, Clark Lane)
    "top_ahd_lidar": 147.7,     # 2019 LiDAR: top of the roof plant/lift overrun
    "levels_pt_slabs": 43,      # suspended post-tensioned slabs (John's build notes)
    "pours_per_level": 2,
    "transfer_slab_level": 6,
    "transfer_slab_thick_m": 1.25,
    "builder": "Hutchinson Builders",
    "engineer": "ADG",
    "completed": "2017-06",
}

# ---------------------------------------------------------------- Spire massing (step 2)
# Tower plate traced from the architect's "Typical Floor Plan" (my_photos/spire/Spire-Residences floor
# plan.jpg, NOT in git): pixel points, image 1414 x 1000, y down. Scale bar 0-10 m = 115 -> 333 px.
# Slab edge (outer line, balconies included), clockwise from the top-left.
TOWER_PLAN = {
    "px": [(300, 128), (400, 112), (500, 118), (600, 124), (700, 124), (800, 118), (900, 110), (960, 108),
           (1020, 140), (1060, 200), (1100, 260), (1150, 330), (1190, 400), (1225, 450), (1240, 500),
           (1230, 560), (1200, 620), (1160, 680), (1110, 740), (1050, 790), (980, 830), (900, 860),
           (800, 880), (720, 892), (650, 878), (580, 850), (500, 810), (420, 770), (350, 730), (290, 690),
           (245, 640), (215, 580), (205, 500), (215, 420), (235, 330), (255, 250), (275, 180)],
    "core_px": (555, 365, 860, 560),        # lift + stair core box (x0, y0, x1, y1)
    "px_per_m": 25.5,             # scale bar reads 21.8 px/m, but the 2018 roof is ~16% smaller: fitted
    # Plan +x (the straight top edge) runs along Ann St, 40.5 deg from east. Checked on the roof plan
    # vs aerial_2018: pool on the E side, plant on the NW side, pointed corner to the S.
    "rotation_deg": 43.0,          # step 4: major axis of the 2019 LiDAR roof cells (was 40.5 from the aerial)
    # Where the plate's centroid sits in the local frame: roof centroid read from aerial_2018_site160m
    # (lean of the roof ignored, OSM outlines of the neighbours sit on their roofs too). Tuned by overlay.
    "centre_xy": (0.0, 4.6),       # step 4: centroid of the 2019 LiDAR roof cells (true 3D, no lean)
}
# Levels. Facts (John's notes): 43 suspended PT slabs, 2 pours each, L6 = 1250 mm transfer slab.
# Not from drawings (rough, from the podium elevations and the OSM height): podium top ~11.5 m over
# Ann St; ground floor 4.5 m; L1-L6 3.2 m; typical floor-to-floor solved so the roof slab lands at
# the OSM height. Flagged in the metadata as solved, not measured.
LEVELS = {
    "ground_floor_m": 4.5,
    "podium_ftf_m": 3.2,
    "podium_levels": 5,            # step 4: LiDAR podium roof 36-40 m AHD = L5; tower plate from L6 (the transfer) up
    "transfer_level": 6,
    "slab_m": 0.20,                # typical PT slab
    "transfer_m": 1.25,
    # step 6: 40 storeys above ground (GF + L1..L38 + the roof storey), tower floor to floor 2.9 m from the
    # L6 transfer up. The roof slab RF (= L39) lands at 138.0 m AHD, inside the LiDAR roof band (deck
    # 135-137.5, parapets 140-142). John's 43 PT slabs = L1..L39 (39) + the 4 extra slabs below, labelled.
    "top_level": 38,
    "tower_ftf_m": 2.9,
    "roof_slab_ahd": 136.0,        # LiDAR roof deck, for reference (RF is solved from tower_ftf_m)
    "extra_pt_slabs": [            # the rest of John's 43: roof/plant/basement slabs (heights assumed)
        {"name": "PLANT", "kind": "plant", "above_rf_m": 3.5, "note": "roof plant deck"},
        {"name": "LMR", "kind": "plant", "above_rf_m": 7.0, "note": "lift motor room / overrun roof (plant top 147.7 LiDAR)"},
        {"name": "B1", "kind": "basement", "above_rf_m": None, "below_gf_m": 3.2, "note": "basement level 1 (assumed)"},
        {"name": "B2", "kind": "basement", "above_rf_m": None, "below_gf_m": 6.4, "note": "basement level 2 (assumed)"},
    ],
    "parapet_m": 1.2,
}

# Core (step 3): its own element, NOT part of any slab pour. Cast in a climbing jump form ahead of the
# slabs; the slabs are poured round it later. Square and plumb (same box every level) so the lifts run.
CORE = {
    "wall_m": 0.30,               # assumption (typical residential core wall)
    "lifts": 3,                   # three lift cars along the south side of the core on the plan
    "overrun_m": 3.5,             # lift overrun above the roof slab
    "jump_form": {
        "type": "unknown: no public source names the system for Spire. Modelled as a generic "
                "self-climbing core jump form (screen-enclosed rig, 3 working decks).",
        "lead_levels": 3,         # core top this many levels above the working deck (brief: 2-4)
        "rig_levels": 2,          # the rig hangs over this many levels of finished core wall
        "rig_out_m": 1.2,         # deck/screen stand-off round the core walls
    },
    "source": "Core box from the typical floor plan; jump-form lead from common Australian practice "
              "(core 2-4 levels ahead). Spire-specific system not found in public sources.",
}
# Pour joint (step 3): two pours a level split by a construction joint made of two short lines, one on
# each side of the core, from the core face to the slab edge. ASSUMPTION: about a third of the span
# from the west (Ann St / Clark Lane) end, across the plan's short axis, the same on every level.
# Not on a column line (columns unknown). Pour A = the west third, pour B = the rest.
JOINT = {
    "plan_px_x": 600,             # plan x of the joint (plate 205..1240 px, core 555..860 px)
    "assumption": True,
    "note": "Not shown in any photo or drawing we have. Change plan_px_x to move it.",
}
# Podium (step 3): the Ann St face is a sloped brick wall (NW podium elevation + John's Ann St photos):
# set back at the footpath, leaning out to the boundary at the top.
PODIUM = {
    "top_level": "L05",                                   # step 6: podium L1-L5 (LiDAR)
    "ann_st_corners": ((-28.53, 3.74), (-3.48, 25.09)),   # OSM lot vertices on Ann St
    "ann_st_setback_at_ground_m": 3.0,                    # read off the NW elevation (glass line under the brick)
    "source": "NW podium elevation drawing + photo 'street view Ann st 1' (John, not in git)",
    "lobby_t": [(0.05, 0.68), (0.74, 0.97)],          # glazing under the brick, west corner -> north (NW elevation)
}

# ---------------------------------------------------------------- construction stages
# A stage turns the finished tower back into a site. build_all.build_all(stage="2016_l6").
STAGES = {
    "2016_l6": {
        "name": "Mid-2016: L6 transfer slab on the deck",
        "evidence": "aerial_2016_site160m_0p1m.jpg: frame up a few levels, formwork deck, crane mast top "
                    "next to the west corner (matches the brief's L6 transfer stage).",
        "deck_level": 6,          # working deck (formwork up, pour in progress)
        "deck_pours_done": ["A"], # pour A of the deck is poured, B is still formwork + reo
        "props_levels_below": 3,  # backprops stay in this many levels under the deck (transfer slab)
        "screen_levels": 2,       # edge screens cover the deck and this many levels below
        "screen_above_deck_m": 2.0,
        "column_grid_m": 8.0,     # ASSUMPTION: columns on an 8 m grid inside the plate (no structural drawings)
        "crane_over_core_m": 14.0,
        "hoarding_m": 2.4,
        # 2016 aerial: a long white strip over the Ann St footpath from past the west corner to the north
        # end = a B-class gantry with site sheds on top (the 2015 ground sheds are under the podium now).
        "gantry": {"from_t": -0.15, "to_t": 1.0, "out_m": 2.2, "width_m": 3.4, "clear_m": 3.2,
                   "shed_m": (3.0, 6.0), "evidence": "aerial_2016_site160m_0p1m.jpg, white strip along Ann St"},
    },
}
# Howard Smith Wharves features (step 6). Positions estimated from John's photos + OSM; flagged.
HSW = {
    "hotel_way": 679146305,                       # Crystalbrook Vincent (OSM)
    "mr_percivals": {"centre_xy": (482.0, 40.0), "size_m": (30.0, 20.0), "angle_deg": 0.0, "deck_ahd": 3.6,
                     "roof_m": 4.2, "source": "OSM point + RESEARCH.md (20 x 30 m deck between the bridge pylons)"},
    "lift_towers": [{"xy": (600.0, 92.0), "face_deg": -90.0, "top_ahd": 39.0, "cliff_top_xy": (600.0, 121.0),
                     "photo": "hb-m-hsw-shoot2-2", "note": "position estimated (cliff base, under the cliff top path)"}],
}
STAGES["2017_top"] = dict(STAGES["2016_l6"], name="2017: tower near the top, crane still up",
                          evidence="John's fly-by photos 'crane placement' 2 and 3 (almost complete)",
                          deck_level=36, deck_pours_done=["A"], props_levels_below=2)
STAGES["hsw_2017"] = {
    "site": "hsw", "name": "HSW mid-build, late 2017",
    "evidence": "John's HSW photos (2017 aerials, construction 6/9/19, 2018-07) + RESEARCH.md",
    "dig_depth_m": 6.0,                           # ASSUMPTION: one basement level + footings
    "crane_xy": (432.0, 96.0), "crane_height_m": 45.0, "crane_jib_deg": 200.0,   # west of the hotel, clear of the bridge
    "shed_e_way": 679146315,                      # Felons Barrel Hall: over-water shed east of the bridge pier (photo 19)
    "shed_lift_m": 1.5,
}
# Plant on the 2016 deck and at the gate (step 3). Shapes are blockout, sizes from maker data sheets
# (rounded): Schwing KVM 26 static placing boom, ~26 m reach, 4-section; Putzmeister BSA 2109 HD
# trailer line pump, ~6.6 x 2.2 x 2.5 m.
PLANT = {
    "booms": [
        {"id": "boom_A", "model": "Schwing KVM 26", "pour": "A", "plan_px": (360, 500), "reach_m": 26.0,
         "slew_deg": 230.0, "note": "ASSUMPTION: one boom per pour area, on a pedestal through the deck"},
        {"id": "boom_B", "model": "Schwing KVM 26", "pour": "B", "plan_px": (1010, 520), "reach_m": 26.0,
         "slew_deg": 40.0, "note": "ASSUMPTION: see boom_A"},
    ],
    "line_pump": {"model": "Putzmeister BSA 2109 HD", "size_m": (6.6, 2.2, 2.5),
                  "note": "inside the Ann St gate, rear (hopper) to the kerb for the agitators"},
    "pipe_m": 0.25,               # drawn thicker than the real 125 mm line so it reads
}

# Default road widths (kerb to kerb, metres) by OSM highway class when the way has no width/lanes tag.
ROAD_WIDTH = {"primary": 14.0, "secondary": 12.0, "tertiary": 10.0, "secondary_link": 7.0,
              "tertiary_link": 7.0, "unclassified": 7.0, "residential": 7.0, "service": 4.5,
              "living_street": 5.0, "pedestrian": 6.0, "footway": 2.0, "steps": 2.0, "cycleway": 2.5,
              "path": 2.0}
LANE_WIDTH = 3.3
FOOTPATH_WIDTH = 3.5    # verge each side of a car road (kerb to property line), rough CBD value
KERB_HEIGHT = 0.15
LEVEL_HEIGHT = 3.2      # used only when OSM has levels but no height
DEFAULT_HEIGHT = 12.0   # used when OSM has neither (flagged in metadata)
RIVER_LEVEL_AHD = 0.3   # rough mean water level for the blockout water plane

# ---------------------------------------------------------------- hand-placed site logistics
# Worked out by eye from John's construction photos (my_photos/spire, NOT in git) and the
# 2015-2017 aerials (reference/sites/spire/aerial_*). Positions are the best read, not survey.
# "confidence": high = seen from above in an aerial; medium = clear in a photo, placed by matching;
# low = a guess from one oblique photo.
#
# Street names round the site (OSM): Ann Street runs along the NW face (4 lanes, red bus lane,
# bus stop 5 "F/S Orient Hotel" at (-24, 13)); Queen Street curves past the E face; Clark Lane
# runs along the SW face from Ann St at (-36, 11) to (-15, -14) and on to Queen St.
CRANE = {
    "kind": "external tower crane, tied to the building",
    "mast_xy": (-16.0, 11.5),     # step 7b: middle of the NW (Ann St) face, slightly to the W (photos crane 2 + 3)
    "type": "luffing",            # step 7b: luffing jib (raised red/white lattice jib in both fly-by photos)
    "luff_deg": 65.0,
    "mast_size_m": 2.0,
    "tie_face": "NW (Ann St)",
    "jib_length_m": 45.0,         # rough: the 2017 aerial shows about 31 m of jib lying over the roof
    "counter_jib_m": 14.0,
    "jib_heading_deg": -35.0,     # 2017 aerial: jib pointing SE across the roof (0 = east, CCW +)
    "height_over_roof_m": 18.0,   # rough, from the fly-by photos
    "confidence": "medium",
    "evidence": [
        "aerial_2017_site160m_0p1m.jpg: crane head and cab just off the west corner, jib lies SE over the roof",
        "photo 'construction site fly by almost complete with crane placement 2.jpg' (camera SW, looking NE "
        "up Ann St): blue mast runs the full height at the left (NW/Ann St) edge of the SW face, ties every few floors",
        "photo '... crane placement 3.jpg' (camera N, looking S to the river): mast on the near (NW) face, right-hand end",
    ],
}
HOIST = {
    "kind": "builder's hoist (personnel/materials), mast tied to the face",
    "mast_xy": (-9.5, 18.5),      # NW (Ann St) face, north end, just outside the slab edge
    "car_size_m": (3.2, 1.5),
    "face": "NW (Ann St)",
    "confidence": "low",
    "john": "John does not know where the hoist was (14 Nov 2026). Keep as a placeholder.",
    "evidence": [
        "aerial_2017_site160m_0p1m.jpg: small box sticking out past the roof edge on the NW face, north end "
        "(crop px ~690,615) - reads as a hoist mast top",
        "No photo shows it clearly. Alternative: the dark vertical strip down the middle of the SW face in "
        "'... crane placement 2.jpg' may be the hoist. Ask John.",
    ],
}
TRUCK_GATE = {
    "street": "Ann Street",
    "centre_xy": (-16.0, 14.4),   # middle of the Ann St boundary
    "width_m": 7.0,
    "along_xy": (0.760, 0.650),   # unit vector along the Ann St boundary (west corner -> north corner)
    "facing": "NW",
    "kerb_zone_now": "council 'Loading Zone Commercial Vehicle 20 Min' sign at (-13.5, 21.3) (2026 data)",
    "confidence": "medium",
    "evidence": [
        "photo 'construction site 2015.jpg', April half (camera NW, looking SE): Ann St hoarding along the "
        "near edge, a truck standing just inside it about a third along from the north end",
        "aerial_2015_site160m_0p1m.jpg: two trucks inside the dig close to the Ann St line at about "
        "(-13..-6, 13..17); a truck at the Ann St kerb near the Clark Lane corner",
        "photo 'construction site 2015.jpg', March half: site sheds (3 portables) on the SW (Clark Lane) "
        "boundary near Ann St, so the gate is not on that side",
    ],
}
SITE_SHEDS = {"xy": (-20.0, -4.0), "along_xy": (0.644, -0.767), "count": 3, "size_m": (3.0, 7.0),
              "note": "3 portables along the Clark Lane (SW) boundary, 2015 aerial + March 2015 photo"}
SITE_NOTES = [
    "No photo in my_photos/spire has EXIF GPS; every spot here is read by eye.",
    "Aerials are not true-ortho: tall things lean away from the plane's nadir, so tops sit a few metres off their bases.",
]

# ---------------------------------------------------------------- camera spots for photo matching
# No photo in my_photos/spire has EXIF GPS, so each spot is estimated from what the photo shows
# (which buildings line up). pos/look_at z = metres above the ground at that point.
# lens_mm on a 36 x 24 mm sensor (long side vertical when portrait). shift_y = shift-lens rise
# (camera kept level), as a fraction of the long side, read from where the horizon sits in the photo.
# Orient Hotel = OSM "Johnny Ringo's Country Saloon" (x -3..26, y 21..49); Mantra on Queen (x -8..19,
# y 72..98, 118 m); St John's Cathedral (x -111..-50, y -132..-66).
CAMERAS = [
    {"id": "cam_ann_queen_corner", "photo": "Spire-Residences opposite corner intersection of Ann and Queen st.jpg",
     "pos": (92.0, 160.0, 1.6), "look_at": (0.0, 0.0, 1.6), "lens_mm": 24.0, "portrait": True, "shift_y": 0.32,
     "note": "Canon 5D3 at 24 mm (EXIF), shift lens. Orient Hotel dead in front of Spire, St John's spires just "
             "right of Spire (camera must sit on the side where y > 1.52 x), Mantra on Queen close on the right, "
             "Spire about a third of the frame high (~190 m away). Best fit: the Ann St junction NE of the Orient."},
    {"id": "cam_ann_far", "photo": "Spire-Residences futher away on ann st.jpg",
     "pos": (150.0, 203.0, 1.7), "look_at": (0.0, 0.0, 1.7), "lens_mm": 45.0, "portrait": True, "shift_y": 0.30,
     "note": "On Ann St about 250 m NE, looking SW down the road; Orient Hotel at the road's end just right of "
             "Spire, Mantra on Queen on the right. Lens from Spire filling ~2/3 of the frame height."},
    {"id": "cam_ann_footpath", "photo": "Spire-Residences street view Ann st 1.jpg",
     "pos": (-8.0, 30.0, 1.6), "look_at": (-70.0, -60.0, 1.6), "lens_mm": 28.0, "portrait": True, "shift_y": 0.20,
     "note": "Ann St, SE kerb, at the north end of Spire's podium, looking SW: sloped brick podium on the left, "
             "Clark Lane heritage roofs and St John's Cathedral ahead to the right of the road."},
    {"id": "cam_queen_st", "photo": "spire-residences street view Queens st 1.JPEG",
     "pos": (52.0, -30.0, 1.7), "look_at": (0.0, 5.0, 1.7), "lens_mm": 24.0, "portrait": True, "shift_y": 0.30,
     "note": "Queen St, east kerb south of the bend, looking NW at the Queen St face of Spire (spot estimated)."},
    {"id": "cam_flyby_crane", "photo": "Spire-Residences construction site fly by almost complete with crane placement 2.jpg",
     "pos": (-120.0, -150.0, 330.0), "look_at": (0.0, 0.0, 60.0), "lens_mm": 50.0, "portrait": True,
     "shift_y": 0.0, "show_logistics": True,
     "note": "Aerial fly-by during the build (crane up): camera high to the SW looking NE up Ann St, steeply "
             "down. Used to check the crane and hoist spots, so the logistics markers are shown."},
]
# Views of the 2016 stage (no photo of this exact moment; spots chosen to show the site).
STAGE_CAMERAS = [
    {"id": "stage_flyby_sw", "pos": (-120.0, -150.0, 160.0), "look_at": (-3.0, 2.0, 25.0), "lens_mm": 50.0,
     "portrait": False, "note": "high to the SW looking NE up Ann St (like the fly-by photos)"},
    {"id": "stage_deck_nw", "pos": (-70.0, 85.0, 115.0), "look_at": (0.0, 4.0, 22.0), "lens_mm": 35.0,
     "portrait": False, "note": "over Ann St from the NW: gate, pump, gantry, booms on the deck"},
]
# Story Bridge (step 5): measured from the 2019 LiDAR bridge points (bridge_hsw voxels). t = metres along
# the axis (+ to the south / Kangaroo Point), n = metres across (+ east). Heights m AHD.
STORY_BRIDGE = {
    "centre_xy": (491.5, -182.2), "axis": (-0.0083, -0.99997),
    "truss_centre_n": -3.5, "truss_half_m": 10.5,
    "truss_t": (-395.0, 165.0),               # north anchor end .. south anchor end (truss length 560 m)
    "main_piers_t": (-255.0, 25.0),           # main span 280 m between the main piers (published: 282 m)
    "suspended_span_t": (-185.0, -45.0),
    "panel_m": 14.0,
    "top_chord_profile": [(-395, 42.0), (-255, 80.0), (-185, 53.0), (-115, 49.5), (-45, 53.0), (25, 80.0), (165, 44.0)],
    "deck_profile": [(-485, 33.0), (-395, 34.0), (-255, 35.5), (-115, 36.5), (25, 35.5), (115, 32.5), (200, 30.5),
                     (280, 28.5), (360, 26.5), (430, 24.5), (500, 22.5), (600, 20.5), (700, 19.5)],
    "deck_t": (-485.0, 700.0),                # north approach (Fortitude Valley) .. south approach (Kangaroo Pt)
    "approach_span_m": 40.0,
    "light_spacing_m": 30.0,
    "measured_from": "2019 LiDAR: 20 m bins along the axis; main piers where points reach the water, "
                     "top chord = max height, deck = 10th percentile height",
}
# Landmark views (step 4). Matching photos (John's, not in git) named where one exists.
HERO_CAMERAS = [
    {"id": "hero_bridge_hsw", "pos": (520.0, -170.0, 80.0), "look_at": (600.0, 70.0, 12.0), "lens_mm": 24.0,
     "portrait": False, "photo": "my_photos/hsw/hb-m-howardsmithwharves-aerial-2017-06-june-lowres-jpg.jpg",
     "note": "over the river SW of HSW, looking NE at the wharf strip (y 50-100), the cliffs and the bridge's north end"},
    {"id": "hero_hsw_lift_tower", "pos": (600.0, 62.0, 1.7), "look_at": (600.0, 112.0, 14.0), "lens_mm": 24.0,
     "portrait": True, "shift_y": 0.15, "photo": "my_photos/hsw/hb-m-hsw-shoot2-2-lowres-jpg.jpg",
     "note": "HSW lawn looking up at the cliff (corten lift tower in the photo; spot estimated)"},
    {"id": "hero_cathedral", "pos": (-15.0, -35.0, 30.0), "look_at": (-80.0, -100.0, 12.0), "lens_mm": 35.0,
     "portrait": False, "photo": "my_photos/spire/Spire-Residences street view Ann st 1.jpg (spires in the distance)",
     "note": "raised view from the NE (over Ann St by Spire) down onto St John's Cathedral"},
]
HERO_CAMERAS.append({"id": "hero_cathedral_street", "pos": (-38.0, -62.0, 1.7), "look_at": (-80.0, -100.0, 1.7),
                     "lens_mm": 24.0, "portrait": True, "shift_y": 0.28,
                     "photo": "Google: St John's Cathedral Brisbane Ann Street exterior (Wikipedia view)",
                     "note": "cathedral grounds, NE of the church, looking SW up at the towers"})
HERO_CAMERAS.append({"id": "hero_cathedral_west_front", "pos": (-124.0, -48.0, 1.7), "look_at": (-101.0, -75.0, 1.7),
                     "lens_mm": 24.0, "portrait": True, "shift_y": 0.30,
                     "photo": "materials_from_photos.md: west front from the Ann St lawn",
                     "note": "Ann St kerb by the lawn, looking SE at the west front and the twin spires"})
HERO_CAMERAS.append({"id": "cam_ann_st_precinct", "pos": (-82.0, -27.0, 1.7), "look_at": (-30.0, 20.0, 7.0),
                     "lens_mm": 24.0, "portrait": False,
                     "photo": "materials_from_photos.md: Church House, Webber House, The Manhattan, Metropolis",
                     "note": "Ann St near the cathedral looking NE towards Spire: precinct on the right, Manhattan/Metropolis left"})
HERO_CAMERAS.append({"id": "hero_spire_roof", "pos": (-40.0, -70.0, 260.0), "look_at": (0.0, 4.0, 138.0),
                     "lens_mm": 40.0, "portrait": False, "photo": "fly by view 2 (top-down) + roof pool photos",
                     "note": "high over the SW, looking down at Spire's roof: pool, cabana, plant box, railing"})
HERO_CAMERAS.append({"id": "street_ann_queen", "pos": (62.0, 96.0, 1.6), "look_at": (30.0, 50.0, 3.0),
                     "lens_mm": 24.0, "portrait": False, "note": "Ann/Queen/Boundary junction at eye height, looking SW"})
HERO_CAMERAS.append({"id": "street_ann_cathedral", "pos": (-52.0, -10.0, 1.6), "look_at": (-110.0, -60.0, 3.0),
                     "lens_mm": 24.0, "portrait": False, "note": "Ann St outside the cathedral at eye height, looking SW"})
HERO_CAMERAS.append({"id": "hero_spire_green_wall", "pos": (52.0, 10.0, 1.7), "look_at": (20.0, 2.0, 9.0),
                     "lens_mm": 24.0, "portrait": True, "shift_y": 0.15, "note": "Queen St kerb: Spire podium battens and green wall"})
HERO_CAMERAS.append({"id": "hero_cathedral_lawn", "pos": (-128.0, -40.0, 1.7), "look_at": (-95.0, -78.0, 6.0),
                     "lens_mm": 24.0, "portrait": False, "note": "Ann St edge of the cathedral lawn, looking at the west front"})
HERO_CAMERAS.append({"id": "hero_spire_facade", "pos": (-62.0, 38.0, 24.0), "look_at": (-4.0, 6.0, 45.0),
                     "lens_mm": 35.0, "portrait": True,
                     "photo": "my_photos/spire/Spire-Residences street view Ann st 1.jpg + fly-by photos",
                     "note": "across Ann St, raised: staggered slab edges, frames, balustrades, brick podium, lobby"})
# Brisbane ~06:45 AEST, clear autumn morning (mid April): sun ~10 deg up, bearing ~80 deg (just N of E).
MORNING = {"sun_azimuth_deg": 80.0, "sun_elevation_deg": 10.0, "sun_strength": 4.5, "sun_colour": (1.0, 0.88, 0.74),
           "sky_strength": 0.25, "haze_dust": 2.0, "haze_density": 0.0, "exposure": -0.3,
           "note": "06:45 AEST mid-April, Brisbane (27.5 S): approximate sun position; physical sky + light haze"}
TOP_VIEW = {"half": 400.0, "aerial_year": 2016}   # top-down clay overlay: whole 800 m square, 2016 aerial
SITE_VIEW = {"half": 80.0, "aerial_year": 2016}   # close top-down of the site (matches aerial_*_site160m)


# ================================================================ maths
def mga56(lat, lon):
    """GDA94 lat/lon (deg) -> MGA zone 56 easting, northing (m)."""
    a, f = 6378137.0, 1 / 298.257222101
    k0, lon0, fe, fn = 0.9996, math.radians(153.0), 500000.0, 10000000.0
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    phi, lam = math.radians(lat), math.radians(lon)
    N = a / math.sqrt(1 - e2 * math.sin(phi) ** 2)
    T = math.tan(phi) ** 2
    C = ep2 * math.cos(phi) ** 2
    A = math.cos(phi) * (lam - lon0)
    M = a * ((1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256) * phi
             - (3 * e2 / 8 + 3 * e2 ** 2 / 32 + 45 * e2 ** 3 / 1024) * math.sin(2 * phi)
             + (15 * e2 ** 2 / 256 + 45 * e2 ** 3 / 1024) * math.sin(4 * phi)
             - (35 * e2 ** 3 / 3072) * math.sin(6 * phi))
    E = fe + k0 * N * (A + (1 - T + C) * A ** 3 / 6 + (5 - 18 * T + T * T + 72 * C - 58 * ep2) * A ** 5 / 120)
    Nn = fn + k0 * (M + N * math.tan(phi) * (A * A / 2 + (5 - T + 9 * C + 4 * C * C) * A ** 4 / 24
                                              + (61 - 58 * T + T * T + 600 * C - 330 * ep2) * A ** 6 / 720))
    return E, Nn


def to_local(lat, lon):
    E, N = mga56(lat, lon)
    return E - ORIGIN_MGA56[0], N - ORIGIN_MGA56[1]


def to_merc(lon, lat):
    x = lon * 20037508.34 / 180.0
    y = math.log(math.tan((90 + lat) * math.pi / 360.0)) * 20037508.34 / math.pi
    return x, y


def local_to_merc_affine():
    """Affine (2x3) that maps local (x, y) to Web Mercator (EPSG:3857). Fitted on a grid; error < 1 cm
    over the 800 m square."""
    import numpy as np
    lat0, lon0 = ORIGIN_LATLON
    rows, rhs = [], []
    for i in range(-3, 4):
        for j in range(-3, 4):
            lat, lon = lat0 + i * 0.0015, lon0 + j * 0.0015
            x, y = to_local(lat, lon)
            rows.append([x, y, 1.0])
            rhs.append(to_merc(lon, lat))
    sol, *_ = np.linalg.lstsq(np.array(rows), np.array(rhs), rcond=None)
    return sol.T  # 2x3


# ================================================================ loaders (cached)
_cache = {}


def ref(name):
    return os.path.join(REF, name)


def osm():
    """Cropped OSM (raw elements) -> dict with local-metre geometry."""
    if "osm" in _cache:
        return _cache["osm"]
    raw = json.load(gzip.open(ref("osm_spire_800m.json.gz"), "rt", encoding="utf-8"))
    nodes, ways, rels = {}, {}, []
    for el in raw["elements"]:
        t = el["type"]
        if t == "node":
            nodes[el["id"]] = to_local(el["lat"], el["lon"])
        elif t == "way":
            ways[el["id"]] = el
        else:
            rels.append(el)

    def line(w):
        return [nodes[n] for n in w["nodes"] if n in nodes]

    _cache["osm"] = out = {"nodes": nodes, "ways": ways, "rels": rels, "line": line}
    return out


def tag_float(t, *keys):
    for k in keys:
        v = t.get(k)
        if v is None:
            continue
        try:
            return float(str(v).lower().replace("m", "").strip())
        except ValueError:
            pass
    return None


def building_height(t):
    """(height above ground, source) from OSM tags."""
    h = tag_float(t, "height", "building:height")
    if h is not None:
        return h, "osm height"
    lv = tag_float(t, "building:levels")
    if lv is not None:
        return lv * LEVEL_HEIGHT, "osm levels x %.1f m" % LEVEL_HEIGHT
    return DEFAULT_HEIGHT, "default (no tag)"


def dem():
    """DEM crop: (array rows north->south, x0, y0, step). Metres AHD."""
    if "dem" in _cache:
        return _cache["dem"]
    import numpy as np
    hdr = json.load(open(ref("dem_1m.json"), encoding="utf-8"))
    a = np.frombuffer(gzip.open(ref("dem_1m.f32.gz"), "rb").read(), dtype="<f4").reshape(hdr["rows"], hdr["cols"])
    _cache["dem"] = out = (a, hdr["x0"], hdr["y0"], hdr["step"])
    return out


def ground_z(x, y):
    """Ground (m AHD) at local x, y: 2019 LiDAR ground (bilinear) inside LIDAR_BOX, else the old DEM."""
    x0, y0, x1, y1 = LIDAR_BOX
    if os.path.exists(os.path.join(REF, "lidar", "lidar.json")) and x0 + 1 <= x < x1 - 1 and y0 + 1 < y <= y1 - 1:
        g = lidar("ground_smooth")
        c = x - x0 - 0.5
        r = y1 - y - 0.5
        c0, r0 = int(c), int(r)
        fc, fr = c - c0, r - r0
        top = g[r0, c0] * (1 - fc) + g[r0, c0 + 1] * fc
        bot = g[r0 + 1, c0] * (1 - fc) + g[r0 + 1, c0 + 1] * fc
        return float(top * (1 - fr) + bot * fr)
    return ground_z_dem2014(x, y)


def ground_z_dem2014(x, y):
    """Bilinear DEM height (m AHD) at local x, y (QldDem default mix, 2014 LiDAR on land)."""
    a, x0, y0, s = dem()
    c = (x - x0) / s
    r = (y0 - y) / s
    c = min(max(c, 0.0), a.shape[1] - 1.001)
    r = min(max(r, 0.0), a.shape[0] - 1.001)
    c0, r0 = int(c), int(r)
    fc, fr = c - c0, r - r0
    top = a[r0, c0] * (1 - fc) + a[r0, c0 + 1] * fc
    bot = a[r0 + 1, c0] * (1 - fc) + a[r0 + 1, c0 + 1] * fc
    return float(top * (1 - fr) + bot * fr)


def aerial_path(year, kind="800m_0p5m"):
    return ref("aerial_%d_%s.jpg" % (year, kind))


AERIAL_800 = {"half": 400.0, "px": 1600, "m_per_px": 0.5}     # aerial_YYYY_800m_0p5m.jpg
AERIAL_SITE = {"half": 80.0, "px": 1600, "m_per_px": 0.1}     # aerial_YYYY_site160m_0p1m.jpg (upsampled from 0.2 m)


def local_to_aerial_px(x, y, spec=AERIAL_800):
    """Local metres -> (col, row) pixel in a local-frame aerial crop (row 0 = north edge)."""
    return (x + spec["half"]) / spec["m_per_px"], (spec["half"] - y) / spec["m_per_px"]


# ================================================================ Spire massing helpers
# Plan frame (u, v): metres from the plate centroid, u along Ann St (plan +x), v to the NW (plan up).
def plan_uv(px, py):
    cx, cy = _plan_centroid_px()
    s = TOWER_PLAN["px_per_m"]
    return (px - cx) / s, -(py - cy) / s          # image y is down


def uv_to_local(u, v):
    a = math.radians(TOWER_PLAN["rotation_deg"])
    x0, y0 = TOWER_PLAN["centre_xy"]
    return (x0 + u * math.cos(a) - v * math.sin(a), y0 + u * math.sin(a) + v * math.cos(a))


def local_to_uv(x, y):
    a = math.radians(TOWER_PLAN["rotation_deg"])
    x0, y0 = TOWER_PLAN["centre_xy"]
    dx, dy = x - x0, y - y0
    return dx * math.cos(a) + dy * math.sin(a), -dx * math.sin(a) + dy * math.cos(a)


def plan_to_local(px, py):
    """Floor-plan pixel -> local metres (rotated and placed per TOWER_PLAN)."""
    return uv_to_local(*plan_uv(px, py))


def core_uv():
    """Core box in the plan frame: (u0, u1, v0, v1)."""
    x0, y0, x1, y1 = TOWER_PLAN["core_px"]
    (u0, v1), (u1, v0) = plan_uv(x0, y0), plan_uv(x1, y1)
    return u0, u1, v0, v1


def joint_u():
    return plan_uv(JOINT["plan_px_x"], 0)[0]


ACTIVE_STAGE = None   # set by build_all: None = finished building, else a STAGES entry


def stage():
    return ACTIVE_STAGE


def level(n_or_name):
    for lv in spire_levels():
        if lv["n"] == n_or_name or lv["name"] == n_or_name:
            return lv
    raise KeyError(n_or_name)


def core_top_ahd():
    st = spire_stage()
    lv = spire_levels()
    if st is None:
        return lv[-1]["top_ahd"] + CORE["overrun_m"]
    return level(min(st["deck_level"] + CORE["jump_form"]["lead_levels"], lv[-1]["n"]))["top_ahd"]


def ann_st_frame():
    """(unit vector along Ann St boundary, unit outward normal to the street)."""
    (ax, ay), (bx, by) = PODIUM["ann_st_corners"]
    ln = math.hypot(bx - ax, by - ay)
    ex, ey = (bx - ax) / ln, (by - ay) / ln
    return (ex, ey), (-ey, ex)


def _plan_centroid_px():
    pts = TOWER_PLAN["px"]
    a = cx = cy = 0.0
    for i in range(len(pts)):
        (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % len(pts)]
        c = x1 * y2 - x2 * y1
        a += c
        cx += (x1 + x2) * c
        cy += (y1 + y2) * c
    a *= 0.5
    return cx / (6 * a), cy / (6 * a)


def tower_outline():
    return [plan_to_local(*p) for p in TOWER_PLAN["px"]]


def core_outline():
    x0, y0, x1, y1 = TOWER_PLAN["core_px"]
    return [plan_to_local(x, y) for x, y in ((x0, y1), (x1, y1), (x1, y0), (x0, y0))]


def spire_base_ahd():
    """Ground floor level: ground at the middle of the Ann St frontage (main entry side)."""
    return round(ground_z(*TRUCK_GATE["centre_xy"]), 2)


def spire_levels():
    """List of levels, bottom up: name, number, kind, top-of-slab AHD, slab thickness, pours."""
    Lv = LEVELS
    base = spire_base_ahd()
    out = [{"name": "GF", "n": 0, "kind": "ground", "top_ahd": base, "slab_m": 0.3, "pours": 1}]
    z = base + Lv["ground_floor_m"]
    for n in range(1, Lv["transfer_level"] + 1):
        kind = "podium" if n <= Lv["podium_levels"] else ("transfer" if n == Lv["transfer_level"] else "tower")
        out.append({"name": "L%02d" % n, "n": n, "kind": kind, "top_ahd": round(z, 3),
                    "slab_m": Lv["transfer_m"] if kind == "transfer" else Lv["slab_m"], "pours": 2})
        z += Lv["podium_ftf_m"]
    z_t = out[-1]["top_ahd"]
    ftf = Lv["tower_ftf_m"]                                  # step 6: fixed 2.9 m (no longer solved)
    roof = z_t + (Lv["top_level"] - Lv["transfer_level"] + 1) * ftf
    for n in range(Lv["transfer_level"] + 1, Lv["top_level"] + 1):
        z_t += ftf
        out.append({"name": "L%02d" % n, "n": n, "kind": "tower", "top_ahd": round(z_t, 3),
                    "slab_m": Lv["slab_m"], "pours": 2})
    out.append({"name": "RF", "n": Lv["top_level"] + 1, "kind": "roof", "top_ahd": round(roof, 3),
                "slab_m": Lv["slab_m"], "pours": 1})
    for lv in out:
        lv["typical_ftf_solved_m"] = round(ftf, 3)
    return out


def spire_extra_slabs():
    """The rest of John's 43 PT slabs: plant decks over the roof and basement slabs (assumed heights)."""
    lv = spire_levels()
    rf, gf = lv[-1]["top_ahd"], lv[0]["top_ahd"]
    out = []
    for e in LEVELS["extra_pt_slabs"]:
        z = rf + e["above_rf_m"] if e["above_rf_m"] is not None else gf - e["below_gf_m"]
        out.append(dict(e, top_ahd=round(z, 3), slab_m=LEVELS["slab_m"]))
    return out


def spire_stage():
    """The active stage if it is a Spire construction stage (has a deck level), else None (finished)."""
    st = ACTIVE_STAGE
    return st if st and "deck_level" in st else None


def hsw_stage():
    st = ACTIVE_STAGE
    return st if st and st.get("site") == "hsw" else None

# ================================================================ 2019 LiDAR loaders (step 4)
def lidar_header():
    if "lidar_hdr" not in _cache:
        _cache["lidar_hdr"] = json.load(open(os.path.join(REF, "lidar", "lidar.json"), encoding="utf-8"))
    return _cache["lidar_hdr"]


def box_blur(a, r):
    """Mean over a (2r+1) square window (edges clamped), via cumulative sums."""
    import numpy as np
    p = np.pad(a.astype("f8"), r, mode="edge")
    c = p.cumsum(0).cumsum(1)
    c = np.pad(c, ((1, 0), (1, 0)))
    k = 2 * r + 1
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return (s / (k * k)).astype("f4")


def lidar(name):
    """'dsm' | 'ground' (float32 m AHD) | 'class' (uint8) over LIDAR_BOX, rows north->south, 1 m.
    'ground_smooth': the ground with the river pushed under the water and two 5 m box blurs (no cars,
    no noise) - this is what ground_z and the visible ground use (step 5)."""
    import numpy as np
    key = "lidar_" + name
    if name == "ground_smooth":
        if key not in _cache:
            g = lidar("ground").copy()
            cl = lidar("class")
            wet = (((cl == 0) | (cl == 4)) & (g < 3.0)) | (g < 1.0)   # no return / under the bridge / below 1 m AHD
            g[wet] = np.minimum(g[wet], RIVER_LEVEL_AHD - 2.0)
            smooth = box_blur(box_blur(g, 2), 2)
            # step 7a: keep the cliffs crisp - where the raw ground is steeper than 50 deg use a light blur only
            gy, gx = np.gradient(box_blur(g, 1))
            steep = np.degrees(np.arctan(np.hypot(gx, gy))) > 50
            steep = box_blur(steep.astype("f4"), 1) > 0.2
            _cache[key] = np.where(steep, box_blur(g, 1), smooth).astype("f4")
        return _cache[key]
    if key not in _cache:
        h = lidar_header()
        fn, dt = {"dsm": ("dsm_1m.f32.gz", "<f4"), "ground": ("ground_1m.f32.gz", "<f4"),
                  "class": ("class_1m.u8.gz", "u1")}[name]
        raw = gzip.open(os.path.join(REF, "lidar", fn), "rb").read()
        _cache[key] = np.frombuffer(raw, dt).reshape(h["rows"], h["cols"])
    return _cache[key]


def lidar_cell(x, y):
    """(row, col) of the LiDAR cell holding local x, y (clamped)."""
    x0, y0, x1, y1 = LIDAR_BOX
    return (min(max(int(y1 - y), 0), y1 - y0 - 1), min(max(int(x - x0), 0), x1 - x0 - 1))


def lidar_voxels(name):
    """(int32 N x 3 voxel indices, box [E0, N0, Z0, E1, N1, Z1, size]) for a hero box."""
    import numpy as np
    h = lidar_header()["voxels"][name]
    raw = gzip.open(os.path.join(REF, "lidar", "vox_%s.i32.gz" % name), "rb").read()
    return np.frombuffer(raw, "<i4").reshape(-1, 3), h["box_mga"]


def lidar_building_heights():
    """{osm way id: height above ground (m)} from building_heights.csv."""
    import csv
    if "bh" not in _cache:
        with open(os.path.join(REF, "lidar", "building_heights.csv"), encoding="utf-8") as f:
            _cache["bh"] = {int(r["osm_way"]): float(r["height_m"]) for r in csv.DictReader(f)}
    return _cache["bh"]


def spire_podium_outline():
    return [tuple(p) for p in json.load(open(os.path.join(REF, "lidar", "spire_podium.json")))["outline_local"]]


def tree_points():
    import csv
    with open(os.path.join(REF, "lidar", "tree_points.csv"), encoding="utf-8") as f:
        return [(float(r["x_local"]), float(r["y_local"]), float(r["height_m"]), float(r["ground_ahd"]))
                for r in csv.DictReader(f)]


def ground_z2019(x, y):
    """2019 LiDAR ground (m AHD) at local x, y; falls back to the old DEM outside LIDAR_BOX."""
    x0, y0, x1, y1 = LIDAR_BOX
    if not (x0 <= x < x1 and y0 < y <= y1):
        return ground_z(x, y)
    r, c = lidar_cell(x, y)
    return float(lidar("ground")[r, c])