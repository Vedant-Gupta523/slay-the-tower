class_name BlacksmithPage
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
const TRADE_LIST_PANEL_MIN_WIDTH := 250
const TRADE_DETAIL_PANEL_MIN_WIDTH := 240
const TRADE_ITEM_CARD_HEIGHT := 84
const TRADE_ITEM_NAME_MAX_CHARS := 20
const TRADE_ITEM_META_MAX_CHARS := 18
const ENCHANT_CAST_TIME := 0.65

var _gold_label: Label
var _ores_label: Label
var _tab_shop_button: Button
var _tab_sell_button: Button
var _tab_enhance_button: Button
var _status_label: Label
var _shop_tab: HBoxContainer
var _sell_tab: HBoxContainer
var _enhance_tab: HBoxContainer
var _shop_list: GridContainer
var _sell_list: GridContainer
var _enhance_list: GridContainer
var _enhance_item_panel: PanelContainer
var _enhance_material_panel: PanelContainer
var _shop_detail_label: RichTextLabel
var _sell_detail_label: RichTextLabel
var _enhance_detail_label: RichTextLabel
var _enhance_selected_item_label: RichTextLabel
var _enhance_material_label: RichTextLabel
var _enhance_progress_bar: ProgressBar
var _trade_confirm_popup: PanelContainer
var _trade_confirm_title: Label
var _trade_confirm_price: Label
var _trade_confirm_button: Button
var _trade_cancel_button: Button
var _enhance_filter_all_button: Button
var _enhance_filter_equipped_button: Button
var _buy_button: Button
var _sell_button: Button
var _enhance_button: Button

var _selected_shop_index: int = -1
var _selected_shop_item: EquipmentData
var _selected_sell_index: int = -1
var _selected_sell_item: EquipmentData
var _selected_enhance_item: EquipmentData
var _pending_trade_type: StringName = &""
var _pending_trade_index: int = -1
var _pending_trade_item: EquipmentData
var _pending_trade_price: int = 0
var _pending_trade_source_control: Control
var _shop_item_buttons: Array[Button] = []
var _sell_item_buttons: Array[Button] = []
var _last_enhance_result: Dictionary = {}
var _enhance_inventory_filter: StringName = &"all"
var _active_tab: StringName = &"shop"
var _enchant_animating: bool = false


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

	_hide_trade_confirm_popup()
	_shop_tab.visible = true
	_sell_tab.visible = false
	_enhance_tab.visible = false
	_apply_tab_state()
	_status_label.text = ""
	_status_label.modulate = STATUS_DEFAULT_COLOR


func show_sell_tab() -> void:
	_active_tab = &"sell"
	if _sell_tab == null:
		return

	_clear_pending_trade()
	_shop_tab.visible = false
	_sell_tab.visible = true
	_enhance_tab.visible = false
	_apply_tab_state()
	_status_label.text = ""
	_status_label.modulate = STATUS_DEFAULT_COLOR


