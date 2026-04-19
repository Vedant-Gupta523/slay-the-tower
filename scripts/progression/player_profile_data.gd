class_name PlayerProfileData
extends Resource

const RESOURCE_MONSTER_MATERIALS := &"monster_materials"
const RESOURCE_ORES := &"ores"
const RESOURCE_HERBS := &"herbs"

@export var gold: int = 2000
@export var monster_materials: int = 0
@export var ores: int = 250
@export var herbs: int = 0
@export var owned_gear_inventory: Array[EquipmentData] = []
@export var owned_skill_books: Array[SkillData] = []
@export var equipped_gear: Dictionary = {}
@export var equipped_skills: Array[SkillData] = []
@export var current_streak: int = 0


func add_gold(amount: int) -> void:
	gold = max(0, gold + amount)


func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true

	if gold < amount:
		return false

	gold -= amount
	return true


func add_resource(type: StringName, amount: int) -> void:
	if amount <= 0:
		return

	match type:
		RESOURCE_MONSTER_MATERIALS:
			monster_materials += amount
		RESOURCE_ORES:
			ores += amount
		RESOURCE_HERBS:
			herbs += amount
		_:
			push_warning("Unknown profile resource type: %s" % String(type))


func spend_resource(type: StringName, amount: int) -> bool:
	if amount <= 0:
		return true

	var current_amount: int = get_resource_amount(type)
	if current_amount < amount:
		return false

	match type:
		RESOURCE_MONSTER_MATERIALS:
			monster_materials -= amount
		RESOURCE_ORES:
			ores -= amount
		RESOURCE_HERBS:
			herbs -= amount
		_:
			return false

	return true


func get_resource_amount(type: StringName) -> int:
	match type:
		RESOURCE_MONSTER_MATERIALS:
			return monster_materials
		RESOURCE_ORES:
			return ores
		RESOURCE_HERBS:
			return herbs
		_:
			return 0


func increment_streak() -> void:
	current_streak += 1


func reset_streak() -> void:
	current_streak = 0


func initialize_from_unit_data(unit_data: UnitData) -> void:
	if unit_data == null or not owned_skill_books.is_empty() or not equipped_skills.is_empty():
		return

	for skill: SkillData in unit_data.skills:
		if skill != null and not owned_skill_books.has(skill):
			owned_skill_books.append(skill)

	equipped_skills.resize(SkillLoadout.MAX_ACTIVE_SKILLS)
	for index in range(min(SkillLoadout.MAX_ACTIVE_SKILLS, owned_skill_books.size())):
		equipped_skills[index] = owned_skill_books[index]


func capture_from_player_unit(player: BattleUnit) -> void:
	if player == null:
		return

	owned_gear_inventory.clear()
	for item in player.get_reserve_inventory():
		owned_gear_inventory.append(EquipmentInstance.from_equipment_data(item))

	equipped_gear.clear()
	for slot_type in player.get_equipped_items().keys():
		var item := player.get_equipped_items()[slot_type] as EquipmentData
		equipped_gear[slot_type] = EquipmentInstance.from_equipment_data(item)

	var loadout: SkillLoadout = player.get_skill_loadout()
	owned_skill_books.clear()
	owned_skill_books.assign(loadout.owned_skills)
	equipped_skills.clear()
	equipped_skills.assign(loadout.get_equipped_skills())


func apply_to_player_unit(player: BattleUnit) -> void:
	if player == null:
		return

	player.reserve_inventory.clear()
	for item in owned_gear_inventory:
		player.reserve_inventory.append(EquipmentInstance.from_equipment_data(item))

	player.equipment.clear()
	for slot_type in equipped_gear.keys():
		var item := equipped_gear[slot_type] as EquipmentData
		player.equipment[slot_type] = EquipmentInstance.from_equipment_data(item)

	var loadout: SkillLoadout = player.get_skill_loadout()
	loadout.owned_skills.clear()
	loadout.owned_skills.assign(owned_skill_books)
	loadout.equipped_skills.clear()
	loadout.equipped_skills.assign(equipped_skills)
	loadout.equipped_skills.resize(SkillLoadout.MAX_ACTIVE_SKILLS)
	player.rebuild_skill_instances()
