class_name AIVideoGenerator
extends Node
## REST client for AI video / animation generation APIs.
##   prompt -> create task -> poll until done -> download -> cache in user://cache/animations/ -> play.
## Providers: "revana" (api.revana.si, tested), "replicate" and "luma" (written from their public API
## docs, not tested against the live services). The API key goes in `Authorization: Bearer <key>`.
##
## PLAYBACK: Godot 4.3 can only decode Ogg Theora (.ogv) natively. For .mp4/.webm results use one of:
##   a) the EIRTeam.FFmpeg GDExtension (class FFmpegVideoStream) - detected automatically, or
##   b) a spritesheet (png/webp) result, played with AnimatedSprite2D, or
##   c) the procedural intro (BoosterEntryAnimation falls back to it when `play_into` returns null).

signal progress(stage: String, detail: String)
signal asset_ready(path: String)
signal failed(message: String)

const CACHE_DIR := "user://cache/animations/"
const POLL_SECONDS := 4.0
const MAX_WAIT_SECONDS := 20 * 60

const PROFILES := {
	"revana": {"base": "https://api.revana.si/v1", "label": "Revana"},
	"replicate": {"base": "https://api.replicate.com/v1", "label": "Replicate"},
	"luma": {"base": "https://api.lumalabs.ai/dream-machine/v1", "label": "Luma"},
}

var api_key := ""
var provider := "revana"
var model := "minimax-h3-free" # replicate: "owner/name" e.g. "minimax/video-01"; luma: "ray-2"
var busy := false
var _cancel := false

# ---------------------------------------------------------------- public API
func cancel() -> void:
	_cancel = true

## Generates (or reuses from cache) an animation for `prompt`. opts: duration, aspect_ratio, resolution, force.
func generate(prompt: String, opts := {}) -> void:
	if busy:
		failed.emit("Already generating.")
		return
	prompt = prompt.strip_edges()
	if prompt.length() < 5:
		failed.emit("Write a longer prompt first.")
		return
	if api_key.strip_edges() == "":
		failed.emit("Add your API key first.")
		return
	busy = true
	_cancel = false
	var hit := cached_path(prompt)
	if hit != "" and not opts.get("force", false):
		progress.emit("cache", "Using cached animation")
		busy = false
		asset_ready.emit(hit)
		return
	var ok := await _run(prompt, opts)
	busy = false
	if not ok and _cancel:
		failed.emit("Cancelled.")

func cached_path(prompt: String) -> String:
	var stem := _stem(prompt)
	var d := DirAccess.open(CACHE_DIR)
	if d == null:
		return ""
	for f in d.get_files():
		if f.begins_with(stem + "."):
			return CACHE_DIR + f
	return ""

func clear_cache() -> int:
	var d := DirAccess.open(CACHE_DIR)
	if d == null:
		return 0
	var n := 0
	for f in d.get_files():
		if d.remove(f) == OK:
			n += 1
	return n

## Puts the downloaded asset on screen inside `host` (filling it). Returns the created node or null when
## the format cannot be decoded on this build (caller should use its procedural fallback).
## opts for spritesheets: hframes, vframes, fps.
static func play_into(host: Control, path: String, loop := true, opts := {}) -> Node:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var ext := path.get_extension().to_lower()
	if ext == "ogv":
		var theora := VideoStreamTheora.new()
		theora.file = path
		return _make_player(host, theora, loop)
	if ext in ["mp4", "webm", "mov", "mkv"] and ClassDB.class_exists("FFmpegVideoStream"):
		var ff = ClassDB.instantiate("FFmpegVideoStream")
		ff.set("file", path)
		return _make_player(host, ff, loop)
	if ext in ["png", "webp", "jpg", "jpeg"]:
		return _make_sheet(host, path, loop, opts)
	return null

