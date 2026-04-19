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


func get_connected_node_ids(node_id: int) -> Array[int]:
	var connected_ids: Array[int] = []
	var node := get_node_by_id(node_id)

	if node != null:
		for target_id in node.connected_to:
			if not connected_ids.has(target_id):
				connected_ids.append(target_id)

	for candidate in nodes:
		if candidate.connected_to.has(node_id) and not connected_ids.has(candidate.id):
			connected_ids.append(candidate.id)

	return connected_ids


func get_available_node_ids() -> Array[int]:
	var available_ids: Array[int] = []

	for node in nodes:
		if node.is_visible and node.is_available:
			available_ids.append(node.id)

	return available_ids


func can_travel_to(node_id: int) -> bool:
	var node := get_node_by_id(node_id)
	if node == null:
		return false

	return node.is_visible and node.is_available


func should_resolve_node(node_id: int) -> bool:
	var node := get_node_by_id(node_id)
	return node != null and not node.is_completed


func move_to_node(node_id: int) -> bool:
	if not can_travel_to(node_id):
		return false

	var node := get_node_by_id(node_id)
	if node == null:
		return false

	current_node_id = node_id
	started = true
	node.is_discovered = true
	node.is_visible = true
	refresh_node_visibility()
	return true


func mark_node_visited(node_id: int) -> void:
	var node := get_node_by_id(node_id)
	if node == null:
		return

	node.visited = true
	node.is_completed = true
	node.is_discovered = true
	node.is_visible = true
	current_node_id = node_id
	started = true
	refresh_node_visibility()


func initialize_node_visibility() -> void:
	for node in nodes:
		node.is_discovered = node.is_discovered or node.is_visible or node.visited
		node.is_visible = false
		node.is_available = false
		node.is_completed = node.is_completed or node.visited
		node.visited = node.is_completed

	if nodes.is_empty():
		return

	if not started or current_node_id < 0:
		var start_nodes: Array[MapNodeData] = get_nodes_in_row(0)
		if start_nodes.is_empty():
			return

		var start_node := start_nodes[0]
		start_node.is_discovered = true
		start_node.is_visible = true
		start_node.is_available = not start_node.is_completed
		_reveal_connected_nodes(start_node, false)
		return

	refresh_node_visibility()


func refresh_node_visibility() -> void:
	if nodes.is_empty():
		return

	for node in nodes:
		node.is_completed = node.is_completed or node.visited
		node.visited = node.is_completed
		node.is_available = false
		if node.is_completed or node.is_discovered:
			node.is_discovered = true
			node.is_visible = true

	if not started or current_node_id < 0:
		initialize_node_visibility()
		return

	var current_node := get_node_by_id(current_node_id)
	if current_node == null:
		return

	current_node.is_visible = true
	current_node.is_completed = true
	current_node.visited = true
	current_node.is_discovered = true
	_reveal_connected_nodes(current_node, true)
	_update_available_nodes()


func _reveal_connected_nodes(source_node: MapNodeData, make_available: bool) -> void:
	for target_id in source_node.connected_to:
		var target_node := get_node_by_id(target_id)
		if target_node == null:
			continue

		target_node.is_discovered = true
		target_node.is_visible = true
		target_node.is_available = make_available and not target_node.is_completed


func _update_available_nodes() -> void:
	if current_node_id < 0:
		return

	for node in nodes:
		node.is_available = false

	for connected_id in get_connected_node_ids(current_node_id):
		var connected_node := get_node_by_id(connected_id)
		if connected_node == null or not connected_node.is_discovered:
			continue

		connected_node.is_visible = true
		connected_node.is_available = true

	var current_node := get_node_by_id(current_node_id)
	if current_node != null:
		current_node.is_available = false


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
