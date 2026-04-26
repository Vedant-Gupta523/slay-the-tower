extends Node

signal resources_changed
signal expedition_state_changed

const RESOURCE_MONSTER_MATERIALS := &"monster_materials"
const RESOURCE_ORES := &"ores"
const RESOURCE_HERBS := &"herbs"
const TEST_STARTING_GOLD := 2000
const TEST_STARTING_ORES := 250

var dungeon_index: int = 0
var max_dungeons: int = 10
var gold: int = TEST_STARTING_GOLD
var monster_materials: int = 0
var ores: int = TEST_STARTING_ORES
var herbs: int = 0
var inventory: Array[EquipmentData] = []
var item_inventory: Array[ItemData] = []
var skill_books: Array[SkillData] = []
var equipped_gear: Dictionary = {}
var equipped_skills: Array[SkillData] = []
var is_active: bool = false
var is_failed: bool = false
var is_complete: bool = false
var blacksmith_refresh_counter: int = 0


func start_or_continue(unit_data: UnitData = null) -> void:
	if is_active:
		return

	_prepare_for_new_expedition()
	is_active = true
	dungeon_index = 1
	initialize_from_unit_data(unit_data)
	emit_signal("expedition_state_changed")
	emit_signal("resources_changed")


func reset() -> void:
	dungeon_index = 0
	gold = TEST_STARTING_GOLD
	monster_materials = 0
	ores = TEST_STARTING_ORES
	herbs = 0
	inventory.clear()
	item_inventory.clear()
	skill_books.clear()
	equipped_gear.clear()
	equipped_skills.clear()
	is_active = false
	is_failed = false
	is_complete = false
	blacksmith_refresh_counter = 0
	emit_signal("expedition_state_changed")
	emit_signal("resources_changed")


func _prepare_for_new_expedition() -> void:
	is_active = false
	is_failed = false
	is_complete = false
	dungeon_index = 0


func complete_current_dungeon() -> bool:
	if not is_active:
		return false

	if dungeon_index >= max_dungeons:
		is_complete = true
		is_active = false
		emit_signal("expedition_state_changed")
		return true

	dungeon_index += 1
	emit_signal("expedition_state_changed")
	return false


func fail_expedition() -> void:
	is_failed = true
	is_active = false
	emit_signal("expedition_state_changed")


func add_gold(amount: int) -> void:
	gold = max(0, gold + amount)
	emit_signal("resources_changed")


func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true

	if gold < amount:
		return false

	gold -= amount
	emit_signal("resources_changed")
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
	emit_signal("resources_changed")


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

	emit_signal("resources_changed")
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


func add_equipment_item(item: EquipmentData) -> void:
	if item == null:
		return

	var owned_item := EquipmentInstance.from_equipment_data(item)
	if owned_item == null or inventory.has(owned_item) or is_item_equipped(owned_item):
		return

	inventory.append(owned_item)
	emit_signal("expedition_state_changed")


func add_item(item: ItemData) -> void:
	if item == null:
		return

	item_inventory.append(item)
	emit_signal("expedition_state_changed")


func add_material_item(item: MaterialData) -> void:
	add_item(item)


func add_potion_item(item: PotionData) -> void:
	add_item(item)


func remove_item(item: ItemData) -> bool:
	if item == null:
		return false

	var index := item_inventory.find(item)
	if index < 0:
		return false

	item_inventory.remove_at(index)
	emit_signal("expedition_state_changed")
	return true


func remove_item_at(index: int) -> ItemData:
	if index < 0 or index >= item_inventory.size():
		return null

	var item := item_inventory[index]
	item_inventory.remove_at(index)
	emit_signal("expedition_state_changed")
	return item


func remove_material_item(item: MaterialData) -> bool:
	return remove_item(item)


func remove_potion_item(item: PotionData) -> bool:
	return remove_item(item)


func get_items_by_type(item_script) -> Array[ItemData]:
	var results: Array[ItemData] = []
	for item in item_inventory:
		if item != null and item_script != null and is_instance_of(item, item_script):
			results.append(item)
	return results


func get_material_items() -> Array[MaterialData]:
	var materials: Array[MaterialData] = []
	for item in item_inventory:
		var material := item as MaterialData
		if material != null:
			materials.append(material)
	return materials


func get_potion_items() -> Array[PotionData]:
	var potions: Array[PotionData] = []
	for item in item_inventory:
		var potion := item as PotionData
		if potion != null:
			potions.append(potion)
	return potions


func get_items_matching_tag(tag: StringName) -> Array[ItemData]:
	var results: Array[ItemData] = []
	for item in item_inventory:
		if item != null and item.has_tag(tag):
			results.append(item)
	return results


func get_materials_by_type(material_type: StringName) -> Array[MaterialData]:
	var materials: Array[MaterialData] = []
	for item in item_inventory:
		var material := item as MaterialData
		if material != null and material.material_type == material_type:
			materials.append(material)
	return materials


