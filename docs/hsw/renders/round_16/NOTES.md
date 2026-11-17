# HSW + Story Bridge, round 16 (17 Nov 2026), cloud render

Critic r15 (~35 %): lighting has given what it can; water shadows missing because the water was mostly mirror.
- River: opaque olive body (0.20, 0.18, 0.085), roughness 0.16 -> 0.36, specular 0.25 -> 0.12, grazing sky mix
  0.22 -> 0.12 (preview.py). Sun angle 1.6 -> 0.8 deg.
- My own check: the water now reads as an opaque olive body, but p06 still has no lattice shadow in frame. In the
  p06 photo the shadow falls south-west of the bridge (sun north-north-east, late morning); at 9:00 our shadow
  falls due west, off the left edge. p06 sun time is the next thing to try (~11:00). The ripples also got weaker
  with the rougher surface.
Still open: tuff cliff + far plane (green slab p06 x1260-1600 y440-560, runway strips), lattice density,
waterfront facades, p01 shadow wedge.
