class_name SkillLoadoutScreen
extends Control

signal equip_reserve_requested(reserve_index: int, slot_index: int)
signal unequip_slot_requested(slot_index: int)
signal closed

const SCREEN_DIM := Color(0.0, 0.0, 0.0, 0.78)
const PANEL_COLOR := Color(0.07, 0.075, 0.08, 0.98)
const SECTION_COLOR := Color(0.105, 0.11, 0.12, 1.0)
const SECTION_BORDER := Color(0.34, 0.36, 0.38, 0.9)
const ROW_NORMAL := Color(0.13, 0.135, 0.145, 1.0)
const ROW_HOVER := Color(0.19, 0.20, 0.21, 1.0)
const ROW_SELECTED := Color(0.26, 0.235, 0.13, 1.0)
const ROW_BORDER := Color(0.42, 0.44, 0.46, 0.55)
const ROW_SELECTED_BORDER := Color(1.0, 0.82, 0.36, 1.0)
const MUTED_COLOR := "#8b949e"
const NEUTRAL_COLOR := "#c9d1d9"

var _loadout: SkillLoadout
var _selected_skill: SkillData
var _selected_reserve_index := -1
var _selected_slot_index := -1
var _target_slot_index := -1
var _selected_button: Button
var _target_slot_button: Button
var _show_all_reserve := false

var _equipped_list: VBoxContainer
var _reserve_title: Label
var _relevant_button: Button
var _all_skills_button: Button
var _reserve_list: VBoxContainer
var _details_label: RichTextLabel
var _equip_button: Button
var _unequip_button: Button


func _ready() -> void:
	_build_ui()
	hide()


func show_for_loadout(loadout: SkillLoadout) -> void:
	_loadout = loadout
	_clear_selection()
	refresh()
	show()


func refresh() -> void:
	if _loadout == null:
		return

	_render_equipped_slots()
	_render_reserve_skills()
	_render_details()
	_update_action_buttons()


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim: ColorRect = ColorRect.new()
	dim.color = SCREEN_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var root_panel: PanelContainer = PanelContainer.new()
	root_panel.custom_minimum_size = Vector2(1040, 560)
	root_panel.add_theme_stylebox_override("panel", _create_style(PANEL_COLOR, Color(0.58, 0.62, 0.66, 0.95), 1, 8))
	center.add_child(root_panel)

	var outer_margin: MarginContainer = _create_margin(24, 18, 24, 18)
	root_panel.add_child(outer_margin)

	var main_box: VBoxContainer = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 12)
	outer_margin.add_child(main_box)

	var title: Label = Label.new()
	title.text = "Skills"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	main_box.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Select a reserve skill, choose a slot, then equip or swap."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.78, 0.80, 0.83)
	main_box.add_child(subtitle)

	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	main_box.add_child(content)

	content.add_child(_build_equipped_column())
	content.add_child(_build_reserve_column())
	content.add_child(_build_details_column())

	var footer_margin: MarginContainer = MarginContainer.new()
	footer_margin.custom_minimum_size = Vector2(0, 58)
	footer_margin.add_theme_constant_override("margin_top", 12)
	main_box.add_child(footer_margin)

	var footer: CenterContainer = CenterContainer.new()
	footer_margin.add_child(footer)

	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(180, 38)
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
	footer.add_child(close_button)


func _build_equipped_column() -> PanelContainer:
	var panel: PanelContainer = _create_section_panel(Vector2(300, 0))
	var margin: MarginContainer = _create_margin(14, 12, 14, 12)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	box.add_child(_create_section_title("Equipped Skills"))

	_equipped_list = VBoxContainer.new()
	_equipped_list.add_theme_constant_override("separation", 8)
	box.add_child(_equipped_list)
	return panel


func _build_reserve_column() -> PanelContainer:
	var panel: PanelContainer = _create_section_panel(Vector2(310, 0))
	var margin: MarginContainer = _create_margin(14, 12, 14, 12)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_reserve_title = _create_section_title("All Skills")
	box.add_child(_reserve_title)

	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	box.add_child(filter_row)

	_relevant_button = Button.new()
	_relevant_button.custom_minimum_size = Vector2(116, 32)
	_relevant_button.text = "Relevant"
	_relevant_button.pressed.connect(_on_relevant_filter_pressed)
	filter_row.add_child(_relevant_button)

	_all_skills_button = Button.new()
	_all_skills_button.custom_minimum_size = Vector2(116, 32)
	_all_skills_button.text = "All Skills"
	_all_skills_button.pressed.connect(_on_all_skills_filter_pressed)
	filter_row.add_child(_all_skills_button)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_reserve_list = VBoxContainer.new()
	_reserve_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reserve_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_reserve_list)
	return panel


