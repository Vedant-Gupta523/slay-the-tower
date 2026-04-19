class_name BaseEquipmentPage
extends Control

signal inventory_changed

const GOOD_COLOR := "#7ee787"
const BAD_COLOR := "#ff7b72"
const MUTED_COLOR := "#8b949e"
const NEUTRAL_COLOR := "#c9d1d9"
const PANEL_COLOR := Color(0.095, 0.10, 0.11, 1.0)
const PANEL_BORDER := Color(0.34, 0.36, 0.38, 0.9)
const ROW_NORMAL := Color(0.13, 0.135, 0.145, 1.0)
const ROW_HOVER := Color(0.18, 0.19, 0.20, 1.0)
const ROW_SELECTED := Color(0.23, 0.205, 0.12, 1.0)
const ROW_BORDER := Color(0.42, 0.44, 0.46, 0.55)

var _equipped_list: VBoxContainer
var _reserve_list: VBoxContainer
var _details_label: RichTextLabel
var _summary_label: RichTextLabel
var _equip_button: Button
var _unequip_button: Button
var _status_label: Label

var _selected_item: EquipmentData
var _selected_reserve_index: int = -1
var _selected_slot_type: int = -1
var _selected_from_equipped: bool = false
var _selected_button: Button


func _ready() -> void:
	_build_ui()
	_connect_state()
	refresh()


func refresh() -> void:
	_render_equipped()
	_render_inventory()
	_render_summary()
	_render_details()
	_update_actions()


func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title: Label = Label.new()
	title.text = "Equipment"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.modulate = Color(0.88, 0.84, 0.68)
	header.add_child(_status_label)

	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	root.add_child(content)

	content.add_child(_build_equipped_column())
	content.add_child(_build_inventory_column())
	content.add_child(_build_details_column())


func _build_equipped_column() -> PanelContainer:
	var panel: PanelContainer = _create_section_panel(Vector2(190, 0))
	var box: VBoxContainer = _create_section_box(panel)
	box.add_child(_create_section_title("Equipped"))

	_equipped_list = _create_list()
	box.add_child(_equipped_list)

	box.add_child(_create_section_title("Gear Bonuses"))
	_summary_label = _create_detail_label()
	_summary_label.custom_minimum_size = Vector2(0, 150)
	box.add_child(_summary_label)
	return panel


func _build_inventory_column() -> PanelContainer:
	var panel: PanelContainer = _create_section_panel(Vector2(220, 0))
	var box: VBoxContainer = _create_section_box(panel)
	box.add_child(_create_section_title("Owned Equipment"))

	_reserve_list = _create_list()
	box.add_child(_wrap_scroll(_reserve_list))
	return panel


func _build_details_column() -> PanelContainer:
	var panel: PanelContainer = _create_section_panel(Vector2(260, 0))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = _create_section_box(panel)
	box.add_child(_create_section_title("Details"))

	_details_label = _create_detail_label()
	box.add_child(_details_label)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	box.add_child(action_row)

	_equip_button = Button.new()
	_equip_button.custom_minimum_size = Vector2(130, 38)
	_equip_button.text = "Equip"
	_equip_button.pressed.connect(_on_equip_pressed)
	action_row.add_child(_equip_button)

	_unequip_button = Button.new()
	_unequip_button.custom_minimum_size = Vector2(130, 38)
	_unequip_button.text = "Unequip"
	_unequip_button.pressed.connect(_on_unequip_pressed)
	action_row.add_child(_unequip_button)
	return panel


func _render_equipped() -> void:
	_clear_children(_equipped_list)
	_add_equipped_slot(EquipmentData.SlotType.WEAPON, "Weapon")
	_add_equipped_slot(EquipmentData.SlotType.ARMOR, "Armor")
	_add_equipped_slot(EquipmentData.SlotType.ACCESSORY, "Accessory")


func _add_equipped_slot(slot_type: int, slot_name: String) -> void:
	var item: EquipmentData = ExpeditionState.equipped_gear.get(slot_type, null) as EquipmentData
	var item_name: String = item.get_display_name() if item != null else "Empty"
	var button: Button = _create_item_button(item, "%s\n%s" % [slot_name, item_name])
	button.pressed.connect(_select_equipped.bind(slot_type, button))
	_equipped_list.add_child(button)

	if _selected_from_equipped and _selected_slot_type == slot_type:
		_select_button(button)


