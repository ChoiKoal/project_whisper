extends Node
## WH-UNIT15 (QA) — isolated check of hover_timing_probe's evidence sink.
##
## The probe itself cannot complete headless (it awaits RenderingServer.frame_post_draw
## and warps the mouse), so screen/input timing stays BLOCKED. The evidence sink is
## separable, and this fixture exercises write_evidence() alone.
##
## ---------------------------------------------------------------------------
## Why the probe instance is NEVER added to the tree
##
## hover_timing_probe._ready() does call_deferred("run"), and run() calls
## SaveManager.new_game_for_layout() and builds a world. Parenting the instance —
## even briefly, even with a queue_free() afterwards — SCHEDULES that whole path:
## a later free cannot cancel an already-deferred call. write_evidence() has no Node
## dependency, so the instance is created unparented, used, and freed immediately.
##
## Scope: QA test code only; no production script is modified by this file. It writes
## exclusively inside FDN_SINK_TMP and refuses to run without it — there is no
## user:// fallback, because a fallback is exactly how a "sink test" would end up
## writing into a real user directory.

const PROBE := preload("res://scenes/dev/hover_timing_probe.gd")

var _fail := 0
var _ran: Array[String] = []

const EXPECTED := [
	"unset", "relative", "missing_dir",
	"happy_path", "readback_exact",
	"open_failure", "readonly_dir_refused",
]


func _ready() -> void:
	_run()
	_report()


func _check(id: String, ok: bool, detail: String) -> void:
	_ran.append(id)
	print(("[PASS] " if ok else "[FAIL] ") + id + " — " + detail)
	if not ok:
		_fail += 1


## Explicit isolation root. No fallback: without it the fixture refuses to run.
func _tmp_root() -> String:
	var v := OS.get_environment("FDN_SINK_TMP").strip_edges()
	if v.is_empty() or not v.is_absolute_path():
		return ""
	return v.trim_suffix("/")


func _run() -> void:
	var root := _tmp_root()
	if root.is_empty():
		print("[BLOCKED] setup — FDN_SINK_TMP must be an absolute isolation path; refusing to run")
		_fail += 1
		return

	# Unparented on purpose. See the header note.
	var probe: Node = PROBE.new()
	var sample: Array = [{"phase": "sink_fixture", "n": 1}]
	var payload := JSON.stringify(sample, "\t")

	# ---- refusal paths ----
	var had_root := FileAccess.file_exists("/timing.json")
	OS.set_environment("FDN_EVIDENCE", "")
	var r_unset: bool = probe.write_evidence(sample)
	var made_root := FileAccess.file_exists("/timing.json") and not had_root
	_check("unset", r_unset == false and not made_root,
		"unset refused=%s stray_root_file=%s" % [not r_unset, made_root])

	OS.set_environment("FDN_EVIDENCE", "relative/dir")
	_check("relative", probe.write_evidence(sample) == false, "relative path refused")

	var missing := root + "/absent_%d" % Time.get_ticks_usec()
	OS.set_environment("FDN_EVIDENCE", missing)
	_check("missing_dir", probe.write_evidence(sample) == false, "nonexistent dir refused")

	# ---- forced open failure: make timing.json itself a directory ----
	var blocked := root + "/blocked_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(blocked + "/timing.json")
	OS.set_environment("FDN_EVIDENCE", blocked)
	_check("open_failure", probe.write_evidence(sample) == false,
		"open() failure (target path is a directory) refused, no crash")

	# ---- read-only directory ----
	# NOTE: on this platform the refusal happens at open(), not at store_string().
	# So this case proves "read-only dir is refused, not silently accepted"; it does
	# NOT demonstrate the post-store write/flush failure branch. That branch stays
	# unverified — see not_verified in the results JSON.
	var ro := root + "/ro_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ro)
	OS.execute("chmod", ["555", ro])
	OS.set_environment("FDN_EVIDENCE", ro)
	var ro_result: bool = probe.write_evidence(sample)
	OS.execute("chmod", ["755", ro])
	_check("readonly_dir_refused", ro_result == false,
		"read-only evidence dir refused at open() (store/flush branch NOT covered)")

	# ---- happy path + exact readback ----
	var good := root + "/ok_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(good)
	OS.set_environment("FDN_EVIDENCE", good)
	_check("happy_path", probe.write_evidence(sample), "valid dir accepted")

	var path := good + "/timing.json"
	var text := ""
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			text = f.get_as_text()
			f.close()
	# Compare the whole payload, not just one field.
	_check("readback_exact", text == payload,
		"file bytes identical to intended payload (%d vs %d)" % [text.length(), payload.length()])

	probe.free()   # never entered the tree, so a direct free is correct


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
