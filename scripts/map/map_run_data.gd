extends Resource
class_name MapRunData

@export var seed: int = 0
@export var nodes: Array[MapNodeData] = []
@export var current_node_id: int = -1
@export var started: bool = false


func get_node_by_id(node_id: int) -> MapNodeData:
	for node in nodes:
		if node.id == node_id:
			return node

	return null


func get_reachable_node_ids(from_id: int) -> Array[int]:
	var reachable_ids: Array[int] = []

	if nodes.is_empty():
		return reachable_ids

	if not started or from_id < 0:
		var start_nodes: Array[MapNodeData] = get_nodes_in_row(0)
		if not start_nodes.is_empty():
			reachable_ids.append(start_nodes[0].id)
		return reachable_ids

	var from_node := get_node_by_id(from_id)
	if from_node == null:
		return reachable_ids

	for target_id in from_node.connected_to:
		reachable_ids.append(target_id)

	return reachable_ids


func can_travel_to(node_id: int) -> bool:
	if nodes.is_empty():
		return false

	if not started:
		var start_nodes: Array[MapNodeData] = get_nodes_in_row(0)
		return not start_nodes.is_empty() and start_nodes[0].id == node_id

	if current_node_id < 0:
		return false

	return get_reachable_node_ids(current_node_id).has(node_id)


func mark_node_visited(node_id: int) -> void:
	var node := get_node_by_id(node_id)
	if node == null:
		return

	node.visited = true
	current_node_id = node_id
	started = true


func get_nodes_in_row(target_row: int) -> Array[MapNodeData]:
	var row_nodes: Array[MapNodeData] = []

	for node in nodes:
		if node.row == target_row:
			row_nodes.append(node)

	return row_nodes


func duplicate_run() -> MapRunData:
	var copy := MapRunData.new()
	copy.seed = seed
	copy.current_node_id = current_node_id
	copy.started = started

	for node in nodes:
		copy.nodes.append(node.duplicate_node())

	return copy
