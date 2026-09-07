class_name SkillConnectorUI
extends ColorRect

## A thin line dropped between two skill nodes inside the same branch
## VBoxContainer. The skill tree flows top-to-bottom (each branch is a
## vertical column), so this is a short *vertical* bar that sits in the
## natural gap between the node above and the node below - not a
## horizontal line, which would only make sense if branches ran
## left-to-right.
##
## Lights up to `unlocked_color` once `prerequisite_skill_id` has been
## unlocked, otherwise stays dim, so the tree reads as a lit-up path
## going down as the player progresses.

@export var prerequisite_skill_id: String = ""
@export var locked_color: Color = Color(0.35, 0.35, 0.35, 0.6)
@export var unlocked_color: Color = Color(0.4, 1.0, 0.5, 1.0)

func _ready() -> void:
	# Narrow and short so it reads as a connecting line, not a bar; centered
	# under the node above it via SIZE_SHRINK_CENTER.
	custom_minimum_size = Vector2(2, 6)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	GameData.skill_unlocked.connect(func(_id): _update_color())
	_update_color()

func _update_color() -> void:
	color = unlocked_color if GameData.has_skill(prerequisite_skill_id) else locked_color
