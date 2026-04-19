extends Resource
class_name MapNodeData

const TYPE_COMBAT := &"combat"
const TYPE_ELITE := &"elite"
const TYPE_BOSS := &"boss"
const TYPE_RESOURCE := &"resource"
const TYPE_EVENT := &"event"

@export var id: int = -1
@export var row: int = 0
@export var position: Vector2 = Vector2.ZERO
@export var angle: float = 0.0
@export var node_type: StringName = TYPE_COMBAT
@export var connected_to: Array[int] = []
@export var visited: bool = false
@export var is_discovered: bool = false
@export var is_visible: bool = false
@export var is_completed: bool = false
@export var is_available: bool = false


func duplicate_node() -> MapNodeData:
	var copy: MapNodeData = MapNodeData.new()
	copy.id = id
	copy.row = row
	copy.position = position
	copy.angle = angle
	copy.node_type = node_type
	copy.connected_to = connected_to.duplicate()
	copy.visited = visited
	copy.is_discovered = is_discovered
	copy.is_visible = is_visible
	copy.is_completed = is_completed
	copy.is_available = is_available
	return copy


func is_combat_node() -> bool:
	return is_combat_type(node_type)


func is_terminal_boss() -> bool:
	return node_type == TYPE_BOSS


func get_type_label() -> String:
	match node_type:
		TYPE_COMBAT:
			return "Combat"
		TYPE_ELITE:
			return "Elite"
		TYPE_BOSS:
			return "Boss"
		TYPE_RESOURCE:
			return "Resource"
		TYPE_EVENT:
			return "Event"
		_:
			return "Unknown"


static func is_combat_type(value: StringName) -> bool:
	return value == TYPE_COMBAT or value == TYPE_ELITE or value == TYPE_BOSS


static func normalize_node_type(value: StringName) -> StringName:
	match value:
		TYPE_COMBAT, TYPE_ELITE, TYPE_BOSS, TYPE_RESOURCE, TYPE_EVENT:
			return value
		&"treasure", &"shop", &"rest":
			return TYPE_RESOURCE
		&"start":
			return TYPE_COMBAT
		_:
			return TYPE_COMBAT
