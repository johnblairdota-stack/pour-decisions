# HSW + Story Bridge, round 19 (17 Nov 2026), cloud render. LOOP PAUSED after this round (John).

Critic r18 (~41 %, best since r08): water hue moving, flat surface now the main giveaway.
- Fine 25 cm ripple layer (layout HSW river fine_scale 4.0, fine_w 0.35), bump 0.55 -> 0.8.
- River body slightly deeper (0.23, 0.20, 0.105).
- Checked the scene: one water plane only (river_water, 1 quad at 0.3 m AHD, receives shadows; material
  dithered), so the p07 bands are not a duplicate plane - likely Eevee screen-space ray-trace artefacts.

Queued for when the loop resumes (critic r18): p07 bands (try full-res ray tracing or no SSR on water), p01 glare
cap, underside lattice + gussets, tuff relief, cream balconied cliff-top blocks, horizon hills, p06/p12 shadows.
