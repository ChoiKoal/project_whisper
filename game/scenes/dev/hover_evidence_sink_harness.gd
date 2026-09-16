extends Node
## WH-UNIT15 (QA) — isolated check of hover_timing_probe's evidence sink.
##
## The probe itself cannot complete headless: it awaits RenderingServer.frame_post_draw
## and warps the mouse, so screen/input timing stays BLOCKED. The evidence-writing
## function is separable from that, so this fixture exercises write_evidence() alone
## and leaves the timing behaviour untested.
##
## Scope: QA test code only. No production script is modified by this file.
## It writes exclusively inside FDN_SINK_TMP (or user://) and never touches a save.

const PROBE := preload("res://scenes/dev/hover_timing_probe.gd")

var _fail := 0
var _ran: Array[String] = []

## Every case this fixture intends to report. A missing id means the run aborted and
## must not read as success.
const EXPECTED := ["unset", "relative", "missing_dir", "happy_path", "readback_match"]


func _ready() -> void:
	_run()
	_report()


func _check(id: String, ok: bool, detail: String) -> void:
	_ran.append(id)
	print(("[PASS] " if ok else "[FAIL] ") + id + " — " + detail)
	if not ok:
		_fail += 1


func _tmp_root() -> String:
	var v := OS.get_environment("FDN_SINK_TMP").strip_edges()
	if not v.is_empty() and v.is_absolute_path():
		return v.trim_suffix("/")
	return ProjectSettings.globalize_path("user://")


func _run() -> void:
	var probe := PROBE.new()
	add_child(probe)
	var sample: Array = [{"phase": "sink_fixture", "n": 1}]

	# --- failure paths: each must refuse, and none may create a stray file ---
	var had_root := FileAccess.file_exists("/timing.json")
	OS.set_environment("FDN_EVIDENCE", "")
	var r_unset: bool = probe.write_evidence(sample)
	var made_root := FileAccess.file_exists("/timing.json") and not had_root
	_check("unset", r_unset == false and not made_root,
		"unset FDN_EVIDENCE refused=%s stray_root_file=%s" % [not r_unset, made_root])

	OS.set_environment("FDN_EVIDENCE", "relative/dir")
	_check("relative", probe.write_evidence(sample) == false, "relative path refused")

	var missing := _tmp_root() + "/wh_sink_absent_%d" % Time.get_ticks_usec()
	OS.set_environment("FDN_EVIDENCE", missing)
	_check("missing_dir", probe.write_evidence(sample) == false, "nonexistent dir refused")

	# --- happy path: must write AND the bytes must survive a readback ---
	var good := _tmp_root() + "/wh_sink_ok_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(good)
	OS.set_environment("FDN_EVIDENCE", good)
	var wrote: bool = probe.write_evidence(sample)
	_check("happy_path", wrote, "valid dir accepted")

	var path := good + "/timing.json"
	var text := ""
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			text = f.get_as_text()
			f.close()
	var parsed: Variant = JSON.parse_string(text)
	var match_ok: bool = parsed is Array and (parsed as Array).size() == 1 \
		and (parsed as Array)[0].get("phase", "") == "sink_fixture"
	_check("readback_match", match_ok,
		"file parses back to the written payload (bytes=%d)" % text.length())

	probe.queue_free()


func _report() -> void:
	var missing: Array[String] = []
	for id in EXPECTED:
		if not _ran.has(id):
			missing.append(id)
	print("SINK_FIXTURE failures=%d missing=%d" % [_fail, missing.size()])
	if missing.size() > 0:
		print("!! RUN INVALID — cases produced no row: %s" % [", ".join(missing)])
		get_tree().quit(2)
		return
	print("SINK_FIXTURE_DONE")
	get_tree().quit(1 if _fail else 0)
