class_name MainBaseController
extends Control

signal start_dungeon_requested

const BlacksmithPageScene := preload("res://scripts/base/blacksmith_page.gd")
const BaseEquipmentPageScene := preload("res://scripts/base/base_equipment_page.gd")
const BaseInventoryPageScene := preload("res://scripts/base/base_inventory_page.gd")
const WitchPageScene := preload("res://scripts/base/witch_page.gd")
const DEBUG_MATERIALS_DIR := "res://data/materials"

@onready var gold_label: Label = %GoldLabel
@onready var monster_materials_label: Label = %MonsterMaterialsLabel
@onready var ores_label: Label = %OresLabel
@onready var herbs_label: Label = %HerbsLabel
@onready var streak_label: Label = %StreakLabel
@onready var start_dungeon_button: Button = %StartDungeonButton
@onready var equipment_button: Button = %EquipmentButton
@onready var inventory_button: Button = %InventoryButton
@onready var blacksmith_button: Button = %BlacksmithButton
@onready var witch_button: Button = %WitchButton
@onready var librarian_button: Button = %LibrarianButton
@onready var quest_board_button: Button = %QuestBoardButton
@onready var debug_mode_button: Button = %DebugModeButton
@onready var service_title_label: Label = %ServiceTitleLabel
@onready var service_body_label: Label = %ServiceBodyLabel
@onready var service_box: VBoxContainer = service_title_label.get_parent() as VBoxContainer

var expedition_state
var blacksmith_page: BlacksmithPage
var equipment_page: BaseEquipmentPage
var inventory_page: BaseInventoryPage
var witch_page: WitchPage


func _ready() -> void:
	start_dungeon_button.pressed.connect(func(): start_dungeon_requested.emit())
	equipment_button.pressed.connect(_show_equipment)
	inventory_button.pressed.connect(_show_inventory)
	blacksmith_button.pressed.connect(_show_blacksmith)
	witch_button.pressed.connect(_show_witch)
	librarian_button.pressed.connect(_show_placeholder.bind("Librarian", "Manage skill books and research. TODO."))
	quest_board_button.pressed.connect(_show_placeholder.bind("Quest Board", "Choose objectives and claims. TODO."))
	debug_mode_button.pressed.connect(_on_debug_mode_pressed)
	_build_equipment_page()
	_build_inventory_page()
	_build_blacksmith_page()
	_build_witch_page()
	_show_placeholder("Prepare", "Choose a base service from the left.")
	_refresh_expedition_summary()


func set_player_profile(profile: PlayerProfileData) -> void:
	if expedition_state == null:
		expedition_state = profile
	if is_node_ready():
		_refresh_expedition_summary()


func set_expedition_state(state) -> void:
	expedition_state = state
	if is_node_ready():
		_refresh_expedition_summary()


func _refresh_expedition_summary() -> void:
	if expedition_state == null:
		gold_label.text = "Gold: 0"
		monster_materials_label.text = "Monster Materials: 0"
		ores_label.text = "Ores: 0"
		herbs_label.text = "Herbs: 0"
		start_dungeon_button.text = "Start Expedition"
		streak_label.text = "Expedition: Not started"
		return

	gold_label.text = "Gold: %d" % _get_state_value("gold", 0)
	monster_materials_label.text = "Monster Materials: %d" % _get_state_value("monster_materials", 0)
	ores_label.text = "Ores: %d" % _get_state_value("ores", 0)
	herbs_label.text = "Herbs: %d" % _get_state_value("herbs", 0)

	if _get_state_value("is_active", false):
		start_dungeon_button.text = "Enter Dungeon %d" % _get_state_value("dungeon_index", 0)
		streak_label.text = "Dungeon: %d/%d" % [
			_get_state_value("dungeon_index", 0),
			_get_state_value("max_dungeons", 10),
		]
	elif _get_state_value("is_complete", false):
		start_dungeon_button.text = "Start Expedition"
		streak_label.text = "Expedition: Complete"
	elif _get_state_value("is_failed", false):
		start_dungeon_button.text = "Start Expedition"
		streak_label.text = "Expedition: Failed"
	else:
		start_dungeon_button.text = "Start Expedition"
		streak_label.text = "Expedition: Not started"


