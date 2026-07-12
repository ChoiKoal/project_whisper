extends Node
## v1.10.0 L0 허브 확장 — 히어로 프리뷰(아치+다이스 줌인). 승인된 포탈 아치 구도가
## 확장 후에도 불변임을 시각적으로 검수하기 위한 줌인 샷: 5기 포탈 아치(P3 최상단 중앙)
## + 중앙 다이스(스폰) 제단을 프레임에 채운다. 세계층 방향성 데코(잎/데이터/태엽/서고/종)
## 도 아치 주변에 들어와 §㉙ 변주·§㉛ 목표물 대비를 검수할 수 있다. Run headless:
##   Godot --headless res://scenes/dev/home_hero_render.tscn

const OUT := "/workspace/group/preview-home-hero.png"
const HOME := "res://scenes/world/home_island.tscn"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(1400, 1000)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var scene: Node = load(HOME).instantiate()
	vp.add_child(scene)
	for i in range(6):
		await get_tree().process_frame

	# 아치를 돋보이게: 전 포탈 flickering(점등 직전) 상태로 5기 모두 은은히 빛나게.
	for lay in ["nature", "science", "machine", "magic", "divinity"]:
		GameState.set_portal_state(lay, GameState.PORTAL_FLICKERING)

	var loader := scene.get_node("Ground") as MapLoader
	# 아치 정점 P3(10,3)와 다이스 스폰(10,9)의 중점 근처를 프레임 중심으로.
	var top := loader.cell_center_world(loader.portal_cells.get("machine", Vector2i(10, 3)))
	var dice := loader.cell_center_world(loader.spawn_cell)
	var center := (top + dice) * 0.5

	var pcam := scene.get_node_or_null("YSortLayer/Player/Camera2D") as Camera2D
	if pcam != null:
		pcam.enabled = false
	var cam := Camera2D.new()
	cam.position = center
	# 줌인: 아치 폭(P1..P5 ≈ 768px) + 다이스 제단이 프레임을 채우도록.
	cam.zoom = Vector2(0.95, 0.95)
	scene.add_child(cam)
	cam.make_current()

	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	if img == null:
		push_error("home_hero: null viewport image")
		get_tree().quit(1)
		return
	var err := img.save_png(OUT)
	print("home hero saved: %s (err=%d) size=%s" % [OUT, err, img.get_size()])
	get_tree().quit(0 if err == OK else 1)
