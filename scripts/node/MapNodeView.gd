extends TextureButton
class_name MapNodeView

var node: MapNode


func set_node(node_data: MapNode) -> void:
	node = node_data
	_load_icon()
	tooltip_text = "%s (%s)" % [node.id, _get_type_name(node.type)]
	visible = not node.hidden


func _load_icon() -> void:
	var texture: Texture2D = null

	if not node.sprite_path.is_empty() and ResourceLoader.exists(node.sprite_path):
		texture = load(node.sprite_path) as Texture2D

	texture_normal = texture
	texture_hover = texture
	texture_pressed = texture
	texture_disabled = texture


func _get_type_name(node_type: MapNode.NodeType) -> String:
	match node_type:
		MapNode.NodeType.ENEMY:
			return "Enemy"
		MapNode.NodeType.ELITE:
			return "Elite"
		MapNode.NodeType.EVENT:
			return "Event"
		MapNode.NodeType.REST:
			return "Rest"
		MapNode.NodeType.TREASURE:
			return "Treasure"
		MapNode.NodeType.BOSS:
			return "Boss"
		_:
			return "Unknown"