func show_enhance_tab() -> void:
	_active_tab = &"enhance"
	if _enhance_tab == null:
		return

	_clear_pending_trade()
	_shop_tab.visible = false
	_sell_tab.visible = false
	_enhance_tab.visible = true
	_apply_tab_state()
	_status_label.text = ""
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
	_tab_shop_button.text = "Trade"
	_tab_shop_button.pressed.connect(show_shop_tab)
	tab_row.add_child(_tab_shop_button)

	_tab_sell_button = _create_tab_button("Sell")
	_tab_sell_button.visible = false
	_tab_sell_button.pressed.connect(show_sell_tab)

	_tab_enhance_button = _create_tab_button("Enchant")
	_tab_enhance_button.pressed.connect(show_enhance_tab)
	tab_row.add_child(_tab_enhance_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.modulate = STATUS_DEFAULT_COLOR
	tab_row.add_child(_status_label)

	_shop_tab = HBoxContainer.new()
	_shop_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_tab.add_theme_constant_override("separation", 10)
	root.add_child(_shop_tab)
	_build_shop_tab()

	_sell_tab = HBoxContainer.new()
	_sell_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sell_tab.add_theme_constant_override("separation", 10)
	root.add_child(_sell_tab)
	_build_sell_tab()

	_enhance_tab = HBoxContainer.new()
	_enhance_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enhance_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enhance_tab.add_theme_constant_override("separation", 10)
	root.add_child(_enhance_tab)
	_build_enhance_tab()


func _build_shop_tab() -> void:
	var player_panel := _create_section_panel(Vector2(TRADE_LIST_PANEL_MIN_WIDTH, 280))
	player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_panel.size_flags_stretch_ratio = 1.0
	var player_box := _create_section_box(player_panel)
	player_box.add_child(_create_section_title("Player inventory"))
	_sell_list = _create_grid_list()
	player_box.add_child(_wrap_scroll(_sell_list))
	_shop_tab.add_child(player_panel)

	var detail_panel := _create_section_panel(Vector2(TRADE_DETAIL_PANEL_MIN_WIDTH, 280))
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 0.72
	var detail_box := _create_section_box(detail_panel)
	var trade_title := _create_section_title("Trade")
	detail_box.add_child(trade_title)
	_shop_detail_label = _create_detail_label()
	_shop_detail_label.fit_content = true
	_shop_detail_label.scroll_active = false
	detail_box.add_child(_shop_detail_label)

	_buy_button = Button.new()
	_buy_button.custom_minimum_size = Vector2(0, 40)
	_buy_button.text = "Click an item to move it"
	_buy_button.disabled = true
	detail_box.add_child(_buy_button)
	_shop_tab.add_child(detail_panel)

	var stock_panel := _create_section_panel(Vector2(TRADE_LIST_PANEL_MIN_WIDTH, 280))
	stock_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stock_panel.size_flags_stretch_ratio = 1.0
	var stock_box := _create_section_box(stock_panel)
	stock_box.add_child(_create_section_title("Blacksmith inventory"))
	_shop_list = _create_grid_list()
	stock_box.add_child(_wrap_scroll(_shop_list))
	_shop_tab.add_child(stock_panel)

	_build_trade_confirm_popup()


func _build_sell_tab() -> void:
	var sell_panel := _create_section_panel(Vector2(300, 0))
	var sell_box := _create_section_box(sell_panel)
	sell_box.add_child(_create_section_title("Reserve Equipment"))
	var legacy_sell_list := _create_grid_list()
	sell_box.add_child(_wrap_scroll(legacy_sell_list))
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
	var enchant_layout := HBoxContainer.new()
	enchant_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enchant_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enchant_layout.add_theme_constant_override("separation", 14)
	_enhance_tab.add_child(enchant_layout)

	var inventory_panel := _create_section_panel(Vector2(300, 0))
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_panel.size_flags_stretch_ratio = 1.1
	var inventory_box := _create_section_box(inventory_panel)

	var inventory_header := HBoxContainer.new()
	inventory_header.add_theme_constant_override("separation", 8)
	inventory_box.add_child(inventory_header)

	var inventory_title := _create_section_title("Inventory")
	inventory_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	inventory_header.add_child(inventory_title)

	_enhance_filter_all_button = _create_tab_button("All")
	_enhance_filter_all_button.custom_minimum_size = Vector2(72, 28)
	_enhance_filter_all_button.pressed.connect(_set_enhance_filter.bind(&"all"))
	inventory_header.add_child(_enhance_filter_all_button)

	_enhance_filter_equipped_button = _create_tab_button("Equipped")
	_enhance_filter_equipped_button.custom_minimum_size = Vector2(92, 28)
	_enhance_filter_equipped_button.pressed.connect(_set_enhance_filter.bind(&"equipped"))
	inventory_header.add_child(_enhance_filter_equipped_button)

	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_box.add_child(inventory_scroll)

	_enhance_list = GridContainer.new()
	_enhance_list.columns = 2
	_enhance_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enhance_list.add_theme_constant_override("h_separation", 10)
	_enhance_list.add_theme_constant_override("v_separation", 10)
	inventory_scroll.add_child(_enhance_list)
	enchant_layout.add_child(inventory_panel)

	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(0, 0)
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 12)
	enchant_layout.add_child(left_column)

	var selection_row := HBoxContainer.new()
	selection_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_row.add_theme_constant_override("separation", 12)
	left_column.add_child(selection_row)

	_enhance_item_panel = _create_section_panel(Vector2(150, 190))
	var item_panel := _enhance_item_panel
	item_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var item_box := _create_section_box(item_panel)
	item_box.add_child(_create_section_title("Item chosen"))
	_enhance_selected_item_label = _create_detail_label()
	_enhance_selected_item_label.custom_minimum_size = Vector2(0, 120)
	_enhance_selected_item_label.scroll_active = false
	item_box.add_child(_enhance_selected_item_label)
	selection_row.add_child(item_panel)

	selection_row.add_child(_create_direction_label("←"))

	_enhance_material_panel = _create_section_panel(Vector2(150, 190))
	var material_panel := _enhance_material_panel
	material_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var material_box := _create_section_box(material_panel)
	material_box.add_child(_create_section_title("Material used to enchant"))
	_enhance_material_label = _create_detail_label()
	_enhance_material_label.custom_minimum_size = Vector2(0, 120)
	_enhance_material_label.scroll_active = false
	material_box.add_child(_enhance_material_label)
	selection_row.add_child(material_panel)

	var detail_panel := _create_section_panel(Vector2(0, 0))
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var detail_box := _create_section_box(detail_panel)
	_enhance_detail_label = _create_detail_label()
	_enhance_detail_label.custom_minimum_size = Vector2(0, 0)
	_enhance_detail_label.scroll_active = false
	_enhance_detail_label.visible = false
	detail_box.add_child(_enhance_detail_label)

	_enhance_progress_bar = ProgressBar.new()
	_enhance_progress_bar.min_value = 0.0
	_enhance_progress_bar.max_value = 100.0
	_enhance_progress_bar.value = 0.0
	_enhance_progress_bar.show_percentage = false
	_enhance_progress_bar.custom_minimum_size = Vector2(0, 8)
	_enhance_progress_bar.modulate.a = 0.35
	detail_box.add_child(_enhance_progress_bar)

	_enhance_button = Button.new()
	_enhance_button.custom_minimum_size = Vector2(180, 44)
	_enhance_button.text = "Enchant"
	_enhance_button.pressed.connect(_enhance_selected_item)
	detail_box.add_child(_enhance_button)
	left_column.add_child(detail_panel)


