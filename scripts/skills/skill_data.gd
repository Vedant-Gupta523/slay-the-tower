class_name SkillData
extends Resource

enum TargetType {
	ENEMY,
	SELF
}

@export var skill_name: String = "Skill"
@export_multiline var description: String = ""
@export var cooldown_turns: int = 0
@export var target_type: TargetType = TargetType.ENEMY

func create_instance() -> SkillInstance:
	return SkillInstance.new(self)

func execute(user, target) -> SkillResult:
	return SkillResult.new()
