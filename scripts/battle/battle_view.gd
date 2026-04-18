class_name BattleView
extends Control

signal attack_pressed
signal defend_pressed
signal skill_pressed(skill_index: int)

const MAX_LOG_LINES := 6
const TARGET_PLAYER := "player"
const TARGET_ENEMY := "enemy"
const POPUP_DAMAGE := "damage"
const PLAYER_FRAME_SIZE := Vector2i(64, 48)
const ENEMY_FRAME_SIZE := Vector2i(64, 32)
const BATTLER_FRAME_COUNT := 8

const PLAYER_SPRITE_SHEET := preload("res://assets/Wizzart_C.png")
const ENEMY_SPRITE_SHEET := preload("res://assets/Orc_Big.png")

@onready var turn_label: Label = %TurnLabel
@onready var battler_stage: Control = %BattlerStage
@onready var player_battler_root: Node2D = %PlayerBattlerRoot
@onready var player_battler_sprite: AnimatedSprite2D = %PlayerBattlerSprite
@onready var enemy_battler_root: Node2D = %EnemyBattlerRoot
@onready var enemy_battler_sprite: AnimatedSprite2D = %EnemyBattlerSprite
@onready var player_hp_label: Label = %PlayerHpLabel
@onready var player_hp_bar: ProgressBar = %PlayerHpBar
@onready var player_status_label: Label = get_node_or_null("%PlayerStatusLabel") as Label
@onready var enemy_hp_label: Label = %EnemyHpLabel
@onready var enemy_hp_bar: ProgressBar = %EnemyHpBar
@onready var enemy_status_label: Label = get_node_or_null("%EnemyStatusLabel") as Label
@onready var log_label: RichTextLabel = %LogLabel
@onready var attack_button: Button = %AttackButton
@onready var defend_button: Button = %DefendButton
@onready var skill_bar: HBoxContainer = %SkillBar
@onready var popup_layer: Control = %PopupLayer

var log_lines: Array[String] = []

func _ready() -> void:
	_setup_battlers()
	battler_stage.resized.connect(_position_battlers)
	call_deferred("_position_battlers")
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

func present_player_turn_started() -> void:
	set_turn_text("Player Turn")
	set_log_text("Choose an action.")

func present_enemy_turn_started(enemy_name: String) -> void:
	set_turn_text("Enemy Turn")
	set_log_text("%s is thinking..." % enemy_name)

func present_basic_attack(actor_name: String, target_name: String, target_side: String, damage: int) -> void:
	_show_damage_feedback(target_side, damage)
	set_log_text("%s attacks %s for %d damage." % [actor_name, target_name, damage])

func present_skill_used(actor_name: String, skill_name: String, target_side: String, damage: int, message: String) -> void:
	_show_damage_feedback(target_side, damage)
	set_log_text("%s uses %s. %s" % [actor_name, skill_name, message])

func present_defend_activated(actor_name: String) -> void:
	set_log_text("%s takes a defensive stance." % actor_name)

func present_battle_result(player_won: bool) -> void:
	if player_won:
		set_turn_text("Victory")
		set_log_text("Player won.")
	else:
		set_turn_text("Defeat")
		set_log_text("Player lost.")

func play_player_attack() -> void:
	await _play_battler_action(player_battler_sprite, "attack")

func play_enemy_attack() -> void:
	await _play_battler_action(enemy_battler_sprite, "attack")

func update_unit_ui(player_name: String, player_hp: int, player_max_hp: int, enemy_name: String, enemy_hp: int, enemy_max_hp: int) -> void:
	player_hp_label.text = "%s HP: %d/%d" % [player_name, player_hp, player_max_hp]
	enemy_hp_label.text = "%s HP: %d/%d" % [enemy_name, enemy_hp, enemy_max_hp]
	player_hp_bar.max_value = max(player_max_hp, 1)
	player_hp_bar.value = clamp(player_hp, 0, player_max_hp)
	enemy_hp_bar.max_value = max(enemy_max_hp, 1)
	enemy_hp_bar.value = clamp(enemy_hp, 0, enemy_max_hp)

func update_status(player_defending: bool, enemy_defending: bool) -> void:
	if player_status_label != null:
		player_status_label.text = "Defending"
		player_status_label.visible = player_defending

	if enemy_status_label != null:
		enemy_status_label.text = "Defending"
		enemy_status_label.visible = enemy_defending

