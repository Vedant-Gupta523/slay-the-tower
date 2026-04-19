extends Resource
class_name MapRunData

@export var seed: int = 0
@export var nodes: Array[MapNodeData] = []
@export var start_node_id: int = -1
@export var current_node_id: int = -1
@export var started: bool = false
@export var visited_node_ids: Array[int] = []
@export var revealed_node_ids: Array[int] = []
@export var traveled_edges: Array[String] = []
@export var revealed_edges: Array[String] = []


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
		if start_node_id >= 0:
			reachable_ids.append(start_node_id)
		return reachable_ids

	var from_node: MapNodeData = get_node_by_id(from_id)
	if from_node == null:
		return reachable_ids

	for target_id in from_node.connected_to:
		reachable_ids.append(target_id)

	return reachable_ids


func get_connected_node_ids(node_id: int) -> Array[int]:
	var connected_ids: Array[int] = []
	var node: MapNodeData = get_node_by_id(node_id)

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


func is_edge_traveled(from_id: int, to_id: int) -> bool:
	return traveled_edges.has(_make_edge_key(from_id, to_id))


func is_edge_revealed(from_id: int, to_id: int) -> bool:
	return revealed_edges.has(_make_edge_key(from_id, to_id))


func can_travel_to(node_id: int) -> bool:
	return can_move_to(node_id)


func can_move_to(node_id: int) -> bool:
	var node: MapNodeData = get_node_by_id(node_id)
	if node == null:
		return false

	if node.id == current_node_id:
		return false

	if node.is_visible and node.is_available:
		return true

	return _can_backtrack_to_node(node_id)


func should_resolve_node(node_id: int) -> bool:
	var node: MapNodeData = get_node_by_id(node_id)
	return node != null and can_move_to(node_id) and not node.is_completed


func move_to_node(node_id: int) -> bool:
	if not can_move_to(node_id):
		return false

	var node: MapNodeData = get_node_by_id(node_id)
	if node != null and node.is_completed:
		_move_to_completed_node(node_id)
		return true

	mark_node_visited(node_id)
	return true


func mark_node_visited(node_id: int) -> void:
	var node: MapNodeData = get_node_by_id(node_id)
	if node == null:
		return

	var previous_node_id: int = current_node_id
	if previous_node_id >= 0 and previous_node_id != node_id:
		_mark_node_history(previous_node_id)
		_add_traveled_edge(previous_node_id, node_id)

	node.visited = true
	node.is_completed = true
	node.is_discovered = true
	node.is_visible = true
	current_node_id = node_id
	started = true
	_mark_node_history(node_id)
	_reveal_node(node_id)
	refresh_node_visibility()


func initialize_node_visibility() -> void:
	for node in nodes:
		node.is_discovered = revealed_node_ids.has(node.id)
		node.is_visible = node.is_discovered
		node.is_available = false
		node.is_completed = node.is_completed or node.visited
		node.visited = node.is_completed or visited_node_ids.has(node.id)

	if nodes.is_empty():
		return

	if not started or current_node_id < 0:
		var start_node: MapNodeData = get_node_by_id(start_node_id)
		if start_node == null:
			return
		current_node_id = start_node_id
		started = true
		start_node.visited = true
		start_node.is_completed = true
		_mark_node_history(start_node_id)
		start_node.is_discovered = true
		start_node.is_visible = true
		_reveal_node(start_node_id)
		_reveal_neighbors(start_node)
		_update_available_nodes()
		return

	refresh_node_visibility()


func refresh_node_visibility() -> void:
	if nodes.is_empty():
		return

	for node in nodes:
		node.is_completed = node.is_completed or node.visited
		node.visited = node.is_completed or visited_node_ids.has(node.id)
		node.is_available = false
		node.is_discovered = revealed_node_ids.has(node.id) or node.visited
		node.is_visible = node.is_discovered

	if not started or current_node_id < 0:
		initialize_node_visibility()
		return

	var current_node: MapNodeData = get_node_by_id(current_node_id)
	if current_node == null:
		return

	current_node.is_visible = true
	current_node.is_completed = true
	current_node.visited = true
	current_node.is_discovered = true
	_reveal_node(current_node.id)
	_reveal_neighbors(current_node)
	_update_available_nodes()


