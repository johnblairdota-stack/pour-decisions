## Dev: tiles a filmed transition's frames (Godot's --write-movie PNGs) into contact sheets, to read a
## camera move frame by frame.
##   godot --headless --path . -s tools/film_sheet.gd -- <frames dir> <out prefix> [start=0] [step=3] [cols=5] [rows=5] [cell width=384]
extends SceneTree

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		print("film_sheet: <frames dir> <out prefix> [start] [step] [cols] [rows] [cell width]")
		quit(1)
		return
	var start := int(a[2]) if a.size() > 2 else 0
	var step := int(a[3]) if a.size() > 3 else 3
	var cols := int(a[4]) if a.size() > 4 else 5
	var rows := int(a[5]) if a.size() > 5 else 5
	var cw := int(a[6]) if a.size() > 6 else 384
	var files: Array = []
	for f in DirAccess.get_files_at(a[0]):
		if f.ends_with(".png"):
			files.append(f)
	files.sort()
	var picks: Array = []
	var i := start
	while i < files.size():
		picks.append(files[i])
		i += step
	var per := cols * rows
	var n := 0
	while n * per < picks.size():
		var sheet: Image = null
		var ch := 0
		for j in range(n * per, mini(picks.size(), (n + 1) * per)):
			var img := Image.load_from_file(String(a[0]).path_join(picks[j]))
			if img == null:
				continue
			img.convert(Image.FORMAT_RGB8)
			if sheet == null:
				ch = int(round(cw * float(img.get_height()) / img.get_width()))
				sheet = Image.create(cols * cw, rows * ch, false, Image.FORMAT_RGB8)
			img.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
			var k := j - n * per
			sheet.blit_rect(img, Rect2i(0, 0, cw, ch), Vector2i((k % cols) * cw, (k / cols) * ch))
		if sheet != null:
			var out := "%s_%d.jpg" % [a[1], n + 1]
			sheet.save_jpg(out, 0.86)
			print("film_sheet: " + out)
		n += 1
	quit()