func _render_summary() -> void:
	_gold_label.text = "Gold: %d" % ExpeditionState.gold
	_ores_label.text = "Ores: %d" % ExpeditionState.ores


func _render_shop_inventory() -> void:
	_clear_children(_shop_list)
	_shop_item_buttons.clear()

	if BlacksmithState.current_shop_items.is_empty():
		_add_empty_label(_shop_list, "No blacksmith stock")
		return

	for index in range(BlacksmithState.current_shop_items.size()):
		var item := BlacksmithState.current_shop_items[index]
		var affordable := BlacksmithState.can_afford(item)
		var text := _format_trade_item_text(item.get_display_name(), item.get_slot_name(), "%d G" % item.get_purchase_price())
		var button := _create_item_button(item, text, index == _selected_shop_index)
		if not affordable:
			button.modulate = Color(1.0, 0.62, 0.62)
		button.pressed.connect(_request_buy_trade.bind(index, button))
		_shop_list.add_child(button)
		_shop_item_buttons.append(button)


func _render_sell_inventory() -> void:
	_clear_children(_sell_list)
	_sell_item_buttons.clear()
	var items := BlacksmithState.get_owned_sell_items()

	if items.is_empty():
		_add_empty_label(_sell_list, "No player gear to trade")
		return

	for index in range(items.size()):
		var item := items[index]
		var button := _create_item_button(
			item,
			_format_trade_item_text(item.get_display_name(), item.get_slot_name(), "%d G" % item.get_sell_value()),
			index == _selected_sell_index
		)
		button.pressed.connect(_request_sell_trade.bind(index, button))
		_sell_list.add_child(button)
		_sell_item_buttons.append(button)


