class_name BlacksmithPage
extends Control

signal inventory_changed

const GOOD_COLOR := "#7ee787"
const BAD_COLOR := "#ff7b72"
const MUTED_COLOR := "#8b949e"
const NEUTRAL_COLOR := "#c9d1d9"
const PANEL_COLOR := Color(0.095, 0.10, 0.11, 1.0)
const PANEL_BORDER := Color(0.34, 0.36, 0.38, 0.9)
const ROW_NORMAL := Color(0.13, 0.135, 0.145, 1.0)
const ROW_SELECTED := Color(0.22, 0.20, 0.12, 1.0)

var _gold_label: Label
var _ores_label: Label
var _tab_shop_button: Button
var _tab_sell_button: Button
var _tab_enhance_button: Button
var _status_label: Label
var _shop_tab: HBoxContainer
var _sell_tab: HBoxContainer
var _enhance_tab: HBoxContainer
var _shop_list: VBoxContainer
var _sell_list: VBoxContainer
var _enhance_list: VBoxContainer
var _shop_detail_label: RichTextLabel
var _sell_detail_label: RichTextLabel
var _enhance_detail_label: RichTextLabel
var _buy_button: Button
var _sell_button: Button
var _enhance_button: Button

var _selected_shop_index: int = -1
var _selected_shop_item: EquipmentData
var _selected_sell_index: int = -1
var _selected_sell_item: EquipmentData
var _selected_enhance_item: EquipmentData
var _last_enhance_result: Dictionary = {}
var _active_tab: StringName = &"shop"


func _ready() -> void:
	_build_ui()
	_connect_state_signals()
	show_shop_tab()
	refresh()


func refresh() -> void:
	BlacksmithState.ensure_inventory(ExpeditionState.blacksmith_refresh_counter)
	_render_summary()
	_render_shop_inventory()
	_render_sell_inventory()
	_render_enhance_inventory()
	_render_shop_details()
	_render_sell_details()
	_render_enhance_details()


func show_shop_tab() -> void:
	_active_tab = &"shop"
	if _shop_tab == null:
		return

	_shop_tab.visible = true
	_sell_tab.visible = false
	_enhance_tab.visible = false
	_apply_tab_state()
	_status_label.text = ""


func show_sell_tab() -> void:
	_active_tab = &"sell"
	if _sell_tab == null:
		return

	_shop_tab.visible = false
	_sell_tab.visible = true
	_enhance_tab.visible = false
	_apply_tab_state()
	_status_label.text = ""


func show_enhance_tab() -> void:
	_active_tab = &"enhance"
	if _enhance_tab == null:
		return

	_shop_tab.visible = false
	_sell_tab.visible = false
	_enhance_tab.visible = true
	_apply_tab_state()
	_status_label.text = ""


