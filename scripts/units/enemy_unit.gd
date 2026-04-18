class_name EnemyUnit
extends BattleUnit

func _init(unit_data: UnitData) -> void:
	super(unit_data)

func choose_action_target(possible_targets: Array[BattleUnit]) -> BattleUnit:
	for target in possible_targets:
		if not target.is_dead():
			return target
	return null
