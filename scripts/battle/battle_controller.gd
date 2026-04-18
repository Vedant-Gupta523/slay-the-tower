class_name BattleController
extends Node

@export var player_data: UnitData
@export var enemy_data: UnitData
@export var enemy_turn_delay: float = 0.75

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

func _ready() -> void:
	view = get_parent() as BattleView

	if view == null:
		push_error("BattleController requires a BattleView parent.")
		return

	await view.ready

	view.attack_pressed.connect(_on_attack_button_pressed)
	view.defend_pressed.connect(_on_defend_button_pressed)
	view.skill_pressed.connect(_on_skill_button_pressed)

	start_battle()

func start_battle() -> void:
	player = PlayerUnit.new(player_data)
	enemy = EnemyUnit.new(enemy_data)

	view.build_skill_bar(player.get_skills())
	update_ui()

	if player.get_spd() >= enemy.get_spd():
		start_player_turn()
	else:
		run_enemy_turn()

func start_player_turn() -> void:
	player.reduce_skill_cooldowns()

	battle_state = BattleState.PLAYER_TURN
	view.set_turn_text("Player Turn")
	view.set_log_text("Choose an action.")
	view.set_action_buttons_enabled(true)
	view.refresh_skill_bar(player.get_skills(), true)

func run_enemy_turn() -> void:
	battle_state = BattleState.ENEMY_TURN
	view.set_turn_text("Enemy Turn")
	view.set_log_text("%s is thinking..." % enemy.get_unit_name())
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

		var result: SkillResult = chosen_skill.use(enemy, target)
		view.set_log_text("%s uses %s. %s" % [
			enemy.get_unit_name(),
			chosen_skill.get_skill_name(),
			result.message
		])
	else:
		var damage: int = enemy.basic_attack(player)
		view.set_log_text("%s attacks %s for %d damage." % [
			enemy.get_unit_name(),
			player.get_unit_name(),
			damage
		])

	update_ui()

	if check_battle_end():
		return

	start_player_turn()

func _on_attack_button_pressed() -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	view.set_action_buttons_enabled(false)
	view.refresh_skill_bar(player.get_skills(), false)

	var damage: int = player.basic_attack(enemy)
	view.set_log_text("%s attacks %s for %d damage." % [
		player.get_unit_name(),
		enemy.get_unit_name(),
		damage
	])

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
	view.set_log_text("%s takes a defensive stance." % player.get_unit_name())

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

	var result: SkillResult = skill.use(player, target)
	view.set_log_text("%s uses %s. %s" % [
		player.get_unit_name(),
		skill.get_skill_name(),
		result.message
	])

	update_ui()

	if check_battle_end():
		return

	run_enemy_turn()

func check_battle_end() -> bool:
	if enemy.is_dead():
		battle_state = BattleState.VICTORY
		view.set_turn_text("Victory")
		view.set_log_text("Player won.")
		view.set_action_buttons_enabled(false)
		view.refresh_skill_bar(player.get_skills(), false)
		return true

	if player.is_dead():
		battle_state = BattleState.DEFEAT
		view.set_turn_text("Defeat")
		view.set_log_text("Player lost.")
		view.set_action_buttons_enabled(false)
		view.refresh_skill_bar(player.get_skills(), false)
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
