class_name MainBaseController
extends Control

signal start_dungeon_requested

@onready var gold_label: Label = %GoldLabel
@onready var monster_materials_label: Label = %MonsterMaterialsLabel
@onready var ores_label: Label = %OresLabel
@onready var herbs_label: Label = %HerbsLabel
@onready var streak_label: Label = %StreakLabel
@onready var start_dungeon_button: Button = %StartDungeonButton
@onready var blacksmith_button: Button = %BlacksmithButton
@onready var witch_button: Button = %WitchButton
@onready var librarian_button: Button = %LibrarianButton
@onready var quest_board_button: Button = %QuestBoardButton
@onready var service_title_label: Label = %ServiceTitleLabel
@onready var service_body_label: Label = %ServiceBodyLabel

var expedition_state


func _ready() -> void:
	start_dungeon_button.pressed.connect(func(): start_dungeon_requested.emit())
	blacksmith_button.pressed.connect(_show_placeholder.bind("Blacksmith", "Upgrade and craft equipment. TODO."))
	witch_button.pressed.connect(_show_placeholder.bind("Witch", "Brew run support and strange bargains. TODO."))
	librarian_button.pressed.connect(_show_placeholder.bind("Librarian", "Manage skill books and research. TODO."))
	quest_board_button.pressed.connect(_show_placeholder.bind("Quest Board", "Choose objectives and claims. TODO."))
	_show_placeholder("Welcome", "Prepare for the next dungeon run.")
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
	service_title_label.text = title
	service_body_label.text = body


func _get_state_value(property_name: StringName, fallback: Variant) -> Variant:
	if expedition_state == null:
		return fallback

	var value: Variant = expedition_state.get(property_name)
	if value == null:
		return fallback

	return value