func _build_details_column() -> PanelContainer:
	var panel: PanelContainer = _create_section_panel(Vector2(380, 0))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin: MarginContainer = _create_margin(16, 14, 16, 14)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	box.add_child(_create_section_title("Details"))

	_details_label = RichTextLabel.new()
	_details_label.bbcode_enabled = true
	_details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details_label.custom_minimum_size = Vector2(0, 310)
	box.add_child(_details_label)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	box.add_child(action_row)

	_equip_button = Button.new()
	_equip_button.custom_minimum_size = Vector2(132, 38)
	_equip_button.text = "Equip"
	_equip_button.pressed.connect(_on_equip_pressed)
	action_row.add_child(_equip_button)

	_unequip_button = Button.new()
	_unequip_button.custom_minimum_size = Vector2(132, 38)
	_unequip_button.text = "Unequip"
	_unequip_button.pressed.connect(_on_unequip_pressed)
	action_row.add_child(_unequip_button)
	return panel


func _render_equipped_slots() -> void:
	_clear_children(_equipped_list)
	var equipped: Array[SkillData] = _loadout.get_equipped_skills()

	for slot_index in range(SkillLoadout.MAX_ACTIVE_SKILLS):
		var skill: SkillData = equipped[slot_index]
		var row_text: String = "Slot %d\n%s" % [slot_index + 1, skill.skill_name if skill != null else "Empty"]
		var button: Button = _create_row_button(row_text)
		button.pressed.connect(_select_slot.bind(slot_index, button))
		_equipped_list.add_child(button)

		if _selected_slot_index == slot_index:
			_select_button(button)

		if _target_slot_index == slot_index:
			_select_target_slot_button(button)


func _render_reserve_skills() -> void:
	_clear_children(_reserve_list)
	_update_reserve_filter_ui()
	var reserve: Array[SkillData] = _loadout.get_reserve_skills()

	if reserve.is_empty():
		var empty: Label = Label.new()
		empty.text = "No reserve skills"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(0, 120)
		empty.modulate = Color(0.66, 0.68, 0.7)
		_reserve_list.add_child(empty)
		return

	for index in range(reserve.size()):
		var skill: SkillData = reserve[index]
		var button: Button = _create_row_button("%s\nCooldown %d" % [skill.skill_name, skill.cooldown_turns])
		button.pressed.connect(_select_reserve.bind(index, button))
		_reserve_list.add_child(button)

		if _selected_reserve_index == index:
			_select_button(button)


func _render_details() -> void:
	if _selected_skill == null:
		if _target_slot_index >= 0:
			_details_label.text = "[font_size=20][b]Slot %d[/b][/font_size]\n\n[color=%s]Choose a reserve skill to equip here.[/color]" % [
				_target_slot_index + 1,
				MUTED_COLOR
			]
		else:
			_details_label.text = "[font_size=20][b]Select a skill[/b][/font_size]\n\n[color=%s]Choose an equipped or reserve skill to inspect it.[/color]" % MUTED_COLOR
		return

	var lines: Array[String] = [
		"[font_size=22][b]%s[/b][/font_size]" % _selected_skill.skill_name,
		"[color=%s]Target: %s[/color]" % [MUTED_COLOR, _get_target_text(_selected_skill.target_type)],
		"[color=%s]Cooldown: %d turn(s)[/color]" % [NEUTRAL_COLOR, _selected_skill.cooldown_turns],
		"",
		_selected_skill.description if _selected_skill.description != "" else "No description yet.",
		"",
		_get_selection_hint(),
	]
	_details_label.text = "\n".join(lines)


func _update_action_buttons() -> void:
	_equip_button.visible = _selected_reserve_index >= 0
	_equip_button.disabled = _selected_reserve_index < 0 or _target_slot_index < 0
	_unequip_button.visible = _selected_slot_index >= 0 and _selected_skill != null
	_unequip_button.disabled = _selected_slot_index < 0 or _selected_skill == null


func _select_slot(slot_index: int, button: Button) -> void:
	var equipped: Array[SkillData] = _loadout.get_equipped_skills()
	_target_slot_index = slot_index
	_select_target_slot_button(button)
	_render_reserve_skills()

	if _selected_reserve_index >= 0:
		_render_details()
		_update_action_buttons()
		return

	_selected_slot_index = slot_index
	_selected_skill = equipped[slot_index]
	_select_button(button)
	_render_details()
	_update_action_buttons()


func _select_reserve(reserve_index: int, button: Button) -> void:
	var reserve: Array[SkillData] = _loadout.get_reserve_skills()
	if reserve_index < 0 or reserve_index >= reserve.size():
		return

	_selected_reserve_index = reserve_index
	_selected_slot_index = -1
	_selected_skill = reserve[reserve_index]
	_select_button(button)
	_render_details()
	_update_action_buttons()


