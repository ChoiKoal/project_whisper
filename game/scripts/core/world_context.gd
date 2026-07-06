extends Node
## WorldContext — global autoload (v0.5.0 phase C). Tracks WHICH world scene the player
## is currently in and carries the intent for a scene change (portal travel / return).
##
## Multi-scene architecture: the game now has TWO playable worlds —
##   • "home"  = 제0세계 (home_island.tscn) — the player's own empty world, the hub.
##   • "grove" = 시작의 숲 (starting_grove.tscn) — Layer 1, reached through a portal.
## Each world's runtime state (placed objects, gathered/VOID tiles, gates, player pos) is
## snapshotted per-scene-id by SaveManager (see WORLD state dict). This singleton names
## the current scene and the transient "where to spawn on arrival" hint so a scene, on
## boot, knows whether to place the player on its default spawn or a portal-arrival point.
##
## Headless-safe: pure state, no scene/tree dependency; the harness sets/reads it directly.

const SCENE_HOME := "home"
const SCENE_GROVE := "grove"
## (L2-5) Layer-2 「꺼진 관문 기지」 — the science portal destination.
const SCENE_TERMINAL := "terminal_station"
## (L3-5) Layer-3 「태엽이 멈춘 도시」 — the machine portal destination. Value matches the literal
## clockwork_city.gd sets on WorldContext.current_scene, so the save snapshot round-trips.
const SCENE_CLOCKWORK := "clockwork_city"
## (L4-5) Layer-4 「봉인이 풀린 마탑」 — the magic portal destination. Value matches the literal
## mage_tower.gd sets on WorldContext.current_scene, so the save snapshot round-trips.
const SCENE_MAGE_TOWER := "mage_tower"
## (L5-5) Layer-5 「응답 없는 대성당」 — the divinity portal destination (마지막 레이어). Value matches
## the literal cathedral.gd sets on WorldContext.current_scene, so the save snapshot round-trips.
const SCENE_CATHEDRAL := "cathedral"

const HOME_SCENE_PATH := "res://scenes/world/home_island.tscn"
const GROVE_SCENE_PATH := "res://scenes/world/starting_grove.tscn"
const TERMINAL_SCENE_PATH := "res://scenes/world/terminal_station.tscn"
const CLOCKWORK_SCENE_PATH := "res://scenes/world/clockwork_city.tscn"
const MAGE_TOWER_SCENE_PATH := "res://scenes/world/mage_tower.tscn"
const CATHEDRAL_SCENE_PATH := "res://scenes/world/cathedral.tscn"

## The scene id the player is currently in ("home" at the start of a new game). Set by each
## world scene's session node on boot; read by SaveManager to key the world snapshot.
var current_scene: String = SCENE_HOME

## Arrival intent for the NEXT scene load. "" = use the scene's own default spawn cell.
## "portal_arrival" = a portal brought the player here (grove: land at the pond; home:
## land back at the return spot near the dais). Cleared by the scene once consumed.
var arrival_mode: String = ""

## When a portal travel is in flight, the layer id being entered ("nature" etc.). Lets the
## destination scene / return portal know which world it belongs to. "" when not travelling.
var travel_layer: String = ""


## Map a scene id to its .tscn path.
func scene_path(scene_id: String) -> String:
	match scene_id:
		SCENE_HOME: return HOME_SCENE_PATH
		SCENE_GROVE: return GROVE_SCENE_PATH
		SCENE_TERMINAL: return TERMINAL_SCENE_PATH
		SCENE_CLOCKWORK: return CLOCKWORK_SCENE_PATH
		SCENE_MAGE_TOWER: return MAGE_TOWER_SCENE_PATH
		SCENE_CATHEDRAL: return CATHEDRAL_SCENE_PATH
	return GROVE_SCENE_PATH


## (L2-5) Map a portal layer id to the world scene it opens. nature→grove, science→terminal,
## machine→clockwork_city (L3-5), magic→mage_tower (L4-5), divinity→cathedral (L5-5).
func layer_scene(layer: String) -> String:
	match layer:
		"science": return SCENE_TERMINAL
		"nature": return SCENE_GROVE
		"machine": return SCENE_CLOCKWORK
		"magic": return SCENE_MAGE_TOWER
		"divinity": return SCENE_CATHEDRAL
	return SCENE_GROVE


## Reset to the new-game baseline (start in the home world, default spawn).
func reset() -> void:
	current_scene = SCENE_HOME
	arrival_mode = ""
	travel_layer = ""


func to_dict() -> Dictionary:
	return {
		"current_scene": current_scene,
		"arrival_mode": arrival_mode,
		"travel_layer": travel_layer,
	}


func from_dict(data: Dictionary) -> void:
	current_scene = String(data.get("current_scene", SCENE_HOME))
	arrival_mode = String(data.get("arrival_mode", ""))
	travel_layer = String(data.get("travel_layer", ""))
