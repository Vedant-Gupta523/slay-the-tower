extends Node

signal shop_inventory_changed
signal transaction_failed(message: String)
signal enhancement_resolved(result: Dictionary)

const EQUIPMENT_DIR := "res://data/equipment"
const SHOP_ITEM_COUNT := 5
const ENHANCE_MAX_LEVEL := EquipmentInstance.MAX_ENHANCEMENT_LEVEL

var current_shop_items: Array[EquipmentData] = []
var last_refresh_counter: int = -1
var has_generated_inventory: bool = false

var _rng := RandomNumberGenerator.new()
var _equipment_pool: Array[EquipmentData] = []


func _ready() -> void:
	_rng.randomize()


func ensure_inventory(refresh_counter: int = 0) -> void:
	if not has_generated_inventory:
		refresh_for_counter(refresh_counter)


func refresh_for_counter(refresh_counter: int) -> void:
	if last_refresh_counter == refresh_counter and not current_shop_items.is_empty():
		return

	last_refresh_counter = refresh_counter
	_rotate_inventory()


func rotate_inventory(refresh_counter: int = -1) -> void:
	if refresh_counter >= 0:
		last_refresh_counter = refresh_counter
	else:
		last_refresh_counter += 1

	_rotate_inventory()


func _rotate_inventory() -> void:
	current_shop_items = _generate_shop_inventory()
	has_generated_inventory = true
	emit_signal("shop_inventory_changed")


func buy_item(shop_index: int) -> bool:
	if shop_index < 0 or shop_index >= current_shop_items.size():
		emit_signal("transaction_failed", "That item is no longer available.")
		return false

	var item := current_shop_items[shop_index]
	if item == null:
		emit_signal("transaction_failed", "That item is no longer available.")
		return false

	var price: int = item.get_purchase_price()
	if not ExpeditionState.spend_gold(price):
		emit_signal("transaction_failed", "Not enough gold.")
		return false

	ExpeditionState.add_equipment_item(EquipmentInstance.from_equipment_data(item))
	current_shop_items.remove_at(shop_index)
	emit_signal("shop_inventory_changed")
	return true


func sell_inventory_item(inventory_index: int) -> bool:
	if inventory_index < 0 or inventory_index >= ExpeditionState.inventory.size():
		emit_signal("transaction_failed", "That item is not in reserve.")
		return false

	var item := ExpeditionState.inventory[inventory_index]
	if item == null:
		emit_signal("transaction_failed", "That item is not in reserve.")
		return false

	ExpeditionState.inventory.remove_at(inventory_index)
	ExpeditionState.add_gold(item.get_sell_value())
	ExpeditionState.emit_signal("expedition_state_changed")
	emit_signal("shop_inventory_changed")
	return true


func get_enhance_cost(item: EquipmentData) -> int:
	var level := _get_enhancement_level(item)
	return 1 + int(level / 5)


func can_enhance(item: EquipmentData) -> bool:
	var instance := EquipmentInstance.from_equipment_data(item)
	if instance == null:
		return false

	return instance.enhancement_level < ENHANCE_MAX_LEVEL and ExpeditionState.ores >= get_enhance_cost(instance)


func enhance_item(item: EquipmentData) -> Dictionary:
	var instance := EquipmentInstance.from_equipment_data(item)
	if instance == null:
		return _build_enhance_result("invalid_item", item, 0, 0, {}, 0, false)

	var level_before := instance.enhancement_level
	if level_before >= ENHANCE_MAX_LEVEL:
		var maxed_result := _build_enhance_result("maxed", instance, level_before, level_before, {}, 0, false)
		emit_signal("enhancement_resolved", maxed_result)
		return maxed_result

	var ore_cost := get_enhance_cost(instance)
	if not ExpeditionState.spend_resource(ExpeditionState.RESOURCE_ORES, ore_cost):
		var insufficient_result := _build_enhance_result("insufficient_ores", instance, level_before, level_before, {}, 0, false)
		emit_signal("enhancement_resolved", insufficient_result)
		return insufficient_result

	if _roll_break(level_before):
		ExpeditionState.remove_equipment_item(instance)
		var broke_result := _build_enhance_result("broke", instance, level_before, level_before, {}, ore_cost, true)
		emit_signal("enhancement_resolved", broke_result)
		return broke_result

	var stat_changes := _roll_enhancement_stat_changes(instance)
	for stat_key in stat_changes.keys():
		instance.add_enhancement_stat(StringName(stat_key), int(stat_changes[stat_key]))

	instance.add_enhancement_levels(1)
	ExpeditionState.emit_signal("expedition_state_changed")
	var success_result := _build_enhance_result("success", instance, level_before, instance.enhancement_level, stat_changes, ore_cost, false)
	var quality: Dictionary = _get_enhancement_quality(stat_changes)
	success_result["enhancement_quality"] = quality["name"]
	success_result["enhancement_quality_color"] = quality["color"]
	emit_signal("enhancement_resolved", success_result)
	return success_result


