extends Button
class_name MapNodeButton

signal node_pressed(node_id: int)

const TYPE_NAMES := {
	MapNodeData.TYPE_COMBAT: "Combat",
	MapNodeData.TYPE_ELITE: "Elite",
	MapNodeData.TYPE_EVENT: "Event",
	MapNodeData.TYPE_RESOURCE: "Resource",
	MapNodeData.TYPE_BOSS: "Boss",
}

const OUTER_SHADOW_COLOR := Color(0.02, 0.03, 0.05, 0.38)
const DISABLED_WASH_COLOR := Color(0.1, 0.11, 0.13, 0.38)
const HOVER_RING_COLOR := Color(0.96, 0.94, 0.82, 0.16)
const CURRENT_RING_COLOR := Color(1.0, 0.93, 0.62, 0.24)
const REACHABLE_RING_COLOR := Color(0.78, 0.88, 1.0, 0.18)

var node_data: MapNodeData
var _is_current := false
var _is_reachable := false
var _is_visited := false
var _is_hovered := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	text = ""
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)


func setup(node: MapNodeData, button_size: Vector2) -> void:
	node_data = node
	custom_minimum_size = button_size
	size = button_size
	tooltip_text = "%s node\nRow %d\nNode %d" % [
		TYPE_NAMES.get(node.node_type, "Unknown"),
		node.row,
		node.id,
	]
	queue_redraw()


func apply_state(is_current: bool, is_reachable: bool, is_visited: bool) -> void:
	_is_current = is_current
	_is_reachable = is_reachable
	_is_visited = is_visited
	disabled = not is_reachable
	queue_redraw()


func _draw() -> void:
	if node_data == null:
		return

	var center: Vector2 = size * 0.5
	var radius: float = min(size.x, size.y) * _get_radius_scale(node_data.node_type)
	var fill_color: Color = _get_type_fill_color(node_data.node_type)
	var border_color: Color = _get_type_border_color(node_data.node_type)
	var icon_color: Color = _get_icon_color(node_data.node_type)

	if _is_visited:
		fill_color = fill_color.darkened(0.18)

	if disabled:
		fill_color = fill_color.darkened(0.18)
		fill_color.a = 0.58
		border_color.a = 0.55
		icon_color.a = 0.7

	var ring_color: Color = Color.TRANSPARENT
	if _is_current:
		ring_color = CURRENT_RING_COLOR
	elif _is_reachable:
		ring_color = REACHABLE_RING_COLOR

	if _is_hovered and not disabled:
		ring_color = HOVER_RING_COLOR if not _is_current else CURRENT_RING_COLOR.lightened(0.08)

	if ring_color.a > 0.0:
		draw_circle(center, radius + 11.0, ring_color)

	draw_circle(center + Vector2(0, 4), radius + 2.0, OUTER_SHADOW_COLOR)
	_draw_node_body(center, radius, fill_color, border_color)
	_draw_node_icon(center, radius * 0.98, icon_color)

	if disabled:
		draw_circle(center, radius - 1.0, DISABLED_WASH_COLOR)


func _draw_node_body(center: Vector2, radius: float, fill_color: Color, border_color: Color) -> void:
	match node_data.node_type:
		MapNodeData.TYPE_EVENT:
			_draw_diamond(center, radius + 2.0, border_color)
			_draw_diamond(center, radius - 3.0, fill_color)
		MapNodeData.TYPE_RESOURCE:
			_draw_hex(center, radius + 1.0, border_color)
			_draw_hex(center, radius - 4.0, fill_color)
		MapNodeData.TYPE_BOSS:
			_draw_octagon(center, radius + 1.0, border_color)
			_draw_octagon(center, radius - 4.0, fill_color)
		_:
			draw_circle(center, radius + 2.0, border_color)
			draw_circle(center, radius - 2.0, fill_color)


