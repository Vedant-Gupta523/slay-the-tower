class_name WitchPage
extends Control

signal inventory_changed

const GOOD_COLOR := "#7ee787"
const BAD_COLOR := "#ff7b72"
const MUTED_COLOR := "#8b949e"
const NEUTRAL_COLOR := "#c9d1d9"
const STATUS_DEFAULT_COLOR := Color(0.88, 0.84, 0.68)
const PANEL_COLOR := Color(0.095, 0.10, 0.11, 1.0)
const PANEL_BORDER := Color(0.34, 0.36, 0.38, 0.9)
const ROW_NORMAL := Color(0.13, 0.135, 0.145, 1.0)
const ROW_SELECTED := Color(0.22, 0.20, 0.12, 1.0)
const TRADE_LIST_PANEL_WIDTH := 250
const TRADE_DETAIL_PANEL_WIDTH := 340
const TRADE_PANEL_HEIGHT := 370
const TRADE_DETAIL_TEXT_HEIGHT := 250
const ITEM_CARD_HEIGHT := 84
const ITEM_NAME_MAX_CHARS := 20
const ITEM_META_MAX_CHARS := 22
const BREW_SLOT_COUNT := 3
const BREW_SLOT_MYSTERIOUS := 0
const BREW_SLOT_BOTTLE := 1
const BREW_SLOT_MONSTER := 2

class BrewSketchDiagram:
	extends Control

	func _draw() -> void:
		var line_color := Color(0.48, 0.53, 0.58, 0.9)
		var line_glow := Color(0.35, 0.74, 0.72, 0.18)
		var slot_fill := Color(0.12, 0.13, 0.14, 1.0)
		var slot_border := Color(0.62, 0.72, 0.68, 0.95)
		var accent := Color(0.35, 0.80, 0.72, 0.9)
		var brew_liquid := Color(0.26, 0.86, 0.68, 0.64)
		var result_center := Vector2(size.x * 0.55, 88.0)
		var result_radius := 64.0
		var mysterious_center := Vector2(size.x * 0.27, size.y - 104.0)
		var bottle_center := Vector2(size.x * 0.55, size.y - 72.0)
		var monster_center := Vector2(size.x * 0.84, size.y - 104.0)

		_draw_connector(mysterious_center + Vector2(46.0, -52.0), result_center + Vector2(-38.0, 48.0), line_glow, 8.0)
		_draw_connector(bottle_center + Vector2(0.0, -44.0), result_center + Vector2(0.0, 54.0), line_glow, 8.0)
		_draw_connector(monster_center + Vector2(-58.0, -52.0), result_center + Vector2(48.0, 42.0), line_glow, 8.0)
		_draw_connector(mysterious_center + Vector2(46.0, -52.0), result_center + Vector2(-38.0, 48.0), line_color, 3.0)
		_draw_connector(bottle_center + Vector2(0.0, -44.0), result_center + Vector2(0.0, 54.0), line_color, 3.0)
		_draw_connector(monster_center + Vector2(-58.0, -52.0), result_center + Vector2(48.0, 42.0), line_color, 3.0)

		draw_circle(result_center, result_radius + 7.0, Color(0.35, 0.80, 0.72, 0.11))
		draw_circle(result_center, result_radius, slot_fill)
		draw_arc(result_center, result_radius, 0.0, TAU, 96, slot_border, 3.0, true)
		draw_arc(result_center, result_radius - 10.0, PI * 0.1, PI * 0.86, 32, accent, 2.0, true)
		_draw_slot_backing(mysterious_center, Vector2(152.0, 88.0), slot_fill, slot_border)
		_draw_slot_backing(bottle_center, Vector2(152.0, 78.0), slot_fill, slot_border)
		_draw_slot_backing(monster_center, Vector2(190.0, 88.0), slot_fill, slot_border)
		_draw_cauldron(Vector2(98.0, size.y - 140.0), brew_liquid, accent, slot_border)

	func _draw_connector(start_pos: Vector2, end_pos: Vector2, color: Color, width: float) -> void:
		draw_line(start_pos, end_pos, color, width, true)

	func _draw_slot_backing(center: Vector2, slot_size: Vector2, fill: Color, border: Color) -> void:
		var rect := Rect2(center - slot_size * 0.5, slot_size)
		draw_rect(rect, fill, true)
		draw_rect(rect, border, false, 2.0)

	func _draw_cauldron(center: Vector2, liquid: Color, accent: Color, border: Color) -> void:
		var bowl := Rect2(center + Vector2(-72.0, -26.0), Vector2(144.0, 86.0))
		draw_arc(center + Vector2(0.0, 6.0), 72.0, 0.0, PI, 48, border, 5.0, true)
		draw_rect(Rect2(bowl.position + Vector2(8.0, 20.0), Vector2(128.0, 32.0)), Color(0.08, 0.09, 0.10, 1.0), true)
		draw_line(center + Vector2(-56.0, 60.0), center + Vector2(-72.0, 84.0), border, 4.0, true)
		draw_line(center + Vector2(56.0, 60.0), center + Vector2(72.0, 84.0), border, 4.0, true)
		draw_arc(center + Vector2(0.0, -12.0), 60.0, 0.0, PI, 42, liquid, 8.0, true)
		draw_circle(center + Vector2(-22.0, -30.0), 8.0, accent)
		draw_circle(center + Vector2(10.0, -42.0), 6.0, accent.lightened(0.2))
		draw_circle(center + Vector2(36.0, -26.0), 5.0, accent.lightened(0.1))

