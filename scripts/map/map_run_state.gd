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
	pending_node_id = -1
	emit_signal("run_started", run_data)
	emit_signal("run_updated", run_data)
	return run_data


func set_run_data(value: MapRunData) -> void:
	run_data = value
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

	return run_data.get_reachable_node_ids(run_data.current_node_id)


func can_travel_to(node_id: int) -> bool:
	return has_active_run() and run_data.can_travel_to(node_id)


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
		"current_node_id": -1,
		"started": false,
		"nodes": [],
	}

	if not has_active_run():
		return save_data

	save_data["seed"] = run_data.seed
	save_data["current_node_id"] = run_data.current_node_id
	save_data["started"] = run_data.started

	var node_entries: Array[Dictionary] = []
	for node in run_data.nodes:
		node_entries.append({
			"id": node.id,
			"row": node.row,
			"position": node.position,
			"node_type": String(node.node_type),
			"connected_to": node.connected_to.duplicate(),
			"visited": node.visited,
		})

	save_data["nodes"] = node_entries
	return save_data


func load_from_save_dict(save_data: Dictionary) -> void:
	var loaded_run := MapRunData.new()
	loaded_run.seed = int(save_data.get("seed", 0))
	loaded_run.current_node_id = int(save_data.get("current_node_id", -1))
	loaded_run.started = bool(save_data.get("started", false))

	var node_entries: Array = save_data.get("nodes", [])
	for node_entry in node_entries:
		var node := MapNodeData.new()
		node.id = int(node_entry.get("id", -1))
		node.row = int(node_entry.get("row", 0))
		node.position = node_entry.get("position", Vector2.ZERO)
		node.node_type = StringName(node_entry.get("node_type", "combat"))
		node.connected_to.clear()
		for target_id in node_entry.get("connected_to", []):
			node.connected_to.append(int(target_id))
		node.visited = bool(node_entry.get("visited", false))
		loaded_run.nodes.append(node)

	run_data = loaded_run
	pending_node_id = -1
	emit_signal("run_updated", run_data)
