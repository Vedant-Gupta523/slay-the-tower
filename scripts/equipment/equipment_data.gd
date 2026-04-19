class_name EquipmentData
extends Resource

enum SlotType {
	WEAPON,
	ARMOR,
	ACCESSORY
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

const RARITY_DEFINITIONS := {
	Rarity.COMMON: {
		"name": "Common",
		"color": Color(0.78, 0.80, 0.82),
		"drop_weight": 58.0,
		"stat_multiplier": 1.0,
	},
	Rarity.UNCOMMON: {
		"name": "Uncommon",
		"color": Color(0.40, 0.86, 0.50),
		"drop_weight": 26.0,
		"stat_multiplier": 1.25,
	},
	Rarity.RARE: {
		"name": "Rare",
		"color": Color(0.38, 0.62, 1.0),
		"drop_weight": 12.0,
		"stat_multiplier": 1.5,
	},
	Rarity.EPIC: {
		"name": "Epic",
		"color": Color(0.75, 0.45, 1.0),
		"drop_weight": 3.5,
		"stat_multiplier": 1.85,
	},
	Rarity.LEGENDARY: {
		"name": "Legendary",
		"color": Color(1.0, 0.72, 0.24),
		"drop_weight": 0.5,
		"stat_multiplier": 2.25,
	},
}

@export var item_name: String = "Equipment"
@export_multiline var description: String = ""
@export var slot_type: SlotType = SlotType.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export var gold_value: int = 25

@export_category("Stat Bonuses")
@export var max_hp_bonus: int = 0
@export var atk_bonus: int = 0
@export var def_bonus: int = 0
@export var spd_bonus: int = 0

@export_category("Future Hooks")
@export var special_effect_key: String = ""

func get_display_name() -> String:
	return item_name

func get_item_category_name() -> String:
	return get_slot_name()

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

func get_rarity_name() -> String:
	return String(_get_rarity_definition_value(rarity, "name", "Common"))

func get_rarity_color() -> Color:
	return _get_rarity_definition_value(rarity, "color", Color.WHITE) as Color

func get_stat_multiplier() -> float:
	return float(_get_rarity_definition_value(rarity, "stat_multiplier", 1.0))

func get_max_hp_bonus() -> int:
	return _scale_stat(max_hp_bonus)

func get_atk_bonus() -> int:
	return _scale_stat(atk_bonus)

func get_def_bonus() -> int:
	return _scale_stat(def_bonus)

func get_spd_bonus() -> int:
	return _scale_stat(spd_bonus)

func get_purchase_price() -> int:
	return max(0, gold_value)

func get_sell_value() -> int:
	return int(floor(float(get_purchase_price()) * 0.7))

func get_stat_bonus(property_name: String) -> int:
	match property_name:
		"max_hp_bonus":
			return get_max_hp_bonus()
		"atk_bonus":
			return get_atk_bonus()
		"def_bonus":
			return get_def_bonus()
		"spd_bonus":
			return get_spd_bonus()
		_:
			return 0

func get_bonus_lines() -> Array[String]:
	var lines: Array[String] = []

	if get_max_hp_bonus() != 0:
		lines.append(_format_bonus("Max HP", get_max_hp_bonus()))

	if get_atk_bonus() != 0:
		lines.append(_format_bonus("ATK", get_atk_bonus()))

	if get_def_bonus() != 0:
		lines.append(_format_bonus("DEF", get_def_bonus()))

	if get_spd_bonus() != 0:
		lines.append(_format_bonus("SPD", get_spd_bonus()))

	return lines

func get_bonus_summary() -> String:
	var lines := get_bonus_lines()

	if lines.is_empty():
		return "No stat bonuses"

	return ", ".join(lines)

func _format_bonus(stat_name: String, value: int) -> String:
	var sign := "+" if value > 0 else ""
	return "%s%s %s" % [sign, value, stat_name]

func _scale_stat(value: int) -> int:
	if value == 0:
		return 0

	return int(round(float(value) * get_stat_multiplier()))

static func get_all_rarities() -> Array[int]:
	return [
		Rarity.COMMON,
		Rarity.UNCOMMON,
		Rarity.RARE,
		Rarity.EPIC,
		Rarity.LEGENDARY,
	]

static func get_rarity_drop_weight(rarity_value: int) -> float:
	return float(_get_static_rarity_definition_value(rarity_value, "drop_weight", 0.0))

static func roll_rarity(rng: RandomNumberGenerator) -> int:
	var total_weight := 0.0

	for rarity_value: int in get_all_rarities():
		total_weight += get_rarity_drop_weight(rarity_value)

	if total_weight <= 0.0:
		return Rarity.COMMON

	var roll := rng.randf_range(0.0, total_weight)
	var current := 0.0

	for rarity_value: int in get_all_rarities():
		current += get_rarity_drop_weight(rarity_value)
		if roll <= current:
			return rarity_value

	return Rarity.COMMON

static func _get_static_rarity_definition_value(rarity_value: int, key: String, default_value):
	var definition: Dictionary = RARITY_DEFINITIONS.get(rarity_value, RARITY_DEFINITIONS[Rarity.COMMON])
	return definition.get(key, default_value)

func _get_rarity_definition_value(rarity_value: int, key: String, default_value):
	return _get_static_rarity_definition_value(rarity_value, key, default_value)