func _render_enhance_inventory() -> void:
	_clear_children(_enhance_list)
	var items := _get_filtered_enhance_items()
	_apply_enhance_filter_state()

	if items.is_empty():
		_add_empty_label(_enhance_list, "No equipment in this view")
		return

	for item in items:
		var selected := item == _selected_enhance_item
		var button := _create_item_button(item, "%s\n%s  %s" % [
			item.get_display_name(),
			item.get_slot_name(),
			_get_enhancement_text(item),
		], selected)
		button.custom_minimum_size = Vector2(0, 80)
		button.pressed.connect(_select_enhance_item.bind(item))
		_enhance_list.add_child(button)


func _render_shop_details() -> void:
	_validate_pending_trade()
	_shop_detail_label.text = "\n".join([
		"[center][font_size=28][b]↔[/b][/font_size][/center]",
		"[center][color=%s]Click blacksmith items to prepare a purchase.[/color][/center]" % NEUTRAL_COLOR,
		"",
		"[center][color=%s]Click player items to prepare a sale.[/color][/center]" % NEUTRAL_COLOR,
		"",
		"[center][color=%s]Gold: %d[/color][/center]" % [NEUTRAL_COLOR, ExpeditionState.gold],
	])
	_buy_button.disabled = true
	_buy_button.text = "Click an item to choose a trade"
	_buy_button.visible = true
	_sync_trade_confirm_popup()


func _render_sell_details() -> void:
	if _sell_detail_label == null:
		return

	_sell_detail_label.text = ""
	if _sell_button != null:
		_sell_button.disabled = true
		_sell_button.text = "Sell"


func _render_enhance_details() -> void:
	if _selected_enhance_item == null:
		_enhance_selected_item_label.text = "[center][b]Empty slot[/b]\n\n[color=%s]Choose an item from the inventory panel.[/color][/center]" % MUTED_COLOR
		_enhance_material_label.text = "[center][b]Enchant Ore[/b]\n\n[color=%s]Available: %d[/color][/center]" % [
			NEUTRAL_COLOR,
			ExpeditionState.ores,
		]
		_enhance_detail_label.text = ""
		_enhance_progress_bar.value = 0.0
		_enhance_progress_bar.modulate.a = 0.35
		_enhance_button.disabled = _enchant_animating
		_enhance_button.text = "Enchant"
		return

	var cost := BlacksmithState.get_enhance_cost(_selected_enhance_item)
	var level := _get_enhancement_level(_selected_enhance_item)
	var maxed := level >= EquipmentInstance.MAX_ENHANCEMENT_LEVEL
	var affordable := ExpeditionState.ores >= cost
	var shatter_chance := _get_enchant_shatter_chance(level)
	var cost_color: String = NEUTRAL_COLOR if affordable else BAD_COLOR
	var bonus_summary := _get_enhancement_bonus_summary(_selected_enhance_item)
	_enhance_selected_item_label.text = "\n".join([
		"[center][font_size=18][color=%s][b]%s[/b][/color][/font_size][/center]" % [
			_selected_enhance_item.get_rarity_color().to_html(false),
			_selected_enhance_item.get_display_name(),
		],
		"[center][color=%s]%s[/color][/center]" % [MUTED_COLOR, _selected_enhance_item.get_slot_name()],
		"",
		"[center][b]Level %s[/b][/center]" % _get_enhancement_text(_selected_enhance_item),
		"[center][color=%s]%s[/color][/center]" % [GOOD_COLOR if bonus_summary != "No enhancement bonuses yet" else MUTED_COLOR, bonus_summary],
	])
	_enhance_material_label.text = "\n".join([
		"[center][b]Enchant Ore[/b][/center]",
		"",
		"[center][color=%s]Owned: %d[/color][/center]" % [NEUTRAL_COLOR, ExpeditionState.ores],
		"[center][color=%s]Cost: %d[/color][/center]" % [cost_color, cost],
		"[center][color=%s]Shatter: %.1f%%[/color][/center]" % [
			BAD_COLOR if shatter_chance > 0.0 else MUTED_COLOR,
			shatter_chance,
		],
	])
	_enhance_detail_label.text = ""
	if not _enchant_animating:
		_enhance_progress_bar.value = 0.0
		_enhance_progress_bar.modulate.a = 0.35
	_enhance_button.disabled = maxed or not affordable or _enchant_animating
	_enhance_button.text = "Infusing..." if _enchant_animating else ("Maxed" if maxed else "Enchant for %d Ore" % cost)


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


