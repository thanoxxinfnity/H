extends SceneTree
## Rasterises the SVG drawables into the PNG launcher icons Android needs.
## Run: godot --headless --path . --script res://tools/make_icons.gd
func _init() -> void:
	var jobs := {"app_icon": ["main_192", 192], "icon_fg": ["fg_432", 432], "icon_bg": ["bg_432", 432]}
	for src in jobs:
		var svg := FileAccess.get_file_as_string("res://assets/drawables/%s.svg" % src)
		var img := Image.new()
		var px: int = jobs[src][1]
		var base := 512.0 if src == "app_icon" else 432.0
		if img.load_svg_from_string(svg, px / base) != OK:
			push_error("svg failed: " + src)
			continue
		img.save_png("res://assets/icons/%s.png" % jobs[src][0])
		print("wrote ", jobs[src][0], " ", img.get_size())
	quit()
