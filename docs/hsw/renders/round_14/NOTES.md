# HSW + Story Bridge, round 14 (16-17 Nov 2026), cloud render

Critic r13 (~35 %) traced the decline to the sky: mid-sky in p12 rendered (130,161,188) vs photo (95,157,244).

## Light (preview.py, Blender 5 path only)
- Tested on one p12 render re-saved under several view transforms: AgX (any look) greys the sky on Blender 5;
  Standard view, no look, no white balance, aerosol 0.1 gave mid-sky (118,164,219) and canopy (59,72,62)
  against the photo's (106,163,246) and (60,70,60). Now the Blender 5 default (MORNING sky5_aerosol, env
  SKY5_AEROSOL). The 4.x (PC) path still uses AgX + Medium High Contrast.
- p09/p12/p13 sun at 9:30 on 2019-11-20 (was 11:00): sun in the east, so the bridge shadow lands camera-left on
  the p09 water like the photo.

No material changes this round, so the light change can be judged on its own. Overall the renders are still
darker than the bright midday photos; exposure is the next knob.

Still open: pile forest (taller, 2 m spacing, caps, braces), tuff cliff + canopy variety, hotel relief.
