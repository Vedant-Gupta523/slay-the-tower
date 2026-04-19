extends Node
class_name GameRunFlow

@export var world_map_scene: PackedScene = preload("res://scenes/map/WorldMap.tscn")
@export var battle_scene: PackedScene = preload("res://scenes/battle/battle_scene.tscn")
@export var main_base_scene: PackedScene = preload("res://scenes/base/MainBase.tscn")
@export var initial_seed: int = 0
@export var player_unit_data: UnitData
@export var combat_enemy_data: UnitData
@export var elite_enemy_data: UnitData
@export var boss_enemy_data: UnitData
@export var player_profile: PlayerProfileData

@onready var map_run_state: MapRunState = $MapRunState
@onready var current_scene_root: Node = $CurrentSceneRoot
@onready var inventory_button: Button = %InventoryButton
@onready var skills_button: Button = %SkillsButton
@onready var equipment_screen: EquipmentScreen = %EquipmentScreen
@onready var skill_loadout_screen: SkillLoadoutScreen = %SkillLoadoutScreen

var _world_map_controller: WorldMapController
var _battle_controller: BattleController
var _main_base_controller: MainBaseController
var _player_unit: PlayerUnit
var _active_battle_node_type: StringName = &""


func _ready() -> void:
	_ensure_expedition_state()
	_ensure_player_unit()
	inventory_button.pressed.connect(_on_inventory_button_pressed)
	skills_button.pressed.connect(_on_skills_button_pressed)
	equipment_screen.equip_reserve_requested.connect(_on_equipment_screen_equip_reserve_requested)
	equipment_screen.unequip_slot_requested.connect(_on_equipment_screen_unequip_slot_requested)
	skill_loadout_screen.equip_reserve_requested.connect(_on_skill_screen_equip_reserve_requested)
	skill_loadout_screen.unequip_slot_requested.connect(_on_skill_screen_unequip_slot_requested)
	_open_main_base()


func _open_main_base() -> void:
	var main_base := main_base_scene.instantiate() as MainBaseController
	main_base.set_expedition_state(ExpeditionState)
	_switch_to_instance(main_base)
	_main_base_controller = main_base
	_world_map_controller = null
	_battle_controller = null
	_active_battle_node_type = &""
	_set_inventory_button_visible(false)
	_set_skills_button_visible(false)
	equipment_screen.hide()
	skill_loadout_screen.hide()
	main_base.start_dungeon_requested.connect(_on_main_base_start_dungeon_requested)


func _open_world_map(create_run_if_missing: bool = false) -> void:
	var world_map := world_map_scene.instantiate() as WorldMapController
	world_map.auto_generate_if_missing = false
	world_map.set_run_state(map_run_state)
	_switch_to_instance(world_map)
	_main_base_controller = null
	_world_map_controller = world_map
	_battle_controller = null
	_active_battle_node_type = &""
	_set_inventory_button_visible(true)
	_set_skills_button_visible(true)
	world_map.node_selected.connect(_on_world_map_node_selected)

	if create_run_if_missing and not map_run_state.has_active_run():
		world_map.start_new_run(_get_current_dungeon_seed())
	else:
		world_map.refresh()


func _open_battle_for_node(node_data: MapNodeData) -> void:
	var battle_root := battle_scene.instantiate()
	var battle_controller := battle_root.get_node_or_null("BattleController") as BattleController

	if battle_controller == null:
		push_error("Battle scene is missing a BattleController child.")
		if _world_map_controller != null:
			_world_map_controller.refresh()
		return

	_ensure_player_unit()
	if _player_unit != null:
		_player_unit.reset_for_battle()
		battle_controller.set_player_unit(_player_unit)
	elif player_unit_data != null:
		battle_controller.player_data = player_unit_data

	var enemy_data: UnitData = _get_enemy_data_for_node(node_data)
	if enemy_data != null:
		battle_controller.enemy_data = enemy_data

	_switch_to_instance(battle_root)

	_world_map_controller = null
	_battle_controller = battle_controller
	_main_base_controller = null
	_active_battle_node_type = node_data.node_type
	_set_inventory_button_visible(false)
	_set_skills_button_visible(false)

	_battle_controller.battle_won.connect(_on_battle_won)
	_battle_controller.battle_lost.connect(_on_battle_lost)
	_battle_controller.battle_exited.connect(_on_battle_exited)


func _switch_to_instance(instance: Node) -> void:
	for child in current_scene_root.get_children():
		child.queue_free()

	current_scene_root.add_child(instance)


func _on_main_base_start_dungeon_requested() -> void:
	_start_or_continue_expedition_dungeon()


func _start_or_continue_expedition_dungeon() -> void:
	_ensure_player_unit()
	ExpeditionState.start_or_continue(player_unit_data)
	if _player_unit != null:
		ExpeditionState.apply_to_player_unit(_player_unit)

	map_run_state.clear_run()
	_open_world_map(true)


func _ensure_player_unit() -> void:
	if _player_unit != null or player_unit_data == null:
		return

	_player_unit = PlayerUnit.new(player_unit_data)
	if ExpeditionState.is_active:
		ExpeditionState.apply_to_player_unit(_player_unit)


func _ensure_player_profile() -> void:
	if player_profile == null:
		player_profile = PlayerProfileData.new()

	player_profile.initialize_from_unit_data(player_unit_data)


func _ensure_expedition_state() -> void:
	ExpeditionState.initialize_from_unit_data(player_unit_data)


func get_player_profile() -> PlayerProfileData:
	_ensure_player_profile()
	return player_profile


func _sync_profile_from_player() -> void:
	if _player_unit == null:
		return

	ExpeditionState.capture_from_player_unit(_player_unit)
	if player_profile != null:
		player_profile.capture_from_player_unit(_player_unit)


