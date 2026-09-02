class_name ItemData
extends Resource

enum ItemType { GENERIC, HEAD, BODY, ACCESSORY, WEAPON }

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.GENERIC
@export var max_stack: int = 99
