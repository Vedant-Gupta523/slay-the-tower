extends Control
class_name MapView

signal node_pressed(node_id: int)
signal pan_requested(delta: Vector2)
signal zoom_requested(direction: int, focus_position: Vector2)

@export var node_scene: PackedScene = preload("res://scenes/map/MapNodeButton.tscn")
@export var node_size: Vector2 = Vector2(86, 86)
@export var connection_width: float = 5.0
@export var connection_color: Color = Color(0.42, 0.46, 0.52, 0.26)
@export var visited_connection_color: Color = Color(0.86, 0.72, 0.42, 0.76)
@export var active_connection_color: Color = Color(0.98, 0.88, 0.58, 0.96)
@export var marker_color: Color = Color(1.0, 0.95, 0.7, 0.95)
@export var content_padding: Vector2 = Vector2(160, 160)
@export var connection_shadow_color: Color = Color(0.02, 0.03, 0.05, 0.34)
@export var connection_glow_color: Color = Color(0.98, 0.86, 0.42, 0.24)
@export var background_top_color: Color = Color(0.07, 0.08, 0.11)
@export var background_bottom_color: Color = Color(0.11, 0.1, 0.09)
@export var background_grid_color: Color = Color(1.0, 1.0, 1.0, 0.025)
@export var route_curve_strength: float = 8.0
@export var route_end_padding: float = 36.0
@export var highlight_width: float = 8.0
@export var highlight_pulse_speed: float = 1.8
@export var highlight_animation_speed: float = 7.5
@export var line_sample_segments: int = 18
@export var radial_ring_color: Color = Color(1.0, 1.0, 1.0, 0.035)
@export var debug_hidden_connection_color: Color = Color(0.54, 0.6, 0.7, 0.22)
@export var drag_threshold: float = 10.0

@onready var node_layer: Control = $NodeLayer
@onready var player_marker: Panel = $PlayerMarker

var _run_data: MapRunData
var _reachable_ids: Array[int] = []
var _current_node_id: int = -1
var _button_by_id: Dictionary = {}
var _highlight_strength_by_key: Dictionary = {}
var _pulse_time: float = 0.0
var _debug_reveal_map: bool = false
var _zoom_factor: float = 1.0
var _pending_drag: bool = false
var _is_dragging: bool = false
var _drag_distance: float = 0.0


func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_pulse_time += delta * highlight_pulse_speed
	if _update_highlight_animation(delta):
		queue_redraw()


func display_run(run_data: MapRunData, reachable_ids: Array[int], current_node_id: int) -> void:
	_run_data = run_data
	_reachable_ids = reachable_ids.duplicate()
	_current_node_id = current_node_id
	_rebuild()


func set_debug_reveal_map(enabled: bool) -> void:
	if _debug_reveal_map == enabled:
		return

	_debug_reveal_map = enabled
	_rebuild()


func set_zoom_factor(value: float) -> void:
	var next_zoom: float = max(value, 0.1)
	if is_equal_approx(_zoom_factor, next_zoom):
		return

	_zoom_factor = next_zoom
	_rebuild()


