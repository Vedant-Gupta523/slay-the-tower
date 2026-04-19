extends RefCounted
class_name MapGenerator

const TYPE_COMBAT := MapNodeData.TYPE_COMBAT
const TYPE_ELITE := MapNodeData.TYPE_ELITE
const TYPE_EVENT := MapNodeData.TYPE_EVENT
const TYPE_RESOURCE := MapNodeData.TYPE_RESOURCE
const TYPE_BOSS := MapNodeData.TYPE_BOSS

const DEFAULT_MIN_NODE_GAP := 92.0
const DEFAULT_ROW_VERTICAL_JITTER := 18.0
const DEFAULT_ROW_CENTER_DRIFT := 72.0
const DEFAULT_CLUSTER_STRENGTH := 0.38
const MAX_PRIMARY_TARGET_STEP := 1
const MAX_EXTRA_TARGET_STEP := 1


func generate_run(seed: int = 0, config: Dictionary = {}) -> MapRunData:
	var run := MapRunData.new()
	var rng := RandomNumberGenerator.new()
	var actual_seed: int = seed

	if actual_seed == 0:
		actual_seed = int(Time.get_unix_time_from_system())

	rng.seed = actual_seed
	run.seed = actual_seed
	run.current_node_id = -1
	run.started = false

	var row_count: int = clamp(int(config.get("row_count", 10)), 8, 12)
	var min_middle_nodes: int = clamp(int(config.get("min_middle_nodes", 2)), 2, 4)
	var max_middle_nodes: int = clamp(int(config.get("max_middle_nodes", 4)), min_middle_nodes, 4)
	var map_width: float = float(config.get("map_width", 960.0))
	var side_padding: float = float(config.get("side_padding", 96.0))
	var top_padding: float = float(config.get("top_padding", 96.0))
	var horizontal_spacing: float = float(config.get("horizontal_spacing", 220.0))
	var vertical_spacing: float = float(config.get("vertical_spacing", 140.0))
	var horizontal_jitter: float = float(config.get("horizontal_jitter", 32.0))
	var row_vertical_jitter: float = float(config.get("row_vertical_jitter", DEFAULT_ROW_VERTICAL_JITTER))
	var min_node_gap: float = float(config.get("min_node_gap", DEFAULT_MIN_NODE_GAP))
	var row_center_drift: float = float(config.get("row_center_drift", DEFAULT_ROW_CENTER_DRIFT))
	var cluster_strength: float = clamp(float(config.get("cluster_strength", DEFAULT_CLUSTER_STRENGTH)), 0.0, 0.85)

	var rows: Array[Array] = []
	var next_node_id: int = 0
	var previous_row_x: Array[float] = []

	for row_index in range(row_count):
		var row_nodes: Array[MapNodeData] = []
		var node_count: int = 1

		if row_index > 0 and row_index < row_count - 1:
			node_count = rng.randi_range(min_middle_nodes, max_middle_nodes)

		var row_positions: Array[Vector2] = _build_row_positions(
			rng,
			row_index,
			row_count,
			node_count,
			map_width,
			side_padding,
			top_padding,
			horizontal_spacing,
			vertical_spacing,
			horizontal_jitter,
			row_vertical_jitter,
			min_node_gap,
			row_center_drift,
			cluster_strength,
			previous_row_x
		)

		for column_index in range(node_count):
			var node := MapNodeData.new()
			node.id = next_node_id
			node.row = row_index
			node.position = row_positions[column_index]
			node.node_type = TYPE_COMBAT
			node.visited = false
			node.is_discovered = false
			node.is_completed = false
			node.is_visible = false
			node.is_available = false
			row_nodes.append(node)
			run.nodes.append(node)
			next_node_id += 1

		previous_row_x.clear()
		for position in row_positions:
			previous_row_x.append(position.x)

		rows.append(row_nodes)

	for row_index in range(row_count - 1):
		var current_row: Array[MapNodeData] = rows[row_index]
		var next_row: Array[MapNodeData] = rows[row_index + 1]
		_connect_rows(rng, current_row, next_row)

	_assign_node_types(rng, run, rows, config)
	return run


