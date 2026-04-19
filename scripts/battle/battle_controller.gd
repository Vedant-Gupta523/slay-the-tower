class_name BattleController
extends Node

signal battle_won
signal battle_lost
signal battle_exited

@export var player_data: UnitData
@export var enemy_data: UnitData
@export var enemy_turn_delay: float = 0.75

const EQUIPMENT_REWARD_DIR := "res://data/equipment"
const REWARD_OPTION_COUNT := 3

enum BattleState {
	START,
	PLAYER_TURN,
	ENEMY_TURN,
	VICTORY,
	DEFEAT
}

var player: PlayerUnit
var enemy: EnemyUnit
var battle_state: BattleState = BattleState.START
var view: BattleView
var _result_emitted: bool = false
var reward_options: Array[EquipmentData] = []

func _ready() -> void:
	view = get_parent() as BattleView

	if view == null:
		push_error("BattleController requires a BattleView parent.")
		return

	await view.ready

	view.attack_pressed.connect(_on_attack_button_pressed)
	view.defend_pressed.connect(_on_defend_button_pressed)
	view.skill_pressed.connect(_on_skill_button_pressed)
	view.reward_selected.connect(_on_reward_selected)
	view.reward_skipped.connect(_on_reward_skipped)
	view.equipment_manage_requested.connect(_on_equipment_manage_requested)
	view.reserve_equipment_equip_requested.connect(_on_reserve_equipment_equip_requested)
	view.equipment_slot_unequip_requested.connect(_on_equipment_slot_unequip_requested)
	set_process_unhandled_input(true)

	start_battle()

func start_battle() -> void:
	player = PlayerUnit.new(player_data)
	enemy = EnemyUnit.new(enemy_data)

	view.hide_equipment_rewards()
	view.hide_equipment_panel()
	view.build_skill_bar(player.get_skills())
	update_ui()

	if player.get_spd() >= enemy.get_spd():
		start_player_turn()
	else:
		run_enemy_turn()

func start_player_turn() -> void:
	player.reduce_skill_cooldowns()

	battle_state = BattleState.PLAYER_TURN
	view.present_player_turn_started()
	view.set_action_buttons_enabled(true)
	view.refresh_skill_bar(player.get_skills(), true)

func run_enemy_turn() -> void:
	battle_state = BattleState.ENEMY_TURN
	view.present_enemy_turn_started(enemy.get_unit_name())
	view.set_action_buttons_enabled(false)
	view.refresh_skill_bar(player.get_skills(), false)

	await get_tree().create_timer(enemy_turn_delay).timeout

	if battle_state != BattleState.ENEMY_TURN:
		return

	enemy.reduce_skill_cooldowns()

	var enemy_skills = enemy.get_skills()
	var chosen_skill = null

	for skill in enemy_skills:
		if skill.is_available():
			chosen_skill = skill
			break

	if chosen_skill != null:
		var target = player

		if chosen_skill.get_target_type() == SkillData.TargetType.SELF:
			target = enemy

		if target != enemy:
			await view.play_enemy_attack()

		var result: SkillResult = chosen_skill.use(enemy, target)
		await view.present_skill_used(
			enemy.get_unit_name(),
			chosen_skill.get_skill_name(),
			_get_target_side(target),
			result.damage,
			result.message
		)
	else:
		await view.play_enemy_attack()
		var damage: int = enemy.basic_attack(player)
		await view.present_basic_attack(
			enemy.get_unit_name(),
			player.get_unit_name(),
			BattleView.TARGET_PLAYER,
			damage
		)

	update_ui()

	if check_battle_end():
		return

	start_player_turn()

func _on_attack_button_pressed() -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	view.set_action_buttons_enabled(false)
	view.refresh_skill_bar(player.get_skills(), false)

	await view.play_player_attack()
	var damage: int = player.basic_attack(enemy)
	await view.present_basic_attack(
		player.get_unit_name(),
		enemy.get_unit_name(),
		BattleView.TARGET_ENEMY,
		damage
	)

	update_ui()

	if check_battle_end():
		return

	run_enemy_turn()

func _on_defend_button_pressed() -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	view.set_action_buttons_enabled(false)
	view.refresh_skill_bar(player.get_skills(), false)

	player.start_defending()
	view.present_defend_activated(player.get_unit_name())

	update_ui()

	if check_battle_end():
		return

	run_enemy_turn()

func _on_skill_button_pressed(skill_index: int) -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	var player_skills = player.get_skills()

	if skill_index < 0 or skill_index >= player_skills.size():
		return

	var skill = player_skills[skill_index]

	if not skill.is_available():
		return

	view.set_action_buttons_enabled(false)
	view.refresh_skill_bar(player.get_skills(), false)

	var target = enemy

	if skill.get_target_type() == SkillData.TargetType.SELF:
		target = player

	if target != player:
		await view.play_player_attack()

	var result: SkillResult = skill.use(player, target)
	await view.present_skill_used(
		player.get_unit_name(),
		skill.get_skill_name(),
		_get_target_side(target),
		result.damage,
		result.message
	)

	update_ui()

	if check_battle_end():
		return

	run_enemy_turn()

