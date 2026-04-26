extends Node

signal shop_inventory_changed
signal transaction_failed(message: String)
signal brewing_completed(result: Dictionary)

const MATERIAL_DIR := "res://data/materials"
const POTION_DIR := "res://data/potions"
const SHOP_MATERIAL_COUNT := 4
const SHOP_POTION_COUNT := 2

const BREWING_RECIPES := [
	{
		"ingredients": [&"empty_bottle", &"glowing_mushroom", &"slime_core"],
		"result": &"minor_healing_potion",
	},
	{
		"ingredients": [&"crimson_herb", &"crystal_bottle", &"haunted_bone"],
		"result": &"strong_healing_potion",
	},
	{
		"ingredients": [&"crimson_herb", &"empty_bottle", &"goblin_fang"],
		"result": &"rage_potion",
	},
	{
		"ingredients": [&"crystal_bottle", &"haunted_bone", &"moon_dust"],
		"result": &"stone_skin_potion",
	},
	{
		"ingredients": [&"empty_bottle", &"slime_core", &"strange_root"],
		"result": &"poisoned_brew",
	},
	{
		"ingredients": [&"beast_claw", &"crystal_bottle", &"moon_dust"],
		"result": &"wild_elixir",
	},
]

var current_shop_items: Array[ItemData] = []
var has_generated_inventory: bool = false

var _rng := RandomNumberGenerator.new()
var _material_pool: Array[MaterialData] = []
var _potion_pool: Array[PotionData] = []
var _potion_lookup: Dictionary = {}


func _ready() -> void:
	_rng.randomize()


func ensure_inventory() -> void:
	if not has_generated_inventory:
		_rotate_inventory()


func rotate_inventory() -> void:
	_rotate_inventory()


func buy_item(shop_index: int) -> bool:
	if shop_index < 0 or shop_index >= current_shop_items.size():
		emit_signal("transaction_failed", "That item is no longer available.")
		return false

	var item := current_shop_items[shop_index]
	if item == null:
		emit_signal("transaction_failed", "That item is no longer available.")
		return false

	if not ExpeditionState.spend_gold(item.get_purchase_price()):
		emit_signal("transaction_failed", "Not enough gold.")
		return false

	ExpeditionState.add_item(item)
	current_shop_items.remove_at(shop_index)
	emit_signal("shop_inventory_changed")
	return true


func sell_inventory_item(inventory_index: int) -> bool:
	if inventory_index < 0 or inventory_index >= ExpeditionState.item_inventory.size():
		emit_signal("transaction_failed", "That item is not in your satchel.")
		return false

	var item := ExpeditionState.item_inventory[inventory_index]
	if item == null:
		emit_signal("transaction_failed", "That item is not in your satchel.")
		return false

	ExpeditionState.remove_item_at(inventory_index)
	ExpeditionState.add_gold(item.get_sell_value())
	current_shop_items.append(item)
	emit_signal("shop_inventory_changed")
	return true


func can_afford(item: ItemData) -> bool:
	return item != null and ExpeditionState.gold >= item.get_purchase_price()


func get_owned_sell_items() -> Array[ItemData]:
	return ExpeditionState.get_item_inventory_snapshot()


func get_brewable_inventory_entries() -> Array[Dictionary]:
	return get_brewable_inventory_entries_for_type(&"")


func get_brewable_inventory_entries_for_type(material_type: StringName) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index in range(ExpeditionState.item_inventory.size()):
		var material := ExpeditionState.item_inventory[index] as MaterialData
		if is_valid_brewing_material(material) and (material_type == &"" or material.material_type == material_type):
			entries.append({
				"index": index,
				"item": material,
			})
	return entries


func is_valid_brewing_material(item: MaterialData) -> bool:
	if item == null:
		return false

	return item.material_type == MaterialData.TYPE_MYSTERIOUS_INGREDIENT or item.material_type == MaterialData.TYPE_BOTTLE or item.material_type == MaterialData.TYPE_MONSTER_MATERIAL


