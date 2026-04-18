class_name BattleController
extends Control

@export var player_data: UnitData
@export var enemy_data: UnitData
@export var enemy_turn_delay: float = 0.75

@onready var turn_label: Label = $MarginContainer/VBoxContainer/TurnLabel
@onready var player_hp_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/PlayerBox/PlayerHpLabel
@onready var enemy_hp_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/EnemyBox/EnemyHpLabel
@onready var log_label: Label = $MarginContainer/VBoxContainer/LogLabel
@onready var attack_button: Button = $MarginContainer/VBoxContainer/Actions/AttackButton
@onready var defend_button: Button = $MarginContainer/VBoxContainer/Actions/DefendButton
@onready var skill_bar: HBoxContainer = $MarginContainer/VBoxContainer/SkillBar

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

func _ready() -> void:
	attack_button.pressed.connect(_on_attack_button_pressed)
	defend_button.pressed.connect(_on_defend_button_pressed)
	start_battle()

func set_action_buttons_enabled(enabled: bool) -> void:
	attack_button.disabled = not enabled
	defend_button.disabled = not enabled

func start_battle() -> void:
	player = PlayerUnit.new(player_data)
	enemy = EnemyUnit.new(enemy_data)

	build_skill_bar()
	update_ui()

	if player.get_spd() >= enemy.get_spd():
		start_player_turn()
	else:
		run_enemy_turn()

func build_skill_bar() -> void:
	for child in skill_bar.get_children():
		child.queue_free()

	var player_skills: Array[SkillInstance] = player.get_skills()

	for i in range(player_skills.size()):
		var skill: SkillInstance = player_skills[i]
		var button := Button.new()
		button.text = skill.get_skill_name()
		button.pressed.connect(_on_skill_button_pressed.bind(i))
		skill_bar.add_child(button)

func refresh_skill_bar() -> void:
	var player_skills = player.get_skills()

	for i in range(skill_bar.get_child_count()):
		var button: Button = skill_bar.get_child(i) as Button
		var skill = player_skills[i]

		if skill.is_available():
			button.text = skill.get_skill_name()
			button.disabled = battle_state != BattleState.PLAYER_TURN
		else:
			button.text = "%s (%d)" % [skill.get_skill_name(), skill.get_remaining_cooldown()]
			button.disabled = true

func start_player_turn() -> void:
	player.reduce_skill_cooldowns()

	for skill in player.get_skills():
		print("%s cooldown: %d" % [skill.get_skill_name(), skill.get_remaining_cooldown()])

	battle_state = BattleState.PLAYER_TURN
	turn_label.text = "Player Turn"
	log_label.text = "Choose an action."
	set_action_buttons_enabled(true)
	refresh_skill_bar()

func run_enemy_turn() -> void:
	battle_state = BattleState.ENEMY_TURN
	turn_label.text = "Enemy Turn"
	log_label.text = "%s is thinking..." % enemy.get_unit_name()
	set_action_buttons_enabled(false)
	refresh_skill_bar()

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
		log_label.text = "%s uses %s. %s" % [
			enemy.get_unit_name(),
			chosen_skill.get_skill_name(),
			result.message
		]
	else:
		var damage: int = enemy.basic_attack(player)
		log_label.text = "%s attacks %s for %d damage." % [
			enemy.get_unit_name(),
			player.get_unit_name(),
			damage
		]

	update_ui()

	if check_battle_end():
		return

	start_player_turn()
	
func _on_attack_button_pressed() -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	set_action_buttons_enabled(false)
	refresh_skill_bar()

	var damage: int = player.basic_attack(enemy)
	log_label.text = "%s attacks %s for %d damage." % [
		player.get_unit_name(),
		enemy.get_unit_name(),
		damage
	]

	update_ui()

	if check_battle_end():
		return

	run_enemy_turn()

func _on_defend_button_pressed() -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	set_action_buttons_enabled(false)
	refresh_skill_bar()

	player.start_defending()
	log_label.text = "%s takes a defensive stance." % player.get_unit_name()

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

	set_action_buttons_enabled(false)
	refresh_skill_bar()

	var target = enemy

	if skill.get_target_type() == SkillData.TargetType.SELF:
		target = player

	var result: SkillResult = skill.use(player, target)
	log_label.text = "%s uses %s. %s" % [
		player.get_unit_name(),
		skill.get_skill_name(),
		result.message
	]

	update_ui()

	if check_battle_end():
		return

	run_enemy_turn()
	
func check_battle_end() -> bool:
	if enemy.is_dead():
		battle_state = BattleState.VICTORY
		turn_label.text = "Victory"
		log_label.text = "Player won."
		set_action_buttons_enabled(false)
		refresh_skill_bar()
		return true

	if player.is_dead():
		battle_state = BattleState.DEFEAT
		turn_label.text = "Defeat"
		log_label.text = "Player lost."
		set_action_buttons_enabled(false)
		refresh_skill_bar()
		return true

	return false

func update_ui() -> void:
	player_hp_label.text = "%s HP: %d/%d" % [
		player_data.unit_name,
		player.get_current_hp() if player != null else player_data.max_hp,
		player_data.max_hp
	]

	enemy_hp_label.text = "%s HP: %d/%d" % [
		enemy_data.unit_name,
		enemy.get_current_hp() if enemy != null else enemy_data.max_hp,
		enemy_data.max_hp
	]
