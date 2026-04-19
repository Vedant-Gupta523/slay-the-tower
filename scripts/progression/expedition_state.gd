extends Node

const RESOURCE_MONSTER_MATERIALS := &"monster_materials"
const RESOURCE_ORES := &"ores"
const RESOURCE_HERBS := &"herbs"

var dungeon_index: int = 0
var max_dungeons: int = 10
var gold: int = 0
var monster_materials: int = 0
var ores: int = 0
var herbs: int = 0
var inventory: Array[EquipmentData] = []
var skill_books: Array[SkillData] = []
var equipped_gear: Dictionary = {}
var equipped_skills: Array[SkillData] = []
var is_active: bool = false
var is_failed: bool = false
var is_complete: bool = false


func start_or_continue(unit_data: UnitData = null) -> void:
	if is_active:
		return

	reset()
	is_active = true
	dungeon_index = 1
	initialize_from_unit_data(unit_data)


func reset() -> void:
	dungeon_index = 0
	gold = 0
	monster_materials = 0
	ores = 0
	herbs = 0
	inventory.clear()
	skill_books.clear()
	equipped_gear.clear()
	equipped_skills.clear()
	is_active = false
	is_failed = false
	is_complete = false


func complete_current_dungeon() -> bool:
	if not is_active:
		return false

	if dungeon_index >= max_dungeons:
		is_complete = true
		is_active = false
		return true

	dungeon_index += 1
	return false


func fail_expedition() -> void:
	is_failed = true
	is_active = false


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
			push_warning("Unknown expedition resource type: %s" % String(type))


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


func initialize_from_unit_data(unit_data: UnitData) -> void:
	if unit_data == null or not skill_books.is_empty() or not equipped_skills.is_empty():
		return

	for skill: SkillData in unit_data.skills:
		if skill != null and not skill_books.has(skill):
			skill_books.append(skill)

	equipped_skills.resize(SkillLoadout.MAX_ACTIVE_SKILLS)
	for index in range(min(SkillLoadout.MAX_ACTIVE_SKILLS, skill_books.size())):
		equipped_skills[index] = skill_books[index]


func capture_from_player_unit(player: BattleUnit) -> void:
	if player == null:
		return

	inventory.clear()
	inventory.assign(player.get_reserve_inventory())
	equipped_gear = player.get_equipped_items()

	var loadout: SkillLoadout = player.get_skill_loadout()
	skill_books.clear()
	skill_books.assign(loadout.owned_skills)
	equipped_skills.clear()
	equipped_skills.assign(loadout.get_equipped_skills())


func apply_to_player_unit(player: BattleUnit) -> void:
	if player == null:
		return

	player.reserve_inventory.clear()
	player.reserve_inventory.assign(inventory)
	player.equipment = equipped_gear.duplicate()

	var loadout: SkillLoadout = player.get_skill_loadout()
	loadout.owned_skills.clear()
	loadout.owned_skills.assign(skill_books)
	loadout.equipped_skills.clear()
	loadout.equipped_skills.assign(equipped_skills)
	loadout.equipped_skills.resize(SkillLoadout.MAX_ACTIVE_SKILLS)
	player.rebuild_skill_instances()