func _update_available_nodes() -> void:
	if current_node_id < 0:
		return

	var current_node: MapNodeData = get_node_by_id(current_node_id)
	if current_node == null:
		return

	for node in nodes:
		node.is_available = false

	for connected_id in get_connected_node_ids(current_node_id):
		var connected_node: MapNodeData = get_node_by_id(connected_id)
		if connected_node == null:
			continue

		if connected_node.is_completed:
			connected_node.is_visible = true
			connected_node.is_available = connected_node.id != current_node_id
			continue

		if connected_node.row <= current_node.row:
			continue
		if not revealed_node_ids.has(connected_id):
			continue

		connected_node.is_visible = true
		connected_node.is_available = true

	current_node.is_available = false


func _move_to_completed_node(node_id: int) -> void:
	var node: MapNodeData = get_node_by_id(node_id)
	if node == null:
		return

	var previous_node_id: int = current_node_id
	if previous_node_id >= 0 and previous_node_id != node_id:
		_mark_node_history(previous_node_id)
		_add_traveled_edge(previous_node_id, node_id)

	current_node_id = node_id
	started = true
	node.visited = true
	node.is_completed = true
	node.is_discovered = true
	node.is_visible = true
	_mark_node_history(node_id)
	_reveal_node(node_id)
	refresh_node_visibility()


func _can_backtrack_to_node(node_id: int) -> bool:
	if current_node_id < 0:
		return false

	var node: MapNodeData = get_node_by_id(node_id)
	if node == null or not node.is_completed:
		return false

	return get_connected_node_ids(current_node_id).has(node_id)


func _mark_node_history(node_id: int) -> void:
	if not visited_node_ids.has(node_id):
		visited_node_ids.append(node_id)


func _reveal_node(node_id: int) -> void:
	if not revealed_node_ids.has(node_id):
		revealed_node_ids.append(node_id)


func _reveal_neighbors(source_node: MapNodeData) -> void:
	for target_id in source_node.connected_to:
		var target_node: MapNodeData = get_node_by_id(target_id)
		if target_node == null:
			continue

		_reveal_node(target_id)
		_add_revealed_edge(source_node.id, target_id)
		target_node.is_discovered = true
		target_node.is_visible = true


func _add_traveled_edge(from_id: int, to_id: int) -> void:
	var edge_key: String = _make_edge_key(from_id, to_id)
	if not traveled_edges.has(edge_key):
		traveled_edges.append(edge_key)
	_add_revealed_edge(from_id, to_id)


func _add_revealed_edge(from_id: int, to_id: int) -> void:
	var edge_key: String = _make_edge_key(from_id, to_id)
	if not revealed_edges.has(edge_key):
		revealed_edges.append(edge_key)


func _make_edge_key(from_id: int, to_id: int) -> String:
	return "%d:%d" % [from_id, to_id]


func get_nodes_in_row(target_row: int) -> Array[MapNodeData]:
	var row_nodes: Array[MapNodeData] = []

	for node in nodes:
		if node.row == target_row:
			row_nodes.append(node)

	return row_nodes


func duplicate_run() -> MapRunData:
	var copy: MapRunData = MapRunData.new()
	copy.seed = seed
	copy.start_node_id = start_node_id
	copy.current_node_id = current_node_id
	copy.started = started
	copy.visited_node_ids = visited_node_ids.duplicate()
	copy.revealed_node_ids = revealed_node_ids.duplicate()
	copy.traveled_edges = traveled_edges.duplicate()
	copy.revealed_edges = revealed_edges.duplicate()

	for node in nodes:
		copy.nodes.append(node.duplicate_node())

	return copy