func get_material_count(material_id: StringName = &"", material_type: StringName = &"") -> int:
	var count := 0
	for item in item_inventory:
		var material := item as MaterialData
		if material == null:
			continue
		if material_id != &"" and material.item_id != material_id:
			continue
		if material_type != &"" and material.material_type != material_type:
			continue
		count += 1
	return count


func get_potion_count(potion_id: StringName = &"") -> int:
	var count := 0
	for item in item_inventory:
		var potion := item as PotionData
		if potion == null:
			continue
		if potion_id != &"" and potion.item_id != potion_id:
			continue
		count += 1
	return count


func has_item(item_id: StringName) -> bool:
	for item in item_inventory:
		if item != null and item.item_id == item_id:
			return true
	return false


func get_item_inventory_snapshot() -> Array[ItemData]:
	var items: Array[ItemData] = []
	items.assign(item_inventory)
	return items


func remove_equipment_item(item: EquipmentData) -> bool:
	if item == null:
		return false

	var reserve_index := inventory.find(item)
	if reserve_index >= 0:
		inventory.remove_at(reserve_index)
		emit_signal("expedition_state_changed")
		return true

	for slot_type in equipped_gear.keys():
		if equipped_gear[slot_type] == item:
			equipped_gear.erase(slot_type)
			emit_signal("expedition_state_changed")
			return true

	return false


func equip_inventory_item(inventory_index: int, slot_type: int) -> bool:
	if inventory_index < 0 or inventory_index >= inventory.size():
		return false

	var item: EquipmentData = inventory[inventory_index]
	if item == null or item.slot_type != slot_type:
		return false

	inventory.remove_at(inventory_index)
	var old_item: EquipmentData = equipped_gear.get(slot_type, null) as EquipmentData
	if old_item != null and old_item != item and not inventory.has(old_item):
		inventory.append(old_item)

	equipped_gear[slot_type] = item
	_remove_duplicate_inventory_references()
	emit_signal("expedition_state_changed")
	return true


func unequip_gear_slot(slot_type: int) -> bool:
	var item: EquipmentData = equipped_gear.get(slot_type, null) as EquipmentData
	if item == null:
		return false

	equipped_gear.erase(slot_type)
	if not inventory.has(item):
		inventory.append(item)
	_remove_duplicate_inventory_references()
	emit_signal("expedition_state_changed")
	return true


func increment_blacksmith_refresh_counter() -> void:
	blacksmith_refresh_counter += 1
	emit_signal("expedition_state_changed")


func get_reserve_equipment() -> Array[EquipmentData]:
	var items: Array[EquipmentData] = []
	items.assign(inventory)
	return items


func get_all_owned_equipment() -> Array[EquipmentData]:
	var items := get_reserve_equipment()
	for item in equipped_gear.values():
		var equipment_item := item as EquipmentData
		if equipment_item != null and not items.has(equipment_item):
			items.append(equipment_item)
	return items


func is_item_equipped(item: EquipmentData) -> bool:
	if item == null:
		return false

	for equipped_item in equipped_gear.values():
		if equipped_item == item:
			return true

	return false


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
	for item in player.get_reserve_inventory():
		inventory.append(EquipmentInstance.from_equipment_data(item))

	equipped_gear.clear()
	for slot_type in player.get_equipped_items().keys():
		var item := player.get_equipped_items()[slot_type] as EquipmentData
		equipped_gear[slot_type] = EquipmentInstance.from_equipment_data(item)

	var loadout: SkillLoadout = player.get_skill_loadout()
	skill_books.clear()
	skill_books.assign(loadout.owned_skills)
	equipped_skills.clear()
	equipped_skills.assign(loadout.get_equipped_skills())
	_remove_duplicate_inventory_references()
	emit_signal("resources_changed")
	emit_signal("expedition_state_changed")


func apply_to_player_unit(player: BattleUnit) -> void:
	if player == null:
		return

	player.reserve_inventory.clear()
	for item in inventory:
		player.reserve_inventory.append(EquipmentInstance.from_equipment_data(item))

	player.equipment.clear()
	for slot_type in equipped_gear.keys():
		var item := equipped_gear[slot_type] as EquipmentData
		player.equipment[slot_type] = EquipmentInstance.from_equipment_data(item)

	var loadout: SkillLoadout = player.get_skill_loadout()
	loadout.owned_skills.clear()
	loadout.owned_skills.assign(skill_books)
	loadout.equipped_skills.clear()
	loadout.equipped_skills.assign(equipped_skills)
	loadout.equipped_skills.resize(SkillLoadout.MAX_ACTIVE_SKILLS)
	player.rebuild_skill_instances()


func _remove_duplicate_inventory_references() -> void:
	var seen: Dictionary = {}
	for index in range(inventory.size() - 1, -1, -1):
		var item := inventory[index]
		if item == null or seen.has(item) or is_item_equipped(item):
			inventory.remove_at(index)
			continue
		seen[item] = true
