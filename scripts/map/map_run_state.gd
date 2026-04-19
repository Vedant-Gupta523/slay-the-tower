extends Node
class_name MapRunState

signal run_started(run_data: MapRunData)
signal run_updated(run_data: MapRunData)
signal node_visited(node_data: MapNodeData)

var run_data: MapRunData
var pending_node_id: int = -1


func has_active_run() -> bool:
	return run_data != null and not run_data.nodes.is_empty()


func create_new_run(generator: MapGenerator, config: Dictionary = {}, seed: int = 0) -> MapRunData:
	run_data = generator.generate_run(seed, config)
	run_data.initialize_node_visibility()
	pending_node_id = -1
	emit_signal("run_started", run_data)
	emit_signal("run_updated", run_data)
	return run_data


func set_run_data(value: MapRunData) -> void:
	run_data = value
	if run_data != null:
		run_data.initialize_node_visibility()
	pending_node_id = -1
	emit_signal("run_updated", run_data)


func clear_run() -> void:
	run_data = null
	pending_node_id = -1


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
	return has_active_run() and run_data.can_travel_to(node_id)


func should_resolve_node(node_id: int) -> bool:
	return has_active_run() and run_data.can_travel_to(node_id) and run_data.should_resolve_node(node_id)


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


func clear_pending_node() -> void:
	pending_node_id = -1


func commit_pending_node() -> void:
	if pending_node_id == -1:
		return

	var node_id: int = pending_node_id
	pending_node_id = -1
	mark_node_visited(node_id)


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
	emit_signal("run_updated", run_data)
