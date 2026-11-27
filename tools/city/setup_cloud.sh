#!/usr/bin/env bash
# One setup for the Brisbane model in a cloud session: one Blender version for every thread.
#   tools/city/setup_cloud.sh            # makes the venv at $CITY_VENV (default /tmp/city-venv)
# Then:  $CITY_VENV/bin/python tools/blender/spire/render_pairs.py tools/city/showcase/pairs.json out only=<id>
# Blender runs in the cloud only, never on John's PC (it crashed the PC and it halves the game's fps).
set -euo pipefail
VENV="${CITY_VENV:-/tmp/city-venv}"
BPY="${CITY_BPY:-4.5.*}"       # the version the showcase pairs were rendered with; change it here and nowhere else
PY="${CITY_PY:-3.11}"
need="libegl1 libegl-mesa0 libgl1-mesa-dri libgles2 libxkbcommon0 libxi6 libxxf86vm1 libxfixes3 libxrender1 libsm6"
missing=""
for p in $need; do dpkg -s "$p" >/dev/null 2>&1 || missing="$missing $p"; done
if [ -n "$missing" ]; then
  (apt-get update -qq && apt-get install -y -qq $missing) || echo "could not install:$missing (renders may still work)"
fi
if [ ! -x "$VENV/bin/python" ]; then
  if command -v uv >/dev/null 2>&1; then uv venv --python "$PY" "$VENV"; else "python$PY" -m venv "$VENV"; fi
fi
if command -v uv >/dev/null 2>&1; then
  uv pip install --python "$VENV/bin/python" "bpy==$BPY" numpy pillow scipy
else
  "$VENV/bin/python" -m pip install -q "bpy==$BPY" numpy pillow scipy
fi
"$VENV/bin/python" -c "import bpy; print('Blender', bpy.app.version_string, 'ready in', '$VENV')"