func _draw_node_icon(center: Vector2, radius: float, icon_color: Color) -> void:
	match node_data.node_type:
		MapNodeData.TYPE_COMBAT:
			draw_line(center + Vector2(-radius * 0.38, -radius * 0.38), center + Vector2(radius * 0.34, radius * 0.34), icon_color, 5.0, true)
			draw_line(center + Vector2(radius * 0.22, -radius * 0.5), center + Vector2(radius * 0.48, -radius * 0.24), icon_color, 5.0, true)
			draw_line(center + Vector2(-radius * 0.28, radius * 0.44), center + Vector2(-radius * 0.52, radius * 0.18), icon_color, 5.0, true)
		MapNodeData.TYPE_ELITE:
			_draw_triangle(center + Vector2(0, -radius * 0.1), radius * 0.56, icon_color)
			draw_circle(center + Vector2(0, radius * 0.26), radius * 0.12, Color(0.12, 0.09, 0.05, 0.95))
		MapNodeData.TYPE_EVENT:
			draw_circle(center, radius * 0.18, icon_color)
			draw_line(center + Vector2(0, radius * 0.3), center + Vector2(0, -radius * 0.18), icon_color, 4.0, true)
			draw_arc(center, radius * 0.44, PI * 1.15, PI * 1.85, 12, icon_color, 4.0)
		MapNodeData.TYPE_RESOURCE:
			draw_rect(Rect2(center + Vector2(-radius * 0.34, -radius * 0.06), Vector2(radius * 0.68, radius * 0.38)), icon_color, true)
			draw_line(center + Vector2(-radius * 0.34, -radius * 0.06), center + Vector2(radius * 0.34, -radius * 0.06), _get_type_fill_color(node_data.node_type), 4.0, true)
			draw_circle(center + Vector2(0, radius * 0.1), radius * 0.08, _get_type_fill_color(node_data.node_type))
		MapNodeData.TYPE_BOSS:
			_draw_triangle(center + Vector2(0, -radius * 0.08), radius * 0.62, icon_color)
			draw_line(center + Vector2(-radius * 0.16, radius * 0.42), center + Vector2(radius * 0.16, radius * 0.42), icon_color, 4.0, true)


func _draw_triangle(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0, -radius),
			center + Vector2(radius * 0.9, radius * 0.75),
			center + Vector2(-radius * 0.9, radius * 0.75),
		]),
		color
	)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0, -radius),
			center + Vector2(radius, 0),
			center + Vector2(0, radius),
			center + Vector2(-radius, 0),
		]),
		color
	)


func _draw_hex(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(6):
		var angle: float = PI / 6.0 + TAU * float(index) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)


func _draw_octagon(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(8):
		var angle: float = PI / 8.0 + TAU * float(index) / 8.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)


func _get_radius_scale(node_type: StringName) -> float:
	match node_type:
		MapNodeData.TYPE_BOSS:
			return 0.39
		MapNodeData.TYPE_ELITE:
			return 0.35
		MapNodeData.TYPE_RESOURCE:
			return 0.34
		_:
			return 0.32


func _get_type_fill_color(node_type: StringName) -> Color:
	match node_type:
		MapNodeData.TYPE_COMBAT:
			return Color(0.7, 0.24, 0.2)
		MapNodeData.TYPE_ELITE:
			return Color(0.76, 0.38, 0.12)
		MapNodeData.TYPE_EVENT:
			return Color(0.28, 0.38, 0.68)
		MapNodeData.TYPE_RESOURCE:
			return Color(0.78, 0.6, 0.16)
		MapNodeData.TYPE_BOSS:
			return Color(0.48, 0.15, 0.16)
		_:
			return Color(0.34, 0.36, 0.4)


func _get_type_border_color(node_type: StringName) -> Color:
	match node_type:
		MapNodeData.TYPE_ELITE:
			return Color(1.0, 0.8, 0.45)
		MapNodeData.TYPE_RESOURCE:
			return Color(1.0, 0.88, 0.52)
		MapNodeData.TYPE_BOSS:
			return Color(1.0, 0.75, 0.56)
		_:
			return Color(0.91, 0.95, 0.98, 0.95)


func _get_icon_color(node_type: StringName) -> Color:
	match node_type:
		MapNodeData.TYPE_RESOURCE:
			return Color(0.15, 0.13, 0.08)
		_:
			return Color(0.96, 0.97, 0.98)


func _on_mouse_entered() -> void:
	_is_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_is_hovered = false
	queue_redraw()


func _on_pressed() -> void:
	if node_data == null:
		return

	emit_signal("node_pressed", node_data.id)
