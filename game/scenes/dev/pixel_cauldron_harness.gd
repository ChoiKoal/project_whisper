extends SceneTree
## Pure visual invariants, no SaveManager calls, no user data writes.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var pot := Cauldron.new()
	root.add_child(pot)
	pot.set_process(false)
	var first := pot.texture
	for delta in [0.11, 0.15, 0.29, 0.16]:
		pot._process(delta)
		if pot.scale != Vector2.ONE:
			print("[FAIL] cauldron physical silhouette must retain pixel-native scale: ", pot.scale)
			failures += 1
	if pot.texture == first:
		print("[FAIL] brew animation still changes frames")
		failures += 1
	else:
		print("[PASS] brew animation still changes frames")
	var stable_id := pot.object_id
	pot._process(0.55)
	if pot.object_id != stable_id or pot.can_gather():
		print("[FAIL] cauldron interaction identity changed")
		failures += 1
	else:
		print("[PASS] cauldron identity and non-gather contract")
	pot.queue_free()
	await process_frame
	print("PIXEL_CAULDRON failures=", failures)
	quit(1 if failures else 0)
