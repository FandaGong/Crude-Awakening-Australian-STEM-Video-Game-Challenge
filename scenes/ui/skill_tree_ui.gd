extends Control

@onready var lock_overlay: Control = $LockOverlay
@onready var data_label: Label = $Header/CompendiumDataLabel
@onready var details_panel: PanelContainer = $DetailsPanel
@onready var skill_title: Label = $DetailsPanel/SkillNameLabel
@onready var skill_desc: Label = $DetailsPanel/DescriptionLabel
@onready var skill_cost: Label = $DetailsPanel/CostLabel
@onready var unlock_button: TextureButton = $DetailsPanel/UnlockButton

var selected_node: SkillNodeData = null

func _ready() -> void:
	unlock_button.pressed.connect(_on_unlock_button_pressed)
	GameData.compendium_data_changed.connect(_update_currency_display)
	GameData.robot_unlocked_changed.connect(_update_lock_state)
	
	_update_lock_state(GameData.is_robot_unlocked)
	_update_currency_display(GameData.compendium_data)
	_connect_all_nodes(self)
	details_panel.hide()

func _connect_all_nodes(parent: Node) -> void:
	for child in parent.get_children():
		if child is SkillNodeUI:
			child.node_selected.connect(_on_node_selected)
		elif child.get_child_count() > 0:
			_connect_all_nodes(child)

func _update_lock_state(unlocked: bool) -> void:
	lock_overlay.visible = not unlocked

func _update_currency_display(amount: int) -> void:
	data_label.text = "Compendium Data: %d TB" % amount
	_refresh_details_panel()

func _on_node_selected(data: SkillNodeData) -> void:
	selected_node = data
	details_panel.show()
	_refresh_details_panel()

func _refresh_details_panel() -> void:
	if not selected_node:
		return
		
	skill_title.text = selected_node.title
	skill_desc.text = selected_node.description
	skill_cost.text = "Cost: %d Data" % selected_node.cost
	
	if GameData.has_skill(selected_node.id):
		unlock_button.disabled = true
		unlock_button.text = "UNLOCKED"
	elif GameData.can_unlock(selected_node.id):
		unlock_button.disabled = false
		unlock_button.text = "UNLOCK"
	else:
		unlock_button.disabled = true
		unlock_button.text = "LOCKED"

func _on_unlock_button_pressed() -> void:
	if selected_node and GameData.unlock_skill(selected_node.id):
		_refresh_details_panel()
