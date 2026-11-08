extends Node
## Live device telemetry. Battery temperature and CPU frequency come from Linux sysfs and are only
## readable on some Android builds/devices; when unreadable the values stay at -1 and the UI shows "--".

signal updated

const BATTERY_CAP := "/sys/class/power_supply/battery/capacity" # percent
const BATTERY_TEMP := "/sys/class/power_supply/battery/temp" # tenths of a degree Celsius
const CPU_FREQ := "/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq" # kHz
const CPU_FREQ_MAX := "/sys/devices/system/cpu/cpu%d/cpufreq/cpuinfo_max_freq"

var fps := 0
var frame_ms := 16.6
var battery_temp_c := -1.0
var battery_pct := -1
var cpu_mhz := -1
var cpu_load := 0.0 # 0..1, current frequency vs. the highest max frequency
var ram_used := 0.0 # 0..1
var ping_ms := -1
var session_seconds := 0.0
var history: PackedFloat32Array = PackedFloat32Array()

var _acc := 0.0
var _ping_acc := 5.0
var _ping_t0 := 0
var _ping_req := HTTPRequest.new()
var _save_acc := 0.0
var _hist_acc := 0.0
var _cpu_max_khz := 0

func _ready() -> void:
	_ping_req.timeout = 4.0
	add_child(_ping_req)
	_ping_req.request_completed.connect(_on_ping)
	for i in 8:
		_cpu_max_khz = maxi(_cpu_max_khz, _read_int(CPU_FREQ_MAX % i))

func _process(dt: float) -> void:
	frame_ms = lerpf(frame_ms, dt * 1000.0, 0.08)
	_hist_acc += dt
	if _hist_acc >= 0.1:
		_hist_acc = 0.0
		history.append(float(Engine.get_frames_per_second()))
		if history.size() > 60:
			history.remove_at(0)
	session_seconds += dt
	_save_acc += dt
	if _save_acc >= 60.0:
		_save_acc = 0.0
		Settings.playtime_total += 60.0
		Settings.save_settings()
	_ping_acc += dt
	if _ping_acc >= 6.0 and _ping_req.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_ping_acc = 0.0
		_ping_t0 = Time.get_ticks_msec()
		_ping_req.request("https://www.gstatic.com/generate_204", PackedStringArray(), HTTPClient.METHOD_HEAD)
	_acc += dt
	if _acc < 0.5:
		return
	_acc = 0.0
	fps = int(Engine.get_frames_per_second())
	var t := _read_int(BATTERY_TEMP)
	battery_temp_c = t / 10.0 if t > 0 else -1.0
	battery_pct = _read_int(BATTERY_CAP)
	var best := -1
	for i in 8:
		best = maxi(best, _read_int(CPU_FREQ % i))
	cpu_mhz = best / 1000 if best > 0 else -1
	if best > 0 and _cpu_max_khz > 0:
		cpu_load = clampf(float(best) / float(_cpu_max_khz), 0.0, 1.0)
	else:
		cpu_load = clampf(1.0 - frame_ms / 33.0, 0.05, 1.0) # rough estimate from frame time
	var mem := OS.get_memory_info()
	var phys: int = mem.get("physical", -1)
	var avail: int = mem.get("available", -1)
	ram_used = clampf(1.0 - float(avail) / float(phys), 0.0, 1.0) if phys > 0 and avail >= 0 else 0.0
	updated.emit()

static func _read_int(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var s := f.get_line().strip_edges()
	return int(s) if s.is_valid_int() else -1

func free_ram_mb() -> float:
	var mem := OS.get_memory_info()
	var avail: int = mem.get("available", -1)
	return avail / 1048576.0 if avail >= 0 else -1.0

func _on_ping(result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	ping_ms = Time.get_ticks_msec() - _ping_t0 if result == HTTPRequest.RESULT_SUCCESS else -1

static func format_time(seconds: float) -> String:
	var t := int(seconds)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]