func _render_inventory() -> void:
	_clear_children(_reserve_list)

	if ExpeditionState.inventory.is_empty():
		_add_empty_label(_reserve_list, "No reserve equipment")
		return

	for index in range(ExpeditionState.inventory.size()):
		var item: EquipmentData = ExpeditionState.inventory[index]
		var button: Button = _create_item_button(item, "%s\n%s" % [item.get_display_name(), item.get_slot_name()])
		button.pressed.connect(_select_reserve.bind(index, button))
		_reserve_list.add_child(button)

		if not _selected_from_equipped and _selected_reserve_index == index:
			_select_button(button)


func _render_summary() -> void:
	var max_hp: int = 0
	var atk: int = 0
	var def: int = 0
	var spd: int = 0

	for item in ExpeditionState.equipped_gear.values():
		var equipment: EquipmentData = item as EquipmentData
		if equipment == null:
			continue

		max_hp += equipment.get_max_hp_bonus()
		atk += equipment.get_atk_bonus()
		def += equipment.get_def_bonus()
		spd += equipment.get_spd_bonus()

	_summary_label.text = "\n".join([
		"[color=%s]Max HP[/color] %s" % [NEUTRAL_COLOR, _format_signed(max_hp)],
		"[color=%s]ATK[/color] %s" % [NEUTRAL_COLOR, _format_signed(atk)],
		"[color=%s]DEF[/color] %s" % [NEUTRAL_COLOR, _format_signed(def)],
		"[color=%s]SPD[/color] %s" % [NEUTRAL_COLOR, _format_signed(spd)],
	])


func _render_details() -> void:
	if _selected_item == null:
		_details_label.text = "[font_size=20][b]Select equipment[/b][/font_size]\n\n[color=%s]Choose equipped gear or a reserve item to inspect it.[/color]" % MUTED_COLOR
		return

	var lines: Array[String] = [
		"[font_size=22][color=%s][b]%s[/b][/color][/font_size]" % [_selected_item.get_rarity_color().to_html(false), _selected_item.get_display_name()],
		"[color=%s]%s %s[/color]" % [MUTED_COLOR, _selected_item.get_rarity_name(), _selected_item.get_slot_name()],
		"",
		_selected_item.description,
		"",
		"[b]Bonuses[/b]",
		"[color=%s]%s[/color]" % [GOOD_COLOR, _selected_item.get_bonus_summary()],
		"",
		"[b]Comparison[/b]",
		_get_comparison_text(_selected_item),
	]
	_details_label.text = "\n".join(lines)


func _select_equipped(slot_type: int, button: Button) -> void:
	_selected_slot_type = slot_type
	_selected_reserve_index = -1
	_selected_from_equipped = true
	_selected_item = ExpeditionState.equipped_gear.get(slot_type, null) as EquipmentData
	_status_label.text = ""
	_select_button(button)
	_render_details()
	_update_actions()


func _select_reserve(reserve_index: int, button: Button) -> void:
	if reserve_index < 0 or reserve_index >= ExpeditionState.inventory.size():
		return

	_selected_reserve_index = reserve_index
	_selected_from_equipped = false
	_selected_item = ExpeditionState.inventory[reserve_index]
	_selected_slot_type = _selected_item.slot_type
	_status_label.text = ""
	_select_button(button)
	_render_details()
	_update_actions()


func _on_equip_pressed() -> void:
	if _selected_reserve_index < 0 or _selected_item == null:
		return

	if ExpeditionState.equip_inventory_item(_selected_reserve_index, _selected_item.slot_type):
		_status_label.text = "Equipped %s." % _selected_item.get_display_name()
		_clear_selection()
		inventory_changed.emit()
		refresh()


func _on_unequip_pressed() -> void:
	if not _selected_from_equipped or _selected_slot_type < 0:
		return

	if ExpeditionState.unequip_gear_slot(_selected_slot_type):
		_status_label.text = "Moved equipment to reserve."
		_clear_selection()
		inventory_changed.emit()
		refresh()


func _update_actions() -> void:
	_equip_button.visible = not _selected_from_equipped and _selected_item != null
	_equip_button.disabled = _selected_reserve_index < 0
	_unequip_button.visible = _selected_from_equipped and _selected_item != null
	_unequip_button.disabled = not _selected_from_equipped or _selected_item == null


func _clear_selection() -> void:
	_selected_item = null
	_selected_reserve_index = -1
	_selected_slot_type = -1
	_selected_from_equipped = false
	_selected_button = null


