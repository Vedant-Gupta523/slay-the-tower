class_name BattleView
extends Control

signal attack_pressed
signal defend_pressed
signal skill_pressed(skill_index: int)

const MAX_LOG_LINES := 6

@onready var turn_label: Label = %TurnLabel
@onready var player_hp_label: Label = %PlayerHpLabel
@onready var player_hp_bar: ProgressBar = %PlayerHpBar
@onready var enemy_hp_label: Label = %EnemyHpLabel
@onready var enemy_hp_bar: ProgressBar = %EnemyHpBar
@onready var log_label: RichTextLabel = %LogLabel
@onready var attack_button: Button = %AttackButton
@onready var defend_button: Button = %DefendButton
@onready var skill_bar: HBoxContainer = %SkillBar

var log_lines: Array[String] = []

func _ready() -> void:
	attack_button.pressed.connect(_on_attack_button_pressed)
	defend_button.pressed.connect(_on_defend_button_pressed)

func _on_attack_button_pressed() -> void:
	attack_pressed.emit()

func _on_defend_button_pressed() -> void:
	defend_pressed.emit()

func set_turn_text(text: String) -> void:
	turn_label.text = text

func set_log_text(text: String) -> void:
	log_lines.append(text)

	if log_lines.size() > MAX_LOG_LINES:
		log_lines.pop_front()

	log_label.text = "\n".join(log_lines)

func set_action_buttons_enabled(enabled: bool) -> void:
	attack_button.disabled = not enabled
	defend_button.disabled = not enabled

func update_unit_ui(player_name: String, player_hp: int, player_max_hp: int, enemy_name: String, enemy_hp: int, enemy_max_hp: int) -> void:
	player_hp_label.text = "%s HP: %d/%d" % [player_name, player_hp, player_max_hp]
	enemy_hp_label.text = "%s HP: %d/%d" % [enemy_name, enemy_hp, enemy_max_hp]
	player_hp_bar.max_value = max(player_max_hp, 1)
	player_hp_bar.value = clamp(player_hp, 0, player_max_hp)
	enemy_hp_bar.max_value = max(enemy_max_hp, 1)
	enemy_hp_bar.value = clamp(enemy_hp, 0, enemy_max_hp)

func build_skill_bar(skills) -> void:
	for child in skill_bar.get_children():
		child.queue_free()

	for i in range(skills.size()):
		var skill = skills[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(120, 36)
		button.text = skill.get_skill_name()
		button.pressed.connect(_on_skill_button_internal_pressed.bind(i))
		skill_bar.add_child(button)

func refresh_skill_bar(skills, player_turn: bool) -> void:
	for i in range(skill_bar.get_child_count()):
		var button: Button = skill_bar.get_child(i) as Button
		var skill = skills[i]

		if skill.is_available():
			button.text = skill.get_skill_name()
			button.disabled = not player_turn
		else:
			button.text = "%s (%d)" % [skill.get_skill_name(), skill.get_remaining_cooldown()]
			button.disabled = true

func _on_skill_button_internal_pressed(skill_index: int) -> void:
	skill_pressed.emit(skill_index)