func check_battle_end() -> bool:
	if enemy.is_dead():
		battle_state = BattleState.VICTORY
		view.present_battle_result(true)
		view.set_action_buttons_enabled(false)
		view.refresh_skill_bar(player.get_skills(), false)
		_offer_equipment_rewards()
		return true

	if player.is_dead():
		battle_state = BattleState.DEFEAT
		view.present_battle_result(false)
		view.set_action_buttons_enabled(false)
		view.refresh_skill_bar(player.get_skills(), false)
		_emit_battle_result(&"battle_lost")
		return true

	return false

func update_ui() -> void:
	view.update_unit_ui(
		player.get_unit_name(),
		player.get_current_hp(),
		player.get_max_hp(),
		enemy.get_unit_name(),
		enemy.get_current_hp(),
		enemy.get_max_hp()
	)
	view.update_status(player.is_defending, enemy.is_defending)

func _get_target_side(target: BattleUnit) -> String:
	if target == player:
		return BattleView.TARGET_PLAYER

	return BattleView.TARGET_ENEMY

func _offer_equipment_rewards() -> void:
	reward_options = _get_equipment_reward_options()

	if reward_options.is_empty():
		view.set_log_text("No equipment rewards found.")
		_emit_battle_result(&"battle_won")
		return

	view.show_equipment_rewards(reward_options, player.get_equipped_items())

func _get_equipment_reward_options() -> Array[EquipmentData]:
	var pool := _load_equipment_reward_pool()
	var options: Array[EquipmentData] = []

	pool.shuffle()

	for item in pool:
		options.append(item)

		if options.size() >= REWARD_OPTION_COUNT:
			break

	return options

func _load_equipment_reward_pool() -> Array[EquipmentData]:
	var pool: Array[EquipmentData] = []
	var dir := DirAccess.open(EQUIPMENT_REWARD_DIR)

	if dir == null:
		push_warning("Missing equipment reward directory: %s" % EQUIPMENT_REWARD_DIR)
		return pool

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var item := load("%s/%s" % [EQUIPMENT_REWARD_DIR, file_name]) as EquipmentData

			if item != null:
				pool.append(item)

		file_name = dir.get_next()

	dir.list_dir_end()
	return pool

func _on_reward_selected(reward_index: int) -> void:
	if battle_state != BattleState.VICTORY:
		return

	if reward_index < 0 or reward_index >= reward_options.size():
		return

	var item := reward_options[reward_index]
	if player.get_equipped_item(item.slot_type) == null:
		player.equip_item(item)
		view.set_log_text("Equipped %s." % item.item_name)
	else:
		player.add_to_reserve(item)
		view.set_log_text("Stored %s in reserve." % item.item_name)

	update_ui()
	_emit_battle_result(&"battle_won")

func _on_reward_skipped() -> void:
	if battle_state != BattleState.VICTORY:
		return

	view.set_log_text("Skipped equipment reward.")
	_emit_battle_result(&"battle_won")

func _on_equipment_manage_requested() -> void:
	if player == null:
		return

	view.show_equipment_panel(player.get_equipped_items(), player.get_reserve_inventory())

func _on_reserve_equipment_equip_requested(reserve_index: int) -> void:
	if player == null:
		return

	var item := player.equip_reserve_item(reserve_index)

	if item == null:
		return

	view.set_log_text("Equipped %s." % item.item_name)
	update_ui()
	_refresh_equipment_panel()

func _on_equipment_slot_unequip_requested(slot_type: int) -> void:
	if player == null:
		return

	var item := player.unequip_slot(slot_type)

	if item == null:
		return

	view.set_log_text("Moved %s to reserve." % item.item_name)
	update_ui()
	_refresh_equipment_panel()

func _refresh_equipment_panel() -> void:
	view.show_equipment_panel(player.get_equipped_items(), player.get_reserve_inventory())


func _unhandled_input(event: InputEvent) -> void:
	if _result_emitted:
		return

	if event.is_action_pressed("ui_cancel"):
		if view != null:
			view.set_action_buttons_enabled(false)
			if player != null:
				view.refresh_skill_bar(player.get_skills(), false)
		_emit_battle_result(&"battle_exited")
		get_viewport().set_input_as_handled()


func _emit_battle_result(signal_name: StringName) -> void:
	if _result_emitted:
		return

	_result_emitted = true
	call_deferred("emit_signal", signal_name)
