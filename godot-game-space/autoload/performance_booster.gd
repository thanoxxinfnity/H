extends Node
## Engine-side performance controls. Things only Android can do (sustained-performance mode, DND policy,
## system brightness, real screen recording, trimming other apps) are forwarded to an optional
## Android plugin singleton named "GameSpaceAndroid" when it is installed. Without it everything still
## works in-engine, only those system-level parts are skipped.

signal boost_changed(active: bool)

const PLUGIN := "GameSpaceAndroid"
var active := false

func plugin() -> Object:
	return Engine.get_singleton(PLUGIN) if Engine.has_singleton(PLUGIN) else null

func call_plugin(method: String, args: Array = []) -> bool:
	var p := plugin()
	if p == null or not p.has_method(method):
		return false
	p.callv(method, args)
	return true

## mode 0 = power saver (30 fps), 1 = balanced (60), 2 = boost (display refresh rate up to 120).
func apply_mode(mode: int) -> void:
	Settings.performance_mode = mode
	var refresh := DisplayServer.screen_get_refresh_rate()
	if refresh <= 0.0:
		refresh = 60.0
	match mode:
		0: Engine.max_fps = 30
		1: Engine.max_fps = 60
		_: Engine.max_fps = clampi(int(round(refresh)), 60, 120)
	active = mode >= 2
	OS.low_processor_usage_mode = false
	DisplayServer.screen_set_keep_on(mode >= 1)
	call_plugin("setSustainedPerformance", [mode >= 2])
	Settings.save_settings()
	boost_changed.emit(active)

## Frees what this game can free (anything in the "cleanable" group gets clean_up()) and asks the
## Android plugin to trim memory. Returns {freed_mb, available_mb}.
func clean_memory() -> Dictionary:
	var before := Telemetry.free_ram_mb()
	get_tree().call_group("cleanable", "clean_up")
	call_plugin("trimMemory")
	await get_tree().create_timer(0.4).timeout
	var after := Telemetry.free_ram_mb()
	return {"freed_mb": maxf(0.0, after - before) if before >= 0.0 and after >= 0.0 else -1.0, "available_mb": after}