func _build_row_positions(
	rng: RandomNumberGenerator,
	row_index: int,
	row_count: int,
	node_count: int,
	map_width: float,
	side_padding: float,
	top_padding: float,
	horizontal_spacing: float,
	vertical_spacing: float,
	horizontal_jitter: float,
	row_vertical_jitter: float,
	min_node_gap: float,
	row_center_drift: float,
	cluster_strength: float,
	previous_row_x: Array[float]
) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var visual_row: int = row_count - 1 - row_index
	var y: float = top_padding + float(visual_row) * vertical_spacing + rng.randf_range(-row_vertical_jitter, row_vertical_jitter)

	if node_count == 1:
		var single_x: float = _get_row_center_x(rng, map_width, side_padding, row_center_drift, previous_row_x)
		positions.append(Vector2(single_x, y))
		return positions

	var usable_width: float = max(map_width - side_padding * 2.0, horizontal_spacing * float(node_count - 1))
	var x_values: Array[float] = []
	var minimum_gap: float = max(min_node_gap, usable_width / float(max(3, node_count * 3)))
	var target_span: float = min(
		usable_width,
		max(minimum_gap * float(node_count - 1), horizontal_spacing * float(node_count - 1) * rng.randf_range(0.78, 1.08))
	)
	var row_center_x: float = _get_row_center_x(rng, map_width, side_padding, row_center_drift, previous_row_x)
	var span_start: float = clamp(row_center_x - target_span * 0.5, side_padding, map_width - side_padding - target_span)
	var span_end: float = span_start + target_span
	var free_width: float = max(0.0, target_span - minimum_gap * float(node_count - 1))
	var gap_weights: Array[float] = []
	var total_weight: float = 0.0

	for gap_index in range(node_count - 1):
		var weight: float = _sample_gap_weight(rng, cluster_strength, gap_index, node_count - 1)
		gap_weights.append(weight)
		total_weight += weight

	x_values.append(span_start)

	for gap_index in range(gap_weights.size()):
		var extra_gap: float = 0.0
		if total_weight > 0.0:
			extra_gap = free_width * (gap_weights[gap_index] / total_weight)
		x_values.append(x_values[gap_index] + minimum_gap + extra_gap)

	for column_index in range(x_values.size()):
		var left_limit := span_start + float(column_index) * minimum_gap
		var right_limit := span_end - float(node_count - 1 - column_index) * minimum_gap
		var local_jitter := rng.randf_range(-horizontal_jitter, horizontal_jitter)
		x_values[column_index] = clamp(x_values[column_index] + local_jitter, left_limit, right_limit)

		if column_index > 0:
			x_values[column_index] = max(x_values[column_index], x_values[column_index - 1] + minimum_gap)

	_normalize_row_spacing(x_values, side_padding, map_width - side_padding, minimum_gap)

	for x_value in x_values:
		positions.append(Vector2(x_value, y))

	return positions


func _get_row_center_x(
	rng: RandomNumberGenerator,
	map_width: float,
	side_padding: float,
	row_center_drift: float,
	previous_row_x: Array[float]
) -> float:
	var default_center := map_width * 0.5
	var center := default_center

	if not previous_row_x.is_empty():
		for x_value in previous_row_x:
			center += x_value
		center /= float(previous_row_x.size() + 1)

	center += rng.randf_range(-row_center_drift, row_center_drift)
	return clamp(center, side_padding + 32.0, map_width - side_padding - 32.0)


func _sample_gap_weight(
	rng: RandomNumberGenerator,
	cluster_strength: float,
	gap_index: int,
	gap_count: int
) -> float:
	var center_bias: float = 1.0 - absf((float(gap_index) + 0.5) / maxf(1.0, float(gap_count)) - 0.5) * 2.0
	var cluster_pull: float = lerpf(1.0, 0.5 + center_bias * 1.6, cluster_strength)
	return max(0.1, rng.randf_range(0.35, 1.65) * cluster_pull)


func _normalize_row_spacing(x_values: Array[float], min_x: float, max_x: float, minimum_gap: float) -> void:
	if x_values.is_empty():
		return

	if x_values[0] < min_x:
		var underflow: float = min_x - x_values[0]
		for index in range(x_values.size()):
			x_values[index] += underflow

	if x_values[x_values.size() - 1] > max_x:
		var overflow: float = x_values[x_values.size() - 1] - max_x
		for index in range(x_values.size()):
			x_values[index] -= overflow

	for index in range(1, x_values.size()):
		x_values[index] = max(x_values[index], x_values[index - 1] + minimum_gap)

	if x_values[x_values.size() - 1] > max_x:
		x_values[x_values.size() - 1] = max_x

	for index in range(x_values.size() - 2, -1, -1):
		x_values[index] = min(x_values[index], x_values[index + 1] - minimum_gap)

	x_values[0] = max(x_values[0], min_x)


