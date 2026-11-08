class_name GTTheme
extends RefCounted
## Builds the aggressive red Theme used by every Control: chamfered vector buttons / panels, red sliders.

static func build() -> Theme:
	var t := Theme.new()
	var normal := Drawables.box("btn_normal", 18, 1.0, 14)
	var hover := Drawables.box("btn_hover", 18, 1.0, 14)
	var on := Drawables.box("btn_on", 18, 1.0, 14)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", on)
	t.set_stylebox("hover_pressed", "Button", on)
	t.set_stylebox("disabled", "Button", normal)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", Pal.TEXT)
	t.set_color("font_disabled_color", "Button", Pal.MUTED)
	t.set_font_size("font_size", "Button", 17)
	t.set_constant("h_separation", "Button", 10)
	# OptionButton shares the button frames
	for s in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(s, "OptionButton", t.get_stylebox(s if s != "pressed" else "pressed", "Button"))
	t.set_color("font_color", "OptionButton", Pal.TEXT)
	t.set_color("font_hover_color", "OptionButton", Pal.TEXT)
	t.set_color("font_pressed_color", "OptionButton", Pal.TEXT)
	t.set_color("font_hover_pressed_color", "OptionButton", Pal.TEXT)
	t.set_color("font_focus_color", "OptionButton", Pal.TEXT)
	# text inputs: dark slab with a red underline
	var field := StyleBoxFlat.new()
	field.bg_color = Color(0.09, 0.03, 0.05, 0.95)
	field.border_color = Pal.RED
	field.border_width_bottom = 3
	field.content_margin_left = 12
	field.content_margin_right = 12
	field.content_margin_top = 10
	field.content_margin_bottom = 10
	for cls in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", cls, field)
		t.set_stylebox("focus", cls, field)
		t.set_stylebox("read_only", cls, field)
		t.set_color("font_color", cls, Pal.TEXT)
		t.set_color("caret_color", cls, Pal.RED_HOT)
		t.set_color("font_placeholder_color", cls, Pal.MUTED)
	# sliders
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.08, 0.1)
	track.set_corner_radius_all(3)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = Pal.RED
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := Drawables.texture("flame", 0.5)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	t.set_icon("grabber_disabled", "HSlider", knob)
	# scrollbars
	var grab := StyleBoxFlat.new()
	grab.bg_color = Pal.RED
	grab.set_corner_radius_all(4)
	var gtrack := StyleBoxFlat.new()
	gtrack.bg_color = Color(1, 1, 1, 0.05)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", gtrack)
	t.set_color("font_color", "Label", Pal.TEXT)
	t.set_font_size("font_size", "Label", 16)
	return t
