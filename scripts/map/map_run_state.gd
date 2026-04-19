extends Node
class_name MapRunState

signal run_started(run_data: MapRunData)
signal run_updated(run_data: MapRunData)
signal node_visited(node_data: MapNodeData)
signal node_resolution_requested(node_data: MapNodeData, resolution: Dictionary)
signal node_resolution_completed(node_data: MapNodeData, resolution: Dictionary)
signal run_failed(node_data: MapNodeData, resolution: Dictionary)
signal dungeon_cleared(node_data: MapNodeData, resolution: Dictionary)

const RESOLUTION_MOVE := &"move"
const RESOLUTION_BATTLE := &"battle"
const RESOLUTION_RESOURCE := &"resource"
const RESOLUTION_EVENT := &"event"
const RESOLUTION_FAILED := &"failed"
const RESOLUTION_DUNGEON_CLEAR := &"dungeon_clear"
const BATTLE_NORMAL := &"normal"
const BATTLE_ELITE := &"elite"
const BATTLE_BOSS := &"boss"
const EVENT_GOLD_CACHE := &"gold_cache"
const EVENT_MATERIAL_STASH := &"material_stash"
const EVENT_SKILL_BOOK := &"skill_book"
const EVENT_MINOR_PENALTY := &"minor_penalty"
const DEFAULT_SKILL_REWARD_PATH := "res://data/skills/brace.tres"

var run_data: MapRunData
var pending_node_id: int = -1
var pending_resolution: Dictionary = {}


func has_active_run() -> bool:
	return run_data != null and not run_data.nodes.is_empty()


func create_new_run(generator: MapGenerator, config: Dictionary = {}, seed: int = 0) -> MapRunData:
	run_data = generator.generate_run(seed, config)
	run_data.initialize_node_visibility()
	pending_node_id = -1
	pending_resolution.clear()
	emit_signal("run_started", run_data)
	emit_signal("run_updated", run_data)
	return run_data


func set_run_data(value: MapRunData) -> void:
	run_data = value
	if run_data != null:
		run_data.initialize_node_visibility()
	pending_node_id = -1
	pending_resolution.clear()
	emit_signal("run_updated", run_data)


func clear_run() -> void:
	run_data = null
	pending_node_id = -1
	pending_resolution.clear()


func get_run_data() -> MapRunData:
	return run_data


func get_current_node() -> MapNodeData:
	if not has_active_run():
		return null

	return run_data.get_node_by_id(run_data.current_node_id)


func get_reachable_node_ids() -> Array[int]:
	if not has_active_run():
		return []

	return run_data.get_available_node_ids()


func can_travel_to(node_id: int) -> bool:
	return has_active_run() and run_data.can_move_to(node_id)


func can_move_to_node(node_id: int) -> bool:
	return has_active_run() and run_data.can_move_to(node_id)


func should_resolve_node(node_id: int) -> bool:
	return has_active_run() and run_data.can_move_to(node_id) and run_data.should_resolve_node(node_id)


func move_to_node(node_id: int) -> bool:
	if not has_active_run():
		return false

	var moved: bool = run_data.move_to_node(node_id)
	if moved:
		emit_signal("run_updated", run_data)

	return moved


func mark_node_visited(node_id: int) -> bool:
	if not can_travel_to(node_id):
		return false

	run_data.mark_node_visited(node_id)
	emit_signal("node_visited", run_data.get_node_by_id(node_id))
	emit_signal("run_updated", run_data)
	return true


func set_pending_node(node_id: int) -> void:
	pending_node_id = node_id
	if run_data != null:
		var node_data: MapNodeData = run_data.get_node_by_id(node_id)
		if node_data != null:
			pending_resolution = resolve_node_by_type(node_data)
			return

	pending_resolution.clear()


func clear_pending_node() -> void:
	pending_node_id = -1
	pending_resolution.clear()


func commit_pending_node() -> void:
	if pending_node_id == -1:
		return

	var node_id: int = pending_node_id
	pending_node_id = -1
	pending_resolution.clear()
	mark_node_visited(node_id)


func get_pending_resolution() -> Dictionary:
	return pending_resolution.duplicate(true)


func resolve_selected_node(node_id: int) -> Dictionary:
	if not has_active_run() or not can_travel_to(node_id):
		return {}

	var node_data: MapNodeData = run_data.get_node_by_id(node_id)
	if node_data == null:
		return {}

	if not should_resolve_node(node_id):
		var moved: bool = move_to_node(node_id)
		return {
			"kind": RESOLUTION_MOVE,
			"node_id": node_id,
			"moved": moved,
		}

	pending_node_id = node_id
	pending_resolution = resolve_node_by_type(node_data)
	emit_signal("node_resolution_requested", node_data, pending_resolution)
	return get_pending_resolution()


