class_name MaterialData
extends ItemData

const TYPE_MYSTERIOUS_INGREDIENT := &"mysterious_ingredient"
const TYPE_BOTTLE := &"bottle"
const TYPE_MONSTER_MATERIAL := &"monster_material"

@export var material_type: StringName = TYPE_MYSTERIOUS_INGREDIENT


func get_item_category_name() -> String:
	match material_type:
		TYPE_MYSTERIOUS_INGREDIENT:
			return "Mysterious Ingredient"
		TYPE_BOTTLE:
			return "Bottle"
		TYPE_MONSTER_MATERIAL:
			return "Monster Material"
		_:
			return "Material"


func get_detail_lines() -> Array[String]:
	return [get_item_category_name()]


func has_tag(tag: StringName) -> bool:
	return tag == material_type or super.has_tag(tag)
