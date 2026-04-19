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
@onready var reward_notification_panel: PanelContainer = %RewardNotificationPanel
@onready var reward_notification_title: Label = %RewardNotificationTitle
@onready var reward_notification_list: VBoxContainer = %RewardNotificationList

var _world_map_controller: WorldMapController
var _battle_controller: BattleController
var _main_base_controller: MainBaseController
var _player_unit: PlayerUnit
var _active_battle_node_type: StringName = &""
var _active_node_resolution: Dictionary = {}
var _reward_notification_tween: Tween
var _reward_notification_version: int = 0
var _pending_battle_reward_entries: Array[Dictionary] = []


func _ready() -> void:
	_ensure_expedition_state()
	_ensure_player_unit()
	_setup_reward_notification_panel()
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
	_active_node_resolution.clear()
	_set_inventory_button_visible(true)
	_set_skills_button_visible(true)
	world_map.node_resolution_requested.connect(_on_world_map_resolution_requested)

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
	_pending_battle_reward_entries.clear()
	_set_inventory_button_visible(false)
	_set_skills_button_visible(false)

	_battle_controller.battle_won.connect(_on_battle_won)
	_battle_controller.battle_lost.connect(_on_battle_lost)
	_battle_controller.battle_exited.connect(_on_battle_exited)
	if _battle_controller.has_signal("rewards_granted"):
		_battle_controller.rewards_granted.connect(_on_battle_rewards_granted)


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


func _on_world_map_resolution_requested(node_data: MapNodeData, resolution: Dictionary) -> void:
	_active_node_resolution = resolution.duplicate(true)

	match StringName(resolution.get("kind", &"")):
		MapRunState.RESOLUTION_BATTLE:
			_open_battle_for_node(node_data)
		MapRunState.RESOLUTION_RESOURCE, MapRunState.RESOLUTION_EVENT:
			_apply_immediate_node_resolution(resolution)
		_:
			if _world_map_controller != null:
				_world_map_controller.refresh()


func _apply_immediate_node_resolution(resolution: Dictionary) -> void:
	var granted_rewards: Array[Dictionary] = _apply_resolution_rewards(resolution)
	if not granted_rewards.is_empty():
		show_reward_notification(granted_rewards, String(resolution.get("title", "Rewards")))
	map_run_state.complete_pending_resolution()
	_active_node_resolution.clear()
	if _world_map_controller != null:
		_world_map_controller.refresh()


func _on_battle_won() -> void:
	_sync_profile_from_player()
	var resolution: Dictionary = map_run_state.resolve_pending_battle_victory()
	var granted_rewards: Array[Dictionary] = _apply_resolution_rewards(resolution)
	var combined_rewards: Array[Dictionary] = []
	combined_rewards.append_array(_pending_battle_reward_entries)
	combined_rewards.append_array(granted_rewards)
	if not combined_rewards.is_empty():
		show_reward_notification(combined_rewards, String(resolution.get("title", "Rewards")))
	_pending_battle_reward_entries.clear()
	_active_node_resolution = resolution.duplicate(true)
	if bool(resolution.get("clears_dungeon", false)) or _active_battle_node_type == MapNodeData.TYPE_BOSS:
		_complete_current_dungeon()
		return

	_open_world_map(false)


func _on_battle_lost() -> void:
	_sync_profile_from_player()
	_active_node_resolution = map_run_state.resolve_pending_battle_defeat()
	_pending_battle_reward_entries.clear()
	_fail_expedition()


func _on_battle_exited() -> void:
	_sync_profile_from_player()
	map_run_state.consume_pending_resolution()
	_active_node_resolution.clear()
	_pending_battle_reward_entries.clear()
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
	_active_node_resolution.clear()
	_pending_battle_reward_entries.clear()
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


func _apply_resolution_rewards(resolution: Dictionary) -> Array[Dictionary]:
	if resolution.is_empty():
		return []

	var reward_gold: int = int(resolution.get("reward_gold", 0))
	var penalty_gold: int = int(resolution.get("penalty_gold", 0))
	var reward_resource_type: StringName = StringName(resolution.get("reward_resource_type", ""))
	var reward_resource_amount: int = int(resolution.get("reward_resource_amount", 0))
	var reward_skill_path: String = String(resolution.get("reward_skill_path", ""))
	var granted_rewards: Array[Dictionary] = []

	if reward_gold > 0:
		ExpeditionState.add_gold(reward_gold)
		granted_rewards.append(_build_amount_reward_entry("gold", "Gold", reward_gold))

	if penalty_gold > 0:
		ExpeditionState.spend_gold(penalty_gold)

	if not String(reward_resource_type).is_empty() and reward_resource_amount > 0:
		ExpeditionState.add_resource(reward_resource_type, reward_resource_amount)
		granted_rewards.append(_build_amount_reward_entry(
			"resource",
			_get_resource_display_name(reward_resource_type),
			reward_resource_amount
		))

	if not reward_skill_path.is_empty():
		var reward_skill: SkillData = load(reward_skill_path) as SkillData
		if reward_skill != null and not ExpeditionState.skill_books.has(reward_skill):
			ExpeditionState.skill_books.append(reward_skill)
			granted_rewards.append({
				"type": "skill_book",
				"name": reward_skill.skill_name,
				"quantity": 1,
				"line": "Skill Book Found: %s" % reward_skill.skill_name,
				"detail": reward_skill.description,
			})

	return granted_rewards


