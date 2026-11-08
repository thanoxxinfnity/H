extends Node
## Smoke test: boots the real main scene, takes screenshots of the intro, the game and the opened drawer.
## Run: xvfb-run godot --path . res://tests/smoke.tscn -- /output/dir

var out := "/tmp"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.4).timeout
	_shot("1_intro")
	await get_tree().create_timer(3.4).timeout
	_shot("2_intro_late")
	await get_tree().create_timer(2.0).timeout
	_shot("3_game")
	# swipe in from the upper-left border
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
	_shot("4_drawer")
	Settings.triggers_on = true
	Settings.light_theme = 4
	var sc := _find_scroll(main.get_node("UiLayer/Sidebar"))
	for k in 3:
		sc.scroll_vertical = 520 * (k + 1)
		await get_tree().create_timer(0.5).timeout
		_shot("5_scroll_%d" % k)
	print("SMOKE_DONE sidebar_open=", main.get_node("UiLayer/Sidebar").is_open())
	get_tree().quit()

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("shot ", name, " ", img.get_size())

func _find_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer:
		return n
	for c in n.get_children():
		var r := _find_scroll(c)
		if r != null:
			return r
	return null
