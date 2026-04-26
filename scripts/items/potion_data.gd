class_name PotionData
extends ItemData

@export var heal_amount: int = 0
@export var damage_amount: int = 0
@export var buff_stats: Dictionary = {}
@export var debuff_stats: Dictionary = {}
@export var duration_turns: int = 0
@export var is_mixed_effect: bool = false


func get_item_category_name() -> String:
	return "Potion"


func get_detail_lines() -> Array[String]:
	var lines: Array[String] = []
	if heal_amount != 0:
		lines.append(_format_signed_line("Heal", heal_amount))
	if damage_amount != 0:
		lines.append(_format_signed_line("Damage", damage_amount))
	for stat_key in buff_stats.keys():
		lines.append(_format_signed_line(_get_stat_name(StringName(stat_key)), int(buff_stats[stat_key])))
	for stat_key in debuff_stats.keys():
		lines.append(_format_signed_line(_get_stat_name(StringName(stat_key)), -abs(int(debuff_stats[stat_key]))))
	if duration_turns > 0 and (not buff_stats.is_empty() or not debuff_stats.is_empty()):
		lines.append("%d turns" % duration_turns)
	if is_mixed_effect:
		lines.append("Mixed effect")
	return lines


func _format_signed_line(label: String, amount: int) -> String:
	var sign := "+" if amount > 0 else ""
	return "%s%s %s" % [sign, amount, label]


func _get_stat_name(stat_key: StringName) -> String:
	match stat_key:
		&"max_hp":
			return "Max HP"
		&"atk":
			return "ATK"
		&"def":
			return "DEF"
		&"spd":
			return "SPD"
		_:
			return String(stat_key).capitalize()
