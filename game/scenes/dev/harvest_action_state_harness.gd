extends Node
## WH-HARVEST-001 — HarvestActionState 계약 하네스 (카나).
## 실행: godot4 --headless game/scenes/dev/harvest_action_state_harness.tscn
## 종료 코드 = 실패 수. 파이썬 참조 모델 테스트와 케이스 1:1.
## 주의: 이 하네스는 순수 상태 계약 검증이다. 실게임 QA(WH-QA-001)가 아니다.

var _fails: PackedStringArray = []

func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		_fails.append(name)

func _ready() -> void:
	_run_all()
	print("")
	if _fails.size() > 0:
		print("RESULT: FAIL %d건 — %s" % [_fails.size(), ", ".join(_fails)])
	else:
		print("RESULT: ALL GREEN")
	get_tree().quit(_fails.size())

func _run_all() -> void:
	# 정상 경로
	var s := HarvestActionState.new()
	var r := s.begin("flower:az:gen1", "flora")
	_check("begin ok", r["ok"] and r["token"] == 1)
	var t: int = r["token"]
	_check("contact ok", s.reach_contact(t)["ok"])
	var c := s.take_commit(t)
	_check("commit granted 1회", c["ok"] and c["granted"])
	var c2 := s.take_commit(t)
	_check("commit 2회차 거부", (not c2["ok"]) and (not c2["granted"]) and c2["reason"] == "already_committed")
	var f := s.finish(t)
	_check("finish reward_granted", f["ok"] and f["reward_granted"])

	# 잘못된 순서
	s = HarvestActionState.new()
	t = s.begin("rock:b1:gen1", "rock")["token"]
	_check("contact 전 commit 거부", not s.take_commit(t)["ok"])
	_check("contact ok", s.reach_contact(t)["ok"])
	_check("contact 중복 거부", s.reach_contact(t)["reason"] == "already_in_contact")

	# 취소 정책
	s = HarvestActionState.new()
	t = s.begin("rock:b1:gen1", "rock")["token"]
	_check("접촉 전 cancel = 미지급", s.cancel(t)["ok"])
	_check("cancel 후 finish 거부", not s.finish(t)["ok"])
	s = HarvestActionState.new()
	t = s.begin("rock:b1:gen1", "rock")["token"]
	s.reach_contact(t); s.take_commit(t)
	_check("commit 후 cancel 거부", s.cancel(t)["reason"] == "cannot_cancel_after_commit")
	_check("commit 후 finish는 지급 유지", s.finish(t)["reward_granted"])

	# commit 없이 finish = 미지급
	s = HarvestActionState.new()
	t = s.begin("wood:t3:gen1", "wood")["token"]
	s.reach_contact(t)
	f = s.finish(t)
	_check("commit 없이 finish = reward 없음", f["ok"] and not f["reward_granted"])

	# 연타/동시 입력 (같은 대상)
	s = HarvestActionState.new()
	t = s.begin("flower:az:gen1", "flora")["token"]
	var r2 := s.begin("flower:az:gen1", "flora")
	_check("같은 대상 재begin 거부", (not r2["ok"]) and r2["reason"] == "already_active_same_target")
	_check("원 액션 토큰 유효", s.reach_contact(t)["ok"])

	# 대상 교체
	s = HarvestActionState.new()
	var t1: int = s.begin("flower:a:g1", "flora")["token"]
	r2 = s.begin("rock:b:g1", "rock")
	_check("교체 begin 허용", r2["ok"])
	_check("이전 토큰 stale", s.reach_contact(t1)["reason"] == "stale_token")
	_check("교체 시 이전은 auto_cancel 집계", s.inspect_state()["counters"]["auto_cancels"] == 1)

	# commit 후 대상 교체: 보상 불변
	s = HarvestActionState.new()
	t1 = s.begin("flower:a:g1", "flora")["token"]
	s.reach_contact(t1); s.take_commit(t1)
	r2 = s.begin("rock:b:g1", "rock")
	_check("commit 후 교체 begin 허용", r2["ok"])
	var st := s.inspect_state()
	_check("commit분은 supersede_finish로 닫힘", st["counters"]["supersede_finishes"] == 1)
	_check("commit 수 불변", st["counters"]["commits"] == 1)

	# stale token / unknown kind / invalid target
	s = HarvestActionState.new()
	_check("unknown kind 거부", s.begin("x:y:g1", "slime")["reason"] == "unknown_kind")
	_check("빈 target 거부", s.begin("", "flora")["reason"] == "invalid_target")
	t = s.begin("a:b:g1", "flora")["token"]
	_check("위조 토큰 거부", s.reach_contact(t + 999)["reason"] == "stale_token")

	# reset (앱 중단/씬 전환)
	s = HarvestActionState.new()
	t = s.begin("a:b:g1", "flora")["token"]
	s.reach_contact(t); s.take_commit(t)
	var rr := s.reset("scene_change")
	_check("reset: committed-unfinished 보고", rr["had_active"] and rr["was_committed_unfinished"])
	_check("reset 후 구 토큰 stale", s.reach_contact(t)["reason"] == "stale_token")
	var t2: int = s.begin("a:b:g2", "flora")["token"]
	_check("reset 후 새 begin 정상", t2 > t)

	# finish 후 재시작
	s = HarvestActionState.new()
	t = s.begin("a:b:g1", "flora")["token"]
	s.reach_contact(t); s.take_commit(t); s.finish(t)
	_check("finish 후 같은 대상 재시작 허용", s.begin("a:b:g1", "flora")["ok"])

	# 같은 frame 재진입 (commit 훅 중 중첩 호출)
	s = HarvestActionState.new()
	t = s.begin("a:b:g1", "flora")["token"]
	s.reach_contact(t)
	var nested := {}
	var st_ref := s
	var tok := t
	s.transition_hook = func(_phase: String) -> void:
		nested["r"] = st_ref.take_commit(tok)
	c = s.take_commit(t)
	_check("재진입: 외부 commit granted", c["granted"])
	_check("재진입: 중첩 commit 거부",
		nested.has("r") and (nested["r"]["reason"] == "reentrant_call" or nested["r"]["reason"] == "already_committed"))

	# inspect_state 직렬화
	s = HarvestActionState.new()
	s.begin("a:b:g1", "flora")
	var json := JSON.stringify(s.inspect_state())
	_check("inspect_state 직렬화 가능", json != "")