func get_zoom_factor() -> float:
	return _zoom_factor


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = event
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
			var was_dragging: bool = _is_dragging
			if mouse_button_event.pressed:
				_pending_drag = true
				_is_dragging = false
				_drag_distance = 0.0
			else:
				_pending_drag = false
				_is_dragging = false
				_drag_distance = 0.0
				if was_dragging:
					accept_event()
		elif mouse_button_event.pressed and mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			emit_signal("zoom_requested", 1, mouse_button_event.position)
			accept_event()
		elif mouse_button_event.pressed and mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			emit_signal("zoom_requested", -1, mouse_button_event.position)
			accept_event()

	if event is InputEventMouseMotion:
		var mouse_motion_event: InputEventMouseMotion = event
		if not (mouse_motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			return

		if _pending_drag and not _is_dragging:
			_drag_distance += mouse_motion_event.relative.length()
			if _drag_distance >= drag_threshold:
				_is_dragging = true

		if _is_dragging:
			emit_signal("pan_requested", mouse_motion_event.relative)
			accept_event()


func _rebuild() -> void:
	for child in node_layer.get_children():
		child.queue_free()

	_button_by_id.clear()

	if _run_data == null or _run_data.nodes.is_empty():
		player_marker.visible = false
		queue_redraw()
		return

	var max_position: Vector2 = Vector2.ZERO

	for node in _run_data.nodes:
		max_position.x = max(max_position.x, node.position.x)
		max_position.y = max(max_position.y, node.position.y)

	var scaled_node_size: Vector2 = _get_scaled_node_size()
	custom_minimum_size = (max_position + node_size + content_padding) * _zoom_factor
	size = custom_minimum_size

	var sorted_nodes: Array[MapNodeData] = _run_data.nodes.duplicate()
	sorted_nodes.sort_custom(func(a: MapNodeData, b: MapNodeData) -> bool:
		if a.row == b.row:
			return a.angle < b.angle
		return a.row < b.row
	)

	for node in sorted_nodes:
		if not _should_render_node(node):
			continue

		var button: MapNodeButton = node_scene.instantiate() as MapNodeButton
		node_layer.add_child(button)
		button.setup(node, scaled_node_size)
		button.position = _scale_point(node.position) - scaled_node_size * 0.5
		button.node_pressed.connect(_on_node_button_pressed)

		var is_current: bool = node.id == _current_node_id
		var is_reachable: bool = _reachable_ids.has(node.id)
		button.apply_state(is_current, is_reachable, node.visited)
		_button_by_id[node.id] = button

	_update_player_marker()
	queue_redraw()


func _update_player_marker() -> void:
	if _current_node_id < 0 or not _button_by_id.has(_current_node_id):
		player_marker.visible = false
		return

	player_marker.visible = true
	player_marker.size = _get_scaled_node_size() * 0.4
	player_marker.position = _scale_point(_run_data.get_node_by_id(_current_node_id).position) - player_marker.size * 0.5

	var marker_style: StyleBoxFlat = StyleBoxFlat.new()
	marker_style.bg_color = marker_color
	marker_style.corner_radius_top_left = 999
	marker_style.corner_radius_top_right = 999
	marker_style.corner_radius_bottom_right = 999
	marker_style.corner_radius_bottom_left = 999
	player_marker.add_theme_stylebox_override("panel", marker_style)


func _draw() -> void:
	if _run_data == null:
		return

	_draw_background()

	for node in _run_data.nodes:
		if not _should_render_node(node):
			continue

		for target_id in node.connected_to:
			var target_node: MapNodeData = _run_data.get_node_by_id(target_id)
			if target_node == null:
				continue
			if not _should_render_edge(node.id, target_id):
				continue

			_draw_connection(node, target_node)


func _on_node_button_pressed(node_id: int) -> void:
	emit_signal("node_pressed", node_id)


func _draw_background() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	draw_rect(Rect2(Vector2.ZERO, size), background_bottom_color, true)

	var upper_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.58))
	draw_rect(upper_rect, background_top_color, true)

	if _run_data == null or _run_data.nodes.is_empty():
		return

	var center: Vector2 = _get_visual_center()
	var max_depth: int = 0
	for node in _run_data.nodes:
		max_depth = max(max_depth, node.row)

	for depth in range(max_depth + 1):
		var sample_node: MapNodeData = _get_first_node_in_depth(depth)
		if sample_node == null:
			continue
		var radius: float = center.distance_to(_scale_point(sample_node.position))
		if depth == 0:
			draw_circle(center, 8.0 * _get_line_scale(), radial_ring_color.lightened(0.15))
		else:
			draw_arc(center, radius, 0.0, TAU, 48, radial_ring_color, max(1.0, _zoom_factor))


