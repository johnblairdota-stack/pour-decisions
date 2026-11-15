# Spire scene: material sheet from photos (step 7a)

Looked up 14 Nov 2026 in Google Images (reference only: nothing downloaded, nothing copied into textures).
All textures must be procedural or hand-made in Blender from these notes: colour, pattern, spacing.
Colours are sRGB hex estimates from daylight photos; tune by eye in the morning look.

## Rule changes from step 6

1. **No generic window grid on heritage or masonry buildings.** The step 6 window pass put an apartment
   grid on the cathedral (it reads as a block of flats). Each named building below gets its own facade
   recipe; unnamed buildings keep the generic pass, picked by era/use (see the end).
2. Facades are built from three layers: base material (brick / render / stone / glass), a
   procedural pattern (bond, ashlar, mullion grid, balcony bands), and real geometry where it is
   bigger than the 2-px rule at the hero cameras (balcony slabs, fins, arches, parapets, cornices).
3. Glass towers need reflection, not paint: glass shader with a dark tint + sky reflection,
   spandrel bands as geometry.

## Hero landmark: St John's Cathedral (Ann St, OSM way 26384715)

Rebuild cathedral.py as real Gothic Revival parts, not a box with windows.

- **Plan:** Latin cross. West front (twin spires) faces the Ann St lawn; confirm the end with the 2018 aerial and LiDAR spire heights. Nave with lower aisles,
  transepts, a square crossing tower, apse/chancel at the east end (the oldest part, 1906-10).
