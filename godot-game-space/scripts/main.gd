extends Node
## Composition root: Game Space home (library), Arena test game under the CAS upscaler, edge-swipe boost drawer,
## telemetry HUD, air triggers, cyber light and the booster intro.

const BUNDLED_INTRO := "res://assets/entry/booster_entry.ogv"

@onready var upscaler: UpscalerManager = $Upscaler
@onready var generator: AIVideoGenerator = $Generator
@onready var recorder: ScreenRecorder = $Recorder
@onready var triggers: AirTriggers = $UiLayer/AirTriggers
@onready var sidebar: GameSpaceSidebar = $UiLayer/Sidebar
@onready var intro: BoosterEntryAnimation = $UiLayer/BoosterEntry
@onready var library: GameLibrary = $UiLayer/GameLibrary
@onready var toast: Label = $UiLayer/SafeArea/HudRoot/Toast

func _ready() -> void:
	upscaler.add_game_node(DemoGame.new())
	upscaler.set_active(false)
	triggers.upscaler = upscaler
	sidebar.setup(upscaler, generator, recorder, triggers)
	sidebar.replay_intro.connect(func() -> void: _play_intro(""))
	sidebar.go_home.connect(_show_home)
	library.play_game.connect(_on_play)
	PerformanceBooster.thermal_throttled.connect(func(t: float) -> void: _show_toast("Cooling: dropped to Balanced (%.0f C)" % t))
	toast.visible = false
	intro.finished.connect(_on_intro_done)
	_play_intro("")

func _play_intro(target: String) -> void:
	intro.target_name = target
	# priority: AI clip you generated in-app > clip bundled at assets/entry/booster_entry.ogv > procedural intro
	var asset := Settings.entry_asset
	if asset == "" or not FileAccess.file_exists(asset):
		asset = BUNDLED_INTRO if ResourceLoader.exists(BUNDLED_INTRO) else ""
	intro.play(asset)

func _on_intro_done() -> void:
	PerformanceBooster.apply_mode(3 if Settings.boost_on_launch else Settings.performance_mode)

func _show_home() -> void:
	library.visible = true
	upscaler.set_active(false)

## Boost and play: intro runs while Android really closes background apps, then the game launches.
func _on_play(entry: Dictionary) -> void:
	_play_intro(str(entry.get("label", "")))
	var report: Dictionary = await PerformanceBooster.clean_memory(str(entry.get("package", "")))
	intro.set_result(report)
	await intro.finished
	if entry.get("builtin", false):
		library.visible = false
		upscaler.set_active(true)
	elif AndroidBridge.available:
		if not AndroidBridge.launch_package(str(entry.package)):
			_show_toast("Could not launch %s" % entry.label)
	else:
		_show_toast("Desktop preview: would launch %s" % entry.package)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if sidebar.is_open():
			sidebar.toggle(false)
		elif not library.visible:
			_show_home()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if sidebar.is_open():
			sidebar.toggle(false)
		elif not library.visible:
			_show_home()

func _show_toast(text: String) -> void:
	toast.text = text
	toast.visible = true
	await get_tree().create_timer(2.5).timeout
	toast.visible = false
