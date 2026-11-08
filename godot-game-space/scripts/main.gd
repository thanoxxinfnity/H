extends Node
## Composition root: Game Space home (auto-detected games), edge-swipe boost drawer, telemetry HUD, cyber light, booster intro.

const INTRO_FULL := "res://assets/entry/booster_entry.ogv" # 10 s, played when the app opens
const INTRO_LAUNCH := "res://assets/entry/booster_launch.ogv" # 6 s, played before a game launches

@onready var generator: AIVideoGenerator = $Generator
@onready var sidebar: GameSpaceSidebar = $UiLayer/Sidebar
@onready var intro: BoosterEntryAnimation = $UiLayer/BoosterEntry
@onready var library: GameLibrary = $UiLayer/GameLibrary
@onready var toast: Label = $UiLayer/SafeArea/HudRoot/Toast

func _ready() -> void:
	sidebar.setup(generator)
	sidebar.replay_intro.connect(func() -> void: _play_intro(""))
	library.play_game.connect(_on_play)
	PerformanceBooster.thermal_throttled.connect(func(t: float) -> void: _show_toast("Cooling: dropped to Balanced (%.0f C)" % t))
	toast.visible = false
	intro.finished.connect(_on_intro_done)
	_play_intro("")

func _play_intro(target: String) -> void:
	intro.target_name = target
	# priority: clip generated in-app > bundled clip > procedural intro
	var asset := Settings.entry_asset
	var secs := 8.0
	if asset == "" or not FileAccess.file_exists(asset):
		asset = INTRO_LAUNCH if target != "" else INTRO_FULL
		secs = 6.0 if target != "" else 10.0
		if not ResourceLoader.exists(asset):
			asset = ""
	intro.play(asset, secs)

func _on_intro_done() -> void:
	PerformanceBooster.apply_mode(3 if Settings.boost_on_launch else Settings.performance_mode)

## Boost and play: the intro runs while Android really closes background apps, then the game launches.
func _on_play(entry: Dictionary) -> void:
	var pkg := str(entry.get("package", ""))
	var prof := GameSession.profile_for(pkg)
	_play_intro(str(entry.get("label", "")))
	var report := {}
	if prof.clean:
		report = await PerformanceBooster.clean_memory(pkg)
	intro.set_result(report)
	await intro.finished
	entry = entry.duplicate()
	entry["freed_mb"] = report.get("freed_mb", 0.0)
	GameSession.begin(entry)
	if AndroidBridge.available:
		if not AndroidBridge.launch_package(pkg):
			_show_toast("Could not launch %s" % entry.label)
	else:
		_show_toast("Desktop preview: would launch %s" % pkg)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and sidebar.is_open():
		sidebar.toggle(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and sidebar.is_open():
		sidebar.toggle(false)

func _show_toast(text: String) -> void:
	toast.text = text
	toast.visible = true
	await get_tree().create_timer(2.5).timeout
	toast.visible = false
