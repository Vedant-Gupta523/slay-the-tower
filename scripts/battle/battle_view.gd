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
const DEFAULT_TOOLTIP_TEXT := "Hover an action or skill for details. The last tooltip stays here so longer text can be scrolled."
const SKILL_BUTTON_SIZE := Vector2(140, 40)
const SKILL_BUTTON_READY_COLOR := Color.WHITE
const SKILL_BUTTON_DISABLED_COLOR := Color(0.62, 0.62, 0.62)
const SKILL_BUTTON_COOLDOWN_COLOR := Color(0.48, 0.48, 0.48)
const ACTION_BUTTON_READY_COLOR := Color.WHITE
const ACTION_BUTTON_DISABLED_COLOR := Color(0.68, 0.68, 0.68)
const PLAYER_TURN_COLOR := Color(0.8, 0.95, 1.0)
const ENEMY_TURN_COLOR := Color(1.0, 0.84, 0.72)
const RESULT_TURN_COLOR := Color(1.0, 0.95, 0.62)
const HP_TWEEN_TIME := 0.28
const IMPACT_BEAT_TIME := 0.12

const PLAYER_SPRITE_SHEET := preload("res://assets/Wizzart_C.png")
const ENEMY_SPRITE_SHEET := preload("res://assets/Orc_Big.png")

@onready var turn_label: Label = %TurnLabel
@onready var battler_stage: Control = %BattlerStage
@onready var fx_layer: Control = get_node_or_null("%FxLayer") as Control
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
@onready var skill_bar: Container = %SkillBar
@onready var tooltip_label: RichTextLabel = %TooltipLabel
@onready var popup_layer: Control = %PopupLayer

var log_lines: Array[String] = []
var has_unit_ui := false
var player_hp_tween: Tween
var enemy_hp_tween: Tween

func _ready() -> void:
	_setup_fx_layer()
	_setup_battlers()
	battler_stage.resized.connect(_position_battlers)
	call_deferred("_position_battlers")
	_setup_action_tooltips()
	_hide_tooltip()
	attack_button.pressed.connect(_on_attack_button_pressed)
	defend_button.pressed.connect(_on_defend_button_pressed)

func _on_attack_button_pressed() -> void:
	_pulse_button(attack_button)
	attack_pressed.emit()

func _on_defend_button_pressed() -> void:
	_pulse_button(defend_button)
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
	var button_color := ACTION_BUTTON_READY_COLOR if enabled else ACTION_BUTTON_DISABLED_COLOR
	attack_button.modulate = button_color
	defend_button.modulate = button_color

func _setup_action_tooltips() -> void:
	_connect_tooltip(attack_button, "Attack", "Deals basic attack damage to the enemy.")
	_connect_tooltip(defend_button, "Defend", "Reduce the next incoming hit.")

func _setup_fx_layer() -> void:
	if fx_layer != null:
		return

	fx_layer = Control.new()
	fx_layer.name = "FxLayer"
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	battler_stage.add_child(fx_layer)
	battler_stage.move_child(fx_layer, battler_stage.get_child_count() - 1)

func present_player_turn_started() -> void:
	emphasize_turn(TARGET_PLAYER)
	set_turn_text("Player Turn")
	set_log_text("Choose an action.")

func present_enemy_turn_started(enemy_name: String) -> void:
	emphasize_turn(TARGET_ENEMY)
	set_turn_text("Enemy Turn")
	set_log_text("%s is thinking..." % enemy_name)

func present_basic_attack(actor_name: String, target_name: String, target_side: String, damage: int) -> void:
	show_hit_effect(target_side)
	_show_damage_feedback(target_side, damage)
	set_log_text("%s attacks %s for %d damage." % [actor_name, target_name, damage])
	await get_tree().create_timer(IMPACT_BEAT_TIME).timeout

func present_skill_used(actor_name: String, skill_name: String, target_side: String, damage: int, message: String) -> void:
	show_skill_effect(target_side, skill_name, damage > 0)
	if damage > 0:
		await get_tree().create_timer(IMPACT_BEAT_TIME).timeout
		_show_damage_feedback(target_side, damage)
	set_log_text("%s uses %s. %s" % [actor_name, skill_name, message])
	await get_tree().create_timer(IMPACT_BEAT_TIME).timeout

