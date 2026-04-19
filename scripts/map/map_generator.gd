extends RefCounted
class_name MapGenerator

const TYPE_COMBAT := MapNodeData.TYPE_COMBAT
const TYPE_ELITE := MapNodeData.TYPE_ELITE
const TYPE_EVENT := MapNodeData.TYPE_EVENT
const TYPE_RESOURCE := MapNodeData.TYPE_RESOURCE
const TYPE_BOSS := MapNodeData.TYPE_BOSS

const DEFAULT_RING_SPACING := 170.0
const DEFAULT_RING_JITTER := 14.0
const DEFAULT_ANGLE_JITTER := 0.18
const DEFAULT_PHASE_DRIFT := 0.28
const DEFAULT_CENTER_MARGIN := 220.0
const MAX_TOTAL_NODES := 25
const MIN_EDGE_SEPARATION := 20.0
const NODE_CLEARANCE_RADIUS := 46.0
const EDGE_BOUNDS_PADDING := 18.0
const CARDINAL_ANGLES := [
	-PI * 0.5,
	0.0,
	PI * 0.5,
	PI,
]


func generate_run(seed: int = 0, config: Dictionary = {}) -> MapRunData:
	var run: MapRunData = MapRunData.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var actual_seed: int = seed

	if actual_seed == 0:
		actual_seed = int(Time.get_unix_time_from_system())

	rng.seed = actual_seed
	run.seed = actual_seed
	run.current_node_id = -1
	run.started = false

	var ring_count: int = clamp(int(config.get("row_count", 8)), 6, 10)
	var min_ring_nodes: int = clamp(int(config.get("min_middle_nodes", 3)), 4, 5)
	var max_ring_nodes: int = clamp(int(config.get("max_middle_nodes", 5)), min_ring_nodes, 6)
	var map_width: float = float(config.get("map_width", 1600.0))
	var map_height: float = float(config.get("map_height", map_width))
	var ring_spacing: float = float(config.get("ring_spacing", config.get("vertical_spacing", DEFAULT_RING_SPACING)))
	var ring_radius_jitter: float = float(config.get("ring_radius_jitter", DEFAULT_RING_JITTER))
	var angle_jitter: float = float(config.get("angle_jitter", DEFAULT_ANGLE_JITTER))
	var phase_drift: float = float(config.get("phase_drift", DEFAULT_PHASE_DRIFT))
	var center_margin: float = float(config.get("center_margin", DEFAULT_CENTER_MARGIN))
	var boss_count: int = clamp(int(config.get("boss_count", 2)), 1, 3)
	var max_total_nodes: int = min(MAX_TOTAL_NODES, int(config.get("max_total_nodes", MAX_TOTAL_NODES)))
	var content_rect: Rect2 = _build_content_rect(map_width, map_height, config)
	var center: Vector2 = content_rect.position + content_rect.size * 0.5
	var rings: Array[Array] = []
	var next_node_id: int = 0
	var phase: float = rng.randf_range(-PI, PI)
	var ring_counts: Array[int] = _build_ring_counts(rng, ring_count, min_ring_nodes, max_ring_nodes, boss_count, max_total_nodes)
	var ring_radii: Array[float] = _build_ring_radii(ring_counts.size(), center_margin, ring_spacing, ring_radius_jitter, content_rect)
	var accepted_edges: Array[Dictionary] = []

	for depth in range(ring_counts.size()):
		var ring_nodes: Array[MapNodeData] = []
		var node_count: int = ring_counts[depth]
		var ring_base_radius: float = float(ring_radii[depth])
		var min_ring_radius: float = ring_base_radius
		var max_ring_radius: float = ring_base_radius
		if depth > 0:
			var previous_radius: float = float(ring_radii[max(depth - 1, 0)])
			var next_radius: float = float(ring_radii[min(depth + 1, ring_radii.size() - 1)])
			var inward_gap: float = max(28.0, (ring_base_radius - previous_radius) * 0.35)
			var outward_gap: float = max(28.0, (next_radius - ring_base_radius) * 0.35)
			min_ring_radius = max(previous_radius + 24.0, ring_base_radius - min(ring_radius_jitter, inward_gap))
			max_ring_radius = min(next_radius - 24.0, ring_base_radius + min(ring_radius_jitter, outward_gap))

		var positions: Array[Vector2] = _build_ring_positions(
			rng,
			center,
			node_count,
			ring_base_radius,
			min_ring_radius,
			max_ring_radius,
			depth == 1 and node_count == CARDINAL_ANGLES.size(),
			angle_jitter,
			phase,
			content_rect
		)

		for position in positions:
			var node: MapNodeData = MapNodeData.new()
			node.id = next_node_id
			node.row = depth
			node.position = position
			node.angle = center.angle_to_point(position)
			node.node_type = TYPE_COMBAT
			node.connected_to = []
			node.visited = false
			node.is_discovered = false
			node.is_visible = false
			node.is_completed = false
			node.is_available = false
			ring_nodes.append(node)
			run.nodes.append(node)
			next_node_id += 1

		rings.append(ring_nodes)
		if depth > 0:
			phase += rng.randf_range(-phase_drift, phase_drift)

	for depth in range(rings.size() - 1):
		_connect_rings(rng, rings[depth], rings[depth + 1], run.nodes, accepted_edges, content_rect)

	run.start_node_id = rings[0][0].id
	_assign_node_types(rng, run, rings, config)
	return run


