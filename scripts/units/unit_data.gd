class_name UnitData
extends Resource

@export_category("Identity")
@export var unit_name: String = "Unit"

@export_category("Stats")
@export var max_hp: int = 30
@export var atk: int = 5
@export var def: int = 2
@export var spd: int = 10

@export_category("Skills")
@export var skills: Array[SkillData] = []
