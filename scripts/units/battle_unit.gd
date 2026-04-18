class_name BattleUnit
extends RefCounted

var data: UnitData
var current_hp: int

func _init(unit_data: UnitData) -> void:
	data = unit_data
	current_hp = data.max_hp

func get_unit_name() -> String:
	return data.unit_name

func get_max_hp() -> int:
	return data.max_hp

func get_current_hp() -> int:
	return current_hp

func get_atk() -> int:
	return data.atk

func get_def() -> int:
	return data.def

func get_spd() -> int:
	return data.spd

func is_dead() -> bool:
	return current_hp <= 0

func take_damage(amount: int) -> int:
	var final_damage: int = max(1, amount - get_def())
	current_hp = max(0, current_hp - final_damage)
	return final_damage

func basic_attack(target: BattleUnit) -> int:
	return target.take_damage(get_atk())