func _clear_selection() -> void:
	_selected_skill = null
	_selected_reserve_index = -1
	_selected_slot_index = -1
	_target_slot_index = -1
	_selected_button = null
	_target_slot_button = null
	_show_all_reserve = false


func _select_button(button: Button) -> void:
	if _selected_button != null and is_instance_valid(_selected_button) and _selected_button != _target_slot_button:
		_apply_row_style(_selected_button, ROW_NORMAL, ROW_BORDER, 1)

	_selected_button = button

	if _selected_button != null:
		_apply_row_style(_selected_button, ROW_SELECTED, ROW_SELECTED_BORDER, 2)


func _select_target_slot_button(button: Button) -> void:
	if _target_slot_button != null and is_instance_valid(_target_slot_button) and _target_slot_button != _selected_button:
		_apply_row_style(_target_slot_button, ROW_NORMAL, ROW_BORDER, 1)

	_target_slot_button = button

	if _target_slot_button != null:
		_apply_row_style(_target_slot_button, ROW_SELECTED, ROW_SELECTED_BORDER, 2)


func _on_equip_pressed() -> void:
	if _selected_reserve_index < 0 or _target_slot_index < 0:
		return

	equip_reserve_requested.emit(_selected_reserve_index, _target_slot_index)


func _on_relevant_filter_pressed() -> void:
	_show_all_reserve = false
	_selected_reserve_index = -1
	_render_reserve_skills()
	_render_details()
	_update_action_buttons()


func _on_all_skills_filter_pressed() -> void:
	_show_all_reserve = true
	_selected_reserve_index = -1
	_render_reserve_skills()
	_render_details()
	_update_action_buttons()


func _update_reserve_filter_ui() -> void:
	if _reserve_title != null:
		_reserve_title.text = _get_reserve_title_text()

	if _relevant_button != null:
		_relevant_button.disabled = _target_slot_index < 0 or not _show_all_reserve

	if _all_skills_button != null:
		_all_skills_button.disabled = _show_all_reserve


func _get_reserve_title_text() -> String:
	if _show_all_reserve or _target_slot_index < 0:
		return "All Skills"

	return "Skills for Slot %d" % [_target_slot_index + 1]


func _on_unequip_pressed() -> void:
	if _selected_slot_index < 0:
		return

	unequip_slot_requested.emit(_selected_slot_index)


func _on_close_pressed() -> void:
	hide()
	closed.emit()


func _get_selection_hint() -> String:
	if _selected_reserve_index >= 0 and _target_slot_index < 0:
		return "[color=%s]Select a slot on the left to equip this skill.[/color]" % MUTED_COLOR

	if _selected_reserve_index >= 0:
		return "[color=%s]Ready to equip into slot %d. Occupied slots will swap.[/color]" % [NEUTRAL_COLOR, _target_slot_index + 1]

	if _selected_slot_index >= 0:
		return "[color=%s]Currently equipped in slot %d.[/color]" % [NEUTRAL_COLOR, _selected_slot_index + 1]

	return ""


func _get_target_text(target_type) -> String:
	match target_type:
		SkillData.TargetType.SELF:
			return "Self"
		SkillData.TargetType.ENEMY:
			return "Enemy"
		_:
			return "Unknown"


func _create_section_panel(minimum_size: Vector2) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _create_style(SECTION_COLOR, SECTION_BORDER, 1, 8))
	return panel


func _create_section_title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	return label


func _create_row_button(text: String) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_row_style(button, ROW_NORMAL, ROW_BORDER, 1)
	button.mouse_entered.connect(_on_row_hovered.bind(button, true))
	button.mouse_exited.connect(_on_row_hovered.bind(button, false))
	return button


func _on_row_hovered(button: Button, hovered: bool) -> void:
	if button == _selected_button or button == _target_slot_button:
		return

	if hovered:
		_apply_row_style(button, ROW_HOVER, ROW_BORDER, 1)
	else:
		_apply_row_style(button, ROW_NORMAL, ROW_BORDER, 1)


func _apply_row_style(button: Button, background_color: Color, border_color: Color, border_width: int) -> void:
	button.add_theme_stylebox_override("normal", _create_style(background_color, border_color, border_width, 6))
	button.add_theme_stylebox_override("hover", _create_style(ROW_HOVER, border_color, border_width, 6))
	button.add_theme_stylebox_override("pressed", _create_style(ROW_SELECTED, ROW_SELECTED_BORDER, 2, 6))


func _create_style(background_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin(SIDE_LEFT, 10)
	style.set_content_margin(SIDE_RIGHT, 10)
	style.set_content_margin(SIDE_TOP, 8)
	style.set_content_margin(SIDE_BOTTOM, 8)
	return style


func _create_margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