func _build_ring_counts(
	rng: RandomNumberGenerator,
	ring_count: int,
	min_ring_nodes: int,
	max_ring_nodes: int,
	boss_count: int,
	max_total_nodes: int
) -> Array[int]:
	var counts: Array[int] = [1]
	var remaining_budget: int = max_total_nodes - 1
	var usable_ring_count: int = max(2, ring_count)

	for depth in range(1, usable_ring_count):
		var count: int
		if depth == 1:
			count = CARDINAL_ANGLES.size()
		elif depth == usable_ring_count - 1:
			count = min(boss_count, remaining_budget)
		else:
			var remaining_rings: int = usable_ring_count - depth - 1
			var reserve_for_tail: int = max(1, remaining_rings) * 2
			var max_allowed: int = max(2, remaining_budget - reserve_for_tail)
			count = min(max_allowed, rng.randi_range(min_ring_nodes, max_ring_nodes))

		count = max(1, min(count, remaining_budget))
		counts.append(count)
		remaining_budget -= count

		if remaining_budget <= 0:
			break

	if counts[counts.size() - 1] <= 0:
		counts.remove_at(counts.size() - 1)

	return counts


func _build_ring_positions(
	rng: RandomNumberGenerator,
	center: Vector2,
	node_count: int,
	base_radius: float,
	min_radius: float,
	max_radius: float,
	use_cardinal_layout: bool,
	angle_jitter: float,
	phase: float,
	content_rect: Rect2
) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if is_zero_approx(base_radius):
		positions.append(center)
		return positions

	var angles: Array[float] = []

	if use_cardinal_layout:
		for cardinal_angle in CARDINAL_ANGLES:
			angles.append(float(cardinal_angle))
	else:
		var step_angle: float = TAU / float(node_count)
		var max_angle_jitter: float = min(angle_jitter, step_angle * 0.26)
		for index in range(node_count):
			angles.append(phase + float(index) * step_angle + rng.randf_range(-max_angle_jitter, max_angle_jitter))

	for angle_value in angles:
		var angle: float = angle_value
		var radius: float = clampf(base_radius + rng.randf_range(min_radius - base_radius, max_radius - base_radius), min_radius, max_radius)
		var point: Vector2 = center + Vector2.RIGHT.rotated(angle) * radius
		positions.append(_clamp_point_to_rect(point, content_rect))

	positions.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return center.angle_to_point(a) < center.angle_to_point(b)
	)
	return positions