func _show_placeholder(title: String, body: String) -> void:
	_hide_content_pages()
	service_title_label.show()
	service_body_label.show()
	service_title_label.text = title
	service_body_label.text = body


func _show_blacksmith() -> void:
	_hide_content_pages()
	BlacksmithState.ensure_inventory(_get_state_value("blacksmith_refresh_counter", 0))
	if blacksmith_page != null:
		blacksmith_page.refresh()
		blacksmith_page.show()


func _show_equipment() -> void:
	_hide_content_pages()
	if equipment_page != null:
		equipment_page.refresh()
		equipment_page.show()


func _show_inventory() -> void:
	_hide_content_pages()
	if inventory_page != null:
		inventory_page.refresh()
		inventory_page.show()


func _show_witch() -> void:
	_hide_content_pages()
	WitchState.ensure_inventory()
	if witch_page != null:
		witch_page.refresh()
		witch_page.show()


func _hide_content_pages() -> void:
	service_title_label.hide()
	service_body_label.hide()
	if blacksmith_page != null:
		blacksmith_page.hide()
	if equipment_page != null:
		equipment_page.hide()
	if inventory_page != null:
		inventory_page.hide()
	if witch_page != null:
		witch_page.hide()


func _build_equipment_page() -> void:
	if service_box == null:
		return

	equipment_page = BaseEquipmentPageScene.new()
	equipment_page.hide()
	equipment_page.inventory_changed.connect(_refresh_expedition_summary)
	service_box.add_child(equipment_page)


func _build_inventory_page() -> void:
	if service_box == null:
		return

	inventory_page = BaseInventoryPageScene.new()
	inventory_page.hide()
	service_box.add_child(inventory_page)


func _build_blacksmith_page() -> void:
	if service_box == null:
		return

	blacksmith_page = BlacksmithPageScene.new()
	blacksmith_page.hide()
	blacksmith_page.inventory_changed.connect(_refresh_expedition_summary)
	service_box.add_child(blacksmith_page)


func _build_witch_page() -> void:
	if service_box == null:
		return

	witch_page = WitchPageScene.new()
	witch_page.hide()
	witch_page.inventory_changed.connect(_refresh_expedition_summary)
	service_box.add_child(witch_page)


func _on_debug_mode_pressed() -> void:
	ExpeditionState.add_gold(10)
	ExpeditionState.add_resource(ExpeditionState.RESOURCE_MONSTER_MATERIALS, 10)
	ExpeditionState.add_resource(ExpeditionState.RESOURCE_ORES, 10)
	ExpeditionState.add_resource(ExpeditionState.RESOURCE_HERBS, 10)

	for material in _load_debug_materials():
		for _copy_index in range(10):
			ExpeditionState.add_item(material)

	_refresh_expedition_summary()
	if blacksmith_page != null and blacksmith_page.visible:
		blacksmith_page.refresh()
	if equipment_page != null and equipment_page.visible:
		equipment_page.refresh()
	if inventory_page != null and inventory_page.visible:
		inventory_page.refresh()
	if witch_page != null and witch_page.visible:
		witch_page.refresh()


func _load_debug_materials() -> Array[MaterialData]:
	var materials: Array[MaterialData] = []
	var dir := DirAccess.open(DEBUG_MATERIALS_DIR)
	if dir == null:
		push_warning("Missing debug materials directory: %s" % DEBUG_MATERIALS_DIR)
		return materials

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var material := load("%s/%s" % [DEBUG_MATERIALS_DIR, file_name]) as MaterialData
			if material != null:
				materials.append(material)
		file_name = dir.get_next()
	dir.list_dir_end()
	return materials


func _get_state_value(property_name: StringName, fallback: Variant) -> Variant:
	if expedition_state == null:
		return fallback

	var value: Variant = expedition_state.get(property_name)
	if value == null:
		return fallback

	return value
