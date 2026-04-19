extends Node
class_name WorldMapFlowExample

@export var world_map_path: NodePath

@onready var world_map: WorldMapController = get_node_or_null(world_map_path) as WorldMapController


func _ready() -> void:
	if world_map == null:
		return

	world_map.node_selected.connect(_on_world_map_node_selected)


func _on_world_map_node_selected(node_data: MapNodeData) -> void:
	match node_data.node_type:
		MapNodeData.TYPE_COMBAT:
			_enter_combat(node_data)
		MapNodeData.TYPE_ELITE:
			_enter_elite_combat(node_data)
		MapNodeData.TYPE_EVENT:
			_open_event(node_data)
		MapNodeData.TYPE_RESOURCE:
			_open_resource(node_data)
		MapNodeData.TYPE_BOSS:
			_enter_boss(node_data)
		_:
			print("Unhandled node type: %s" % node_data.node_type)


func _enter_combat(node_data: MapNodeData) -> void:
	print("Load combat scene for node %d." % node_data.id)


func _enter_elite_combat(node_data: MapNodeData) -> void:
	print("Load elite combat scene for node %d." % node_data.id)


func _open_event(node_data: MapNodeData) -> void:
	print("Open event scene for node %d." % node_data.id)


func _open_resource(node_data: MapNodeData) -> void:
	print("Grant resource reward for node %d." % node_data.id)


func _enter_boss(node_data: MapNodeData) -> void:
	print("Load boss encounter for node %d." % node_data.id)