func _set_enhance_filter(filter_name: StringName) -> void:
	_enhance_inventory_filter = filter_name
	_status_label.text = ""
	refresh()


func _request_buy_trade(shop_index: int, source_control: Control) -> void:
	if shop_index < 0 or shop_index >= BlacksmithState.current_shop_items.size():
		_on_transaction_failed("That item is no longer available.")
		return

	var item := BlacksmithState.current_shop_items[shop_index]
	if item == null:
		_on_transaction_failed("That item is no longer available.")
		return

	_selected_shop_index = shop_index
	_selected_shop_item = item
	_selected_sell_index = -1
	_selected_sell_item = null
	_show_trade_confirm_popup(source_control, &"buy", shop_index, item, item.get_purchase_price())


func _request_sell_trade(inventory_index: int, source_control: Control) -> void:
	var items := BlacksmithState.get_owned_sell_items()
	if inventory_index < 0 or inventory_index >= items.size():
		_on_transaction_failed("That item is not in reserve.")
		return

	var item := items[inventory_index]
	if item == null:
		_on_transaction_failed("That item is not in reserve.")
		return

	_selected_sell_index = inventory_index
	_selected_sell_item = item
	_selected_shop_index = -1
	_selected_shop_item = null
	_show_trade_confirm_popup(source_control, &"sell", inventory_index, item, item.get_sell_value())


func _set_pending_trade(trade_type: StringName, item_index: int, item: EquipmentData, price: int, source_control: Control = null) -> void:
	_pending_trade_type = trade_type
	_pending_trade_index = item_index
	_pending_trade_item = item
	_pending_trade_price = price
	_pending_trade_source_control = source_control
	_status_label.text = ""
	refresh()


func _clear_pending_trade() -> void:
	_pending_trade_type = &""
	_pending_trade_index = -1
	_pending_trade_item = null
	_pending_trade_price = 0
	_pending_trade_source_control = null
	_selected_shop_index = -1
	_selected_shop_item = null
	_selected_sell_index = -1
	_selected_sell_item = null
	_hide_trade_confirm_popup()


func _validate_pending_trade() -> void:
	if _pending_trade_item == null:
		return

	if _is_pending_trade_valid():
		return

	_clear_pending_trade()


func _show_trade_confirm_popup(source_control: Control, trade_type: StringName, item_index: int, item: EquipmentData, price: int) -> void:
	_set_pending_trade(trade_type, item_index, item, price, source_control)
	_sync_trade_confirm_popup()


func _sync_trade_confirm_popup() -> void:
	if _trade_confirm_popup == null:
		return

	if _pending_trade_item == null or _active_tab != &"shop":
		_hide_trade_confirm_popup()
		return

	var source_control := _get_pending_trade_source_control()
	if source_control == null or not is_instance_valid(source_control):
		_hide_trade_confirm_popup()
		return

	_trade_confirm_title.text = "Buy?" if _pending_trade_type == &"buy" else "Sell?"
	_trade_confirm_price.text = "%d G" % _pending_trade_price
	_trade_confirm_popup.visible = true
	_trade_confirm_popup.reset_size()
	_trade_confirm_popup.size = Vector2.ZERO
	call_deferred("_deferred_position_trade_confirm_popup")


