extends Control
class_name WorldMapController

signal node_selected(node_data: MapNodeData)
signal node_resolution_requested(node_data: MapNodeData, resolution: Dictionary)

@export var run_state_path: NodePath
@export var auto_generate_if_missing: bool = true
@export var seed_override: int = 0

@export_group("Generation")
@export_range(6, 10, 1) var row_count: int = 8
@export_range(3, 6, 1) var min_middle_nodes: int = 3
@export_range(4, 7, 1) var max_middle_nodes: int = 5
@export var map_width: float = 1800.0
@export var map_height: float = 1800.0
@export var vertical_spacing: float = 170.0
@export var horizontal_jitter: float = 0.18
@export var row_vertical_jitter: float = 14.0
@export var side_padding: float = 220.0
@export var top_padding: float = 0.28
@export var boss_count: int = 3
@export var prevent_consecutive_safe_nodes: bool = true
@export var content_margin_left: float = 120.0
@export var content_margin_right: float = 120.0
@export var content_margin_top: float = 120.0
@export var content_margin_bottom: float = 120.0

@export_group("Navigation")
@export var zoom_step: float = 0.12
@export var min_zoom: float = 0.65
@export var max_zoom: float = 1.9
@export var initial_zoom: float = 1.0

@export_group("Type Weights")
@export var combat_weight: int = 55
@export var event_weight: int = 22
@export var elite_weight: int = 10
@export var resource_weight: int = 13

@onready var map_view: MapView = $PanelContainer/MarginContainer/ScrollContainer/MapView
@onready var scroll_container: ScrollContainer = $PanelContainer/MarginContainer/ScrollContainer
@onready var resource_hud: PanelContainer = $ResourceHud
@onready var gold_label: Label = %GoldLabel
@onready var materials_label: Label = %MaterialsLabel
@onready var ores_label: Label = %OresLabel
@onready var herbs_label: Label = %HerbsLabel

var _generator: MapGenerator = MapGenerator.new()
var _run_state: MapRunState
var _debug_reveal_map: bool = false
var _map_zoom: float = 1.0


func _ready() -> void:
	if _run_state == null:
		_run_state = _resolve_run_state()

	_setup_resource_hud()
	map_view.node_pressed.connect(_on_map_view_node_pressed)
	if map_view.has_signal("pan_requested"):
		map_view.pan_requested.connect(_on_map_pan_requested)
	if map_view.has_signal("zoom_requested"):
		map_view.zoom_requested.connect(_on_map_zoom_requested)
	_bind_run_state()
	_bind_expedition_state()
	_map_zoom = clampf(initial_zoom, min_zoom, max_zoom)
	_apply_zoom()
	_refresh_resource_hud()

	if auto_generate_if_missing and _run_state != null and not _run_state.has_active_run():
		start_new_run(seed_override)
	else:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_debug_reveal_map = not _debug_reveal_map
		_apply_debug_reveal_state()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse_button_event: InputEventMouseButton = event
		if not _is_mouse_over_map():
			return

		if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_on_map_zoom_requested(1, map_view.get_local_mouse_position())
			get_viewport().set_input_as_handled()
		elif mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_on_map_zoom_requested(-1, map_view.get_local_mouse_position())
			get_viewport().set_input_as_handled()


func start_new_run(seed: int = 0) -> void:
	_run_state.create_new_run(_generator, _build_generator_config(), seed)


func refresh() -> void:
	if _run_state == null or not _run_state.has_active_run():
		map_view.display_run(null, [], -1)
		_apply_debug_reveal_state()
		return

	var run_data: MapRunData = _run_state.get_run_data()
	map_view.display_run(run_data, _run_state.get_reachable_node_ids(), run_data.current_node_id)
	_apply_debug_reveal_state()
	call_deferred("_focus_map_on_current_or_start")


func get_run_state() -> MapRunState:
	return _run_state


func set_run_state(run_state: MapRunState) -> void:
	if _run_state == run_state:
		return

	_unbind_run_state()
	_run_state = run_state

	if is_node_ready():
		_bind_run_state()
		refresh()


func _build_generator_config() -> Dictionary:
	return {
		"row_count": row_count,
		"min_middle_nodes": min_middle_nodes,
		"max_middle_nodes": max_middle_nodes,
		"map_width": map_width,
		"map_height": map_height,
		"center_margin": side_padding,
		"ring_spacing": vertical_spacing,
		"angle_jitter": horizontal_jitter,
		"ring_radius_jitter": row_vertical_jitter,
		"phase_drift": top_padding,
		"boss_count": boss_count,
		"content_margin_left": content_margin_left,
		"content_margin_right": content_margin_right,
		"content_margin_top": content_margin_top,
		"content_margin_bottom": content_margin_bottom,
		"prevent_consecutive_safe_nodes": prevent_consecutive_safe_nodes,
		"combat_weight": combat_weight,
		"event_weight": event_weight,
		"elite_weight": elite_weight,
		"resource_weight": resource_weight,
	}


func _resolve_run_state() -> MapRunState:
	var resolved_run_state: MapRunState = null

	if not run_state_path.is_empty():
		resolved_run_state = get_node_or_null(run_state_path) as MapRunState

	if resolved_run_state == null:
		resolved_run_state = get_node_or_null("/root/MapRunState") as MapRunState

	if resolved_run_state != null:
		return resolved_run_state

	resolved_run_state = MapRunState.new()
	resolved_run_state.name = "LocalMapRunState"
	add_child(resolved_run_state)
	return resolved_run_state


