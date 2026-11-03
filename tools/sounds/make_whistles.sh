#!/bin/sh
# The dogman's trailing and two-peak whistles, cut from the steady long blast
# (sounds/sfx/whistle_long.ogg) so all the blasts sound like the one whistle.
# ElevenLabs' own tries at these came out as two separate blasts.
#   whistle_trail     hoist down: strong, then dying away as the breath runs out
#   whistle_double_N  trolley out: two peaks in one breath (it dips, never stops)
set -e
D=$(dirname "$0")/../../sounds/sfx
L=$D/whistle_long.ogg
ffmpeg -v error -y -ss 0.1 -t 1.4 -i "$L" -af "volume='if(lt(t,0.35),1,exp(-(t-0.35)*2.6))':eval=frame,afade=t=in:d=0.02,afade=t=out:st=1.3:d=0.1" \
	-c:a libvorbis -q:a 5 "$D/whistle_trail.ogg"
n=1
for at in 0.2 0.8; do
	ffmpeg -v error -y -ss $at -t 0.34 -i "$L" -af "volume='1-0.92*exp(-pow((t-0.17)/0.035,2))':eval=frame,afade=t=in:d=0.015,afade=t=out:st=0.3:d=0.04" \
		-c:a libvorbis -q:a 5 "$D/whistle_double_$n.ogg"
	n=$((n + 1))
done
