extends Control

@onready var lock_overlay: Control = $LockOverlay
@onready var data_label: Label = $Header/CompendiumDataLabel
@onready var details_panel: Panel = $DetailsPanel
@onready var skill_title: Label = $DetailsPanel/SkillNameLabel
@onready var skill_desc: Label = $DetailsPanel/DescriptionLabel
@onready var skill_cost: Label = $DetailsPanel/CostLabel
@onready var unlock_button: TextureButton = $DetailsPanel/UnlockButton
# 1. Fetch the child label reference inside the TextureButton
@onready var unlock_label: Label = $DetailsPanel/UnlockButton/Label

var selected_node: SkillNodeData = null

# Tracks every skill node (and the details panel itself) the mouse is
# currently over. The panel is shown the instant this set stops being empty
# and hidden the instant it goes back to empty, so it appears on hover over
# the skill tree and disappears the moment nothing relevant is hovered.
var _hovered: Dictionary = {}

## How far from the cursor (in viewport pixels) the panel is placed.
@export var details_panel_mouse_offset: Vector2 = Vector2(10, 10)

func _ready() -> void:
	unlock_button.pressed.connect(_on_unlock_button_pressed)
	GameData.trash_tokens_changed.connect(_update_currency_display)
	GameData.robot_unlocked_changed.connect(_update_lock_state)
	
	_update_lock_state(GameData.is_robot_unlocked)
	_update_currency_display(GameData.trash_tokens)
	_connect_all_nodes(self)

	# The panel itself can be hovered too (e.g. to reach the Unlock button),
	# which should keep it open rather than having it vanish out from under
	# the cursor the moment it leaves the skill node.
	details_panel.mouse_entered.connect(_on_panel_hover_entered)
	details_panel.mouse_exited.connect(_on_panel_hover_exited)
	details_panel.hide()

## While a skill node is hovered, keep the panel tracking the cursor. Once
## the cursor has moved onto the panel itself we stop repositioning it (it's
## no longer over a node), which is what lets the mouse travel from the
## button onto the panel without the panel sliding out from under it.
func _process(_delta: float) -> void:
	if details_panel.visible and _is_hovering_a_node():
		_position_details_panel(get_global_mouse_position())

func _is_hovering_a_node() -> bool:
	for key in _hovered.keys():
		if key is SkillNodeUI:
			return true
	return false

## Places the panel just off the cursor, clamped so it never runs off the
## edge of the viewport.
func _position_details_panel(global_mouse_pos: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	var panel_size := details_panel.size
	var target := global_mouse_pos + details_panel_mouse_offset
	target.x = clamp(target.x, 0.0, max(0.0, viewport_size.x - panel_size.x))
	target.y = clamp(target.y, 0.0, max(0.0, viewport_size.y - panel_size.y))
	details_panel.global_position = target

func _connect_all_nodes(parent: Node) -> void:
	for child in parent.get_children():
		if child is SkillNodeUI:
			child.node_selected.connect(_on_node_selected)
			child.mouse_entered.connect(_on_node_hover_entered.bind(child))
			child.mouse_exited.connect(_on_node_hover_exited.bind(child))
		elif child.get_child_count() > 0:
			_connect_all_nodes(child)

func _on_node_hover_entered(node_ui: SkillNodeUI) -> void:
	_hovered[node_ui] = true
	if node_ui.node_data:
		selected_node = node_ui.node_data
		_position_details_panel(get_global_mouse_position())
		details_panel.show()
		_refresh_details_panel()

func _on_node_hover_exited(node_ui: SkillNodeUI) -> void:
	_hovered.erase(node_ui)
	call_deferred("_update_panel_visibility")

func _on_panel_hover_entered() -> void:
	_hovered[details_panel] = true

func _on_panel_hover_exited() -> void:
	_hovered.erase(details_panel)
	call_deferred("_update_panel_visibility")

## Deferred so that leaving one node and entering an adjacent one (or the
## panel) in the same input pass doesn't flicker the panel closed and
## immediately back open.
func _update_panel_visibility() -> void:
	if _hovered.is_empty():
		details_panel.hide()

func _update_lock_state(unlocked: bool) -> void:
	lock_overlay.visible = not unlocked

func _update_currency_display(amount: int) -> void:
	data_label.text = "Recycled Trash: %d" % amount
	_refresh_details_panel()

func _on_node_selected(data: SkillNodeData) -> void:
	selected_node = data
	_position_details_panel(get_global_mouse_position())
	details_panel.show()
	_refresh_details_panel()

func _refresh_details_panel() -> void:
	if not selected_node:
		return
		
	skill_title.text = selected_node.title
	skill_desc.text = selected_node.description
	skill_cost.text = "Cost: %d Data" % selected_node.cost
	
	# 2. Redirect the .text assignment variables safely to the child label
	if GameData.has_skill(selected_node.id):
		unlock_button.disabled = true
		if unlock_label: unlock_label.text = "UNLOCKED"
	elif GameData.can_unlock(selected_node.id):
		unlock_button.disabled = false
		if unlock_label: unlock_label.text = "UNLOCK"
	else:
		unlock_button.disabled = true
		if unlock_label: unlock_label.text = "LOCKED"

func _on_unlock_button_pressed() -> void:
	if selected_node and GameData.unlock_skill(selected_node.id):
		_refresh_details_panel()
