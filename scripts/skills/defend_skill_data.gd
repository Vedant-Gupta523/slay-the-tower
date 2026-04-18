class_name DefendSkillData
extends SkillData

func execute(user, target) -> SkillResult:
	var result := SkillResult.new()
	user.start_defending()
	result.message = "It takes a defensive stance."
	return result
