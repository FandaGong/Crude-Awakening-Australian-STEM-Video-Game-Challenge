class_name SkillNodeData
extends Resource

enum Branch { TARGETING, SYNERGY, COMPENDIUM, OVERHEAT }

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var branch: Branch = Branch.TARGETING
@export var cost: int = 100 # Compendium Data cost
@export var icon: Texture2D
@export var required_node_id: String = "" # Empty if it's the first node in a branch
@export var is_keystone: bool = false
