# Spire area, round 09 (cloud, Cycles)

Builder: cloud session, 16 Nov 2026. Merged HSW r12 (da87d42; preview.py change is Blender 5 only, this scene renders
with bpy 4.5). Same renderer as rounds 7-8.

## Fixes (round 8 critique)
1. **Mantra crest**: now a wedge attached to the SE roof corner. The 0.9 m corner line widens to 5.5 m (3-4 bays) at
   the roof line over the top 26 m (8-9 floors), with its corner edge fixed, leaning out only 1.2 m. Nothing stands
   above the roof. The sign is one clean white "mantra" on a flat blue panel 2.3 m out from the NE face; balcony
   slabs no longer cut through the letters. Body a step warmer (F0DCB2).
2. **Foliage** (`pixel_kill` in area_hero.py): the build casts a 10 x 10 grid of rays through every critic box in
   the real render camera (render_area's own camera code, so pairs, Commons views and heroes all line up) and
   removes every tree within 3.5 m of a tree hit: 178 spots this round. Then the round 8 checks clear remnants.
   Trees inside the keep-out zone are left alone (Willahra fork, orient_front right-hand dots).
3. **Skies per photo**: cobalt for cathedral_forecourt / west_front_2010 / the forecourt hero, navy for
   spire_ann_st_2018, pale blue with thin cloud for orient_front and ann_queen_corner.
4. **Cathedral stone**: palette widened with the mean kept (about 30 % grey-violet #7d7380 blocks, some buff
   #a08a68), dressings sandstone #c4ae86.
5. **Orient**: hip roof lowered to about 25 deg; walls warm tan (D6B488).
6. **Neighbours**: Admiralty peach-pink #e2b9a0; Willahra's accent / band no longer orange.
7. **Ann St road patch**: probed face by face at 11:30. Both sides of the step are the same `roads` material with
   no shadow on either; the faces belong to two overlapping ribbons tilted about 3 deg apart. The road shaders
   now use a world-up normal. The patch is still visible after that, so it is not the tilt either: still open.

## Not done yet
Stepped crown at the Mantra top; Orient upper verandah band, shutters and the billboard (the billboard is not covered
by John's keep-out exception); lawler Art Deco building; Ann/Queen arrows + hatching; car park asphalt; 3 worst
camera fits; Deanery cliff and the faceted hill at the Customs House; a V trunk at the far end of carpark_eye.
