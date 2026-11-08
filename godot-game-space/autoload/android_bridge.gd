extends Node
## Real Android integration WITHOUT a native plugin: Godot's AndroidRuntime singleton + JavaClassWrapper call the
## Android SDK directly. Everything is guarded, so on desktop (or if a call fails) the app still runs.
## Written against the Android SDK docs; needs an on-device check (no phone was available while writing it).

signal apps_loaded(apps: Array)

var available := false
var _rt: Object
var _activity: Object
var _pm: Object

func _ready() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return
	_rt = Engine.get_singleton("AndroidRuntime")
	_activity = _rt.getActivity()
	if _activity != null:
		_pm = _activity.getPackageManager()
	available = _pm != null

static func _wrap(cls: String) -> Object:
	return JavaClassWrapper.wrap(cls)

## Launchable apps: [{package, label}] sorted by label. Package names are parsed from ResolveInfo.toString()
## ("ResolveInfo{hash com.pkg/.Activity m=0x...}") because Java fields are not reachable from GDScript.
func list_launchable_apps() -> Array:
	var out: Array = []
	if not available:
		return out
	var intent_cls := _wrap("android.content.Intent")
	var intent = intent_cls.Intent("android.intent.action.MAIN")
	intent.addCategory("android.intent.category.LAUNCHER")
	var list = _pm.queryIntentActivities(intent, 0)
	if list == null:
		return out
	var rx := RegEx.new()
	rx.compile("ResolveInfo\\{\\S+ ([\\w.]+)/")
	var seen := {}
	for i in int(list.size()):
		var ri = list.get(i)
		var m := rx.search(str(ri.toString()))
		if m == null:
			continue
		var pkg := m.get_string(1)
		if seen.has(pkg) or pkg == OS.get_unique_id() or pkg == _activity.getPackageName():
			continue
		seen[pkg] = true
		var label := pkg
		var cs = ri.loadLabel(_pm)
		if cs != null:
			label = str(cs.toString())
		out.append({"package": pkg, "label": label})
	out.sort_custom(func(a, b) -> bool: return str(a.label).naturalnocasecmp_to(str(b.label)) < 0)
	return out

func launch_package(pkg: String) -> bool:
	if not available:
		return false
	var intent = _pm.getLaunchIntentForPackage(pkg)
	if intent == null:
		return false
	intent.addFlags(0x10000000) # FLAG_ACTIVITY_NEW_TASK
	_activity.startActivity(intent)
	return true

## App icon as a PNG-decoded texture (null when unavailable).
func app_icon(pkg: String, px := 96) -> Texture2D:
	if not available:
		return null
	var drawable = _pm.getApplicationIcon(pkg)
	if drawable == null:
		return null
	var cfg = _wrap("android.graphics.Bitmap$Config").valueOf("ARGB_8888")
	var bmp = _wrap("android.graphics.Bitmap").createBitmap(px, px, cfg)
	var canvas = _wrap("android.graphics.Canvas").Canvas(bmp)
	drawable.setBounds(0, 0, px, px)
	drawable.draw(canvas)
	var baos = _wrap("java.io.ByteArrayOutputStream").ByteArrayOutputStream()
	var fmt = _wrap("android.graphics.Bitmap$CompressFormat").valueOf("PNG")
	bmp.compress(fmt, 100, baos)
	var bytes: PackedByteArray = baos.toByteArray()
	var img := Image.new()
	if bytes.is_empty() or img.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(img)

## Real RAM clean: asks Android to kill the cached background processes of every other launchable app.
## Needs android.permission.KILL_BACKGROUND_PROCESSES (normal permission, granted at install).
func kill_background(except_pkg := "") -> int:
	if not available:
		return 0
	var am = _activity.getSystemService("activity")
	if am == null:
		return 0
	var n := 0
	for app in list_launchable_apps():
		if app.package == except_pkg or app.package == str(_activity.getPackageName()):
			continue
		am.killBackgroundProcesses(app.package)
		n += 1
	return n

## {temp_c, level} from the sticky battery broadcast, or {} when unavailable.
func battery() -> Dictionary:
	if not available:
		return {}
	var filter = _wrap("android.content.IntentFilter").IntentFilter("android.intent.action.BATTERY_CHANGED")
	var it = _activity.registerReceiver(null, filter)
	if it == null:
		return {}
	var temp: int = it.getIntExtra("temperature", -1)
	var level: int = it.getIntExtra("level", -1)
	var scale: int = it.getIntExtra("scale", 100)
	return {"temp_c": temp / 10.0 if temp >= 0 else -1.0, "level": int(100.0 * level / maxf(1.0, float(scale))) if level >= 0 else -1}

## Do Not Disturb. Returns false and opens the system screen when the app has no notification-policy access yet.
func set_dnd(on: bool) -> bool:
	if not available:
		return false
	var nm = _activity.getSystemService("notification")
	if nm == null:
		return false
	if not nm.isNotificationPolicyAccessGranted():
		var intent = _wrap("android.content.Intent").Intent("android.settings.NOTIFICATION_POLICY_ACCESS_SETTINGS")
		_activity.startActivity(intent)
		return false
	nm.setInterruptionFilter(2 if on else 1) # 2 = priority only, 1 = allow all
	return true

## Sustained-performance mode keeps clocks steady instead of bursting then throttling (API 24+).
func set_sustained_performance(on: bool) -> void:
	if not available or _rt == null:
		return
	var task := func() -> void:
		var win = _activity.getWindow()
		if win != null:
			win.setSustainedPerformanceMode(on)
	var runnable = _rt.createRunnableFromGodotCallable(task)
	_activity.runOnUiThread(runnable)