func preview_brew_result(materials: Array[MaterialData]) -> PotionData:
	if materials.size() != 3:
		return null
	if not _has_required_brew_types(materials):
		return null

	var recipe_potion := _get_recipe_result(materials)
	if recipe_potion != null:
		return recipe_potion

	return _get_fallback_potion(materials)


func brew_materials_by_indices(indices: Array[int]) -> Dictionary:
	if indices.size() != 3:
		var invalid_result := _build_brew_result("invalid_inputs", null, [], false)
		emit_signal("brewing_completed", invalid_result)
		return invalid_result

	var seen: Dictionary = {}
	var materials: Array[MaterialData] = []
	var snapshot := ExpeditionState.get_item_inventory_snapshot()
	for index in indices:
		if index < 0 or index >= snapshot.size() or seen.has(index):
			var bad_index_result := _build_brew_result("invalid_inputs", null, [], false)
			emit_signal("brewing_completed", bad_index_result)
			return bad_index_result
		seen[index] = true

		var material := snapshot[index] as MaterialData
		if not is_valid_brewing_material(material):
			var bad_material_result := _build_brew_result("invalid_inputs", null, [], false)
			emit_signal("brewing_completed", bad_material_result)
			return bad_material_result
		materials.append(material)

	if not _has_required_brew_types(materials):
		var bad_mix_result := _build_brew_result("invalid_inputs", null, [], false)
		emit_signal("brewing_completed", bad_mix_result)
		return bad_mix_result

	var potion := preview_brew_result(materials)
	if potion == null:
		var failed_result := _build_brew_result("failed", null, materials, false)
		emit_signal("brewing_completed", failed_result)
		return failed_result

	var sorted_indices := indices.duplicate()
	sorted_indices.sort()
	sorted_indices.reverse()
	for index in sorted_indices:
		ExpeditionState.remove_item_at(index)

	ExpeditionState.add_potion_item(potion)
	var result := _build_brew_result("success", potion, materials, _get_recipe_result(materials) != null)
	emit_signal("brewing_completed", result)
	return result


func _rotate_inventory() -> void:
	current_shop_items.clear()
	current_shop_items.append_array(_generate_material_stock(SHOP_MATERIAL_COUNT))
	current_shop_items.append_array(_generate_potion_stock(SHOP_POTION_COUNT))
	has_generated_inventory = true
	emit_signal("shop_inventory_changed")


func _generate_material_stock(count: int) -> Array[ItemData]:
	var stock: Array[ItemData] = []
	var pool := _get_material_pool()
	if pool.is_empty():
		return stock

	_append_material_type_stock(stock, pool, MaterialData.TYPE_MYSTERIOUS_INGREDIENT)
	_append_material_type_stock(stock, pool, MaterialData.TYPE_BOTTLE)
	_append_material_type_stock(stock, pool, MaterialData.TYPE_MONSTER_MATERIAL)
	while stock.size() < count:
		var rarity := EquipmentData.roll_rarity(_rng)
		stock.append(_pick_item_by_rarity(pool, rarity))
	return stock


func _append_material_type_stock(stock: Array[ItemData], pool: Array[MaterialData], material_type: StringName) -> void:
	var candidates: Array[MaterialData] = []
	for material in pool:
		if material != null and material.material_type == material_type:
			candidates.append(material)
	if candidates.is_empty():
		return
	stock.append(candidates[_rng.randi_range(0, candidates.size() - 1)])


func _generate_potion_stock(count: int) -> Array[ItemData]:
	var stock: Array[ItemData] = []
	var pool := _get_potion_pool()
	if pool.is_empty():
		return stock

	for _i in range(count):
		var rarity := EquipmentData.roll_rarity(_rng)
		stock.append(_pick_item_by_rarity(pool, rarity))
	return stock


