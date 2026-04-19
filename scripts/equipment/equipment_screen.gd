class_name EquipmentScreen
extends Control

signal equip_reserve_requested(reserve_index: int, slot_type: int)
signal unequip_slot_requested(slot_type: int)
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
const GOOD_COLOR := "#7ee787"
const BAD_COLOR := "#ff7b72"
const NEUTRAL_COLOR := "#c9d1d9"
const MUTED_COLOR := "#8b949e"

var _player: BattleUnit
var _selected_item: EquipmentData
var _selected_reserve_index := -1
var _selected_equipped_slot := -1
var _target_slot_type := -1
var _selected_button: Button
var _show_all_reserve := false

var _root_panel: PanelContainer
var _equipped_list: VBoxContainer
var _reserve_title: Label
var _relevant_button: Button
var _all_items_button: Button
var _reserve_list: VBoxContainer
var _details_label: RichTextLabel
var _stats_label: RichTextLabel
var _equip_button: Button
var _unequip_button: Button


func _ready() -> void:
	_build_ui()
	hide()


func show_for_player(player: BattleUnit) -> void:
	_player = player
	_clear_selection()
	refresh()
	show()


func refresh() -> void:
	if _player == null:
		return

	_render_equipped_slots()
	_render_reserve_inventory()
	_render_stats()
	_render_details()
	_update_action_buttons()


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = SCREEN_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_root_panel = PanelContainer.new()
	_root_panel.custom_minimum_size = Vector2(1040, 560)
	_root_panel.add_theme_stylebox_override("panel", _create_style(PANEL_COLOR, Color(0.58, 0.62, 0.66, 0.95), 1, 8))
	center.add_child(_root_panel)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 24)
	outer_margin.add_theme_constant_override("margin_top", 18)
	outer_margin.add_theme_constant_override("margin_right", 24)
	outer_margin.add_theme_constant_override("margin_bottom", 18)
	_root_panel.add_child(outer_margin)

	var main_box := VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 12)
	outer_margin.add_child(main_box)

	var title := Label.new()
	title.text = "Equipment"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	main_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose gear, compare stats, then equip or unequip."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.78, 0.80, 0.83)
	main_box.add_child(subtitle)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	main_box.add_child(content)

	content.add_child(_build_equipped_column())
	content.add_child(_build_reserve_column())
	content.add_child(_build_details_column())

	var footer_margin := MarginContainer.new()
	footer_margin.custom_minimum_size = Vector2(0, 74)
	footer_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_margin.add_theme_constant_override("margin_top", 12)
	footer_margin.add_theme_constant_override("margin_bottom", 18)
	main_box.add_child(footer_margin)

	var footer := CenterContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	footer_margin.add_child(footer)

	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(180, 38)
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
	footer.add_child(close_button)