func _draw_connection(source: MapNodeData, target: MapNodeData) -> void:
	var points: PackedVector2Array = _build_connection_points(source, target)
	if points.size() < 2:
		return

	var key: String = _get_connection_key(source.id, target.id)
	var highlight_strength: float = float(_highlight_strength_by_key.get(key, 0.0))
	var line_color: Color = connection_color

	if _run_data.is_edge_traveled(source.id, target.id):
		line_color = visited_connection_color
	elif source.is_available or target.is_available:
		line_color = connection_color.lightened(0.3)
	elif _debug_reveal_map and not _run_data.is_edge_revealed(source.id, target.id):
		line_color = debug_hidden_connection_color

	var line_scale: float = _get_line_scale()
	draw_polyline(points, connection_shadow_color, (connection_width + 4.0) * line_scale, true)
	draw_polyline(points, line_color, connection_width * line_scale, true)

	if highlight_strength <= 0.001:
		return

	_draw_tapered_highlight(points, highlight_strength)


func _build_connection_points(source: MapNodeData, target: MapNodeData) -> PackedVector2Array:
	var start: Vector2 = _scale_point(source.position)
	var finish: Vector2 = _scale_point(target.position)
	var start_offset: Vector2 = _get_node_edge_point(start, finish)
	var finish_offset: Vector2 = _get_node_edge_point(finish, start)
	var radial_direction: Vector2 = finish.normalized()
	var midpoint: Vector2 = start_offset.lerp(finish_offset, 0.5)
	var bend_amount: float = min(route_curve_strength * _zoom_factor, absf(source.angle - target.angle) * 10.0 * _zoom_factor)
	var control_a: Vector2 = start_offset.lerp(finish_offset, 0.35) + radial_direction * bend_amount
	var control_b: Vector2 = midpoint.lerp(finish_offset, 0.55) + radial_direction * bend_amount * 0.6

	return _sample_cubic_curve(start_offset, control_a, control_b, finish_offset, line_sample_segments)


func _get_node_edge_point(center: Vector2, other_center: Vector2) -> Vector2:
	var direction: Vector2 = other_center - center
	var direction_length: float = direction.length()
	if direction_length <= 0.001:
		return center

	var travel_direction: Vector2 = direction / direction_length
	var scaled_node_size: Vector2 = _get_scaled_node_size()
	var radius: float = min(scaled_node_size.x, scaled_node_size.y) * 0.32 + route_end_padding * 0.15 * _zoom_factor
	return center + travel_direction * radius


