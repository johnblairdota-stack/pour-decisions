# HSW + Story Bridge, round 18 (17 Nov 2026), cloud render

Critic r17 (~36 %): brightness mostly right, hue is the error; the grazing mix was a grey (0.26,0.31,0.36).
- Water grazing mix now a real sky blue (layout HSW river sky_rgb (0.20,0.36,0.64)).
- River body redder (0.25,0.21,0.12) so red sits above green in p06; specular 0.16 -> 0.10 (smaller sun blob).
Own water means (render vs photo, lower water band): p12 160,163,153 vs 169,184,173; p13 147,158,160 vs
135,152,171; p06 169,163,132 vs 167,152,145 (red now above green).
Not done: shadow-receive test, p07 duplicate-plane check, underside lattice, cliffs, skyline variety, horizon.
Renders done in groups of 2-4 views per run (container restarts).