func _build_equipped_column() -> PanelContainer:
	var panel := _create_section_panel(Vector2(300, 0))
	var margin := _create_margin(14, 12, 14, 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	box.add_child(_create_section_title("Equipped"))

	_equipped_list = VBoxContainer.new()
	_equipped_list.add_theme_constant_override("separation", 8)
	box.add_child(_equipped_list)

	box.add_child(_create_section_title("Player Stats"))

	_stats_label = RichTextLabel.new()
	_stats_label.bbcode_enabled = true
	_stats_label.fit_content = true
	_stats_label.scroll_active = false
	_stats_label.custom_minimum_size = Vector2(0, 150)
	box.add_child(_stats_label)

	return panel


func _build_reserve_column() -> PanelContainer:
	var panel := _create_section_panel(Vector2(310, 0))
	var margin := _create_margin(14, 12, 14, 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_reserve_title = _create_section_title("All Equipment")
	box.add_child(_reserve_title)

	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	box.add_child(filter_row)

	_relevant_button = Button.new()
	_relevant_button.custom_minimum_size = Vector2(116, 32)
	_relevant_button.text = "Relevant"
	_relevant_button.pressed.connect(_on_relevant_filter_pressed)
	filter_row.add_child(_relevant_button)

	_all_items_button = Button.new()
	_all_items_button.custom_minimum_size = Vector2(116, 32)
	_all_items_button.text = "All Items"
	_all_items_button.pressed.connect(_on_all_items_filter_pressed)
	filter_row.add_child(_all_items_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_reserve_list = VBoxContainer.new()
	_reserve_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reserve_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_reserve_list)

	return panel


func _build_details_column() -> PanelContainer:
	var panel := _create_section_panel(Vector2(380, 0))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := _create_margin(16, 14, 16, 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	box.add_child(_create_section_title("Details"))

	_details_label = RichTextLabel.new()
	_details_label.bbcode_enabled = true
	_details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details_label.custom_minimum_size = Vector2(0, 310)
	box.add_child(_details_label)

	var action_row := HBoxContainer.new()
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
	_add_equipped_slot(EquipmentData.SlotType.WEAPON, "Weapon")
	_add_equipped_slot(EquipmentData.SlotType.ARMOR, "Armor")
	_add_equipped_slot(EquipmentData.SlotType.ACCESSORY, "Accessory")


func _add_equipped_slot(slot_type: int, slot_name: String) -> void:
	var item := _player.get_equipped_item(slot_type)
	var row_text := "%s\n%s" % [slot_name, item.item_name if item != null else "Empty"]
	var button := _create_row_button(row_text, item)
	button.pressed.connect(_select_equipped.bind(slot_type, button))
	_equipped_list.add_child(button)

	if _selected_equipped_slot == slot_type:
		_select_button(button)


func _render_reserve_inventory() -> void:
	_clear_children(_reserve_list)
	_update_reserve_filter_ui()
	var reserve: Array[EquipmentData] = _player.get_reserve_inventory()
	var visible_count: int = 0

	if reserve.is_empty():
		_add_empty_reserve_label("No reserve equipment")
		return

	for index in range(reserve.size()):
		var item: EquipmentData = reserve[index]
		if not _should_show_reserve_item(item):
			continue

		var is_valid_for_slot: bool = _is_item_valid_for_selected_slot(item)
		var row_text: String = "%s\n%s" % [item.item_name, item.get_slot_name()]
		if not is_valid_for_slot:
			row_text = "%s\nNot valid for %s" % [item.item_name, _get_slot_name(_target_slot_type)]

		var button := _create_row_button(row_text, item)
		if not is_valid_for_slot:
			button.modulate = Color(0.68, 0.68, 0.68)
		button.pressed.connect(_select_reserve.bind(index, button))
		_reserve_list.add_child(button)
		visible_count += 1

		if _selected_reserve_index == index:
			_select_button(button)

	if visible_count == 0:
		_add_empty_reserve_label("No %s in reserve" % _get_reserve_title_text().to_lower())


func _render_stats() -> void:
	var lines: Array[String] = [
		"[color=%s]HP[/color] %d/%d" % [NEUTRAL_COLOR, _player.get_current_hp(), _player.get_max_hp()],
		"[color=%s]ATK[/color] %d" % [NEUTRAL_COLOR, _player.get_atk()],
		"[color=%s]DEF[/color] %d" % [NEUTRAL_COLOR, _player.get_def()],
		"[color=%s]SPD[/color] %d" % [NEUTRAL_COLOR, _player.get_spd()],
	]
	_stats_label.text = "\n".join(lines)


func _render_details() -> void:
	if _selected_item == null:
		if _target_slot_type >= 0:
			_details_label.text = "[font_size=20][b]%s[/b][/font_size]\n\n[color=%s]Empty slot[/color]" % [
				_get_slot_name(_target_slot_type),
				MUTED_COLOR
			]
		else:
			_details_label.text = "[font_size=20][b]Select equipment[/b][/font_size]\n\n[color=%s]Choose an equipped item or reserve item to inspect its stats.[/color]" % MUTED_COLOR
		return

	var lines: Array[String] = [
		"[font_size=22][color=%s][b]%s[/b][/color][/font_size]" % [_selected_item.get_rarity_color().to_html(false), _selected_item.item_name],
		"[color=%s]%s %s[/color]" % [MUTED_COLOR, _selected_item.get_rarity_name(), _selected_item.get_slot_name()],
		"",
		_selected_item.description,
		"",
		"[b]Bonuses[/b]",
		_format_bonus_block(_selected_item),
		"",
		"[b]Comparison[/b]",
		_get_comparison_block(_selected_item),
	]
	_details_label.text = "\n".join(lines)


func _update_action_buttons() -> void:
	var can_equip: bool = _can_equip_selected_reserve_item()
	_equip_button.visible = _selected_reserve_index >= 0
	_equip_button.disabled = not can_equip
	_unequip_button.visible = _selected_equipped_slot >= 0 and _selected_item != null
	_unequip_button.disabled = _selected_equipped_slot < 0 or _selected_item == null


func _select_equipped(slot_type: int, button: Button) -> void:
	_selected_equipped_slot = slot_type
	_target_slot_type = slot_type
	_selected_reserve_index = -1
	_selected_item = _player.get_equipped_item(slot_type)
	_select_button(button)
	_render_reserve_inventory()
	_render_details()
	_update_action_buttons()


func _select_reserve(reserve_index: int, button: Button) -> void:
	var reserve: Array[EquipmentData] = _player.get_reserve_inventory()
	if reserve_index < 0 or reserve_index >= reserve.size():
		return

	_selected_reserve_index = reserve_index
	_selected_equipped_slot = -1
	_selected_item = reserve[reserve_index]
	_select_button(button)
	_render_details()
	_update_action_buttons()


func _clear_selection() -> void:
	_selected_item = null
	_selected_reserve_index = -1
	_selected_equipped_slot = -1
	_target_slot_type = -1
	_selected_button = null
	_show_all_reserve = false


func _select_button(button: Button) -> void:
	if _selected_button != null and is_instance_valid(_selected_button):
		_apply_row_style(_selected_button, ROW_NORMAL, _get_button_border_color(_selected_button), 1)

	_selected_button = button

	if _selected_button != null:
		_apply_row_style(_selected_button, ROW_SELECTED, _get_button_border_color(_selected_button), 2)


func _on_equip_pressed() -> void:
	if not _can_equip_selected_reserve_item():
		return

	equip_reserve_requested.emit(_selected_reserve_index, _target_slot_type)


func _on_relevant_filter_pressed() -> void:
	_show_all_reserve = false
	_selected_reserve_index = -1
	if _target_slot_type < 0:
		_selected_item = null
	_render_reserve_inventory()
	_render_details()
	_update_action_buttons()


func _on_all_items_filter_pressed() -> void:
	_show_all_reserve = true
	_selected_reserve_index = -1
	if _target_slot_type < 0:
		_selected_item = null
	_render_reserve_inventory()
	_render_details()
	_update_action_buttons()


func _should_show_reserve_item(item: EquipmentData) -> bool:
	return _show_all_reserve or _target_slot_type < 0 or item.slot_type == _target_slot_type


func _is_item_valid_for_selected_slot(item: EquipmentData) -> bool:
	return _target_slot_type < 0 or item.slot_type == _target_slot_type


func _can_equip_selected_reserve_item() -> bool:
	if _selected_reserve_index < 0 or _target_slot_type < 0:
		return false

	var reserve: Array[EquipmentData] = _player.get_reserve_inventory()
	if _selected_reserve_index >= reserve.size():
		return false

	return reserve[_selected_reserve_index].slot_type == _target_slot_type


func _update_reserve_filter_ui() -> void:
	if _reserve_title != null:
		_reserve_title.text = _get_reserve_title_text()

	if _relevant_button != null:
		_relevant_button.disabled = _target_slot_type < 0 or not _show_all_reserve

	if _all_items_button != null:
		_all_items_button.disabled = _show_all_reserve


func _get_reserve_title_text() -> String:
	if _show_all_reserve or _target_slot_type < 0:
		return "All Equipment"

	match _target_slot_type:
		EquipmentData.SlotType.WEAPON:
			return "Weapons"
		EquipmentData.SlotType.ARMOR:
			return "Armor"
		EquipmentData.SlotType.ACCESSORY:
			return "Accessories"
		_:
			return "Reserve"


func _add_empty_reserve_label(text: String) -> void:
	var empty: Label = Label.new()
	empty.text = text
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty.custom_minimum_size = Vector2(0, 120)
	empty.modulate = Color(0.66, 0.68, 0.7)
	_reserve_list.add_child(empty)


func _on_unequip_pressed() -> void:
	if _selected_equipped_slot < 0:
		return

	unequip_slot_requested.emit(_selected_equipped_slot)


func _on_close_pressed() -> void:
	hide()
	closed.emit()


func _format_bonus_block(item: EquipmentData) -> String:
	var bonuses := item.get_bonus_lines()
	if bonuses.is_empty():
		return "[color=%s]No stat bonuses[/color]" % MUTED_COLOR

	return "[color=%s]%s[/color]" % [GOOD_COLOR, "\n".join(bonuses)]


func _get_comparison_block(item: EquipmentData) -> String:
	if _selected_equipped_slot >= 0:
		return _get_unequip_comparison_block(item)

	if _target_slot_type >= 0 and item.slot_type != _target_slot_type:
		return "[color=%s]Cannot equip %s into the %s slot.[/color]" % [
			BAD_COLOR,
			item.get_slot_name(),
			_get_slot_name(_target_slot_type)
		]

	var current_item := _player.get_equipped_item(item.slot_type)
	if current_item == item:
		return "[color=%s]Already equipped.[/color]" % NEUTRAL_COLOR

	var lines: Array[String] = []
	if current_item == null:
		lines.append("[color=%s]Compared to empty %s slot[/color]" % [MUTED_COLOR, item.get_slot_name()])
	else:
		lines.append("[color=%s]Compared to [/color][color=%s]%s[/color]" % [
			MUTED_COLOR,
			current_item.get_rarity_color().to_html(false),
			current_item.item_name
		])

	_append_stat_diff(lines, "Max HP", item.get_max_hp_bonus() - _get_item_bonus(current_item, "max_hp_bonus"))
	_append_stat_diff(lines, "ATK", item.get_atk_bonus() - _get_item_bonus(current_item, "atk_bonus"))
	_append_stat_diff(lines, "DEF", item.get_def_bonus() - _get_item_bonus(current_item, "def_bonus"))
	_append_stat_diff(lines, "SPD", item.get_spd_bonus() - _get_item_bonus(current_item, "spd_bonus"))
	return "\n".join(lines)


func _get_unequip_comparison_block(item: EquipmentData) -> String:
	var lines: Array[String] = [
		"[color=%s]Currently equipped. Unequipping changes:[/color]" % MUTED_COLOR
	]
	_append_stat_diff(lines, "Max HP", -item.get_max_hp_bonus())
	_append_stat_diff(lines, "ATK", -item.get_atk_bonus())
	_append_stat_diff(lines, "DEF", -item.get_def_bonus())
	_append_stat_diff(lines, "SPD", -item.get_spd_bonus())
	return "\n".join(lines)


func _append_stat_diff(lines: Array[String], stat_name: String, value: int) -> void:
	var color := NEUTRAL_COLOR
	var sign := ""

	if value > 0:
		color = GOOD_COLOR
		sign = "+"
	elif value < 0:
		color = BAD_COLOR

	lines.append("[color=%s]%s: %s%d[/color]" % [color, stat_name, sign, value])


func _get_item_bonus(item: EquipmentData, property_name: String) -> int:
	if item == null:
		return 0

	return item.get_stat_bonus(property_name)


func _create_section_panel(minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _create_style(SECTION_COLOR, SECTION_BORDER, 1, 8))
	return panel


func _create_section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	return label


func _create_row_button(text: String, item: EquipmentData = null) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var border_color: Color = item.get_rarity_color() if item != null else ROW_BORDER
	button.set_meta("rarity_border_color", border_color)
	_apply_row_style(button, ROW_NORMAL, border_color, 1)
	button.mouse_entered.connect(_on_row_hovered.bind(button, true))
	button.mouse_exited.connect(_on_row_hovered.bind(button, false))
	return button


func _on_row_hovered(button: Button, hovered: bool) -> void:
	if button == _selected_button:
		return

	if hovered:
		_apply_row_style(button, ROW_HOVER, _get_button_border_color(button), 1)
	else:
		_apply_row_style(button, ROW_NORMAL, _get_button_border_color(button), 1)


func _apply_row_style(button: Button, background_color: Color, border_color: Color, border_width: int) -> void:
	button.add_theme_stylebox_override("normal", _create_style(background_color, border_color, border_width, 6))
	button.add_theme_stylebox_override("hover", _create_style(ROW_HOVER, border_color, border_width, 6))
	button.add_theme_stylebox_override("pressed", _create_style(ROW_SELECTED, border_color, 2, 6))


func _get_button_border_color(button: Button) -> Color:
	return button.get_meta("rarity_border_color", ROW_BORDER) as Color


func _create_style(background_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
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
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _get_slot_name(slot_type: int) -> String:
	match slot_type:
		EquipmentData.SlotType.WEAPON:
			return "Weapon"
		EquipmentData.SlotType.ARMOR:
			return "Armor"
		EquipmentData.SlotType.ACCESSORY:
			return "Accessory"
		_:
			return "Equipment"