- **Stone:** mottled random-coursed ashlar of Brisbane tuff (porphyry): blocks of pink-mauve
  (#b48c84), buff (#c8ad8a), grey-lilac (#9a8d8f), warm tan (#a98a6a), a few darker purple-brown
  (#7a6260). Block size about 0.6 x 0.3 m, staggered. Dressings (mouldings, arches, buttress caps,
  pinnacles, string courses, tracery) in paler Helidon sandstone: cream-buff #d8c39c. West front
  (finished 2009) is slightly fresher/paler than the 1906 east end.
- **Roofs:** terracotta tile, orange-red #b5553a with weathered darker patches (#8f4430), on the nave,
  aisles, transepts and chancel. Steep pitch (~55 deg). The aisles have a **row of small cross gables,
  one per bay**, each with its own gable end and window, not one lean-to.
- **Crossing tower:** square, stone, ~2 storeys above the nave ridge, belfry lancets on each face,
  corner pinnacles, **dark slate pyramid roof** #4a4a50.
- **West towers (pair):** square lower stages with angle buttresses stepping in, upper stages turning
  octagonal with tall paired lancet belfry openings, a ring of pinnacles round the base of each spire,
  then **tall octagonal spires in dark grey slate** (#3d3f46) with 2-3 thin pale stone bands near the
  top and a small cross / finial.
- **West front between the towers:** three deep pointed-arch portals at street level (dark recesses,
  clustered shafts, steps up), an arcade band of small blind arches above, then one huge recessed
  pointed-arch window (5-light tracery with a rose in the head), then a steep central gable with a
  small rose/trefoil and pinnacles each side.
- **Sides:** buttresses at every bay with stepped offsets and pinnacle caps; flying buttresses over the
  aisles to the clerestory; pointed lancet windows (pairs) in the aisles and clerestory with dark
  leadlight glass (#2c3038) and cream stone surrounds.
- **Grounds:** grass lawn and cathedral square on the Ann St side, mature trees.

## Cathedral precinct neighbours

- **Webber House** (439 Ann St, 2 storeys + steep roofs): red-orange face brick #a5563b in English bond
  with cream stone dressings, pointed Gothic door arch, **steep gables in grey slate** #6a6e74 with
  a lighter diamond pattern band, small dormers.
- **The Deanery** (2 storeys): rubble-stone walls of mixed tuff (buff/rust/grey, rough coursed),
  wide cream-painted timber verandahs both floors with white balustrade and posts, **hipped
  corrugated iron roof** (pale grey #b8bcbe) with gable dormers, tall brick chimney.
- **Church House** (417 Ann St, 3 storeys): red face brick #9b4a36 upper floors, cream render ground
  floor with round-arched openings, cream render string courses, window surrounds and parapet with
  small gables at the top.

## Ann St neighbours (NW face of Spire)

- **The Manhattan** (436 Ann St, 3 storeys): cream/buff render #d9cba8, pilasters between bays, top
  floor windows with arched heads and keystones, multi-pane white-framed windows, flat parapet with
  cornice. Former warehouse.
- **Metropolis** (446 Ann St): 6-storey podium in white render with stacked balconies (white solid
  balustrades + glass), behind it a slim white tower with rounded balcony ends. Neighbour at
  460 Ann (**The New Yorker**): 4-5 storey red-brown face brick warehouse, white-painted window
  frames with segmental arch heads, rendered sills.

## Queen St towers round Spire

- **Spire itself (correct the step 6 look):** the tower reads DARK from the street: charcoal/near-black
  glass and dark recessed balconies (#2a2d31) with a bright **white frame lattice** (#e8e6e0)
  outlining irregular, staggered rectangles: frames vary in width so the face looks woven. Step 6 had
  beige spandrels; make the infill dark. Podium: Ann St side is the sloped brown face-brick wall
  (#7d5a45, stretcher bond); Queen St side has vertical timber battens (#a0703f) and a planted wall
  above a glass shopfront.
- **Willahra Tower** (540 Queen, 25 lvl, immediately SE): rounded-end oval tower, every floor a
  white curved slab edge + white solid balustrade, blue-grey glass behind (#6f8496), one vertical red
  accent strip; podium white/grey render with red panels.
- **Mantra on Queen** (570 Queen, 30 lvl): cream concrete (#d8ccb4), stacked rounded balconies with
  white rails, one vertical blue-green glass slot full height, tall thin spike on the roof. Podium:
  beige render with terracotta brick panels (#a8553f), curved blue glass atrium, blue metal blade.
- **Marriott** (515 Queen, hotel, 96 m): cream precast #e2dccb with aqua-green glass bays
  (#6fa59a), copper-green dome cap on top, red "Marriott" sign high on the face.
- **Admiralty Towers I and II** (35 Howard / 501 Queen, riverfront): cream-beige concrete with
  aqua-green tinted glass bands, rounded corners, curved balconies, II has a pale green dome crown.
  Sandstone-coloured podium (#c9a67c).
- **Macrossan Residences** (483 Queen, 37 lvl): warm tan #c8a678 with gold-tinted horizontal bands.
- **Skyline** (30 Macrossan, 47 lvl): slender, grey-blue glass (#4e6478) with thin white
  horizontal balcony bands, dark grey vertical blades, open frame crown on top.
- **Aurora Tower** (420 Queen, 69 lvl): dark blue-grey glass with white horizontal balcony bands,
  one copper-orange vertical strip (#c06a3a) up the curved face, crown at the top.
- **480 Queen** (office, under construction in 2016): blue reflective glass in stacked offset boxes,
  white horizontal fins, sandstone podium, green planted terraces. In the 2016 scene: core + upper
  floors open, tower crane.
- **Customs House** (399 Queen, 1889): sandstone #cdb48a, Corinthian colonnade, **green copper dome**
  #6f9b86.

## Generic recipes for unnamed buildings (pick by OSM tags + height)

- **Pre-1940, 1-4 storeys:** red/brown face brick or cream render, punched windows with arched or
  flat heads, parapet + cornice, timber awning over the footpath on Queen/Ann St.
- **1980-2000 towers:** cream/beige precast with tinted green/blue glass bands, rounded balconies.
- **2000-2016 towers:** dark or blue glass with white slab-edge bands and glass balustrades.
- **Offices:** curtain wall grid 1.5 m mullions, 3.7 m floors, spandrel bands darker than vision glass.

## Not yet looked up (generic recipe for now)

Bellagio / The Hudson (Adelaide St), 545 + 549 Queen, 560 Queen (Johnny Ringo's), Collin House,
Riverplace, Soleil, Oracle, 444 Queen, Republic, Spring Hill Marketplace.
