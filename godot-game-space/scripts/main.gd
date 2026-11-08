extends Node
## Wires everything together: CAS-upscaled demo "game", Game Space sidebar, video generator, fake notifications.

var _cas: CasUpscaler
var _sidebar: GameSpaceSidebar
var _video: VideoGeneratorPanel
var _ui := CanvasLayer.new()
var _toast := Label.new()

func _ready() -> void:
	_cas = CasUpscaler.new()
	add_child(_cas)
	_cas.add_game_node(DemoGame.new())

	_ui.layer = 10
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	_sidebar = GameSpaceSidebar.new()
	root.add_child(_sidebar)
	_sidebar.display_changed.connect(_apply_display)
	_sidebar.take_screenshot.connect(_screenshot)

	_video = VideoGeneratorPanel.new()
	root.add_child(_video)
	_sidebar.open_video_generator.connect(func() -> void: _video.open())

	_toast.visible = false
	_toast.position = Vector2(20, 14)
	_toast.add_theme_font_size_override("font_size", 18)
	root.add_child(_toast)

	var timer := Timer.new()
	timer.wait_time = 15.0
	timer.autostart = true
	timer.timeout.connect(_fake_notification)
	add_child(timer)

func _apply_display() -> void:
	_cas.apply(Settings.cas_enabled, Settings.cas_sharpness, Settings.render_scale)

func _fake_notification() -> void:
	if Settings.do_not_disturb:
		return # Do Not Disturb: banners are suppressed while you play
	_toast.text = "🔔 New message (demo notification)"
	_toast.visible = true
	await get_tree().create_timer(2.5).timeout
	_toast.visible = false

func _screenshot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/shot_%d.png" % Time.get_unix_time_from_system()
	img.save_png(path)
	print("Saved ", path)
