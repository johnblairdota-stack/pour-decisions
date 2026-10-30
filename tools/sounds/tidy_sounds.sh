#!/bin/sh
# Turns the generated mp3s (sound_staging/<folder>/<name>.mp3) into the game's
# sounds/<folder>/<name>.ogg: loops and ambience levelled to the same loudness
# (Ogg so they loop without the gap mp3 leaves), one-shots and footsteps
# trimmed to the hit and peak-levelled. Footsteps too quiet to use are skipped.
#
#   sh tools/sounds/tidy_sounds.sh path/to/sound_staging
set -e
IN=${1:?usage: tidy_sounds.sh sound_staging}
OUT=$(dirname "$0")/../../sounds
for f in "$IN"/amb/*.mp3 "$IN"/loop/*.mp3 "$IN"/sfx/*.mp3 "$IN"/step/*.mp3; do
	[ -f "$f" ] || continue
	folder=$(basename "$(dirname "$f")")
	name=$(basename "$f" .mp3)
	mkdir -p "$OUT/$folder"
	dst="$OUT/$folder/$name.ogg"
	case $folder in
	amb|loop)
		ffmpeg -v error -y -i "$f" -af "loudnorm=I=-20:TP=-2:LRA=7" -ar 44100 -c:a libvorbis -q:a 5 "$dst" ;;
	*)
		peak=$(ffmpeg -hide_banner -i "$f" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \([-0-9.]*\) dB.*/\1/p')
		if [ "$folder" = step ] && [ "$(echo "$peak < -35" | bc)" = 1 ]; then
			echo "skip $folder/$name (peak $peak dB)"; rm -f "$dst"; continue
		fi
		gain=$(echo "-1 - ($peak)" | bc)
		ffmpeg -v error -y -i "$f" -af "silenceremove=start_periods=1:start_threshold=-45dB,volume=${gain}dB,areverse,silenceremove=start_periods=1:start_threshold=-60dB,afade=t=in:d=0.03,areverse" \
			-ar 44100 -c:a libvorbis -q:a 5 "$dst" ;;
	esac
	echo "$folder/$name"
done
