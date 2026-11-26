# Mega showcase builder

The page at https://claude.ai/artifact/Ca2pMVT3p5RvXCjf4s249K (always publish to that url) is made by
`build.py` from the photo/render pairs. These files lived in the project files folder
(`/mnt/project-files/showcase-mega/`) until 26 Nov 2026; this is now the copy to edit.

- `pairs.json`, `pairs_new.json`, `pairs_old.json`, `pairs_extra.json`: one camera per reference photo
  (format in `tools/blender/spire/render_pairs.py`). The `photo` paths point at John's photos staged from
  his PC (`Documents\PourDecisions-sites\showcase_refs`); photos are never in git.
- `jobA.sh`, `jobB.sh`, `jobC.sh`, `runall2.sh`, `runold.sh`: the full refresh (42 views, about 2.7 hours,
  three background jobs one after another). They still name the old temporary folders
  (`/tmp/claude-0/bl`, `/tmp/claude-0/cbdr`, `/tmp/claude-0/mega`): use the venv from
  `tools/city/setup_cloud.sh` and set the folders to suit. They go away when the tile build lands.
- `open_strips.py`: makes the game's high opening image (`assets/open/brisbane_high.jpg`).
- `extra.json`, `top_web.json`, `hide.json`, `head.html`: page content for `build.py`.
