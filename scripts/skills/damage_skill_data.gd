class_name DamageSkillData
extends SkillData

@export var power: int = 10

func execute(user, target) -> SkillResult:
	var result := SkillResult.new()
	result.damage = target.take_damage(power)
	result.message = "It deals %d damage." % result.damage
	return result