func _get_comparison_text(item: EquipmentData) -> String:
	if _selected_from_equipped:
		return "[color=%s]Currently equipped. Unequipping changes:[/color]\n%s" % [
			MUTED_COLOR,
			_get_stat_diff_text(null, item)
		]

	var current_item: EquipmentData = ExpeditionState.equipped_gear.get(item.slot_type, null) as EquipmentData
	if current_item == null:
		return "[color=%s]Compared to empty %s slot[/color]\n%s" % [
			MUTED_COLOR,
			item.get_slot_name(),
			_get_stat_diff_text(item, null)
		]

	return "[color=%s]Compared to [/color][color=%s]%s[/color]\n%s" % [
		MUTED_COLOR,
		current_item.get_rarity_color().to_html(false),
		current_item.get_display_name(),
		_get_stat_diff_text(item, current_item)
	]


func _get_stat_diff_text(next_item: EquipmentData, current_item: EquipmentData) -> String:
	var lines: Array[String] = []
	_append_stat_diff(lines, "Max HP", _get_bonus(next_item, "max_hp_bonus") - _get_bonus(current_item, "max_hp_bonus"))
	_append_stat_diff(lines, "ATK", _get_bonus(next_item, "atk_bonus") - _get_bonus(current_item, "atk_bonus"))
	_append_stat_diff(lines, "DEF", _get_bonus(next_item, "def_bonus") - _get_bonus(current_item, "def_bonus"))
	_append_stat_diff(lines, "SPD", _get_bonus(next_item, "spd_bonus") - _get_bonus(current_item, "spd_bonus"))
	return "\n".join(lines)


func _append_stat_diff(lines: Array[String], stat_name: String, value: int) -> void:
	var color: String = NEUTRAL_COLOR
	if value > 0:
		color = GOOD_COLOR
	elif value < 0:
		color = BAD_COLOR

	lines.append("[color=%s]%s: %s[/color]" % [color, stat_name, _format_signed(value)])


func _format_signed(value: int) -> String:
	if value > 0:
		return "+%d" % value

	return "%d" % value


func _get_bonus(item: EquipmentData, property_name: String) -> int:
	if item == null:
		return 0

	return item.get_stat_bonus(property_name)


func _connect_state() -> void:
	if not ExpeditionState.expedition_state_changed.is_connected(_on_state_changed):
		ExpeditionState.expedition_state_changed.connect(_on_state_changed)


func _on_state_changed() -> void:
	if is_inside_tree():
		refresh()


func _select_button(button: Button) -> void:
	if _selected_button != null and is_instance_valid(_selected_button):
		_apply_row_style(_selected_button, ROW_NORMAL, _get_button_border_color(_selected_button), 1)

	_selected_button = button
	if _selected_button != null:
		_apply_row_style(_selected_button, ROW_SELECTED, _get_button_border_color(_selected_button), 2)


func _create_section_panel(minimum_size: Vector2) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _create_style(PANEL_COLOR, PANEL_BORDER, 1, 8))
	return panel


func _create_section_box(panel: PanelContainer) -> VBoxContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	return box


func _create_section_title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	return label


func _create_detail_label() -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.scroll_active = true
	return label


func _create_list() -> VBoxContainer:
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 7)
	return list


func _wrap_scroll(list: VBoxContainer) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(list)
	return scroll


func _create_item_button(item: EquipmentData, text: String) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0, 54)
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

	var background: Color = ROW_HOVER if hovered else ROW_NORMAL
	_apply_row_style(button, background, _get_button_border_color(button), 1)


func _apply_row_style(button: Button, background_color: Color, border_color: Color, border_width: int) -> void:
	button.add_theme_stylebox_override("normal", _create_style(background_color, border_color, border_width, 6))
	button.add_theme_stylebox_override("hover", _create_style(ROW_HOVER, border_color, border_width, 6))
	button.add_theme_stylebox_override("pressed", _create_style(ROW_SELECTED, border_color, 2, 6))


func _get_button_border_color(button: Button) -> Color:
	return button.get_meta("rarity_border_color", ROW_BORDER) as Color


func _add_empty_label(parent: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 90)
	label.modulate = Color(0.66, 0.68, 0.7)
	parent.add_child(label)


func _create_style(background_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin(SIDE_LEFT, 10)
	style.set_content_margin(SIDE_RIGHT, 10)
	style.set_content_margin(SIDE_TOP, 7)
	style.set_content_margin(SIDE_BOTTOM, 7)
	return style


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
