extends Node
func _ready() -> void:
	Settings.games = [{"package": "com.example.racer", "label": "Sample Racer"}]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(5.0).timeout
	var lib: GameLibrary = main.get_node("UiLayer/GameLibrary")
	print("lib size ", lib.size, " grid children ", lib._grid.get_child_count(), " grid size ", lib._grid.size, " grid cols ", lib._grid.columns)
	for c in lib._grid.get_children():
		print(" tile ", c.name, " size ", c.size, " pos ", c.position, " visible ", c.visible)
	var sc: ScrollContainer = lib._grid.get_parent()
	print("scroll size ", sc.size, " pos ", sc.position)
	get_tree().quit()
