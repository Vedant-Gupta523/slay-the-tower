class_name BattleUnit
extends RefCounted

var data: UnitData
var current_hp: int
var is_defending: bool = false

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

func start_defending() -> void:
	is_defending = true

func stop_defending() -> void:
	is_defending = false

func take_damage(amount: int) -> int:
	var mitigated_damage: int = max(1, amount - get_def())

	if is_defending:
		mitigated_damage = max(1, mitigated_damage / 2)
		stop_defending()

	current_hp = max(0, current_hp - mitigated_damage)
	return mitigated_damage

func basic_attack(target: BattleUnit) -> int:
	return target.take_damage(get_atk())
