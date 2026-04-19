extends Node
class_name GameRunFlow

@export var world_map_scene: PackedScene = preload("res://scenes/map/WorldMap.tscn")
@export var battle_scene: PackedScene = preload("res://scenes/battle/battle_scene.tscn")
@export var initial_seed: int = 0
@export var player_unit_data: UnitData
@export var combat_enemy_data: UnitData
@export var elite_enemy_data: UnitData
@export var boss_enemy_data: UnitData

@onready var map_run_state: MapRunState = $MapRunState
@onready var current_scene_root: Node = $CurrentSceneRoot
@onready var inventory_button: Button = %InventoryButton
@onready var skills_button: Button = %SkillsButton
@onready var equipment_screen: EquipmentScreen = %EquipmentScreen
@onready var skill_loadout_screen: SkillLoadoutScreen = %SkillLoadoutScreen

var _world_map_controller: WorldMapController
var _battle_controller: BattleController
var _player_unit: PlayerUnit


func _ready() -> void:
	_ensure_player_unit()
	inventory_button.pressed.connect(_on_inventory_button_pressed)
	skills_button.pressed.connect(_on_skills_button_pressed)
	equipment_screen.equip_reserve_requested.connect(_on_equipment_screen_equip_reserve_requested)
	equipment_screen.unequip_slot_requested.connect(_on_equipment_screen_unequip_slot_requested)
	skill_loadout_screen.equip_reserve_requested.connect(_on_skill_screen_equip_reserve_requested)
	skill_loadout_screen.unequip_slot_requested.connect(_on_skill_screen_unequip_slot_requested)
	_open_world_map(true)


func _open_world_map(create_run_if_missing: bool = false) -> void:
	var world_map := world_map_scene.instantiate() as WorldMapController
	world_map.auto_generate_if_missing = false
	world_map.set_run_state(map_run_state)
	_switch_to_instance(world_map)
	_world_map_controller = world_map
	_battle_controller = null
	_set_inventory_button_visible(true)
	_set_skills_button_visible(true)
	world_map.node_selected.connect(_on_world_map_node_selected)

	if create_run_if_missing and not map_run_state.has_active_run():
		world_map.start_new_run(initial_seed)
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
	_set_inventory_button_visible(false)
	_set_skills_button_visible(false)

	_battle_controller.battle_won.connect(_on_battle_won)
	_battle_controller.battle_lost.connect(_on_battle_lost)
	_battle_controller.battle_exited.connect(_on_battle_exited)


func _switch_to_instance(instance: Node) -> void:
	for child in current_scene_root.get_children():
		child.queue_free()

	current_scene_root.add_child(instance)


func _ensure_player_unit() -> void:
	if _player_unit != null or player_unit_data == null:
		return

	_player_unit = PlayerUnit.new(player_unit_data)


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
	equipment_screen.show_for_player(_player_unit)


func _on_equipment_screen_unequip_slot_requested(slot_type: int) -> void:
	if _player_unit == null:
		return

	_player_unit.unequip_slot(slot_type)
	equipment_screen.show_for_player(_player_unit)


func _on_skill_screen_equip_reserve_requested(reserve_index: int, slot_index: int) -> void:
	if _player_unit == null:
		return

	_player_unit.equip_reserve_skill_to_slot(reserve_index, slot_index)
	skill_loadout_screen.show_for_loadout(_player_unit.get_skill_loadout())


func _on_skill_screen_unequip_slot_requested(slot_index: int) -> void:
	if _player_unit == null:
		return

	_player_unit.unequip_skill_slot(slot_index)
	skill_loadout_screen.show_for_loadout(_player_unit.get_skill_loadout())


func _on_world_map_node_selected(node_data: MapNodeData) -> void:
	map_run_state.set_pending_node(node_data.id)

	match node_data.node_type:
		&"combat", &"elite", &"boss":
			_open_battle_for_node(node_data)
		_:
			map_run_state.commit_pending_node()
			print("Resolved non-battle node type: %s" % String(node_data.node_type))
			if _world_map_controller != null:
				_world_map_controller.refresh()


func _on_battle_won() -> void:
	map_run_state.commit_pending_node()
	_open_world_map(false)


func _on_battle_lost() -> void:
	map_run_state.clear_pending_node()
	_open_world_map(false)


func _on_battle_exited() -> void:
	map_run_state.clear_pending_node()
	_open_world_map(false)


func _get_enemy_data_for_node(node_data: MapNodeData) -> UnitData:
	match node_data.node_type:
		&"elite":
			return elite_enemy_data if elite_enemy_data != null else combat_enemy_data
		&"boss":
			return boss_enemy_data if boss_enemy_data != null else elite_enemy_data if elite_enemy_data != null else combat_enemy_data
		&"combat":
			return combat_enemy_data
		_:
			return null
