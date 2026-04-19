class_name EquipmentInstance
extends EquipmentData

const MAX_ENHANCEMENT_LEVEL := 100
const STAT_MULTIPLIER_PER_LEVEL := 0.02
const VALUE_MULTIPLIER_PER_LEVEL := 0.01

@export var base_item: EquipmentData
@export_range(0, MAX_ENHANCEMENT_LEVEL, 1) var enhancement_level: int = 0:
	set(value):
		enhancement_level = clamp(value, 0, MAX_ENHANCEMENT_LEVEL)
@export var enhancement_max_hp_bonus: int = 0
@export var enhancement_atk_bonus: int = 0
@export var enhancement_def_bonus: int = 0
@export var enhancement_spd_bonus: int = 0


static func from_equipment_data(item: EquipmentData) -> EquipmentInstance:
	if item == null:
		return null

	if item is EquipmentInstance:
		return item

	var instance := EquipmentInstance.new()
	instance.base_item = item
	instance.item_name = item.item_name
	instance.description = item.description
	instance.slot_type = item.slot_type
	instance.rarity = item.rarity
	instance.gold_value = item.gold_value
	instance.max_hp_bonus = item.max_hp_bonus
	instance.atk_bonus = item.atk_bonus
	instance.def_bonus = item.def_bonus
	instance.spd_bonus = item.spd_bonus
	instance.special_effect_key = item.special_effect_key
	instance.enhancement_level = 0
	return instance


func get_display_name() -> String:
	if enhancement_level <= 0:
		return item_name

	return "%s +%d" % [item_name, enhancement_level]


func get_enhancement_text() -> String:
	return "+%d" % enhancement_level


func can_enhance(amount: int = 1) -> bool:
	return enhancement_level + amount <= MAX_ENHANCEMENT_LEVEL


func add_enhancement_levels(amount: int = 1) -> void:
	if amount <= 0:
		return

	enhancement_level = min(MAX_ENHANCEMENT_LEVEL, enhancement_level + amount)


func add_enhancement_stat(stat_key: StringName, amount: int) -> void:
	if amount <= 0:
		return

	match stat_key:
		&"max_hp":
			enhancement_max_hp_bonus += amount
		&"atk":
			enhancement_atk_bonus += amount
		&"def":
			enhancement_def_bonus += amount
		&"spd":
			enhancement_spd_bonus += amount


func get_enhancement_bonus_lines() -> Array[String]:
	var lines: Array[String] = []
	if enhancement_max_hp_bonus != 0:
		lines.append("+%d Max HP" % enhancement_max_hp_bonus)
	if enhancement_atk_bonus != 0:
		lines.append("+%d ATK" % enhancement_atk_bonus)
	if enhancement_def_bonus != 0:
		lines.append("+%d DEF" % enhancement_def_bonus)
	if enhancement_spd_bonus != 0:
		lines.append("+%d SPD" % enhancement_spd_bonus)
	return lines


func get_enhancement_bonus_summary() -> String:
	var lines: Array[String] = get_enhancement_bonus_lines()
	if lines.is_empty():
		return "No enhancement bonuses yet"

	return ", ".join(lines)


func get_max_hp_bonus() -> int:
	return super.get_max_hp_bonus() + enhancement_max_hp_bonus


func get_atk_bonus() -> int:
	return super.get_atk_bonus() + enhancement_atk_bonus


func get_def_bonus() -> int:
	return super.get_def_bonus() + enhancement_def_bonus


func get_spd_bonus() -> int:
	return super.get_spd_bonus() + enhancement_spd_bonus


func get_stat_multiplier() -> float:
	return super.get_stat_multiplier() * get_enhancement_stat_multiplier()


func get_enhancement_stat_multiplier() -> float:
	return 1.0 + float(enhancement_level) * STAT_MULTIPLIER_PER_LEVEL


func get_purchase_price() -> int:
	var multiplier := 1.0 + float(enhancement_level) * VALUE_MULTIPLIER_PER_LEVEL
	return max(0, int(round(float(gold_value) * multiplier)))