# ---------------------------------------------------------------- pipeline
func _run(prompt: String, opts: Dictionary) -> bool:
	progress.emit("create", "Sending prompt to %s…" % PROFILES[provider].label)
	var job := await _create(prompt, opts)
	if job.is_empty():
		return false
	var waited := 0.0
	while waited < MAX_WAIT_SECONDS:
		if _cancel:
			return false
		await get_tree().create_timer(POLL_SECONDS).timeout
		waited += POLL_SECONDS
		var st := await _poll(job)
		if st.get("state", "") == "":
			continue # transient network error, keep polling
		progress.emit("poll", "%s (%ds)" % [st.state, int(waited)])
		if st.state == "failed":
			failed.emit(str(st.get("error", "Generation failed.")))
			return false
		if st.state == "done":
			return await _download(prompt, job, st)
	failed.emit("Timed out waiting for the video.")
	return false

func _headers(extra: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var h := PackedStringArray(["Authorization: Bearer %s" % api_key.strip_edges(), "Content-Type: application/json"])
	h.append_array(extra)
	return h

func _create(prompt: String, opts: Dictionary) -> Dictionary:
	var base: String = PROFILES[provider].base
	var url := ""
	var body := {}
	var extra := PackedStringArray()
	match provider:
		"revana":
			url = base + "/generations"
			body = {"model": model, "input": {"prompt": prompt, "duration": opts.get("duration", 5), "resolution": opts.get("resolution", "480p"), "aspect_ratio": opts.get("aspect_ratio", "16:9")}}
			extra.append("Idempotency-Key: gs-%d-%d" % [Time.get_unix_time_from_system(), randi()])
		"replicate":
			url = "%s/models/%s/predictions" % [base, model]
			body = {"input": {"prompt": prompt}}
		"luma":
			url = base + "/generations"
			body = {"prompt": prompt, "model": model, "resolution": "720p", "duration": "5s", "aspect_ratio": opts.get("aspect_ratio", "16:9"), "loop": true}
		_:
			failed.emit("Unknown provider.")
			return {}
	var r := await _http(HTTPClient.METHOD_POST, url, _headers(extra), JSON.stringify(body))
	if not r.ok:
		failed.emit(_error_text(r))
		return {}
	var j := _json(r.body)
	var id := str(j.get("id", ""))
	if id == "":
		failed.emit("The API returned no task id.")
		return {}
	var poll_url := "%s/generations/%s" % [base, id]
	if provider == "replicate":
		var urls = j.get("urls", {})
		poll_url = str(urls.get("get", "")) if urls is Dictionary else ""
		if poll_url == "":
			poll_url = "https://api.replicate.com/v1/predictions/%s" % id
	return {"id": id, "poll_url": poll_url}

## Returns {state: "pending"|"done"|"failed"|"" (network hiccup), url?, error?}.
func _poll(job: Dictionary) -> Dictionary:
	var r := await _http(HTTPClient.METHOD_GET, job.poll_url, _headers())
	if not r.ok:
		return {"state": ""}
	var j := _json(r.body)
	match provider:
		"revana":
			var s := str(j.get("status", ""))
			if s == "succeeded":
				return {"state": "done", "url": "%s/generations/%s/content" % [PROFILES.revana.base, job.id]}
			if s == "failed" or s == "cancelled":
				return {"state": "failed", "error": _nested_msg(j.get("error"), s)}
			return {"state": s if s != "" else "pending"}
		"replicate":
			var s2 := str(j.get("status", ""))
			if s2 == "succeeded":
				var out = j.get("output")
				var u := str(out[0]) if out is Array and not out.is_empty() else str(out)
				return {"state": "done", "url": u}
			if s2 == "failed" or s2 == "canceled":
				return {"state": "failed", "error": str(j.get("error", s2))}
			return {"state": s2 if s2 != "" else "pending"}
		"luma":
			var s3 := str(j.get("state", ""))
			if s3 == "completed":
				var assets = j.get("assets", {})
				return {"state": "done", "url": str(assets.get("video", "")) if assets is Dictionary else ""}
			if s3 == "failed":
				return {"state": "failed", "error": str(j.get("failure_reason", "failed"))}
			return {"state": s3 if s3 != "" else "pending"}
	return {"state": ""}

func _download(prompt: String, job: Dictionary, st: Dictionary) -> bool:
	progress.emit("download", "Downloading…")
	var url: String = st.get("url", "")
	if url == "":
		failed.emit("The API finished but returned no file.")
		return false
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	if provider == "revana":
		# /content answers 302 to a signed storage URL that must be fetched WITHOUT the Authorization header.
		var r := await _http(HTTPClient.METHOD_GET, url, _headers(), "", false)
		var loc := _header(r.headers, "location")
		if loc == "":
			failed.emit("Could not get the video link: " + _error_text(r))
			return false
		url = loc
		return await _save(prompt, url, PackedStringArray())
	return await _save(prompt, url, PackedStringArray())

func _save(prompt: String, url: String, headers: PackedStringArray) -> bool:
	var ext := url.get_file().split("?")[0].get_extension().to_lower()
	if ext == "":
		ext = "mp4"
	var final_path := "%s%s.%s" % [CACHE_DIR, _stem(prompt), ext]
	var part := final_path + ".part"
	var r := await _http(HTTPClient.METHOD_GET, url, headers, "", true, part)
	if not r.ok:
		DirAccess.remove_absolute(part)
		failed.emit("Download failed (HTTP %d)." % r.code)
		return false
	DirAccess.rename_absolute(part, final_path)
	progress.emit("done", "Saved " + final_path.get_file())
	asset_ready.emit(final_path)
	return true

# ---------------------------------------------------------------- HTTP helpers
## Returns {ok, code, headers, body}. `download_to` streams the body straight to disk (low RAM on phones).
func _http(method: int, url: String, headers: PackedStringArray, body := "", follow := true, download_to := "") -> Dictionary:
	var req := HTTPRequest.new()
	req.max_redirects = 8 if follow else 0
	req.timeout = 180.0
	if download_to != "":
		req.download_file = download_to
	add_child(req)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "headers": PackedStringArray(), "body": PackedByteArray()}
	var res: Array = await req.request_completed
	req.queue_free()
	var code: int = res[1]
	return {"ok": code >= 200 and code < 400, "code": code, "headers": res[2], "body": res[3]}

