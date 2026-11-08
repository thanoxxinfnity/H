class_name ScreenRecorder
extends Node
## In-engine capture: saves downscaled JPG frames to user://recordings/<timestamp>/ (15 fps, 20 s cap) on a
## worker thread. Real MP4 screen recording needs Android's MediaProjection; if the optional
## "GameSpaceAndroid" plugin exposes startScreenRecord()/stopScreenRecord(), that is used instead.

signal state_changed(recording: bool, info: String)

var recording := false
var _use_plugin := false
var _vp: Viewport
var _dir := ""
var _n := 0
var _elapsed := 0.0
var _max_seconds := 20.0
var _timer := Timer.new()

func _ready() -> void:
	add_child(_timer)
	_timer.timeout.connect(_tick)

func start(vp: Viewport, fps := 15, max_seconds := 20) -> void:
	if recording:
		return
	recording = true
	_n = 0
	_elapsed = 0.0
	_max_seconds = float(max_seconds)
	if PerformanceBooster.call_plugin("startScreenRecord"):
		_use_plugin = true
		state_changed.emit(true, "Recording (system)")
		return
	_use_plugin = false
	_vp = vp
	_dir = "user://recordings/%d" % Time.get_unix_time_from_system()
	DirAccess.make_dir_recursive_absolute(_dir)
	_timer.wait_time = 1.0 / float(fps)
	_timer.start()
	state_changed.emit(true, "Recording…")

func stop() -> void:
	if not recording:
		return
	recording = false
	if _use_plugin:
		PerformanceBooster.call_plugin("stopScreenRecord")
		state_changed.emit(false, "Saved by system recorder")
		return
	_timer.stop()
	state_changed.emit(false, "Saved %d frames in %s" % [_n, ProjectSettings.globalize_path(_dir)])

func _tick() -> void:
	_elapsed += _timer.wait_time
	if _elapsed > _max_seconds:
		stop()
		return
	var img := _vp.get_texture().get_image()
	if img == null or img.is_empty():
		return
	if img.get_width() > 960:
		img.resize(960, int(img.get_height() * 960.0 / img.get_width()), Image.INTERPOLATE_BILINEAR)
	WorkerThreadPool.add_task(img.save_jpg.bind("%s/f%05d.jpg" % [_dir, _n], 0.8))
	_n += 1
	state_changed.emit(true, "REC %02d s" % int(_elapsed))
