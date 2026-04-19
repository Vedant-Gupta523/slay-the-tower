extends Node2D

const MAP_NODE_VIEW_SCENE := preload("res://scenes/map/MapNodeView.tscn")

@export var rows: int = 5
@export var min_nodes_per_row: int = 2
@export var max_nodes_per_row: int = 5
@export var horizontal_spacing: float = 220.0
@export var vertical_spacing: float = 140.0

var map_nodes: Array[Array] = []
var node_positions: Dictionary = {}

@onready var line_2d_container: Node2D = $Line2DContainer
@onready var node_container: Node2D = $NodeContainer

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	redraw_map()


func redraw_map() -> void:
	_clear_container(node_container)
	_clear_container(line_2d_container)
	_generate_map()
	_place_nodes()
	_draw_connections()


func _generate_map() -> void:
	map_nodes.clear()
	node_positions.clear()

	var total_rows: int = 5
	var min_count: int = 2
	var max_count: int = 5

	for row_index in range(total_rows):
		var row_nodes: Array[MapNode] = []
		var node_count := _rng.randi_range(min_count, max_count)

		if row_index == total_rows - 1:
			node_count = 1

		for column_index in range(node_count):
			var map_node := MapNode.new()
			map_node.id = "row_%d_col_%d" % [row_index, column_index]
			map_node.row = row_index
			map_node.column = column_index
			map_node.type = _get_random_node_type(row_index, total_rows)
			row_nodes.append(map_node)

		map_nodes.append(row_nodes)

	for row_index in range(total_rows - 1):
		var current_row: Array[MapNode] = map_nodes[row_index]
		var next_row: Array[MapNode] = map_nodes[row_index + 1]
		_connect_rows(current_row, next_row)


func _place_nodes() -> void:
	for row_nodes in map_nodes:
		for map_node in row_nodes:
			var node_view := MAP_NODE_VIEW_SCENE.instantiate() as MapNodeView
			var local_position: Vector2 = Vector2(
				map_node.column * horizontal_spacing,
				map_node.row * vertical_spacing
			)

			node_container.add_child(node_view)
			node_view.position = local_position
			node_view.set_node(map_node)
			node_positions[map_node.id] = node_view.global_position


func _draw_connections() -> void:
	for row_nodes in map_nodes:
		for map_node in row_nodes:
			if not node_positions.has(map_node.id):
				continue

			var from_global: Vector2 = node_positions[map_node.id]
			var from_center: Vector2 = from_global + (Vector2.ONE * 32.0)

			for target_id in map_node.connected_to:
				if not node_positions.has(target_id):
					continue

				var to_global: Vector2 = node_positions[target_id]
				var to_center: Vector2 = to_global + (Vector2.ONE * 32.0)
				var line: Line2D = Line2D.new()

				line.width = 6.0
				line.default_color = Color.WHITE
				line.add_point(line_2d_container.to_local(from_center))
				line.add_point(line_2d_container.to_local(to_center))
				line_2d_container.add_child(line)


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.free()


func _get_random_node_type(row_index: int, total_rows: int) -> MapNode.NodeType:
	if row_index == total_rows - 1:
		return MapNode.NodeType.BOSS

	var available_types: Array[MapNode.NodeType] = [
		MapNode.NodeType.ENEMY,
		MapNode.NodeType.ELITE,
		MapNode.NodeType.EVENT,
		MapNode.NodeType.REST,
		MapNode.NodeType.TREASURE,
	]

	return available_types[_rng.randi_range(0, available_types.size() - 1)]


func _connect_rows(current_row: Array[MapNode], next_row: Array[MapNode]) -> void:
	var owner_by_target: Array[int] = _build_target_owners(current_row.size(), next_row.size())
	var required_targets_by_source: Array[Array] = []
	required_targets_by_source.resize(current_row.size())

	for source_index in range(current_row.size()):
		required_targets_by_source[source_index] = []

	for target_index in range(next_row.size()):
		var owner_index: int = owner_by_target[target_index]
		required_targets_by_source[owner_index].append(target_index)

	var next_required_start: Array[int] = _build_next_required_start(required_targets_by_source, next_row.size())
	var previous_target_index: int = 0

	for source_index in range(current_row.size()):
		var current_node: MapNode = current_row[source_index]
		var required_targets: Array = required_targets_by_source[source_index]
		var range_start: int
		var range_end: int

		if required_targets.is_empty():
			range_start = previous_target_index
			range_end = next_required_start[source_index]
			var chosen_target: int = _rng.randi_range(range_start, range_end)
			required_targets.append(chosen_target)
		else:
			range_start = int(required_targets.front())
			range_end = int(required_targets.back())

		for target_value in required_targets:
			var target_index: int = int(target_value)
			current_node.connected_to.append(next_row[target_index].id)

		previous_target_index = range_end


func _build_target_owners(current_count: int, next_count: int) -> Array[int]:
	var owners: Array[int] = []
	owners.resize(next_count)
	owners[0] = 0

	for target_index in range(1, next_count - 1):
		var min_owner: int = owners[target_index - 1]
		var max_owner: int = current_count - 1
		owners[target_index] = _rng.randi_range(min_owner, max_owner)

	if next_count > 1:
		owners[next_count - 1] = current_count - 1

	return owners


func _build_next_required_start(required_targets_by_source: Array[Array], fallback_target: int) -> Array[int]:
	var next_required_start: Array[int] = []
	next_required_start.resize(required_targets_by_source.size())
	var next_start: int = fallback_target - 1

	for source_index in range(required_targets_by_source.size() - 1, -1, -1):
		var required_targets: Array = required_targets_by_source[source_index]

		if not required_targets.is_empty():
			next_start = int(required_targets.front())

		next_required_start[source_index] = next_start

	return next_required_start
