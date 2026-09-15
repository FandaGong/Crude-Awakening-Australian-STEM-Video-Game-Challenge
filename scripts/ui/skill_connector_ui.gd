class_name SkillConnectorUI
extends ColorRect

# Skill tree connector

@export var prerequisite_skill_id: String = ""
@export var locked_color: Color = Color(0.35, 0.35, 0.35, 0.6)
@export var unlocked_color: Color = Color(0.4, 1.0, 0.5, 1.0)

func _ready() -> void:
	# Connector size
	custom_minimum_size = Vector2(2, 6)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	GameData.skill_unlocked.connect(func(_id): _update_color())
	_update_color()

func _update_color() -> void:
	color = unlocked_color if GameData.has_skill(prerequisite_skill_id) else locked_color