func _connect_rows(rng: RandomNumberGenerator, current_row: Array[MapNodeData], next_row: Array[MapNodeData]) -> void:
	if next_row.size() == 1:
		var boss_target_id: int = next_row[0].id
		for node in current_row:
			node.connected_to = [boss_target_id]
		return

	var primary_targets: Array[int] = _build_primary_targets(rng, current_row, next_row)
	var connections_by_source: Array[Array] = []
	connections_by_source.resize(current_row.size())

	for source_index in range(current_row.size()):
		connections_by_source[source_index] = [primary_targets[source_index]]

	_ensure_every_target_has_owner(connections_by_source, current_row, next_row)
	_add_optional_branches(rng, connections_by_source, current_row, next_row)

	for source_index in range(current_row.size()):
		var source_node: MapNodeData = current_row[source_index]
		var chosen_targets: Array[int] = []

		for target_index in connections_by_source[source_index]:
			chosen_targets.append(int(target_index))

		chosen_targets.sort()
		source_node.connected_to.clear()

		for target_index in chosen_targets:
			source_node.connected_to.append(next_row[target_index].id)


func _build_primary_targets(
	rng: RandomNumberGenerator,
	current_row: Array[MapNodeData],
	next_row: Array[MapNodeData]
) -> Array[int]:
	var primary_targets: Array[int] = []
	primary_targets.resize(current_row.size())
	var previous_target: int = 0

	for source_index in range(current_row.size()):
		var projected_target: int = _find_closest_target_index(current_row[source_index], next_row)
		var min_target: int = previous_target
		var max_target: int = next_row.size() - 1

		if source_index < current_row.size() - 1:
			max_target = min(max_target, next_row.size() - (current_row.size() - source_index))

		var target_index: int = clamp(projected_target, min_target, max_target)
		if source_index > 0:
			target_index = min(target_index, previous_target + MAX_PRIMARY_TARGET_STEP)
			target_index = max(target_index, previous_target)

		if source_index == current_row.size() - 1:
			target_index = next_row.size() - 1
		elif source_index == 0:
			target_index = 0 if projected_target == 0 else target_index

		if source_index > 0 and target_index < previous_target:
			target_index = previous_target

		if source_index < current_row.size() - 1 and max_target < target_index:
			target_index = max_target

		primary_targets[source_index] = target_index
		previous_target = target_index

	if not primary_targets.is_empty():
		primary_targets[0] = 0
		primary_targets[primary_targets.size() - 1] = next_row.size() - 1

	for index in range(1, primary_targets.size()):
		primary_targets[index] = max(primary_targets[index], primary_targets[index - 1])

	return primary_targets


func _ensure_every_target_has_owner(
	connections_by_source: Array[Array],
	current_row: Array[MapNodeData],
	next_row: Array[MapNodeData]
) -> void:
	for target_index in range(next_row.size()):
		if _has_target_owner(connections_by_source, target_index):
			continue

		var source_index: int = _find_best_source_for_target(target_index, connections_by_source, current_row, next_row)
		if source_index >= 0 and not connections_by_source[source_index].has(target_index):
			connections_by_source[source_index].append(target_index)


func _add_optional_branches(
	rng: RandomNumberGenerator,
	connections_by_source: Array[Array],
	current_row: Array[MapNodeData],
	next_row: Array[MapNodeData]
) -> void:
	for source_index in range(current_row.size()):
		if rng.randf() > 0.42:
			continue

		var primary_target: int = int(connections_by_source[source_index][0])
		var candidates: Array[int] = []

		for delta in [-1, 1]:
			var candidate_target: int = primary_target + delta
			if candidate_target < 0 or candidate_target >= next_row.size():
				continue
			if abs(candidate_target - primary_target) > MAX_EXTRA_TARGET_STEP:
				continue
			if connections_by_source[source_index].has(candidate_target):
				continue
			if not _is_connection_candidate_valid(source_index, candidate_target, connections_by_source, current_row, next_row):
				continue
			candidates.append(candidate_target)

		if candidates.is_empty():
			continue

		var chosen_index: int = rng.randi_range(0, candidates.size() - 1)
		connections_by_source[source_index].append(candidates[chosen_index])


func _find_closest_target_index(source_node: MapNodeData, next_row: Array[MapNodeData]) -> int:
	var best_index: int = 0
	var best_distance: float = INF

	for target_index in range(next_row.size()):
		var distance_to_target: float = absf(next_row[target_index].position.x - source_node.position.x)
		if distance_to_target < best_distance:
			best_distance = distance_to_target
			best_index = target_index

	return best_index


func _has_target_owner(connections_by_source: Array[Array], target_index: int) -> bool:
	for targets in connections_by_source:
		if targets.has(target_index):
			return true

	return false


func _find_best_source_for_target(
	target_index: int,
	connections_by_source: Array[Array],
	current_row: Array[MapNodeData],
	next_row: Array[MapNodeData]
) -> int:
	var best_source: int = -1
	var best_score: float = INF

	for source_index in range(current_row.size()):
		if not _is_connection_candidate_valid(source_index, target_index, connections_by_source, current_row, next_row):
			continue

		var score: float = absf(current_row[source_index].position.x - next_row[target_index].position.x)
		score += float(connections_by_source[source_index].size()) * 48.0

		if score < best_score:
			best_score = score
			best_source = source_index

	return best_source