func _pick_item_by_rarity(pool: Array, rarity: int) -> ItemData:
	var matches: Array[ItemData] = []
	var fallback: Array[ItemData] = []
	for item in pool:
		if item == null:
			continue
		fallback.append(item)
		if item.rarity == rarity:
			matches.append(item)

	var candidates := matches if not matches.is_empty() else fallback
	return candidates[_rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else null


func _get_recipe_result(materials: Array[MaterialData]) -> PotionData:
	var ingredient_ids := _get_sorted_ingredient_ids(materials)
	for recipe in BREWING_RECIPES:
		var recipe_ids: Array = recipe["ingredients"]
		if _string_array_matches(ingredient_ids, _sorted_string_name_array(recipe_ids)):
			return _get_potion_by_id(recipe["result"])
	return null


func _get_fallback_potion(materials: Array[MaterialData]) -> PotionData:
	var pool := _get_potion_pool()
	if pool.is_empty():
		return null

	var rarity_total := 0
	var max_rarity := EquipmentData.Rarity.COMMON
	for material in materials:
		if material == null:
			continue
		rarity_total += material.rarity
		max_rarity = max(max_rarity, int(material.rarity))

	var target_rarity := int(round(float(rarity_total) / max(1.0, float(materials.size()))))
	target_rarity = clamp(target_rarity, EquipmentData.Rarity.COMMON, max_rarity)

	var exact_matches: Array[PotionData] = []
	var lower_matches: Array[PotionData] = []
	var higher_matches: Array[PotionData] = []
	for potion in pool:
		if potion == null:
			continue
		if potion.rarity == target_rarity:
			exact_matches.append(potion)
		elif potion.rarity < target_rarity:
			lower_matches.append(potion)
		else:
			higher_matches.append(potion)

	if not exact_matches.is_empty():
		return exact_matches[_rng.randi_range(0, exact_matches.size() - 1)]
	if not lower_matches.is_empty():
		return lower_matches[_rng.randi_range(0, lower_matches.size() - 1)]
	if not higher_matches.is_empty():
		return higher_matches[_rng.randi_range(0, higher_matches.size() - 1)]
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _build_brew_result(status: String, potion: PotionData, consumed: Array[MaterialData], matched_recipe: bool) -> Dictionary:
	return {
		"status": status,
		"success": status == "success",
		"potion": potion,
		"consumed_materials": consumed,
		"matched_recipe": matched_recipe,
	}


func _has_required_brew_types(materials: Array[MaterialData]) -> bool:
	var has_mysterious := false
	var has_bottle := false
	var has_monster := false
	for material in materials:
		if material == null:
			continue
		match material.material_type:
			MaterialData.TYPE_MYSTERIOUS_INGREDIENT:
				has_mysterious = true
			MaterialData.TYPE_BOTTLE:
				has_bottle = true
			MaterialData.TYPE_MONSTER_MATERIAL:
				has_monster = true
	return has_mysterious and has_bottle and has_monster


func _get_sorted_ingredient_ids(materials: Array[MaterialData]) -> Array[String]:
	var ids: Array[String] = []
	for material in materials:
		if material != null:
			ids.append(String(material.item_id))
	ids.sort()
	return ids


func _sorted_string_name_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	result.sort()
	return result


func _string_array_matches(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if left[index] != right[index]:
			return false
	return true


func _get_potion_by_id(item_id: StringName) -> PotionData:
	if _potion_lookup.is_empty():
		_get_potion_pool()
	return _potion_lookup.get(item_id, null) as PotionData


func _get_material_pool() -> Array[MaterialData]:
	if not _material_pool.is_empty():
		return _material_pool
	for resource in _load_resources_from_dir(MATERIAL_DIR):
		var material := resource as MaterialData
		if material != null:
			_material_pool.append(material)
	return _material_pool


func _get_potion_pool() -> Array[PotionData]:
	if not _potion_pool.is_empty():
		return _potion_pool
	for resource in _load_resources_from_dir(POTION_DIR):
		var potion := resource as PotionData
		if potion != null:
			_potion_pool.append(potion)
	_potion_lookup.clear()
	for potion in _potion_pool:
		if potion != null:
			_potion_lookup[potion.item_id] = potion
	return _potion_pool


func _load_resources_from_dir(dir_path: String) -> Array:
	var resources: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Missing witch data directory: %s" % dir_path)
		return resources

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path := "%s/%s" % [dir_path, file_name]
			var resource := load(resource_path)
			if resource != null:
				resources.append(resource)
		file_name = dir.get_next()
	dir.list_dir_end()
	return resources