func resolve_node_by_type(node_data: MapNodeData) -> Dictionary:
	match node_data.node_type:
		MapNodeData.TYPE_COMBAT:
			return _build_battle_resolution(node_data, BATTLE_NORMAL, 6, ExpeditionState.RESOURCE_MONSTER_MATERIALS, 1, false)
		MapNodeData.TYPE_ELITE:
			return _build_battle_resolution(node_data, BATTLE_ELITE, 18, ExpeditionState.RESOURCE_MONSTER_MATERIALS, 3, false)
		MapNodeData.TYPE_BOSS:
			return _build_battle_resolution(node_data, BATTLE_BOSS, 40, ExpeditionState.RESOURCE_ORES, 3, true)
		MapNodeData.TYPE_RESOURCE:
			return {
				"kind": RESOLUTION_RESOURCE,
				"node_id": node_data.id,
				"node_type": node_data.node_type,
				"title": "Salvage Cache",
				"reward_gold": 0,
				"reward_resource_type": ExpeditionState.RESOURCE_MONSTER_MATERIALS,
				"reward_resource_amount": 2 + int(max(0, node_data.row / 3)),
				"reward_skill_path": "",
				"penalty_gold": 0,
			}
		MapNodeData.TYPE_EVENT:
			return _build_event_resolution(node_data)
		_:
			return {
				"kind": RESOLUTION_MOVE,
				"node_id": node_data.id,
				"moved": false,
			}


func complete_pending_resolution() -> Dictionary:
	if pending_node_id == -1:
		return {}

	var node_data: MapNodeData = run_data.get_node_by_id(pending_node_id) if run_data != null else null
	var completed_resolution: Dictionary = get_pending_resolution()
	commit_pending_node()

	if node_data != null:
		emit_signal("node_resolution_completed", node_data, completed_resolution)

	return completed_resolution


func resolve_pending_battle_victory() -> Dictionary:
	if pending_node_id == -1:
		return {}

	var node_data: MapNodeData = run_data.get_node_by_id(pending_node_id) if run_data != null else null
	var completed_resolution: Dictionary = get_pending_resolution()
	commit_pending_node()

	if node_data == null:
		return completed_resolution

	if bool(completed_resolution.get("clears_dungeon", false)):
		emit_signal("dungeon_cleared", node_data, completed_resolution)
	else:
		emit_signal("node_resolution_completed", node_data, completed_resolution)

	return completed_resolution


func resolve_pending_battle_defeat() -> Dictionary:
	if pending_node_id == -1:
		return {}

	var node_data: MapNodeData = run_data.get_node_by_id(pending_node_id) if run_data != null else null
	var failed_resolution: Dictionary = get_pending_resolution()
	failed_resolution["kind"] = RESOLUTION_FAILED
	clear_pending_node()

	if node_data != null:
		emit_signal("run_failed", node_data, failed_resolution)

	return failed_resolution


func consume_pending_resolution() -> Dictionary:
	var resolution: Dictionary = get_pending_resolution()
	clear_pending_node()
	return resolution


func is_boss_pending() -> bool:
	return StringName(pending_resolution.get("battle_kind", &"")) == BATTLE_BOSS


func _build_battle_resolution(
	node_data: MapNodeData,
	battle_kind: StringName,
	reward_gold: int,
	reward_resource_type: StringName,
	reward_resource_amount: int,
	clears_dungeon: bool
) -> Dictionary:
	return {
		"kind": RESOLUTION_BATTLE,
		"node_id": node_data.id,
		"node_type": node_data.node_type,
		"battle_kind": battle_kind,
		"title": node_data.get_type_label(),
		"reward_gold": reward_gold,
		"reward_resource_type": reward_resource_type,
		"reward_resource_amount": reward_resource_amount,
		"reward_skill_path": "",
		"penalty_gold": 0,
		"clears_dungeon": clears_dungeon,
		"fails_run_on_defeat": true,
	}