func _is_connection_candidate_valid(
	source_index: int,
	target_index: int,
	connections_by_source: Array[Array],
	current_row: Array[MapNodeData],
	next_row: Array[MapNodeData]
) -> bool:
	var source_node: MapNodeData = current_row[source_index]
	var target_node: MapNodeData = next_row[target_index]

	for other_source_index in range(connections_by_source.size()):
		for other_target_index_value in connections_by_source[other_source_index]:
			var other_target_index := int(other_target_index_value)
			if other_source_index == source_index and other_target_index == target_index:
				continue
			if other_source_index == source_index or other_target_index == target_index:
				continue
			if _segments_cross(
				source_node.position,
				target_node.position,
				current_row[other_source_index].position,
				next_row[other_target_index].position
			):
				return false
			if _segments_stack_too_closely(
				source_node.position,
				target_node.position,
				current_row[other_source_index].position,
				next_row[other_target_index].position
			):
				return false

	var horizontal_jump: float = absf(target_node.position.x - source_node.position.x)
	var average_row_gap: float = 0.0
	if next_row.size() > 1:
		average_row_gap = (next_row[next_row.size() - 1].position.x - next_row[0].position.x) / float(next_row.size() - 1)

	if average_row_gap > 0.0 and horizontal_jump > average_row_gap * 1.35:
		return false

	return true


func _segments_cross(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	var orientation_a := signf((a2.x - a1.x) * (b1.y - a1.y) - (a2.y - a1.y) * (b1.x - a1.x))
	var orientation_b := signf((a2.x - a1.x) * (b2.y - a1.y) - (a2.y - a1.y) * (b2.x - a1.x))
	var orientation_c := signf((b2.x - b1.x) * (a1.y - b1.y) - (b2.y - b1.y) * (a1.x - b1.x))
	var orientation_d := signf((b2.x - b1.x) * (a2.y - b1.y) - (b2.y - b1.y) * (a2.x - b1.x))
	return orientation_a != orientation_b and orientation_c != orientation_d


func _segments_stack_too_closely(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	if absf(a1.x - b1.x) > 54.0:
		return false
	if absf(a2.x - b2.x) > 54.0:
		return false

	var slope_a: float = (a2.x - a1.x) / maxf(1.0, absf(a2.y - a1.y))
	var slope_b: float = (b2.x - b1.x) / maxf(1.0, absf(b2.y - b1.y))
	return absf(slope_a - slope_b) < 0.08


func _assign_node_types(
	rng: RandomNumberGenerator,
	run: MapRunData,
	rows: Array[Array],
	config: Dictionary
) -> void:
	rows[0][0].node_type = TYPE_COMBAT
	rows[rows.size() - 1][0].node_type = TYPE_BOSS

	for row_index in range(1, rows.size() - 1):
		for node in rows[row_index]:
			node.node_type = _pick_node_type(rng, run, node, config)


func _pick_node_type(
	rng: RandomNumberGenerator,
	run: MapRunData,
	node: MapNodeData,
	config: Dictionary
) -> StringName:
	var weights: Dictionary = {
		TYPE_COMBAT: int(config.get("combat_weight", 55)),
		TYPE_EVENT: int(config.get("event_weight", 22)),
		TYPE_ELITE: int(config.get("elite_weight", 10)),
		TYPE_RESOURCE: int(config.get("resource_weight", 13)),
	}

	if bool(config.get("prevent_consecutive_safe_nodes", true)):
		var parent_nodes: Array[MapNodeData] = _get_parent_nodes(run, node.id)
		var all_parents_non_combat: bool = not parent_nodes.is_empty()

		for parent in parent_nodes:
			if parent.node_type == TYPE_COMBAT or parent.node_type == TYPE_ELITE:
				all_parents_non_combat = false
				break

		if all_parents_non_combat:
			weights[TYPE_EVENT] = 0
			weights[TYPE_RESOURCE] = 0

	var total_weight: int = 0
	for weight_value in weights.values():
		total_weight += int(weight_value)

	if total_weight <= 0:
		return TYPE_COMBAT

	var roll: int = rng.randi_range(1, total_weight)

	for node_type in weights.keys():
		roll -= int(weights[node_type])
		if roll <= 0:
			return StringName(node_type)

	return TYPE_COMBAT


func _get_parent_nodes(run: MapRunData, node_id: int) -> Array[MapNodeData]:
	var parents: Array[MapNodeData] = []

	for candidate in run.nodes:
		if candidate.connected_to.has(node_id):
			parents.append(candidate)

	return parents
