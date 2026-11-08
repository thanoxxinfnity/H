class_name Icons
extends RefCounted
## Vector "drawables": SVG icons rasterised at runtime at exactly the size you ask for (crisp on any
## screen density, no import step, no PNG assets to ship).

const PATHS := {
	"bolt": '<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>',
	"cpu": '<rect x="6" y="6" width="12" height="12" rx="1.5"/><rect x="9.5" y="9.5" width="5" height="5"/><path d="M9 3v3M15 3v3M9 18v3M15 18v3M3 9h3M3 15h3M18 9h3M18 15h3"/>',
	"ram": '<rect x="3" y="7" width="18" height="9" rx="1.5"/><path d="M7 7v9M11 7v9M15 7v9M6 16v3M10 16v3M14 16v3M18 16v3"/>',
	"gauge": '<path d="M4 18a8 8 0 1 1 16 0"/><path d="M12 18l4-6"/>',
	"thermo": '<path d="M10 14V5a2 2 0 0 1 4 0v9a4 4 0 1 1-4 0z"/>',
	"record": '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="3.2" fill="currentColor"/>',
	"stop": '<rect x="6" y="6" width="12" height="12" rx="2" fill="currentColor"/>',
	"bell_off": '<path d="M6 8a6 6 0 0 1 9-5M18 8c0 5 2 6 2 7H5.5M10 20a2 2 0 0 0 4 0M3 3l18 18"/>',
	"sun": '<circle cx="12" cy="12" r="4"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2"/>',
	"camera": '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
	"sparkle": '<path d="M12 3l2 6 6 2-6 2-2 6-2-6-6-2 6-2z"/>',
	"video": '<rect x="3" y="6" width="13" height="12" rx="2"/><path d="M16 10l5-3v10l-5-3z"/>',
	"close": '<path d="M6 6l12 12M18 6 6 18"/>',
	"layers": '<path d="M12 3 3 8l9 5 9-5z"/><path d="M3 13l9 5 9-5"/>',
	"play": '<path d="M8 5v14l11-7z" fill="currentColor"/>',
	"sweep": '<path d="M4 20 14 10"/><path d="M14 10l4-4 2 2-4 4z"/><path d="M6 18l-1 3 3-1"/>',
	"chevron": '<path d="M9 5l7 7-7 7"/>',
}

static var _cache := {}

static func get_icon(icon_name: String, px := 48, color := Color.WHITE) -> Texture2D:
	var key := "%s_%d_%s" % [icon_name, px, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var body: String = PATHS.get(icon_name, PATHS["bolt"]).replace("currentColor", "#" + color.to_html(false))
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [color.to_html(false), body]
	var img := Image.new()
	if img.load_svg_from_string(svg, px / 24.0) != OK:
		img = Image.create(px, px, false, Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
