extends Node
## One play session of an external game: applies the game's profile when it launches and, when you come back to
## Game Space, restores your settings and records play time + a battery/temperature report.
## "Back in Game Space" is detected through the app-focus notifications (needs an on-device check).

signal session_ended(report: Dictionary)

var _a := {}
var _bg := false

func profile_for(pkg: String) -> Dictionary:
	var d := {"mode": 3, "clean": true, "dnd": true, "bright": -1.0}
	d.merge(Settings.profiles.get(pkg, {}), true)
	return d

func stats_for(pkg: String) -> Dictionary:
	var d := {"launches": 0, "seconds": 0.0, "last": 0.0}
	d.merge(Settings.stats.get(pkg, {}), true)
	return d

func begin(entry: Dictionary) -> void:
	var pkg := str(entry.get("package", ""))
	var prof := profile_for(pkg)
	var bat := AndroidBridge.battery()
	_a = {"package": pkg, "label": str(entry.get("label", pkg)), "t0": Time.get_unix_time_from_system(),
		"battery0": bat.get("level", -1), "dnd_changed": false, "bright_old": -1, "freed_mb": float(entry.get("freed_mb", 0.0))}
	PerformanceBooster.apply_mode(int(prof.mode))
	if prof.dnd and AndroidBridge.set_dnd(true):
		_a.dnd_changed = true
	if float(prof.bright) >= 0.0 and AndroidBridge.can_write_settings():
		_a.bright_old = AndroidBridge.get_brightness()
		AndroidBridge.set_brightness(int(float(prof.bright) * 255.0))
	var st := stats_for(pkg)
	st.launches = int(st.launches) + 1
	st.last = _a.t0
	Settings.stats[pkg] = st
	Settings.save_settings()
	_bg = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_bg = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and not _a.is_empty() and _bg:
		end()

func end() -> void:
	var secs := Time.get_unix_time_from_system() - float(_a.t0)
	if _a.dnd_changed and not Settings.do_not_disturb:
		AndroidBridge.set_dnd(false)
	if int(_a.bright_old) >= 0:
		AndroidBridge.set_brightness(int(_a.bright_old))
	var bat := AndroidBridge.battery()
	var drop := -1
	if int(_a.battery0) >= 0 and int(bat.get("level", -1)) >= 0:
		drop = int(_a.battery0) - int(bat.level)
	var report := {"label": _a.label, "seconds": secs, "battery_drop": drop, "temp_c": bat.get("temp_c", -1.0), "freed_mb": _a.freed_mb}
	if secs >= 20.0:
		var st := stats_for(str(_a.package))
		st.seconds = float(st.seconds) + secs
		Settings.stats[_a.package] = st
		Settings.last_session = report
		Settings.save_settings()
		session_ended.emit(report)
	PerformanceBooster.apply_mode(Settings.performance_mode if not Settings.boost_on_launch else 3)
	_a = {}

static func fmt_duration(seconds: float) -> String:
	var m := int(seconds / 60.0)
	if m < 1:
		return "<1 MIN"
	if m < 60:
		return "%d MIN" % m
	return "%dH %02dM" % [m / 60, m % 60]