func _position_trade_confirm_popup(source_control: Control) -> void:
	if _trade_confirm_popup == null or not is_instance_valid(source_control):
		return

	var popup_size := _trade_confirm_popup.size
	if popup_size == Vector2.ZERO:
		popup_size = _trade_confirm_popup.get_combined_minimum_size()

	var anchor_margin := 8.0
	var button_position := source_control.global_position
	var button_size := source_control.size
	var popup_position := Vector2(
		button_position.x + button_size.x + anchor_margin,
		button_position.y + (button_size.y - popup_size.y) * 0.5
	)

	var page_rect := Rect2(global_position, size)
	if popup_position.x + popup_size.x > page_rect.position.x + page_rect.size.x - anchor_margin:
		popup_position.x = button_position.x - popup_size.x - anchor_margin
	if popup_position.x < page_rect.position.x + anchor_margin:
		popup_position.x = clamp(
			button_position.x + button_size.x * 0.5 - popup_size.x * 0.5,
			page_rect.position.x + anchor_margin,
			page_rect.position.x + page_rect.size.x - popup_size.x - anchor_margin
		)
	popup_position.y = clamp(
		popup_position.y,
		page_rect.position.y + anchor_margin,
		page_rect.position.y + page_rect.size.y - popup_size.y - anchor_margin
	)

	_trade_confirm_popup.global_position = popup_position.floor()


func _hide_trade_confirm_popup() -> void:
	if _trade_confirm_popup != null:
		_trade_confirm_popup.visible = false


func _get_pending_trade_source_control() -> Control:
	if _pending_trade_type == &"buy":
		if _pending_trade_index >= 0 and _pending_trade_index < _shop_item_buttons.size():
			return _shop_item_buttons[_pending_trade_index]
	elif _pending_trade_type == &"sell":
		if _pending_trade_index >= 0 and _pending_trade_index < _sell_item_buttons.size():
			return _sell_item_buttons[_pending_trade_index]

	return _pending_trade_source_control if is_instance_valid(_pending_trade_source_control) else null


func _deferred_position_trade_confirm_popup() -> void:
	if _pending_trade_item == null or _active_tab != &"shop":
		return

	var source_control := _get_pending_trade_source_control()
	if source_control != null:
		_position_trade_confirm_popup(source_control)


func _is_pending_trade_valid() -> bool:
	if _pending_trade_item == null:
		return false

	if _pending_trade_type == &"buy":
		if _pending_trade_index >= 0 and _pending_trade_index < BlacksmithState.current_shop_items.size():
			if BlacksmithState.current_shop_items[_pending_trade_index] == _pending_trade_item:
				_pending_trade_price = _pending_trade_item.get_purchase_price()
				return true
		return false

	if _pending_trade_type == &"sell":
		var items := BlacksmithState.get_owned_sell_items()
		if _pending_trade_index >= 0 and _pending_trade_index < items.size():
			if items[_pending_trade_index] == _pending_trade_item:
				_pending_trade_price = _pending_trade_item.get_sell_value()
				return true
		return false

	return false


func _on_confirm_trade_pressed() -> void:
	if _pending_trade_item == null:
		return

	if not _is_pending_trade_valid():
		var message := "That item is no longer available." if _pending_trade_type == &"buy" else "That item is not in reserve."
		_clear_pending_trade()
		_status_label.text = message
		refresh()
		return

	var traded := false
	match _pending_trade_type:
		&"buy":
			traded = _buy_selected_item(_pending_trade_index)
		&"sell":
			traded = _sell_selected_item(_pending_trade_index)

	if not traded:
		_clear_pending_trade()
		refresh()


func _on_cancel_trade_pressed() -> void:
	_clear_pending_trade()
	_status_label.text = "Trade cancelled."
	_status_label.modulate = STATUS_DEFAULT_COLOR
	refresh()


func _buy_selected_item(shop_index: int = -1) -> bool:
	if shop_index >= 0:
		_selected_shop_index = shop_index
	if _selected_shop_index < 0:
		return false

	if BlacksmithState.buy_item(_selected_shop_index):
		_status_label.text = "Bought item from blacksmith."
		_status_label.modulate = STATUS_DEFAULT_COLOR
		_clear_pending_trade()
		inventory_changed.emit()
		refresh()
		return true

	return false