func can_afford(item: EquipmentData) -> bool:
	return item != null and ExpeditionState.gold >= item.get_purchase_price()


func get_owned_sell_items() -> Array[EquipmentData]:
	var items: Array[EquipmentData] = []
	items.assign(ExpeditionState.inventory)
	return items


func get_enhance_items() -> Array[EquipmentData]:
	var items: Array[EquipmentData] = []
	items.assign(ExpeditionState.inventory)

	for item in ExpeditionState.equipped_gear.values():
		if item != null:
			items.append(item)

	return items


func _get_enhancement_level(item: EquipmentData) -> int:
	if item is EquipmentInstance:
		return (item as EquipmentInstance).enhancement_level

	return 0


func _roll_break(level: int) -> bool:
	var chance: float = clamp((float(level) - 8.0) * 0.006, 0.0, 0.38)
	return _rng.randf() < chance


func _roll_enhancement_stat_changes(item: EquipmentData) -> Dictionary:
	var stat_key: StringName = _pick_stat_key_for_item(item)
	var boost_size: int = _roll_boost_size()
	var applied_amount: int = boost_size * 3 if stat_key == &"max_hp" else boost_size
	return {stat_key: applied_amount}


func _pick_stat_key_for_item(item: EquipmentData) -> StringName:
	var candidates: Array[StringName] = []
	if item.max_hp_bonus != 0:
		candidates.append(&"max_hp")
	if item.atk_bonus != 0:
		candidates.append(&"atk")
	if item.def_bonus != 0:
		candidates.append(&"def")
	if item.spd_bonus != 0:
		candidates.append(&"spd")

	if candidates.is_empty():
		candidates = [&"max_hp", &"atk", &"def", &"spd"]

	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _roll_boost_size() -> int:
	var roll := _rng.randf()
	if roll < 0.72:
		return 1
	if roll < 0.94:
		return 2
	return 3


func _get_enhancement_quality(stat_changes: Dictionary) -> Dictionary:
	var boost_size: int = 1
	for stat_key in stat_changes.keys():
		var amount: int = int(stat_changes[stat_key])
		boost_size = int(round(float(amount) / 3.0)) if StringName(stat_key) == &"max_hp" else amount
		break

	if boost_size >= 3:
		return {"name": "Exceptional", "color": "#d2a8ff"}
	if boost_size == 2:
		return {"name": "Great", "color": "#79c0ff"}

	return {"name": "Solid", "color": "#7ee787"}


func _build_enhance_result(
	status: String,
	item: EquipmentData,
	level_before: int,
	level_after: int,
	stat_changes: Dictionary,
	ore_spent: int,
	broke: bool
) -> Dictionary:
	return {
		"status": status,
		"item": item,
		"success": status == "success",
		"broke": broke,
		"level_before": level_before,
		"level_after": level_after,
		"stat_changes": stat_changes,
		"ore_spent": ore_spent,
	}


func _generate_shop_inventory() -> Array[EquipmentData]:
	var pool := _get_equipment_pool()
	var stock: Array[EquipmentData] = []
	var used: Array[EquipmentData] = []

	if pool.is_empty():
		return stock

	while stock.size() < SHOP_ITEM_COUNT and used.size() < pool.size():
		var rolled_rarity: int = EquipmentData.roll_rarity(_rng)
		var item := _pick_item(pool, rolled_rarity, used)
		if item == null:
			break

		stock.append(item)
		used.append(item)

	return stock


func _pick_item(pool: Array[EquipmentData], rarity: int, used: Array[EquipmentData]) -> EquipmentData:
	var candidates: Array[EquipmentData] = []

	for item in pool:
		if item == null or used.has(item):
			continue
		if item.rarity == rarity:
			candidates.append(item)

	if candidates.is_empty():
		for item in pool:
			if item != null and not used.has(item):
				candidates.append(item)

	if candidates.is_empty():
		return null

	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _get_equipment_pool() -> Array[EquipmentData]:
	if not _equipment_pool.is_empty():
		return _equipment_pool

	var dir := DirAccess.open(EQUIPMENT_DIR)
	if dir == null:
		push_warning("Missing blacksmith equipment directory: %s" % EQUIPMENT_DIR)
		return _equipment_pool

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var item := load("%s/%s" % [EQUIPMENT_DIR, file_name]) as EquipmentData
			if item != null:
				_equipment_pool.append(item)

		file_name = dir.get_next()

	dir.list_dir_end()
	return _equipment_pool