func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	root.add_child(top_row)

	var title := Label.new()
	title.text = "Blacksmith"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	top_row.add_child(title)

	_gold_label = _create_summary_label("Gold: 0")
	top_row.add_child(_gold_label)

	_ores_label = _create_summary_label("Ores: 0")
	top_row.add_child(_ores_label)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	root.add_child(tab_row)

	_tab_shop_button = _create_tab_button("Buy")
	_tab_shop_button.pressed.connect(show_shop_tab)
	tab_row.add_child(_tab_shop_button)

	_tab_sell_button = _create_tab_button("Sell")
	_tab_sell_button.pressed.connect(show_sell_tab)
	tab_row.add_child(_tab_sell_button)

	_tab_enhance_button = _create_tab_button("Enhance")
	_tab_enhance_button.pressed.connect(show_enhance_tab)
	tab_row.add_child(_tab_enhance_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.modulate = Color(0.88, 0.84, 0.68)
	tab_row.add_child(_status_label)

	_shop_tab = HBoxContainer.new()
	_shop_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_tab.add_theme_constant_override("separation", 10)
	root.add_child(_shop_tab)
	_build_shop_tab()

	_sell_tab = HBoxContainer.new()
	_sell_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sell_tab.add_theme_constant_override("separation", 10)
	root.add_child(_sell_tab)
	_build_sell_tab()

	_enhance_tab = HBoxContainer.new()
	_enhance_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enhance_tab.add_theme_constant_override("separation", 10)
	root.add_child(_enhance_tab)
	_build_enhance_tab()


func _build_shop_tab() -> void:
	var stock_panel := _create_section_panel(Vector2(260, 0))
	var stock_box := _create_section_box(stock_panel)
	stock_box.add_child(_create_section_title("For Sale"))
	_shop_list = _create_list()
	stock_box.add_child(_wrap_scroll(_shop_list))
	_shop_tab.add_child(stock_panel)

	var detail_panel := _create_section_panel(Vector2(340, 0))
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_box := _create_section_box(detail_panel)
	detail_box.add_child(_create_section_title("Details"))
	_shop_detail_label = _create_detail_label()
	detail_box.add_child(_shop_detail_label)

	_buy_button = Button.new()
	_buy_button.custom_minimum_size = Vector2(160, 36)
	_buy_button.text = "Buy"
	_buy_button.pressed.connect(_buy_selected_item)
	detail_box.add_child(_buy_button)
	_shop_tab.add_child(detail_panel)


func _build_sell_tab() -> void:
	var sell_panel := _create_section_panel(Vector2(300, 0))
	var sell_box := _create_section_box(sell_panel)
	sell_box.add_child(_create_section_title("Reserve Equipment"))
	_sell_list = _create_list()
	sell_box.add_child(_wrap_scroll(_sell_list))
	_sell_tab.add_child(sell_panel)

	var detail_panel := _create_section_panel(Vector2(340, 0))
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_box := _create_section_box(detail_panel)
	detail_box.add_child(_create_section_title("Sell Details"))
	_sell_detail_label = _create_detail_label()
	detail_box.add_child(_sell_detail_label)

	_sell_button = Button.new()
	_sell_button.custom_minimum_size = Vector2(160, 38)
	_sell_button.text = "Sell"
	_sell_button.pressed.connect(_sell_selected_item)
	detail_box.add_child(_sell_button)
	_sell_tab.add_child(detail_panel)


func _build_enhance_tab() -> void:
	var list_panel := _create_section_panel(Vector2(240, 0))
	var list_box := _create_section_box(list_panel)
	list_box.add_child(_create_section_title("Owned Equipment"))
	_enhance_list = _create_list()
	list_box.add_child(_wrap_scroll(_enhance_list))
	_enhance_tab.add_child(list_panel)

	var detail_panel := _create_section_panel(Vector2(280, 0))
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_box := _create_section_box(detail_panel)
	detail_box.add_child(_create_section_title("Enhancement"))
	_enhance_detail_label = _create_detail_label()
	detail_box.add_child(_enhance_detail_label)

	_enhance_button = Button.new()
	_enhance_button.custom_minimum_size = Vector2(170, 38)
	_enhance_button.text = "Enhance"
	_enhance_button.pressed.connect(_enhance_selected_item)
	detail_box.add_child(_enhance_button)
	_enhance_tab.add_child(detail_panel)


func _render_summary() -> void:
	_gold_label.text = "Gold: %d" % ExpeditionState.gold
	_ores_label.text = "Ores: %d" % ExpeditionState.ores


func _render_shop_inventory() -> void:
	_clear_children(_shop_list)

	if BlacksmithState.current_shop_items.is_empty():
		_add_empty_label(_shop_list, "No stock available")
		return

	for index in range(BlacksmithState.current_shop_items.size()):
		var item := BlacksmithState.current_shop_items[index]
		var affordable := BlacksmithState.can_afford(item)
		var text := "%s\n%s  %d G" % [
			item.get_display_name(),
			item.get_slot_name(),
			item.get_purchase_price(),
		]
		var button := _create_item_button(item, text, index == _selected_shop_index)
		if not affordable:
			button.modulate = Color(1.0, 0.62, 0.62)
		button.pressed.connect(_select_shop_item.bind(index))
		_shop_list.add_child(button)


func _render_sell_inventory() -> void:
	_clear_children(_sell_list)
	var items := BlacksmithState.get_owned_sell_items()

	if items.is_empty():
		_add_empty_label(_sell_list, "No reserve equipment")
		return

	for index in range(items.size()):
		var item := items[index]
		var button := _create_item_button(item, "%s\n%s  %d G" % [
			item.get_display_name(),
			item.get_slot_name(),
			item.get_sell_value(),
		], index == _selected_sell_index)
		button.pressed.connect(_select_sell_item.bind(index))
		_sell_list.add_child(button)


func _render_enhance_inventory() -> void:
	_clear_children(_enhance_list)
	var items := BlacksmithState.get_enhance_items()

	if items.is_empty():
		_add_empty_label(_enhance_list, "No owned equipment")
		return

	for item in items:
		var selected := item == _selected_enhance_item
		var button := _create_item_button(item, "%s\n%s  %s" % [
			item.get_display_name(),
			item.get_slot_name(),
			_get_enhancement_text(item),
		], selected)
		button.pressed.connect(_select_enhance_item.bind(item))
		_enhance_list.add_child(button)


func _render_shop_details() -> void:
	if _selected_shop_item == null:
		_shop_detail_label.text = "[b]Select an item[/b]\n\n[color=%s]Choose stock on the left to inspect it.[/color]" % MUTED_COLOR
		_buy_button.disabled = true
		_buy_button.text = "Buy"
		return

	var affordable := BlacksmithState.can_afford(_selected_shop_item)
	var price_color: String = NEUTRAL_COLOR if affordable else BAD_COLOR
	_shop_detail_label.text = _format_item_detail(
		_selected_shop_item,
		"[color=%s]Cost: %d Gold[/color]" % [price_color, _selected_shop_item.get_purchase_price()]
	)
	_buy_button.disabled = not affordable
	_buy_button.text = "Buy for %d G" % _selected_shop_item.get_purchase_price()


func _render_sell_details() -> void:
	if _selected_sell_item == null:
		_sell_detail_label.text = "[b]Select an item[/b]\n\n[color=%s]Choose reserve equipment to inspect its sell value.[/color]" % MUTED_COLOR
		_sell_button.disabled = true
		_sell_button.text = "Sell"
		return

	_sell_detail_label.text = _format_item_detail(
		_selected_sell_item,
		"[color=%s]Sell Value: %d Gold[/color]\n[color=%s]Equipped gear is protected from selling.[/color]" % [
			NEUTRAL_COLOR,
			_selected_sell_item.get_sell_value(),
			MUTED_COLOR,
		]
	)
	_sell_button.disabled = false
	_sell_button.text = "Sell for %d G" % _selected_sell_item.get_sell_value()


func _render_enhance_details() -> void:
	if _selected_enhance_item == null:
		_enhance_detail_label.text = "[b]Select equipment[/b]\n\n[color=%s]Choose owned gear to enhance it.[/color]" % MUTED_COLOR
		_enhance_button.disabled = true
		_enhance_button.text = "Enhance"
		return

	var cost := BlacksmithState.get_enhance_cost(_selected_enhance_item)
	var level := _get_enhancement_level(_selected_enhance_item)
	var maxed := level >= EquipmentInstance.MAX_ENHANCEMENT_LEVEL
	var affordable := ExpeditionState.ores >= cost
	var cost_color: String = NEUTRAL_COLOR if affordable else BAD_COLOR
	var extra_lines: Array[String] = [
		"Enhancement: [b]+%d[/b]" % level,
		"[b]Enhancement Bonuses[/b]",
		"[color=%s]%s[/color]" % [GOOD_COLOR, _get_enhancement_bonus_summary(_selected_enhance_item)],
		"[color=%s]Ore Cost: %d[/color]" % [cost_color, cost],
	]
	if _last_enhance_result.get("item", null) == _selected_enhance_item and String(_last_enhance_result.get("status", "")) == "success":
		var last_stat_changes: Dictionary = _last_enhance_result.get("stat_changes", {})
		extra_lines.append("[b]Last Result[/b]")
		extra_lines.append("[color=%s]%s roll[/color]: %s" % [
			String(_last_enhance_result.get("enhancement_quality_color", NEUTRAL_COLOR)),
			String(_last_enhance_result.get("enhancement_quality", "Solid")),
			_format_stat_changes(last_stat_changes),
		])
	_enhance_detail_label.text = _format_item_detail(
		_selected_enhance_item,
		"\n".join(extra_lines)
	)
	_enhance_button.disabled = maxed or not affordable
	_enhance_button.text = "Maxed" if maxed else "Enhance"


func _select_shop_item(index: int) -> void:
	if index < 0 or index >= BlacksmithState.current_shop_items.size():
		return

	_selected_shop_index = index
	_selected_shop_item = BlacksmithState.current_shop_items[index]
	_status_label.text = ""
	refresh()


func _select_sell_item(index: int) -> void:
	var items := BlacksmithState.get_owned_sell_items()
	if index < 0 or index >= items.size():
		return

	_selected_sell_index = index
	_selected_sell_item = items[index]
	_status_label.text = ""
	refresh()


func _select_enhance_item(item: EquipmentData) -> void:
	_selected_enhance_item = item
	_status_label.text = ""
	refresh()


func _buy_selected_item() -> void:
	if _selected_shop_index < 0:
		return

	if BlacksmithState.buy_item(_selected_shop_index):
		_status_label.text = "Purchased."
		_selected_shop_index = -1
		_selected_shop_item = null
		inventory_changed.emit()
		refresh()


func _sell_selected_item() -> void:
	if _selected_sell_index < 0:
		return

	if BlacksmithState.sell_inventory_item(_selected_sell_index):
		_status_label.text = "Sold."
		_selected_sell_index = -1
		_selected_sell_item = null
		if _selected_enhance_item != null and not _is_item_owned(_selected_enhance_item):
			_selected_enhance_item = null
		inventory_changed.emit()
		refresh()


func _enhance_selected_item() -> void:
	if _selected_enhance_item == null:
		return

	var result := BlacksmithState.enhance_item(_selected_enhance_item)
	_last_enhance_result = result
	_status_label.text = _format_enhance_result(result)
	if bool(result.get("broke", false)):
		_selected_enhance_item = null
	inventory_changed.emit()
	refresh()


func _format_item_detail(item: EquipmentData, extra_line: String) -> String:
	return "\n".join([
		"[font_size=20][color=%s][b]%s[/b][/color][/font_size]" % [item.get_rarity_color().to_html(false), item.get_display_name()],
		"[color=%s]%s %s[/color]" % [MUTED_COLOR, item.get_rarity_name(), item.get_slot_name()],
		"",
		item.description,
		"",
		"[b]Stats[/b]",
		"[color=%s]%s[/color]" % [GOOD_COLOR, item.get_bonus_summary()],
		"",
		extra_line,
	])


func _format_enhance_result(result: Dictionary) -> String:
	match String(result.get("status", "")):
		"success":
			var stat_changes: Dictionary = result.get("stat_changes", {})
			return "%s enhancement to +%d. %s" % [
				String(result.get("enhancement_quality", "Solid")),
				int(result.get("level_after", 0)),
				_format_stat_changes(stat_changes),
			]
		"broke":
			return "Enhancement failed. The item broke."
		"maxed":
			return "This item is already +100."
		"insufficient_ores":
			return "Not enough ores."
		_:
			return "Enhancement failed."


func _format_stat_changes(stat_changes: Dictionary) -> String:
	var lines: Array[String] = []
	for stat_key in stat_changes.keys():
		lines.append("+%d %s" % [int(stat_changes[stat_key]), _get_stat_display_name(StringName(stat_key))])
	return ", ".join(lines)


func _get_stat_display_name(stat_key: StringName) -> String:
	match stat_key:
		&"max_hp":
			return "Max HP"
		&"atk":
			return "ATK"
		&"def":
			return "DEF"
		&"spd":
			return "SPD"
		_:
			return String(stat_key).capitalize()


func _on_transaction_failed(message: String) -> void:
	_status_label.text = message


func _get_enhancement_text(item: EquipmentData) -> String:
	return "+%d" % _get_enhancement_level(item)


func _get_enhancement_bonus_summary(item: EquipmentData) -> String:
	if item is EquipmentInstance:
		return (item as EquipmentInstance).get_enhancement_bonus_summary()

	return "No enhancement bonuses yet"


func _get_enhancement_level(item: EquipmentData) -> int:
	if item is EquipmentInstance:
		return (item as EquipmentInstance).enhancement_level

	return 0


func _is_item_owned(item: EquipmentData) -> bool:
	if ExpeditionState.inventory.has(item):
		return true

	for equipped_item in ExpeditionState.equipped_gear.values():
		if equipped_item == item:
			return true

	return false


func _connect_state_signals() -> void:
	if not ExpeditionState.resources_changed.is_connected(_on_state_changed):
		ExpeditionState.resources_changed.connect(_on_state_changed)
	if not ExpeditionState.expedition_state_changed.is_connected(_on_state_changed):
		ExpeditionState.expedition_state_changed.connect(_on_state_changed)
	if not BlacksmithState.shop_inventory_changed.is_connected(_on_state_changed):
		BlacksmithState.shop_inventory_changed.connect(_on_state_changed)
	if not BlacksmithState.transaction_failed.is_connected(_on_transaction_failed):
		BlacksmithState.transaction_failed.connect(_on_transaction_failed)


func _on_state_changed() -> void:
	if is_inside_tree():
		refresh()


func _apply_tab_state() -> void:
	_tab_shop_button.disabled = _active_tab == &"shop"
	_tab_sell_button.disabled = _active_tab == &"sell"
	_tab_enhance_button.disabled = _active_tab == &"enhance"


func _create_summary_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(120, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	return label


func _create_tab_button(text: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(108, 32)
	button.text = text
	return button


func _create_section_panel(minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _create_style(PANEL_COLOR, PANEL_BORDER, 1, 8))
	return panel


func _create_section_box(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	return box


func _create_section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	return label


func _create_detail_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.scroll_active = true
	return label


func _create_list() -> VBoxContainer:
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 7)
	return list


func _wrap_scroll(list: VBoxContainer) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(list)
	return scroll


func _create_item_button(item: EquipmentData, text: String, selected: bool = false) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var background: Color = ROW_SELECTED if selected else ROW_NORMAL
	button.add_theme_stylebox_override("normal", _create_style(background, item.get_rarity_color(), 1, 6))
	button.add_theme_stylebox_override("hover", _create_style(background.lightened(0.08), item.get_rarity_color(), 1, 6))
	button.add_theme_stylebox_override("pressed", _create_style(background.lightened(0.14), item.get_rarity_color(), 2, 6))
	return button


func _add_empty_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 90)
	label.modulate = Color(0.66, 0.68, 0.7)
	parent.add_child(label)


func _create_style(background_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
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
