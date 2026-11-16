# HSW + Story Bridge, round 12 (16 Nov 2026), cloud render

Critic r11 (~40 %): everything read cold and blue at once, so the cause was the renderer, not the materials.

## Cause and fix (preview.py, shared)
- Blender 5 renamed the Nishita sky: `sky_type = "NISHITA"` raised, and the whole try-block was skipped, so the
  cloud sky had no sun elevation/rotation, air/dust/ozone settings. Now "MULTIPLE_SCATTERING" on Blender 5, and
  `dust_density` -> `aerosol_density`.
- Blender 5's sky is ~3x brighter than 4.5's Nishita, flooding shadows with blue. On Blender 5 only:
  sky strength x0.3 (`MORNING["sky5_k"]`, env SKY5_K), exposure +0.5, view white balance 7000 K.
  Calibrated against the PC r10 renders: p06 mean chroma now matches the PC (0.326/0.351/0.323 vs
  0.327/0.350/0.323). p09 is still a touch bluer (the sky gradient itself differs).
- Blender 4.x (PC) path unchanged.

## Model changes
- Crest slabs cream (0.85, 0.78, 0.60), balcony bands warm off-white (0.86, 0.82, 0.70).
- River: grazing sky-reflection factor 0.35 -> 0.22 (less mirror).

## Run
Same as round 11 (HSW_TAA=8, scale=0.5). Full set ~150 min, over the 2 h background limit: render heroes and
photos in two runs. Fits unchanged.

## Still open (critic r11)
Deck/pile zone under Felons/HSW/Percival's ~half the photo height (p12); second underside bracing layer;
p07 straight band y 780-800; Fiume ~300 px right in p09/p12 (1 critic); cliff ochre streaks and ledges;
hotel charcoal/taupe/white cubes; dark recessed balconies on the slabs.