func _sell_selected_item(inventory_index: int = -1) -> bool:
	if inventory_index >= 0:
		_selected_sell_index = inventory_index
	if _selected_sell_index < 0:
		return false

	if BlacksmithState.sell_inventory_item(_selected_sell_index):
		_status_label.text = "Sold item to blacksmith."
		_status_label.modulate = STATUS_DEFAULT_COLOR
		_clear_pending_trade()
		if _selected_enhance_item != null and not _is_item_owned(_selected_enhance_item):
			_selected_enhance_item = null
		inventory_changed.emit()
		refresh()
		return true

	return false


func _enhance_selected_item() -> void:
	if _selected_enhance_item == null or _enchant_animating:
		return

	_enchant_animating = true
	if _enhance_button != null:
		_enhance_button.disabled = true
		_enhance_button.text = "Infusing..."
	if _enhance_progress_bar != null:
		_enhance_progress_bar.value = 0.0
		_enhance_progress_bar.modulate.a = 1.0
		var progress_tween := create_tween()
		progress_tween.tween_property(_enhance_progress_bar, "value", 100.0, ENCHANT_CAST_TIME)
		await progress_tween.finished

	var result := BlacksmithState.enhance_item(_selected_enhance_item)
	_last_enhance_result = result
	_status_label.text = _format_enhance_result(result)
	_status_label.modulate = _get_enchant_result_color(result)
	if bool(result.get("broke", false)):
		_selected_enhance_item = null
	inventory_changed.emit()
	refresh()
	await _play_enchant_animation(result)
	_enchant_animating = false
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
			var item := result.get("item", null) as EquipmentData
			return "%s improved: %s" % [
				item.get_display_name() if item != null else "Item",
				_format_stat_changes(stat_changes),
			]
		"broke":
			var item := result.get("item", null) as EquipmentData
			return "%s shattered during infusion." % (item.get_display_name() if item != null else "The item")
		"maxed":
			return "This item is already fully infused."
		"insufficient_ores":
			return "Not enough ores."
		"invalid_item":
			return "Choose an item to enchant."
		_:
			return "Enhancement failed."


func _format_enhance_result_bbcode(result: Dictionary) -> String:
	var color := _get_enchant_result_color(result)
	return "[color=%s]%s[/color]" % [color.to_html(false), _format_enhance_result(result)]


func _format_stat_changes(stat_changes: Dictionary) -> String:
	var lines: Array[String] = []
	for stat_key in stat_changes.keys():
		lines.append("+%d %s" % [int(stat_changes[stat_key]), _get_stat_display_name(StringName(stat_key))])
	return ", ".join(lines) if not lines.is_empty() else "No visible stat change"


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
	_status_label.modulate = Color.html(BAD_COLOR)


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


func _get_enchant_shatter_chance(level: int) -> float:
	return clamp((float(level) - 8.0) * 0.6, 0.0, 38.0)


func _get_enchant_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"common", "solid":
			return Color(0.78, 0.80, 0.82)
		"uncommon":
			return Color(0.40, 0.86, 0.50)
		"rare", "great":
			return Color(0.38, 0.62, 1.0)
		"epic":
			return Color(0.75, 0.45, 1.0)
		"legendary", "exceptional":
			return Color(1.0, 0.72, 0.24)
		_:
			return Color.html(NEUTRAL_COLOR)


func _get_enchant_result_color(result: Dictionary) -> Color:
	if String(result.get("status", "")) == "success":
		var quality_color := String(result.get("enhancement_quality_color", ""))
		if quality_color != "":
			return Color.html(quality_color)
		return _get_enchant_rarity_color(String(result.get("enhancement_quality", "Solid")))

	match String(result.get("status", "")):
		"broke", "insufficient_ores":
			return Color.html(BAD_COLOR)
		"maxed":
			return Color.html(MUTED_COLOR)
		_:
			return Color.html(NEUTRAL_COLOR)


func _get_enchant_result_color_bbcode(result: Dictionary) -> String:
	return _get_enchant_result_color(result).to_html(false)


func _get_enchant_animation_message(result: Dictionary) -> String:
	match String(result.get("status", "")):
		"success":
			var quality := String(result.get("enhancement_quality", "Enchanted"))
			return "%s!" % quality
		"broke":
			return "Shattered!"
		"insufficient_ores":
			return "No Ore"
		"maxed":
			return "Maxed"
		_:
			return "Enchanted"