func _connect_rings(
	rng: RandomNumberGenerator,
	inner_ring: Array[MapNodeData],
	outer_ring: Array[MapNodeData],
	all_nodes: Array[MapNodeData],
	accepted_edges: Array[Dictionary],
	content_rect: Rect2
) -> void:
	if inner_ring.is_empty() or outer_ring.is_empty():
		return

	if inner_ring.size() == 1:
		for outer_node in outer_ring:
			if _is_connection_valid(inner_ring[0], outer_node, accepted_edges, all_nodes, content_rect):
				inner_ring[0].connected_to.append(outer_node.id)
				accepted_edges.append({
					"from": inner_ring[0],
					"to": outer_node,
				})
		return

	var outer_by_inner: Array[Array] = []
	outer_by_inner.resize(inner_ring.size())

	for inner_index in range(inner_ring.size()):
		outer_by_inner[inner_index] = []

	for outer_index in range(outer_ring.size()):
		var owner_index: int = _get_owner_index_for_outer_node(outer_index, outer_ring.size(), inner_ring.size())
		outer_by_inner[owner_index].append(outer_index)

	for inner_index in range(inner_ring.size()):
		var inner_node: MapNodeData = inner_ring[inner_index]
		var owned_targets: Array = outer_by_inner[inner_index]

		for outer_index_value in owned_targets:
			var outer_index: int = int(outer_index_value)
			if _is_connection_valid(inner_node, outer_ring[outer_index], accepted_edges, all_nodes, content_rect):
				inner_node.connected_to.append(outer_ring[outer_index].id)
				accepted_edges.append({
					"from": inner_node,
					"to": outer_ring[outer_index],
				})

		if owned_targets.is_empty():
			continue

		if rng.randf() <= 0.22:
			var branch_candidate: int = int(owned_targets.back()) + 1
			if branch_candidate < outer_ring.size() \
			and not inner_node.connected_to.has(outer_ring[branch_candidate].id) \
			and _is_connection_valid(inner_node, outer_ring[branch_candidate], accepted_edges, all_nodes, content_rect):
				inner_node.connected_to.append(outer_ring[branch_candidate].id)
				accepted_edges.append({
					"from": inner_node,
					"to": outer_ring[branch_candidate],
				})

	for outer_node in outer_ring:
		if _count_incoming_edges(inner_ring, outer_node.id) > 0:
			continue

		var fallback_inner: MapNodeData = _find_best_connection_source(inner_ring, outer_node, accepted_edges, all_nodes, content_rect)
		if fallback_inner != null:
			fallback_inner.connected_to.append(outer_node.id)
			accepted_edges.append({
				"from": fallback_inner,
				"to": outer_node,
			})

	for inner_node in inner_ring:
		if not inner_node.connected_to.is_empty():
			continue

		var fallback_outer: MapNodeData = _find_best_connection_target(inner_node, outer_ring, accepted_edges, all_nodes, content_rect)
		if fallback_outer != null:
			inner_node.connected_to.append(fallback_outer.id)
			accepted_edges.append({
				"from": inner_node,
				"to": fallback_outer,
			})


func _get_owner_index_for_outer_node(outer_index: int, outer_count: int, inner_count: int) -> int:
	if outer_count <= 1 or inner_count <= 1:
		return 0

	var ratio: float = float(outer_index) / float(outer_count - 1)
	return clamp(int(round(ratio * float(inner_count - 1))), 0, inner_count - 1)


func _is_connection_valid(
	from_node: MapNodeData,
	to_node: MapNodeData,
	accepted_edges: Array[Dictionary],
	all_nodes: Array[MapNodeData],
	content_rect: Rect2
) -> bool:
	if not content_rect.grow(-EDGE_BOUNDS_PADDING).has_point(from_node.position) or not content_rect.grow(-EDGE_BOUNDS_PADDING).has_point(to_node.position):
		return false

	for edge in accepted_edges:
		var edge_from: MapNodeData = edge["from"] as MapNodeData
		var edge_to: MapNodeData = edge["to"] as MapNodeData
		if edge_from == null or edge_to == null:
			continue
		if edge_from == from_node or edge_to == to_node or edge_from == to_node or edge_to == from_node:
			continue
		if Geometry2D.segment_intersects_segment(from_node.position, to_node.position, edge_from.position, edge_to.position) != null:
			return false
		if _segments_stack_too_closely(from_node.position, to_node.position, edge_from.position, edge_to.position):
			return false

	for node in all_nodes:
		if node == from_node or node == to_node:
			continue
		if Geometry2D.get_closest_point_to_segment(node.position, from_node.position, to_node.position).distance_to(node.position) < NODE_CLEARANCE_RADIUS:
			return false

	return true


