class_name BattleController
extends Control

@export var player_data: UnitData
@export var enemy_data: UnitData
@export var enemy_turn_delay: float = 0.9

@onready var turn_label: Label = $MarginContainer/VBoxContainer/TurnLabel
@onready var player_hp_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/PlayerBox/PlayerHpLabel
@onready var enemy_hp_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/EnemyBox/EnemyHpLabel
@onready var log_label: Label = $MarginContainer/VBoxContainer/LogLabel
@onready var attack_button: Button = $MarginContainer/VBoxContainer/Actions/AttackButton

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
	start_battle()

func start_battle() -> void:
	player = PlayerUnit.new(player_data)
	enemy = EnemyUnit.new(enemy_data)

	update_ui()

	if player.get_spd() >= enemy.get_spd():
		start_player_turn()
	else:
		run_enemy_turn()

func start_player_turn() -> void:
	battle_state = BattleState.PLAYER_TURN
	turn_label.text = "Player Turn"
	log_label.text = "Choose an action."
	attack_button.disabled = false

func run_enemy_turn() -> void:
	battle_state = BattleState.ENEMY_TURN
	turn_label.text = "Enemy Turn"
	log_label.text = "%s is thinking..." % enemy.get_unit_name()
	attack_button.disabled = true

	await get_tree().create_timer(enemy_turn_delay).timeout

	if battle_state != BattleState.ENEMY_TURN:
		return

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

	attack_button.disabled = true

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

func check_battle_end() -> bool:
	if enemy.is_dead():
		battle_state = BattleState.VICTORY
		turn_label.text = "Victory"
		log_label.text = "Player won."
		attack_button.disabled = true
		return true

	if player.is_dead():
		battle_state = BattleState.DEFEAT
		turn_label.text = "Defeat"
		log_label.text = "Player lost."
		attack_button.disabled = true
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
