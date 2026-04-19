class_name SkillLoadout
extends RefCounted

const MAX_ACTIVE_SKILLS := 5

var owned_skills: Array[SkillData] = []
var equipped_skills: Array[SkillData] = []


func _init(initial_skills: Array[SkillData] = []) -> void:
	equipped_skills.resize(MAX_ACTIVE_SKILLS)

	for skill: SkillData in initial_skills:
		add_owned_skill(skill)

	for index in range(min(MAX_ACTIVE_SKILLS, owned_skills.size())):
		equipped_skills[index] = owned_skills[index]


func add_owned_skill(skill: SkillData) -> void:
	if skill == null or owned_skills.has(skill):
		return

	owned_skills.append(skill)


func get_equipped_skills() -> Array[SkillData]:
	var copy: Array[SkillData] = []
	copy.assign(equipped_skills)
	return copy


func get_active_skills() -> Array[SkillData]:
	var active: Array[SkillData] = []

	for skill: SkillData in equipped_skills:
		if skill != null:
			active.append(skill)

	return active


func get_reserve_skills() -> Array[SkillData]:
	var reserve: Array[SkillData] = []

	for skill: SkillData in owned_skills:
		if skill != null and not is_skill_equipped(skill):
			reserve.append(skill)

	return reserve


func equip_reserve_skill_to_slot(reserve_index: int, slot_index: int) -> bool:
	var reserve: Array[SkillData] = get_reserve_skills()

	if reserve_index < 0 or reserve_index >= reserve.size():
		return false

	return equip_skill_to_slot(reserve[reserve_index], slot_index)


func equip_skill_to_slot(skill: SkillData, slot_index: int) -> bool:
	if skill == null or slot_index < 0 or slot_index >= MAX_ACTIVE_SKILLS:
		return false

	if not owned_skills.has(skill):
		add_owned_skill(skill)

	var equipped_index: int = equipped_skills.find(skill)
	if equipped_index >= 0 and equipped_index != slot_index:
		equipped_skills[equipped_index] = null

	equipped_skills[slot_index] = skill
	return true


func unequip_slot(slot_index: int) -> SkillData:
	if slot_index < 0 or slot_index >= MAX_ACTIVE_SKILLS:
		return null

	var skill: SkillData = equipped_skills[slot_index]
	equipped_skills[slot_index] = null
	return skill


func swap_slots(first_slot: int, second_slot: int) -> bool:
	if first_slot < 0 or first_slot >= MAX_ACTIVE_SKILLS:
		return false

	if second_slot < 0 or second_slot >= MAX_ACTIVE_SKILLS:
		return false

	var first_skill: SkillData = equipped_skills[first_slot]
	equipped_skills[first_slot] = equipped_skills[second_slot]
	equipped_skills[second_slot] = first_skill
	return true


func is_skill_equipped(skill: SkillData) -> bool:
	return skill != null and equipped_skills.has(skill)