func show_floating_text(target_side: String, text: String, kind: String = POPUP_DAMAGE) -> void:
	var target_anchor: Control = _get_floating_text_anchor(target_side)

	if target_anchor == null:
		return

	var popup: Label = Label.new()
	popup.custom_minimum_size = Vector2(96, 32)
	popup.size = popup.custom_minimum_size
	popup.text = text
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.modulate = Color(1, 1, 1, 1)
	popup.add_theme_color_override("font_color", _get_floating_text_color(kind))
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	popup.add_theme_constant_override("outline_size", 4)
	popup.add_theme_font_size_override("font_size", 22)

	popup_layer.add_child(popup)

	var start_position: Vector2 = target_anchor.global_position + Vector2(
		(target_anchor.size.x - popup.size.x) * 0.5,
		-12
	)
	popup.global_position = start_position

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position", popup.position + Vector2(0, -36), 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.65).set_delay(0.15)
	tween.finished.connect(func(): popup.queue_free())

func _get_floating_text_anchor(target_side: String) -> Control:
	match target_side:
		TARGET_PLAYER:
			return player_hp_bar
		TARGET_ENEMY:
			return enemy_hp_bar
		_:
			return null

func _get_floating_text_color(kind: String) -> Color:
	match kind:
		POPUP_DAMAGE:
			return Color(1.0, 0.25, 0.18)
		_:
			return Color.WHITE

func _show_damage_feedback(target_side: String, damage: int) -> void:
	if damage <= 0:
		return

	show_floating_text(target_side, "-%d" % damage, POPUP_DAMAGE)
	_flash_battler(target_side)

func _setup_battlers() -> void:
	_setup_battler_sprite(player_battler_sprite, PLAYER_SPRITE_SHEET, PLAYER_FRAME_SIZE, 0, 2)
	_setup_battler_sprite(enemy_battler_sprite, ENEMY_SPRITE_SHEET, ENEMY_FRAME_SIZE, 0, 2)
	player_battler_sprite.flip_h = false
	enemy_battler_sprite.flip_h = true

func _setup_battler_sprite(sprite: AnimatedSprite2D, texture: Texture2D, frame_size: Vector2i, idle_row: int, attack_row: int) -> void:
	var frames: SpriteFrames = SpriteFrames.new()
	var max_rows: int = int(max(1, int(texture.get_height() / frame_size.y)))
	var safe_idle_row: int = int(clamp(idle_row, 0, max_rows - 1))
	var safe_attack_row: int = int(clamp(attack_row, 0, max_rows - 1))

	_add_sheet_animation(frames, "idle", texture, frame_size, safe_idle_row, true, 8.0)
	_add_sheet_animation(frames, "attack", texture, frame_size, safe_attack_row, false, 12.0)

	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = Vector2(-frame_size.x * 0.5, -frame_size.y)
	sprite.play("idle")

func _add_sheet_animation(frames: SpriteFrames, animation_name: String, texture: Texture2D, frame_size: Vector2i, row: int, loops: bool, speed: float) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loops)
	frames.set_animation_speed(animation_name, speed)

	var frame_count: int = int(min(BATTLER_FRAME_COUNT, int(texture.get_width() / frame_size.x)))

	for frame_index in range(frame_count):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(
			frame_index * frame_size.x,
			row * frame_size.y,
			frame_size.x,
			frame_size.y
		)
		frames.add_frame(animation_name, atlas)

func _position_battlers() -> void:
	var stage_size: Vector2 = battler_stage.size
	var baseline_y: float = stage_size.y - 8.0
	player_battler_root.position = Vector2(stage_size.x * 0.25, baseline_y)
	enemy_battler_root.position = Vector2(stage_size.x * 0.75, baseline_y)

func _play_battler_action(sprite: AnimatedSprite2D, animation_name: String) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		return

	sprite.play(animation_name)
	sprite.frame = 0
	await sprite.animation_finished

	if is_instance_valid(sprite) and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

func _flash_battler(target_side: String) -> void:
	var sprite: AnimatedSprite2D = _get_battler_sprite(target_side)

	if sprite == null:
		return

	sprite.modulate = Color(1.0, 0.55, 0.55)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)

func _get_battler_sprite(target_side: String) -> AnimatedSprite2D:
	match target_side:
		TARGET_PLAYER:
			return player_battler_sprite
		TARGET_ENEMY:
			return enemy_battler_sprite
		_:
			return null

func build_skill_bar(skills) -> void:
	for child in skill_bar.get_children():
		child.queue_free()

	for i in range(skills.size()):
		var skill = skills[i]
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(116, 34)
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
