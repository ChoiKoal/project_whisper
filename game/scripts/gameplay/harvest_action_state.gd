extends RefCounted
class_name HarvestActionState
## WH-HARVEST-001 — 채집 액션 순수 상태 모듈 (카나).
##
## 목적: 하나의 채집 행동(예약 → 접촉 → 보상 commit → 종결)의 상태를
## 단일 소유로 관리해, 연타·동시 입력·씬 전환·재진입에서도 "보상 commit은
## 액션당 정확히 1회"를 보장한다.
##
## 경계 (WH-TEAM-001 계약):
## - 순수 모듈: Node/singleton/파일 I/O/효과 실행/시간 참조 없음. 이벤트 구동.
## - Gatherable/InteractionController/GameState/Inventory/SaveManager를
##   참조하지 않는다. 통합(루비)이 이 모듈의 반환값을 보고 지급/연출을 잇는다.
## - 보상 사실의 영속화와 거래 성공 판정은 통합 계약이다. 이 모듈은
##   "commit 허가가 정확히 1회 나갔다"는 사실만 책임진다.
##
## 사용 순서: begin() → reach_contact() → take_commit() → finish().
## 취소는 commit 이전에만 유효하다. commit 이후에는 어떤 경로로도 보상을
## 되돌리거나 재허용하지 않는다 (수용 기준 A·B).

const KINDS := ["flora", "rock", "wood"]

var _active: Dictionary = {}          ## 빈 Dictionary = 활성 액션 없음
var _next_token: int = 1
var _generation: int = 1
var _in_transition: bool = false      ## 같은 콜스택 재진입 가드
var _last: Dictionary = {}
var _counters := {
	"begun": 0, "rejected": 0, "contacts": 0, "commits": 0,
	"cancels": 0, "finishes": 0, "resets": 0,
	"auto_cancels": 0, "supersede_finishes": 0,
}
## 테스트 seam: commit 확정 직후(반환 전) 호출된다. 하네스가 재진입 방지를
## 검증하는 용도로만 쓴다. 게임 코드는 이 훅에 로직을 걸지 않는다.
var transition_hook: Callable = Callable()

func _reject(reason: String) -> Dictionary:
	_counters["rejected"] += 1
	return {"ok": false, "reason": reason}

func _is_stale(token: int) -> bool:
	return _active.is_empty() or _active["token"] != token

func _close(phase: String, reward_granted: bool, reason: String) -> void:
	_last = {
		"token": _active["token"], "target_key": _active["target_key"],
		"kind": _active["kind"], "phase": phase,
		"reward_granted": reward_granted, "reason": reason,
	}
	_active = {}

## 액션 예약. target_key는 외부가 만드는 world/target/respawn 세대 식별자
## (예: "l1:rock:14:gen2"). Node 참조를 받지 않는다.
func begin(target_key: String, material_kind: String) -> Dictionary:
	if _in_transition:
		return _reject("reentrant_call")
	if target_key == "":
		return _reject("invalid_target")
	if not KINDS.has(material_kind):
		return _reject("unknown_kind")
	if not _active.is_empty():
		if _active["target_key"] == target_key:
			# 연타/터치+클릭 동시 입력: 같은 대상 재예약 금지 (수용 기준 A)
			return _reject("already_active_same_target")
		# 대상 교체: 미commit → 자동 취소 / commit됨 → 보상 유지한 채 종결.
		# 빠른 연속 채집을 막지 않으면서 commit 불변성을 지킨다.
		if _active["committed"]:
			_counters["supersede_finishes"] += 1
			_counters["finishes"] += 1
			_close("done", true, "superseded")
		else:
			_counters["auto_cancels"] += 1
			_counters["cancels"] += 1
			_close("cancelled", false, "superseded")
	var token := _next_token
	_next_token += 1
	_active = {
		"token": token, "target_key": target_key, "kind": material_kind,
		"phase": "reserved", "committed": false, "generation": _generation,
	}
	_counters["begun"] += 1
	return {"ok": true, "token": token, "reason": ""}

## 예비 동작이 실제 접촉 프레임에 닿았을 때 통합이 호출한다.
func reach_contact(token: int) -> Dictionary:
	if _in_transition:
		return _reject("reentrant_call")
	if _is_stale(token):
		return _reject("stale_token")
	if _active["phase"] == "contact":
		return _reject("already_in_contact")
	if _active["phase"] != "reserved":
		return _reject("wrong_order")
	_active["phase"] = "contact"
	_counters["contacts"] += 1
	return {"ok": true, "reason": ""}

## 보상 commit 허가. 액션당 정확히 1회만 granted=true.
## 상태를 반환/훅 호출 이전에 원자적으로 확정해 재진입 중복을 차단한다.
func take_commit(token: int) -> Dictionary:
	if _in_transition:
		var r := _reject("reentrant_call"); r["granted"] = false; return r
	if _is_stale(token):
		var r := _reject("stale_token"); r["granted"] = false; return r
	if _active["committed"]:
		var r := _reject("already_committed"); r["granted"] = false; return r
	if _active["phase"] != "contact":
		var r := _reject("wrong_order"); r["granted"] = false; return r
	_in_transition = true
	_active["committed"] = true
	_active["phase"] = "committed"
	_counters["commits"] += 1
	if transition_hook.is_valid():
		transition_hook.call("committed")
	_in_transition = false
	return {"ok": true, "granted": true, "reason": ""}

## commit 이전에만 유효. 취소된 액션은 보상 0 (수용 기준 B).
func cancel(token: int) -> Dictionary:
	if _in_transition:
		return _reject("reentrant_call")
	if _is_stale(token):
		return _reject("stale_token")
	if _active["committed"]:
		return _reject("cannot_cancel_after_commit")
	_counters["cancels"] += 1
	_close("cancelled", false, "cancelled")
	return {"ok": true, "reason": ""}

## 액션 종결. commit 여부를 reward_granted로 되돌려준다 —
## 연출이 중간에 끊겨 commit 전에 finish되면 지급하지 않는 근거값이다.
func finish(token: int) -> Dictionary:
	if _in_transition:
		var r := _reject("reentrant_call"); r["reward_granted"] = false; return r
	if _is_stale(token):
		var r := _reject("stale_token"); r["reward_granted"] = false; return r
	var granted: bool = _active["committed"]
	_counters["finishes"] += 1
	_close("done", granted, "finished")
	return {"ok": true, "reward_granted": granted, "reason": ""}

## 씬 전환/앱 중단/세이브 개입 시 통합이 호출한다. 모든 토큰을 무효화한다.
## committed-unfinished였다면 was_committed_unfinished=true — 보상은 이미
## commit 시점에 통합으로 나갔으므로 되돌리지 않는다 (수용 기준 B·C).
func reset(reason: String) -> Dictionary:
	var had := not _active.is_empty()
	var committed_unfinished: bool = had and _active["committed"]
	if had:
		var phase := "done" if committed_unfinished else "cancelled"
		_close(phase, committed_unfinished, "reset:" + reason)
	_generation += 1
	_counters["resets"] += 1
	return {"had_active": had, "was_committed_unfinished": committed_unfinished}

## 검증용 직렬화 가능 상태. 원시 타입만 반환한다.
func inspect_state() -> Dictionary:
	return {
		"version": 1,
		"generation": _generation,
		"active": _active.duplicate(true) if not _active.is_empty() else null,
		"last": _last.duplicate(true) if not _last.is_empty() else null,
		"counters": _counters.duplicate(true),
	}