static func _header(headers: PackedStringArray, header_name: String) -> String:
	var prefix := header_name.to_lower() + ":"
	for h in headers:
		if h.to_lower().begins_with(prefix):
			return h.substr(prefix.length()).strip_edges()
	return ""

static func _json(body: PackedByteArray) -> Dictionary:
	var v = JSON.parse_string(body.get_string_from_utf8())
	return v if v is Dictionary else {}

static func _nested_msg(e, fallback: String) -> String:
	if e is Dictionary and str(e.get("message", "")) != "":
		return str(e.get("message"))
	return fallback

func _error_text(r: Dictionary) -> String:
	var j := _json(r.body)
	var e = j.get("error", j.get("detail", ""))
	return _nested_msg(e, str(e) if str(e) != "" else "HTTP %d" % r.code)

func _stem(prompt: String) -> String:
	return ("%s_%s_%s" % [provider, model.replace("/", "-"), prompt.sha256_text().substr(0, 12)])

# ---------------------------------------------------------------- playback helpers
static func _make_player(host: Control, stream: VideoStream, loop: bool) -> Node:
	var p := VideoStreamPlayer.new()
	p.stream = stream
	p.expand = true
	p.loop = loop
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(p)
	p.play()
	return p

static func _make_sheet(host: Control, path: String, loop: bool, opts: Dictionary) -> Node:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	var h: int = maxi(1, int(opts.get("hframes", 4)))
	var v: int = maxi(1, int(opts.get("vframes", 4)))
	var tex := ImageTexture.create_from_image(img)
	var fw := img.get_width() / h
	var fh := img.get_height() / v
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", loop)
	frames.set_animation_speed("default", float(opts.get("fps", 24)))
	for i in h * v:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((i % h) * fw, (i / h) * fh, fw, fh)
		frames.add_frame("default", at)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = true
	host.add_child(sprite)
	var fit := func() -> void:
		var s := host.size
		sprite.position = s * 0.5
		sprite.scale = Vector2.ONE * maxf(s.x / fw, s.y / fh)
	fit.call()
	host.resized.connect(fit)
	sprite.play("default")
	return sprite