func show_reward_notification(rewards: Array[Dictionary], title: String = "Rewards") -> void:
	if reward_notification_panel == null or reward_notification_title == null or reward_notification_list == null:
		return

	if rewards.is_empty():
		return

	_reward_notification_version += 1
	var notification_version: int = _reward_notification_version
	_clear_reward_notification_entries()
	reward_notification_title.text = title

	for reward in rewards:
		reward_notification_list.add_child(_create_reward_entry_label(reward))

	if _reward_notification_tween != null:
		_reward_notification_tween.kill()
		_reward_notification_tween = null

	reward_notification_panel.visible = true
	reward_notification_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	reward_notification_panel.scale = Vector2(0.97, 0.97)
	reward_notification_panel.pivot_offset = reward_notification_panel.size * 0.5

	_reward_notification_tween = create_tween()
	_reward_notification_tween.set_parallel(true)
	_reward_notification_tween.tween_property(reward_notification_panel, "modulate:a", 1.0, 0.18)
	_reward_notification_tween.tween_property(reward_notification_panel, "scale", Vector2.ONE, 0.18)

	await get_tree().create_timer(2.4).timeout

	if reward_notification_panel == null or not reward_notification_panel.visible or notification_version != _reward_notification_version:
		return

	_reward_notification_tween = create_tween()
	_reward_notification_tween.set_parallel(true)
	_reward_notification_tween.tween_property(reward_notification_panel, "modulate:a", 0.0, 0.24)
	_reward_notification_tween.tween_property(reward_notification_panel, "scale", Vector2(0.98, 0.98), 0.24)
	await _reward_notification_tween.finished
	reward_notification_panel.visible = false


func present_rewards(rewards: Array[Dictionary], title: String = "Rewards") -> void:
	show_reward_notification(rewards, title)


func _on_battle_rewards_granted(rewards: Array[Dictionary]) -> void:
	for reward in rewards:
		_pending_battle_reward_entries.append(reward.duplicate(true))


func _setup_reward_notification_panel() -> void:
	if reward_notification_panel == null:
		return

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.08, 0.1, 0.96)
	panel_style.border_color = Color(0.88, 0.78, 0.46, 0.92)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2(0, 3)
	reward_notification_panel.add_theme_stylebox_override("panel", panel_style)
	reward_notification_panel.visible = false

	if reward_notification_title != null:
		reward_notification_title.modulate = Color(1.0, 0.94, 0.72)


func _clear_reward_notification_entries() -> void:
	if reward_notification_list == null:
		return

	for child in reward_notification_list.get_children():
		child.queue_free()


func _create_reward_entry_label(reward: Dictionary) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = String(reward.get("line", "Reward"))
	label.modulate = _get_reward_entry_color(String(reward.get("type", "")))
	return label


func _get_reward_entry_color(reward_type: String) -> Color:
	match reward_type:
		"gold":
			return Color(1.0, 0.87, 0.45)
		"resource":
			return Color(0.76, 0.96, 0.76)
		"skill_book":
			return Color(0.72, 0.84, 1.0)
		"gear":
			return Color(0.95, 0.82, 1.0)
		"consumable":
			return Color(0.82, 1.0, 0.9)
		_:
			return Color(0.94, 0.95, 0.97)


func _build_amount_reward_entry(reward_type: String, reward_name: String, quantity: int) -> Dictionary:
	return {
		"type": reward_type,
		"name": reward_name,
		"quantity": quantity,
		"line": "+%d %s" % [quantity, reward_name],
	}


func _get_resource_display_name(resource_type: StringName) -> String:
	match resource_type:
		ExpeditionState.RESOURCE_MONSTER_MATERIALS:
			return "Monster Materials"
		ExpeditionState.RESOURCE_ORES:
			return "Ore"
		ExpeditionState.RESOURCE_HERBS:
			return "Herb"
		_:
			return String(resource_type).capitalize()
