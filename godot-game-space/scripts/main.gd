extends Node
## Composition root: CAS-upscaled game + Game Space drawer + telemetry HUD + cinematic booster intro.

@onready var upscaler: UpscalerManager = $Upscaler
@onready var generator: AIVideoGenerator = $Generator
@onready var recorder: ScreenRecorder = $Recorder
@onready var sidebar: GameSpaceSidebar = $UiLayer/Sidebar
@onready var intro: BoosterEntryAnimation = $UiLayer/BoosterEntry
@onready var toast: Label = $UiLayer/SafeArea/HudRoot/Toast

func _ready() -> void:
	upscaler.add_game_node(DemoGame.new())
	sidebar.setup(upscaler, generator, recorder)
	sidebar.replay_intro.connect(_play_intro)
	toast.visible = false
	var timer := Timer.new()
	timer.wait_time = 18.0
	timer.autostart = true
	timer.timeout.connect(_fake_notification)
	add_child(timer)
	_play_intro()

func _play_intro() -> void:
	if not intro.finished.is_connected(_on_intro_done):
		intro.finished.connect(_on_intro_done)
	var asset := Settings.entry_asset
	intro.play(asset if asset != "" and FileAccess.file_exists(asset) else "")

func _on_intro_done() -> void:
	PerformanceBooster.apply_mode(2 if Settings.boost_on_launch else Settings.performance_mode)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and sidebar.is_open():
		sidebar.toggle(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and sidebar.is_open():
		sidebar.toggle(false)

func _fake_notification() -> void:
	if Settings.do_not_disturb:
		return # Do Not Disturb: banners are suppressed while you play
	toast.text = "New message (demo notification)"
	toast.visible = true
	await get_tree().create_timer(2.5).timeout
	toast.visible = false