var _gold_label: Label
var _tab_brew_button: Button
var _tab_trade_button: Button
var _status_label: Label
var _brew_tab: HBoxContainer
var _trade_tab: HBoxContainer
var _trade_player_list: GridContainer
var _trade_shop_list: GridContainer
var _trade_detail_label: RichTextLabel
var _trade_action_button: Button
var _trade_player_buttons: Array[Button] = []
var _trade_shop_buttons: Array[Button] = []
var _trade_confirm_popup: PanelContainer
var _trade_confirm_title: Label
var _trade_confirm_price: Label
var _trade_confirm_button: Button
var _trade_cancel_button: Button
var _brew_available_list: GridContainer
var _brew_diagram: Control
var _brew_slot_buttons: Array[Button] = []
var _brew_result_label: RichTextLabel
var _brew_button: Button
var _inventory_popup: PanelContainer
var _inventory_popup_title: Label
var _inventory_popup_list: GridContainer

var _active_tab: StringName = &"brew"
var _selected_trade_item: ItemData
var _selected_trade_index: int = -1
var _selected_trade_mode: StringName = &""
var _pending_trade_item: ItemData
var _pending_trade_index: int = -1
var _pending_trade_mode: StringName = &""
var _pending_trade_price: int = 0
var _pending_trade_source_control: Control
var _brew_slot_items: Array = [null, null, null]
var _brew_slot_indices: Array[int] = [-1, -1, -1]
var _active_brew_slot_index: int = -1
var _last_brewed_potion: PotionData


func _ready() -> void:
	_build_ui()
	_connect_state_signals()
	show_brew_tab()
	refresh()


func refresh() -> void:
	WitchState.ensure_inventory()
	_render_summary()
	_render_trade_inventory()
	_render_brew_inventory()
	_render_trade_details()
	_render_brew_details()


func show_brew_tab() -> void:
	_active_tab = &"brew"
	_hide_trade_confirm_popup()
	if _inventory_popup != null:
		_inventory_popup.visible = false
	_brew_tab.visible = true
	_trade_tab.visible = false
	_apply_tab_state()
	_status_label.text = "Choose three materials to brew."
	_status_label.modulate = STATUS_DEFAULT_COLOR


func show_trade_tab() -> void:
	_active_tab = &"trade"
	if _inventory_popup != null:
		_inventory_popup.visible = false
	_trade_tab.visible = true
	_brew_tab.visible = false
	_apply_tab_state()
	_status_label.text = "Trade ingredients and potions with the witch."
	_status_label.modulate = STATUS_DEFAULT_COLOR