func _on_map_view_node_pressed(node_id: int) -> void:
	if _run_state == null or not _run_state.can_travel_to(node_id):
		return

	var selected_node: MapNodeData = _run_state.get_run_data().get_node_by_id(node_id)
	if selected_node == null:
		return

	var resolution: Dictionary = _run_state.resolve_selected_node(node_id)
	emit_signal("node_selected", selected_node)

	if resolution.is_empty():
		return

	if StringName(resolution.get("kind", &"")) == MapRunState.RESOLUTION_MOVE:
		refresh()
		return

	emit_signal("node_resolution_requested", selected_node, resolution)


func _on_run_state_updated(_run_data: MapRunData) -> void:
	refresh()


func _on_expedition_resources_changed() -> void:
	_refresh_resource_hud()


func _focus_map_on_current_or_start() -> void:
	if _run_state == null or not _run_state.has_active_run():
		return

	var run_data: MapRunData = _run_state.get_run_data()
	if run_data == null:
		return

	var target_node_id: int = run_data.current_node_id if run_data.current_node_id >= 0 else run_data.start_node_id
	var target_node: MapNodeData = run_data.get_node_by_id(target_node_id)
	if target_node == null:
		return

	var zoomed_position: Vector2 = target_node.position * _map_zoom
	scroll_container.scroll_horizontal = int(max(0.0, zoomed_position.x - scroll_container.size.x * 0.5))
	scroll_container.scroll_vertical = int(max(0.0, zoomed_position.y - scroll_container.size.y * 0.5))


func _apply_debug_reveal_state() -> void:
	if map_view == null:
		return

	if map_view.has_method("set_debug_reveal_map"):
		map_view.call("set_debug_reveal_map", _debug_reveal_map)


func _apply_zoom() -> void:
	if map_view == null:
		return

	if map_view.has_method("set_zoom_factor"):
		map_view.call("set_zoom_factor", _map_zoom)


func _on_map_pan_requested(delta: Vector2) -> void:
	scroll_container.scroll_horizontal = int(clampf(
		scroll_container.scroll_horizontal - delta.x,
		0.0,
		_get_max_scroll().x
	))
	scroll_container.scroll_vertical = int(clampf(
		scroll_container.scroll_vertical - delta.y,
		0.0,
		_get_max_scroll().y
	))


func _on_map_zoom_requested(direction: int, focus_position: Vector2) -> void:
	var previous_zoom: float = _map_zoom
	var next_zoom: float = clampf(_map_zoom + zoom_step * float(direction), min_zoom, max_zoom)
	if is_equal_approx(previous_zoom, next_zoom):
		return

	var previous_scroll: Vector2 = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
	var viewport_focus: Vector2 = focus_position - previous_scroll
	var content_focus: Vector2 = focus_position / previous_zoom

	_map_zoom = next_zoom
	_apply_zoom()

	var updated_scroll: Vector2 = content_focus * _map_zoom - viewport_focus
	var max_scroll: Vector2 = _get_max_scroll()
	scroll_container.scroll_horizontal = int(clampf(updated_scroll.x, 0.0, max_scroll.x))
	scroll_container.scroll_vertical = int(clampf(updated_scroll.y, 0.0, max_scroll.y))


func _get_max_scroll() -> Vector2:
	if map_view == null:
		return Vector2.ZERO

	return Vector2(
		maxf(0.0, map_view.custom_minimum_size.x - scroll_container.size.x),
		maxf(0.0, map_view.custom_minimum_size.y - scroll_container.size.y)
	)


func _is_mouse_over_map() -> bool:
	if scroll_container == null:
		return false

	return Rect2(scroll_container.global_position, scroll_container.size).has_point(get_global_mouse_position())


func _bind_run_state() -> void:
	if _run_state == null:
		return

	if not _run_state.run_updated.is_connected(_on_run_state_updated):
		_run_state.run_updated.connect(_on_run_state_updated)


func _bind_expedition_state() -> void:
	if ExpeditionState == null:
		return

	if ExpeditionState.has_signal("resources_changed") and not ExpeditionState.resources_changed.is_connected(_on_expedition_resources_changed):
		ExpeditionState.resources_changed.connect(_on_expedition_resources_changed)


func _unbind_run_state() -> void:
	if _run_state == null:
		return

	if _run_state.run_updated.is_connected(_on_run_state_updated):
		_run_state.run_updated.disconnect(_on_run_state_updated)


func _exit_tree() -> void:
	if ExpeditionState != null and ExpeditionState.has_signal("resources_changed") and ExpeditionState.resources_changed.is_connected(_on_expedition_resources_changed):
		ExpeditionState.resources_changed.disconnect(_on_expedition_resources_changed)


func _setup_resource_hud() -> void:
	if resource_hud == null:
		return

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.11, 0.92)
	panel_style.border_color = Color(0.78, 0.82, 0.9, 0.72)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	panel_style.shadow_size = 6
	panel_style.shadow_offset = Vector2(0, 2)
	resource_hud.add_theme_stylebox_override("panel", panel_style)

	if gold_label != null:
		gold_label.modulate = Color(1.0, 0.9, 0.52)
	if materials_label != null:
		materials_label.modulate = Color(0.82, 0.96, 0.82)
	if ores_label != null:
		ores_label.modulate = Color(0.78, 0.86, 0.95)
	if herbs_label != null:
		herbs_label.modulate = Color(0.72, 0.95, 0.8)


func _refresh_resource_hud() -> void:
	if gold_label == null:
		return

	gold_label.text = "Gold: %d" % ExpeditionState.gold
	materials_label.text = "Materials: %d" % ExpeditionState.monster_materials
	ores_label.text = "Ores: %d" % ExpeditionState.ores
	herbs_label.text = "Herbs: %d" % ExpeditionState.herbs
