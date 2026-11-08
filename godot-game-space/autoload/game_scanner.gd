extends Node
## Finds games by itself and keeps the Game Space list in sync, like a phone's built-in game space:
## a game you install shows up on its own, an uninstalled one disappears, and a game you removed by hand stays removed.
## Detection: Android's own game classification (see AndroidBridge.is_game), a list of well-known game packages,
## and name keywords as a last resort.

signal games_changed(added: Array, removed: Array)

const SCAN_EVERY := 25.0

## package -> display name for popular titles (used for the label when Android's name is unhelpful).
const KNOWN := {
	"com.dts.freefireth": "Free Fire",
	"com.dts.freefiremax": "Free Fire MAX",
	"com.pubg.imobile": "BGMI",
	"com.tencent.ig": "PUBG MOBILE",
	"com.pubg.krmobile": "PUBG MOBILE (KR)",
	"com.tencent.iglite": "PUBG MOBILE LITE",
	"com.mojang.minecraftpe": "Minecraft",
	"com.activision.callofduty.shooter": "Call of Duty Mobile",
	"com.miHoYo.GenshinImpact": "Genshin Impact",
	"com.supercell.clashofclans": "Clash of Clans",
	"com.supercell.clashroyale": "Clash Royale",
	"com.supercell.brawlstars": "Brawl Stars",
	"com.roblox.client": "Roblox",
	"com.innersloth.spacemafia": "Among Us",
	"com.mobile.legends": "Mobile Legends",
	"com.kiloo.subwaysurf": "Subway Surfers",
	"com.king.candycrushsaga": "Candy Crush Saga",
	"com.gameloft.android.ANMP.GloftA9HM": "Asphalt 9",
	"com.ea.gp.fifamobile": "EA SPORTS FC Mobile",
	"com.epicgames.fortnite": "Fortnite",
	"com.tencent.tmgp.sgame": "Honor of Kings",
	"com.garena.game.codm": "Call of Duty Mobile (Garena)",
}
const KEYWORDS := ["freefire", "free fire", "pubg", "bgmi", "minecraft", "battleground", "callofduty", "clash", "legends", "fortnite", "roblox", "genshin", "carrom", "ludo", "racing", "asphalt", "gameloft", "supercell", "garena", "tencent.ig", ".game", "games."]

var _timer := Timer.new()
var _busy := false

func _ready() -> void:
	_timer.wait_time = SCAN_EVERY
	_timer.timeout.connect(scan)
	add_child(_timer)
	if AndroidBridge.available:
		_timer.start()
		scan.call_deferred()
	elif Settings.games.is_empty():
		_seed_desktop_preview()

func _notification(what: int) -> void:
	# coming back from the Play Store / package installer: pick up the game that was just installed
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and AndroidBridge.available:
		scan()

func is_game(pkg: String, label: String) -> bool:
	if KNOWN.has(pkg):
		return true
	if AndroidBridge.is_game(pkg):
		return true
	var hay := (pkg + " " + label).to_lower()
	for k in KEYWORDS:
		if k in hay:
			return true
	return false

func scan() -> void:
	if _busy or not AndroidBridge.available:
		return
	_busy = true
	var apps := AndroidBridge.list_launchable_apps()
	if apps.is_empty():
		_busy = false
		return # query failed or no permission: keep the list as it is
	var installed := {}
	var added: Array = []
	var have := {}
	for g in Settings.games:
		have[g.package] = true
	for a in apps:
		installed[a.package] = true
		if have.has(a.package) or Settings.ignored.has(a.package):
			continue
		if is_game(a.package, str(a.label)):
			var entry := {"package": a.package, "label": KNOWN.get(a.package, a.label), "auto": true}
			Settings.games.append(entry)
			added.append(entry)
	var removed: Array = []
	var kept: Array = []
	for g in Settings.games:
		if installed.has(g.package):
			kept.append(g)
		else:
			removed.append(g)
	Settings.games = kept
	if not added.is_empty() or not removed.is_empty():
		Settings.save_settings()
		games_changed.emit(added, removed)
	_busy = false

## User removed a tile: remember it so the scanner does not bring it back.
func forget(pkg: String) -> void:
	Settings.games = Settings.games.filter(func(g) -> bool: return g.package != pkg)
	if not Settings.ignored.has(pkg):
		Settings.ignored.append(pkg)
	Settings.save_settings()

## Un-hide everything the user removed earlier and scan again.
func restore_ignored() -> void:
	Settings.ignored = []
	Settings.save_settings()
	scan()

func _seed_desktop_preview() -> void:
	# desktop preview only: there is no installed-app list off Android, so show what the home looks like
	for pkg in ["com.dts.freefiremax", "com.pubg.imobile", "com.mojang.minecraftpe", "com.dts.freefireth", "com.tencent.ig"]:
		Settings.games.append({"package": pkg, "label": KNOWN[pkg], "auto": true, "preview": true})