func _segments_stack_too_closely(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	var samples := [0.2, 0.4, 0.6, 0.8]
	for sample_t in samples:
		var point_a: Vector2 = a1.lerp(a2, float(sample_t))
		var point_b: Vector2 = b1.lerp(b2, float(sample_t))
		if point_a.distance_to(point_b) < MIN_EDGE_SEPARATION:
			return true
	return false


func _build_content_rect(map_width: float, map_height: float, config: Dictionary) -> Rect2:
	var margin_left: float = float(config.get("content_margin_left", 120.0))
	var margin_right: float = float(config.get("content_margin_right", 120.0))
	var margin_top: float = float(config.get("content_margin_top", 120.0))
	var margin_bottom: float = float(config.get("content_margin_bottom", 120.0))
	var safe_width: float = max(320.0, map_width - margin_left - margin_right)
	var safe_height: float = max(320.0, map_height - margin_top - margin_bottom)
	return Rect2(Vector2(margin_left, margin_top), Vector2(safe_width, safe_height))


func _build_ring_radii(
	ring_total: int,
	center_margin: float,
	ring_spacing: float,
	ring_radius_jitter: float,
	content_rect: Rect2
) -> Array[float]:
	var radii: Array[float] = []
	radii.resize(ring_total)
	if ring_total <= 0:
		return radii

	radii[0] = 0.0
	if ring_total == 1:
		return radii

	var max_radius: float = max(80.0, min(content_rect.size.x, content_rect.size.y) * 0.5 - NODE_CLEARANCE_RADIUS - 18.0)
	var desired_outer_radius: float = center_margin + float(max(0, ring_total - 2)) * ring_spacing
	var outer_radius: float = min(desired_outer_radius, max_radius)
	var inner_radius: float = max(72.0, min(center_margin, outer_radius * 0.42))
	inner_radius = min(inner_radius, outer_radius - max(56.0, ring_radius_jitter * 2.0))

	if ring_total == 2:
		radii[1] = outer_radius
		return radii

	for depth in range(1, ring_total):
		var t: float = float(depth - 1) / float(ring_total - 2)
		var target_radius: float = lerpf(inner_radius, outer_radius, t)
		if depth > 1:
			target_radius = max(target_radius, float(radii[depth - 1]) + max(28.0, ring_radius_jitter * 1.5))
		radii[depth] = min(target_radius, outer_radius)

	return radii


func _clamp_point_to_rect(point: Vector2, content_rect: Rect2) -> Vector2:
	var safe_rect: Rect2 = content_rect.grow(-NODE_CLEARANCE_RADIUS)
	return Vector2(
		clampf(point.x, safe_rect.position.x, safe_rect.end.x),
		clampf(point.y, safe_rect.position.y, safe_rect.end.y)
	)


func _count_incoming_edges(inner_ring: Array[MapNodeData], target_id: int) -> int:
	var count: int = 0
	for node in inner_ring:
		if node.connected_to.has(target_id):
			count += 1
	return count


func _find_best_connection_source(
	inner_ring: Array[MapNodeData],
	outer_node: MapNodeData,
	accepted_edges: Array[Dictionary],
	all_nodes: Array[MapNodeData],
	content_rect: Rect2
) -> MapNodeData:
	var best_node: MapNodeData = null
	var best_score: float = INF
	for inner_node in inner_ring:
		if _is_connection_valid(inner_node, outer_node, accepted_edges, all_nodes, content_rect):
			var score: float = absf(wrapf(inner_node.angle - outer_node.angle, -PI, PI)) + float(inner_node.connected_to.size()) * 0.2
			if score < best_score:
				best_score = score
				best_node = inner_node
	return best_node


func _find_best_connection_target(
	inner_node: MapNodeData,
	outer_ring: Array[MapNodeData],
	accepted_edges: Array[Dictionary],
	all_nodes: Array[MapNodeData],
	content_rect: Rect2
) -> MapNodeData:
	var best_node: MapNodeData = null
	var best_score: float = INF
	for outer_node in outer_ring:
		if _is_connection_valid(inner_node, outer_node, accepted_edges, all_nodes, content_rect):
			var score: float = absf(wrapf(inner_node.angle - outer_node.angle, -PI, PI))
			if score < best_score:
				best_score = score
				best_node = outer_node
	return best_node


func _assign_node_types(
	rng: RandomNumberGenerator,
	run: MapRunData,
	rings: Array[Array],
	config: Dictionary
) -> void:
	for depth in range(rings.size()):
		for node in rings[depth]:
			if depth == rings.size() - 1:
				node.node_type = TYPE_BOSS if node == rings[depth][0] else TYPE_ELITE
			elif depth == 0:
				node.node_type = TYPE_RESOURCE
			else:
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

	var parent_nodes: Array[MapNodeData] = _get_parent_nodes(run, node.id)
	if not parent_nodes.is_empty():
		var all_parents_non_combat: bool = true
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
