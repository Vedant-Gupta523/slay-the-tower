extends Resource
class_name MapNodeData

@export var id: int = -1
@export var row: int = 0
@export var position: Vector2 = Vector2.ZERO
@export var node_type: StringName = &"combat"
@export var connected_to: Array[int] = []
@export var visited: bool = false


func duplicate_node() -> MapNodeData:
	var copy := MapNodeData.new()
	copy.id = id
	copy.row = row
	copy.position = position
	copy.node_type = node_type
	copy.connected_to = connected_to.duplicate()
	copy.visited = visited
	return copy
