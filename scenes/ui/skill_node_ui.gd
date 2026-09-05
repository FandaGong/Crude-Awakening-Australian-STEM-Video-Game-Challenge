class_name SkillNodeUI
extends TextureButton

signal node_selected(node_data: SkillNodeData)

@export var skill_id: String = ""
@onready var icon_rect: TextureRect = $Icon
@onready var border: TextureRect = $Border
@onready var keystone_glow: TextureRect = $KeystoneGlow

var node_data: SkillNodeData

func _ready() -> void:
	pressed.connect(_on_pressed)
	GameData.skill_unlocked.connect(func(_id): update_state())
	GameData.trash_tokens_changed.connect(func(_val): update_state())
	GameData.robot_unlocked_changed.connect(func(_val): update_state())
	
	if GameData.skill_database.has(skill_id):
		node_data = GameData.skill_database[skill_id]
		if node_data.icon and icon_rect:
			icon_rect.texture = node_data.icon
		if keystone_glow:
			keystone_glow.visible = node_data.is_keystone
	update_state()

func update_state() -> void:
	if not node_data:
		return

	var is_unlocked = GameData.has_skill(skill_id)
	var can_buy = GameData.can_unlock(skill_id)

	if is_unlocked:
		modulate = Color(1.0, 1.0, 1.0, 1.0) # Full bright (Acquired)
		if border: border.modulate = Color.GREEN
	elif can_buy:
		modulate = Color(0.8, 0.9, 1.0, 0.9) # Ready to purchase (Cyan tint)
		if border: border.modulate = Color.CYAN
	else:
		modulate = Color(0.35, 0.35, 0.35, 0.6) # Locked (Darkened)
		if border: border.modulate = Color.DIM_GRAY

func _on_pressed() -> void:
	if node_data:
		node_selected.emit(node_data)
