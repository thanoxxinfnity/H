class_name Drawables
extends RefCounted
## Vector drawables: the SVG files in res://assets/drawables/ are rasterised at runtime at the exact size
## needed (sharp on every screen density). 9-patch SVGs become StyleBoxTexture frames for panels/buttons/tiles.

const DIR := "res://assets/drawables/"
static var _cache := {}

static func texture(drawable: String, scale := 1.0) -> Texture2D:
	var key := "%s@%.2f" % [drawable, scale]
	if _cache.has(key):
		return _cache[key]
	var path := "%s%s.svg" % [DIR, drawable]
	var svg := FileAccess.get_file_as_string(path)
	var img := Image.new()
	if svg == "" or img.load_svg_from_string(svg, scale) != OK:
		# raw SVG not packed into this build: fall back to the importer's raster of the same drawable
		var imported := load(path) as Texture2D
		if imported != null:
			_cache[key] = imported
			return imported
		push_warning("Drawable missing or invalid: " + drawable)
		img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## 9-patch frame from an SVG. `margin` is in SVG pixels at scale 1; `scale` > 1 for dense screens.
static func box(drawable: String, margin: int, scale := 1.0, content := 12) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = texture(drawable, scale)
	var m := int(margin * scale)
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = content
	sb.content_margin_right = content
	sb.content_margin_top = content * 0.6
	sb.content_margin_bottom = content * 0.6
	return sb