func _play_enchant_animation(result: Dictionary) -> Signal:
	var color := _get_enchant_result_color(result)

	var tween := create_tween()
	if _enhance_item_panel != null:
		_enhance_item_panel.modulate = Color.WHITE
		tween.tween_property(_enhance_item_panel, "modulate", color.lightened(0.35), 0.12)
		tween.tween_property(_enhance_item_panel, "modulate", Color.WHITE, 0.22)

	if _enhance_material_panel != null:
		_enhance_material_panel.modulate = Color.WHITE
		var material_tween := create_tween()
		material_tween.tween_property(_enhance_material_panel, "modulate", color.lightened(0.2), 0.1)
		material_tween.tween_property(_enhance_material_panel, "modulate", Color.WHITE, 0.24)

	if _enhance_button != null:
		_enhance_button.modulate = Color.WHITE
		var button_tween := create_tween()
		button_tween.tween_property(_enhance_button, "modulate", color.lightened(0.25), 0.12)
		button_tween.tween_property(_enhance_button, "modulate", Color.WHITE, 0.24)

	var feedback_label := Label.new()
	feedback_label.top_level = true
	feedback_label.text = _get_enchant_animation_message(result)
	feedback_label.modulate = color
	feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_label.add_theme_font_size_override("font_size", 18)
	add_child(feedback_label)
	if _enhance_item_panel != null:
		feedback_label.global_position = _enhance_item_panel.global_position + Vector2(18, 18)

	var label_tween := create_tween()
	label_tween.set_parallel(true)
	label_tween.tween_property(feedback_label, "global_position", feedback_label.global_position + Vector2(0, -24), 0.45)
	label_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.45)
	label_tween.finished.connect(feedback_label.queue_free)
	return tween.finished


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


func _get_filtered_enhance_items() -> Array[EquipmentData]:
	var all_items: Array[EquipmentData] = []
	for item in ExpeditionState.inventory:
		if item != null:
			all_items.append(item)

	for item in ExpeditionState.equipped_gear.values():
		var equipment_item := item as EquipmentData
		if equipment_item != null and not all_items.has(equipment_item):
			all_items.append(equipment_item)

	if _enhance_inventory_filter == &"equipped":
		var equipped_items: Array[EquipmentData] = []
		for item in ExpeditionState.equipped_gear.values():
			var equipment_item := item as EquipmentData
			if equipment_item != null:
				equipped_items.append(equipment_item)
		return equipped_items

	return all_items


func _apply_enhance_filter_state() -> void:
	if _enhance_filter_all_button != null:
		_enhance_filter_all_button.disabled = _enhance_inventory_filter == &"all"
	if _enhance_filter_equipped_button != null:
		_enhance_filter_equipped_button.disabled = _enhance_inventory_filter == &"equipped"


func _on_state_changed() -> void:
	if is_inside_tree():
		refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _trade_confirm_popup != null and _trade_confirm_popup.visible:
		var source_control := _get_pending_trade_source_control()
		if source_control != null:
			_position_trade_confirm_popup(source_control)


func _process(_delta: float) -> void:
	if _trade_confirm_popup == null or not _trade_confirm_popup.visible:
		return

	var source_control := _get_pending_trade_source_control()
	if source_control != null:
		_position_trade_confirm_popup(source_control)


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


func _create_direction_label(text: String) -> Label:
	var arrow_label := Label.new()
	arrow_label.text = text
	arrow_label.custom_minimum_size = Vector2(42, 0)
	arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow_label.add_theme_font_size_override("font_size", 28)
	arrow_label.modulate = Color(0.88, 0.88, 0.9)
	return arrow_label


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


func _create_item_button(item: EquipmentData, text: String, selected: bool = false) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, TRADE_ITEM_CARD_HEIGHT)
	button.size = Vector2(0, TRADE_ITEM_CARD_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
		_truncate_text(name_text, TRADE_ITEM_NAME_MAX_CHARS),
		_truncate_text(meta_text, TRADE_ITEM_META_MAX_CHARS),
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
