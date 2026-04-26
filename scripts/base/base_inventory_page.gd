class_name BaseInventoryPage
extends Control

const GOOD_COLOR := "#7ee787"
const MUTED_COLOR := "#8b949e"
const NEUTRAL_COLOR := "#c9d1d9"
const PANEL_COLOR := Color(0.095, 0.10, 0.11, 1.0)
const PANEL_BORDER := Color(0.34, 0.36, 0.38, 0.9)
const ROW_NORMAL := Color(0.13, 0.135, 0.145, 1.0)
const ROW_HOVER := Color(0.18, 0.19, 0.20, 1.0)
const ROW_SELECTED := Color(0.23, 0.205, 0.12, 1.0)
const ROW_BORDER := Color(0.42, 0.44, 0.46, 0.55)
const PANEL_PADDING := 11
const SECTION_SPACING := 9
const INVENTORY_PANEL_MIN_WIDTH := 360
const DETAILS_PANEL_WIDTH := 310
const CONTENT_PANEL_HEIGHT := 420
const INVENTORY_CARD_HEIGHT := 76

const FILTER_ALL := &"all"
const FILTER_CONSUMABLES := &"consumables"
const FILTER_POTIONS := &"potions"
const FILTER_MATERIALS := &"materials"
const FILTER_MYSTERIOUS := &"mysterious_ingredients"
const FILTER_BOTTLES := &"bottles"
const FILTER_MONSTER := &"monster_materials"

const SORT_NAME := &"name"
const SORT_RARITY := &"rarity"
const SORT_TYPE := &"type"
const SORT_VALUE := &"value"

var _inventory_title: Label
var _item_list: VBoxContainer
var _details_label: RichTextLabel
var _summary_label: Label
var _sort_option: OptionButton
var _filter_buttons: Dictionary = {}

var _selected_item: ItemData
var _selected_inventory_index: int = -1
var _selected_stack_key: String = ""
var _selected_stack_quantity: int = 0
var _selected_button: Button
var _active_filter: StringName = FILTER_ALL
var _active_sort: StringName = SORT_NAME


func _ready() -> void:
	_build_ui()
	_connect_state()
	refresh()


func refresh() -> void:
	_validate_selection()
	_render_inventory()
	_render_details()


func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title := Label.new()
	title.text = "Inventory"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary_label.modulate = Color.html(NEUTRAL_COLOR)
	header.add_child(_summary_label)

	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_theme_constant_override("separation", 12)
	root.add_child(content)

	content.add_child(_build_inventory_column())
	content.add_child(_build_details_column())


func _build_inventory_column() -> PanelContainer:
	var panel := _create_section_panel(Vector2(INVENTORY_PANEL_MIN_WIDTH, CONTENT_PANEL_HEIGHT))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := _create_section_box(panel)

	_inventory_title = _create_section_title("All Items")
	box.add_child(_inventory_title)

	var filter_row_top := HBoxContainer.new()
	filter_row_top.add_theme_constant_override("separation", 7)
	filter_row_top.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(filter_row_top)
	_add_filter_button(filter_row_top, "All", FILTER_ALL)
	_add_filter_button(filter_row_top, "Consumables", FILTER_CONSUMABLES)
	_add_filter_button(filter_row_top, "Potions", FILTER_POTIONS)
	_add_filter_button(filter_row_top, "Materials", FILTER_MATERIALS)

	var filter_row_bottom := HBoxContainer.new()
	filter_row_bottom.add_theme_constant_override("separation", 7)
	filter_row_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(filter_row_bottom)
	_add_filter_button(filter_row_bottom, "Mysterious", FILTER_MYSTERIOUS)
	_add_filter_button(filter_row_bottom, "Bottles", FILTER_BOTTLES)
	_add_filter_button(filter_row_bottom, "Monster Mats", FILTER_MONSTER)

	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 8)
	box.add_child(sort_row)

	var sort_label := Label.new()
	sort_label.text = "Sort"
	sort_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sort_label.modulate = Color.html(MUTED_COLOR)
	sort_row.add_child(sort_label)

	_sort_option = OptionButton.new()
	_sort_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sort_option.add_item("Name")
	_sort_option.set_item_metadata(0, SORT_NAME)
	_sort_option.add_item("Rarity")
	_sort_option.set_item_metadata(1, SORT_RARITY)
	_sort_option.add_item("Type")
	_sort_option.set_item_metadata(2, SORT_TYPE)
	_sort_option.add_item("Value")
	_sort_option.set_item_metadata(3, SORT_VALUE)
	_sort_option.item_selected.connect(_on_sort_selected)
	sort_row.add_child(_sort_option)

	_item_list = _create_list()
	box.add_child(_wrap_scroll(_item_list))
	return panel


