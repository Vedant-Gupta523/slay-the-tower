class_name EquipmentData
extends Resource

enum SlotType {
	WEAPON,
	ARMOR,
	ACCESSORY
}

@export var item_name: String = "Equipment"
@export_multiline var description: String = ""
@export var slot_type: SlotType = SlotType.WEAPON

@export_category("Stat Bonuses")
@export var max_hp_bonus: int = 0
@export var atk_bonus: int = 0
@export var def_bonus: int = 0
@export var spd_bonus: int = 0

@export_category("Future Hooks")
@export var special_effect_key: String = ""

func get_slot_name() -> String:
	match slot_type:
		SlotType.WEAPON:
			return "Weapon"
		SlotType.ARMOR:
			return "Armor"
		SlotType.ACCESSORY:
			return "Accessory"
		_:
			return "Unknown"

func get_bonus_lines() -> Array[String]:
	var lines: Array[String] = []

	if max_hp_bonus != 0:
		lines.append(_format_bonus("Max HP", max_hp_bonus))

	if atk_bonus != 0:
		lines.append(_format_bonus("ATK", atk_bonus))

	if def_bonus != 0:
		lines.append(_format_bonus("DEF", def_bonus))

	if spd_bonus != 0:
		lines.append(_format_bonus("SPD", spd_bonus))

	return lines

func get_bonus_summary() -> String:
	var lines := get_bonus_lines()

	if lines.is_empty():
		return "No stat bonuses"

	return ", ".join(lines)

func _format_bonus(stat_name: String, value: int) -> String:
	var sign := "+" if value > 0 else ""
	return "%s%s %s" % [sign, value, stat_name]