func _sample_cubic_curve(start: Vector2, control_a: Vector2, control_b: Vector2, finish: Vector2, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var safe_segments: int = max(6, segments)

	for index in range(safe_segments + 1):
		var t: float = float(index) / float(safe_segments)
		points.append(_cubic_bezier(start, control_a, control_b, finish, t))

	return points


func _cubic_bezier(start: Vector2, control_a: Vector2, control_b: Vector2, finish: Vector2, t: float) -> Vector2:
	var omt: float = 1.0 - t
	return (
		omt * omt * omt * start
		+ 3.0 * omt * omt * t * control_a
		+ 3.0 * omt * t * t * control_b
		+ t * t * t * finish
	)


func _draw_tapered_highlight(points: PackedVector2Array, strength: float) -> void:
	var pulse: float = 0.86 + sin(_pulse_time) * 0.14
	var glow_strength: float = clamp(strength * pulse, 0.0, 1.0)

	for index in range(points.size() - 1):
		var a: Vector2 = points[index]
		var b: Vector2 = points[index + 1]
		var t0: float = float(index) / float(max(1, points.size() - 1))
		var t1: float = float(index + 1) / float(max(1, points.size() - 1))
		var alpha0: float = _highlight_falloff(t0) * glow_strength
		var alpha1: float = _highlight_falloff(t1) * glow_strength
		var line_scale: float = _get_line_scale()
		var width0: float = lerpf(connection_width, highlight_width + 1.5, alpha0) * line_scale
		var width1: float = lerpf(connection_width, highlight_width, alpha1) * line_scale

		_draw_segment_glow(a, b, alpha0, alpha1, width0, width1)


func _draw_segment_glow(a: Vector2, b: Vector2, alpha0: float, alpha1: float, width0: float, width1: float) -> void:
	var segment_direction: Vector2 = b - a
	var segment_length: float = segment_direction.length()
	if segment_length <= 0.001:
		return

	var normal: Vector2 = Vector2(-segment_direction.y, segment_direction.x).normalized()
	var color_a: Color = active_connection_color
	var color_b: Color = active_connection_color
	var glow_a: Color = connection_glow_color
	var glow_b: Color = connection_glow_color
	color_a.a *= alpha0
	color_b.a *= alpha1
	glow_a.a *= alpha0 * 0.7
	glow_b.a *= alpha1 * 0.7

	var outer_a: float = width0 + 6.0
	var outer_b: float = width1 + 6.0
	draw_polygon(
		PackedVector2Array([
			a + normal * outer_a,
			b + normal * outer_b,
			b - normal * outer_b,
			a - normal * outer_a,
		]),
		PackedColorArray([glow_a, glow_b, glow_b, glow_a])
	)
	draw_polygon(
		PackedVector2Array([
			a + normal * width0,
			b + normal * width1,
			b - normal * width1,
			a - normal * width0,
		]),
		PackedColorArray([color_a, color_b, color_b, color_a])
	)
	draw_circle(a, outer_a, glow_a)
	draw_circle(b, outer_b, glow_b)
	draw_circle(a, width0, color_a)
	draw_circle(b, width1, color_b)


func _highlight_falloff(t: float) -> float:
	var centered: float = sin(clampf(t, 0.0, 1.0) * PI)
	return ease(centered, 1.55)


func _update_highlight_animation(delta: float) -> bool:
	var changed: bool = false
	var target_strength_by_key: Dictionary = _build_target_highlight_strengths()

	for key in target_strength_by_key.keys():
		if not _highlight_strength_by_key.has(key):
			_highlight_strength_by_key[key] = 0.0

	for key in _highlight_strength_by_key.keys():
		var target_strength: float = float(target_strength_by_key.get(key, 0.0))
		var current_strength: float = float(_highlight_strength_by_key.get(key, 0.0))
		var next_strength: float = move_toward(current_strength, target_strength, delta * highlight_animation_speed)
		if absf(next_strength - current_strength) > 0.0005:
			changed = true
		_highlight_strength_by_key[key] = next_strength

	var stale_keys: Array = []
	for key in _highlight_strength_by_key.keys():
		if not target_strength_by_key.has(key) and float(_highlight_strength_by_key[key]) <= 0.001:
			stale_keys.append(key)

	for key in stale_keys:
		_highlight_strength_by_key.erase(key)

	return changed


func _build_target_highlight_strengths() -> Dictionary:
	var target_strengths: Dictionary = {}

	if _run_data == null:
		return target_strengths

	for node in _run_data.nodes:
		for target_id in node.connected_to:
			var key: String = _get_connection_key(node.id, target_id)
			var strength: float = 0.0

			if _run_data.is_edge_traveled(node.id, target_id):
				strength = 0.42

			if node.id == _current_node_id and _reachable_ids.has(target_id):
				strength = 1.0

			target_strengths[key] = strength

	return target_strengths


func _should_render_node(node: MapNodeData) -> bool:
	if _debug_reveal_map:
		return true

	return node.is_visible or node.visited or node.id == _current_node_id


func _should_render_edge(source_id: int, target_id: int) -> bool:
	if _debug_reveal_map:
		return true

	return _run_data.is_edge_revealed(source_id, target_id) or _run_data.is_edge_traveled(source_id, target_id)


func _get_connection_key(source_id: int, target_id: int) -> String:
	return "%d:%d" % [source_id, target_id]


func _get_visual_center() -> Vector2:
	if _run_data == null or _run_data.nodes.is_empty():
		return size * 0.5

	var start_node: MapNodeData = _run_data.get_node_by_id(_run_data.start_node_id)
	if start_node != null:
		return _scale_point(start_node.position)

	return _scale_point(_run_data.nodes[0].position)


func _get_first_node_in_depth(depth: int) -> MapNodeData:
	for node in _run_data.nodes:
		if node.row == depth:
			return node

	return null


func _scale_point(point: Vector2) -> Vector2:
	return point * _zoom_factor


func _get_scaled_node_size() -> Vector2:
	return node_size * _zoom_factor


func _get_line_scale() -> float:
	return clampf(_zoom_factor, 0.65, 1.8)
