extends Control
class_name WorldMapController

signal node_selected(node_data: MapNodeData)

@export var run_state_path: NodePath
@export var auto_generate_if_missing: bool = true
@export var seed_override: int = 0

@export_group("Generation")
@export_range(8, 12, 1) var row_count: int = 10
@export_range(2, 4, 1) var min_middle_nodes: int = 2
@export_range(2, 4, 1) var max_middle_nodes: int = 4
@export var map_width: float = 1024.0
@export var side_padding: float = 96.0
@export var top_padding: float = 96.0
@export var horizontal_spacing: float = 220.0
@export var vertical_spacing: float = 140.0
@export var horizontal_jitter: float = 34.0
@export var row_vertical_jitter: float = 18.0
@export var min_node_gap: float = 92.0
@export var row_center_drift: float = 72.0
@export_range(0.0, 0.85, 0.01) var cluster_strength: float = 0.38
@export var prevent_consecutive_safe_nodes: bool = true

@export_group("Type Weights")
@export var combat_weight: int = 55
@export var event_weight: int = 22
@export var elite_weight: int = 10
@export var shop_weight: int = 6
@export var rest_weight: int = 5
@export var treasure_weight: int = 2

@onready var map_view: MapView = $PanelContainer/MarginContainer/ScrollContainer/MapView

var _generator := MapGenerator.new()
var _run_state: MapRunState


func _ready() -> void:
	if _run_state == null:
		_run_state = _resolve_run_state()

	map_view.node_pressed.connect(_on_map_view_node_pressed)
	_bind_run_state()

	if auto_generate_if_missing and _run_state != null and not _run_state.has_active_run():
		start_new_run(seed_override)
	else:
		refresh()


func start_new_run(seed: int = 0) -> void:
	_run_state.create_new_run(_generator, _build_generator_config(), seed)


func refresh() -> void:
	if _run_state == null or not _run_state.has_active_run():
		map_view.display_run(null, [], -1)
		return

	var run_data: MapRunData = _run_state.get_run_data()
	map_view.display_run(run_data, _run_state.get_reachable_node_ids(), run_data.current_node_id)


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
		"side_padding": side_padding,
		"top_padding": top_padding,
		"horizontal_spacing": horizontal_spacing,
		"vertical_spacing": vertical_spacing,
		"horizontal_jitter": horizontal_jitter,
		"row_vertical_jitter": row_vertical_jitter,
		"min_node_gap": min_node_gap,
		"row_center_drift": row_center_drift,
		"cluster_strength": cluster_strength,
		"prevent_consecutive_safe_nodes": prevent_consecutive_safe_nodes,
		"combat_weight": combat_weight,
		"event_weight": event_weight,
		"elite_weight": elite_weight,
		"shop_weight": shop_weight,
		"rest_weight": rest_weight,
		"treasure_weight": treasure_weight,
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
	emit_signal("node_selected", selected_node)


func _on_run_state_updated(_run_data: MapRunData) -> void:
	refresh()


func _bind_run_state() -> void:
	if _run_state == null:
		return

	if not _run_state.run_updated.is_connected(_on_run_state_updated):
		_run_state.run_updated.connect(_on_run_state_updated)


func _unbind_run_state() -> void:
	if _run_state == null:
		return

	if _run_state.run_updated.is_connected(_on_run_state_updated):
		_run_state.run_updated.disconnect(_on_run_state_updated)