func _build_details_column() -> PanelContainer:
	var panel := _create_section_panel(Vector2(DETAILS_PANEL_WIDTH, CONTENT_PANEL_HEIGHT))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := _create_section_box(panel)
	box.add_child(_create_section_title("Details"))

	_details_label = _create_detail_label()
	_details_label.custom_minimum_size = Vector2(0, 320)
	_details_label.scroll_active = true
	box.add_child(_details_label)
	return panel


func _render_inventory() -> void:
	_clear_children(_item_list)
	_apply_filter_button_state()

	var entries := _get_visible_entries()
	_inventory_title.text = _get_filter_title()
	_summary_label.text = _format_inventory_summary(entries)

	if entries.is_empty():
		_add_empty_label(_item_list, "No items in this view")
		return

	for entry in entries:
		var item := entry["item"] as ItemData
		var inventory_index := int(entry["index"])
		var quantity := int(entry.get("quantity", 1))
		var stack_key := String(entry.get("stack_key", ""))
		var display_name := item.get_display_name()
		if quantity > 1:
			display_name = "%s x%d" % [display_name, quantity]
		var row_text := "%s\n%s  %d G" % [
			display_name,
			item.get_item_category_name(),
			item.get_sell_value() * quantity,
		]
		var button := _create_item_button(item, row_text)
		button.pressed.connect(_select_item.bind(inventory_index, item, quantity, stack_key, button))
		_item_list.add_child(button)

		if _selected_inventory_index == inventory_index and _selected_stack_key == stack_key:
			_select_button(button)


func _render_details() -> void:
	if _selected_item == null:
		_details_label.text = "[font_size=20][b]Select item[/b][/font_size]\n\n[color=%s]Choose a consumable or material to inspect it.[/color]" % MUTED_COLOR
		return

	var lines: Array[String] = [
		"[font_size=22][color=%s][b]%s[/b][/color][/font_size]" % [_selected_item.get_rarity_color().to_html(false), _selected_item.get_display_name()],
		"[color=%s]%s %s[/color]" % [MUTED_COLOR, _selected_item.get_rarity_name(), _selected_item.get_item_category_name()],
		"",
		_selected_item.description,
		"",
		"[b]Quantity[/b]",
		"[color=%s]%d[/color]" % [NEUTRAL_COLOR, max(1, _selected_stack_quantity)],
		"",
		"[b]Value[/b]",
		"[color=%s]Gold Value: %d[/color]" % [NEUTRAL_COLOR, _selected_item.get_purchase_price()],
		"[color=%s]Sell Value: %d[/color]" % [NEUTRAL_COLOR, _selected_item.get_sell_value()],
	]
	if _selected_stack_quantity > 1:
		lines.append("[color=%s]Stack Sell Value: %d[/color]" % [NEUTRAL_COLOR, _selected_item.get_sell_value() * _selected_stack_quantity])

	var material := _selected_item as MaterialData
	if material != null:
		lines.append("")
		lines.append("[b]Material[/b]")
		lines.append("[color=%s]%s[/color]" % [GOOD_COLOR, material.get_item_category_name()])
		lines.append("[color=%s]Type: %s[/color]" % [NEUTRAL_COLOR, _format_material_type(material.material_type)])

	var potion := _selected_item as PotionData
	if potion != null:
		lines.append("")
		lines.append("[b]Effects[/b]")
		lines.append("[color=%s]%s[/color]" % [GOOD_COLOR, potion.get_detail_summary()])
	elif material == null:
		lines.append("")
		lines.append("[b]Effects[/b]")
		lines.append("[color=%s]%s[/color]" % [GOOD_COLOR, _selected_item.get_detail_summary()])

	_details_label.text = "\n".join(lines)


