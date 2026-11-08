class_name VideoApiClient
extends Node
## Minimal client for the Revana video API (https://api.revana.si/v1).
## Flow: POST /generations -> poll GET /generations/{id} -> GET /generations/{id}/content (302 to a signed URL).

signal status_changed(id: String, status: String)
signal finished(id: String, path: String)
signal failed(id: String, message: String)

const BASE_URL := "https://api.revana.si/v1"
const POLL_SECONDS := 5.0
const MAX_WAIT_SECONDS := 25 * 60

var api_key := ""
var model := "minimax-h3-free"

## One HTTP request. Returns {ok, code, headers, body}. Redirects are followed only when `follow` is true.
func _http(method: int, url: String, headers: PackedStringArray, body := "", follow := true) -> Dictionary:
	var req := HTTPRequest.new()
	req.max_redirects = 8 if follow else 0
	req.timeout = 120.0
	add_child(req)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "headers": PackedStringArray(), "body": PackedByteArray(), "error": "request error %d" % err}
	var res: Array = await req.request_completed
	req.queue_free()
	var code: int = res[1]
	return {"ok": code >= 200 and code < 400, "code": code, "headers": res[2], "body": res[3], "result": res[0]}

func _auth() -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer %s" % api_key, "Content-Type: application/json"])

static func _header(headers: PackedStringArray, name: String) -> String:
	var prefix := name.to_lower() + ":"
	for h in headers:
		if h.to_lower().begins_with(prefix):
			return h.substr(prefix.length()).strip_edges()
	return ""

static func _json(body: PackedByteArray) -> Dictionary:
	var v = JSON.parse_string(body.get_string_from_utf8())
	return v if v is Dictionary else {}

func _error_text(r: Dictionary) -> String:
	var e = _json(r.body).get("error")
	if e is Dictionary and str(e.get("message", "")) != "":
		return str(e.get("message"))
	return "HTTP %d" % r.code

## Lists the video models (no API key needed). Returns an Array of model ids, free ones first.
func fetch_models() -> Array:
	var r := await _http(HTTPClient.METHOD_GET, BASE_URL + "/models", PackedStringArray())
	var out: Array = []
	if not r.ok:
		return out
	var free: Array = []
	for m in _json(r.body).get("data", []):
		if m is Dictionary and m.get("kind") == "video" and ("text_to_video" in m.get("tasks", []) or "image_to_video" in m.get("tasks", [])):
			var price = m.get("price", {})
			if price is Dictionary and price.get("free", false):
				free.append(m.id)
			else:
				out.append(m.id)
	free.append_array(out)
	return free

## Starts a generation and waits for the result. Emits `finished` with the saved file path or `failed`.
func generate(prompt: String, duration := 5, aspect_ratio := "16:9", resolution := "480p") -> void:
	if api_key.strip_edges() == "":
		failed.emit("", "Add your API key first.")
		return
	var body := JSON.stringify({"model": model, "input": {"prompt": prompt, "duration": duration, "resolution": resolution, "aspect_ratio": aspect_ratio}})
	var headers := _auth()
	headers.append("Idempotency-Key: gs-%d-%d" % [Time.get_unix_time_from_system(), randi()])
	var r := await _http(HTTPClient.METHOD_POST, BASE_URL + "/generations", headers, body)
	if not r.ok:
		failed.emit("", _error_text(r))
		return
	var id: String = str(_json(r.body).get("id", ""))
	if id == "":
		failed.emit("", "The API returned no generation id.")
		return
	status_changed.emit(id, "queued")

	var waited := 0.0
	while waited < MAX_WAIT_SECONDS:
		await get_tree().create_timer(POLL_SECONDS).timeout
		waited += POLL_SECONDS
		var p := await _http(HTTPClient.METHOD_GET, "%s/generations/%s" % [BASE_URL, id], _auth())
		if not p.ok:
			continue # transient network error: keep polling
		var g := _json(p.body)
		var status := str(g.get("status", ""))
		status_changed.emit(id, status)
		if status == "succeeded":
			await _download(id)
			return
		if status == "failed" or status == "cancelled":
			var e = g.get("error", {})
			failed.emit(id, str(e.get("message", status)) if e is Dictionary else status)
			return
	failed.emit(id, "Timed out waiting for the video.")

## The content endpoint answers 302 to a signed storage URL. That URL must be fetched WITHOUT the
## Authorization header, so the redirect is followed by hand.
func _download(id: String) -> void:
	var r := await _http(HTTPClient.METHOD_GET, "%s/generations/%s/content" % [BASE_URL, id], _auth(), "", false)
	var url := _header(r.headers, "location")
	var data: PackedByteArray = r.body
	if url != "":
		var d := await _http(HTTPClient.METHOD_GET, url, PackedStringArray())
		if not d.ok:
			failed.emit(id, "Download failed (HTTP %d)." % d.code)
			return
		data = d.body
	elif r.code != 200:
		failed.emit(id, "Could not get the video file: " + _error_text(r))
		return
	DirAccess.make_dir_recursive_absolute("user://videos")
	var path := "user://videos/%s.mp4" % id
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		failed.emit(id, "Could not save the file.")
		return
	f.store_buffer(data)
	f.close()
	finished.emit(id, path)