func _build_event_resolution(node_data: MapNodeData) -> Dictionary:
	var event_roll: int = _roll_event_outcome(node_data.id)
	var base_resolution: Dictionary = {
		"kind": RESOLUTION_EVENT,
		"node_id": node_data.id,
		"node_type": node_data.node_type,
		"title": "Unknown Encounter",
		"reward_gold": 0,
		"reward_resource_type": "",
		"reward_resource_amount": 0,
		"reward_skill_path": "",
		"penalty_gold": 0,
	}

	match event_roll:
		0:
			base_resolution["event_kind"] = EVENT_GOLD_CACHE
			base_resolution["title"] = "Lost Purse"
			base_resolution["reward_gold"] = 12 + node_data.row * 2
		1:
			base_resolution["event_kind"] = EVENT_MATERIAL_STASH
			base_resolution["title"] = "Abandoned Supplies"
			base_resolution["reward_resource_type"] = ExpeditionState.RESOURCE_HERBS if node_data.row % 2 == 0 else ExpeditionState.RESOURCE_ORES
			base_resolution["reward_resource_amount"] = 2 + int(max(1, node_data.row / 2))
		2:
			base_resolution["event_kind"] = EVENT_SKILL_BOOK
			base_resolution["title"] = "Forgotten Manual"
			base_resolution["reward_skill_path"] = DEFAULT_SKILL_REWARD_PATH
		_:
			base_resolution["event_kind"] = EVENT_MINOR_PENALTY
			base_resolution["title"] = "Cursed Relic"
			base_resolution["reward_gold"] = 8 + node_data.row
			base_resolution["penalty_gold"] = 5 + int(max(0, node_data.row / 2))

	return base_resolution


func _roll_event_outcome(node_id: int) -> int:
	var seed_value: int = run_data.seed if run_data != null else 0
	return abs(node_id * 37 + seed_value) % 4


func to_save_dict() -> Dictionary:
	var save_data: Dictionary = {
		"seed": 0,
		"start_node_id": -1,
		"current_node_id": -1,
		"started": false,
		"visited_node_ids": [],
		"revealed_node_ids": [],
		"traveled_edges": [],
		"revealed_edges": [],
		"nodes": [],
	}

	if not has_active_run():
		return save_data

	save_data["seed"] = run_data.seed
	save_data["start_node_id"] = run_data.start_node_id
	save_data["current_node_id"] = run_data.current_node_id
	save_data["started"] = run_data.started
	save_data["visited_node_ids"] = run_data.visited_node_ids.duplicate()
	save_data["revealed_node_ids"] = run_data.revealed_node_ids.duplicate()
	save_data["traveled_edges"] = run_data.traveled_edges.duplicate()
	save_data["revealed_edges"] = run_data.revealed_edges.duplicate()

	var node_entries: Array[Dictionary] = []
	for node in run_data.nodes:
		node_entries.append({
			"id": node.id,
			"row": node.row,
			"position": node.position,
			"angle": node.angle,
			"node_type": String(node.node_type),
			"connected_to": node.connected_to.duplicate(),
			"visited": node.visited,
			"is_discovered": node.is_discovered,
			"is_visible": node.is_visible,
			"is_completed": node.is_completed,
			"is_available": node.is_available,
		})

	save_data["nodes"] = node_entries
	return save_data


func load_from_save_dict(save_data: Dictionary) -> void:
	var loaded_run: MapRunData = MapRunData.new()
	loaded_run.seed = int(save_data.get("seed", 0))
	loaded_run.start_node_id = int(save_data.get("start_node_id", -1))
	loaded_run.current_node_id = int(save_data.get("current_node_id", -1))
	loaded_run.started = bool(save_data.get("started", false))
	for visited_node_id in save_data.get("visited_node_ids", []):
		loaded_run.visited_node_ids.append(int(visited_node_id))
	for revealed_node_id in save_data.get("revealed_node_ids", []):
		loaded_run.revealed_node_ids.append(int(revealed_node_id))
	for traveled_edge in save_data.get("traveled_edges", []):
		loaded_run.traveled_edges.append(String(traveled_edge))
	for revealed_edge in save_data.get("revealed_edges", []):
		loaded_run.revealed_edges.append(String(revealed_edge))

	var node_entries: Array = save_data.get("nodes", [])
	for node_entry in node_entries:
		var node: MapNodeData = MapNodeData.new()
		node.id = int(node_entry.get("id", -1))
		node.row = int(node_entry.get("row", 0))
		node.position = node_entry.get("position", Vector2.ZERO)
		node.angle = float(node_entry.get("angle", 0.0))
		node.node_type = MapNodeData.normalize_node_type(StringName(node_entry.get("node_type", MapNodeData.TYPE_COMBAT)))
		node.connected_to.clear()
		for target_id in node_entry.get("connected_to", []):
			node.connected_to.append(int(target_id))
		node.visited = bool(node_entry.get("visited", false))
		node.is_discovered = bool(node_entry.get("is_discovered", node.visited))
		node.is_visible = bool(node_entry.get("is_visible", false))
		node.is_completed = bool(node_entry.get("is_completed", node.visited))
		node.is_available = bool(node_entry.get("is_available", false))
		loaded_run.nodes.append(node)

	run_data = loaded_run
	run_data.refresh_node_visibility()
	pending_node_id = -1
	pending_resolution.clear()
	emit_signal("run_updated", run_data)
