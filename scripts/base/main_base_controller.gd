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

var player_profile: PlayerProfileData


func _ready() -> void:
	start_dungeon_button.pressed.connect(func(): start_dungeon_requested.emit())
	blacksmith_button.pressed.connect(_show_placeholder.bind("Blacksmith", "Upgrade and craft equipment. TODO."))
	witch_button.pressed.connect(_show_placeholder.bind("Witch", "Brew run support and strange bargains. TODO."))
	librarian_button.pressed.connect(_show_placeholder.bind("Librarian", "Manage skill books and research. TODO."))
	quest_board_button.pressed.connect(_show_placeholder.bind("Quest Board", "Choose objectives and claims. TODO."))
	_show_placeholder("Welcome", "Prepare for the next dungeon run.")
	_refresh_profile_summary()


func set_player_profile(profile: PlayerProfileData) -> void:
	player_profile = profile
	if is_node_ready():
		_refresh_profile_summary()


func _refresh_profile_summary() -> void:
	if player_profile == null:
		gold_label.text = "Gold: 0"
		monster_materials_label.text = "Monster Materials: 0"
		ores_label.text = "Ores: 0"
		herbs_label.text = "Herbs: 0"
		streak_label.text = "Streak: 0"
		return

	gold_label.text = "Gold: %d" % player_profile.gold
	monster_materials_label.text = "Monster Materials: %d" % player_profile.monster_materials
	ores_label.text = "Ores: %d" % player_profile.ores
	herbs_label.text = "Herbs: %d" % player_profile.herbs
	streak_label.text = "Streak: %d" % player_profile.current_streak


func _show_placeholder(title: String, body: String) -> void:
	service_title_label.text = title
	service_body_label.text = body