func present_defend_activated(actor_name: String) -> void:
	set_log_text("%s takes a defensive stance." % actor_name)
	show_skill_effect(TARGET_PLAYER, "Defend", false)

func present_battle_result(player_won: bool) -> void:
	emphasize_turn("")
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
	_update_hp_bar(TARGET_PLAYER, player_hp_bar, player_max_hp, player_hp)
	_update_hp_bar(TARGET_ENEMY, enemy_hp_bar, enemy_max_hp, enemy_hp)
	has_unit_ui = true

func update_status(player_defending: bool, enemy_defending: bool) -> void:
	if player_status_label != null:
		player_status_label.text = "Defending"
		player_status_label.visible = player_defending
		if player_defending:
			_pulse_status_label(player_status_label)

	if enemy_status_label != null:
		enemy_status_label.text = "Defending"
		enemy_status_label.visible = enemy_defending
		if enemy_defending:
			_pulse_status_label(enemy_status_label)

func show_hit_effect(target_side: String) -> void:
	_flash_battler(target_side)
	_shake_battler(target_side)
	_spawn_burst(target_side, Color(1.0, 0.24, 0.12, 0.72), Vector2(52, 52))

func show_skill_effect(target_side: String, skill_name: String, is_offensive: bool) -> void:
	if is_offensive:
		_spawn_burst(target_side, Color(0.38, 0.72, 1.0, 0.65), Vector2(72, 72))
		return

	_spawn_burst(target_side, Color(0.42, 0.95, 0.7, 0.58), Vector2(88, 88))
	_pulse_status_side(target_side)

