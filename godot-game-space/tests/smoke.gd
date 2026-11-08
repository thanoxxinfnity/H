extends Node
## Smoke test: boots the real main scene and screenshots intro, home library, add-game picker, arena and the drawer.
## Run: xvfb-run godot --path . res://tests/smoke.tscn -- /output/dir

var out := "/tmp"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Settings.games = [{"package": "com.example.racer", "label": "Sample Racer"}, {"package": "com.example.shooter", "label": "Sample Shooter"}]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.5).timeout
	_shot("1_intro")
	await get_tree().create_timer(3.4).timeout
	_shot("2_home")
	var lib: GameLibrary = main.get_node("UiLayer/GameLibrary")
	lib.call("_open_picker")
	await get_tree().create_timer(0.5).timeout
	_shot("3_picker")
	lib._picker.visible = false
	lib.play_game.emit(GameLibrary.ARENA)
	await get_tree().create_timer(6.5).timeout
	_shot("4_arena")
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.pressed = true
	t.position = Vector2(10, 100)
	Input.parse_input_event(t)
	for i in 8:
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = Vector2(10 + i * 14, 100)
		d.relative = Vector2(14, 0)
		Input.parse_input_event(d)
		await get_tree().process_frame
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.pressed = false
	u.position = Vector2(130, 100)
	Input.parse_input_event(u)
	await get_tree().create_timer(1.2).timeout
	_shot("5_drawer")
	print("SMOKE_DONE sidebar_open=", main.get_node("UiLayer/Sidebar").is_open(), " library_visible=", lib.visible)
	get_tree().quit()

func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, shot_name])
	print("shot ", shot_name, " ", img.get_size())
