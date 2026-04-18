class_name SkillInstance
extends RefCounted

var data: SkillData
var remaining_cooldown: int = 0

func _init(skill_data: SkillData) -> void:
	data = skill_data

func get_skill_name() -> String:
	return data.skill_name

func get_description() -> String:
	return data.description

func get_target_type():
	return data.target_type

func is_available() -> bool:
	return remaining_cooldown == 0

func get_remaining_cooldown() -> int:
	return remaining_cooldown

func use(user, target) -> SkillResult:
	var result: SkillResult = data.execute(user, target)
	remaining_cooldown = data.cooldown_turns
	return result

func reduce_cooldown() -> void:
	if remaining_cooldown > 0:
		remaining_cooldown -= 1
