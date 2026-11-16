# Spire area, round 11 (cloud, Cycles)

Builder: cloud session, 16 Nov 2026. Merged HSW r14 (225fa82; preview.py change is Blender 5 only, this scene renders
with bpy 4.5). Same renderer as rounds 7-10.

## Fixes (round 10 critique)
1. **Mantra crest**: compared at 3x zoom with the fly_by_east photo: the wing is a flat blue flag standing straight
   out of the SE corner (in the plane of the east-face normal), widest AT the roof line (5.5 m out, about a quarter
   of the tower width), tapering to the corner 12 m (about 4 floors) down, 0.35 m thick, nothing above the roof.
   The r9-r10 widening wedge and the hanging curved fin are gone.
2. **Mantra sign**: a solid one-storey cream band (#E9DFC8) stands 0.9 m in front of the top floor on the NE face,
   with a single "mantra" text object (#1b5fa8) 1.5 cm proud of it, so no window or balcony can show through.
3. **Cathedral**: the ashlar joints are dark (#4a4440) and recessed (stronger bump), so courses and blocks read as
   stone, not checker; sandstone dressings matt (roughness 0.8) #c4a878; spires near-black #2e2e33; tile roof
   #6e3426 (tile courses kept).
4. **Foliage**: 7 more boxes in `pixel_kill`, each with its own radius; two of them trace through walls (leaves
   seen through the nave wall, the cathedral_grounds nave).
5. **Skies**: ann_st_far gets the deep sky with cumulus; ann_queen_corner a pale dusk gradient (warm pale at the
   horizon to grey-blue).

## Not done yet
Gable shell over the arch; forecourt edge strips (box image size unclear); Admiralty copies; QUEEN ST sign; porch
gap; BUS ONLY; wheel stops; Mantra stepped crown; Orient verandah band; Ann St road patch; arrows/hatching; car
park asphalt; camera fits; Deanery cliff; keep-out trees.