func emphasize_turn(side: String) -> void:
	match side:
		TARGET_PLAYER:
			turn_label.modulate = PLAYER_TURN_COLOR
		TARGET_ENEMY:
			turn_label.modulate = ENEMY_TURN_COLOR
		_:
			turn_label.modulate = RESULT_TURN_COLOR

	turn_label.scale = Vector2(1.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(turn_label, "scale", Vector2(1.04, 1.04), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(turn_label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _update_hp_bar(side: String, bar: ProgressBar, max_hp: int, current_hp: int) -> void:
	bar.max_value = max(max_hp, 1)
	var target_value: int = clamp(current_hp, 0, max_hp)

	if not has_unit_ui:
		bar.value = target_value
		return

	var tween_ref := player_hp_tween if side == TARGET_PLAYER else enemy_hp_tween
	if tween_ref != null and tween_ref.is_valid():
		tween_ref.kill()

	var tween: Tween = create_tween()
	tween.tween_property(bar, "value", target_value, HP_TWEEN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if side == TARGET_PLAYER:
		player_hp_tween = tween
	else:
		enemy_hp_tween = tween

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

	sprite.modulate = Color(1.0, 0.5, 0.42)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.22)

func _shake_battler(target_side: String) -> void:
	var root: Node2D = _get_battler_root(target_side)

	if root == null:
		return

	var start_position: Vector2 = root.position
	var recoil_x := -8.0 if target_side == TARGET_PLAYER else 8.0
	var tween: Tween = create_tween()
	tween.tween_property(root, "position", start_position + Vector2(recoil_x, -2), 0.05)
	tween.tween_property(root, "position", start_position + Vector2(-recoil_x * 0.45, 1), 0.06)
	tween.tween_property(root, "position", start_position, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _spawn_burst(target_side: String, color: Color, burst_size: Vector2) -> void:
	var root: Node2D = _get_battler_root(target_side)

	if root == null or fx_layer == null:
		return

	var burst := ColorRect.new()
	burst.color = color
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.custom_minimum_size = burst_size
	burst.size = burst_size
	burst.pivot_offset = burst_size * 0.5
	burst.position = root.position + Vector2(-burst_size.x * 0.5, -58.0 - burst_size.y * 0.5)
	burst.scale = Vector2(0.35, 0.35)
	fx_layer.add_child(burst)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector2(1.25, 1.25), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): burst.queue_free())

func _pulse_button(button: Button) -> void:
	if button == null:
		return

	button.scale = Vector2(1.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.96, 0.96), 0.05)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _pulse_status_side(target_side: String) -> void:
	match target_side:
		TARGET_PLAYER:
			_pulse_status_label(player_status_label)
		TARGET_ENEMY:
			_pulse_status_label(enemy_status_label)

func _pulse_status_label(label: Label) -> void:
	if label == null or not label.visible:
		return

	label.modulate = Color(0.55, 1.0, 0.78)
	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate", Color.WHITE, 0.25)

func _get_battler_root(target_side: String) -> Node2D:
	match target_side:
		TARGET_PLAYER:
			return player_battler_root
		TARGET_ENEMY:
			return enemy_battler_root
		_:
			return null

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
		button.custom_minimum_size = SKILL_BUTTON_SIZE
		button.text = _get_skill_button_text(skill)
		_connect_tooltip(button, skill.get_skill_name(), _get_skill_tooltip_body(skill))
		button.pressed.connect(_on_skill_button_internal_pressed.bind(i))
		skill_bar.add_child(button)

func refresh_skill_bar(skills, player_turn: bool) -> void:
	for i in range(skill_bar.get_child_count()):
		var button: Button = skill_bar.get_child(i) as Button
		var skill = skills[i]

		button.text = _get_skill_button_text(skill)
		_apply_skill_button_state(button, skill, player_turn)
		_set_button_tooltip_data(button, skill.get_skill_name(), _get_skill_tooltip_body(skill))

func _on_skill_button_internal_pressed(skill_index: int) -> void:
	if skill_index >= 0 and skill_index < skill_bar.get_child_count():
		var button := skill_bar.get_child(skill_index) as Button
		_pulse_button(button)
	skill_pressed.emit(skill_index)

func _get_skill_button_text(skill) -> String:
	if skill.is_available():
		return skill.get_skill_name()

	return "%s\nCooldown %d" % [skill.get_skill_name(), skill.get_remaining_cooldown()]

func _apply_skill_button_state(button: Button, skill, player_turn: bool) -> void:
	if not skill.is_available():
		button.disabled = true
		button.modulate = SKILL_BUTTON_COOLDOWN_COLOR
		return

	button.disabled = not player_turn
	button.modulate = SKILL_BUTTON_READY_COLOR if player_turn else SKILL_BUTTON_DISABLED_COLOR

func _connect_tooltip(control: Control, title: String, body: String) -> void:
	_set_button_tooltip_data(control, title, body)
	control.mouse_entered.connect(_show_control_tooltip.bind(control))
	control.focus_entered.connect(_show_control_tooltip.bind(control))

func _set_button_tooltip_data(control: Control, title: String, body: String) -> void:
	control.set_meta("tooltip_title", title)
	control.set_meta("tooltip_body", body)

func _show_control_tooltip(control: Control) -> void:
	var title: String = control.get_meta("tooltip_title", "") as String
	var body: String = control.get_meta("tooltip_body", "") as String

	if title == "" and body == "":
		return

	tooltip_label.text = "[b]%s[/b]\n%s" % [title, body]

func _hide_tooltip() -> void:
	tooltip_label.text = DEFAULT_TOOLTIP_TEXT

func _get_skill_tooltip_body(skill) -> String:
	var lines: Array[String] = []
	var description: String = skill.get_description()

	if description != "":
		lines.append(description)

	lines.append("Target: %s" % _get_target_type_text(skill.get_target_type()))
	lines.append("Cooldown: %s" % _get_cooldown_text(skill))

	return "\n".join(lines)

func _get_target_type_text(target_type) -> String:
	match target_type:
		SkillData.TargetType.SELF:
			return "Self"
		SkillData.TargetType.ENEMY:
			return "Enemy"
		_:
			return "Unknown"

func _get_cooldown_text(skill) -> String:
	var remaining_cooldown: int = skill.get_remaining_cooldown()

	if remaining_cooldown > 0:
		return "%d turn(s) remaining" % remaining_cooldown

	return "Ready"