func _select_item(inventory_index: int, item: ItemData, quantity: int, stack_key: String, button: Button) -> void:
	if inventory_index < 0 or inventory_index >= ExpeditionState.item_inventory.size():
		return

	_selected_inventory_index = inventory_index
	_selected_item = item
	_selected_stack_quantity = max(1, quantity)
	_selected_stack_key = stack_key
	_select_button(button)
	_render_details()


func _get_visible_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var material_stacks: Dictionary = {}
	for index in range(ExpeditionState.item_inventory.size()):
		var item := ExpeditionState.item_inventory[index] as ItemData
		if item == null or not _matches_filter(item):
			continue

		var material := item as MaterialData
		if material != null:
			var stack_key := _get_material_stack_key(material)
			if material_stacks.has(stack_key):
				var stack_entry := material_stacks[stack_key] as Dictionary
				stack_entry["quantity"] = int(stack_entry["quantity"]) + 1
				var stack_indices := stack_entry["indices"] as Array
				stack_indices.append(index)
				continue

			var entry := {
				"index": index,
				"item": item,
				"quantity": 1,
				"indices": [index],
				"stack_key": stack_key,
			}
			material_stacks[stack_key] = entry
			entries.append(entry)
			continue

		entries.append({
			"index": index,
			"item": item,
			"quantity": 1,
			"indices": [index],
			"stack_key": "item:%d" % index,
		})

	_sort_entries(entries)
	return entries


func _matches_filter(item: ItemData) -> bool:
	match _active_filter:
		FILTER_ALL:
			return true
		FILTER_CONSUMABLES:
			return item is PotionData or not (item is MaterialData)
		FILTER_POTIONS:
			return item is PotionData
		FILTER_MATERIALS:
			return item is MaterialData
		FILTER_MYSTERIOUS:
			var mysterious := item as MaterialData
			return mysterious != null and mysterious.material_type == MaterialData.TYPE_MYSTERIOUS_INGREDIENT
		FILTER_BOTTLES:
			var bottle := item as MaterialData
			return bottle != null and bottle.material_type == MaterialData.TYPE_BOTTLE
		FILTER_MONSTER:
			var monster := item as MaterialData
			return monster != null and monster.material_type == MaterialData.TYPE_MONSTER_MATERIAL
		_:
			return true


func _sort_entries(entries: Array[Dictionary]) -> void:
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_item := left["item"] as ItemData
		var right_item := right["item"] as ItemData
		if left_item == null or right_item == null:
			return false

		match _active_sort:
			SORT_RARITY:
				if left_item.rarity == right_item.rarity:
					return left_item.get_display_name().to_lower() < right_item.get_display_name().to_lower()
				return int(left_item.rarity) > int(right_item.rarity)
			SORT_TYPE:
				if left_item.get_item_category_name() == right_item.get_item_category_name():
					return left_item.get_display_name().to_lower() < right_item.get_display_name().to_lower()
				return left_item.get_item_category_name().to_lower() < right_item.get_item_category_name().to_lower()
			SORT_VALUE:
				var left_value := left_item.get_sell_value() * int(left.get("quantity", 1))
				var right_value := right_item.get_sell_value() * int(right.get("quantity", 1))
				if left_value == right_value:
					return left_item.get_display_name().to_lower() < right_item.get_display_name().to_lower()
				return left_value > right_value
			_:
				return left_item.get_display_name().to_lower() < right_item.get_display_name().to_lower()
	)


func _add_filter_button(parent: HBoxContainer, text: String, filter: StringName) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(86, 30)
	button.text = text
	button.pressed.connect(_set_filter.bind(filter))
	parent.add_child(button)
	_filter_buttons[filter] = button


func _set_filter(filter: StringName) -> void:
	_active_filter = filter
	_selected_item = null
	_selected_inventory_index = -1
	_selected_stack_key = ""
	_selected_stack_quantity = 0
	_selected_button = null
	refresh()


func _on_sort_selected(index: int) -> void:
	_active_sort = StringName(_sort_option.get_item_metadata(index))
	refresh()


