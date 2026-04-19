extends Resource
class_name MapNode

enum NodeType {
	ENEMY,
	ELITE,
	EVENT,
	REST,
	TREASURE,
	BOSS,
}

@export var id: String = ""
@export var row: int = 0
@export var column: int = 0
@export var type: NodeType = NodeType.ENEMY
@export var connected_to: Array[String] = []
@export var sprite_path: String = ""
@export var hidden: bool = false
