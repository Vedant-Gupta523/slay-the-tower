class_name BattleUnit
extends RefCounted

var data: UnitData
var current_hp: int
var is_defending: bool = false
var skills: Array[SkillInstance] = []
var skill_loadout: SkillLoadout
var equipment: Dictionary = {}
var reserve_inventory: Array[EquipmentData] = []

func _init(unit_data: UnitData) -> void:
	data = unit_data
	current_hp = data.max_hp
	skill_loadout = SkillLoadout.new(data.skills)
	_initialize_skills()

func _initialize_skills() -> void:
	skills.clear()

	for skill_data: SkillData in skill_loadout.get_active_skills():
		skills.append(skill_data.create_instance())

func reset_for_battle() -> void:
	current_hp = get_max_hp()
	is_defending = false
	_initialize_skills()

func get_unit_name() -> String:
	return data.unit_name

func get_max_hp() -> int:
	return max(1, data.max_hp + _get_equipment_stat_bonus("max_hp_bonus"))

func get_current_hp() -> int:
	return current_hp

func get_atk() -> int:
	return data.atk + _get_equipment_stat_bonus("atk_bonus")

func get_def() -> int:
	return data.def + _get_equipment_stat_bonus("def_bonus")

func get_spd() -> int:
	return data.spd + _get_equipment_stat_bonus("spd_bonus")

func get_skills() -> Array[SkillInstance]:
	return skills

func rebuild_skill_instances() -> void:
	_initialize_skills()

func get_skill_loadout() -> SkillLoadout:
	return skill_loadout

func equip_reserve_skill_to_slot(reserve_index: int, slot_index: int) -> bool:
	var equipped: bool = skill_loadout.equip_reserve_skill_to_slot(reserve_index, slot_index)

	if equipped:
		_initialize_skills()

	return equipped

func unequip_skill_slot(slot_index: int) -> SkillData:
	var skill: SkillData = skill_loadout.unequip_slot(slot_index)

	if skill != null:
		_initialize_skills()

	return skill

func is_dead() -> bool:
	return current_hp <= 0

func start_defending() -> void:
	is_defending = true

func stop_defending() -> void:
	is_defending = false

func take_damage(amount: int) -> int:
	var mitigated_damage: int = max(1, amount - get_def())

	if is_defending:
		mitigated_damage = max(1, int(mitigated_damage / 2))
		stop_defending()

	current_hp = max(0, current_hp - mitigated_damage)
	return mitigated_damage

func basic_attack(target: BattleUnit) -> int:
	return target.take_damage(get_atk())

func reduce_skill_cooldowns() -> void:
	for skill in skills:
		skill.reduce_cooldown()

func equip_item(item: EquipmentData) -> void:
	if item == null:
		return

	var old_item := get_equipped_item(item.slot_type)
	_remove_from_reserve(item)

	if old_item != null and old_item != item:
		add_to_reserve(old_item)

	equipment[item.slot_type] = item
	var new_max_hp := get_max_hp()
	current_hp = clamp(current_hp, 0, new_max_hp)

func add_to_reserve(item: EquipmentData) -> void:
	if item == null or reserve_inventory.has(item):
		return

	reserve_inventory.append(item)

func equip_reserve_item(reserve_index: int) -> EquipmentData:
	if reserve_index < 0 or reserve_index >= reserve_inventory.size():
		return null

	var item: EquipmentData = reserve_inventory[reserve_index]
	equip_item(item)
	return item

func equip_reserve_item_to_slot(reserve_index: int, slot_type: int) -> EquipmentData:
	if reserve_index < 0 or reserve_index >= reserve_inventory.size():
		return null

	var item: EquipmentData = reserve_inventory[reserve_index]
	if item == null or item.slot_type != slot_type:
		return null

	equip_item(item)
	return item

func unequip_slot(slot_type: int) -> EquipmentData:
	var item := get_equipped_item(slot_type)

	if item == null:
		return null

	equipment.erase(slot_type)
	add_to_reserve(item)
	var new_max_hp := get_max_hp()
	current_hp = clamp(current_hp, 0, new_max_hp)

	return item

func get_equipped_item(slot_type: int) -> EquipmentData:
	return equipment.get(slot_type, null) as EquipmentData

func get_equipped_items() -> Dictionary:
	return equipment.duplicate()

func get_reserve_inventory() -> Array[EquipmentData]:
	var copy: Array[EquipmentData] = []
	copy.assign(reserve_inventory)
	return copy

func _remove_from_reserve(item: EquipmentData) -> void:
	var index := reserve_inventory.find(item)

	if index >= 0:
		reserve_inventory.remove_at(index)

func _get_equipment_stat_bonus(property_name: String) -> int:
	var total := 0

	for item in equipment.values():
		if item == null:
			continue

		total += item.get_stat_bonus(property_name)

	return total
