extends Node
func _ready() -> void:
	var g := AIVideoGenerator.new()
	add_child(g)
	g.failed.connect(func(m: String) -> void: print("FAILED_SIGNAL: ", m); get_tree().quit())
	g.asset_ready.connect(func(p: String) -> void: print("READY ", p); get_tree().quit())
	g.progress.connect(func(s: String, d: String) -> void: print("PROGRESS ", s, " ", d))
	g.api_key = "bad-key"
	g.generate("Cinematic neon nitro vortex boost entry animation test", {})