func _set_inventory_button_visible(is_visible: bool) -> void:
	if inventory_button != null:
		inventory_button.visible = is_visible


func _set_skills_button_visible(is_visible: bool) -> void:
	if skills_button != null:
		skills_button.visible = is_visible


func _on_inventory_button_pressed() -> void:
	_ensure_player_unit()
	if _player_unit == null:
		return

	skill_loadout_screen.hide()
	equipment_screen.show_for_player(_player_unit)


func _on_skills_button_pressed() -> void:
	_ensure_player_unit()
	if _player_unit == null:
		return

	equipment_screen.hide()
	skill_loadout_screen.show_for_loadout(_player_unit.get_skill_loadout())


func _on_equipment_screen_equip_reserve_requested(reserve_index: int, slot_type: int) -> void:
	if _player_unit == null:
		return

	_player_unit.equip_reserve_item_to_slot(reserve_index, slot_type)
	_sync_profile_from_player()
	equipment_screen.show_for_player(_player_unit)


func _on_equipment_screen_unequip_slot_requested(slot_type: int) -> void:
	if _player_unit == null:
		return

	_player_unit.unequip_slot(slot_type)
	_sync_profile_from_player()
	equipment_screen.show_for_player(_player_unit)


func _on_skill_screen_equip_reserve_requested(reserve_index: int, slot_index: int) -> void:
	if _player_unit == null:
		return

	_player_unit.equip_reserve_skill_to_slot(reserve_index, slot_index)
	_sync_profile_from_player()
	skill_loadout_screen.show_for_loadout(_player_unit.get_skill_loadout())


func _on_skill_screen_unequip_slot_requested(slot_index: int) -> void:
	if _player_unit == null:
		return

	_player_unit.unequip_skill_slot(slot_index)
	_sync_profile_from_player()
	skill_loadout_screen.show_for_loadout(_player_unit.get_skill_loadout())


func _on_world_map_node_selected(node_data: MapNodeData) -> void:
	if not map_run_state.should_resolve_node(node_data.id):
		map_run_state.move_to_node(node_data.id)
		return

	map_run_state.set_pending_node(node_data.id)
	_resolve_map_node(node_data)


func _resolve_map_node(node_data: MapNodeData) -> void:
	match node_data.node_type:
		MapNodeData.TYPE_COMBAT, MapNodeData.TYPE_ELITE, MapNodeData.TYPE_BOSS:
			_open_battle_for_node(node_data)
		MapNodeData.TYPE_RESOURCE:
			_resolve_resource_node(node_data)
		MapNodeData.TYPE_EVENT:
			_resolve_event_node(node_data)


func _resolve_resource_node(_node_data: MapNodeData) -> void:
	ExpeditionState.add_resource(ExpeditionState.RESOURCE_MONSTER_MATERIALS, 1)
	map_run_state.commit_pending_node()
	if _world_map_controller != null:
		_world_map_controller.refresh()


func _resolve_event_node(node_data: MapNodeData) -> void:
	map_run_state.commit_pending_node()
	print("Event node placeholder resolved: %d" % node_data.id)
	if _world_map_controller != null:
		_world_map_controller.refresh()


func _on_battle_won() -> void:
	_sync_profile_from_player()
	map_run_state.commit_pending_node()
	if _active_battle_node_type == MapNodeData.TYPE_BOSS:
		_complete_current_dungeon()
		return

	_open_world_map(false)


func _on_battle_lost() -> void:
	_sync_profile_from_player()
	_fail_expedition()


func _on_battle_exited() -> void:
	_sync_profile_from_player()
	_return_to_main_base_after_dungeon()


func _complete_current_dungeon() -> void:
	ExpeditionState.complete_current_dungeon()
	_return_to_main_base_after_dungeon()


func _fail_expedition() -> void:
	ExpeditionState.fail_expedition()
	ExpeditionState.reset()
	if player_profile != null:
		player_profile.reset_streak()
	_return_to_main_base_after_dungeon()


func _return_to_main_base_after_dungeon() -> void:
	map_run_state.clear_pending_node()
	map_run_state.clear_run()
	_open_main_base()


func _get_current_dungeon_seed() -> int:
	return initial_seed + max(0, ExpeditionState.dungeon_index - 1)


func _get_enemy_data_for_node(node_data: MapNodeData) -> UnitData:
	var enemy_data: UnitData = null
	match node_data.node_type:
		MapNodeData.TYPE_ELITE:
			enemy_data = elite_enemy_data if elite_enemy_data != null else combat_enemy_data
		MapNodeData.TYPE_BOSS:
			enemy_data = boss_enemy_data if boss_enemy_data != null else elite_enemy_data if elite_enemy_data != null else combat_enemy_data
		MapNodeData.TYPE_COMBAT:
			enemy_data = combat_enemy_data
		_:
			return null

	return _get_scaled_enemy_data(enemy_data)


func _get_scaled_enemy_data(enemy_data: UnitData) -> UnitData:
	if enemy_data == null:
		return null

	var dungeon_bonus: int = max(0, ExpeditionState.dungeon_index - 1)
	if dungeon_bonus <= 0:
		return enemy_data

	var scaled_enemy := enemy_data.duplicate() as UnitData
	var hp_multiplier := 1.0 + float(dungeon_bonus) * 0.12
	var atk_multiplier := 1.0 + float(dungeon_bonus) * 0.08
	scaled_enemy.max_hp = max(1, int(round(float(enemy_data.max_hp) * hp_multiplier)))
	scaled_enemy.atk = max(1, int(round(float(enemy_data.atk) * atk_multiplier)))
	scaled_enemy.def = enemy_data.def + int(dungeon_bonus / 3)
	return scaled_enemy