func _apply_filter_button_state() -> void:
	for filter in _filter_buttons.keys():
		var button := _filter_buttons[filter] as Button
		if button != null:
			button.disabled = filter == _active_filter


func _validate_selection() -> void:
	if _selected_inventory_index < 0:
		return

	var entries := _get_visible_entries()
	for entry in entries:
		if String(entry.get("stack_key", "")) != _selected_stack_key:
			continue
		var item := entry["item"] as ItemData
		if item == _selected_item:
			_selected_inventory_index = int(entry["index"])
			_selected_stack_quantity = int(entry.get("quantity", 1))
			return

	_selected_item = null
	_selected_inventory_index = -1
	_selected_stack_key = ""
	_selected_stack_quantity = 0
	_selected_button = null


func _get_filter_title() -> String:
	match _active_filter:
		FILTER_CONSUMABLES:
			return "Consumables"
		FILTER_POTIONS:
			return "Potions"
		FILTER_MATERIALS:
			return "Materials"
		FILTER_MYSTERIOUS:
			return "Mysterious Ingredients"
		FILTER_BOTTLES:
			return "Bottles"
		FILTER_MONSTER:
			return "Monster Materials"
		_:
			return "All Items"


func _format_material_type(material_type: StringName) -> String:
	match material_type:
		MaterialData.TYPE_MYSTERIOUS_INGREDIENT:
			return "Mysterious Ingredient"
		MaterialData.TYPE_BOTTLE:
			return "Bottle"
		MaterialData.TYPE_MONSTER_MATERIAL:
			return "Monster Material"
		_:
			return String(material_type).capitalize()


func _get_material_stack_key(material: MaterialData) -> String:
	return "material:%s" % String(material.item_id)


func _format_inventory_summary(entries: Array[Dictionary]) -> String:
	var total_count := 0
	for entry in entries:
		total_count += int(entry.get("quantity", 1))

	if entries.size() == total_count:
		return "%d item%s" % [total_count, "" if total_count == 1 else "s"]

	return "%d stack%s, %d item%s" % [
		entries.size(),
		"" if entries.size() == 1 else "s",
		total_count,
		"" if total_count == 1 else "s",
	]


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
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _create_style(PANEL_COLOR, PANEL_BORDER, 1, 8))
	return panel


func _create_section_box(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_PADDING)
	margin.add_theme_constant_override("margin_top", PANEL_PADDING)
	margin.add_theme_constant_override("margin_right", PANEL_PADDING)
	margin.add_theme_constant_override("margin_bottom", PANEL_PADDING)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", SECTION_SPACING)
	margin.add_child(box)
	return box


func _create_section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
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
	list.add_theme_constant_override("separation", 8)
	return list


func _wrap_scroll(list: VBoxContainer) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	scroll.add_child(list)
	return scroll


func _create_item_button(item: ItemData, text: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, INVENTORY_CARD_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var border_color := item.get_rarity_color() if item != null else ROW_BORDER
	button.set_meta("rarity_border_color", border_color)
	_apply_row_style(button, ROW_NORMAL, border_color, 1)
	button.mouse_entered.connect(_on_row_hovered.bind(button, true))
	button.mouse_exited.connect(_on_row_hovered.bind(button, false))
	return button


func _on_row_hovered(button: Button, hovered: bool) -> void:
	if button == _selected_button:
		return

	var background := ROW_HOVER if hovered else ROW_NORMAL
	_apply_row_style(button, background, _get_button_border_color(button), 1)


func _apply_row_style(button: Button, background_color: Color, border_color: Color, border_width: int) -> void:
	button.add_theme_stylebox_override("normal", _create_style(background_color, border_color, border_width, 6))
	button.add_theme_stylebox_override("hover", _create_style(ROW_HOVER, border_color, border_width, 6))
	button.add_theme_stylebox_override("pressed", _create_style(ROW_SELECTED, border_color, 2, 6))


func _get_button_border_color(button: Button) -> Color:
	return button.get_meta("rarity_border_color", ROW_BORDER) as Color


func _add_empty_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 120)
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
	style.set_content_margin(SIDE_TOP, 8)
	style.set_content_margin(SIDE_BOTTOM, 8)
	return style


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
