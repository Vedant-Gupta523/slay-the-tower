class_name ItemData
extends Resource

@export var item_id: StringName = &"item"
@export var item_name: String = "Item"
@export_multiline var description: String = ""
@export var rarity: EquipmentData.Rarity = EquipmentData.Rarity.COMMON
@export var gold_value: int = 15
@export var item_tags: Array[StringName] = []


func get_display_name() -> String:
	return item_name


func get_item_category_name() -> String:
	return "Item"


func get_rarity_name() -> String:
	var definition: Dictionary = EquipmentData.RARITY_DEFINITIONS.get(rarity, EquipmentData.RARITY_DEFINITIONS[EquipmentData.Rarity.COMMON])
	return String(definition.get("name", "Common"))


func get_rarity_color() -> Color:
	var definition: Dictionary = EquipmentData.RARITY_DEFINITIONS.get(rarity, EquipmentData.RARITY_DEFINITIONS[EquipmentData.Rarity.COMMON])
	return definition.get("color", Color.WHITE) as Color


func get_purchase_price() -> int:
	return max(0, gold_value)


func get_sell_value() -> int:
	return int(floor(float(get_purchase_price()) * 0.7))


func has_tag(tag: StringName) -> bool:
	return item_tags.has(tag)


func get_detail_lines() -> Array[String]:
	return []


func get_detail_summary() -> String:
	var lines := get_detail_lines()
	return ", ".join(lines) if not lines.is_empty() else "No special properties"