func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	root.add_child(top_row)

	var title := Label.new()
	title.text = "Witch"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	top_row.add_child(title)

	_gold_label = _create_summary_label("Gold: 0")
	top_row.add_child(_gold_label)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	root.add_child(tab_row)

	_tab_brew_button = _create_tab_button("Brewing")
	_tab_brew_button.pressed.connect(show_brew_tab)
	tab_row.add_child(_tab_brew_button)

	_tab_trade_button = _create_tab_button("Trade")
	_tab_trade_button.pressed.connect(show_trade_tab)
	tab_row.add_child(_tab_trade_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.modulate = STATUS_DEFAULT_COLOR
	tab_row.add_child(_status_label)

	_brew_tab = HBoxContainer.new()
	_brew_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brew_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_brew_tab.add_theme_constant_override("separation", 10)
	root.add_child(_brew_tab)
	_build_brew_tab()

	_trade_tab = HBoxContainer.new()
	_trade_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trade_tab.add_theme_constant_override("separation", 10)
	root.add_child(_trade_tab)
	_build_trade_tab()

	_build_trade_confirm_popup()
	_build_inventory_popup()


func _build_trade_tab() -> void:
	var player_panel := _create_section_panel(Vector2(TRADE_LIST_PANEL_WIDTH, TRADE_PANEL_HEIGHT))
	player_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	player_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var player_box := _create_section_box(player_panel)
	player_box.add_child(_create_section_title("Player satchel"))
	_trade_player_list = _create_grid_list()
	player_box.add_child(_wrap_scroll(_trade_player_list))
	_trade_tab.add_child(player_panel)

	var detail_panel := _create_section_panel(Vector2(TRADE_DETAIL_PANEL_WIDTH, TRADE_PANEL_HEIGHT))
	detail_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	detail_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var detail_box := _create_section_box(detail_panel)
	detail_box.add_child(_create_section_title("Trade"))
	_trade_detail_label = _create_detail_label()
	_trade_detail_label.custom_minimum_size = Vector2(0, TRADE_DETAIL_TEXT_HEIGHT)
	_trade_detail_label.fit_content = false
	_trade_detail_label.scroll_active = true
	detail_box.add_child(_trade_detail_label)

	_trade_action_button = Button.new()
	_trade_action_button.custom_minimum_size = Vector2(0, 40)
	_trade_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_action_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_trade_action_button.clip_text = true
	_trade_action_button.text = "Click an item to choose a trade"
	_trade_action_button.disabled = true
	detail_box.add_child(_trade_action_button)
	_trade_tab.add_child(detail_panel)

	var stock_panel := _create_section_panel(Vector2(TRADE_LIST_PANEL_WIDTH, TRADE_PANEL_HEIGHT))
	stock_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stock_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var stock_box := _create_section_box(stock_panel)
	stock_box.add_child(_create_section_title("Witch stock"))
	_trade_shop_list = _create_grid_list()
	stock_box.add_child(_wrap_scroll(_trade_shop_list))
	_trade_tab.add_child(stock_panel)


func _build_brew_tab() -> void:
	var brew_panel := _create_section_panel(Vector2(760, 440))
	brew_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brew_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var brew_box := _create_section_box(brew_panel)
	var title := _create_section_title("Brew")
	title.add_theme_color_override("font_color", Color(0.88, 0.84, 0.68))
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	brew_box.add_child(title)

	_brew_diagram = BrewSketchDiagram.new()
	_brew_diagram.custom_minimum_size = Vector2(720, 360)
	_brew_diagram.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brew_diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brew_box.add_child(_brew_diagram)

	_brew_result_label = _create_detail_label()
	_brew_result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brew_result_label.scroll_active = false
	_brew_result_label.bbcode_enabled = true
	_brew_result_label.add_theme_color_override("default_color", Color(0.9, 0.92, 0.9))
	_brew_diagram.add_child(_brew_result_label)

	for slot_index in range(BREW_SLOT_COUNT):
		var slot_button := Button.new()
		slot_button.custom_minimum_size = Vector2(132, 76)
		slot_button.text = _get_brew_slot_label(slot_index)
		slot_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_button.add_theme_font_size_override("font_size", 13)
		slot_button.pressed.connect(_open_inventory_popup.bind(slot_index, slot_button))
		_brew_diagram.add_child(slot_button)
		_brew_slot_buttons.append(slot_button)

	_brew_button = Button.new()
	_brew_button.custom_minimum_size = Vector2(120, 42)
	_brew_button.text = "Brew"
	_brew_button.pressed.connect(_brew_selected_materials)
	_brew_diagram.add_child(_brew_button)
	_brew_tab.add_child(brew_panel)
	call_deferred("_layout_brew_diagram")


func _render_summary() -> void:
	_gold_label.text = "Gold: %d" % ExpeditionState.gold


func _render_trade_inventory() -> void:
	_clear_children(_trade_shop_list)
	_clear_children(_trade_player_list)
	_trade_shop_buttons.clear()
	_trade_player_buttons.clear()

	if WitchState.current_shop_items.is_empty():
		_add_empty_label(_trade_shop_list, "No witch stock")
	else:
		for index in range(WitchState.current_shop_items.size()):
			var item := WitchState.current_shop_items[index]
			var button := _create_item_button(item, _format_trade_item_text(item.get_display_name(), item.get_item_category_name(), "%d G" % item.get_purchase_price()), _selected_trade_mode == &"buy" and _selected_trade_index == index)
			if not WitchState.can_afford(item):
				button.modulate = Color(1.0, 0.62, 0.62)
			button.pressed.connect(_request_buy_trade.bind(index, button))
			_trade_shop_list.add_child(button)
			_trade_shop_buttons.append(button)

	var owned_items := WitchState.get_owned_sell_items()
	if owned_items.is_empty():
		_add_empty_label(_trade_player_list, "No potion items to sell")
	else:
		for index in range(owned_items.size()):
			var item := owned_items[index]
			var button := _create_item_button(item, _format_trade_item_text(item.get_display_name(), item.get_item_category_name(), "%d G" % item.get_sell_value()), _selected_trade_mode == &"sell" and _selected_trade_index == index)
			button.pressed.connect(_request_sell_trade.bind(index, button))
			_trade_player_list.add_child(button)
			_trade_player_buttons.append(button)


func _render_brew_inventory() -> void:
	if _brew_available_list == null:
		if _brew_diagram != null:
			_brew_diagram.queue_redraw()
		return

	_clear_children(_brew_available_list)
	var entries := WitchState.get_brewable_inventory_entries()
	if entries.is_empty():
		_add_empty_label(_brew_available_list, "No valid brewing materials")
		return

	var grouped_counts: Dictionary = {}
	for entry in entries:
		var item := entry["item"] as MaterialData
		var current_count := int(grouped_counts.get(item.item_id, 0))
		grouped_counts[item.item_id] = current_count + 1

	var seen_ids: Dictionary = {}
	for entry in entries:
		var item := entry["item"] as MaterialData
		if item == null or seen_ids.has(item.item_id):
			continue
		seen_ids[item.item_id] = true
		var button := _create_item_button(item, _format_trade_item_text(item.get_display_name(), item.get_item_category_name(), "Owned: %d" % int(grouped_counts[item.item_id])))
		button.disabled = true
		_brew_available_list.add_child(button)


func _render_trade_details() -> void:
	_validate_pending_trade()
	if _selected_trade_item == null:
		_trade_detail_label.text = "\n".join([
			"[center][font_size=28][b]Trade[/b][/font_size][/center]",
			"[center][color=%s]Click witch stock to buy ingredients and potions.[/color][/center]" % NEUTRAL_COLOR,
			"",
			"[center][color=%s]Click satchel items to sell them back.[/color][/center]" % NEUTRAL_COLOR,
			"",
			"[center][color=%s]Gold: %d[/color][/center]" % [NEUTRAL_COLOR, ExpeditionState.gold],
		])
		_trade_action_button.disabled = true
		_trade_action_button.text = "Click an item to choose a trade"
	else:
		var price_text := "%d G" % (_selected_trade_item.get_purchase_price() if _selected_trade_mode == &"buy" else _selected_trade_item.get_sell_value())
		_trade_detail_label.text = _format_item_detail(_selected_trade_item, price_text)
		_trade_action_button.disabled = true
		_trade_action_button.text = "Confirm in popup"

	_sync_trade_confirm_popup()


func _render_brew_details() -> void:
	_layout_brew_diagram()
	for slot_index in range(BREW_SLOT_COUNT):
		var slot_item := _brew_slot_items[slot_index] as MaterialData
		var slot_button := _brew_slot_buttons[slot_index]
		if slot_item == null:
			slot_button.text = "%s\nChoose" % _get_brew_slot_label(slot_index)
			slot_button.add_theme_stylebox_override("normal", _create_style(ROW_NORMAL, Color(0.62, 0.72, 0.68), 1, 8))
			slot_button.add_theme_stylebox_override("hover", _create_style(ROW_NORMAL.lightened(0.08), Color(0.35, 0.80, 0.72), 2, 8))
			slot_button.add_theme_stylebox_override("pressed", _create_style(ROW_NORMAL.lightened(0.14), Color(0.35, 0.80, 0.72), 2, 8))
		else:
			slot_button.text = "%s\n%s" % [_get_brew_slot_label(slot_index), _truncate_text(slot_item.get_display_name(), 18)]
			slot_button.add_theme_stylebox_override("normal", _create_style(ROW_SELECTED, slot_item.get_rarity_color(), 2, 8))
			slot_button.add_theme_stylebox_override("hover", _create_style(ROW_SELECTED.lightened(0.08), slot_item.get_rarity_color(), 2, 8))
			slot_button.add_theme_stylebox_override("pressed", _create_style(ROW_SELECTED.lightened(0.14), slot_item.get_rarity_color(), 2, 8))

	var preview_materials := _get_selected_brew_materials()
	if preview_materials.size() == BREW_SLOT_COUNT:
		var preview_potion := WitchState.preview_brew_result(preview_materials)
		if preview_potion != null:
			_brew_result_label.text = "[center][color=%s][b]Potion[/b][/color]\n%s[/center]" % [
				preview_potion.get_rarity_color().to_html(false),
				_truncate_text(preview_potion.get_display_name(), 22),
			]
		else:
			_brew_result_label.text = "[center][color=%s]No stable result yet.[/color][/center]" % BAD_COLOR
	else:
		if _last_brewed_potion != null:
			_brew_result_label.text = "[center][b]Potion[/b]\n[color=%s]%s[/color][/center]" % [
				_last_brewed_potion.get_rarity_color().to_html(false),
				_truncate_text(_last_brewed_potion.get_display_name(), 22),
			]
		else:
			_brew_result_label.text = "[center][b]Potion[/b][/center]"

	_brew_button.disabled = preview_materials.size() != BREW_SLOT_COUNT
	_brew_button.text = "Brew" if not _brew_button.disabled else "Need 3 materials"
	if _brew_diagram != null:
		_brew_diagram.queue_redraw()


func _request_buy_trade(index: int, source_control: Control) -> void:
	if index < 0 or index >= WitchState.current_shop_items.size():
		return
	_selected_trade_mode = &"buy"
	_selected_trade_index = index
	_selected_trade_item = WitchState.current_shop_items[index]
	_show_trade_confirm_popup(source_control, &"buy", index, _selected_trade_item, _selected_trade_item.get_purchase_price())
	refresh()


func _request_sell_trade(index: int, source_control: Control) -> void:
	var items := WitchState.get_owned_sell_items()
	if index < 0 or index >= items.size():
		return
	_selected_trade_mode = &"sell"
	_selected_trade_index = index
	_selected_trade_item = items[index]
	_show_trade_confirm_popup(source_control, &"sell", index, _selected_trade_item, _selected_trade_item.get_sell_value())
	refresh()


func _show_trade_confirm_popup(source_control: Control, mode: StringName, index: int, item: ItemData, price: int) -> void:
	_pending_trade_mode = mode
	_pending_trade_index = index
	_pending_trade_item = item
	_pending_trade_price = price
	_pending_trade_source_control = source_control
	_sync_trade_confirm_popup()
	_trade_confirm_popup.visible = true
	_deferred_position_trade_confirm_popup()


func _sync_trade_confirm_popup() -> void:
	if _trade_confirm_popup == null or _pending_trade_item == null:
		return

	var mode_text := "Buy" if _pending_trade_mode == &"buy" else "Sell"
	_trade_confirm_title.text = "%s %s?" % [mode_text, _truncate_text(_pending_trade_item.get_display_name(), 16)]
	_trade_confirm_price.text = "%s for %d G" % [mode_text, _pending_trade_price]
	_trade_confirm_button.text = "Confirm"
	call_deferred("_deferred_position_trade_confirm_popup")


func _hide_trade_confirm_popup() -> void:
	if _trade_confirm_popup != null:
		_trade_confirm_popup.visible = false
	_pending_trade_item = null
	_pending_trade_mode = &""
	_pending_trade_index = -1
	_pending_trade_price = 0
	_pending_trade_source_control = null


func _get_pending_trade_source_control() -> Control:
	if _pending_trade_mode == &"buy":
		if _pending_trade_index >= 0 and _pending_trade_index < _trade_shop_buttons.size():
			return _trade_shop_buttons[_pending_trade_index]
	elif _pending_trade_mode == &"sell":
		if _pending_trade_index >= 0 and _pending_trade_index < _trade_player_buttons.size():
			return _trade_player_buttons[_pending_trade_index]

	return _pending_trade_source_control if is_instance_valid(_pending_trade_source_control) else null


func _deferred_position_trade_confirm_popup() -> void:
	if _pending_trade_item == null or _active_tab != &"trade":
		return

	var source_control := _get_pending_trade_source_control()
	if source_control != null:
		_position_popup_near_control(_trade_confirm_popup, source_control)


func _validate_pending_trade() -> void:
	if _pending_trade_item == null:
		return
	if _pending_trade_mode == &"buy":
		if _pending_trade_index < 0 or _pending_trade_index >= WitchState.current_shop_items.size() or WitchState.current_shop_items[_pending_trade_index] != _pending_trade_item:
			_hide_trade_confirm_popup()
	elif _pending_trade_mode == &"sell":
		var items := WitchState.get_owned_sell_items()
		if _pending_trade_index < 0 or _pending_trade_index >= items.size() or items[_pending_trade_index] != _pending_trade_item:
			_hide_trade_confirm_popup()


func _on_confirm_trade_pressed() -> void:
	var traded := false
	match _pending_trade_mode:
		&"buy":
			traded = WitchState.buy_item(_pending_trade_index)
		&"sell":
			traded = WitchState.sell_inventory_item(_pending_trade_index)

	if traded:
		_status_label.text = "Trade completed."
		_status_label.modulate = STATUS_DEFAULT_COLOR
		inventory_changed.emit()
		_selected_trade_item = null
		_selected_trade_index = -1
		_selected_trade_mode = &""
		_hide_trade_confirm_popup()
		refresh()
	else:
		_hide_trade_confirm_popup()
		refresh()


func _on_cancel_trade_pressed() -> void:
	_hide_trade_confirm_popup()
	_status_label.text = "Trade cancelled."
	_status_label.modulate = STATUS_DEFAULT_COLOR
	refresh()


func _open_inventory_popup(slot_index: int, source_control: Control) -> void:
	_active_brew_slot_index = slot_index
	_inventory_popup.visible = true
	_inventory_popup_title.text = "Choose %s" % _get_brew_slot_title(slot_index)
	_clear_children(_inventory_popup_list)

	var clear_button := Button.new()
	clear_button.text = "Clear slot"
	clear_button.custom_minimum_size = Vector2(0, 36)
	clear_button.pressed.connect(_clear_brew_slot.bind(slot_index))
	_inventory_popup_list.add_child(clear_button)

	var entries := WitchState.get_brewable_inventory_entries_for_type(_get_brew_slot_material_type(slot_index))
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No valid brewing materials"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_inventory_popup_list.add_child(empty_label)
	else:
		var reserved_indices: Dictionary = {}
		for selected_index in _brew_slot_indices:
			if selected_index >= 0:
				reserved_indices[selected_index] = true
		for entry in entries:
			var item := entry["item"] as MaterialData
			var inventory_index := int(entry["index"])
			if reserved_indices.has(inventory_index) and _brew_slot_indices[slot_index] != inventory_index:
				continue
			var button := _create_item_button(item, _format_trade_item_text(item.get_display_name(), item.get_item_category_name(), "Use in brew"))
			button.custom_minimum_size = Vector2(0, 72)
			button.pressed.connect(_select_brew_material.bind(slot_index, inventory_index, item))
			_inventory_popup_list.add_child(button)

	_position_popup_near_control(_inventory_popup, source_control)


func _select_brew_material(slot_index: int, inventory_index: int, item: MaterialData) -> void:
	_brew_slot_indices[slot_index] = inventory_index
	_brew_slot_items[slot_index] = item
	_inventory_popup.visible = false
	refresh()


func _clear_brew_slot(slot_index: int) -> void:
	_brew_slot_indices[slot_index] = -1
	_brew_slot_items[slot_index] = null
	_inventory_popup.visible = false
	refresh()


func _brew_selected_materials() -> void:
	var indices: Array[int] = []
	for index in _brew_slot_indices:
		if index < 0:
			_status_label.text = "Choose three valid materials first."
			_status_label.modulate = Color.html(BAD_COLOR)
			return
		indices.append(index)

	var result := WitchState.brew_materials_by_indices(indices)
	if bool(result.get("success", false)):
		_last_brewed_potion = result.get("potion", null) as PotionData
		_status_label.text = "Brewing succeeded: %s" % (_last_brewed_potion.get_display_name() if _last_brewed_potion != null else "Potion created")
		_status_label.modulate = Color.html(GOOD_COLOR)
		_clear_all_brew_slots()
		inventory_changed.emit()
	else:
		_status_label.text = "Brewing failed. Choose three valid materials."
		_status_label.modulate = Color.html(BAD_COLOR)
	refresh()


func _clear_all_brew_slots() -> void:
	for slot_index in range(BREW_SLOT_COUNT):
		_brew_slot_indices[slot_index] = -1
		_brew_slot_items[slot_index] = null


func _get_selected_brew_materials() -> Array[MaterialData]:
	var materials: Array[MaterialData] = []
	for item in _brew_slot_items:
		var material := item as MaterialData
		if material != null:
			materials.append(material)
	return materials


func _format_item_detail(item: ItemData, extra_line: String) -> String:
	return "\n".join([
		"[font_size=20][color=%s][b]%s[/b][/color][/font_size]" % [item.get_rarity_color().to_html(false), item.get_display_name()],
		"[color=%s]%s %s[/color]" % [MUTED_COLOR, item.get_rarity_name(), item.get_item_category_name()],
		"",
		item.description,
		"",
		"[b]Effects[/b]",
		"[color=%s]%s[/color]" % [GOOD_COLOR, item.get_detail_summary()],
		"",
		extra_line,
	])


func _on_transaction_failed(message: String) -> void:
	_status_label.text = message
	_status_label.modulate = Color.html(BAD_COLOR)


func _on_state_changed() -> void:
	if is_inside_tree():
		_revalidate_brew_slots()
		refresh()


func _on_brewing_completed(_result: Dictionary) -> void:
	if is_inside_tree():
		_revalidate_brew_slots()


func _revalidate_brew_slots() -> void:
	var snapshot := ExpeditionState.get_item_inventory_snapshot()
	for slot_index in range(BREW_SLOT_COUNT):
		var inventory_index := _brew_slot_indices[slot_index]
		if inventory_index < 0 or inventory_index >= snapshot.size():
			_brew_slot_indices[slot_index] = -1
			_brew_slot_items[slot_index] = null
			continue
		var material := snapshot[inventory_index] as MaterialData
		if material == null or not WitchState.is_valid_brewing_material(material) or material.material_type != _get_brew_slot_material_type(slot_index):
			_brew_slot_indices[slot_index] = -1
			_brew_slot_items[slot_index] = null
			continue
		_brew_slot_items[slot_index] = material


func _layout_brew_diagram() -> void:
	if _brew_diagram == null or _brew_slot_buttons.size() < BREW_SLOT_COUNT or _brew_result_label == null or _brew_button == null:
		return

	var diagram_size := _brew_diagram.size
	if diagram_size.x <= 1.0 or diagram_size.y <= 1.0:
		diagram_size = _brew_diagram.custom_minimum_size

	var result_size := Vector2(166, 88)
	var small_slot_size := Vector2(142, 76)
	var bottle_slot_size := Vector2(150, 66)
	var monster_slot_size := Vector2(178, 76)
	var result_center := Vector2(diagram_size.x * 0.55, 88.0)
	var mysterious_center := Vector2(diagram_size.x * 0.27, diagram_size.y - 104.0)
	var bottle_center := Vector2(diagram_size.x * 0.55, diagram_size.y - 72.0)
	var monster_center := Vector2(diagram_size.x * 0.84, diagram_size.y - 104.0)

	_brew_result_label.position = result_center - result_size * 0.5
	_brew_result_label.size = result_size
	_brew_slot_buttons[BREW_SLOT_MYSTERIOUS].position = mysterious_center - small_slot_size * 0.5
	_brew_slot_buttons[BREW_SLOT_MYSTERIOUS].size = small_slot_size
	_brew_slot_buttons[BREW_SLOT_BOTTLE].position = bottle_center - bottle_slot_size * 0.5
	_brew_slot_buttons[BREW_SLOT_BOTTLE].size = bottle_slot_size
	_brew_slot_buttons[BREW_SLOT_MONSTER].position = monster_center - monster_slot_size * 0.5
	_brew_slot_buttons[BREW_SLOT_MONSTER].size = monster_slot_size
	_brew_button.position = Vector2(diagram_size.x - 150.0, 18.0)
	_brew_button.size = Vector2(128.0, 42.0)


func _get_brew_slot_label(slot_index: int) -> String:
	match slot_index:
		BREW_SLOT_MYSTERIOUS:
			return "Mysterious"
		BREW_SLOT_BOTTLE:
			return "Bottle"
		BREW_SLOT_MONSTER:
			return "Monster mats"
		_:
			return "Input"


func _get_brew_slot_title(slot_index: int) -> String:
	match slot_index:
		BREW_SLOT_MYSTERIOUS:
			return "mysterious ingredient"
		BREW_SLOT_BOTTLE:
			return "bottle"
		BREW_SLOT_MONSTER:
			return "monster material"
		_:
			return "material"


func _get_brew_slot_material_type(slot_index: int) -> StringName:
	match slot_index:
		BREW_SLOT_MYSTERIOUS:
			return MaterialData.TYPE_MYSTERIOUS_INGREDIENT
		BREW_SLOT_BOTTLE:
			return MaterialData.TYPE_BOTTLE
		BREW_SLOT_MONSTER:
			return MaterialData.TYPE_MONSTER_MATERIAL
		_:
			return &""


func _connect_state_signals() -> void:
	if not ExpeditionState.resources_changed.is_connected(_on_state_changed):
		ExpeditionState.resources_changed.connect(_on_state_changed)
	if not ExpeditionState.expedition_state_changed.is_connected(_on_state_changed):
		ExpeditionState.expedition_state_changed.connect(_on_state_changed)
	if not WitchState.shop_inventory_changed.is_connected(_on_state_changed):
		WitchState.shop_inventory_changed.connect(_on_state_changed)
	if not WitchState.transaction_failed.is_connected(_on_transaction_failed):
		WitchState.transaction_failed.connect(_on_transaction_failed)
	if not WitchState.brewing_completed.is_connected(_on_brewing_completed):
		WitchState.brewing_completed.connect(_on_brewing_completed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_brew_diagram()
		if _brew_diagram != null:
			_brew_diagram.queue_redraw()
		if _trade_confirm_popup != null and _trade_confirm_popup.visible:
			_deferred_position_trade_confirm_popup()


func _process(_delta: float) -> void:
	if _trade_confirm_popup != null and _trade_confirm_popup.visible:
		_deferred_position_trade_confirm_popup()


func _apply_tab_state() -> void:
	_tab_brew_button.disabled = _active_tab == &"brew"
	_tab_trade_button.disabled = _active_tab == &"trade"


func _build_trade_confirm_popup() -> void:
	_trade_confirm_popup = PanelContainer.new()
	_trade_confirm_popup.visible = false
	_trade_confirm_popup.top_level = true
	_trade_confirm_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_trade_confirm_popup.add_theme_stylebox_override("panel", _create_style(PANEL_COLOR, PANEL_BORDER, 1, 6))
	add_child(_trade_confirm_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 7)
	_trade_confirm_popup.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	_trade_confirm_title = Label.new()
	_trade_confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_confirm_title.add_theme_font_size_override("font_size", 13)
	box.add_child(_trade_confirm_title)

	_trade_confirm_price = Label.new()
	_trade_confirm_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_confirm_price.modulate = Color(0.88, 0.84, 0.68)
	_trade_confirm_price.add_theme_font_size_override("font_size", 12)
	box.add_child(_trade_confirm_price)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 6)
	box.add_child(button_row)

	_trade_confirm_button = Button.new()
	_trade_confirm_button.custom_minimum_size = Vector2(68, 26)
	_trade_confirm_button.text = "Confirm"
	_trade_confirm_button.add_theme_font_size_override("font_size", 12)
	_trade_confirm_button.pressed.connect(_on_confirm_trade_pressed)
	button_row.add_child(_trade_confirm_button)

	_trade_cancel_button = Button.new()
	_trade_cancel_button.custom_minimum_size = Vector2(60, 26)
	_trade_cancel_button.text = "Cancel"
	_trade_cancel_button.add_theme_font_size_override("font_size", 12)
	_trade_cancel_button.pressed.connect(_on_cancel_trade_pressed)
	button_row.add_child(_trade_cancel_button)


func _build_inventory_popup() -> void:
	_inventory_popup = PanelContainer.new()
	_inventory_popup.visible = false
	_inventory_popup.top_level = true
	_inventory_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_popup.custom_minimum_size = Vector2(280, 260)
	_inventory_popup.add_theme_stylebox_override("panel", _create_style(PANEL_COLOR, PANEL_BORDER, 1, 8))
	add_child(_inventory_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_inventory_popup.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	_inventory_popup_title = Label.new()
	_inventory_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inventory_popup_title.add_theme_font_size_override("font_size", 16)
	box.add_child(_inventory_popup_title)

	_inventory_popup_list = _create_grid_list()
	box.add_child(_wrap_scroll(_inventory_popup_list))


func _position_popup_near_control(popup: Control, source_control: Control) -> void:
	if popup == null or source_control == null:
		return

	var popup_size := popup.size
	if popup_size == Vector2.ZERO:
		popup_size = popup.get_combined_minimum_size()
	var source_rect := source_control.get_global_rect()
	var desired := source_rect.position + Vector2(source_rect.size.x + 8.0, 0.0)
	var bounds := Rect2(global_position, size)
	var margin := 8.0
	if desired.x + popup_size.x > bounds.position.x + bounds.size.x - margin:
		desired.x = source_rect.position.x - popup_size.x - margin
	if desired.x < bounds.position.x + margin:
		desired.x = clamp(
			source_rect.position.x + source_rect.size.x * 0.5 - popup_size.x * 0.5,
			bounds.position.x + margin,
			bounds.position.x + bounds.size.x - popup_size.x - margin
		)
	desired.y = clamp(
		source_rect.position.y + (source_rect.size.y - popup_size.y) * 0.5,
		bounds.position.y + margin,
		bounds.position.y + bounds.size.y - popup_size.y - margin
	)
	popup.global_position = desired.floor()


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
	label.fit_content = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.scroll_active = true
	return label


func _create_grid_list() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	return grid


func _wrap_scroll(list: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	scroll.add_child(list)
	return scroll


func _create_item_button(item: ItemData, text: String, selected: bool = false) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, ITEM_CARD_HEIGHT)
	button.size = Vector2(0, ITEM_CARD_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.clip_text = true
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var background: Color = ROW_SELECTED if selected else ROW_NORMAL
	button.add_theme_stylebox_override("normal", _create_style(background, item.get_rarity_color(), 1, 6))
	button.add_theme_stylebox_override("hover", _create_style(background.lightened(0.08), item.get_rarity_color(), 1, 6))
	button.add_theme_stylebox_override("pressed", _create_style(background.lightened(0.14), item.get_rarity_color(), 2, 6))
	return button


func _format_trade_item_text(name_text: String, meta_text: String, price_text: String) -> String:
	return "%s\n%s\n%s" % [
		_truncate_text(name_text, ITEM_NAME_MAX_CHARS),
		_truncate_text(meta_text, ITEM_META_MAX_CHARS),
		price_text,
	]


func _truncate_text(value: String, max_chars: int) -> String:
	if value.length() <= max_chars:
		return value
	if max_chars <= 1:
		return value.left(max_chars)
	return "%s..." % value.left(max_chars - 3)


func _add_empty_label(parent: Node, text: String) -> void:
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
